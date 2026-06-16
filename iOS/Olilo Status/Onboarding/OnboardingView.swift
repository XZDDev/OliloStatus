import SwiftUI

struct OnboardingView: View {
    let completionAction: () -> Void

    @State private var selectedPage = 0

    private let pages = OnboardingPage.pages

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $selectedPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                VStack(spacing: 12) {
                    Button(action: primaryAction) {
                        Text(selectedPage == pages.indices.last ? "Start Using Olilo Status" : "Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.oliloPurple)

                    if selectedPage < pages.indices.last! {
                        Button("Skip Tutorial", action: completionAction)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(OliloDarkGradientBackground())
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    OliloToolbarLogo()
                }
            }
        }
        .tint(Color.oliloPurple)
        .preferredColorScheme(.dark)
    }

    /// Advances to the next onboarding page, or completes the tutorial on the final page.
    private func primaryAction() {
        guard selectedPage < pages.indices.last! else {
            completionAction()
            return
        }

        withAnimation(.easeInOut) {
            selectedPage += 1
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let systemImage: String
    let highlights: [String]

    static let pages = [
        OnboardingPage(
            title: "Track service health",
            message: "The Status tab gives you a live view of Olilo services, affected components, active incidents, and scheduled maintenance.",
            systemImage: "waveform.path.ecg",
            highlights: [
                "Refresh status whenever you need the latest update",
                "Open dashboard, portal, terminal, and wiki links from one place",
                "Choose which components are shown on your status screen"
            ]
        ),
        OnboardingPage(
            title: "Follow notices",
            message: "The Notices tab keeps current and historical incident and maintenance updates together so you can review what changed and when.",
            systemImage: "bell.badge",
            highlights: [
                "Filter notice history by incident or maintenance",
                "Open linked incident and maintenance reports",
                "See current notices before older history"
            ]
        ),
        OnboardingPage(
            title: "Control notifications",
            message: "Use Settings to decide which status updates you want delivered to this device.",
            systemImage: "bell.and.waves.left.and.right",
            highlights: [
                "Enable alerts for incidents, maintenance, and component changes",
                "Choose specific networks for component alerts",
                "Update your preferences at any time"
            ]
        ),
        OnboardingPage(
            title: "Get help quickly",
            message: "Settings also includes support, compliance, version, and contributor information when you need it.",
            systemImage: "gearshape",
            highlights: [
                "Contact Olilo support from inside the app",
                "Report a problem using the project board link",
                "Restart this tutorial from Settings whenever you want"
            ]
        )
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 18)

                Image(systemName: page.systemImage)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(Color.oliloPurple)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)

                    Text(page.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(page.highlights, id: \.self) { highlight in
                        Label {
                            Text(highlight)
                                .font(.callout)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.oliloPurple)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)

                Spacer(minLength: 18)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    OnboardingView(completionAction: {})
}
