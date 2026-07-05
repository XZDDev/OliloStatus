import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @AppStorage(OliloTheme.storageKey) private var selectedThemeRawValue = OliloTheme.oliloPurple.rawValue
    @State private var appIconErrorMessage: String?

    private var selectedTheme: OliloTheme {
        OliloTheme(rawValue: selectedThemeRawValue) ?? .oliloPurple
    }

    var body: some View {
        ZStack {
            OliloDarkGradientBackground()

            Form {
                Section {
                    ForEach(OliloTheme.allCases) { theme in
                        Button {
                            selectedThemeRawValue = theme.rawValue
                            applyAppIcon(for: theme)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(theme.accentColor)
                                    .frame(width: 20, height: 20)
                                    .accessibilityHidden(true)

                                Text(theme.displayName)
                                    .foregroundStyle(.white)

                                Spacer()

                                if theme == selectedTheme {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.oliloTheme)
                                        .accessibilityLabel("Selected")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Theme")
                } footer: {
                    Text("The selected colour is used across app controls, links, icons, and the app background.")
                }

                if let appIconErrorMessage {
                    Section {
                        Text(appIconErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("App Icon")
                    }
                }

                Section {
                    OliloFooterLogo()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .listRowSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .iPadReadableContent()
        }
        .tint(Color.oliloTheme)
        .navigationTitle("Appearance")
        .toolbar {
            ToolbarItem(placement: .principal) {
                OliloToolbarLogo()
            }
        }
    }

    private func applyAppIcon(for theme: OliloTheme) {
        appIconErrorMessage = nil

        #if os(iOS)
        let idiom = UIDevice.current.userInterfaceIdiom
        guard idiom == .phone || idiom == .pad else { return }
        guard UIApplication.shared.supportsAlternateIcons else { return }

        UIApplication.shared.setAlternateIconName(theme.alternateIconName) { error in
            guard let error else { return }
            appIconErrorMessage = error.localizedDescription
        }
        #endif
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
}
