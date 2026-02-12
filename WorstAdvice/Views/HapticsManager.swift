import UIKit

// MARK: - HapticsManager

/// Tier-aware haptics. Escalates from light to heavy as tier increases.
enum HapticsManager {

    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)

    static func play(for tier: AdviceTier) {
        switch tier {
        case .tier1:
            impact(lightGenerator, intensity: 0.5)
        case .tier2:
            impact(mediumGenerator, intensity: 0.7)
        case .tier3:
            impact(heavyGenerator, intensity: 0.85)
        case .tier4:
            // Double hit at highest tier.
            impact(heavyGenerator, intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                impact(rigidGenerator, intensity: 1.0)
            }
        }
    }

    static func playButton() {
        impact(lightGenerator, intensity: 0.3)
    }

    private static func impact(_ generator: UIImpactFeedbackGenerator, intensity: CGFloat) {
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }
}
