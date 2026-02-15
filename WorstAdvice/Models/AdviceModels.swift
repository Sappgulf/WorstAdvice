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
        }
    }
}

enum ThemeMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case badvice
    case minimal
    case ember
    case slate
    case evergreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .badvice: return "Badvice"
        case .minimal: return "Minimal"
        case .ember: return "Ember"
        case .slate: return "Slate"
        case .evergreen: return "Evergreen"
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .officeMeltdown: return "Office Meltdown"
        case .weekendChaos: return "Weekend Chaos"
        case .chronicallyOnline: return "Chronically Online"
        }
    }
}

enum AdviceVoteState: Int, CaseIterable, Codable, Identifiable, Sendable {
    case none = 0
    case like = 1
    case dislike = -1

    var id: Int { rawValue }
}

enum AppTab: String, CaseIterable, Codable, Identifiable, Sendable {
    case generate
    case quotes
    case favorites
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .generate: return "Advice"
        case .quotes: return "Quotes"
        case .favorites: return "Favorites"
        case .history: return "History"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .generate: return "sparkles"
        case .quotes: return "quote.bubble"
        case .favorites: return "bookmark.fill"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }

    static let defaultOrder: [AppTab] = [.generate, .quotes, .favorites, .history, .settings]
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
