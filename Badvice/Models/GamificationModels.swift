import Foundation

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
        case .toneExplorer: return "Try every concrete tone mode"
        case .categoryMaster: return "Generate advice in every concrete category"
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

    var displayTitle: String {
        switch self {
        case .generateAdvice: return "Advice filed"
        case .shareAdvice: return "Advice shared"
        case .favoriteAdvice: return "Keeper saved"
        case .dailyChallenge: return "Daily contract closed"
        case .groupChallenge: return "Relay progress"
        case .battleWin: return "Battle won"
        case .streakBonus: return "Streak bonus"
        case .achievementUnlock: return "Achievement unlocked"
        case .questComplete: return "Case completed"
        }
    }
}

// MARK: - Bureau progression

enum BureauRank: Int, CaseIterable, Codable, Identifiable, Sendable {
    case intern = 0
    case clerk = 1
    case analyst = 2
    case director = 3
    case legend = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .intern: return "Rookie Operative"
        case .clerk: return "Chaos Clerk"
        case .analyst: return "Badvice Analyst"
        case .director: return "Dossier Director"
        case .legend: return "Legendary Liability"
        }
    }

    var shortTitle: String {
        switch self {
        case .intern: return "Rookie"
        case .clerk: return "Clerk"
        case .analyst: return "Analyst"
        case .director: return "Director"
        case .legend: return "Legend"
        }
    }

    var systemImage: String {
        switch self {
        case .intern: return "person.crop.circle"
        case .clerk: return "doc.badge.gearshape"
        case .analyst: return "magnifyingglass.circle.fill"
        case .director: return "person.crop.circle.badge.checkmark"
        case .legend: return "crown.fill"
        }
    }

    var threshold: Int {
        switch self {
        case .intern: return 0
        case .clerk: return 100
        case .analyst: return 300
        case .director: return 650
        case .legend: return 1_100
        }
    }

    var nextThreshold: Int? {
        guard let next = BureauRank(rawValue: rawValue + 1) else { return nil }
        return next.threshold
    }

    static func forXP(_ xp: Int) -> BureauRank {
        allCases.last(where: { xp >= $0.threshold }) ?? .intern
    }

    func progress(for xp: Int) -> Double {
        guard let nextThreshold else { return 1 }
        let span = max(nextThreshold - threshold, 1)
        return min(max(Double(xp - threshold) / Double(span), 0), 1)
    }
}

struct BureauContract: Identifiable, Codable, Sendable {
    let key: String
    let category: AdviceCategory
    let tone: ToneMode
    let targetCount: Int
    let title: String
    let detail: String
    let rewardXP: Int
    let cosmetic: BureauCosmetic

    var id: String { key }

    static func current(for date: Date = Date(), calendar: Calendar = .current) -> BureauContract {
        let mission = DailyMissionSpec.current(for: date, calendar: calendar)
        return BureauContract(
            key: "contract-\(mission.key)",
            category: mission.category,
            tone: mission.tone,
            targetCount: mission.targetCount,
            title: "The Daily Filing",
            detail: "File \(mission.targetCount) \(mission.tone.title) takes in \(mission.category.title).",
            rewardXP: 40,
            cosmetic: .dailySeal
        )
    }
}

struct BureauBossCase: Identifiable, Codable, Sendable {
    let key: String
    let category: AdviceCategory
    let tone: ToneMode
    let targetCount: Int
    let title: String
    let detail: String
    let rewardXP: Int
    let cosmetic: BureauCosmetic
    let periodStart: Date
    let periodEnd: Date

    var id: String { key }

    static func current(for date: Date = Date(), calendar: Calendar = .current) -> BureauBossCase {
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let categories = AdviceCategory.concrete
        let tones = ToneMode.concrete
        let category = categories[(week * 3) % categories.count]
        let tone = tones[(week * 7) % tones.count]
        let targetCount = 6 + (week % 4)
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        let periodStart = interval?.start ?? calendar.startOfDay(for: date)
        let periodEnd = interval?.end ?? (calendar.date(byAdding: .day, value: 7, to: periodStart) ?? date)

        return BureauBossCase(
            key: "boss-\(year)-\(week)-\(category.rawValue)-\(tone.rawValue)-\(targetCount)",
            category: category,
            tone: tone,
            targetCount: targetCount,
            title: "The \(category.title) \(tone.title) Dossier",
            detail: "Build the week's flagship case file with \(targetCount) matching takes.",
            rewardXP: 150,
            cosmetic: .cosmicSeal,
            periodStart: periodStart,
            periodEnd: periodEnd
        )
    }
}

enum BureauCosmetic: String, CaseIterable, Codable, Identifiable, Sendable {
    case dailySeal
    case careerTab
    case redFlagStamp
    case neonStamp
    case circuitBadge
    case stardustBadge
    case cosmicSeal
    case directorBadge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailySeal: return "Daily Seal"
        case .careerTab: return "Career Tab"
        case .redFlagStamp: return "Red Flag Stamp"
        case .neonStamp: return "Neon Stamp"
        case .circuitBadge: return "Circuit Badge"
        case .stardustBadge: return "Stardust Badge"
        case .cosmicSeal: return "Cosmic Seal"
        case .directorBadge: return "Director Badge"
        }
    }

    var detail: String {
        switch self {
        case .dailySeal: return "A fresh seal for completing a daily contract."
        case .careerTab: return "A brass tab for a fully documented career file."
        case .redFlagStamp: return "A scarlet stamp for relationship evidence."
        case .neonStamp: return "A high-voltage stamp for crypto cases."
        case .circuitBadge: return "A diagnostic badge for technical incidents."
        case .stardustBadge: return "A suspiciously luminous badge for cosmic evidence."
        case .cosmicSeal: return "The official seal of a completed boss case."
        case .directorBadge: return "A director's badge earned through sustained chaos."
        }
    }

    var systemImage: String {
        switch self {
        case .dailySeal: return "seal.fill"
        case .careerTab: return "briefcase.fill"
        case .redFlagStamp: return "flag.fill"
        case .neonStamp: return "bolt.fill"
        case .circuitBadge: return "cpu.fill"
        case .stardustBadge: return "sparkles"
        case .cosmicSeal: return "globe.americas.fill"
        case .directorBadge: return "rosette"
        }
    }

    var theme: ThemeMode {
        switch self {
        case .dailySeal: return .ember
        case .careerTab: return .sunset
        case .redFlagStamp: return .retro
        case .neonStamp: return .neon
        case .circuitBadge: return .cybernetic
        case .stardustBadge: return .midnight
        case .cosmicSeal: return .cosmic
        case .directorBadge: return .fallout
        }
    }
}

enum BureauArchetype: String, CaseIterable, Codable, Sendable {
    case spreadsheetGremlin
    case velvetSaboteur
    case wellnessWarlock
    case cryptidStrategist
    case cosmicIntern
    case chaosArchivist

    static func resolve(category: AdviceCategory?, tone: ToneMode?) -> BureauArchetype {
        switch category {
        case .career, .productivity:
            return .spreadsheetGremlin
        case .dating, .relationships, .social, .weddings:
            return .velvetSaboteur
        case .fitness, .pets, .parenting:
            return .wellnessWarlock
        case .money, .financeCrypto, .tech, .gaming:
            return .cryptidStrategist
        case .spirituality, .travel:
            return .cosmicIntern
        case .cooking:
            return .chaosArchivist
        case .random, nil:
            switch tone {
            case .corporateConsultant, .linkedInInfluencer, .minimalistMonk, .oldMoney:
                return .spreadsheetGremlin
            case .toxicBestFriend, .friendRoast, .genZ:
                return .velvetSaboteur
            case .alphaPodcast, .cryptoBro, .conspiracyTheorist:
                return .cryptidStrategist
            case .wizard, .lifeCoach, .redditCommenter, .astrologyGirlie:
                return .cosmicIntern
            case .boomer, .influencer, .random, nil:
                return .chaosArchivist
            }
        }
    }

    var title: String {
        switch self {
        case .spreadsheetGremlin: return "Spreadsheet Gremlin"
        case .velvetSaboteur: return "Velvet Saboteur"
        case .wellnessWarlock: return "Wellness Warlock"
        case .cryptidStrategist: return "Cryptid Strategist"
        case .cosmicIntern: return "Cosmic Intern"
        case .chaosArchivist: return "Chaos Archivist"
        }
    }

    var detail: String {
        switch self {
        case .spreadsheetGremlin:
            return "You turn every decision into a meeting with a color-coded agenda."
        case .velvetSaboteur:
            return "You bring confidence, timing, and just enough emotional damage."
        case .wellnessWarlock:
            return "You can make a wellness ritual out of almost any questionable choice."
        case .cryptidStrategist:
            return "You see hidden leverage everywhere, especially where none exists."
        case .cosmicIntern:
            return "You report directly to the universe and accept no follow-up questions."
        case .chaosArchivist:
            return "You collect bad ideas carefully and file them for future generations."
        }
    }

    var systemImage: String {
        switch self {
        case .spreadsheetGremlin: return "tablecells.fill"
        case .velvetSaboteur: return "heart.slash.fill"
        case .wellnessWarlock: return "wand.and.stars"
        case .cryptidStrategist: return "binoculars.fill"
        case .cosmicIntern: return "sparkles"
        case .chaosArchivist: return "archivebox.fill"
        }
    }
}

struct BureauIdentitySnapshot: Sendable {
    let archetype: BureauArchetype
    let favoriteCategory: AdviceCategory?
    let favoriteTone: ToneMode?
    let currentRank: BureauRank
    let bureauXP: Int
    let streakDays: Int
    let generatedCount: Int
    let equippedCosmetic: BureauCosmetic?
}

struct WeeklyRecapSnapshot: Sendable {
    let weekStart: Date
    let generatedCount: Int
    let savedCount: Int
    let sharedCount: Int
    let streakDays: Int
    let topCategory: AdviceCategory?
    let topTone: ToneMode?
    let highlightLine: String?

    var isEmpty: Bool {
        generatedCount == 0 && savedCount == 0 && sharedCount == 0
    }

    var headline: String {
        guard generatedCount > 0 else { return "Your first filing is waiting." }
        if let topCategory {
            return "You made \(topCategory.title) your main liability."
        }
        return "A productive week of bad judgment."
    }
}

struct BureauCollection: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let detail: String
    let category: AdviceCategory
    let targetCount: Int
    let rewardXP: Int
    let cosmetic: BureauCosmetic

    static let all: [BureauCollection] = [
        BureauCollection(
            id: "career-file",
            title: "Career File",
            detail: "Document three career catastrophes.",
            category: .career,
            targetCount: 3,
            rewardXP: 35,
            cosmetic: .careerTab
        ),
        BureauCollection(
            id: "heartbreak-file",
            title: "Heartbreak File",
            detail: "Assemble three relationship exhibits.",
            category: .dating,
            targetCount: 3,
            rewardXP: 40,
            cosmetic: .redFlagStamp
        ),
        BureauCollection(
            id: "crypto-ledger",
            title: "Crypto Ledger",
            detail: "Audit three volatile money takes.",
            category: .financeCrypto,
            targetCount: 3,
            rewardXP: 50,
            cosmetic: .neonStamp
        ),
        BureauCollection(
            id: "incident-log",
            title: "Incident Log",
            detail: "Close three technical incidents.",
            category: .tech,
            targetCount: 3,
            rewardXP: 40,
            cosmetic: .circuitBadge
        ),
        BureauCollection(
            id: "cosmic-evidence",
            title: "Cosmic Evidence",
            detail: "File three suspiciously spiritual exhibits.",
            category: .spirituality,
            targetCount: 3,
            rewardXP: 50,
            cosmetic: .stardustBadge
        )
    ]
}

struct BureauCollectionState: Identifiable, Sendable {
    let collection: BureauCollection
    let progress: Int
    let isUnlocked: Bool

    var id: String { collection.id }
    var isComplete: Bool { progress >= collection.targetCount }
    var progressFraction: Double {
        min(max(Double(progress) / Double(max(collection.targetCount, 1)), 0), 1)
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
