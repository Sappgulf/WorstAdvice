import SwiftUI

struct IntensityIndicator: View {
    let tone: ToneMode
    let theme: ThemeMode
    
    @State private var animatedLevel: Int = 0
    @State private var pulsePhase: Double = 0

    private var level: Int {
        switch tone {
        case .corporateConsultant: return 3
        case .alphaPodcast: return 5
        case .wizard: return 4
        case .influencer: return 4
        case .toxicBestFriend: return 5
        case .boomer: return 4
        case .cryptoBro: return 5
        case .minimalistMonk: return 2
        case .friendRoast: return 4
        case .lifeCoach: return 3
        case .conspiracyTheorist: return 5
        }
    }
    
    private var isMaxIntensity: Bool { level == 5 }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                BarView(
                    index: index,
                    targetLevel: level,
                    animatedLevel: animatedLevel,
                    isMaxIntensity: isMaxIntensity,
                    pulsePhase: pulsePhase,
                    theme: theme
                )
            }
        }
        .onAppear {
            // Animate bars filling up sequentially
            animatedLevel = 0
            for i in 1...level {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                        animatedLevel = i
                    }
                }
            }
            
            // Start pulse animation for max intensity
            if isMaxIntensity {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulsePhase = 1.0
                }
            }
        }
        .onChange(of: tone) { _, _ in
            animatedLevel = 0
            pulsePhase = 0
            // Re-trigger animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                for i in 1...level {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                            animatedLevel = i
                        }
                    }
                }
                
                if isMaxIntensity {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulsePhase = 1.0
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tone intensity")
        .accessibilityValue("\(level) out of 5")
    }
}

private struct BarView: View {
    let index: Int
    let targetLevel: Int
    let animatedLevel: Int
    let isMaxIntensity: Bool
    let pulsePhase: Double
    let theme: ThemeMode
    
    private var isActive: Bool { index <= animatedLevel }
    private var shouldPulse: Bool { isMaxIntensity && index == targetLevel }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.secondaryText(for: theme).opacity(0.15))
                    .frame(width: 16, height: geometry.size.height)
                
                // Active bar with animated fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.accent(for: theme).opacity(0.8),
                                Theme.accent(for: theme)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 16, height: isActive ? geometry.size.height : 0)
                    .overlay {
                        if shouldPulse {
                            // Inner pulse glow
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.white.opacity(0.35 * pulsePhase), lineWidth: 1.5)
                        }
                    }
                    .overlay(
                        // Glow effect for max intensity
                        shouldPulse ?
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.accent(for: theme).opacity(0.5 * pulsePhase))
                                .blur(radius: 4)
                                .frame(width: 20, height: geometry.size.height + 4)
                            : nil
                    )
            }
            .frame(width: 16, height: geometry.size.height, alignment: .bottom)
        }
        .frame(width: 16, height: CGFloat(6 + index * 3))
        .scaleEffect(isActive ? 1.0 : 0.9)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}
