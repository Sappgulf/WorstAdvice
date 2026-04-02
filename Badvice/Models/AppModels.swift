import Foundation

    let id: UUID
    let originalAdvice: String
    let originalCategory: AdviceCategory
    let originalTone: ToneMode
    let remixedAdvice: String
    let remixedTone: ToneMode
    let remixStyle: RemixStyle
    let createdAt: Date
    
    enum RemixStyle: String, Codable, Sendable {
        case moreAbsurd
        case differentTone
        case escalate
        case minimal
        case contradictory
    }
}

struct LiveFeedEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let userID: String
    let userName: String
    let eventType: EventType
    let advicePreview: String?
    let category: AdviceCategory?
    let tone: ToneMode?
    let timestamp: Date
    
    enum EventType: String, Codable, Sendable {
        case generated
        case shared
        case battleStarted
        case battleVote
        case achievementUnlocked
        case levelUp
    }
}

struct CollaborativeSession: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let hostID: String
    let participants: [String]
    let category: AdviceCategory
    let tone: ToneMode
    let contributions: [Contribution]
    let startedAt: Date
    let endsAt: Date
    let isActive: Bool
    
    struct Contribution: Identifiable, Codable, Sendable {
        let id: UUID
        let userID: String
        let userName: String
        let text: String
        let order: Int
    }
}

struct QRCodeShare: Codable, Sendable {
    let adviceID: UUID
    let adviceText: String
    let category: AdviceCategory
    let tone: ToneMode
    let creatorName: String
    let createdAt: Date
    
    var deepLink: String {
        "badvice://advice/\(adviceID)"
    }
}

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
        case invite
    }
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

struct SocialActivityEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let actorHandle: String
    let actorDisplayName: String
    let type: ActivityEventType
    let targetText: String?
    let targetCategory: AdviceCategory?
    let targetTone: ToneMode?
    let occurredAt: Date

    enum ActivityEventType: String, Codable, Sendable, CaseIterable {
        case friendJoined
        case friendSharedAdvice
        case friendReactedToYourPost
        case friendUnlockedAchievement
        case friendCompletedChallenge
        case friendStartedStreak
        case friendReachedStreak7
        case friendReachedStreak30

        var icon: String {
            switch self {
            case .friendJoined: return "person.badge.plus"
            case .friendSharedAdvice: return "square.and.arrow.up"
            case .friendReactedToYourPost: return "heart.fill"
            case .friendUnlockedAchievement: return "star.fill"
            case .friendCompletedChallenge: return "checkmark.seal.fill"
            case .friendStartedStreak: return "flame"
            case .friendReachedStreak7: return "flame.fill"
            case .friendReachedStreak30: return "crown.fill"
            }
        }

        var templateText: String {
            switch self {
            case .friendJoined: return "joined Badvice"
            case .friendSharedAdvice: return "shared advice"
            case .friendReactedToYourPost: return "reacted to your post"
            case .friendUnlockedAchievement: return "unlocked an achievement"
            case .friendCompletedChallenge: return "completed a challenge"
            case .friendStartedStreak: return "started a streak"
            case .friendReachedStreak7: return "hit a 7-day streak 🔥"
            case .friendReachedStreak30: return "hit a 30-day streak 👑"
            }
        }
    }
}

// MARK: - Category/Tone Compatibility (#10)

struct CategoryToneCompatibility {
    /// Returns a compatibility score 0.0–1.0 for a category+tone pair.
    /// 1.0 = perfect fit, 0.0 = very awkward pairing.
    static func score(category: AdviceCategory, tone: ToneMode) -> Double {
        matrix[category]?[tone] ?? 0.7
    }

    static func compatibilityLabel(category: AdviceCategory, tone: ToneMode) -> String? {
        let s = score(category: category, tone: tone)
        if s >= 0.9 { return nil }          // great — no warning
        if s >= 0.75 { return nil }         // fine — no warning
        if s >= 0.55 { return "Unusual mix" }
        return "Awkward combo"
    }

    // Sparse matrix — only low-compatibility pairs listed; others default to 0.7.
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

struct CollabAdviceSession: Identifiable, Codable, Sendable {
    let id: UUID
    let initiatorHandle: String
    let partnerHandle: String?
    var initiatorPickedCategory: AdviceCategory?
    var partnerPickedTone: ToneMode?
    let createdAt: Date
    var isComplete: Bool { initiatorPickedCategory != nil && partnerPickedTone != nil }

    var resolvedCategory: AdviceCategory? { initiatorPickedCategory }
    var resolvedTone: ToneMode? { partnerPickedTone }
}

// MARK: - Live Activity Attributes (#17)

struct BadviceStreakAttributes: Codable, Sendable {
    let streakDays: Int
    let challengeTitle: String

    struct ContentState: Codable, Sendable {
        let currentCount: Int
        let targetCount: Int
        let isComplete: Bool
    }
}

// MARK: - Referral (#15)

struct ReferralLink: Identifiable, Codable, Sendable {
    let id: UUID
    let inviterHandle: String
    let createdAt: Date

    var deepLinkURL: URL {
        // UUID strings are always URL-safe, so this will never fail in practice.
        guard let url = URL(string: "badvice://invite/\(id.uuidString.lowercased())") else {
            return URL(string: "badvice://invite")!
        }
        return url
    }

    var shareText: String {
        "Join me on Badvice — the app for spectacularly wrong advice! \(deepLinkURL.absoluteString)"
    }
}

struct RoastModeChallenge: Identifiable, Codable, Sendable {
    let id: UUID
    let targetName: String
    let targetDescription: String
    let category: AdviceCategory
    let entries: [RoastEntry]
    let startedAt: Date
    let endsAt: Date
    
    var isActive: Bool { Date() < endsAt }
    
    struct RoastEntry: Identifiable, Codable, Sendable {
        let id: UUID
        let userID: String
        let userName: String
        let roastText: String
        let votes: Int
    }
}

struct CustomTone: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let opener: [String]
    let closer: [String]
    let vocabulary: [String]
    let intensity: Double
    let createdBy: String
    let isPublic: Bool
    let createdAt: Date
}

struct CategoryMixer: Identifiable, Codable, Sendable {
    let id: UUID
    let categories: [AdviceCategory]
    let tones: [ToneMode]
    let generatedCount: Int
    let createdAt: Date
    
    var isValid: Bool {
        categories.count >= 1 && tones.count >= 1
    }
}

struct AdviceCollection: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let adviceIDs: [UUID]
    let createdBy: String
    let isPublic: Bool
    let createdAt: Date
    let viewCount: Int
    let likeCount: Int
}

struct AdviceTournament: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let category: AdviceCategory
    let tone: ToneMode
    let entries: [TournamentEntry]
    let currentRound: Int
    let totalRounds: Int
    let status: TournamentStatus
    let createdAt: Date
    let endsAt: Date
    
    var isActive: Bool { status == .active }
    
    enum TournamentStatus: String, Codable, Sendable {
        case pending
        case active
        case completed
    }
    
    struct TournamentEntry: Identifiable, Codable, Sendable {
        let id: UUID
        let adviceText: String
        let submittedBy: String
        var votes: Int
        let round: Int
    }
}

struct PersonalStats: Codable, Sendable {
    let totalGenerated: Int
    let totalShared: Int
    let totalFavorited: Int
    let totalRemixed: Int
    let totalBattles: Int
    let battlesWon: Int
    let currentStreak: Int
    let longestStreak: Int
    let favoriteCategory: AdviceCategory?
    let favoriteTone: ToneMode?
    let categoryBreakdown: [AdviceCategory: Int]
    let toneBreakdown: [ToneMode: Int]
    let weeklyGenerated: Int
    let monthlyGenerated: Int
    
    var winRate: Double {
        guard totalBattles > 0 else { return 0 }
        return Double(battlesWon) / Double(totalBattles)
    }
}

struct FriendComparison: Codable, Sendable {
    let friendID: String
    let friendName: String
    let yourStats: PersonalStats
    let friendStats: PersonalStats
    
    var whoWon: ComparisonResult {
        let yourScore = yourStats.totalGenerated + yourStats.battlesWon * 10
        let friendScore = friendStats.totalGenerated + friendStats.battlesWon * 10
        if yourScore > friendScore { return .you }
        else if friendScore > yourScore { return .friend }
        else { return .tie }
    }
    
    enum ComparisonResult {
        case you
        case friend
        case tie
    }
}

enum ShortcutCommand: String, Codable, Sendable {
    case generateAdvice
    case generateRandom
    case dailyChallenge
    case shareLastAdvice
    case openFavorites
    
    var description: String {
        switch self {
        case .generateAdvice: return "Generate bad advice"
        case .generateRandom: return "Generate random advice"
        case .dailyChallenge: return "Complete daily challenge"
        case .shareLastAdvice: return "Share last advice"
        case .openFavorites: return "Open favorites"
        }
    }
}

struct SiriIntent: Codable, Sendable {
    let command: ShortcutCommand
    let parameters: [String: String]
    let invokedAt: Date
}

struct ShareExtensionItem: Codable, Sendable {
    let type: ShareItemType
    let content: String
    let metadata: ShareMetadata?
    
    enum ShareItemType: String, Codable, Sendable {
        case advice
        case collection
        case challenge
        case battle
    }
    
    struct ShareMetadata: Codable, Sendable {
        let category: AdviceCategory?
        let tone: ToneMode?
        let creatorName: String?
    }
}

struct OnboardingQuiz: Identifiable, Codable, Sendable {
    let id: UUID
    let questions: [QuizQuestion]
    let completedAt: Date?
    let results: QuizResults?
    
    struct QuizQuestion: Identifiable, Codable, Sendable {
        let id: UUID
        let question: String
        let options: [QuizOption]
        
        struct QuizOption: Codable, Sendable {
            let text: String
            let category: AdviceCategory?
            let tone: ToneMode?
            let mood: MoodSuggestion?
        }
    }
    
    struct QuizResults: Codable, Sendable {
        let suggestedCategories: [AdviceCategory]
        let suggestedTones: [ToneMode]
        let suggestedMood: MoodSuggestion
        let personalityType: PersonalityType
        
        enum PersonalityType: String, Codable, Sendable {
            case chaoticRomantic
            case corporateGrifter
            case wellnessWarlock
            case techBro
            case retroRebel
            case minimalistMystic
        }
    }
}

struct TutorialChallenge: Identifiable, Codable, Sendable {
    let id: UUID
    let step: Int
    let title: String
    let description: String
    let action: TutorialAction
    let xpReward: Int
    let isCompleted: Bool
    
    enum TutorialAction: String, Codable, Sendable {
        case generateFirst
        case shareAdvice
        case favoriteAdvice
        case tryNewTone
        case tryNewCategory
        case startBattle
        case completeChallenge
    }
}

enum MonetizationTier: String, Codable, Sendable {
    case free
    case supporter
    case premium
    case pro
    
    var features: [String] {
        switch self {
        case .free:
            return ["Basic categories", "Basic tones", "Standard themes"]
        case .supporter:
            return ["All free features", "Tip developer", "Supporter badge", "Early access"]
        case .premium:
            return ["All supporter features", "Premium categories", "Custom tones", "Advanced sharing"]
        case .pro:
            return ["All premium features", "All categories/tones", "Pro themes", "Priority support"]
        }
    }
    
    var monthlyPrice: Double {
        switch self {
        case .free: return 0
        case .supporter: return 1.99
        case .premium: return 4.99
        case .pro: return 9.99
        }
    }
}

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

struct SeasonalPack: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let price: Double
    let categories: [AdviceCategory]
    let tones: [ToneMode]
    let isLimitedTime: Bool
    let availableUntil: Date?
    let icon: String
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

struct CategoryMastery: Codable, Sendable {
    let category: AdviceCategory
    var generationCount: Int
    var shareCount: Int
    var favoriteCount: Int
    var masteryLevel: MasteryLevel
    
    enum MasteryLevel: Int, Codable, Sendable {
        case novice = 0
        case apprentice = 1
        case journeyman = 2
        case expert = 3
        case master = 4
        case grandmaster = 5
        
        var title: String {
            switch self {
            case .novice: return "Novice"
            case .apprentice: return "Apprentice"
            case .journeyman: return "Journeyman"
            case .expert: return "Expert"
            case .master: return "Master"
            case .grandmaster: return "Grandmaster"
            }
        }
        
        var requiredGenerations: Int {
            switch self {
            case .novice: return 0
            case .apprentice: return 10
            case .journeyman: return 50
            case .expert: return 100
            case .master: return 250
            case .grandmaster: return 500
            }
        }
    }
    
    mutating func increment(type: IncrementType) {
        switch type {
        case .generation: generationCount += 1
        case .share: shareCount += 1
        case .favorite: favoriteCount += 1
        }
        updateMasteryLevel()
    }
    
    private mutating func updateMasteryLevel() {
        let total = generationCount + shareCount * 2 + favoriteCount * 3
        if total >= MasteryLevel.grandmaster.requiredGenerations {
            masteryLevel = .grandmaster
        } else if total >= MasteryLevel.master.requiredGenerations {
            masteryLevel = .master
        } else if total >= MasteryLevel.expert.requiredGenerations {
            masteryLevel = .expert
        } else if total >= MasteryLevel.journeyman.requiredGenerations {
            masteryLevel = .journeyman
        } else if total >= MasteryLevel.apprentice.requiredGenerations {
            masteryLevel = .apprentice
        } else {
            masteryLevel = .novice
        }
    }
    
    enum IncrementType {
        case generation
        case share
        case favorite
    }
}

struct ToneMastery: Codable, Sendable {
    let tone: ToneMode
    var usageCount: Int
    var masteryBadges: [ToneBadge]
    
    struct ToneBadge: Codable, Sendable {
        let name: String
        let description: String
        let earnedAt: Date
        let icon: String
    }
    
    mutating func earnBadge(_ badge: ToneBadge) {
        if !masteryBadges.contains(where: { $0.name == badge.name }) {
            masteryBadges.append(badge)
        }
    }
}

struct SurvivalMode: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let category: AdviceCategory
    let startedAt: Date
    var rounds: [SurvivalRound]
    var currentStreak: Int
    var isAlive: Bool
    
    var totalScore: Int { rounds.reduce(0) { $0 + $1.score } }
    
    struct SurvivalRound: Identifiable, Codable, Sendable {
        let id: UUID
        let advice: String
        let category: AdviceCategory
        let tone: ToneMode
        let submittedAt: Date
        let survived: Bool
        let votes: Int
        let score: Int
    }
    
    mutating func submitRound(advice: String, category: AdviceCategory, tone: ToneMode, survived: Bool, votes: Int) {
        let score = survived ? (10 + votes) : 0
        rounds.append(SurvivalRound(
            id: UUID(),
            advice: advice,
            category: category,
            tone: tone,
            submittedAt: Date(),
            survived: survived,
            votes: votes,
            score: score
        ))
        if survived {
            currentStreak += 1
        } else {
            isAlive = false
        }
    }
}

struct AdviceReaction: Identifiable, Codable, Sendable {
    let id: UUID
    let adviceID: UUID
    let userID: String
    let reaction: ReactionType
    let createdAt: Date
    
    enum ReactionType: String, Codable, Sendable {
        case laugh
        case shocked
        case cringe
        case fire
        case thinking
        case cry
        
        var emoji: String {
            switch self {
            case .laugh: return "😂"
            case .shocked: return "😱"
            case .cringe: return "😬"
            case .fire: return "🔥"
            case .thinking: return "🤔"
            case .cry: return "😭"
            }
        }
    }
}

struct AdviceComment: Identifiable, Codable, Sendable {
    let id: UUID
    let adviceID: UUID
    let userID: String
    let userName: String
    let text: String
    let createdAt: Date
    var replies: [CommentReply]
    var likes: Int
    
    struct CommentReply: Identifiable, Codable, Sendable {
        let id: UUID
        let userID: String
        let userName: String
        let text: String
        let createdAt: Date
        var likes: Int
    }
}

struct FriendActivity: Identifiable, Codable, Sendable {
    let id: UUID
    let friendID: String
    let friendName: String
    let activity: ActivityType
    let details: String?
    let timestamp: Date
    
    enum ActivityType: String, Codable, Sendable {
        case generatedAdvice
        case sharedAdvice
        case startedBattle
        case wonBattle
        case completedChallenge
        case unlockedAchievement
        case leveledUp
    }
}

struct BlockedUser: Codable, Sendable {
    let userID: String
    let blockedAt: Date
    let reason: String?
}

struct MutedUser: Codable, Sendable {
    let userID: String
    let mutedAt: Date
    let unmutedAt: Date?
}

struct BulkOperation: Codable, Sendable {
    let type: OperationType
    let targetIDs: [UUID]
    let status: OperationStatus
    let createdAt: Date
    let completedAt: Date?
    
    enum OperationType: String, Codable, Sendable {
        case favorite
        case unfavorite
        case delete
        case share
        case archive
    }
    
    enum OperationStatus: String, Codable, Sendable {
        case pending
        case inProgress
        case completed
        case failed
    }
}

struct ArchivedAdvice: Identifiable, Codable, Sendable {
    let id: UUID
    let originalAdviceID: UUID
    let adviceText: String
    let category: AdviceCategory
    let tone: ToneMode
    let archivedAt: Date
    let tags: [String]
}

struct AdviceTag: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let color: String
    let createdAt: Date
    let adviceIDs: [UUID]
}

struct SearchHistory: Codable, Sendable {
    var queries: [SearchQuery]
    var recentCategories: [AdviceCategory]
    var recentTones: [ToneMode]
    
    struct SearchQuery: Identifiable, Codable, Sendable {
        let id: UUID
        let query: String
        let timestamp: Date
        let resultCount: Int
    }
    
    mutating func addQuery(_ query: String, results: Int) {
        queries.insert(SearchQuery(id: UUID(), query: query, timestamp: Date(), resultCount: results), at: 0)
        if queries.count > 50 {
            queries = Array(queries.prefix(50))
        }
    }
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

struct PushNotification: Identifiable, Codable, Sendable {
    let id: UUID
    let type: NotificationType
    let title: String
    let body: String
    let data: [String: String]?
    let scheduledFor: Date?
    let sentAt: Date?
    
    enum NotificationType: String, Codable, Sendable {
        case dailyChallenge
        case friendActivity
        case streakWarning
        case trendingHighlight
        case battleInvite
        case challengeComplete
    }
}

struct DataExport: Identifiable, Codable, Sendable {
    let id: UUID
    let requestedAt: Date
    let status: ExportStatus
    let downloadURL: String?
    let expiresAt: Date?
    
    enum ExportStatus: String, Codable, Sendable {
        case pending
        case processing
        case ready
        case failed
    }
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

struct DataUsageDashboard: Codable, Sendable {
    let totalStorageUsed: Int64
    let adviceCount: Int
    let favoritesCount: Int
    let historyCount: Int
    let cacheSize: Int64
    let lastCleared: Date?
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

struct TestCoverage: Codable, Sendable {
    let unitTests: Int
    let uiTests: Int
    let codeCoverage: Double
    let lastRun: Date
    let failedTests: [String]
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

struct CrashReport: Identifiable, Codable, Sendable {
    let id: UUID
    let bundleVersion: String
    let osVersion: String
    let deviceModel: String
    let crashType: String
    let stackTrace: String
    let timestamp: Date
    let userDescription: String?
}
