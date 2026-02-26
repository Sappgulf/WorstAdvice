import SwiftUI

struct SplashView: View {
    @Binding var isShowing: Bool

    @State private var wordmarkScale: CGFloat = 0.72
    @State private var wordmarkOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 12
    @State private var glowOpacity: Double = 0
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

            // Soft radial glow behind wordmark
            RadialGradient(
                colors: [Color(hex: "8F4A22").opacity(0.38), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 260
            )
            .opacity(glowOpacity)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App logo
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 108, height: 108)
                    .shadow(color: Color(hex: "8F4A22").opacity(0.25), radius: 12, x: 0, y: 8)
                    .scaleEffect(wordmarkScale * 1.05) // Ken Burns effect
                    .opacity(wordmarkOpacity)

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
            // Triple-A Polish: Initial state for Ken Burns
            wordmarkScale = 0.92
            let animateInDuration = accessibilityReduceMotion ? 0.35 : 1.2
            let holdDuration = accessibilityReduceMotion ? 1.0 : 2.2
            let animateOutDuration = accessibilityReduceMotion ? 0.25 : 0.45

            // Animate in
            withAnimation(.easeOut(duration: animateInDuration)) {
                wordmarkScale = 1.0 // Subtle zoom
                wordmarkOpacity = 1.0
                glowOpacity = 1.0
                taglineOpacity = 1.0
                taglineOffset = 0
            }

            // Animate out after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) {
                withAnimation(.easeIn(duration: animateOutDuration)) {
                    wordmarkOpacity = 0
                    taglineOpacity = 0
                    glowOpacity = 0
                    wordmarkScale = accessibilityReduceMotion ? 1.0 : 1.05
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + animateOutDuration + 0.05) {
                    isShowing = false
                }
            }
        }
    }
}
