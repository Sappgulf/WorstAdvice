import Foundation

enum AdviceCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case dating
    case fitness
    case career
    case money
    case parenting
    case tech
    case social
    case cooking
    case travel
    case productivity
    case pets
    case relationships
    case spirituality
    case financeCrypto
    /// Resolves to a random concrete category at generation time
    case random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dating: return "Dating"
        case .fitness: return "Fitness"
        case .career: return "Career"
        case .money: return "Money"
        case .parenting: return "Parenting"
        case .tech: return "Tech"
        case .social: return "Social"
        case .cooking: return "Cooking"
        case .travel: return "Travel"
        case .productivity: return "Productivity"
        case .pets: return "Pets"
        case .relationships: return "Relationships"
        case .spirituality: return "Spirituality"
        case .financeCrypto: return "Crypto"
        case .random: return "Random Mix"
        }
    }

    var icon: String {
        switch self {
        case .dating: return "heart"
        case .fitness: return "dumbbell"
        case .career: return "briefcase"
        case .money: return "dollarsign.circle"
        case .parenting: return "figure.2.and.child.holdinghands"
        case .tech: return "desktopcomputer"
        case .social: return "person.3"
        case .cooking: return "fork.knife"
        case .travel: return "airplane"
        case .productivity: return "checklist"
        case .pets: return "pawprint.fill"
        case .relationships: return "heart.circle"
        case .spirituality: return "star.fill"
        case .financeCrypto: return "bitcoinsign.circle"
        case .random: return "shuffle"
        }
    }

    var isPremium: Bool {
        switch self {
        case .pets, .relationships, .spirituality, .financeCrypto: return true
        default: return false
        }
    }

    /// All concrete (non-random) categories.
    static var concrete: [AdviceCategory] {
        allCases.filter { $0 != .random }
    }

    /// Resolves `.random` to an actual category using the provided seed.
    func resolved(seed: Int) -> AdviceCategory {
        guard self == .random else { return self }
        let pool = AdviceCategory.concrete
        return pool[seed.positiveModulo(pool.count)]
    }
}

enum ToneMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case corporateConsultant
    case alphaPodcast
    case wizard
    case influencer
    case toxicBestFriend
    case boomer
    case cryptoBro
    case minimalistMonk
    case friendRoast
    case lifeCoach
    case conspiracyTheorist
    case genZ
    case redditCommenter
    case linkedInInfluencer
    /// Resolves to a random concrete tone at generation time
    case random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .corporateConsultant: return "Corporate Consultant"
        case .alphaPodcast: return "Alpha Podcast"
        case .wizard: return "Wizard"
        case .influencer: return "Influencer"
        case .toxicBestFriend: return "Toxic Best Friend"
        case .boomer: return "Boomer"
        case .cryptoBro: return "Crypto Bro"
        case .minimalistMonk: return "Minimalist Monk"
        case .friendRoast: return "Friend Roast"
        case .lifeCoach: return "Life Coach"
        case .conspiracyTheorist: return "Conspiracy Theorist"
        case .genZ: return "Gen Z"
        case .redditCommenter: return "Reddit Commenter"
        case .linkedInInfluencer: return "LinkedIn Influencer"
        case .random: return "Random Mix"
        }
    }

    var isPremium: Bool {
        switch self {
        case .genZ, .redditCommenter, .linkedInInfluencer: return true
        default: return false
        }
    }

    /// All concrete (non-random) tones
    static var concrete: [ToneMode] {
        allCases.filter { $0 != .random }
    }

    /// Resolves `.random` to an actual tone using the provided seed.
    func resolved(seed: Int) -> ToneMode {
        guard self == .random else { return self }
        let pool = ToneMode.concrete
        return pool[seed.positiveModulo(pool.count)]
    }
}

enum ThemeMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case badvice
    case minimal
    case ember
    case slate
    case evergreen
    case fallout
    case neon
    case midnight
    case sunset
    case cosmic
    case retro
    case cybernetic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .badvice: return "Badvice"
        case .minimal: return "Minimal"
        case .ember: return "Ember"
        case .slate: return "Slate"
        case .evergreen: return "Evergreen"
        case .fallout: return "Fallout"
        case .neon: return "Neon Nights"
        case .midnight: return "Midnight Oil"
        case .sunset: return "Golden Hour"
        case .cosmic: return "Cosmic Chaos"
        case .retro: return "Retro Wave"
        case .cybernetic: return "Cybernetic"
        }
    }
}

enum ShareCardTemplate: String, CaseIterable, Codable, Identifiable, Sendable {
    case minimal
    case gradient
    case bold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: return "Minimal"
        case .gradient: return "Gradient"
        case .bold: return "Bold"
        }
    }
}

enum ShareAspectRatio: String, CaseIterable, Codable, Identifiable, Sendable {
    case square
    case story

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: return "Square"
        case .story: return "Story"
        }
    }
}

enum ShareCaptionPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case deadpan
    case chaotic
    case fauxExpert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deadpan: return "Deadpan"
        case .chaotic: return "Chaotic"
        case .fauxExpert: return "Faux Expert"
        }
    }
}

enum ContentPack: String, CaseIterable, Codable, Identifiable, Sendable {
    case classic
    case officeMeltdown
    case weekendChaos
    case chronicallyOnline
    case cyberInfluence
    case valentine
    case halloween
    case aprilFools
    case newYear
    case summerVibes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .officeMeltdown: return "Office Meltdown"
        case .weekendChaos: return "Weekend Chaos"
        case .chronicallyOnline: return "Chronically Online"
        case .cyberInfluence: return "Cyber Influence"
        case .valentine: return "Valentine's Day"
        case .halloween: return "Halloween"
        case .aprilFools: return "April Fools"
        case .newYear: return "New Year"
        case .summerVibes: return "Summer Vibes"
        }
    }

    var icon: String {
        switch self {
        case .classic: return "sparkles"
        case .officeMeltdown: return "building.2"
        case .weekendChaos: return "party.popper"
        case .chronicallyOnline: return "globe"
        case .cyberInfluence: return "brain"
        case .valentine: return "heart.fill"
        case .halloween: return "ghost.fill"
        case .aprilFools: return "face.smiling.inverse"
        case .newYear: return "fireworks"
        case .summerVibes: return "sun.max.fill"
        }
    }

    var isSeasonal: Bool {
        switch self {
        case .valentine, .halloween, .aprilFools, .newYear, .summerVibes:
            return true
        default:
            return false
        }
    }

    var availableMonths: Set<Int>? {
        switch self {
        case .valentine: return Set(1...2)
        case .halloween: return [10]
        case .aprilFools: return [4]
        case .newYear: return [12, 1]
        case .summerVibes: return Set(6...8)
        default: return nil
        }
    }
}

enum AdviceGenerationProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case auto
    case classic
    case appleOnDevice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .classic: return "Classic"
        case .appleOnDevice: return "Apple On-Device"
        }
    }
}

enum AdviceVoteState: Int, CaseIterable, Codable, Identifiable, Sendable {
    case none = 0
    case like = 1
    case dislike = -1

    var id: Int { rawValue }
}

enum LearningSignalType: String, CaseIterable, Codable, Identifiable, Sendable {
    case shown
    case like
    case dislike
    case favorite
    case copy
    case share
    case regen

    var id: String { rawValue }
}

struct ChaosContract: Identifiable, Sendable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let icon: String
    let category: AdviceCategory?
    let tone: ToneMode?
    let contentPack: ContentPack?
    let reward: String
}

struct LearningWeightProfile: Sendable {
    let semanticWeight: Double
    let explicitWeight: Double
    let implicitWeight: Double
    let noveltyWeight: Double
    let explorationWeight: Double
    let recencyWeight: Double
    let dislikePenaltyWeight: Double
    let favoriteBonusWeight: Double
    let copyBonusWeight: Double
    let shareBonusWeight: Double
    let regenPenaltyWeight: Double

    static let balanced = LearningWeightProfile(
        semanticWeight: 0.44,
        explicitWeight: 0.34,
        implicitWeight: 0.12,
        noveltyWeight: 0.10,
        explorationWeight: 0.08,
        recencyWeight: 0.06,
        dislikePenaltyWeight: 1.00,
        favoriteBonusWeight: 0.65,
        copyBonusWeight: 0.35,
        shareBonusWeight: 0.50,
        regenPenaltyWeight: 0.18
    )

    /// Converged profile for users with rich signal history — leans on learned preferences.
    static let converged = LearningWeightProfile(
        semanticWeight: 0.36,
        explicitWeight: 0.48,
        implicitWeight: 0.16,
        noveltyWeight: 0.08,
        explorationWeight: 0.04,
        recencyWeight: 0.08,
        dislikePenaltyWeight: 1.20,
        favoriteBonusWeight: 0.80,
        copyBonusWeight: 0.45,
        shareBonusWeight: 0.60,
        regenPenaltyWeight: 0.25
    )

    /// Explorer profile for new users or when generating in unexplored category/tone combos.
    static let explorer = LearningWeightProfile(
        semanticWeight: 0.50,
        explicitWeight: 0.22,
        implicitWeight: 0.08,
        noveltyWeight: 0.12,
        explorationWeight: 0.18,
        recencyWeight: 0.04,
        dislikePenaltyWeight: 0.80,
        favoriteBonusWeight: 0.50,
        copyBonusWeight: 0.25,
        shareBonusWeight: 0.40,
        regenPenaltyWeight: 0.12
    )
}

enum AppTab: String, CaseIterable, Codable, Identifiable, Sendable {
    case generate
    case chaosHub
    case explore
    case groupChallenges
    case friends
    case quotes
    case favorites
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generate: return "Advice"
        case .chaosHub: return "Chaos Hub"
        case .explore: return "Explore"
        case .groupChallenges: return "Challenges"
        case .friends: return "Friends"
        case .quotes: return "Quotes"
        case .favorites: return "Favorites"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var compactTitle: String {
        switch self {
        case .generate: return "Advice"
        case .chaosHub: return "Hub"
        case .explore: return "Explore"
        case .groupChallenges: return "Challenges"
        case .friends: return "Friends"
        case .quotes: return "Quotes"
        case .favorites: return "Saved"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .generate: return "sparkles"
        case .chaosHub: return "flame.fill"
        case .explore: return "magnifyingglass"
        case .groupChallenges: return "person.3.fill"
        case .friends: return "person.2.fill"
        case .quotes: return "quote.bubble"
        case .favorites: return "bookmark.fill"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }

    static let defaultOrder: [AppTab] = [
        .generate, .chaosHub, .explore, .groupChallenges, .friends, .quotes, .favorites, .history, .settings,
    ]

    static let primaryNavigationTabs: [AppTab] = [
        .generate, .friends, .chaosHub, .quotes,
    ]

    static let brandMenuTabs: [AppTab] = [
        .favorites, .history, .explore, .groupChallenges, .settings,
    ]
}

enum QuoteRankingMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case recent
    case topLiked
    case topDisliked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "Recent"
        case .topLiked: return "Top Liked"
        case .topDisliked: return "Top Disliked"
        }
    }
}

enum QuoteSourceDebugFilter: String, CaseIterable, Codable, Identifiable, Sendable {
    case all
    case appleModel
    case remixLab
    case community
    case curated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .appleModel: return "Apple Model"
        case .remixLab: return "Remix"
        case .community: return "Community"
        case .curated: return "Curated"
        }
    }
}

struct CategoryRuleSet: Sendable {
    let badPrinciples: [String]
    let keywords: [String]
    let forbiddenPatterns: [String]
    let actionTemplates: [String]
    let rationaleTemplates: [String]

    func merged(with augment: CategoryRuleAugment) -> CategoryRuleSet {
        CategoryRuleSet(
            badPrinciples: badPrinciples + augment.badPrinciples,
            keywords: keywords + augment.keywords,
            forbiddenPatterns: forbiddenPatterns,
            actionTemplates: actionTemplates + augment.actionTemplates,
            rationaleTemplates: rationaleTemplates + augment.rationaleTemplates
        )
    }
}

struct CategoryRuleAugment: Sendable {
    let badPrinciples: [String]
    let keywords: [String]
    let actionTemplates: [String]
    let rationaleTemplates: [String]
}

struct ToneProfile: Sendable {
    let opener: [String]
    let confidenceTag: [String]
    let rhetoricalTick: [String]
    let ending: [String]
    let slang: [String]
}

struct GeneratedAdvice: Identifiable, Equatable, Sendable {
    let id: UUID
    let category: AdviceCategory
    let tone: ToneMode
    let adviceLine: String
    let rationaleLine: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        category: AdviceCategory,
        tone: ToneMode,
        adviceLine: String,
        rationaleLine: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.tone = tone
        self.adviceLine = adviceLine
        self.rationaleLine = rationaleLine
        self.createdAt = createdAt
    }
}

struct ShareCardContent: Sendable {
    let category: AdviceCategory
    let tone: ToneMode
    let adviceLine: String
    let rationaleLine: String?
    let includeDisclaimer: Bool
    let template: ShareCardTemplate
    let aspectRatio: ShareAspectRatio
}

struct BadQuote: Identifiable, Hashable, Sendable {
    let id: String
    let text: String
    let source: String
    let category: AdviceCategory
}

extension String {
    var normalizedForFiltering: String {
        lowercased().folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

// MARK: - Achievements System
