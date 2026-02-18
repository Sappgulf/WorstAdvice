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
        }
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
        case .random: return "Random Mix"
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .officeMeltdown: return "Office Meltdown"
        case .weekendChaos: return "Weekend Chaos"
        case .chronicallyOnline: return "Chronically Online"
        case .cyberInfluence: return "Cyber Influence"
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
    case quotes
    case favorites
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generate: return "Advice"
        case .chaosHub: return "Chaos Hub"
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
        case .quotes: return "quote.bubble"
        case .favorites: return "bookmark.fill"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }

    static let defaultOrder: [AppTab] = [.generate, .chaosHub, .quotes, .favorites, .history, .settings]
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

// MARK: - Unlockable Themes

enum UnlockableTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case neon
    case midnight
    case sunset
    case cosmic
    case retro
    
    var id: String { rawValue }
    
    var requiredAchievement: AchievementType? {
        switch self {
        case .neon: return .dailyStreak7
        case .midnight: return .hundredAdvice
        case .sunset: return .categoryMaster
        case .cosmic: return nil // Purchase or special event
        case .retro: return nil // Special code
        }
    }
    
    var displayName: String {
        switch self {
        case .neon: return "Neon Nights"
        case .midnight: return "Midnight Oil"
        case .sunset: return "Golden Hour"
        case .cosmic: return "Cosmic Chaos"
        case .retro: return "Retro Wave"
        }
    }
    
    var description: String {
        switch self {
        case .neon: return "7-day streak unlock"
        case .midnight: return "100 advice generations unlock"
        case .sunset: return "All categories unlock"
        case .cosmic: return "Limited edition"
        case .retro: return "Secret unlock"
        }
    }
}
