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

enum StatusComponentCategory: String, CaseIterable {
    case network
    case website
    case connections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network: return "Network"
        case .website: return "Website"
        case .connections: return "Connections"
        }
    }

    private var componentNames: [String] {
        switch self {
        case .network:
            return ["Openreach", "Freedom Fibre", "CityFibre", "MS3", "Telehouse North"]
        case .website:
            return ["Prosumer Website", "Consumer Website", "Terminal", "API"]
        case .connections:
            return ["3rd Party"]
        }
    }

    func components(from components: [StatusComponent]) -> [StatusComponent] {
        var includedIDs = Set<String>()
        var result: [StatusComponent] = []

        for componentName in componentNames {
            guard let parent = components.first(where: { $0.name.localizedCaseInsensitiveCompare(componentName) == .orderedSame }) else {
                continue
            }
            append(parent, to: &result, includedIDs: &includedIDs)

            let children = components.filter { child in
                child.group?.id == parent.id || child.group?.name.localizedCaseInsensitiveCompare(parent.name) == .orderedSame
            }.sorted { $0.name < $1.name }
            for child in children {
                append(child, to: &result, includedIDs: &includedIDs)
            }
        }

        return result
    }

    private func append(_ component: StatusComponent, to result: inout [StatusComponent], includedIDs: inout Set<String>) {
        guard includedIDs.insert(component.id).inserted else { return }
        result.append(component)
    }
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

struct StatusComponentDisplayPreferences: Codable, Equatable {
    var hiddenComponentIDs: Set<String> = []
    var orderedComponentIDs: [String] = []

    static let storageKey = "statusComponentDisplayPreferences"

    static func load() -> StatusComponentDisplayPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return StatusComponentDisplayPreferences()
        }
        return (try? JSONDecoder().decode(StatusComponentDisplayPreferences.self, from: data)) ?? StatusComponentDisplayPreferences()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func orderedComponents(from components: [StatusComponent]) -> [StatusComponent] {
        let componentsByID = Dictionary(uniqueKeysWithValues: components.map { ($0.id, $0) })
        var ordered = orderedComponentIDs.compactMap { componentsByID[$0] }
        let orderedIDs = Set(ordered.map(\.id))
        ordered.append(contentsOf: components.filter { !orderedIDs.contains($0.id) })
        return ordered
    }

    func visibleGroups(from groups: [StatusComponentGroup]) -> [StatusComponentGroup] {
        groups.compactMap { group in
            let visibleComponents = orderedComponents(from: group.allComponents).filter { !hiddenComponentIDs.contains($0.id) }
            guard !visibleComponents.isEmpty else { return nil }
            return StatusComponentGroup(
                id: group.id,
                name: group.name,
                description: group.description,
                parent: nil,
                children: visibleComponents
            )
        }
    }

    func isComponentVisible(_ component: StatusComponent) -> Bool {
        !hiddenComponentIDs.contains(component.id)
    }

    mutating func setComponent(_ component: StatusComponent, isVisible: Bool) {
        if isVisible {
            hiddenComponentIDs.remove(component.id)
        } else {
            hiddenComponentIDs.insert(component.id)
        }
    }

    mutating func moveComponents(from source: IndexSet, to destination: Int, in group: StatusComponentGroup) {
        let groupComponentIDs = Set(group.allComponents.map(\.id))
        var orderedIDs = orderedComponents(from: group.allComponents).map(\.id)
        orderedIDs.move(fromOffsets: source, toOffset: destination)
        orderedComponentIDs.removeAll { groupComponentIDs.contains($0) }
        orderedComponentIDs.append(contentsOf: orderedIDs)
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
        StatusComponentCategory.allCases.compactMap { category in
            let children = category.components(from: components)
            guard !children.isEmpty else { return nil }
            return StatusComponentGroup(
                id: category.id,
                name: category.title,
                description: nil,
                parent: nil,
                children: children
            )
        }
    }

    func visibleComponentGroups(using preferences: StatusComponentDisplayPreferences) -> [StatusComponentGroup] {
        preferences.visibleGroups(from: componentGroups)
    }

    func visibleAffectedComponents(using preferences: StatusComponentDisplayPreferences) -> [StatusComponent] {
        affectedComponents.filter { component in
            !preferences.hiddenComponentIDs.contains(component.id)
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
    @State private var isPortalPresented = false
    @State private var isTerminalPresented = false
    @State private var isWikiPresented = false
    @State private var isComponentEditorPresented = false
    @State private var componentDisplayPreferences = StatusComponentDisplayPreferences.load()

    private let dashboardURL = URL(string: "https://dashboard.as212683.net/d/olilo-traffic-analytics-001/traffic-analytics?orgId=2&from=now-1h&to=now&timezone=browser")
    private let portalURL = URL(string: "https://portal.olilo.co.uk")
    private let terminalURL = URL(string: "https://terminal.olilo.co.uk")
    private let wikiURL = URL(string: "https://olilo.co.uk/wiki")

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
                            .accessibilityHidden(true)
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
                    let visibleComponentGroups = model.visibleComponentGroups(using: componentDisplayPreferences)
                    let visibleAffectedComponents = model.visibleAffectedComponents(using: componentDisplayPreferences)
                    let visibleComponentCount = visibleComponentGroups.reduce(0) { $0 + $1.allComponents.count }

                    ScrollView {
                        LazyVStack(spacing: 18) {
                            if let summary = model.summary {
                                OverviewCard(
                                    summary: summary,
                                    componentCount: visibleComponentCount,
                                    affectedCount: visibleAffectedComponents.count,
                                    incidentCount: model.incidents.count,
                                    maintenanceCount: model.maintenances.count,
                                    lastRefreshed: model.lastRefreshed
                                )
                                .padding(.horizontal)

                                StatusLinksCard(
                                    isTerminalEnabled: terminalURL != nil,
                                    isWikiEnabled: wikiURL != nil,
                                    dashboardAction: { isDashboardPresented = true },
                                    portalAction: { isPortalPresented = true },
                                    terminalAction: { isTerminalPresented = true },
                                    wikiAction: { isWikiPresented = true }
                                )
                                .padding(.horizontal)

                                if !visibleAffectedComponents.isEmpty {
                                    StatusSectionHeader(title: "Affected Services", count: visibleAffectedComponents.count)
                                    AffectedServicesCard(components: visibleAffectedComponents)
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

                            if visibleComponentGroups.isEmpty {
                                StatusSectionHeader(
                                    title: "Components",
                                    count: visibleComponentCount
                                )
                                EmptyComponentsCard()
                                    .padding(.horizontal)
                            } else {
                                ForEach(visibleComponentGroups) { group in
                                    if group.id == StatusComponentCategory.network.id {
                                        StatusSectionHeader(
                                            title: group.name,
                                            count: group.allComponents.count
                                        )
                                    } else {
                                        StatusSectionHeader(title: group.name, count: group.allComponents.count)
                                    }
                                    ComponentCategoryCard(components: group.allComponents)
                                        .padding(.horizontal)
                                }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isComponentEditorPresented = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(Color.oliloPurple)
                    }
                    .tint(Color.oliloPurple)
                    .accessibilityLabel("Edit status components")
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
            .onChange(of: componentDisplayPreferences) { _, preferences in
                preferences.save()
            }
            .background(OliloDarkGradientBackground())
            .sheet(isPresented: $isDashboardPresented) {
                if let dashboardURL {
                    OliloWebViewSheet(title: "Dashboard", url: dashboardURL)
                }
            }
            .sheet(isPresented: $isPortalPresented) {
                if let portalURL {
                    OliloWebViewSheet(title: "Portal", url: portalURL)
                }
            }
            .sheet(isPresented: $isTerminalPresented) {
                if let terminalURL {
                    OliloWebViewSheet(title: "Terminal", url: terminalURL)
                }
            }
            .sheet(isPresented: $isWikiPresented) {
                if let wikiURL {
                    OliloWebViewSheet(title: "Wiki", url: wikiURL)
                }
            }
            .sheet(isPresented: $isComponentEditorPresented) {
                ComponentDisplayEditor(
                    groups: model.componentGroups,
                    preferences: $componentDisplayPreferences
                )
            }
        }
    }
}

private struct ComponentDisplayEditor: View {
    let groups: [StatusComponentGroup]
    @Binding var preferences: StatusComponentDisplayPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    let orderedComponents = preferences.orderedComponents(from: group.allComponents)
                    Section {
                        ForEach(orderedComponents) { component in
                            Toggle(isOn: visibilityBinding(for: component)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(component.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.white)
                                    Text(componentDetail(for: component))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(Color.oliloPurple)
                        }
                        .onMove { source, destination in
                            preferences.moveComponents(from: source, to: destination, in: group)
                        }
                    } header: {
                        Text(group.name)
                    }
                }
            }
            .navigationTitle("Components")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditButton()
                        .tint(Color.oliloPurple)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Show All") {
                        preferences.hiddenComponentIDs.removeAll()
                    }
                    .disabled(preferences.hiddenComponentIDs.isEmpty)
                    .tint(Color.oliloPurple)
                }
            }
            .scrollContentBackground(.hidden)
            .background(OliloDarkGradientBackground())
        }
        .tint(Color.oliloPurple)
    }

    private func visibilityBinding(for component: StatusComponent) -> Binding<Bool> {
        Binding {
            preferences.isComponentVisible(component)
        } set: { isVisible in
            preferences.setComponent(component, isVisible: isVisible)
        }
    }

    private func componentDetail(for component: StatusComponent) -> String {
        var details = [readableStatus(component.status)]
        if let groupName = component.group?.name, !groupName.isEmpty {
            details.append(groupName)
        }
        if let description = component.description, !description.isEmpty {
            details.append(description)
        }
        return details.joined(separator: " - ")
    }
}

private struct EmptyComponentsCard: View {
    var body: some View {
        StatusCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "eye.slash")
                    .font(.title2)
                    .foregroundStyle(Color.oliloPurple)
                Text("No components shown")
                    .font(.headline)
                Text("Use the component editor to show services on this page.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StatusLinksCard: View {
    let isTerminalEnabled: Bool
    let isWikiEnabled: Bool
    let dashboardAction: () -> Void
    let portalAction: () -> Void
    let terminalAction: () -> Void
    let wikiAction: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 10)]

    var body: some View {
        StatusCard {
            LazyVGrid(columns: columns, spacing: 10) {
                StatusLinkButton(title: "Dashboard", systemImage: "chart.line.uptrend.xyaxis", action: dashboardAction)
                StatusLinkButton(title: "Portal", systemImage: "person.crop.circle", action: portalAction)
                StatusLinkButton(title: "Terminal", systemImage: "terminal", isEnabled: isTerminalEnabled, action: terminalAction)
                StatusLinkButton(title: "Wiki", systemImage: "book.closed", isEnabled: isWikiEnabled, action: wikiAction)
            }
        }
    }
}

private struct StatusLinkButton: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Color.oliloPurple)
        .disabled(!isEnabled)
        .accessibilityHint("Opens \(title)")
    }
}

private struct StatusSectionHeader: View {
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
                    PulsingStatusIcon(status: summary.page.status)
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
                    .accessibilityLabel("Open Olilo Status page")
                    .accessibilityHint("Opens the public status page")
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

// Animated StatusSeverity icon.
// Pulses by default but respects users set accessibility settings.
// Disabled if reduceMotion is enabled and reverted to a static state.

private struct PulsingStatusIcon: View {
    let status: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private var color: Color { statusColor(status) }
    private var systemImage: String {
        statusSeverity(status) == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
    }

    var body: some View {
        ZStack {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(color)
                .opacity(isPulsing && !reduceMotion ? 0.18 : 0)
                .scaleEffect(isPulsing && !reduceMotion ? 1.45 : 1)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulsing)

            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.25), radius: 5)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
        .onAppear(perform: startPulse)
        .onChange(of: status) { _, _ in
            startPulse()
        }
    }

    private func startPulse() {
        guard !reduceMotion else {
            isPulsing = false
            return
        }

        isPulsing = false
        DispatchQueue.main.async {
            isPulsing = true
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

private struct ComponentCategoryCard: View {
    let components: [StatusComponent]

    var body: some View {
        StatusCard {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(components) { component in
                    ComponentRow(component: component, showGroup: false)
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

    @State private var isExpanded = false

    private var hasExpandableDetails: Bool {
        group.children.isEmpty == false || group.description?.isEmpty == false
    }

    var body: some View {
        StatusCard {
            if hasExpandableDetails {
                DisclosureGroup(isExpanded: $isExpanded) {
                    ComponentGroupDetails(group: group)
                        .padding(.top, 12)
                } label: {
                    ComponentGroupHeader(group: group)
                }
                .tint(Color.oliloPurple)
            } else {
                ComponentGroupHeader(group: group)
            }
        }
    }
}

private struct ComponentGroupHeader: View {
    let group: StatusComponentGroup

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StatusDot(status: group.worstStatus)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(readableStatus(group.worstStatus))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(text: readableStatus(group.worstStatus), status: group.worstStatus)
        }
    }
}

private struct ComponentGroupDetails: View {
    let group: StatusComponentGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let description = group.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(group.children) { component in
                ComponentRow(component: component, showGroup: false)
            }
        }
    }
}

private struct ComponentRow: View {
    let component: StatusComponent
    let showGroup: Bool

    private var accessibilitySummary: String {
        var details = [readableStatus(component.status)]
        if showGroup, let group = component.group {
            details.append(group.name)
        }
        if let description = component.description, !description.isEmpty {
            details.append(description)
        }
        return details.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(status: component.status, size: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(component.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(component.name)
        .accessibilityValue(accessibilitySummary)
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
            .accessibilityHidden(true)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
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
    case "HASISSUES", "HAS_ISSUES", "DEGRADEDPERFORMANCE", "DEGRADED_PERFORMANCE", "IDENTIFIED":
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
        return .oliloPurple
    case "UNDERMAINTENANCE", "MONITORING", "NOTSTARTEDYET":
        return .blue
    case "HASISSUES", "HAS_ISSUES", "DEGRADEDPERFORMANCE", "DEGRADED_PERFORMANCE", "IDENTIFIED":
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
        "HASISSUES": "Has issues",
        "HAS_ISSUES": "Has issues",
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
