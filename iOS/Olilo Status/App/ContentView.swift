import Combine
import SwiftUI
import UIKit

enum OliloTheme: String, CaseIterable, Identifiable {
    case oliloPurple
    case oliloBlue
    case oliloRed
    case oliloGreen
    case oliloOrange
    case oliloPink

    static let storageKey = "selectedOliloTheme"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oliloPurple: return "Purple"
        case .oliloBlue: return "Blue"
        case .oliloRed: return "Red"
        case .oliloGreen: return "Green"
        case .oliloOrange: return "Orange"
        case .oliloPink: return "Pink"
        }
    }

    var accentColor: Color {
        switch self {
        case .oliloPurple: return .oliloPurple
        case .oliloBlue: return .oliloBlue
        case .oliloRed: return .oliloRed
        case .oliloGreen: return .oliloGreen
        case .oliloOrange: return .oliloOrange
        case .oliloPink: return .oliloPink
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .oliloPurple:
            return [.black, Color(red: 0.13, green: 0.04, blue: 0.24), Color(red: 0.30, green: 0.08, blue: 0.48)]
        case .oliloBlue:
            return [.black, Color(red: 0.03, green: 0.09, blue: 0.25), Color(red: 0.05, green: 0.22, blue: 0.48)]
        case .oliloRed:
            return [.black, Color(red: 0.22, green: 0.03, blue: 0.06), Color(red: 0.48, green: 0.08, blue: 0.12)]
        case .oliloGreen:
            return [.black, Color(red: 0.03, green: 0.16, blue: 0.10), Color(red: 0.04, green: 0.34, blue: 0.20)]
        case .oliloOrange:
            return [.black, Color(red: 0.22, green: 0.10, blue: 0.02), Color(red: 0.52, green: 0.22, blue: 0.04)]
        case .oliloPink:
            return [.black, Color(red: 0.23, green: 0.03, blue: 0.16), Color(red: 0.54, green: 0.08, blue: 0.38)]
        }
    }

    var alternateIconName: String? {
        switch self {
        case .oliloPurple: return nil
        case .oliloBlue: return "OliloBlueIcon"
        case .oliloRed: return "OliloRedIcon"
        case .oliloGreen: return "OliloGreenIcon"
        case .oliloOrange: return "OliloOrangeIcon"
        case .oliloPink: return "OliloPinkIcon"
        }
    }

    static var selected: OliloTheme {
        OliloTheme(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .oliloPurple
    }
}

extension Color {
    static let oliloPurple = Color(red: 0.70, green: 0.28, blue: 1.0)
    static let oliloBlue = Color(red: 0.16, green: 0.52, blue: 1.0)
    static let oliloRed = Color(red: 1.0, green: 0.25, blue: 0.32)
    static let oliloGreen = Color(red: 0.18, green: 0.78, blue: 0.44)
    static let oliloOrange = Color(red: 1.0, green: 0.55, blue: 0.18)
    static let oliloPink = Color(red: 1.0, green: 0.30, blue: 0.72)

    static var oliloTheme: Color {
        OliloTheme.selected.accentColor
    }
}

enum AppTab: Hashable {
    case status
    case notices
    case settings
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: AppTab = .status

    private init() {}

    /// Switches the main tab selection to the notices screen.
    func openNotices() {
        selectedTab = .notices
    }
}

struct ContentView: View {
    @StateObject private var router = AppRouter.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isOnboardingPresented = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesIPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            StatusView()
                .tabItem {
                    Label("Status", systemImage: "waveform.path.ecg")
                }
                .tag(AppTab.status)

            NoticesView()
                .tabItem {
                    Label("Notices", systemImage: "bell.badge")
                }
                .tag(AppTab.notices)

            SettingsView {
                isOnboardingPresented = true
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .tint(Color.oliloTheme)
        .preferredColorScheme(.dark)
        .background(OliloDarkGradientBackground())
        .onAppear {
            if !hasCompletedOnboarding {
                isOnboardingPresented = true
            }
        }
        .modifier(
            OnboardingPresenter(
                isPresented: $isOnboardingPresented,
                hasCompletedOnboarding: hasCompletedOnboarding,
                usesIPadLayout: usesIPadLayout,
                completionAction: completeOnboarding
            )
        )
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        isOnboardingPresented = false
    }
}

private struct OnboardingPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let hasCompletedOnboarding: Bool
    let usesIPadLayout: Bool
    let completionAction: () -> Void

    func body(content: Content) -> some View {
        if usesIPadLayout {
            content.fullScreenCover(isPresented: $isPresented) {
                OnboardingView(completionAction: completionAction)
                    .interactiveDismissDisabled(!hasCompletedOnboarding)
            }
        } else {
            content.sheet(isPresented: $isPresented) {
                OnboardingView(completionAction: completionAction)
                    .interactiveDismissDisabled(!hasCompletedOnboarding)
            }
        }
    }
}

struct OliloDarkGradientBackground: View {
    @AppStorage(OliloTheme.storageKey) private var theme: OliloTheme = .oliloPurple

    var body: some View {
        LinearGradient(
            colors: theme.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct OliloToolbarLogo: View {
    var body: some View {
        Image("Olilo")
            .resizable()
            .scaledToFit()
            .frame(height: 20)
            .accessibilityHidden(true)
    }
}

#Preview {
    ContentView()
}
