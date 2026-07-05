import SwiftUI

struct ContactUsView: View {
    var body: some View {
        ZStack {
            OliloDarkGradientBackground()

            Form {
                Section {
                    Link(destination: URL(string: "https://discord.gg/olilo")!) {
                        ContactAssetRowLabel(title: "Find us on Discord", imageName: "Discord")
                    }

                    Link(destination: URL(string: "https://www.reddit.com/r/Olilo")!) {
                        ContactAssetRowLabel(title: "Find us on Reddit", imageName: "Reddit")
                    }
                } header: {
                    Text("Social")
                } footer: {
                    Text("Support links will open to external sites.")
                }

                Section {
                    Link(destination: URL(string: "mailto:support@olilo.co.uk")!) {
                        ContactSystemRowLabel(title: "Olilo Support", systemImage: "envelope")
                    }

                    Link(destination: URL(string: "mailto:sales@olilo.co.uk")!) {
                        ContactSystemRowLabel(title: "Olilo Sales", systemImage: "envelope")
                    }
                } header: {
                    Text("Email")
                } footer: {
                    Text("Please provide as much useful information as possible.")
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
        .navigationTitle("Contact Us")
        .toolbar {
            ToolbarItem(placement: .principal) {
                OliloToolbarLogo()
            }
        }
    }
}

private struct ContactAssetRowLabel: View {
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

private struct ContactSystemRowLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(.white)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.oliloTheme)
                .frame(width: 20, height: 20)
        }
    }
}
