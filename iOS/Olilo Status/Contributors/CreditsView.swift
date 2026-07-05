import SwiftUI

struct CreditsView: View {
    var body: some View {
        ZStack {
            OliloDarkGradientBackground()

            Form {
                Section("Meet the Developers") {
                    Text("Olilo Status is a community built application overseen by the official Olilo Team. Listed below are the developers that helped put Olilo Status together.")
                        .foregroundStyle(.white)
                }

                Section("Olilo Status Contributors") {
                    CreditsRowLabel(title: "Aaron Doe", subtitle: "Developer", systemImage: "person")
                    CreditsRowLabel(title: "Aydan Abrahams", subtitle: "Developer", systemImage: "person")
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
        .navigationTitle("Credits")
        .toolbar {
            ToolbarItem(placement: .principal) {
                OliloToolbarLogo()
            }
        }
    }
}

private struct CreditsRowLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.oliloTheme)
        }
    }
}

struct OliloFooterLogo: View {
    var body: some View {
        Image("Olilo")
            .resizable()
            .scaledToFit()
            .frame(height: 36)
            .accessibilityHidden(true)
    }
}
