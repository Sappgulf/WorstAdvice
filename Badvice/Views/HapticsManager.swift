import UIKit
import CoreHaptics
import AudioToolbox



enum SoundFeedback {
    static func playGenerate(isEnabled: Bool) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1113)
    }
}
enum HapticsManager {
    // Performance: Reuse generators to avoid recreation overhead
    private static var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    private static var selectionGenerator: UISelectionFeedbackGenerator?
    private static var notificationGenerator: UINotificationFeedbackGenerator?
    
    private static func getImpactGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let existing = impactGenerators[style] {
            return existing
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style] = generator
        return generator
    }
    
    static func play(style: UIImpactFeedbackGenerator.FeedbackStyle, isEnabled: Bool) {
        guard isEnabled else { return }
        let generator = getImpactGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func playSelection(isEnabled: Bool) {
        guard isEnabled else { return }
        if selectionGenerator == nil {
            selectionGenerator = UISelectionFeedbackGenerator()
        }
        selectionGenerator?.prepare()
        selectionGenerator?.selectionChanged()
    }
    
    static func playSuccess(isEnabled: Bool) {
        guard isEnabled else { return }
        if notificationGenerator == nil {
            notificationGenerator = UINotificationFeedbackGenerator()
        }
        notificationGenerator?.prepare()
        notificationGenerator?.notificationOccurred(.success)
    }
    
    static func playError(isEnabled: Bool) {
        guard isEnabled else { return }
        if notificationGenerator == nil {
            notificationGenerator = UINotificationFeedbackGenerator()
        }
        notificationGenerator?.prepare()
        notificationGenerator?.notificationOccurred(.error)
    }
    
    static func playWarning(isEnabled: Bool) {
        guard isEnabled else { return }
        if notificationGenerator == nil {
            notificationGenerator = UINotificationFeedbackGenerator()
        }
        notificationGenerator?.prepare()
        notificationGenerator?.notificationOccurred(.warning)
    }
    
    // MARK: - Tone-Specific Haptic Patterns
    
    static func playToneHaptic(tone: ToneMode, isEnabled: Bool) {
        guard isEnabled else { return }
        
        switch tone {
        case .alphaPodcast, .cryptoBro:
            // Aggressive double-tap
            play(style: .heavy, isEnabled: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                play(style: .rigid, isEnabled: true)
            }
            
        case .corporateConsultant, .lifeCoach:
            // Professional single medium
            play(style: .medium, isEnabled: true)
            
        case .toxicBestFriend, .conspiracyTheorist:
            // Chaotic triple
            play(style: .light, isEnabled: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                play(style: .medium, isEnabled: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                play(style: .light, isEnabled: true)
            }
            
        case .wizard:
            // Mysterious slow double
            play(style: .soft, isEnabled: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                play(style: .soft, isEnabled: true)
            }
            
        case .boomer:
            // Old-school single heavy
            play(style: .heavy, isEnabled: true)
            
        case .minimalistMonk:
            // Zen soft single
            play(style: .soft, isEnabled: true)
            
        case .friendRoast:
            // Playful bounce
            play(style: .light, isEnabled: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                play(style: .rigid, isEnabled: true)
            }
            
        case .influencer, .genZ, .linkedInInfluencer:
            // Pop style
            play(style: .rigid, isEnabled: true)
            
        case .redditCommenter:
            // Debate style - rapid back and forth
            play(style: .light, isEnabled: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                play(style: .medium, isEnabled: true)
            }
            
        case .random:
            // Random pick based on hash
            let hash = ObjectIdentifier(ToneMode.self).hashValue % 5
            switch hash {
            case 0: play(style: .heavy, isEnabled: true)
            case 1: play(style: .medium, isEnabled: true)
            case 2: play(style: .light, isEnabled: true)
            case 3: play(style: .rigid, isEnabled: true)
            default: play(style: .soft, isEnabled: true)
            }
        }
    }
    
    // MARK: - Achievement Celebration
    
    static func playAchievementCelebration(isEnabled: Bool) {
        guard isEnabled else { return }
        
        // Success pattern: light -> medium -> heavy with increasing intensity
        play(style: .light, isEnabled: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            play(style: .medium, isEnabled: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            play(style: .heavy, isEnabled: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            play(style: .rigid, isEnabled: true)
        }
    }
    
    // MARK: - Shake Detection Haptic
    
    static func playShakeDetected(isEnabled: Bool) {
        guard isEnabled else { return }
        play(style: .medium, isEnabled: true)
    }
    
    // MARK: - Streak Milestone
    
    static func playStreakMilestone(days: Int, isEnabled: Bool) {
        guard isEnabled else { return }
        
        let intensity = min(Double(days) / 30.0, 1.0)
        let baseDelay = 0.08
        
        for i in 0..<min(days / 3, 5) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * baseDelay) {
                let style: UIImpactFeedbackGenerator.FeedbackStyle = intensity > 0.7 ? .heavy : (intensity > 0.4 ? .medium : .light)
                play(style: style, isEnabled: true)
            }
        }
    }
    
    // MARK: - Level Up
    
    static func playLevelUp(isEnabled: Bool) {
        guard isEnabled else { return }
        
        play(style: .heavy, isEnabled: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            play(style: .rigid, isEnabled: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            play(style: .heavy, isEnabled: true)
        }
    }
    
    // MARK: - XP Earned
    
    static func playXPEarned(amount: Int, isEnabled: Bool) {
        guard isEnabled else { return }
        
        if amount >= 100 {
            play(style: .medium, isEnabled: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                play(style: .medium, isEnabled: true)
            }
        } else {
            play(style: .light, isEnabled: true)
        }
    }
    
    // MARK: - Save Action
    
    static func playSave(isEnabled: Bool) {
        guard isEnabled else { return }
        play(style: .rigid, isEnabled: true)
    }
    
    // MARK: - Share Action
    
    static func playShare(isEnabled: Bool) {
        guard isEnabled else { return }
        play(style: .medium, isEnabled: true)
    }
    
    // MARK: - Card Swipe
    
    static func playCardSwipe(isEnabled: Bool) {
        guard isEnabled else { return }
        play(style: .light, isEnabled: true)
    }
}
