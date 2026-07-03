import SwiftUI
import Combine
import Charts
import UIKit

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

    /// Returns whether the incident text clearly references a component name.
    func references(component: StatusComponent) -> Bool {
        [name, description]
            .compactMap { $0 }
            .contains { text in
                text.referencesComponentName(component.name)
            }
    }
}

private extension String {
    /// Matches multi-word component names as phrases and short names as whole tokens.
    func referencesComponentName(_ componentName: String) -> Bool {
        let normalizedName = componentName.lowercased()
        let normalizedText = lowercased()
        guard !normalizedName.isEmpty else { return false }

        if normalizedName.contains(" ") {
            return normalizedText.contains(normalizedName)
        }

        return normalizedText
            .split { !$0.isLetter && !$0.isNumber }
            .contains { $0 == normalizedName }
    }
}

struct Maintenance: Identifiable, Decodable {
    let id: String
    let name: String
    let status: String
    let start: Date?
    let duration: Int?
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

    /// Selects the components that belong in this category, preserving the configured parent-child order.
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

    /// Appends a component once while tracking IDs already included in the category.
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

    /// Loads saved component display preferences, falling back to defaults when unavailable.
    static func load() -> StatusComponentDisplayPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return StatusComponentDisplayPreferences()
        }
        return (try? JSONDecoder().decode(StatusComponentDisplayPreferences.self, from: data)) ?? StatusComponentDisplayPreferences()
    }

    /// Persists component display preferences in user defaults.
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    /// Applies the saved component order while keeping any new components at the end.
    func orderedComponents(from components: [StatusComponent]) -> [StatusComponent] {
        let componentsByID = Dictionary(uniqueKeysWithValues: components.map { ($0.id, $0) })
        var ordered = orderedComponentIDs.compactMap { componentsByID[$0] }
        let orderedIDs = Set(ordered.map(\.id))
        ordered.append(contentsOf: components.filter { !orderedIDs.contains($0.id) })
        return ordered
    }

    /// Filters groups down to visible components and drops empty groups.
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

    /// Returns whether the component is currently shown in the status UI.
    func isComponentVisible(_ component: StatusComponent) -> Bool {
        !hiddenComponentIDs.contains(component.id)
    }

    /// Updates the hidden component set for a single component.
    mutating func setComponent(_ component: StatusComponent, isVisible: Bool) {
        if isVisible {
            hiddenComponentIDs.remove(component.id)
        } else {
            hiddenComponentIDs.insert(component.id)
        }
    }

    /// Stores a drag-reordered component sequence for the specified group.
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

    /// Returns component groups after applying the user's display preferences.
    func visibleComponentGroups(using preferences: StatusComponentDisplayPreferences) -> [StatusComponentGroup] {
        preferences.visibleGroups(from: componentGroups)
    }

    /// Returns affected components after applying the user's component visibility and order preferences.
    func visibleAffectedComponents(using preferences: StatusComponentDisplayPreferences) -> [StatusComponent] {
        preferences.orderedComponents(from: components)
            .filter { statusSeverity($0.status) > 0 }
            .filter { component in
                !preferences.hiddenComponentIDs.contains(component.id)
            }
    }

    /// Returns the highest-severity status among components still shown by the user.
    func visibleStatus(using preferences: StatusComponentDisplayPreferences) -> String {
        let visibleComponents = components.filter { !preferences.hiddenComponentIDs.contains($0.id) }
        return visibleComponents.map(\.status).sorted(by: statusSeveritySort).last ?? "OPERATIONAL"
    }

    /// Returns active incidents that still apply to the user's visible component configuration.
    func visibleIncidents(using preferences: StatusComponentDisplayPreferences) -> [Incident] {
        let visibleComponents = components.filter { !preferences.hiddenComponentIDs.contains($0.id) }
        let hiddenComponents = components.filter { preferences.hiddenComponentIDs.contains($0.id) }

        return incidents.filter { incident in
            let matchesVisibleComponent = visibleComponents.contains { incident.references(component: $0) }
            let matchesHiddenComponent = hiddenComponents.contains { incident.references(component: $0) }
            return matchesVisibleComponent || !matchesHiddenComponent
        }
    }

    private let api = StatusAPI()

    /// Refreshes summary and component data, updating published state for the status screen.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let summary = try await api.fetchSummary()
            let components = try await api.fetchComponents()

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

private struct StatusWebDestination: Identifiable {
    let title: String
    let url: URL

    var id: URL { url }
}

struct StatusView: View {
    @StateObject private var model = StatusViewModel()
    @State private var presentedWebDestination: StatusWebDestination?
    @State private var isComponentEditorPresented = false
    @State private var componentDisplayPreferences = StatusComponentDisplayPreferences.load()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let dashboardURL = URL(string: "https://dashboard.as212683.net/d/olilo-traffic-analytics-001/traffic-analytics?orgId=2&from=now-1h&to=now&timezone=browser")
    private let portalURL = URL(string: "https://billing.olilo.co.uk")
    private let terminalURL = URL(string: "https://terminal.olilo.co.uk")
    private let wikiURL = URL(string: "https://olilo.co.uk/wiki")

    private var usesIPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

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
                    let visibleIncidents = model.visibleIncidents(using: componentDisplayPreferences)
                    let visibleComponentCount = visibleComponentGroups.reduce(0) { $0 + $1.allComponents.count }
                    let visibleStatus = model.visibleStatus(using: componentDisplayPreferences)

                    ScrollView {
                        LazyVStack(spacing: 18) {
                            if let summary = model.summary {
                                OverviewCard(
                                    summary: summary,
                                    displayStatus: visibleStatus,
                                    componentCount: visibleComponentCount,
                                    affectedCount: visibleAffectedComponents.count,
                                    incidentCount: visibleIncidents.count,
                                    maintenanceCount: model.maintenances.count,
                                    lastRefreshed: model.lastRefreshed
                                )
                                .padding(.horizontal)

                                StatusLinksCard(
                                    usesIPadLayout: usesIPadLayout,
                                    isTerminalEnabled: terminalURL != nil,
                                    isWikiEnabled: wikiURL != nil,
                                    dashboardAction: { presentWebDestination(title: "Dashboard", url: dashboardURL) },
                                    portalAction: { presentWebDestination(title: "Portal", url: portalURL) },
                                    terminalAction: { presentWebDestination(title: "Terminal", url: terminalURL) },
                                    wikiAction: { presentWebDestination(title: "Wiki", url: wikiURL) }
                                )
                                .padding(.horizontal)

                                if !visibleAffectedComponents.isEmpty {
                                    StatusSectionHeader(title: "Affected Services", count: visibleAffectedComponents.count)
                                    AffectedServicesCard(components: visibleAffectedComponents)
                                        .padding(.horizontal)
                                }
                            }

                            if !visibleIncidents.isEmpty {
                                StatusSectionHeader(title: "Active Incidents", count: visibleIncidents.count)
                                ForEach(visibleIncidents) { incident in
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
            .modifier(
                StatusWebDestinationPresenter(
                    destination: $presentedWebDestination,
                    usesIPadLayout: usesIPadLayout
                )
            )
            .sheet(isPresented: $isComponentEditorPresented) {
                ComponentDisplayEditor(
                    groups: model.componentGroups,
                    preferences: $componentDisplayPreferences
                )
            }
        }
    }

    private func presentWebDestination(title: String, url: URL?) {
        guard let url else { return }
        presentedWebDestination = StatusWebDestination(title: title, url: url)
    }
}

private struct StatusWebDestinationPresenter: ViewModifier {
    @Binding var destination: StatusWebDestination?
    let usesIPadLayout: Bool

    func body(content: Content) -> some View {
        if usesIPadLayout {
            content.fullScreenCover(item: $destination) { destination in
                OliloWebViewSheet(title: destination.title, url: destination.url)
                    .ignoresSafeArea(edges: .bottom)
            }
        } else {
            content.sheet(item: $destination) { destination in
                OliloWebViewSheet(title: destination.title, url: destination.url)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
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

    /// Creates a binding for the component visibility toggle in the editor.
    private func visibilityBinding(for component: StatusComponent) -> Binding<Bool> {
        Binding {
            preferences.isComponentVisible(component)
        } set: { isVisible in
            preferences.setComponent(component, isVisible: isVisible)
        }
    }

    /// Builds the secondary detail line for a component in the editor.
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
    let usesIPadLayout: Bool
    let isTerminalEnabled: Bool
    let isWikiEnabled: Bool
    let dashboardAction: () -> Void
    let portalAction: () -> Void
    let terminalAction: () -> Void
    let wikiAction: () -> Void

    private var columns: [GridItem] {
        if usesIPadLayout {
            Array(repeating: GridItem(.flexible(minimum: 150), spacing: 12), count: 4)
        } else {
            [GridItem(.adaptive(minimum: 140), spacing: 10)]
        }
    }

    var body: some View {
        StatusCard {
            LazyVGrid(columns: columns, spacing: usesIPadLayout ? 12 : 10) {
                StatusLinkButton(
                    title: "Dashboard",
                    systemImage: "chart.line.uptrend.xyaxis",
                    usesIPadLayout: usesIPadLayout,
                    action: dashboardAction
                )
                StatusLinkButton(
                    title: "Portal",
                    systemImage: "person.crop.circle",
                    usesIPadLayout: usesIPadLayout,
                    action: portalAction
                )
                StatusLinkButton(
                    title: "Terminal",
                    systemImage: "terminal",
                    usesIPadLayout: usesIPadLayout,
                    isEnabled: isTerminalEnabled,
                    action: terminalAction
                )
                StatusLinkButton(
                    title: "Wiki",
                    systemImage: "book.closed",
                    usesIPadLayout: usesIPadLayout,
                    isEnabled: isWikiEnabled,
                    action: wikiAction
                )
            }
        }
    }
}

private struct StatusLinkButton: View {
    let title: String
    let systemImage: String
    let usesIPadLayout: Bool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } icon: {
                Image(systemName: systemImage)
                    .font(usesIPadLayout ? .title3.weight(.semibold) : .caption.weight(.semibold))
            }
            .font(usesIPadLayout ? .callout.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: usesIPadLayout ? 52 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(usesIPadLayout ? .large : .regular)
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
    let displayStatus: String
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
                    PulsingStatusIcon(status: displayStatus)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Olilo Network Status")
                            .font(.title2.weight(.bold))
                        Text(statusSeverity(displayStatus) == 0 ? "All systems operational" : readableStatus(displayStatus))
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

    /// Restarts the pulse animation unless the user has reduced motion enabled.
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

    /// Captures the caller's content for rendering inside the shared card style.
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

/// Maps backend status strings to numeric severity for sorting and summaries.
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

/// Sorts status strings from least to most severe.
func statusSeveritySort(_ lhs: String, _ rhs: String) -> Bool {
    statusSeverity(lhs) < statusSeverity(rhs)
}

/// Chooses the display color associated with a backend status string.
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

/// Converts backend status identifiers into readable user-facing text.
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

    /// Downloads and decodes the status page summary payload.
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

    /// Downloads and decodes the full component list from the status API.
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
