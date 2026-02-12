import Foundation

// MARK: - InterstitialMessages

/// In-character rate-limit and cool-off messages. The app never breaks character.
/// These appear when the user is tapping too fast or has used too many in a session.
enum InterstitialMessages {

    // Shown after 5+ asks in rapid succession (session burst)
    static let burstMessages = [
        "That is enough wisdom for now. Decisions made in bulk lose their power.",
        "You have more than you need. Go act on what you already know.",
        "Pause. Absorb. The best advice requires no second opinion.",
        "Information without implementation is decoration. You have plenty.",
        "Even the most decisive leaders stop to breathe between decisions.",
    ]

    // Shown on 3rd+ app open in a single day (30% chance)
    static let frequentReturnMessages = [
        "You already have everything you need. Go act on it.",
        "Returning this often suggests you already know the answer. Trust that.",
        "The best move now is the one you have been avoiding.",
    ]

    // Shown when user taps after a cool-off period ended
    static let coolOffReturnMessages = [
        "Welcome back. Time away builds perspective. Let us continue.",
        "You have rested. The world has not improved. Let us fix that.",
        "Distance creates clarity. You are ready for the next step.",
    ]

    static func randomBurst() -> String {
        burstMessages.randomElement() ?? burstMessages[0]
    }

    static func randomFrequentReturn() -> String {
        frequentReturnMessages.randomElement() ?? frequentReturnMessages[0]
    }

    static func randomCoolOffReturn() -> String {
        coolOffReturnMessages.randomElement() ?? coolOffReturnMessages[0]
    }
}
