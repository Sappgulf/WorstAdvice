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
        .explore, .groupChallenges, .favorites, .history, .settings,
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
        lowercased().folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

// MARK: - Achievements System

enum AchievementType: String, CaseIterable, Codable, Identifiable, Sendable {
    case firstAdvice = "first_advice"
    case tenAdvice = "ten_advice"
    case hundredAdvice = "hundred_advice"
    case firstSave = "first_save"
    case collector = "collector"
    case hoarder = "hoarder"
    case sharer = "sharer"
    case viral = "viral"
    case dailyStreak3 = "streak_3"
    case dailyStreak7 = "streak_7"
    case dailyStreak14 = "streak_14"
    case dailyStreak30 = "streak_30"
    case toneExplorer = "tone_explorer"
    case categoryMaster = "category_master"
    case nightOwl = "night_owl"
    case earlyBird = "early_bird"
    case shakeItOff = "shake_it_off"
    case suggestionAccepted = "suggestion_accepted"
    case bugHunter = "bug_hunter"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .firstAdvice: return "First Mistake"
        case .tenAdvice: return "Serial Offender"
        case .hundredAdvice: return "Chaos Connoisseur"
        case .firstSave: return "Bookmarked Badness"
        case .collector: return "Curator of Catastrophe"
        case .hoarder: return "Advice Archivist"
        case .sharer: return "Spread the Badness"
        case .viral: return "Going Viral"
        case .dailyStreak3: return "3-Day Bender"
        case .dailyStreak7: return "Weekly Chaos"
        case .dailyStreak14: return "Two Weeks of Trouble"
        case .dailyStreak30: return "Monthly Madness"
        case .toneExplorer: return "Voice Actor"
        case .categoryMaster: return "Jack of All Trades"
        case .nightOwl: return "Midnight Badvice"
        case .earlyBird: return "Early Bird Gets the Burn"
        case .shakeItOff: return "Shake It Off"
        case .suggestionAccepted: return "Community Contributor"
        case .bugHunter: return "Bug Hunter"
        }
    }
    
    var description: String {
        switch self {
        case .firstAdvice: return "Generate your first bad advice"
        case .tenAdvice: return "Generate 10 pieces of bad advice"
        case .hundredAdvice: return "Generate 100 pieces of bad advice"
        case .firstSave: return "Save your first bad advice"
        case .collector: return "Save 10 pieces of bad advice"
        case .hoarder: return "Save 50 pieces of bad advice"
        case .sharer: return "Share bad advice 5 times"
        case .viral: return "Share bad advice 25 times"
        case .dailyStreak3: return "Use Badvice for 3 days in a row"
        case .dailyStreak7: return "Use Badvice for 7 days in a row"
        case .dailyStreak14: return "Use Badvice for 14 days in a row"
        case .dailyStreak30: return "Use Badvice for 30 days in a row"
        case .toneExplorer: return "Try all 11 different tones (excluding Random Mix)"
        case .categoryMaster: return "Generate advice in all 10 categories"
        case .nightOwl: return "Generate advice after midnight"
        case .earlyBird: return "Generate advice before 6 AM"
        case .shakeItOff: return "Use shake to generate advice"
        case .suggestionAccepted: return "Submit a community suggestion"
        case .bugHunter: return "Generate advice with a technical glitch"
        }
    }
    
    var icon: String {
        switch self {
        case .firstAdvice: return "sparkles"
        case .tenAdvice: return "10.circle.fill"
        case .hundredAdvice: return "100.circle.fill"
        case .firstSave: return "bookmark.fill"
        case .collector: return "folder.fill"
        case .hoarder: return "archivebox.fill"
        case .sharer: return "square.and.arrow.up.fill"
        case .viral: return "flame.fill"
        case .dailyStreak3: return "3.circle.fill"
        case .dailyStreak7: return "7.circle.fill"
        case .dailyStreak14: return "14.circle.fill"
        case .dailyStreak30: return "30.circle.fill"
        case .toneExplorer: return "theatermasks.fill"
        case .categoryMaster: return "checkmark.circle.fill"
        case .nightOwl: return "moon.fill"
        case .earlyBird: return "sunrise.fill"
        case .shakeItOff: return "iphone.gen3.radiowaves.left.and.right"
        case .suggestionAccepted: return "person.2.fill"
        case .bugHunter: return "ant.fill"
        }
    }
    
    var unlocksTheme: ThemeMode? {
        switch self {
        case .dailyStreak7: return .neon
        case .hundredAdvice: return .midnight
        case .categoryMaster: return .sunset
        case .bugHunter: return .cybernetic
        default: return nil
        }
    }
    
    var isSecret: Bool {
        // Secret achievements that aren't revealed until unlocked
        self == .nightOwl || self == .earlyBird
    }
}

struct Achievement: Identifiable, Codable, Sendable {
    let type: AchievementType
    var unlockedAt: Date?
    var progress: Int
    let target: Int
    
    var id: String { type.rawValue }
    var isUnlocked: Bool { unlockedAt != nil }
    var progressPercent: Double {
        Double(progress) / Double(target)
    }
}

struct DailyChallenge: Identifiable, Codable, Sendable {
    let id: UUID
    let category: AdviceCategory
    let tone: ToneMode
    let title: String
    let description: String
    let expiresAt: Date
    let bonusPoints: Int
    
    var isExpired: Bool { Date() > expiresAt }
    
    static func generateForToday() -> DailyChallenge {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: today) ?? 1
        
        let categories = AdviceCategory.concrete
        let tones = ToneMode.concrete
        
        let category = categories[dayOfYear % categories.count]
        let tone = tones[dayOfYear % tones.count]
        
        let titles = [
            "Wizard Wednesday", "Toxic Tuesday", "Alpha Friday",
            "Boomer Monday", "Crypto Chaos", "Wizard Wisdom"
        ]
        let title = titles[dayOfYear % titles.count]
        
        return DailyChallenge(
            id: UUID(),
            category: category,
            tone: tone,
            title: title,
            description: "Get bad \(category.title) advice in \(tone.title) tone",
            expiresAt: calendar.date(byAdding: .day, value: 1, to: today) ?? today,
            bonusPoints: 50
        )
    }
}

struct GroupChallenge: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let inviteCode: String
    let category: AdviceCategory
    let tone: ToneMode
    let creatorID: String
    let participantIDs: [String]
    let startedAt: Date
    let endsAt: Date
    let leaderboard: [ChallengeEntry]
    
    var isActive: Bool { Date() < endsAt }
}

struct ChallengeEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let userID: String
    let userName: String
    let adviceCount: Int
    let totalLikes: Int
    
    var score: Int { adviceCount * 10 + totalLikes * 5 }
}

struct StreakCard: Identifiable, Codable, Sendable {
    let id: UUID
    let currentStreak: Int
    let longestStreak: Int
    let totalGenerated: Int
    let generatedAt: Date
    
    var streakTier: StreakTier {
        switch currentStreak {
        case 0..<3: return .bronze
        case 3..<7: return .silver
        case 7..<14: return .gold
        case 14..<30: return .platinum
        default: return .diamond
        }
    }
}

enum StreakTier: String, Codable, Sendable {
    case bronze, silver, gold, platinum, diamond
    
    var icon: String {
        switch self {
        case .bronze: return "circle.fill"
        case .silver: return "circle.fill"
        case .gold: return "star.fill"
        case .platinum: return "sparkles"
        case .diamond: return "crown.fill"
        }
    }
}

struct TrendingAdvice: Identifiable, Codable, Sendable {
    let id: UUID
    let adviceLine: String
    let category: AdviceCategory
    let tone: ToneMode
    let likeCount: Int
    let shareCount: Int
    let generatedAt: Date
}

enum PremiumTier: String, Codable, Sendable {
    case free
    case premium
    case pro
    
    var unlockedCategories: [AdviceCategory] {
        switch self {
        case .free: return []
        case .premium: return [.pets, .relationships]
        case .pro: return AdviceCategory.concrete.filter { $0 != .random }
        }
    }
    
    var unlockedTones: [ToneMode] {
        switch self {
        case .free: return []
        case .premium: return [.genZ, .redditCommenter]
        case .pro: return ToneMode.concrete.filter { $0 != .random }
        }
    }
}

struct UserLevel: Codable, Sendable {
    let currentLevel: Int
    let currentXP: Int
    let totalXPEarned: Int
    
    var xpForNextLevel: Int {
        (currentLevel + 1) * 100
    }
    
    var xpProgress: Double {
        guard xpForNextLevel > 0 else { return 1.0 }
        return Double(currentXP) / Double(xpForNextLevel)
    }
    
    var title: String {
        switch currentLevel {
        case 0..<5: return "Novice Chaotic"
        case 5..<10: return "Apprentice Fool"
        case 10..<20: return "Journeyman Blunderer"
        case 20..<30: return "Expert Mishap"
        case 30..<50: return "Master Debacle"
        case 50..<75: return "Grandmaster Gaffe"
        default: return "Chaos Legend"
        }
    }
}

enum XPReason: String, Codable, Sendable {
    case generateAdvice = "generated_advice"
    case shareAdvice = "shared_advice"
    case favoriteAdvice = "favorited_advice"
    case dailyChallenge = "daily_challenge"
    case groupChallenge = "group_challenge"
    case battleWin = "battle_win"
    case streakBonus = "streak_bonus"
    case achievementUnlock = "achievement"
    case questComplete = "quest_complete"
    
    var xpAmount: Int {
        switch self {
        case .generateAdvice: return 5
        case .shareAdvice: return 10
        case .favoriteAdvice: return 2
        case .dailyChallenge: return 25
        case .groupChallenge: return 15
        case .battleWin: return 50
        case .streakBonus: return 20
        case .achievementUnlock: return 100
        case .questComplete: return 30
        }
    }
}

struct DailyQuest: Identifiable, Codable, Sendable {
    let id: UUID
    let type: QuestType
    let target: Int
    let xpReward: Int
    let expiresAt: Date
    
    var progress: Int = 0
    var isCompleted: Bool { progress >= target }
    
    enum QuestType: String, Codable, Sendable {
        case generate
        case share
        case favorite
        case useSpecificCategory
        case useSpecificTone
        case battle
        case inviteFriend
    }
    
    var title: String {
        switch type {
        case .generate: return "Generate \(target) pieces of advice"
        case .share: return "Share \(target) advice"
        case .favorite: return "Favorite \(target) advice"
        case .useSpecificCategory: return "Use a specific category"
        case .useSpecificTone: return "Try a new tone"
        case .battle: return "Win \(target) battles"
        case .inviteFriend: return "Invite \(target) friends"
        }
    }
}

struct Battle: Identifiable, Codable, Sendable {
    let id: UUID
    let challengerID: String
    let challengerName: String
    let challengedID: String
    let challengedName: String
    let category: AdviceCategory
    let tone: ToneMode
    let challengerAdvice: String
    let challengedAdvice: String
    let votes: BattleVotes
    let startedAt: Date
    let endsAt: Date
    
    var isActive: Bool { Date() < endsAt }
    
    struct BattleVotes: Codable, Sendable {
        var challengerVotes: Int
        var challengedVotes: Int
    }
}

struct PublicProfile: Identifiable, Codable, Sendable {
    let id: UUID
    let handle: String
    let displayName: String
    let avatarURL: String?
    let level: UserLevel
    let totalAdviceGenerated: Int
    let totalShares: Int
    let battlesWon: Int
    let joinedAt: Date
    
    var bio: String?
    var favoriteCategory: AdviceCategory?
    var favoriteTone: ToneMode?
}

enum AccessibilitySettings: Codable, Sendable {
    case standard
    case voiceOver
    case reducedMotion
    case reducedData
    case highContrast
    case customGestures
    
    var description: String {
        switch self {
        case .standard: return "Standard accessibility"
        case .voiceOver: return "Full VoiceOver support"
        case .reducedMotion: return "Minimal animations"
        case .reducedData: return "Reduced data usage"
        case .highContrast: return "High contrast mode"
        case .customGestures: return "Custom gesture support"
        }
    }
}

enum ShareFormat: String, Codable, Sendable {
    case image
    case video
    case text
    case instagramStory
    case sticker
    
    var exportAction: String {
        switch self {
        case .image: return "Export as image"
        case .video: return "Export as video"
        case .text: return "Copy as text"
        case .instagramStory: return "Share to Stories"
        case .sticker: return "Create sticker"
        }
    }
}

struct ShareOptions: Codable, Sendable {
    var format: ShareFormat
    var includeWatermark: Bool
    var watermarkText: String
    var includeCategory: Bool
    var includeTone: Bool
    var backgroundColor: String
    var textColor: String
    
    static let `default` = ShareOptions(
        format: .image,
        includeWatermark: true,
        watermarkText: "Badvice",
        includeCategory: true,
        includeTone: true,
        backgroundColor: "#000000",
        textColor: "#FFFFFF"
    )
}

enum MoodSuggestion: String, Codable, Sendable {
    case chaotic
    case reflective
    case motivated
    case bored
    case social
    case competitive
    
    var suggestedCategories: [AdviceCategory] {
        switch self {
        case .chaotic: return [.dating, .social]
        case .reflective: return [.career, .productivity]
        case .motivated: return [.fitness, .money]
        case .bored: return [.cooking, .travel]
        case .social: return [.dating, .parenting]
        case .competitive: return [.tech, .career]
        }
    }
}

struct TimeOfDayRecommendation: Codable, Sendable {
    let hour: Int
    
    var suggestedCategory: AdviceCategory {
        switch hour {
        case 6..<10: return .productivity
        case 10..<14: return .career
        case 14..<17: return .tech
        case 17..<21: return .dating
        default: return .social
        }
    }
    
    var suggestedTone: ToneMode {
        switch hour {
        case 6..<10: return .minimalistMonk
        case 10..<14: return .corporateConsultant
        case 14..<17: return .alphaPodcast
        case 21..<24: return .toxicBestFriend
        default: return .boomer
        }
    }
}

struct WeeklyHighlight: Identifiable, Codable, Sendable {
    let id: UUID
    let adviceLine: String
    let category: AdviceCategory
    let tone: ToneMode
    let authorID: String
    let authorName: String
    let likeCount: Int
    let weekStartDate: Date
    
    var isFeatured: Bool { likeCount > 100 }
}

struct UserVote: Identifiable, Codable, Sendable {
    let id: UUID
    let targetID: UUID
    let targetType: VoteType
    let voteValue: Int
    let votedAt: Date
    
    enum VoteType: String, Codable, Sendable {
        case advice
        case quote
        case battle
    }
}

struct UserPreferences: Codable, Sendable {
    var preferredCategories: [AdviceCategory]
    var preferredTones: [ToneMode]
    var engagementHistory: [EngagementRecord]
    var remixCount: Int
    var lastRemixDate: Date?
    
    mutating func recordEngagement(_ type: EngagementRecord.EngagementType, category: AdviceCategory, tone: ToneMode) {
        engagementHistory.append(EngagementRecord(type: type, category: category, tone: tone, timestamp: Date()))
    }
    
    mutating func suggestImprovements(for advice: String, category: AdviceCategory, tone: ToneMode) -> [String] {
        var suggestions: [String] = []
        if let lastTone = preferredTones.last {
            suggestions.append("Try \(lastTone.title) tone for more contrast")
        }
        if engagementHistory.count > 10 {
            if let topCategory = engagementHistory.map(\.category).mostCommon() as AdviceCategory?, topCategory != category {
                suggestions.append("You usually like \(topCategory.title), try that!")
            }
        }
        suggestions.append("Add a dramatic opening phrase")
        suggestions.append("End with an absurd certainty")
        return suggestions
    }
}

enum EngagementType: String, Codable, Sendable {
    case generated
    case shared
    case favorited
    case remixed
    case battleEntry
}

struct EngagementRecord: Codable, Sendable {
    let type: EngagementType
    let category: AdviceCategory
    let tone: ToneMode
    let timestamp: Date
    
    enum EngagementType: String, Codable, Sendable {
        case generated
        case shared
        case favorited
        case remixed
        case battleEntry
    }
}

extension Array where Element: Hashable {
    func mostCommon() -> Element? {
        let counts = reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

struct AdviceRemix: Identifiable, Codable, Sendable {
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
