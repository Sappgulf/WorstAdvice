import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {

    @Binding var isPresented: Bool

    @State private var currentPage = 0

    private let pages: [(title: String, body: String)] = [
        (
            "Welcome.",
            "You have questions. We have answers. The quality of those answers is not guaranteed, but the confidence is absolute."
        ),
        (
            "How it works.",
            "Tap. Receive guidance. The more you ask, the bolder the advice becomes. This is by design."
        ),
        (
            "A note on trust.",
            "This app believes in you. It believes you can handle anything. Whether or not that belief is warranted is not our concern."
        ),
    ]

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Page content
                VStack(spacing: 20) {
                    Text(pages[currentPage].title)
                        .font(Theme.headlineFont)
                        .foregroundStyle(.primary)
                        .id("title_\(currentPage)")
                        .transition(.opacity.combined(with: .move(edge: .trailing)))

                    Text(pages[currentPage].body)
                        .font(.body)
                        .fontDesign(.serif)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 32)
                        .id("body_\(currentPage)")
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .animation(.easeInOut(duration: 0.4), value: currentPage)

                Spacer()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? Color.primary : Color.primary.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // Action button
                Button(action: advance) {
                    Text(currentPage == pages.count - 1 ? "Begin" : "Continue")
                        .font(Theme.buttonFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentTint)
                .clipShape(RoundedRectangle(cornerRadius: Theme.buttonCornerRadius, style: .continuous))
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 50)
            }
        }
    }

    private func advance() {
        HapticsManager.playButton()
        if currentPage < pages.count - 1 {
            withAnimation { currentPage += 1 }
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                isPresented = false
            }
        }
    }
}
