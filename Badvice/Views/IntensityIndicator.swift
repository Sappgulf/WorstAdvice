import SwiftUI

struct IntensityIndicator: View {
    let tone: ToneMode
    let theme: ThemeMode
    var reduceMotion: Bool = false

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    
    @State private var animatedLevel: Int = 0
    @State private var pulsePhase: Double = 0
    @State private var fillAnimationTask: Task<Void, Never>?

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
        case .random: return 3 // mid-level indicator for mix
        }
    }
    
    private var isMaxIntensity: Bool { level == 5 }
    private var animationsEnabled: Bool { !(reduceMotion || accessibilityReduceMotion) }
    private var accentColor: Color { Theme.accent(for: theme) }
    private var inactiveBarColor: Color { Theme.secondaryText(for: theme).opacity(0.15) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                BarView(
                    index: index,
                    targetLevel: level,
                    animatedLevel: animatedLevel,
                    isMaxIntensity: isMaxIntensity,
                    pulsePhase: pulsePhase,
                    accentColor: accentColor,
                    inactiveBarColor: inactiveBarColor,
                    animationsEnabled: animationsEnabled
                )
            }
        }
        .onAppear {
            restartAnimations()
        }
        .onChange(of: tone) { _, _ in
            restartAnimations()
        }
        .onChange(of: animationsEnabled) { _, _ in
            restartAnimations()
        }
        .onDisappear {
            fillAnimationTask?.cancel()
            fillAnimationTask = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tone intensity")
        .accessibilityValue("\(level) out of 5")
    }

    @MainActor
    private func restartAnimations() {
        fillAnimationTask?.cancel()
        fillAnimationTask = nil
        pulsePhase = 0

        guard animationsEnabled else {
            animatedLevel = level
            return
        }

        animatedLevel = 0
        fillAnimationTask = Task { @MainActor in
            for i in 1...level {
                try? await Task.sleep(nanoseconds: UInt64(80_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    animatedLevel = i
                }
            }

            guard !Task.isCancelled, isMaxIntensity else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulsePhase = 1.0
            }
        }
    }
}

private struct BarView: View {
    let index: Int
    let targetLevel: Int
    let animatedLevel: Int
    let isMaxIntensity: Bool
    let pulsePhase: Double
    let accentColor: Color
    let inactiveBarColor: Color
    let animationsEnabled: Bool
    
    private var isActive: Bool { index <= animatedLevel }
    private var shouldPulse: Bool { isMaxIntensity && index == targetLevel }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(inactiveBarColor)
                    .frame(width: 16, height: geometry.size.height)
                
                // Active bar with animated fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.8),
                                accentColor
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
                                .fill(accentColor.opacity(0.5 * pulsePhase))
                                .blur(radius: 4)
                                .frame(width: 20, height: geometry.size.height + 4)
                            : nil
                    )
            }
            .frame(width: 16, height: geometry.size.height, alignment: .bottom)
        }
        .frame(width: 16, height: CGFloat(6 + index * 3))
        .scaleEffect(isActive ? 1.0 : 0.9)
        .animation(animationsEnabled ? .spring(response: 0.3, dampingFraction: 0.7) : nil, value: isActive)
    }
}
