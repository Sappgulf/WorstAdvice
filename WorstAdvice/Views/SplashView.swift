import SwiftUI

struct SplashView: View {
    @Binding var isShowing: Bool

    @State private var wordmarkScale: CGFloat = 0.72
    @State private var wordmarkOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 12
    @State private var glowOpacity: Double = 0
    @State private var particleOpacity: Double = 0

    var body: some View {
        ZStack {
            // Warm deep background
            Color(hex: "1C130A").ignoresSafeArea()

            // Soft radial glow behind wordmark
            RadialGradient(
                colors: [Color(hex: "8F4A22").opacity(0.38), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 260
            )
            .opacity(glowOpacity)
            .ignoresSafeArea()

            // Decorative noise grain
            Canvas { context, size in
                for _ in 0..<320 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let r = CGFloat.random(in: 0.5...1.4)
                    context.opacity = Double.random(in: 0.03...0.10)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                        with: .color(.white)
                    )
                }
            }
            .opacity(particleOpacity)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App icon glyph
                ZStack {
                    Circle()
                        .fill(Color(hex: "8F4A22").opacity(0.18))
                        .frame(width: 96, height: 96)
                    Image(systemName: "sparkles")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(Color(hex: "D4845A"))
                }
                .scaleEffect(wordmarkScale)
                .opacity(wordmarkOpacity)
                .animation(.spring(response: 0.62, dampingFraction: 0.65).delay(0.05), value: wordmarkScale)

                Spacer().frame(height: 30)

                // Wordmark
                Text("Badvice")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.headerColor(for: .minimal)) // Use iconic black
                    .shadow(color: Color.white.opacity(0.4), radius: 8, x: 0, y: 0) // Glow on the dark splash
                    .scaleEffect(wordmarkScale)
                    .opacity(wordmarkOpacity)
                    .animation(.spring(response: 0.62, dampingFraction: 0.65).delay(0.05), value: wordmarkScale)

                Spacer().frame(height: 14)

                // Tagline
                Text("confidence in every bad take")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color(hex: "B07C58").opacity(0.85))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .offset(y: taglineOffset)
                    .opacity(taglineOpacity)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.32), value: taglineOpacity)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.32), value: taglineOffset)

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
            // Animate in
            withAnimation {
                wordmarkScale = 1.0
                wordmarkOpacity = 1.0
                glowOpacity = 1.0
                particleOpacity = 1.0
                taglineOpacity = 1.0
                taglineOffset = 0
            }

            // Animate out after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
                withAnimation(.easeIn(duration: 0.35)) {
                    wordmarkOpacity = 0
                    taglineOpacity = 0
                    glowOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                    isShowing = false
                }
            }
        }
    }
}
