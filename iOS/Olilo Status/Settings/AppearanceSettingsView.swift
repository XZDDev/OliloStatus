import Darwin
import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @AppStorage(OliloTheme.storageKey) private var selectedTheme: OliloTheme = .oliloPurple
    @State private var appIconErrorMessage: String?
    @State private var isRestartAlertPresented = false

    var body: some View {
        ZStack {
            OliloDarkGradientBackground()

            Form {
                Section {
                    ForEach(OliloTheme.allCases) { theme in
                        Button {
                            selectTheme(theme)
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
        .alert("Restart required", isPresented: $isRestartAlertPresented) {
            Button("Close App") {
                exit(0)
            }
        } message: {
            Text("Olilo Status will close now. Reopen it to finish applying your theme.")
        }
    }

    private func selectTheme(_ theme: OliloTheme) {
        guard theme != selectedTheme else { return }
        selectedTheme = theme
        applyAppIcon(for: theme)
    }

    private func applyAppIcon(for theme: OliloTheme) {
        appIconErrorMessage = nil

        #if os(iOS)
        let idiom = UIDevice.current.userInterfaceIdiom
        guard idiom == .phone || idiom == .pad else {
            isRestartAlertPresented = true
            return
        }
        guard UIApplication.shared.supportsAlternateIcons else {
            isRestartAlertPresented = true
            return
        }

        UIApplication.shared.setAlternateIconName(theme.alternateIconName) { error in
            Task { @MainActor in
                if let error {
                    appIconErrorMessage = error.localizedDescription
                }
                isRestartAlertPresented = true
            }
        }
        #else
        isRestartAlertPresented = true
        #endif
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
}
