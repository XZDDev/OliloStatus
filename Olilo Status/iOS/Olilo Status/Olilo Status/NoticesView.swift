import Foundation
import SwiftUI
import Combine

struct StatusNotice: Identifiable {
    enum NoticeKind: String, CaseIterable, Identifiable {
        case incident = "Incident"
        case maintenance = "Maintenance"
        case notice = "Notice"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .incident: return "exclamationmark.triangle"
            case .maintenance: return "wrench.and.screwdriver"
            case .notice: return "bell"
            }
        }
    }

    struct Update: Identifiable {
        let id = UUID()
        let status: String
        let message: String
    }

    let id: String
    let title: String
    let kind: NoticeKind
    let published: Date?
    let updated: Date?
    let link: URL?
    let duration: String?
    let affectedComponents: String?
    let summary: String
    let updates: [Update]
}

@MainActor
final class NoticesViewModel: ObservableObject {
    @Published var activeIncidents: [Incident] = []
    @Published var activeMaintenances: [Maintenance] = []
    @Published var notices: [StatusNotice] = []
    @Published var selectedKind: StatusNotice.NoticeKind?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefreshed: Date?

    private let api = StatusAPI()
    private let noticesAPI = NoticesAPI()

    var filteredNotices: [StatusNotice] {
        guard let selectedKind else { return notices }
        return notices.filter { $0.kind == selectedKind }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            async let summaryTask = api.fetchSummary()
            async let noticesTask = noticesAPI.fetchNoticeHistory()
            let (summary, notices) = try await (summaryTask, noticesTask)

            self.activeIncidents = summary.activeIncidents ?? []
            self.activeMaintenances = summary.activeMaintenances ?? []
            self.notices = notices
            self.lastRefreshed = .now
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isLoading = false
    }
}

struct NoticesView: View {
    @StateObject private var model = NoticesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.notices.isEmpty {
                    ProgressView("Loading notices...")
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").symbolVariant(.fill)
                        Text("Failed to load notices")
                            .font(.headline)
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { Task { await model.refresh() } }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            if !model.activeIncidents.isEmpty || !model.activeMaintenances.isEmpty {
                                NoticeSectionHeader(title: "Current Notices", count: model.activeIncidents.count + model.activeMaintenances.count)
                                ForEach(model.activeIncidents) { incident in
                                    ActiveIncidentNoticeCard(incident: incident)
                                        .padding(.horizontal)
                                }
                                ForEach(model.activeMaintenances) { maintenance in
                                    ActiveMaintenanceNoticeCard(maintenance: maintenance)
                                        .padding(.horizontal)
                                }
                            }

                            NoticeFilterBar(selectedKind: Binding(
                                get: { model.selectedKind },
                                set: { model.selectedKind = $0 }
                            ))
                                .padding(.horizontal)

                            NoticeSectionHeader(title: "Notice History", count: model.filteredNotices.count)
                            ForEach(model.filteredNotices) { notice in
                                NoticeHistoryCard(notice: notice)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 18)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Notices")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    OliloToolbarLogo()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.oliloPurple)
                    }
                    .disabled(model.isLoading)
                    .tint(Color.oliloPurple)
                    .accessibilityLabel("Refresh notices")
                }
            }
            .task { await model.refresh() }
            .background(OliloDarkGradientBackground())
        }
    }
}

private struct NoticeFilterBar: View {
    @Binding var selectedKind: StatusNotice.NoticeKind?

    var body: some View {
        Picker("Notice type", selection: $selectedKind) {
            Text("All").tag(StatusNotice.NoticeKind?.none)
            ForEach([StatusNotice.NoticeKind.incident, .maintenance]) { kind in
                Text(kind.rawValue).tag(Optional(kind))
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct NoticeSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

private struct ActiveIncidentNoticeCard: View {
    let incident: Incident

    var body: some View {
        NoticeCard {
            VStack(alignment: .leading, spacing: 12) {
                NoticeTitleRow(title: incident.title, subtitle: "Incident", status: incident.impact ?? incident.status, systemImage: "exclamationmark.triangle")
                NoticeDetailGrid(rows: [
                    NoticeDetailRow(label: "Status", value: readableStatus(incident.status)),
                    NoticeDetailRow(label: "Impact", value: incident.impact.map(readableStatus)),
                    NoticeDetailRow(label: "Started", value: incident.started?.formatted(date: .abbreviated, time: .shortened)),
                    NoticeDetailRow(label: "Updated", value: incident.updatedAt?.formatted(date: .abbreviated, time: .shortened))
                ])
                if let description = incident.description, !description.isEmpty {
                    ExpandableNoticeDescription(text: description)
                }
                if let url = incident.url {
                    Link(destination: url) {
                        Label("Open incident", systemImage: "arrow.up.forward.square")
                    }
                    .font(.callout.weight(.medium))
                }
            }
        }
    }
}

private struct ActiveMaintenanceNoticeCard: View {
    let maintenance: Maintenance

    var body: some View {
        NoticeCard {
            VStack(alignment: .leading, spacing: 12) {
                NoticeTitleRow(title: maintenance.name, subtitle: "Maintenance", status: maintenance.status, systemImage: "wrench.and.screwdriver")
                NoticeDetailGrid(rows: [
                    NoticeDetailRow(label: "Status", value: readableStatus(maintenance.status)),
                    NoticeDetailRow(label: "Start", value: maintenance.start?.formatted(date: .abbreviated, time: .shortened)),
                    NoticeDetailRow(label: "Duration", value: maintenance.duration.map { "\($0) minutes" }),
                    NoticeDetailRow(label: "Updated", value: maintenance.updatedAt?.formatted(date: .abbreviated, time: .shortened))
                ])
                if let url = maintenance.url {
                    Link(destination: url) {
                        Label("Open maintenance", systemImage: "arrow.up.forward.square")
                    }
                    .font(.callout.weight(.medium))
                }
            }
        }
    }
}

private struct NoticeHistoryCard: View {
    let notice: StatusNotice

    var body: some View {
        NoticeCard {
            VStack(alignment: .leading, spacing: 12) {
                NoticeTitleRow(title: notice.title, subtitle: notice.kind.rawValue, status: notice.kind == .incident ? "PARTIALOUTAGE" : "UNDERMAINTENANCE", systemImage: notice.kind.systemImage)
                NoticeDetailGrid(rows: [
                    NoticeDetailRow(label: "Published", value: notice.published?.formatted(date: .abbreviated, time: .shortened)),
                    NoticeDetailRow(label: "Updated", value: notice.updated?.formatted(date: .abbreviated, time: .shortened)),
                    NoticeDetailRow(label: "Duration", value: notice.duration),
                    NoticeDetailRow(label: "Components", value: notice.affectedComponents)
                ])

                ExpandableNoticeDescription(text: notice.summary)

                if !notice.updates.isEmpty {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(notice.updates) { update in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(update.status)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(statusColor(update.status))
                                    Text(update.message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Label("\(notice.updates.count) update\(notice.updates.count == 1 ? "" : "s")", systemImage: "list.bullet.rectangle")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Color.oliloPurple)
                    }
                    .tint(Color.oliloPurple)
                }

                if let link = notice.link {
                    Link(destination: link) {
                        Label("Open notice", systemImage: "arrow.up.forward.square")
                            .foregroundStyle(Color.oliloPurple)
                    }
                    .font(.callout.weight(.medium))
                    .tint(Color.oliloPurple)
                }
            }
        }
    }
}

private struct ExpandableNoticeDescription: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(isExpanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Label(isExpanded ? "Show less" : "Show more", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.oliloPurple)
            .accessibilityLabel(isExpanded ? "Collapse description" : "Expand description")
        }
    }
}

private struct NoticeTitleRow: View {
    let title: String
    let subtitle: String
    let status: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.oliloPurple)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct NoticeMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 68, alignment: .topLeading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct NoticeDetailRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String?
}

private struct NoticeDetailGrid: View {
    let rows: [NoticeDetailRow]

    var visibleRows: [NoticeDetailRow] {
        rows.filter { $0.value?.isEmpty == false }
    }

    var body: some View {
        if !visibleRows.isEmpty {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                ForEach(visibleRows) { row in
                    GridRow {
                        Text(row.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(row.value ?? "")
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

private struct NoticeCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
    }
}

private struct NoticesAPI {
    private let feedURL = URL(string: "https://status.olilo.co.uk/default/history.atom")!

    func fetchNoticeHistory() async throws -> [StatusNotice] {
        let (data, response) = try await URLSession.shared.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try AtomNoticeParser().parse(data)
    }
}

private final class AtomNoticeParser: NSObject, XMLParserDelegate {
    private var notices: [StatusNotice] = []
    private var currentEntry: Entry?
    private var currentElement = ""
    private var currentText = ""

    private struct Entry {
        var id = ""
        var title = ""
        var published: Date?
        var updated: Date?
        var link: URL?
        var content = ""
    }

    func parse(_ data: Data) throws -> [StatusNotice] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }
        return notices.sorted {
            ($0.published ?? .distantPast) > ($1.published ?? .distantPast)
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""
        if elementName == "entry" {
            currentEntry = Entry()
        } else if elementName == "link", currentEntry != nil, let href = attributeDict["href"] {
            currentEntry?.link = URL(string: href)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let text = String(data: CDATABlock, encoding: .utf8) {
            currentText += text
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard currentEntry != nil else { return }
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "id":
            currentEntry?.id = text
        case "title":
            currentEntry?.title = text.decodingHTMLEntities()
        case "published":
            currentEntry?.published = DateFormatter.atomDate.date(from: text)
        case "updated":
            currentEntry?.updated = DateFormatter.atomDate.date(from: text)
        case "content":
            currentEntry?.content = text
        case "entry":
            if let entry = currentEntry {
                notices.append(makeNotice(from: entry))
            }
            currentEntry = nil
        default:
            break
        }

        currentText = ""
        currentElement = ""
    }

    private func makeNotice(from entry: Entry) -> StatusNotice {
        let text = entry.content
            .htmlToPlainText()
            .decodingHTMLEntities()
            .normalizingWhitespace()

        let kind = value(after: "Type:", in: text)
            .flatMap { StatusNotice.NoticeKind(rawValue: $0) } ?? .notice
        let duration = value(after: "Duration:", in: text)
        let affected = value(after: "Affected Components:", in: text)
        let updates = parseUpdates(fromHTML: entry.content)
        let summary = updates.first?.message ?? text
        let id = entry.id.isEmpty ? "notice-\(entry.link?.absoluteString ?? entry.title)" : entry.id

        return StatusNotice(
            id: id,
            title: entry.title,
            kind: kind,
            published: entry.published,
            updated: entry.updated,
            link: entry.link,
            duration: duration,
            affectedComponents: affected,
            summary: summary,
            updates: updates
        )
    }

    private func value(after label: String, in text: String) -> String? {
        guard let labelRange = text.range(of: label) else { return nil }
        let tail = text[labelRange.upperBound...]
        let stopLabels = ["Type:", "Duration:", "Affected Components:"]
        var stop = stopLabels
            .filter { $0 != label }
            .compactMap { tail.range(of: $0)?.lowerBound }
            .min()
        if let updateStart = tail.range(of: #"[A-Z][a-z]{2}\s+\d{1,2},"#, options: .regularExpression)?.lowerBound {
            if stop == nil || updateStart < stop! {
                stop = updateStart
            }
        }
        let valueSlice = tail[..<(stop ?? tail.endIndex)]
        let value = String(valueSlice).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func parseUpdates(fromHTML html: String) -> [StatusNotice.Update] {
        let pattern = #"<p>\s*<small>.*?</small>\s*<br\s*/?>\s*<strong>(.*?)</strong>\s*-\s*(.*?)</p>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: nsRange).compactMap { match in
            guard
                let statusRange = Range(match.range(at: 1), in: html),
                let messageRange = Range(match.range(at: 2), in: html)
            else { return nil }
            let status = String(html[statusRange])
                .htmlToPlainText()
                .decodingHTMLEntities()
                .normalizingWhitespace()
            let message = String(html[messageRange])
                .htmlToPlainText()
                .decodingHTMLEntities()
                .normalizingWhitespace()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard !status.isEmpty, !message.isEmpty else { return nil }
            return StatusNotice.Update(status: status, message: message)
        }
    }
}

private extension DateFormatter {
    static let atomDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
}

private extension String {
    func htmlToPlainText() -> String {
        var text = self
        text = text.replacingOccurrences(of: "<br />", with: " ")
        text = text.replacingOccurrences(of: "<br>", with: " ")
        text = text.replacingOccurrences(of: "</p>", with: "\n")
        text = text.replacingOccurrences(of: "</small>", with: " ")
        text = text.replacingOccurrences(of: "</strong>", with: " ")
        text = text.replacingOccurrences(of: "</var>", with: "")
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>") else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    func normalizingWhitespace() -> String {
        components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    func decodingHTMLEntities() -> String {
        guard let data = data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return self
        }
        return attributed.string
    }
}

#Preview {
    NoticesView()
}
