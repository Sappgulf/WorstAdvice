import Foundation





struct DeepLink: Codable, Sendable {
    let type: LinkType
    let id: UUID?
    let category: AdviceCategory?
    let tone: ToneMode?

    enum LinkType: String, Codable, Sendable {
        case advice
        case category
        case tone
        case battle
        case challenge
        case friend
        case quotes
        case invite
    }
}

extension DeepLink {
    init?(url: URL) {
        guard url.scheme?.lowercased() == "badvice" else { return nil }

        let host = url.host?.lowercased()
        let pathParts = url.pathComponents
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased() }
            .filter { !$0.isEmpty }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        let categoryRaw = queryItems.first(where: { $0.name.lowercased() == "category" })?.value
        let toneRaw = queryItems.first(where: { $0.name.lowercased() == "tone" })?.value
        let category = categoryRaw.flatMap(AdviceCategory.init(rawValue:))
        let tone = toneRaw.flatMap(ToneMode.init(rawValue:))

        let primary = host ?? pathParts.first
        let inviteID = queryItems
            .first(where: { item in item.name.lowercased() == "invite" || item.name.lowercased() == "id" })
            .flatMap(\.value)
            .flatMap(UUID.init(uuidString:))

        switch primary {
        case "invite":
            let targetID = host == "invite" ? pathParts.first : pathParts.dropFirst().first
            guard let rawID = targetID ?? inviteID?.uuidString,
                  let id = UUID(uuidString: rawID)
            else {
                return nil
            }
            self = .init(type: .invite, id: id, category: nil, tone: nil)
        case "advice":
            self = .init(
                type: .advice,
                id: queryItems.first(where: { $0.name.lowercased() == "id" })?.value.flatMap(UUID.init(uuidString:)),
                category: category,
                tone: tone
            )
        case "friends", "friend", "social":
            self = .init(type: .friend, id: nil, category: category, tone: tone)
        case "quotes":
            self = .init(type: .quotes, id: nil, category: category, tone: tone)
        case "battle":
            self = .init(type: .battle, id: nil, category: category, tone: tone)
        case "challenge":
            self = .init(type: .challenge, id: nil, category: category, tone: tone)
        default:
            if category != nil || tone != nil {
                self = .init(type: .advice, id: nil, category: category, tone: tone)
            } else {
                return nil
            }
        }
    }

    var inviteID: UUID? { type == .invite ? id : nil }
}

// MARK: - Feed Reactions (#1)

enum SocialReactionType: String, CaseIterable, Codable, Sendable {
    case fire = "fire"
    case laugh = "laugh"
    case facepalm = "facepalm"
    case skull = "skull"
    case hundredPoints = "100"

    var emoji: String {
        switch self {
        case .fire: return "🔥"
        case .laugh: return "😂"
        case .facepalm: return "🤦"
        case .skull: return "💀"
        case .hundredPoints: return "💯"
        }
    }

    var label: String {
        switch self {
        case .fire: return "Fire"
        case .laugh: return "Laugh"
        case .facepalm: return "Facepalm"
        case .skull: return "Dead"
        case .hundredPoints: return "100"
        }
    }
}

struct FeedReaction: Identifiable, Codable, Sendable {
    let id: UUID
    let postID: String
    let userHandle: String
    let type: SocialReactionType
    let createdAt: Date
}

// MARK: - Activity Feed (#6)


// MARK: - Category/Tone Compatibility (#10)

struct CategoryToneCompatibility {
    /// Returns a compatibility score 0.0–1.0 for a category+tone pair.
    /// 1.0 = perfect fit, 0.0 = very awkward pairing.
    static func score(category: AdviceCategory, tone: ToneMode) -> Double {
        matrix[category]?[tone] ?? 0.8
    }

    static func compatibilityLabel(category: AdviceCategory, tone: ToneMode) -> String? {
        let s = score(category: category, tone: tone)
        if s >= 0.9 { return nil }          // great — no warning
        if s >= 0.75 { return nil }         // fine — no warning
        if s >= 0.55 { return "Unusual mix" }
        return "Awkward combo"
    }

    // Sparse matrix — only low-compatibility pairs listed; others default to a solid fit.
    private static let matrix: [AdviceCategory: [ToneMode: Double]] = [
        .cooking: [
            .cryptoBro: 0.40,
            .corporateConsultant: 0.45,
            .alphaPodcast: 0.50,
            .linkedInInfluencer: 0.50,
        ],
        .parenting: [
            .cryptoBro: 0.35,
            .alphaPodcast: 0.40,
            .redditCommenter: 0.50,
        ],
        .spirituality: [
            .cryptoBro: 0.30,
            .corporateConsultant: 0.45,
            .linkedInInfluencer: 0.40,
        ],
        .fitness: [
            .wizard: 0.50,
            .minimalistMonk: 0.55,
            .conspiracyTheorist: 0.50,
        ],
        .money: [
            .wizard: 0.45,
            .minimalistMonk: 0.50,
        ],
        .pets: [
            .cryptoBro: 0.35,
            .corporateConsultant: 0.40,
            .alphaPodcast: 0.45,
        ],
    ]
}

// MARK: - Offline Pack State (#3)

enum OfflinePackStatus: String, Codable, Sendable {
    case notCached
    case downloading
    case cached
    case stale

    var label: String {
        switch self {
        case .notCached: return "Available"
        case .downloading: return "Downloading…"
        case .cached: return "Downloaded"
        case .stale: return "Update available"
        }
    }

    var systemImage: String {
        switch self {
        case .notCached: return "arrow.down.circle"
        case .downloading: return "arrow.down.circle.dotted"
        case .cached: return "checkmark.circle.fill"
        case .stale: return "exclamationmark.circle"
        }
    }
}

struct OfflinePackCacheEntry: Codable, Sendable {
    let packID: String
    let cachedAt: Date
    let version: Int
}

// MARK: - Collab Advice Session (#7)


// MARK: - Live Activity Attributes (#17)


// MARK: - Referral (#15)















struct TipJar: Identifiable, Codable, Sendable {
    let id: UUID
    let amount: Double
    let message: String?
    let tippedAt: Date
    
    static let presets: [TipJar] = [
        TipJar(id: UUID(), amount: 0.99, message: "Keep it up!", tippedAt: Date()),
        TipJar(id: UUID(), amount: 1.99, message: "Love the app!", tippedAt: Date()),
        TipJar(id: UUID(), amount: 4.99, message: "You're the best!", tippedAt: Date())
    ]
}


struct TimedChallenge: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let category: AdviceCategory
    let tone: ToneMode
    let timeLimit: TimeInterval
    let isActive: Bool
    let startedAt: Date?
    let score: Int?
    let totalRounds: Int
    let completedRounds: Int
    
    var isCompleted: Bool { completedRounds >= totalRounds }
    
    static let presets: [TimedChallenge] = [
        TimedChallenge(
            id: UUID(),
            name: "30-Second War",
            description: "Generate as much terrible advice as possible in 30 seconds",
            category: .random,
            tone: .random,
            timeLimit: 30,
            isActive: true,
            startedAt: nil,
            score: nil,
            totalRounds: 10,
            completedRounds: 0
        ),
        TimedChallenge(
            id: UUID(),
            name: "Minute of Chaos",
            description: "One minute to create the worst advice possible",
            category: .dating,
            tone: .toxicBestFriend,
            timeLimit: 60,
            isActive: true,
            startedAt: nil,
            score: nil,
            totalRounds: 5,
            completedRounds: 0
        )
    ]
}













struct NotificationSettings: Codable, Sendable {
    var dailyChallengeEnabled: Bool
    var dailyChallengeTime: Date
    var friendActivityEnabled: Bool
    var streakWarningEnabled: Bool
    var streakWarningThreshold: Int
    var trendingHighlightsEnabled: Bool
    var soundEnabled: Bool
    var badgeEnabled: Bool
    
    static let `default` = NotificationSettings(
        dailyChallengeEnabled: true,
        dailyChallengeTime: Date(),
        friendActivityEnabled: true,
        streakWarningEnabled: true,
        streakWarningThreshold: 2,
        trendingHighlightsEnabled: true,
        soundEnabled: true,
        badgeEnabled: true
    )
}



struct PrivacySettings: Codable, Sendable {
    var profileVisibility: ProfileVisibility
    var showActivityStatus: Bool
    var allowFriendRequests: Bool
    var showOnLeaderboard: Bool
    var shareAnalytics: Bool
    
    enum ProfileVisibility: String, Codable, Sendable {
        case public_
        case friends
        case private_
    }
    
    static let `default` = PrivacySettings(
        profileVisibility: .friends,
        showActivityStatus: true,
        allowFriendRequests: true,
        showOnLeaderboard: true,
        shareAnalytics: true
    )
}


struct HapticSettings: Codable, Sendable {
    var generationEnabled: Bool
    var shareEnabled: Bool
    var achievementEnabled: Bool
    var battleEnabled: Bool
    var intensity: HapticIntensity
    
    enum HapticIntensity: String, Codable, Sendable {
        case off
        case light
        case medium
        case heavy
        
        var impactValue: Double {
            switch self {
            case .off: return 0
            case .light: return 0.3
            case .medium: return 0.6
            case .heavy: return 1.0
            }
        }
    }
    
    static let `default` = HapticSettings(
        generationEnabled: true,
        shareEnabled: true,
        achievementEnabled: true,
        battleEnabled: true,
        intensity: .medium
    )
}

struct SoundSettings: Codable, Sendable {
    var enabled: Bool
    var volume: Double
    var generationSound: SoundEffect
    var shareSound: SoundEffect
    
    enum SoundEffect: String, Codable, Sendable {
        case pop
        case chime
        case whoosh
        case none
    }
    
    static let `default` = SoundSettings(
        enabled: true,
        volume: 0.7,
        generationSound: .pop,
        shareSound: .chime
    )
}

struct AnimationSettings: Codable, Sendable {
    var speed: AnimationSpeed
    var reducedMotion: Bool
    var particleEffects: Bool
    
    enum AnimationSpeed: String, Codable, Sendable {
        case slow
        case normal
        case fast
        case instant
    }
    
    static let `default` = AnimationSettings(
        speed: .normal,
        reducedMotion: false,
        particleEffects: true
    )
}

struct PullToRefreshConfig: Codable, Sendable {
    var enabled: Bool
    var hapticFeedback: Bool
    var autoRefresh: Bool
    var refreshInterval: TimeInterval
    
    static let `default` = PullToRefreshConfig(
        enabled: true,
        hapticFeedback: true,
        autoRefresh: false,
        refreshInterval: 300
    )
}

struct iPadLayout: Codable, Sendable {
    var useAdaptiveLayout: Bool
    var sidebarEnabled: Bool
    var multiColumnEnabled: Bool
    var splitViewStyle: SplitStyle
    
    enum SplitStyle: String, Codable, Sendable {
        case automatic
        case doubleColumn
        case tripleColumn
    }
    
    static let `default` = iPadLayout(
        useAdaptiveLayout: true,
        sidebarEnabled: true,
        multiColumnEnabled: true,
        splitViewStyle: .automatic
    )
}

struct MacSettings: Codable, Sendable {
    var menuBarEnabled: Bool
    var touchBarEnabled: Bool
    var keyboardShortcuts: [KeyboardShortcut]
    
    struct KeyboardShortcut: Codable, Sendable {
        let action: String
        let keys: [String]
    }
    
    static let `default` = MacSettings(
        menuBarEnabled: true,
        touchBarEnabled: true,
        keyboardShortcuts: []
    )
}

struct WatchSettings: Codable, Sendable {
    var complicationEnabled: Bool
    var showStreak: Bool
    var showDailyChallenge: Bool
    var hapticEnabled: Bool
    
    static let `default` = WatchSettings(
        complicationEnabled: true,
        showStreak: true,
        showDailyChallenge: true,
        hapticEnabled: true
    )
}


struct BetaConfig: Codable, Sendable {
    var isBetaTester: Bool
    var betaBuildNumber: String?
    var feedbackEmail: String?
    var crashReportingEnabled: Bool
    
    static let `default` = BetaConfig(
        isBetaTester: false,
        betaBuildNumber: nil,
        feedbackEmail: nil,
        crashReportingEnabled: true
    )
}

