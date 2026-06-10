import AppIntents
import Foundation
import SwiftUI
import WidgetKit

enum WidgetStatusSource: String, AppEnum {
    case openreach
    case cityFibre
    case freedomFibre

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Status Source"
    static var caseDisplayRepresentations: [WidgetStatusSource: DisplayRepresentation] = [
        .openreach: "Openreach",
        .cityFibre: "CityFibre",
        .freedomFibre: "Freedom Fibre"
    ]

    var displayName: String {
        switch self {
        case .openreach: return "Openreach"
        case .cityFibre: return "CityFibre"
        case .freedomFibre: return "Freedom Fibre"
        }
    }

    var componentName: String { displayName }
}

struct OliloStatusWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Status Source"
    static var description = IntentDescription("Choose which network source the widget uses.")

    @Parameter(title: "Source", default: .openreach)
    var source: WidgetStatusSource
}

struct OliloStatusEntry: TimelineEntry {
    let date: Date
    let source: WidgetStatusSource
    let status: String

    var isOnline: Bool {
        let normalizedStatus = status.uppercased()
        return normalizedStatus == "UP" || normalizedStatus == "OPERATIONAL"
    }
}

struct OliloStatusProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OliloStatusEntry {
        OliloStatusEntry(date: .now, source: .openreach, status: "OPERATIONAL")
    }

    func snapshot(for configuration: OliloStatusWidgetConfiguration, in context: Context) async -> OliloStatusEntry {
        OliloStatusEntry(date: .now, source: configuration.source, status: "OPERATIONAL")
    }

    func timeline(for configuration: OliloStatusWidgetConfiguration, in context: Context) async -> Timeline<OliloStatusEntry> {
        let status = await fetchNetworkStatus(for: configuration.source)
        let entry = OliloStatusEntry(date: .now, source: configuration.source, status: status)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func fetchNetworkStatus(for source: WidgetStatusSource) async -> String {
        guard let url = URL(string: "https://status.olilo.co.uk/v3/components.json") else {
            return "UNKNOWN"
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                return "UNKNOWN"
            }
            let result = try JSONDecoder().decode(OliloWidgetComponentsResponse.self, from: data)
            return result.components.first { $0.name == source.componentName }?.status ?? "UNKNOWN"
        } catch {
            return "UNKNOWN"
        }
    }
}

private struct OliloWidgetComponentsResponse: Decodable {
    let components: [OliloWidgetComponent]
}

private struct OliloWidgetComponent: Decodable {
    let name: String
    let status: String
}

struct OliloStatusWidgetView: View {
    let entry: OliloStatusEntry

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.colorScheme) private var colorScheme

    private var statusText: String {
        entry.isOnline ? "Online" : "Offline"
    }

    private var statusColor: Color {
        entry.isOnline ? .green : .red
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var titleColor: Color {
        widgetRenderingMode == .fullColor ? (isDarkMode ? .white : .black) : .primary
    }

    private var secondaryColor: Color {
        widgetRenderingMode == .fullColor ? (isDarkMode ? .white.opacity(0.7) : .gray) : .secondary
    }

    private var timelineColor: Color {
        widgetRenderingMode == .fullColor ? statusColor : .primary
    }

    private var backgroundColor: Color {
        isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.10) : .white
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Olilo Status")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(timelineColor)
                            .frame(width: 10, height: 10)
                            .widgetAccentable()
                        Text(statusText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(secondaryColor)
                    }
                }
                Spacer(minLength: 12)
                Text(entry.source.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: 110, alignment: .trailing)
            }

            Spacer(minLength: 16)

            Capsule()
                .fill(timelineColor)
                .frame(height: 10)
                .widgetAccentable()

            HStack {
                Text("-24 h")
                Spacer()
                Text("Now")
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(secondaryColor)
            .padding(.top, 8)

            Spacer(minLength: 10)

            Image("OliloWidget")
                .resizable()
                .scaledToFit()
                .frame(height: 24)
                .colorInvertIfNeeded(isDarkMode)
                .opacity(widgetRenderingMode == .fullColor ? 1 : 0.9)
        }
        .padding(20)
        .containerBackground(for: .widget) {
            backgroundColor
        }
    }
}

private extension View {
    @ViewBuilder
    func colorInvertIfNeeded(_ shouldInvert: Bool) -> some View {
        if shouldInvert {
            colorInvert()
        } else {
            self
        }
    }
}

struct OliloStatusWidget: Widget {
    let kind = "OliloStatusWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: OliloStatusWidgetConfiguration.self, provider: OliloStatusProvider()) { entry in
            OliloStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Olilo Status")
        .description("Shows whether the selected Olilo network source is online.")
        .supportedFamilies([.systemMedium])
    }
}
