import SwiftUI

struct SettingsView: View {
    @State private var presentedWebPage: SettingsWebPage?

    var body: some View {
        NavigationStack {
            Form {
                Section("Information") {
                    NavigationLink {
                        LegalNoticesView()
                    } label: {
                        SettingsRowLabel(title: "Legal Notices", systemImage: "doc.text", titleColor: Color.oliloPurple)
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRowLabel(title: "About", systemImage: "info.circle", titleColor: Color.oliloPurple)
                    }

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
                }

                Section("Olilo Status") {
                    VStack(spacing: 10) {
                        SettingsLogo()

                        Text("© 2026 Olilo UK & Ireland Ltd. Company number: 16352417")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
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

    var id: String { title }

    var title: String {
        switch self {
        case .privacyPolicy: return "Privacy Policy"
        case .termsAndConditions: return "Terms & Conditions"
        }
    }

    var url: URL {
        switch self {
        case .privacyPolicy: return URL(string: "https://olilo.co.uk/privacy")!
        case .termsAndConditions: return URL(string: "https://olilo.co.uk/terms")!
        }
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    var titleColor: Color = Color.oliloPurple

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(titleColor)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.oliloPurple)
        }
    }
}

private struct SettingsLogo: View {
    var body: some View {
        Image("OliloLogoLight")
            .resizable()
            .scaledToFit()
            .frame(height: 44)
            .accessibilityLabel("Olilo")
    }
}
