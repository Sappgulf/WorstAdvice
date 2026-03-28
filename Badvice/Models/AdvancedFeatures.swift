import SwiftUI

// MARK: - Favorites Collection/Folder

struct FavoritesCollection: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var icon: String
    var adviceIDs: [UUID]
    let createdAt: Date
    var updatedAt: Date
    
    var adviceCount: Int { adviceIDs.count }
    
    static let defaultCollections: [FavoritesCollection] = [
        FavoritesCollection(
            id: UUID(),
            name: "Job & Career",
            icon: "briefcase.fill",
            adviceIDs: [],
            createdAt: Date(),
            updatedAt: Date()
        ),
        FavoritesCollection(
            id: UUID(),
            name: "Dating & Relationships",
            icon: "heart.fill",
            adviceIDs: [],
            createdAt: Date(),
            updatedAt: Date()
        ),
        FavoritesCollection(
            id: UUID(),
            name: "Daily Life",
            icon: "sun.max.fill",
            adviceIDs: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}

// MARK: - Custom Tone Blend

struct ToneBlend: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var tone1: ToneMode
    var tone2: ToneMode
    var blendRatio: Double // 0.5 = equal blend
    
    var displayTitle: String {
        if blendRatio < 0.3 {
            return tone1.title
        } else if blendRatio > 0.7 {
            return tone2.title
        } else {
            return "\(tone1.title) / \(tone2.title)"
        }
    }
}

// MARK: - Personal Motto

struct PersonalMotto: Codable, Sendable {
    var text: String
    var isEnabled: Bool
    
    static let examples = [
        "Terrible advice, delivered with confidence",
        "I don't give good advice. I give bad advice with even worse timing.",
        "My wisdom is your warning",
        "Expert in giving the worst possible counsel",
        "Confidently incorrect since [year]"
    ]
}

// MARK: - Remix History

struct RemixEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let originalAdviceID: UUID
    let originalText: String
    let remixText: String
    let category: AdviceCategory
    let tone: ToneMode
    let createdAt: Date
}

// MARK: - Category Priority

struct CategoryPriority: Codable, Sendable {
    var priorities: [AdviceCategory]
    
    static let `default`: CategoryPriority = CategoryPriority(
        priorities: AdviceCategory.concrete
    )
}

// MARK: - Mood Tracking

enum MoodType: String, Codable, CaseIterable {
    case stressed
    case anxious
    case sad
    case bored
    case confused
    case frustrated
    case lonely
    case excited
    case happy
    case confident
    
    var icon: String {
        switch self {
        case .stressed: return "bolt.heart.fill"
        case .anxious: return "waveform.path.ecg"
        case .sad: return "cloud.rain.fill"
        case .bored: return "zzz"
        case .confused: return "questionmark.circle.fill"
        case .frustrated: return "flame.fill"
        case .lonely: return "person.fill.questionmark"
        case .excited: return "star.fill"
        case .happy: return "sun.max.fill"
        case .confident: return "crown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .stressed: return .red
        case .anxious: return .orange
        case .sad: return .blue
        case .bored: return .gray
        case .confused: return .purple
        case .frustrated: return .red.opacity(0.7)
        case .lonely: return .indigo
        case .excited: return .yellow
        case .happy: return .green
        case .confident: return .mint
        }
    }
}

struct MoodEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let mood: MoodType
    let category: AdviceCategory
    let tone: ToneMode
    let adviceID: UUID?
    let timestamp: Date
}

// MARK: - Streak Calendar

struct StreakDay: Identifiable {
    let id = UUID()
    let date: Date
    let generationCount: Int
    let hadStreak: Bool
    
    var intensity: Double {
        min(Double(generationCount) / 10.0, 1.0)
    }
}

struct StreakCalendar {
    let weeks: Int
    let startDate: Date
    
    static func generate(for days: Int = 84) -> [StreakDay] {
        // Placeholder - would pull from actual data
        return []
    }
}

// MARK: - Daily Spin

struct DailySpin: Identifiable, Codable, Sendable {
    let id: UUID
    let spinDate: Date
    var reward: SpinReward?
    var hasSpun: Bool
    
    var isAvailable: Bool {
        !hasSpun && Calendar.current.isDateInToday(spinDate)
    }
}

struct SpinReward: Codable, Sendable {
    let type: SpinRewardType
    let amount: Int
    let message: String
}

enum SpinRewardType: String, Codable {
    case xp
    case bonusPoints
    case mysteryBox
    case streakBonus
    case nothing
}

// MARK: - Mystery Box

struct MysteryBox: Identifiable, Codable, Sendable {
    let id: UUID
    let earnedAt: Date
    var isOpened: Bool
    var reward: SpinReward?
    
    static let possibleRewards: [SpinReward] = [
        SpinReward(type: .xp, amount: 50, message: "+50 XP"),
        SpinReward(type: .xp, amount: 100, message: "+100 XP"),
        SpinReward(type: .bonusPoints, amount: 10, message: "+10 Bonus Points"),
        SpinReward(type: .streakBonus, amount: 1, message: "+1 Day Streak"),
        SpinReward(type: .mysteryBox, amount: 1, message: "Another Mystery Box!"),
        SpinReward(type: .nothing, amount: 0, message: "Better luck next time!")
    ]
}

// MARK: - Achievement Chain

struct AchievementChain: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let steps: [AchievementChainStep]
    var currentStep: Int
    
    var isCompleted: Bool { currentStep >= steps.count }
    var progress: Double { Double(currentStep) / Double(steps.count) }
}

struct AchievementChainStep: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let targetValue: Int
    var currentValue: Int
    let rewardXP: Int
    
    var isCompleted: Bool { currentValue >= targetValue }
}

extension AchievementChain {
    static let chains: [AchievementChain] = [
        AchievementChain(
            id: UUID(),
            name: "Streak Master",
            description: "Build up your daily streak",
            steps: [
                AchievementChainStep(id: UUID(), title: "3-Day Streak", description: "Use app 3 days in a row", targetValue: 3, currentValue: 0, rewardXP: 50),
                AchievementChainStep(id: UUID(), title: "7-Day Streak", description: "Use app 7 days in a row", targetValue: 7, currentValue: 0, rewardXP: 100),
                AchievementChainStep(id: UUID(), title: "14-Day Streak", description: "Use app 14 days in a row", targetValue: 14, currentValue: 0, rewardXP: 200),
                AchievementChainStep(id: UUID(), title: "30-Day Streak", description: "Use app 30 days in a row", targetValue: 30, currentValue: 0, rewardXP: 500)
            ],
            currentStep: 0
        ),
        AchievementChain(
            id: UUID(),
            name: "Collector",
            description: "Build your favorites collection",
            steps: [
                AchievementChainStep(id: UUID(), title: "First Save", description: "Save your first advice", targetValue: 1, currentValue: 0, rewardXP: 25),
                AchievementChainStep(id: UUID(), title: "10 Saves", description: "Save 10 pieces of advice", targetValue: 10, currentValue: 0, rewardXP: 75),
                AchievementChainStep(id: UUID(), title: "50 Saves", description: "Save 50 pieces of advice", targetValue: 50, currentValue: 0, rewardXP: 200),
                AchievementChainStep(id: UUID(), title: "100 Saves", description: "Save 100 pieces of advice", targetValue: 100, currentValue: 0, rewardXP: 500)
            ],
            currentStep: 0
        )
    ]
}

// MARK: - Referral System

struct Referral: Identifiable, Codable, Sendable {
    let id: UUID
    let code: String
    let referrerID: String
    var referredUserIDs: [String]
    let createdAt: Date
    var totalXPEarned: Int
    var isActive: Bool
}

struct ReferralReward: Identifiable, Codable, Sendable {
    let id: UUID
    let xpAmount: Int
    let badgeUnlock: String?
    let referralCount: Int
}

// MARK: - Season Pass

struct SeasonPass: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let seasonNumber: Int
    let startDate: Date
    let endDate: Date
    var tiers: [SeasonTier]
    var currentTierIndex: Int
    var xpEarned: Int
    var claimedRewards: Set<Int>
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
    }
    
    var currentTier: SeasonTier? {
        guard currentTierIndex < tiers.count else { return nil }
        return tiers[currentTierIndex]
    }
    
    var nextTier: SeasonTier? {
        guard currentTierIndex + 1 < tiers.count else { return nil }
        return tiers[currentTierIndex + 1]
    }
    
    var progressToNextTier: Double {
        guard let current = currentTier, let next = nextTier else { return 1.0 }
        let xpInTier = xpEarned - current.requiredXP
        let xpNeeded = next.requiredXP - current.requiredXP
        return Double(xpInTier) / Double(xpNeeded)
    }
}

struct SeasonTier: Identifiable, Codable, Sendable {
    let id: Int
    let name: String
    let requiredXP: Int
    let rewards: [SeasonReward]
    let isPremium: Bool
}

struct SeasonReward: Identifiable, Codable, Sendable {
    let id: UUID
    let type: SeasonRewardType
    let value: Int
    let description: String
}

enum SeasonRewardType: String, Codable {
    case xp
    case theme
    case badge
    case mysteryBox
    case bonusPoints
}

// MARK: - Advice Card Image

struct AdviceCardImage: Identifiable {
    let id: UUID
    let adviceText: String
    let category: AdviceCategory
    let tone: ToneMode
    let source: String
    let backgroundImage: UIImage?
    let quoteFont: String
    let includeWatermark: Bool
    
    func generateImage(size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Draw background
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw advice text
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
            
            let textRect = CGRect(x: 20, y: size.height / 2 - 50, width: size.width - 40, height: 100)
            adviceText.draw(in: textRect, withAttributes: attributes)
            
            // Draw category and tone
            let metaAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
            
            let metaText = "\(category.title) • \(tone.title)"
            let metaRect = CGRect(x: 20, y: size.height / 2 + 60, width: size.width - 40, height: 30)
            metaText.draw(in: metaRect, withAttributes: metaAttributes)
        }
    }
}

// MARK: - Quote Image Template

enum QuoteImageTemplate: String, CaseIterable {
    case minimal
    case gradient
    case vintage
    case modern
    case dark
    
    var backgroundColors: [UIColor] {
        switch self {
        case .minimal: return [.systemBackground]
        case .gradient: return [UIColor(red: 0.96, green: 0.6, blue: 0.3, alpha: 1), UIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1)]
        case .vintage: return [UIColor(red: 0.85, green: 0.75, blue: 0.6, alpha: 1), UIColor(red: 0.7, green: 0.55, blue: 0.4, alpha: 1)]
        case .modern: return [UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1), UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1)]
        case .dark: return [.black]
        }
    }
    
    var textColor: UIColor {
        switch self {
        case .minimal, .vintage: return .label
        case .gradient, .modern, .dark: return .white
        }
    }
    
    var fontName: String {
        switch self {
        case .minimal: return "Helvetica Neue"
        case .gradient, .modern: return "SF Pro Display"
        case .vintage: return "Georgia"
        case .dark: return "SF Pro Rounded"
        }
    }
}

// MARK: - Friend Match

struct FriendMatch: Identifiable, Codable, Sendable {
    let id: UUID
    let friendID: String
    let friendName: String
    let matchScore: Int // 0-100
    let commonCategories: [AdviceCategory]
    let commonTones: [ToneMode]
    let sharedAdviceCount: Int
    let matchDate: Date
}

struct FriendMatchReason: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

// MARK: - Advice Tournament

struct AdviceTournament: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let category: AdviceCategory
    let tone: ToneMode
    let entries: [TournamentEntry]
    let votingStartDate: Date
    let votingEndDate: Date
    let resultDate: Date
    
    var isVotingOpen: Bool {
        let now = Date()
        return now >= votingStartDate && now <= votingEndDate
    }
    
    var isCompleted: Bool {
        Date() > resultDate
    }
}

struct TournamentEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let adviceID: UUID
    let adviceText: String
    let submittedBy: String
    var voteCount: Int
}

struct TournamentVote: Identifiable, Codable, Sendable {
    let id: UUID
    let tournamentID: UUID
    let entryID: UUID
    let votedAt: Date
}

// MARK: - Advice of the Day

struct AdviceOfTheDay: Codable, Sendable {
    let date: Date
    let adviceID: UUID
    let adviceText: String
    let category: AdviceCategory
    let tone: ToneMode
    let source: String
    let submitterName: String?
    let voteCount: Int
    let commentCount: Int
    
    static func generate(from entries: [AdviceRecord]) -> AdviceOfTheDay? {
        guard let entry = entries.randomElement() else { return nil }
        return AdviceOfTheDay(
            date: Date(),
            adviceID: entry.id,
            adviceText: entry.adviceLine,
            category: entry.category,
            tone: entry.tone,
            source: entry.source ?? "Badvice",
            submitterName: nil,
            voteCount: 0,
            commentCount: 0
        )
    }
}

// MARK: - Social Reaction

enum SocialReaction: String, Codable, CaseIterable {
    case fire
    case heart
    case skull
    case think
    case laugh
    case wow
    
    var emoji: String {
        switch self {
        case .fire: return "🔥"
        case .heart: return "❤️"
        case .skull: return "💀"
        case .think: return "🤔"
        case .laugh: return "😂"
        case .wow: return "😮"
        }
    }
    
    var icon: String {
        switch self {
        case .fire: return "flame.fill"
        case .heart: return "heart.fill"
        case .skull: return "xmark.circle.fill"
        case .think: return "questionmark.circle.fill"
        case .laugh: return "face.smiling.fill"
        case .wow: return "exclamationmark.circle.fill"
        }
    }
}

struct ReactionCount: Identifiable {
    let id = UUID()
    let reaction: SocialReaction
    var count: Int
}

// MARK: - Comment

struct AdviceComment: Identifiable, Codable, Sendable {
    let id: UUID
    let adviceID: UUID
    let userID: String
    let userName: String
    let text: String
    let createdAt: Date
    var replies: [AdviceComment]
}
