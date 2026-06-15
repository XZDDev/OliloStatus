import SwiftUI

struct CreditsView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            OliloDarkGradientBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meet the Developers")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Olilo Status is a community built application overseen by the official Olilo Team. Listed below are the developers that helped put Olilo Status together.")
                        .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    }

                    Text("Olilo Status Contributors")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Aaron Doe (Developer)")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(.white.opacity(0.15), lineWidth: 1)
                        }

                    Text("Aydan Abrahams (Developer)")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(.white.opacity(0.15), lineWidth: 1)                        }

                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .safeAreaPadding(.bottom, 72)

            OliloFooterLogo()
                .padding(.bottom, 24)
        }
        .navigationTitle("Credits")
        .toolbar {
            ToolbarItem(placement: .principal) {
                OliloToolbarLogo()
            }
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
