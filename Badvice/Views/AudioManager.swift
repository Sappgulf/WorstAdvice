import AudioToolbox

enum UIActionSound {
    // Non-intrusive generic UI system sounds.
    case generate   // "Pop"
    case swipe      // "Swoosh" / Light Slide
    case success    // Subdued Chime
    case pop        // Lighter Pop

    var systemSoundID: SystemSoundID {
        switch self {
        case .generate: return 1003 // Tink / Pop
        case .swipe: return 1104 // Tock
        case .success: return 1054 // Keypad / confirmation
        case .pop: return 1004 // Tock
        }
    }
}

enum AudioManager {
    static func play(_ sound: UIActionSound, isEnabled: Bool) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }
}
