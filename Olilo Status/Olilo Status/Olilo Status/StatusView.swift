import SwiftUI
import Combine
import Charts

struct Incident: Identifiable, Decodable {
    let id: String
    let name: String
    let description: String?
    let status: String
    let impact: String?
    let url: URL?
    let started: Date?
    let updatedAt: Date?

    var title: String { name }
    var displayDate: Date? { updatedAt ?? started }
}

struct Maintenance: Identifiable, Decodable {
    let id: String
    let name: String
    let status: String
    let start: Date?
    let duration: String?
    let url: URL?
    let updatedAt: Date?
}

struct StatusPageSummary: Decodable {
    struct Page: Decodable {
        let name: String
        let url: URL
        let status: String
    }

    let page: Page
    let activeIncidents: [Incident]?
    let activeMaintenances: [Maintenance]?
}

struct StatusComponent: Decodable, Identifiable {
    struct Group: Decodable, Identifiable {
        let id: String
        let name: String
        let description: String?
    }

    let id: String
    let name: String
    let description: String?
    let status: String
    let group: Group?
}

struct StatusComponentGroup: Identifiable {
    let id: String
    let name: String
    let description: String?
    let parent: StatusComponent?
    let children: [StatusComponent]

    var allComponents: [StatusComponent] {
        if let parent {
            return [parent] + children
        }
        return children
    }

    var worstStatus: String {
        allComponents.map(\.status).sorted(by: statusSeveritySort).last ?? "UNKNOWN"
    }
}

@MainActor
final class StatusViewModel: ObservableObject {
    @Published var summary: StatusPageSummary?
    @Published var components: [StatusComponent] = []
    @Published var incidents: [Incident] = []
    @Published var maintenances: [Maintenance] = []
    @Published var lastRefreshed: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var groupedByDay: [(day: Date, items: [Incident])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: incidents) { (incident: Incident) -> Date in
            let date = incident.displayDate ?? Date()
            return calendar.startOfDay(for: date)
        }
        return groups.keys.sorted(by: >).map { key in
            (day: key, items: groups[key]!.sorted { ($0.displayDate ?? .distantPast) > ($1.displayDate ?? .distantPast) })
        }
    }

    var affectedComponents: [StatusComponent] {
        components
            .filter { statusSeverity($0.status) > 0 }
            .sorted { statusSeverity($0.status) > statusSeverity($1.status) }
    }

    var componentGroups: [StatusComponentGroup] {
        let parentComponents = components.filter { $0.group == nil }
        let childComponents = components.filter { $0.group != nil }
        let childrenByGroup = Dictionary(grouping: childComponents) { $0.group!.id }

        var seenGroupIDs = Set<String>()
        var groups = parentComponents.map { parent -> StatusComponentGroup in
            seenGroupIDs.insert(parent.id)
            return StatusComponentGroup(
                id: parent.id,
                name: parent.name,
                description: parent.description,
                parent: parent,
                children: (childrenByGroup[parent.id] ?? []).sorted { $0.name < $1.name }
            )
        }

        let orphanGroups = childrenByGroup.keys
            .filter { !seenGroupIDs.contains($0) }
            .compactMap { groupID -> StatusComponentGroup? in
                guard let group = childrenByGroup[groupID]?.first?.group else { return nil }
                return StatusComponentGroup(
                    id: group.id,
                    name: group.name,
                    description: group.description,
                    parent: nil,
                    children: (childrenByGroup[groupID] ?? []).sorted { $0.name < $1.name }
                )
            }

        groups.append(contentsOf: orphanGroups)
        return groups.sorted {
            if statusSeverity($0.worstStatus) == statusSeverity($1.worstStatus) {
                return $0.name < $1.name
            }
            return statusSeverity($0.worstStatus) > statusSeverity($1.worstStatus)
        }
    }

    private let api = StatusAPI()

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            async let summaryTask = api.fetchSummary()
            async let componentsTask = api.fetchComponents()
            let (summary, components) = try await (summaryTask, componentsTask)

            self.summary = summary
            self.components = components
            self.incidents = summary.activeIncidents ?? []
            self.maintenances = summary.activeMaintenances ?? []
            self.lastRefreshed = .now
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isLoading = false
    }
}

struct StatusView: View {
    @StateObject private var model = StatusViewModel()
    @State private var isDashboardPresented = false

    private let dashboardURL = URL(string: "https://dashboard.as212683.net/d/olilo-traffic-analytics-001/traffic-analytics?orgId=2&from=now-1h&to=now&timezone=browser")

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.summary == nil {
                    ProgressView("Loading status...")
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").symbolVariant(.fill)
                        Text("Failed to load status")
                            .font(.headline)
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await model.refresh() } }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            if let summary = model.summary {
                                OverviewCard(
                                    summary: summary,
                                    componentCount: model.components.count,
                                    affectedCount: model.affectedComponents.count,
                                    incidentCount: model.incidents.count,
                                    maintenanceCount: model.maintenances.count,
                                    lastRefreshed: model.lastRefreshed
                                )
                                .padding(.horizontal)

                                if !model.affectedComponents.isEmpty {
                                    StatusSectionHeader(title: "Affected Services", count: model.affectedComponents.count)
                                    AffectedServicesCard(components: model.affectedComponents)
                                        .padding(.horizontal)
                                }
                            }

                            if !model.incidents.isEmpty {
                                StatusSectionHeader(title: "Active Incidents", count: model.incidents.count)
                                ForEach(model.incidents) { incident in
                                    IncidentCard(incident: incident)
                                        .padding(.horizontal)
                                }
                            }

                            if !model.maintenances.isEmpty {
                                StatusSectionHeader(title: "Maintenance", count: model.maintenances.count)
                                ForEach(model.maintenances) { maintenance in
                                    MaintenanceCard(maintenance: maintenance)
                                        .padding(.horizontal)
                                }
                            }

                            StatusSectionHeader(title: "Components", count: model.components.count) {
                                isDashboardPresented = true
                            }
                            ForEach(model.componentGroups) { group in
                                ComponentGroupCard(group: group)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 18)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Status")
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
                    .accessibilityLabel("Refresh status")
                }
            }
            .task { await model.refresh() }
            .background(OliloDarkGradientBackground())
            .sheet(isPresented: $isDashboardPresented) {
                if let dashboardURL {
                    OliloWebViewSheet(title: "Dashboard", url: dashboardURL)
                }
            }
        }
    }
}

private struct StatusSectionHeader: View {
    let title: String
    let count: Int
    var dashboardAction: (() -> Void)?

    init(title: String, count: Int, dashboardAction: (() -> Void)? = nil) {
        self.title = title
        self.count = count
        self.dashboardAction = dashboardAction
    }

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
            if let dashboardAction {
                Button("Grafana Dashboard", action: dashboardAction)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(Color.oliloPurple)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

private struct OverviewCard: View {
    let summary: StatusPageSummary
    let componentCount: Int
    let affectedCount: Int
    let incidentCount: Int
    let maintenanceCount: Int
    let lastRefreshed: Date?

    @State private var isStatusPagePresented = false

    var body: some View {
        StatusCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: statusSeverity(summary.page.status) == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(statusColor(summary.page.status))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Olilo Network Status")
                            .font(.title2.weight(.bold))
                        Text(statusSeverity(summary.page.status) == 0 ? "All systems operational" : readableStatus(summary.page.status))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    MetricPill(title: "Components", value: "\(componentCount)", systemImage: "server.rack")
                    MetricPill(title: "Affected", value: "\(affectedCount)", systemImage: "waveform.path.ecg")
                    MetricPill(title: "Incidents", value: "\(incidentCount)", systemImage: "exclamationmark.triangle")
                    MetricPill(title: "Maintenance", value: "\(maintenanceCount)", systemImage: "wrench.and.screwdriver")
                }

                HStack {
                    Button {
                        isStatusPagePresented = true
                    } label: {
                        Label("Olilo Status", systemImage: "gauge")
                            .foregroundStyle(Color.oliloPurple)
                    }
                    .buttonStyle(.plain)
                    .tint(Color.oliloPurple)
                    Spacer()
                    if let lastRefreshed {
                        Text("Updated \(lastRefreshed.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.callout.weight(.medium))
            }
        }
        .sheet(isPresented: $isStatusPagePresented) {
            OliloWebViewSheet(title: "Olilo Status", url: summary.page.url)
        }
    }
}

private struct AffectedServicesCard: View {
    let components: [StatusComponent]

    var body: some View {
        StatusCard {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(components) { component in
                    ComponentRow(component: component, showGroup: true)
                }
            }
        }
    }
}

private struct IncidentCard: View {
    let incident: Incident

    var body: some View {
        StatusCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    StatusDot(status: incident.status)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(incident.title)
                            .font(.headline)
                        Text(readableStatus(incident.status))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let impact = incident.impact {
                        StatusBadge(text: readableStatus(impact), status: impact)
                    }
                }

                DetailGrid(rows: [
                    DetailRow(label: "Started", value: incident.started?.formatted(date: .abbreviated, time: .shortened)),
                    DetailRow(label: "Updated", value: incident.updatedAt?.formatted(date: .abbreviated, time: .shortened)),
                    DetailRow(label: "ID", value: incident.id)
                ])

                if let description = incident.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let url = incident.url {
                    Link(destination: url) {
                        Label("Open incident", systemImage: "arrow.up.forward.square")
                            .font(.callout.weight(.medium))
                    }
                }
            }
        }
    }
}

private struct MaintenanceCard: View {
    let maintenance: Maintenance

    var body: some View {
        StatusCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    StatusDot(status: maintenance.status)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(maintenance.name)
                            .font(.headline)
                        Text(readableStatus(maintenance.status))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(text: readableStatus(maintenance.status), status: maintenance.status)
                }

                DetailGrid(rows: [
                    DetailRow(label: "Start", value: maintenance.start?.formatted(date: .abbreviated, time: .shortened)),
                    DetailRow(label: "Duration", value: maintenance.duration.map { "\($0) minutes" }),
                    DetailRow(label: "Updated", value: maintenance.updatedAt?.formatted(date: .abbreviated, time: .shortened)),
                    DetailRow(label: "ID", value: maintenance.id)
                ])

                if let url = maintenance.url {
                    Link(destination: url) {
                        Label("Open maintenance", systemImage: "arrow.up.forward.square")
                            .font(.callout.weight(.medium))
                    }
                }
            }
        }
    }
}

private struct ComponentGroupCard: View {
    let group: StatusComponentGroup

    var body: some View {
        StatusCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    StatusDot(status: group.worstStatus)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.headline)
                        if let description = group.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(group.allComponents.count) service\(group.allComponents.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    StatusBadge(text: readableStatus(group.worstStatus), status: group.worstStatus)
                }

                if let parent = group.parent, group.children.isEmpty {
                    ComponentRow(component: parent, showGroup: false)
                } else {
                    ForEach(group.children) { component in
                        ComponentRow(component: component, showGroup: false)
                    }
                }
            }
        }
    }
}

private struct ComponentRow: View {
    let component: StatusComponent
    let showGroup: Bool

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(status: component.status, size: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(component.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(readableStatus(component.status))
                    if showGroup, let group = component.group {
                        Text("-")
                        Text(group.name)
                    }
                    if let description = component.description, !description.isEmpty {
                        Text("-")
                        Text(description)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            StatusBadge(text: readableStatus(component.status), status: component.status)
        }
        .padding(.vertical, 6)
    }
}

private struct StatusCard<Content: View>: View {
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
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                            .blur(radius: 2)
                            .offset(x: -1, y: -1)
                            .mask(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 8)
    }
}

private struct StatusDot: View {
    let status: String
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: size, height: size)
            .padding(.top, size == 10 ? 6 : 0)
    }
}

private struct StatusBadge: View {
    let text: String
    let status: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(statusColor(status))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(statusColor(status).opacity(0.15), in: Capsule())
    }
}

private struct MetricPill: View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 68, alignment: .topLeading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DetailRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String?
}

private struct DetailGrid: View {
    let rows: [DetailRow]

    var visibleRows: [DetailRow] {
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

func statusSeverity(_ status: String) -> Int {
    switch status.uppercased() {
    case "UP", "OPERATIONAL", "RESOLVED", "COMPLETED":
        return 0
    case "UNDERMAINTENANCE", "MONITORING", "NOTSTARTEDYET":
        return 1
    case "DEGRADEDPERFORMANCE", "DEGRADED_PERFORMANCE", "IDENTIFIED":
        return 2
    case "PARTIALOUTAGE", "PARTIAL_OUTAGE", "INVESTIGATING":
        return 3
    case "MAJOROUTAGE", "MAJOR_OUTAGE":
        return 4
    default:
        return 2
    }
}

func statusSeveritySort(_ lhs: String, _ rhs: String) -> Bool {
    statusSeverity(lhs) < statusSeverity(rhs)
}

func statusColor(_ status: String) -> Color {
    switch status.uppercased() {
    case "UP", "OPERATIONAL", "RESOLVED", "COMPLETED":
        return .green
    case "UNDERMAINTENANCE", "MONITORING", "NOTSTARTEDYET":
        return .blue
    case "DEGRADEDPERFORMANCE", "DEGRADED_PERFORMANCE", "IDENTIFIED":
        return .orange
    case "PARTIALOUTAGE", "PARTIAL_OUTAGE", "INVESTIGATING":
        return .yellow
    case "MAJOROUTAGE", "MAJOR_OUTAGE":
        return .red
    default:
        return .secondary
    }
}

func readableStatus(_ status: String) -> String {
    let replacements = [
        "UP": "Up",
        "OPERATIONAL": "Operational",
        "UNDERMAINTENANCE": "Under maintenance",
        "DEGRADEDPERFORMANCE": "Degraded performance",
        "DEGRADED_PERFORMANCE": "Degraded performance",
        "PARTIALOUTAGE": "Partial outage",
        "PARTIAL_OUTAGE": "Partial outage",
        "MAJOROUTAGE": "Major outage",
        "MAJOR_OUTAGE": "Major outage",
        "INVESTIGATING": "Investigating",
        "IDENTIFIED": "Identified",
        "MONITORING": "Monitoring",
        "RESOLVED": "Resolved",
        "NOTSTARTEDYET": "Not started yet",
        "COMPLETED": "Completed"
    ]
    if let replacement = replacements[status.uppercased()] {
        return replacement
    }

    let words = status
        .replacingOccurrences(of: "_", with: " ")
        .split(separator: " ")
        .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
    return words.joined(separator: " ")
}

struct StatusAPI {
    private let base = URL(string: "https://status.olilo.co.uk")!

    struct ComponentsResponse: Decodable {
        let components: [StatusComponent]
    }

    func fetchSummary() async throws -> StatusPageSummary {
        let url = base.appending(path: "v3/summary.json")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StatusPageSummary.self, from: data)
    }

    func fetchComponents() async throws -> [StatusComponent] {
        let url = base.appending(path: "v3/components.json")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        let result = try decoder.decode(ComponentsResponse.self, from: data)
        return result.components
    }
}

#Preview {
    StatusView()
}
