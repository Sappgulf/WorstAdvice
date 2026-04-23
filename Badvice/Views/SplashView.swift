import SwiftUI

struct SplashView: View {
    @Binding var isShowing: Bool

    @State private var logoScale: CGFloat = 0.88
    @State private var logoOpacity: Double = 0
    @State private var logoGlowScale: CGFloat = 0.92
    @State private var logoGlowOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 12
    @State private var wordmarkScale: CGFloat = 0.92
    @State private var wordmarkOpacity: Double = 0
    @State private var footerOpacity: Double = 0
    @State private var dismissTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        GeometryReader { proxy in
            let markSize = min(max(proxy.size.width * 0.34, 116), 152)
            let wordmarkSize = min(max(proxy.size.width * 0.14, 44), 60)

            ZStack {
                Color(hex: "1C130A").ignoresSafeArea()

                FloatingParticlesView(theme: .badvice, reduceMotion: accessibilityReduceMotion, isGenerating: false)
                    .opacity(accessibilityReduceMotion ? 0.16 : 0.42)

                CinematicVignetteView()
                    .opacity(0.78)

                VStack(spacing: 0) {
                    Spacer(minLength: 32)

                    ZStack {
                        Circle()
                            .fill(Color(hex: "8F4A22").opacity(0.28))
                            .frame(width: markSize * 0.86, height: markSize * 0.86)
                            .blur(radius: 14)
                            .scaleEffect(logoGlowScale)
                            .opacity(logoGlowOpacity)

                        Circle()
                            .stroke(Color(hex: "E88D72").opacity(0.16), lineWidth: 1)
                            .frame(width: markSize * 1.06, height: markSize * 1.06)
                            .opacity(logoOpacity)

                        Image("BadviceMark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: markSize, height: markSize)
                            .shadow(color: Color(hex: "8F4A22").opacity(0.22), radius: 12, x: 0, y: 6)
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                    }

                    Spacer().frame(height: 28)

                    Text("Badvice")
                        .font(.system(size: wordmarkSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: Color(hex: "8F4A22").opacity(0.42), radius: 14, x: 0, y: 0)
                        .scaleEffect(wordmarkScale)
                        .opacity(wordmarkOpacity)
                        .minimumScaleFactor(0.8)

                    Spacer().frame(height: 14)

                    Text("confidence in every bad take")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color(hex: "D7A37F").opacity(0.88))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .multilineTextAlignment(.center)
                        .offset(y: taglineOffset)
                        .opacity(taglineOpacity)
                        .padding(.horizontal, 28)

                    Spacer()

                    HStack(spacing: 8) {
                        Capsule()
                            .fill(Color(hex: "E88D72").opacity(0.76))
                            .frame(width: 28, height: 4)
                        Capsule()
                            .fill(Color(hex: "E88D72").opacity(0.28))
                            .frame(width: 16, height: 4)
                        Capsule()
                            .fill(Color(hex: "E88D72").opacity(0.18))
                            .frame(width: 10, height: 4)
                    }
                    .opacity(footerOpacity)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 34, 52))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear(perform: runIntroAnimation)
            .onDisappear {
                dismissTask?.cancel()
                dismissTask = nil
            }
        }
    }

    private func runIntroAnimation() {
        dismissTask?.cancel()
        logoScale = accessibilityReduceMotion ? 1.0 : 0.88
        logoOpacity = 0
        logoGlowScale = accessibilityReduceMotion ? 1.0 : 0.92
        logoGlowOpacity = 0
        wordmarkScale = accessibilityReduceMotion ? 1.0 : 0.92
        wordmarkOpacity = 0
        taglineOpacity = 0
        taglineOffset = 12
        footerOpacity = 0

        let animateInDuration = accessibilityReduceMotion ? 0.18 : 0.46
        let holdDuration = accessibilityReduceMotion ? 0.28 : 0.95
        let animateOutDuration = accessibilityReduceMotion ? 0.14 : 0.24

        withAnimation(
            accessibilityReduceMotion
                ? .easeOut(duration: animateInDuration)
                : .spring(response: 0.62, dampingFraction: 0.82)
        ) {
            logoScale = 1.0
            logoOpacity = 1.0
            wordmarkScale = 1.0
            wordmarkOpacity = 1.0
            logoGlowOpacity = accessibilityReduceMotion ? 0.12 : 0.24
        }

        withAnimation(.easeOut(duration: animateInDuration * 0.95).delay(accessibilityReduceMotion ? 0 : 0.06)) {
            taglineOpacity = 1.0
            taglineOffset = 0
        }

        withAnimation(.easeOut(duration: 0.24).delay(accessibilityReduceMotion ? 0 : 0.16)) {
            footerOpacity = 1.0
        }

        if !accessibilityReduceMotion {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                logoGlowScale = 1.08
                logoGlowOpacity = 0.3
            }
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(holdDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: animateOutDuration)) {
                logoOpacity = 0
                wordmarkOpacity = 0
                taglineOpacity = 0
                footerOpacity = 0
                logoGlowOpacity = 0
                logoScale = accessibilityReduceMotion ? 1.0 : 1.02
                wordmarkScale = accessibilityReduceMotion ? 1.0 : 1.05
            }
            try? await Task.sleep(for: .seconds(animateOutDuration + 0.05))
            guard !Task.isCancelled else { return }
            isShowing = false
            dismissTask = nil
        }
    }
}
