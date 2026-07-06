import Combine
import IperfSwift
import SwiftUI
import UIKit

private enum SpeedtestMode: String, CaseIterable, Identifiable {
    case upload = "Upload"
    case download = "Download"
    case multiUpload = "Multi-Stream Upload"
    case multiDownload = "Multi-Stream Download"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .upload: return "arrow.up.circle"
        case .download: return "arrow.down.circle"
        case .multiUpload: return "arrow.up.arrow.down.circle"
        case .multiDownload: return "arrow.up.arrow.down.circle"
        }
    }

    var isReverse: Bool {
        self == .download || self == .multiDownload
    }

    var usesMultipleStreams: Bool {
        self == .multiUpload || self == .multiDownload
    }
}

@MainActor
private final class SpeedtestViewModel: ObservableObject {
    @Published var runnerState: IperfRunnerState = .ready
    @Published var currentResult: IperfIntervalResult?
    @Published var results: [IperfIntervalResult] = []
    @Published var errorMessage: String?

    private var runner: IperfRunner?

    var isRunning: Bool {
        runnerState == .initialising || runnerState == .running || runnerState == .stopping
    }

    var stateLabel: String {
        switch runnerState {
        case .unknown: return "Unknown"
        case .ready: return "Ready"
        case .initialising: return "Starting"
        case .running: return "Running"
        case .error: return "Error"
        case .stopping: return "Stopping"
        case .finished: return "Finished"
        }
    }

    func start(server: String, port: Int, duration: Int, streams: Int, mode: SpeedtestMode) {
        stop()
        errorMessage = nil
        currentResult = nil
        results = []

        var configuration = IperfConfiguration()
        configuration.address = server
        configuration.role = .client
        configuration.port = port
        configuration.prot = .tcp
        configuration.reverse = mode.isReverse ? .download : .upload
        configuration.numStreams = mode.usesMultipleStreams ? streams : 1
        configuration.duration = TimeInterval(duration)
        configuration.timeout = 5
        configuration.reporterInterval = 1
        configuration.statsInterval = 1

        let runner = IperfRunner(with: configuration)
        self.runner = runner
        runner.start(
            { [weak self] result in
                Task { @MainActor in
                    self?.currentResult = result
                    self?.results.append(result)
                }
            },
            { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.debugDescription
                    self?.runnerState = .error
                }
            },
            { [weak self] state in
                Task { @MainActor in
                    self?.runnerState = state
                    if state == .finished || state == .error {
                        self?.runner = nil
                    }
                }
            }
        )
    }

    func stop() {
        runner?.stop()
        runner = nil
    }
}

struct SpeedtestView: View {
    @StateObject private var model = SpeedtestViewModel()
    @AppStorage("speedtestRunTimestamps") private var speedtestRunTimestamps = ""
    @State private var selectedMode: SpeedtestMode = .download
    @State private var selectedPort = 5201
    @State private var selectedStreams = 8
    @State private var selectedDuration = 10

    private let server = "speedtest.as212683.net"
    private let ports = Array(5201...5210)
    private let streamOptions = [1, 8, 16, 32]
    private let durationOptions = [5, 10]
    private let maxRunsPerHour = 3
    private let rateLimitWindow: TimeInterval = 60 * 60

    private var rateLimitMessage: String? {
        let recentRuns = recentSpeedtestRuns()
        guard recentRuns.count >= maxRunsPerHour, let oldestRun = recentRuns.first else { return nil }
        let nextRunDate = oldestRun.addingTimeInterval(rateLimitWindow)
        let minutesRemaining = max(1, Int(ceil(nextRunDate.timeIntervalSinceNow / 60)))
        return "Speedtest limit reached. You can run 3 tests per hour. Try again in \(minutesRemaining) min."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    SpeedtestIntroCard()
                        .padding(.horizontal)

                    SpeedtestRunnerCard(
                        stateLabel: model.stateLabel,
                        isRunning: model.isRunning,
                        latestResult: model.currentResult,
                        errorMessage: model.errorMessage,
                        rateLimitMessage: rateLimitMessage,
                        canStart: rateLimitMessage == nil,
                        startAction: {
                            guard recordSpeedtestRun() else { return }
                            model.start(
                                server: server,
                                port: selectedPort,
                                duration: selectedDuration,
                                streams: selectedStreams,
                                mode: selectedMode
                            )
                        },
                        stopAction: model.stop
                    )
                    .padding(.horizontal)

                    SpeedtestConfigurationCard(
                        selectedMode: $selectedMode,
                        selectedPort: $selectedPort,
                        selectedStreams: $selectedStreams,
                        selectedDuration: $selectedDuration,
                        isRunning: model.isRunning,
                        ports: ports,
                        streamOptions: streamOptions,
                        durationOptions: durationOptions
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical, 18)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Speedtest")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    OliloToolbarLogo()
                }
            }
            .background(OliloDarkGradientBackground())
        }
    }

    private func recordSpeedtestRun() -> Bool {
        var recentRuns = recentSpeedtestRuns()
        guard recentRuns.count < maxRunsPerHour else { return false }
        recentRuns.append(Date())
        speedtestRunTimestamps = recentRuns
            .map { String($0.timeIntervalSince1970) }
            .joined(separator: ",")
        return true
    }

    private func recentSpeedtestRuns() -> [Date] {
        let cutoff = Date().addingTimeInterval(-rateLimitWindow)
        return speedtestRunTimestamps
            .split(separator: ",")
            .compactMap { TimeInterval($0) }
            .map(Date.init(timeIntervalSince1970:))
            .filter { $0 > cutoff }
            .sorted()
    }
}

private struct SpeedtestIntroCard: View {
    var body: some View {
        SpeedtestCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Olilo Public Speed Test", systemImage: "speedometer")
                    .font(.title3.weight(.bold))
                Text("Test directly against the Olilo network. Please use responsibly, abuse will result in the speedtest being removed from Olilo Status.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SpeedtestConfigurationCard: View {
    @Binding var selectedMode: SpeedtestMode
    @Binding var selectedPort: Int
    @Binding var selectedStreams: Int
    @Binding var selectedDuration: Int
    let isRunning: Bool
    let ports: [Int]
    let streamOptions: [Int]
    let durationOptions: [Int]

    var body: some View {
        SpeedtestCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Speedtest Configuration")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Test Type")
                        .font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                        ForEach(SpeedtestMode.allCases) { mode in
                            SpeedtestModeButton(
                                mode: mode,
                                isSelected: selectedMode == mode,
                                isEnabled: !isRunning
                            ) {
                                selectedMode = mode
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Available Ports")
                        .font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                        ForEach(ports, id: \.self) { port in
                            SpeedtestOptionButton(
                                title: "\(port)",
                                isSelected: selectedPort == port,
                                isEnabled: !isRunning
                            ) {
                                selectedPort = port
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Test Streams")
                        .font(.subheadline.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                        ForEach(streamOptions, id: \.self) { streams in
                            SpeedtestOptionButton(
                                title: "\(streams)",
                                isSelected: selectedStreams == streams,
                                isEnabled: selectedMode.usesMultipleStreams && !isRunning
                            ) {
                                selectedStreams = streams
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Test Duration")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 8) {
                        ForEach(durationOptions, id: \.self) { duration in
                            SpeedtestOptionButton(
                                title: "\(duration)s",
                                isSelected: selectedDuration == duration,
                                isEnabled: !isRunning
                            ) {
                                selectedDuration = duration
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct SpeedtestRunnerCard: View {
    let stateLabel: String
    let isRunning: Bool
    let latestResult: IperfIntervalResult?
    let errorMessage: String?
    let rateLimitMessage: String?
    let canStart: Bool
    let startAction: () -> Void
    let stopAction: () -> Void

    var body: some View {
        SpeedtestCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(stateLabel, systemImage: isRunning ? "dot.radiowaves.left.and.right" : "checkmark.circle")
                        .font(.headline)
                    Spacer()
                    if isRunning {
                        ProgressView()
                            .tint(Color.oliloTheme)
                    }
                }

                if let latestResult {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        SpeedtestMetricTile(title: "Throughput", value: formattedThroughput(latestResult.throughput))
                        SpeedtestMetricTile(title: "Transferred", value: formattedBytes(latestResult.totalBytes))
                        SpeedtestMetricTile(title: "Duration", value: String(format: "%.1fs", latestResult.duration))
                        SpeedtestMetricTile(title: "Streams", value: "\(latestResult.streams.count)")
                    }
                } else {
                    Text("Run a short test against the selected Olilo speedtest port. Avoid long duration tests on busy ports.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let rateLimitMessage, !isRunning {
                    Text(rateLimitMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Button {
                    isRunning ? stopAction() : startAction()
                } label: {
                    Label(isRunning ? "Stop Test" : "Run Test", systemImage: isRunning ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : Color.oliloTheme)
                .disabled(!isRunning && !canStart)
            }
        }
    }

    private func formattedThroughput(_ throughput: IperfThroughput) -> String {
        if throughput.Gbps >= 1 {
            return String(format: "%.2f Gb/s", throughput.Gbps)
        }
        return String(format: "%.1f Mb/s", throughput.Mbps)
    }

    private func formattedBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

private struct SpeedtestMetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SpeedtestCard<Content: View>: View {
    private let content: Content

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

private struct SpeedtestModeButton: View {
    let mode: SpeedtestMode
    let isSelected: Bool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(mode.rawValue, systemImage: mode.systemImage)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .tint(isSelected ? Color.oliloTheme : .secondary)
        .disabled(!isEnabled)
    }
}

private struct SpeedtestOptionButton: View {
    let title: String
    let isSelected: Bool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .tint(isSelected ? Color.oliloTheme : .secondary)
        .disabled(!isEnabled)
    }
}

#Preview {
    SpeedtestView()
}
