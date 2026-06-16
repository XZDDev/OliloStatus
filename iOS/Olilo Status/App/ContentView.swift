import Combine
import SwiftUI

extension Color {
    static let oliloPurple = Color(red: 0.70, green: 0.28, blue: 1.0)
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
        .tint(Color.oliloPurple)
        .preferredColorScheme(.dark)
        .background(OliloDarkGradientBackground())
        .onAppear {
            if !hasCompletedOnboarding {
                isOnboardingPresented = true
            }
        }
        .sheet(isPresented: $isOnboardingPresented) {
            OnboardingView {
                hasCompletedOnboarding = true
                isOnboardingPresented = false
            }
            .interactiveDismissDisabled(!hasCompletedOnboarding)
        }
    }
}

struct OliloDarkGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                .black,
                Color(red: 0.13, green: 0.04, blue: 0.24),
                Color(red: 0.30, green: 0.08, blue: 0.48)
            ],
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
