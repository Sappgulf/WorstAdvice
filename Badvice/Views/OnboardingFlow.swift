import SwiftUI

struct OnboardingFlow: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var showCompletionConfetti = false
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private struct Page {
        let icon: String
        let title: String
        let subtitle: String
        let accent: Color
        let background: LinearGradient
    }

    private let pages: [Page] = [
        Page(
            icon: "sparkles",
            title: "Badvice.\nConfidently delivered.",
            subtitle: "Hilariously wrong guidance for dating, money, fitness, work, and everyday chaos.",
            accent: Color(hex: "8F4A22"),
            background: LinearGradient(colors: [Color(hex: "F7F2E8"), Color(hex: "F1E4D4")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "quote.bubble.fill",
            title: "14 categories.\n14 tones of chaos.",
            subtitle: "From Corporate Consultant to Conspiracy Theorist, every terrible take has a distinct voice.",
            accent: Color(hex: "7E4B7A"),
            background: LinearGradient(colors: [Color(hex: "F3EAF6"), Color(hex: "E6D7F0")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "square.and.arrow.up",
            title: "Share the\nspectacular failure.",
            subtitle: "Beautiful cards, one-tap copy/share, and daily drops built for group chats.",
            accent: Color(hex: "2E6F64"),
            background: LinearGradient(colors: [Color(hex: "EAF6F3"), Color(hex: "D8EFE8")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "flame.fill",
            title: "Build your\nchaos streak.",
            subtitle: "Generate daily to keep your streak alive. Missions in Chaos Hub earn bonus chaos points and unlock leaderboard rankings.",
            accent: Color(hex: "B84A14"),
            background: LinearGradient(colors: [Color(hex: "FDF3EC"), Color(hex: "F7E0CC")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "person.2.fill",
            title: "Friends &\ncollabs.",
            subtitle: "Add friends, share advice to the community feed, and start collab drafts together. Set up your handle in Friends to get started.",
            accent: Color(hex: "2B5CA8"),
            background: LinearGradient(colors: [Color(hex: "EBF2FE"), Color(hex: "D6E6FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        Page(
            icon: "map.fill",
            title: "Where to next?",
            subtitle: "Chaos Hub for missions and contracts, Advice for instant bad ideas, Quotes for daily chaos, Favorites to save the best disasters. Shake your phone anytime to generate.",
            accent: Color(hex: "3C4E7A"),
            background: LinearGradient(colors: [Color(hex: "EAF0FB"), Color(hex: "DDE6F6")], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]

    private var isMotionReduced: Bool {
        accessibilityReduceMotion
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            pages[currentPage].background
                .ignoresSafeArea()
                .animation(isMotionReduced ? nil : .easeInOut(duration: 0.6), value: currentPage)

            ConfettiView(isActive: $showCompletionConfetti, lowPowerMode: isMotionReduced)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Triple-A Background Elements
            FloatingParticlesView(theme: .minimal, reduceMotion: isMotionReduced, isGenerating: false)
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
                        subtitle: page.subtitle,
                        accent: page.accent,
                        reduceMotion: isMotionReduced
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
                // Progress label
                Text("Step \(currentPage + 1) of \(pages.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(pages[currentPage].accent.opacity(0.9))

                // Pill page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule(style: .continuous)
                            .fill(pages[currentPage].accent.opacity(i == currentPage ? 1 : 0.22))
                            .frame(width: i == currentPage ? 28 : 8, height: 8)
                            .animation(isMotionReduced ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: currentPage)
                    }
                }

                Text("Swipe to explore")
                    .font(.caption)
                    .foregroundStyle(pages[currentPage].accent.opacity(0.7))
                    .opacity(isMotionReduced ? 1 : 0.9)

                // CTA
                Button {
                    if currentPage < pages.count - 1 {
                        if isMotionReduced {
                            currentPage += 1
                        } else {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                                currentPage += 1
                            }
                        }
                    } else {
                        HapticsManager.playSuccess(isEnabled: true)
                        showCompletionConfetti = true
                        Task {
                            try? await Task.sleep(for: .milliseconds(isMotionReduced ? 100 : 700))
                            if isMotionReduced {
                                isPresented = false
                            } else {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isPresented = false
                                }
                            }
                        }
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Start The Chaos")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(pages[currentPage].accent)
                                .shadow(color: pages[currentPage].accent.opacity(0.3), radius: 10, y: 5)
                        )
                }
                .padding(.horizontal, 28)
                .buttonStyle(.plain)

                // Skip (hidden on last page)
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        HapticsManager.playSelection(isEnabled: true)
                        if isMotionReduced {
                            isPresented = false
                        } else {
                            withAnimation(.easeOut(duration: 0.25)) {
                                isPresented = false
                            }
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(pages[currentPage].accent.opacity(0.75))
                    .transition(isMotionReduced ? .identity : .opacity.combined(with: .move(edge: .bottom)))
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
    let accent: Color
    var reduceMotion: Bool = false

    @State private var appeared = false
    @State private var floatAnim = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon bubble
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .scaleEffect(floatAnim ? 1.05 : 0.95)

                Circle()
                    .fill(accent.opacity(0.07))
                    .frame(width: 110, height: 110)
                    .scaleEffect(floatAnim ? 0.9 : 1.1)

                if reduceMotion {
                    Image(systemName: icon)
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(accent)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(accent)
                        .symbolEffect(.bounce.up.byLayer, value: appeared)
                        .offset(y: floatAnim ? -5 : 5)
                }
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.68).delay(0.08), value: appeared)
            .animation(reduceMotion ? nil : .easeInOut(duration: 3).repeatForever(autoreverses: true), value: floatAnim)
            .onAppear {
                floatAnim = !reduceMotion
            }

            Spacer().frame(height: 52)

            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.headerColor(for: .minimal))
                .lineSpacing(2)
                .offset(y: appeared ? 0 : 24)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82).delay(0.18), value: appeared)

            Spacer().frame(height: 18)

            Text(subtitle)
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(accent.opacity(0.6))
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82).delay(0.28), value: appeared)

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
