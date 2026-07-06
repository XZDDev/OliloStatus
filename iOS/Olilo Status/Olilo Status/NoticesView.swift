import Foundation
import SwiftUI
import Combine
import UIKit

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
        let timestamp: Date?
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
    @Published var hidesNoticesOlderThan30Days = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastRefreshed: Date?

    private let api = StatusAPI()
    private let noticesAPI = NoticesAPI()

    var filteredNotices: [StatusNotice] {
        notices
            .filter { notice in
                selectedKind == nil || notice.kind == selectedKind
            }
            .filter { notice in
                !hidesNoticesOlderThan30Days || !notice.isOlderThan30Days
            }
    }

    /// Refreshes active notices and historical feed entries for the notices screen.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let summary = try await api.fetchSummary()
            let notices = try await noticesAPI.fetchNoticeHistory()

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

private extension Incident {
    var currentNoticeListID: String { "current-incident-\(id)" }
}

private extension Maintenance {
    var currentNoticeListID: String { "current-maintenance-\(id)" }
}

private extension StatusNotice {
    var isOlderThan30Days: Bool {
        guard
            let noticeDate = updated ?? published,
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: .now)
        else {
            return false
        }
        return noticeDate < cutoffDate
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
                            .accessibilityHidden(true)
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
                                ForEach(model.activeIncidents, id: \.currentNoticeListID) { incident in
                                    ActiveIncidentNoticeCard(incident: incident)
                                        .padding(.horizontal)
                                }
                                ForEach(model.activeMaintenances, id: \.currentNoticeListID) { maintenance in
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.hidesNoticesOlderThan30Days.toggle()
                    } label: {
                        Image(systemName: model.hidesNoticesOlderThan30Days ? "eye.slash" : "eye")
                            .foregroundStyle(Color.oliloTheme)
                    }
                    .tint(Color.oliloTheme)
                    .accessibilityLabel(
                        model.hidesNoticesOlderThan30Days
                        ? "Show notices older than 30 days"
                        : "Hide notices older than 30 days"
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.oliloTheme)
                    }
                    .disabled(model.isLoading)
                    .tint(Color.oliloTheme)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(count)")
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
                            .foregroundStyle(Color.oliloTheme)
                    }
                    .tint(Color.oliloTheme)
                }

                if let link = notice.link {
                    Link(destination: link) {
                        Label("Open notice", systemImage: "arrow.up.forward.square")
                            .foregroundStyle(Color.oliloTheme)
                    }
                    .font(.callout.weight(.medium))
                    .tint(Color.oliloTheme)
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
            .foregroundStyle(Color.oliloTheme)
            .accessibilityLabel(isExpanded ? "Collapse description" : "Expand description")
            .accessibilityHint(isExpanded ? "Hides the full description" : "Shows the full description")
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
                .foregroundStyle(Color.oliloTheme)
                .frame(width: 24)
                .accessibilityHidden(true)
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

    /// Captures the caller's content for rendering inside the shared notice card style.
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct NoticesAPI {
    private let feedURL = URL(string: "https://status.olilo.co.uk/default/history.atom")!

    /// Downloads the Atom notice history feed and parses it into status notices.
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

    /// Parses Atom XML data and returns notices sorted newest first.
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

    /// Tracks entry boundaries and captures entry links when XML elements start.
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""
        if elementName == "entry" {
            currentEntry = Entry()
        } else if elementName == "link", currentEntry != nil, let href = attributeDict["href"] {
            currentEntry?.link = URL(string: href)
        }
    }

    /// Accumulates text emitted for the current XML element.
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    /// Appends CDATA content to the current element text when present.
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let text = String(data: CDATABlock, encoding: .utf8) {
            currentText += text
        }
    }

    /// Commits parsed element text and finalizes entries when their XML closes.
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

    /// Converts a parsed Atom entry into the app's notice model.
    private func makeNotice(from entry: Entry) -> StatusNotice {
        let text = entry.content
            .htmlToPlainText()
            .decodingHTMLEntities()
            .normalizingWhitespace()

        let kind = value(after: "Type:", in: text)
            .flatMap { StatusNotice.NoticeKind(rawValue: $0) } ?? .notice
        let duration = value(after: "Duration:", in: text)
        let affected = value(after: "Affected Components:", in: text)
        let updates = parseUpdates(fromHTML: entry.content, referenceDate: entry.published ?? entry.updated)
        let updateTimestamps = updates.compactMap(\.timestamp)
        let summary = updates.first?.message ?? text
        let id = entry.id.isEmpty ? "notice-\(entry.link?.absoluteString ?? entry.title)" : entry.id

        return StatusNotice(
            id: id,
            title: entry.title,
            kind: kind,
            published: updateTimestamps.min() ?? entry.published,
            updated: updateTimestamps.max() ?? entry.updated,
            link: entry.link,
            duration: duration,
            affectedComponents: affected,
            summary: summary,
            updates: updates
        )
    }

    /// Extracts the value following a known label in the flattened notice text.
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

    /// Extracts status update rows from the notice HTML content.
    private func parseUpdates(fromHTML html: String, referenceDate: Date?) -> [StatusNotice.Update] {
        let pattern = #"<p>\s*<small>(.*?)</small>\s*<br\s*/?>\s*<strong>(.*?)</strong>\s*-\s*(.*?)</p>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: nsRange).compactMap { match in
            guard
                let timestampRange = Range(match.range(at: 1), in: html),
                let statusRange = Range(match.range(at: 2), in: html),
                let messageRange = Range(match.range(at: 3), in: html)
            else { return nil }
            let timestamp = parseUpdateTimestamp(String(html[timestampRange]), referenceDate: referenceDate)
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
            return StatusNotice.Update(timestamp: timestamp, status: status, message: message)
        }
    }

    /// Parses the feed's update row timestamp, which omits the year.
    private func parseUpdateTimestamp(_ html: String, referenceDate: Date?) -> Date? {
        let text = html
            .htmlToPlainText()
            .decodingHTMLEntities()
            .replacingOccurrences(of: ",", with: "")
            .normalizingWhitespace()
        let pattern = #"^([A-Za-z]{3})\s+(\d{1,2})\s+(\d{1,2}):(\d{2}):(\d{2})\s+GMT([+-]\d{1,2})$"#
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
            let monthRange = Range(match.range(at: 1), in: text),
            let dayRange = Range(match.range(at: 2), in: text),
            let hourRange = Range(match.range(at: 3), in: text),
            let minuteRange = Range(match.range(at: 4), in: text),
            let secondRange = Range(match.range(at: 5), in: text),
            let offsetRange = Range(match.range(at: 6), in: text),
            let month = monthFormatter.shortMonthSymbols.firstIndex(of: String(text[monthRange])),
            let day = Int(text[dayRange]),
            let hour = Int(text[hourRange]),
            let minute = Int(text[minuteRange]),
            let second = Int(text[secondRange]),
            let offsetHours = Int(text[offsetRange])
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: offsetHours * 60 * 60) ?? .gmt
        let year = referenceDate.map { calendar.component(.year, from: $0) } ?? calendar.component(.year, from: .now)
        return calendar.date(from: DateComponents(year: year, month: month + 1, day: day, hour: hour, minute: minute, second: second))
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
    /// Removes lightweight HTML tags while preserving readable paragraph breaks.
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

    /// Trims blank lines and joins remaining lines with single newlines.
    func normalizingWhitespace() -> String {
        components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Decodes HTML entities using Foundation's attributed string importer.
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
