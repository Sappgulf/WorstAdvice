import SwiftUI

struct OnboardingFlow: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private struct Page {
        let icon: String
        let title: String
        let subtitle: String
    }

    private let pages: [Page] = [
        Page(
            icon: "sparkles",
            title: "Badvice.\nConfidently delivered.",
            subtitle: "Hilariously wrong guidance for every situation — dating, money, fitness, and more."
        ),
        Page(
            icon: "quote.bubble.fill",
            title: "10 categories.\n9 tones of chaos.",
            subtitle: "Corporate Consultant to Crypto Bro. Every terrible take has a distinct flavor."
        ),
        Page(
            icon: "square.and.arrow.up",
            title: "Share the\nspectacular failure.",
            subtitle: "Beautiful cards. One-tap copy. Wisdom so bad it's almost useful."
        )
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "F7F2E8").ignoresSafeArea()

            // Triple-A Background Elements
            FloatingParticlesView(theme: .minimal, reduceMotion: false, isGenerating: false)
                .opacity(0.4)
            
            CinematicVignetteView()
                .opacity(0.2)
                .blendMode(.multiply)

            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(
                        icon: page.icon,
                        title: page.title,
                        subtitle: page.subtitle
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentPage) { _, _ in
                HapticsManager.playSelection(isEnabled: true)
            }

            // Bottom controls
            VStack(spacing: 20) {
                // Pill page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule(style: .continuous)
                            .fill(Color(hex: "8F4A22").opacity(i == currentPage ? 1 : 0.22))
                            .frame(width: i == currentPage ? 28 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentPage)
                    }
                }

                // CTA
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            currentPage += 1
                        }
                    } else {
                        HapticsManager.play(style: .medium, isEnabled: true)
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Let\u{2019}s Go")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(hex: "8F4A22"))
                                .shadow(color: Color(hex: "8F4A22").opacity(0.3), radius: 10, y: 5)
                        )
                }
                .padding(.horizontal, 28)
                .buttonStyle(.plain)

                // Skip (hidden on last page)
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        HapticsManager.playSelection(isEnabled: true)
                        withAnimation(.easeOut(duration: 0.25)) {
                            isPresented = false
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: "665746"))
                } else {
                    Color.clear.frame(height: 22)
                }
            }
            .padding(.bottom, 44)
        }
    }
}

private struct OnboardingPageView: View {
    let icon: String
    let title: String
    let subtitle: String

    @State private var appeared = false
    @State private var floatAnim = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon bubble
            ZStack {
                Circle()
                    .fill(Color(hex: "8F4A22").opacity(0.1))
                    .frame(width: 140, height: 140)
                    .scaleEffect(floatAnim ? 1.05 : 0.95)

                Circle()
                    .fill(Color(hex: "8F4A22").opacity(0.06))
                    .frame(width: 110, height: 110)
                    .scaleEffect(floatAnim ? 0.9 : 1.1)

                Image(systemName: icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Color(hex: "8F4A22"))
                    .symbolEffect(.bounce.up.byLayer, value: appeared)
                    .offset(y: floatAnim ? -5 : 5)
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.68).delay(0.08), value: appeared)
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: floatAnim)
            .onAppear {
                floatAnim = true
            }

            Spacer().frame(height: 52)

            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.headerColor(for: .minimal))
                .lineSpacing(2)
                .offset(y: appeared ? 0 : 24)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.82).delay(0.18), value: appeared)

            Spacer().frame(height: 18)

            Text(subtitle)
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "665746"))
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.82).delay(0.28), value: appeared)

            Spacer()
            Spacer()
        }
        .onAppear {
            appeared = true
        }
        .onDisappear {
            appeared = false
        }
    }
}
