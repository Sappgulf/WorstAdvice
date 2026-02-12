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
        "Overloading on guidance is itself a form of avoidance. You know what to do.",
        "The oracle requires a moment. Even wisdom needs to recharge.",
        "Too many questions dilute the answers. Pick one. Execute it.",
        "You are collecting advice the way some people collect gym memberships.",
        "Slow down. The problem is not that you lack guidance. The problem is action.",
        "Every great mistake requires only one bad idea. You now have several.",
    ]

    // Shown on 3rd+ app open in a single day (30% chance)
    static let frequentReturnMessages = [
        "You already have everything you need. Go act on it.",
        "Returning this often suggests you already know the answer. Trust that.",
        "The best move now is the one you have been avoiding.",
        "This app is not a replacement for a decision. It is a supplement.",
        "Checking back again? Bold. Let us see if the advice got worse.",
    ]

    // Shown when user taps after a cool-off period ended
    static let coolOffReturnMessages = [
        "Welcome back. Time away builds perspective. Let us continue.",
        "You have rested. The world has not improved. Let us fix that.",
        "Distance creates clarity. You are ready for the next step.",
        "A break was wise. The advice was waiting patiently.",
        "The hiatus is over. Your recklessness is back on schedule.",
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
