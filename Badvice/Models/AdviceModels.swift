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
        return pool[abs(seed) % pool.count]
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
        return pool[abs(seed) % pool.count]
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

    var availableMonths: ClosedRange<Int>? {
        switch self {
        case .valentine: return 1...2
        case .halloween: return 10...10
        case .aprilFools: return 4...4
        case .newYear: return 12...1
        case .summerVibes: return 6...8
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
