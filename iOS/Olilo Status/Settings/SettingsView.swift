import SwiftUI

struct SettingsView: View {
    /// Presents the onboarding tutorial again from the app-level sheet host.
    let startOnboardingAction: () -> Void

    @State private var presentedWebPage: SettingsWebPage?

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Unknown"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRowLabel(title: "Status Updates", systemImage: "bell.badge")
                    }
                }

                Section("Support") {
                    NavigationLink {
                        ContactUsView()
                    } label: {
                        SettingsRowLabel(title: "Contact Us", systemImage: "envelope")
                    }

                    Link(destination: URL(string: "https://gitlab.com/team-olilo/olilo-status/-/boards/11373269")!) {
                        SettingsRowLabel(title: "Report a Problem", systemImage: "exclamationmark.bubble")
                    }

                    Button(action: startOnboardingAction) {
                        SettingsRowLabel(title: "Start Onboarding", systemImage: "questionmark.circle")
                    }
                    .buttonStyle(.plain)
                }

                Section("Contributors") {
                    NavigationLink {
                        CreditsView()
                    } label: {
                        SettingsRowLabel(title: "Credits", systemImage: "megaphone")
                    }
                }

                Section("Compliance") {
                    Button {
                        presentedWebPage = .privacyPolicy
                    } label: {
                        SettingsRowLabel(title: "Privacy Policy", systemImage: "hand.raised")
                    }
                    .buttonStyle(.plain)

                    Button {
                        presentedWebPage = .termsAndConditions
                    } label: {
                        SettingsRowLabel(title: "Terms & Conditions", systemImage: "doc.plaintext")
                    }
                    .buttonStyle(.plain)

                    Button {
                        presentedWebPage = .accessibility
                    } label: {
                        SettingsRowLabel(title: "Accessibility Statement", systemImage: "accessibility")
                    }
                    .buttonStyle(.plain)
                }

                Section("Version") {
                    Link(destination: URL(string: "https://gitlab.com/team-olilo/status-app")!) {
                        SettingsAssetRowLabel(title: "Contribute to Olilo Status", imageName: "GitLab")
                    }
                    .listRowSeparator(.hidden)

                    Text(appVersion)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityLabel("App version \(appVersion)")
                        .listRowSeparator(.hidden)

                    VStack(spacing: 10) {
                        SettingsLogo()

                        Text("© 2026 Olilo UK & Ireland Ltd. Company number: 16352417")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .background(OliloDarkGradientBackground())
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    OliloToolbarLogo()
                }
            }
        }
        .tint(Color.oliloPurple)
        .sheet(item: $presentedWebPage) { webPage in
            OliloWebViewSheet(title: webPage.title, url: webPage.url)
        }
    }
}

private enum SettingsWebPage: Identifiable {
    case privacyPolicy
    case termsAndConditions
    case accessibility

    var id: String { title }

    var title: String {
        switch self {
        case .privacyPolicy: return "Privacy Policy"
        case .termsAndConditions: return "Terms & Conditions"
        case .accessibility: return "Accessibility"
        }
    }

    var url: URL {
        switch self {
        case .privacyPolicy: return URL(string: "https://olilo.co.uk/privacy")!
        case .termsAndConditions: return URL(string: "https://olilo.co.uk/terms")!
        case .accessibility: return URL(string: "https://olilo.co.uk/accessibility")!
        }
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(.white)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.oliloPurple)
        }
    }
}

private struct SettingsAssetRowLabel: View {
    let title: String
    let imageName: String

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(.white)
        } icon: {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        }
    }
}

private struct SettingsLogo: View {
    var body: some View {
        Image("Olilo")
            .resizable()
            .scaledToFit()
            .frame(height: 44)
            .accessibilityHidden(true)
    }
}
