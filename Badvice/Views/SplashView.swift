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
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        ZStack {
            // Warm deep background
            Color(hex: "1C130A").ignoresSafeArea()

            // Triple-A Background Elements
            FloatingParticlesView(theme: .badvice, reduceMotion: accessibilityReduceMotion, isGenerating: false)
                .opacity(accessibilityReduceMotion ? 0.2 : 0.6)
            
            CinematicVignetteView()
                .opacity(0.7)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    // Tight, low-cost glow behind the mark only
                    Circle()
                        .fill(Color(hex: "8F4A22").opacity(0.26))
                        .frame(width: 108, height: 108)
                        .blur(radius: 12)
                        .scaleEffect(logoGlowScale)
                        .opacity(logoGlowOpacity)

                    Image("BadviceMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 138, height: 138)
                        .shadow(color: Color(hex: "8F4A22").opacity(0.16), radius: 8, x: 0, y: 5)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }

                Spacer().frame(height: 30)

                // Wordmark
                Text("Badvice")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: "8F4A22").opacity(0.4), radius: 12, x: 0, y: 0)
                    .scaleEffect(wordmarkScale)
                    .opacity(wordmarkOpacity)

                Spacer().frame(height: 14)

                // Tagline
                Text("confidence in every bad take")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color(hex: "B07C58").opacity(0.85))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .offset(y: taglineOffset)
                    .opacity(taglineOpacity)

                Spacer()

                // Bottom badge
                Text("from the makers of questionable decisions")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color(hex: "665746").opacity(0.6))
                    .opacity(taglineOpacity)
                    .padding(.bottom, 52)
            }
        }
        .onAppear {
            logoScale = accessibilityReduceMotion ? 1.0 : 0.88
            logoOpacity = 0
            logoGlowScale = accessibilityReduceMotion ? 1.0 : 0.92
            logoGlowOpacity = 0
            wordmarkScale = 0.92
            wordmarkOpacity = 0
            taglineOpacity = 0
            taglineOffset = 12

            let animateInDuration = accessibilityReduceMotion ? 0.35 : 1.2
            let holdDuration = accessibilityReduceMotion ? 1.0 : 2.2
            let animateOutDuration = accessibilityReduceMotion ? 0.25 : 0.45

            withAnimation(
                accessibilityReduceMotion
                    ? .easeOut(duration: animateInDuration)
                    : .spring(response: 0.62, dampingFraction: 0.82)
            ) {
                logoScale = 1.0
                logoOpacity = 1.0
                wordmarkScale = 1.0
                wordmarkOpacity = 1.0
                logoGlowOpacity = accessibilityReduceMotion ? 0.12 : 0.22
            }

            withAnimation(.easeOut(duration: animateInDuration * 0.95).delay(accessibilityReduceMotion ? 0 : 0.06)) {
                taglineOpacity = 1.0
                taglineOffset = 0
            }

            if !accessibilityReduceMotion {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    logoGlowScale = 1.08
                    logoGlowOpacity = 0.28
                }
            }

            // Animate out after delay
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(holdDuration))
                withAnimation(.easeIn(duration: animateOutDuration)) {
                    logoOpacity = 0
                    wordmarkOpacity = 0
                    taglineOpacity = 0
                    logoGlowOpacity = 0
                    logoScale = accessibilityReduceMotion ? 1.0 : 1.02
                    wordmarkScale = accessibilityReduceMotion ? 1.0 : 1.05
                }
                try? await Task.sleep(for: .seconds(animateOutDuration + 0.05))
                isShowing = false
            }
        }
    }
}
