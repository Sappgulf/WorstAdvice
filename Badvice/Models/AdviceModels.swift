import AppIntents
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
    case gaming
    case weddings
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
        case .gaming: return "Gaming"
        case .weddings: return "Weddings"
        case .random: return "Random Mix"
        }
    }

    var icon: String {
        switch self {
        case .dating: return "heart.fill"
        case .fitness: return "dumbbell.fill"
        case .career: return "briefcase.fill"
        case .money: return "dollarsign.circle.fill"
        case .parenting: return "figure.2.and.child.holdinghands"
        case .tech: return "desktopcomputer"
        case .social: return "person.3.fill"
        case .cooking: return "fork.knife"
        case .travel: return "airplane"
        case .productivity: return "checklist"
        case .pets: return "pawprint.fill"
        case .relationships: return "person.2.fill"
        case .spirituality: return "star.fill"
        case .financeCrypto: return "bitcoinsign.circle.fill"
        case .gaming: return "gamecontroller.fill"
        case .weddings: return "party.popper.fill"
        case .random: return "shuffle"
        }
    }

    var isPremium: Bool {
        switch self {
        case .pets, .relationships, .spirituality, .financeCrypto, .gaming, .weddings: return true
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
    case astrologyGirlie
    case oldMoney
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
        case .astrologyGirlie: return "Astrology Girlie"
        case .oldMoney: return "Old Money"
        case .random: return "Random Mix"
        }
    }

    var isPremium: Bool {
        switch self {
        case .genZ, .redditCommenter, .linkedInInfluencer, .astrologyGirlie, .oldMoney: return true
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

/// A small, deterministic personality descriptor for each advice voice.
///
/// The generator stays fully local: `ToneMode` still controls the actual
/// engine rules, while this value type gives the UI a memorable, human-sized
/// way to explain what each model sounds like.
struct AdviceVoice: Identifiable, Hashable, Sendable {
    let tone: ToneMode
    let name: String
    let descriptor: String
    let systemImage: String
    let intensity: Int

    var id: String { tone.rawValue }

    static func profile(for tone: ToneMode) -> AdviceVoice {
        switch tone {
        case .corporateConsultant:
            return AdviceVoice(tone: tone, name: "The Operator", descriptor: "Turns every feeling into a quarterly initiative.", systemImage: "briefcase.fill", intensity: 3)
        case .alphaPodcast:
            return AdviceVoice(tone: tone, name: "The Alpha", descriptor: "Confuses volume with evidence and calls it leadership.", systemImage: "mic.fill", intensity: 5)
        case .wizard:
            return AdviceVoice(tone: tone, name: "The Wizard", descriptor: "Solves ordinary problems with unnecessary ceremony.", systemImage: "wand.and.stars", intensity: 4)
        case .influencer:
            return AdviceVoice(tone: tone, name: "The Main Character", descriptor: "Optimizes the story before checking what happened.", systemImage: "camera.fill", intensity: 4)
        case .toxicBestFriend:
            return AdviceVoice(tone: tone, name: "The Menace", descriptor: "Would absolutely make this worse for your growth.", systemImage: "flame.fill", intensity: 5)
        case .boomer:
            return AdviceVoice(tone: tone, name: "The Dad", descriptor: "Has one story, three rules, and no follow-up questions.", systemImage: "radio.fill", intensity: 2)
        case .cryptoBro:
            return AdviceVoice(tone: tone, name: "The Moon Boy", descriptor: "Treats every decision like a once-in-a-lifetime pump.", systemImage: "chart.line.uptrend.xyaxis", intensity: 5)
        case .minimalistMonk:
            return AdviceVoice(tone: tone, name: "The Monk", descriptor: "Removes the problem, the context, and most of the furniture.", systemImage: "circle.dotted", intensity: 1)
        case .friendRoast:
            return AdviceVoice(tone: tone, name: "The Bestie", descriptor: "Says the quiet part out loud, then adds a little seasoning.", systemImage: "person.2.fill", intensity: 4)
        case .lifeCoach:
            return AdviceVoice(tone: tone, name: "The Optimist", descriptor: "Believes a fresh mindset can solve an old spreadsheet.", systemImage: "sun.max.fill", intensity: 3)
        case .conspiracyTheorist:
            return AdviceVoice(tone: tone, name: "The Pattern", descriptor: "Connects unrelated dots with alarming confidence.", systemImage: "eye.fill", intensity: 5)
        case .genZ:
            return AdviceVoice(tone: tone, name: "The Timeline", descriptor: "Chronically online, emotionally precise, spiritually buffering.", systemImage: "bolt.horizontal.fill", intensity: 4)
        case .redditCommenter:
            return AdviceVoice(tone: tone, name: "The Commenter", descriptor: "Has read half the thread and formed a legal opinion.", systemImage: "bubble.left.and.bubble.right.fill", intensity: 3)
        case .linkedInInfluencer:
            return AdviceVoice(tone: tone, name: "The Thought Leader", descriptor: "Starts with a hook and ends with a humblebrag.", systemImage: "person.crop.circle.badge.checkmark", intensity: 4)
        case .astrologyGirlie:
            return AdviceVoice(tone: tone, name: "The Star Chart", descriptor: "Blames the moon, then makes a very specific plan.", systemImage: "moon.stars.fill", intensity: 3)
        case .oldMoney:
            return AdviceVoice(tone: tone, name: "The Heir", descriptor: "Would never rush a decision, especially in public.", systemImage: "seal.fill", intensity: 2)
        case .random:
            return AdviceVoice(tone: tone, name: "The Blender", descriptor: "A rotating panel of confident specialists with no oversight.", systemImage: "shuffle", intensity: 4)
        }
    }
}

extension ToneMode {
    var voice: AdviceVoice { AdviceVoice.profile(for: self) }
}

/// A persisted, model-free severity preference for the Bureau engine.
///
/// Raw integer values intentionally match the five slider stops in the Desk UI,
/// which keeps App Intents, settings persistence, and accessibility adjustments
/// speaking the same language.
enum BadviceIntensity: Int, CaseIterable, Codable, Identifiable, Sendable {
    case questionable = 1
    case plausible = 2
    case bold = 3
    case careerLimiting = 4
    case legendaryMistake = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .questionable: return "Questionable"
        case .plausible: return "Plausible"
        case .bold: return "Bold"
        case .careerLimiting: return "Career Limiting"
        case .legendaryMistake: return "Legendary Mistake"
        }
    }

    var shortTitle: String {
        switch self {
        case .questionable: return "Mild"
        case .plausible: return "Plausible"
        case .bold: return "Bold"
        case .careerLimiting: return "Risky"
        case .legendaryMistake: return "Legendary"
        }
    }

    var detail: String {
        switch self {
        case .questionable:
            return "A small lapse in judgment."
        case .plausible:
            return "Wrong enough to sting, believable enough to try."
        case .bold:
            return "Confident, visible, and difficult to walk back."
        case .careerLimiting:
            return "The kind of take that earns a calendar invite."
        case .legendaryMistake:
            return "Maximum theatrical damage, still safely satirical."
        }
    }
}

/// A one-shot local rewrite direction. These never change the saved intensity
/// preference and never require Apple Intelligence.
enum AdviceRevisionStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case moreChaotic
    case moreBelievable
    case colder
    case officeSafe
    case oneSentence
    case completelyUnhinged

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moreChaotic: return "More chaotic"
        case .moreBelievable: return "More believable"
        case .colder: return "Colder"
        case .officeSafe: return "Office-safe"
        case .oneSentence: return "One sentence"
        case .completelyUnhinged: return "Completely unhinged"
        }
    }

    var systemImage: String {
        switch self {
        case .moreChaotic: return "tornado"
        case .moreBelievable: return "checkmark.seal"
        case .colder: return "snowflake"
        case .officeSafe: return "building.2"
        case .oneSentence: return "text.line.first.and.arrowtriangle.forward"
        case .completelyUnhinged: return "sparkles.rectangle.stack"
        }
    }
}

enum CaseRarity: Int, CaseIterable, Codable, Identifiable, Sendable {
    case routine = 1
    case notable = 2
    case legendary = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .routine: return "Routine"
        case .notable: return "Notable"
        case .legendary: return "Legendary"
        }
    }

    var systemImage: String {
        switch self {
        case .routine: return "doc.text"
        case .notable: return "seal"
        case .legendary: return "crown.fill"
        }
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
    case certified
    case cinematic
    case redFlag
    case caseFile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: return "Deadpan"
        case .gradient: return "Faux Expert"
        case .bold: return "Chaotic"
        case .certified: return "Badvice Certified"
        case .cinematic: return "Cinematic"
        case .redFlag: return "Red Flag"
        case .caseFile: return "Case File"
        }
    }

    /// Editorial share personality used by ShareKit layout rails.
    var editorialKind: ShareEditorialKind {
        switch self {
        case .minimal: return .deadpan
        case .bold: return .chaotic
        case .gradient, .certified, .caseFile: return .fauxExpert
        case .cinematic: return .deadpan
        case .redFlag: return .chaotic
        }
    }
}

enum ShareEditorialKind: String, Sendable {
    case deadpan
    case chaotic
    case fauxExpert
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
        case .auto: return "Local First"
        case .classic: return "Bureau Engine"
        case .appleOnDevice: return "Apple Intelligence"
        }
    }

    var detail: String {
        switch self {
        case .auto:
            return "Legacy local-first setting. Uses the Bureau Engine."
        case .classic:
            return "Instant, private, deterministic, and fully offline."
        case .appleOnDevice:
            return "Optional model-assisted rewrites on supported devices."
        }
    }

    /// `auto` remains decodable for existing installs but is intentionally absent from
    /// new settings UI. Model-backed generation always requires an explicit selection.
    static let userSelectable: [AdviceGenerationProvider] = [.classic, .appleOnDevice]
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
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: AdviceCategory?
    let tone: ToneMode?
    let contentPack: ContentPack?
    let reward: String
}

extension ChaosContract {
    static let catalog: [ChaosContract] = [
        ChaosContract(
            id: "neural-glitch",
            title: "The Neural Glitch",
            description: "Force all advice to prioritize efficiency over ethics.",
            icon: "cpu",
            category: .tech,
            tone: .corporateConsultant,
            contentPack: .cyberInfluence,
            reward: "Cyber Unlock"
        ),
        ChaosContract(
            id: "social-overwrite",
            title: "Social Overwrite",
            description: "Redirect conversation protocols to social engineering.",
            icon: "network",
            category: .social,
            tone: .influencer,
            contentPack: .cyberInfluence,
            reward: "Glitch Aura"
        ),
        ChaosContract(
            id: "chaos-franchise",
            title: "The Chaos Franchise",
            description: "Scale your worst idea until it becomes someone else's problem.",
            icon: "building.2",
            category: .money,
            tone: .corporateConsultant,
            contentPack: nil,
            reward: "Franchise Badge"
        ),
        ChaosContract(
            id: "friend-roast-protocol",
            title: "Friend Roast Protocol",
            description: "Deploy targeted social sabotage disguised as helpful advice.",
            icon: "flame",
            category: .social,
            tone: .friendRoast,
            contentPack: nil,
            reward: "Roast Master"
        ),
        ChaosContract(
            id: "career-implosion",
            title: "Career Implosion",
            description: "Accelerate to the top via the express elevator to chaos.",
            icon: "chart.line.uptrend.xyaxis",
            category: .career,
            tone: .corporateConsultant,
            contentPack: nil,
            reward: "Executive Chaos"
        ),
        ChaosContract(
            id: "conspiracy-gym",
            title: "The Conspiracy Gym",
            description: "Apply fringe logic to fitness. Gains not guaranteed. Neither is safety.",
            icon: "dumbbell",
            category: .fitness,
            tone: .conspiracyTheorist,
            contentPack: nil,
            reward: "Cryptid Athlete"
        ),
        ChaosContract(
            id: "finance-wildfire",
            title: "Finance Wildfire",
            description: "Invest aggressively in ideas your family warned you about.",
            icon: "dollarsign.circle",
            category: .money,
            tone: .cryptoBro,
            contentPack: nil,
            reward: "Burning Wallet"
        ),
        ChaosContract(
            id: "wizards-dilemma",
            title: "Wizard's Dilemma",
            description: "Conjure solutions to problems that didn't exist until now.",
            icon: "wand.and.stars",
            category: .productivity,
            tone: .wizard,
            contentPack: nil,
            reward: "Arcane Badge"
        )
    ]
}

struct DailyMissionSpec: Sendable {
    let key: String
    let category: AdviceCategory
    let tone: ToneMode
    let targetCount: Int

    static func current(for date: Date = Date(), calendar: Calendar = .current) -> DailyMissionSpec {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = calendar.component(.year, from: date)
        let categories = AdviceCategory.concrete
        let tones = ToneMode.concrete
        let category = categories[(dayOfYear * 2) % categories.count]
        let tone = tones[(dayOfYear * 5) % tones.count]
        let targetCount = 2 + (dayOfYear % 3)
        let key = "\(year)-\(dayOfYear)-\(category.rawValue)-\(tone.rawValue)-\(targetCount)"
        return DailyMissionSpec(
            key: key,
            category: category,
            tone: tone,
            targetCount: targetCount
        )
    }
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
    case wire
    case generate
    case chaosHub
    case explore
    case groupChallenges
    case quotes
    case favorites
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wire: return "Wire"
        case .generate: return "Desk"
        case .chaosHub: return "Dares"
        case .explore: return "Starters"
        case .groupChallenges: return "Groups"
        case .quotes: return "Dispatches"
        case .favorites: return "Casebook"
        case .history: return "Recent"
        case .settings: return "Settings"
        }
    }

    var compactTitle: String {
        switch self {
        case .wire: return "Wire"
        case .generate: return "Desk"
        case .chaosHub: return "Dares"
        case .explore: return "Ideas"
        case .groupChallenges: return "Groups"
        case .quotes: return "Dispatch"
        case .favorites: return "Files"
        case .history: return "Recent"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .wire: return "antenna.radiowaves.left.and.right"
        case .generate: return "deskclock.fill"
        case .chaosHub: return "flag.checkered.2.crossed"
        case .explore: return "lightbulb.max.fill"
        case .groupChallenges: return "person.3.fill"
        case .quotes: return "envelope.open.fill"
        case .favorites: return "books.vertical.fill"
        case .history: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .settings: return "gearshape"
        }
    }

    static let defaultOrder: [AppTab] = [
        .wire, .generate, .favorites, .chaosHub, .quotes, .history, .explore, .groupChallenges,
        .settings,
    ]

    static let primaryNavigationTabs: [AppTab] = [
        .wire, .generate, .favorites, .chaosHub,
    ]

    static let brandMenuTabs: [AppTab] = [
        .quotes, .history, .explore, .groupChallenges, .settings,
    ]
}

extension AppTab {
    var focusModeStorageKey: String {
        "badvice.focusmode.\(rawValue)"
    }
}

@available(iOS 16.0, *)
extension AppTab: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation("Badvice tab")
    static let typeDisplayName = LocalizedStringResource("Badvice tab")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .wire: "Wire",
        .generate: "Desk",
        .chaosHub: "Dares",
        .explore: "Starters",
        .groupChallenges: "Groups",
        .quotes: "Dispatches",
        .favorites: "Casebook",
        .history: "Recent",
        .settings: "Settings",
    ]
}

@available(iOS 16.0, *)
extension AdviceCategory: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation("Advice category")
    static let typeDisplayName = LocalizedStringResource("Advice category")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .dating: "Dating",
        .fitness: "Fitness",
        .career: "Career",
        .money: "Money",
        .parenting: "Parenting",
        .tech: "Tech",
        .social: "Social",
        .cooking: "Cooking",
        .travel: "Travel",
        .productivity: "Productivity",
        .pets: "Pets",
        .relationships: "Relationships",
        .spirituality: "Spirituality",
        .financeCrypto: "Crypto",
        .gaming: "Gaming",
        .weddings: "Weddings",
        .random: "Random Mix",
    ]
}

@available(iOS 16.0, *)
extension ToneMode: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation("Tone mode")
    static let typeDisplayName = LocalizedStringResource("Tone mode")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .corporateConsultant: "Corporate Consultant",
        .alphaPodcast: "Alpha Podcast",
        .wizard: "Wizard",
        .influencer: "Influencer",
        .toxicBestFriend: "Toxic Best Friend",
        .boomer: "Boomer",
        .cryptoBro: "Crypto Bro",
        .minimalistMonk: "Minimalist Monk",
        .friendRoast: "Friend Roast",
        .lifeCoach: "Life Coach",
        .conspiracyTheorist: "Conspiracy Theorist",
        .genZ: "Gen Z",
        .redditCommenter: "Reddit Commenter",
        .linkedInInfluencer: "LinkedIn Influencer",
        .astrologyGirlie: "Astrology Girlie",
        .oldMoney: "Old Money",
        .random: "Random Mix",
    ]
}

@available(iOS 16.0, *)
extension BadviceIntensity: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation("Badvice intensity")
    static let typeDisplayName = LocalizedStringResource("Badvice intensity")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .questionable: "Questionable",
        .plausible: "Plausible",
        .bold: "Bold",
        .careerLimiting: "Career Limiting",
        .legendaryMistake: "Legendary Mistake",
    ]
}

@available(iOS 16.0, *)
struct BadviceIntentPayload: Codable, Sendable {
    enum HandledCommand: String, Codable, Sendable {
        case openTab
        case generateAdvice
        case openDailyQuote
    }

    let command: HandledCommand
    let tab: String?
    let category: String?
    let tone: String?
    let friendName: String?
    let scenario: String?
    let shouldGenerate: Bool
}

@available(iOS 16.0, *)
@MainActor
final class BadviceIntentRouter {
    static let shared = BadviceIntentRouter()
    private static let storageKey = "com.worstadvice.app.pendingIntentPayloadV1"
    private var pendingPayload: BadviceIntentPayload?

    private init() {}

    func enqueue(_ payload: BadviceIntentPayload) {
        pendingPayload = payload
        persist(payload)
    }

    func consume() -> BadviceIntentPayload? {
        if let payload = pendingPayload {
            pendingPayload = nil
            clearPersistedPayload()
            return payload
        }

        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let payload = try? JSONDecoder().decode(BadviceIntentPayload.self, from: data)
        else {
            return nil
        }
        pendingPayload = nil
        clearPersistedPayload()
        return payload
    }

    private func persist(_ payload: BadviceIntentPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func clearPersistedPayload() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }
}

@available(iOS 16.0, *)
struct OpenBadviceTabIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Badvice tab"
    static let description = IntentDescription("Open Badvice directly to the tab you need.")
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$tab)")
    }
    @Parameter(title: "Tab") var tab: AppTab

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            BadviceIntentRouter.shared.enqueue(
                .init(
                    command: .openTab,
                    tab: tab.rawValue,
                    category: nil,
                    tone: nil,
                    friendName: nil,
                    scenario: nil,
                    shouldGenerate: false
                ))
        }
        return .result()
    }
}

@available(iOS 16.0, *)
@available(*, deprecated, message: "Use supportedModes instead")
extension OpenBadviceTabIntent {
    static var openAppWhenRun: Bool { true }
}

@available(iOS 16.0, *)
struct GenerateBadviceAdviceIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Badvice advice"
    static let description = IntentDescription(
        "Open Badvice and generate advice using the optional category, tone, friend, and scenario inputs."
    )
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var parameterSummary: some ParameterSummary {
        Summary("Generate bad advice")
    }
    @Parameter(title: "Category")
    var category: AdviceCategory?

    @Parameter(title: "Tone")
    var tone: ToneMode?

    @Parameter(title: "Friend name")
    var friendName: String?

    @Parameter(title: "Situation")
    var situation: String?

    @Parameter(title: "Generate now", default: true) var generateNow: Bool

    func perform() async throws -> some IntentResult {
        let normalizedFriendName = friendName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
            .prefix(80)
        let normalizedSituation = situation?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(4_000)
        let normalizedFriendNameValue =
            normalizedFriendName.map { String($0) }.flatMap { $0.isEmpty ? nil : $0 }
        let normalizedScenarioValue =
            normalizedSituation.map { String($0) }.flatMap { $0.isEmpty ? nil : $0 }
        await MainActor.run {
            BadviceIntentRouter.shared.enqueue(
                .init(
                    command: .generateAdvice,
                    tab: AppTab.generate.rawValue,
                    category: category?.rawValue,
                    tone: tone?.rawValue,
                    friendName: normalizedFriendNameValue,
                    scenario: normalizedScenarioValue,
                    shouldGenerate: generateNow
                ))
        }
        return .result(dialog: "Prepared Badvice advice request.")
    }
}

@available(iOS 16.0, *)
@available(*, deprecated, message: "Use supportedModes instead")
extension GenerateBadviceAdviceIntent {
    static var openAppWhenRun: Bool { true }
}

@available(iOS 16.0, *)
struct OpenDailyQuoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open daily quote"
    static let description = IntentDescription(
        "Open Badvice to today's quote ritual in the Quotes tab."
    )
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var parameterSummary: some ParameterSummary {
        Summary("Open today's quote")
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            BadviceIntentRouter.shared.enqueue(
                .init(
                    command: .openDailyQuote,
                    tab: AppTab.quotes.rawValue,
                    category: nil,
                    tone: nil,
                    friendName: nil,
                    scenario: nil,
                    shouldGenerate: false
                ))
        }
        return .result(dialog: "Opening today's Badvice quote.")
    }
}

@available(iOS 16.0, *)
@available(*, deprecated, message: "Use supportedModes instead")
extension OpenDailyQuoteIntent {
    static var openAppWhenRun: Bool { true }
}

@available(iOS 16.0, *)
struct OpenBadviceMissionsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Badvice missions"
    static let description = IntentDescription(
        "Open Badvice directly to the Missions surface for daily progress, streaks, and season status."
    )
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var parameterSummary: some ParameterSummary {
        Summary("Open Badvice missions")
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            BadviceIntentRouter.shared.enqueue(
                .init(
                    command: .openTab,
                    tab: AppTab.chaosHub.rawValue,
                    category: nil,
                    tone: nil,
                    friendName: nil,
                    scenario: nil,
                    shouldGenerate: false
                ))
        }
        return .result(dialog: "Opening Badvice missions.")
    }
}

@available(iOS 16.0, *)
@available(*, deprecated, message: "Use supportedModes instead")
extension OpenBadviceMissionsIntent {
    static var openAppWhenRun: Bool { true }
}

@available(iOS 16.0, *)
struct StartDailyMissionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Badvice daily mission"
    static let description = IntentDescription(
        "Open Badvice to the current daily mission setup and generate the first matching advice run."
    )
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .foreground(.immediate) }
    static var parameterSummary: some ParameterSummary {
        Summary("Start today's Badvice mission")
    }

    func perform() async throws -> some IntentResult {
        let mission = DailyMissionSpec.current()
        await MainActor.run {
            BadviceIntentRouter.shared.enqueue(
                .init(
                    command: .generateAdvice,
                    tab: AppTab.generate.rawValue,
                    category: mission.category.rawValue,
                    tone: mission.tone.rawValue,
                    friendName: nil,
                    scenario: "Daily mission: \(mission.category.title) with \(mission.tone.title)",
                    shouldGenerate: true
                ))
        }
        return .result(dialog: "Starting today's Badvice mission.")
    }
}

@available(iOS 16.0, *)
@available(*, deprecated, message: "Use supportedModes instead")
extension StartDailyMissionIntent {
    static var openAppWhenRun: Bool { true }
}

/// Completes entirely in Shortcuts/Siri using the deterministic Bureau engine.
/// This is deliberately separate from `GenerateBadviceAdviceIntent`, which opens
/// the full Desk workflow and can use the optional Apple Intelligence provider.
@available(iOS 16.0, *)
struct GetQuickBadviceIntent: AppIntent {
    static let title: LocalizedStringResource = "Get quick Badvice"
    static let description = IntentDescription(
        "Return private, local bad advice without opening the app or using an AI model."
    )
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Category", default: .career)
    var category: AdviceCategory

    @Parameter(title: "Tone", default: .corporateConsultant)
    var tone: ToneMode

    @Parameter(title: "Intensity", default: .bold)
    var intensity: BadviceIntensity

    @Parameter(title: "Situation")
    var situation: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$intensity) bad advice for \(\.$category)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let safeSituation = situation?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(280)
        let output = BureauAdviceEngine().generate(
            category: category,
            tone: tone,
            includeRationale: false,
            situation: safeSituation.map(String.init),
            intensity: intensity,
            seed: Int(Date().timeIntervalSinceReferenceDate * 1_000)
        )
        return .result(
            value: output.adviceLine,
            dialog: IntentDialog("\(output.adviceLine)")
        )
    }
}

@available(iOS 16.0, *)
@available(*, deprecated, message: "Use supportedModes instead")
extension GetQuickBadviceIntent {
    static var openAppWhenRun: Bool { false }
}

@available(iOS 16.0, *)
enum BadviceDailyQuoteIntentFormatter {
    static func shortcutText(for quote: SharedDailyQuote) -> String {
        "\"\(quote.text)\"\n- \(quote.source)\n\nBadvice"
    }

    static func dialogText(for quote: SharedDailyQuote) -> IntentDialog {
        IntentDialog("\(quote.text) - \(quote.source)")
    }
}

@available(iOS 16.0, *)
struct GetDailyQuoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Get daily Badvice quote"
    static let description = IntentDescription(
        "Return today's Badvice quote without opening the app."
    )
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }
    static var parameterSummary: some ParameterSummary {
        Summary("Get today's Badvice quote")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let quote = SharedDailyQuoteSource.quoteOfDay()
        return .result(
            value: BadviceDailyQuoteIntentFormatter.shortcutText(for: quote),
            dialog: BadviceDailyQuoteIntentFormatter.dialogText(for: quote)
        )
    }
}

@available(iOS 16.0, *)
@available(*, deprecated, message: "Use supportedModes instead")
extension GetDailyQuoteIntent {
    static var openAppWhenRun: Bool { false }
}

@available(iOS 16.0, *)
struct BadviceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetQuickBadviceIntent(),
            phrases: [
                "Give me quick Badvice in ${applicationName}",
                "Get local bad advice from ${applicationName}",
                "Tell me a terrible idea with ${applicationName}"
            ],
            shortTitle: "Quick Badvice",
            systemImageName: "bolt.shield.fill"
        )
        AppShortcut(
            intent: GetDailyQuoteIntent(),
            phrases: [
                "Get today's Badvice quote in ${applicationName}",
                "Read today's Badvice quote in ${applicationName}",
                "What is today's Badvice quote in ${applicationName}"
            ],
            shortTitle: "Get Quote",
            systemImageName: "text.quote"
        )
        AppShortcut(
            intent: OpenDailyQuoteIntent(),
            phrases: [
                "Open today's quote in ${applicationName}",
                "Show today's bad quote in ${applicationName}",
                "Open Badvice quotes in ${applicationName}"
            ],
            shortTitle: "Daily Quote",
            systemImageName: "quote.bubble.fill"
        )
        AppShortcut(
            intent: OpenBadviceMissionsIntent(),
            phrases: [
                "Open Badvice missions in ${applicationName}",
                "Show my Badvice missions in ${applicationName}",
                "Open Badvice progress in ${applicationName}"
            ],
            shortTitle: "Missions",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: StartDailyMissionIntent(),
            phrases: [
                "Start today's Badvice mission in ${applicationName}",
                "Run my Badvice daily mission in ${applicationName}",
                "Start Badvice mission in ${applicationName}"
            ],
            shortTitle: "Start Mission",
            systemImageName: "flag.checkered.2.crossed"
        )
        AppShortcut(
            intent: OpenBadviceTabIntent(),
            phrases: [
                "Open advice in ${applicationName}",
                "Open generate tab in ${applicationName}",
                "Open friends in ${applicationName}",
                "Open Badvice in ${applicationName}"
            ],
            shortTitle: "Open Badvice tab",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: GenerateBadviceAdviceIntent(),
            phrases: [
                "Generate bad advice in ${applicationName}",
                "Generate bad advice for ${applicationName}",
                "Give me bad advice from ${applicationName}",
                "Generate bad advice with my friends in ${applicationName}"
            ],
            shortTitle: "Generate advice",
            systemImageName: "wand.and.stars"
        )
    }
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
    let caseNumber: String?

    init(
        category: AdviceCategory,
        tone: ToneMode,
        adviceLine: String,
        rationaleLine: String?,
        includeDisclaimer: Bool,
        template: ShareCardTemplate,
        aspectRatio: ShareAspectRatio,
        caseNumber: String? = nil
    ) {
        self.category = category
        self.tone = tone
        self.adviceLine = adviceLine
        self.rationaleLine = rationaleLine
        self.includeDisclaimer = includeDisclaimer
        self.template = template
        self.aspectRatio = aspectRatio
        self.caseNumber = caseNumber
    }
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
