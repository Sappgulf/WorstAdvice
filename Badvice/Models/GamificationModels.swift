import SwiftUI

// MARK: - XP & Level System

enum UserLevel: Int, Codable, CaseIterable {
    case novice = 1
    case apprentice = 5
    case practitioner = 10
    case expert = 25
    case master = 50
    case grandmaster = 100
    
    var title: String {
        switch self {
        case .novice: return "Novice"
        case .apprentice: return "Apprentice"
        case .practitioner: return "Practitioner"
        case .expert: return "Expert"
        case .master: return "Master"
        case .grandmaster: return "Grandmaster"
        }
    }
    
    var icon: String {
        switch self {
        case .novice: return "leaf.fill"
        case .apprentice: return "flame.fill"
        case .practitioner: return "bolt.fill"
        case .expert: return "star.fill"
        case .master: return "crown.fill"
        case .grandmaster: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .novice: return .green
        case .apprentice: return .blue
        case .practitioner: return .purple
        case .expert: return .orange
        case .master: return .pink
        case .grandmaster: return .red
        }
    }
}

struct XPProgress: Codable, Sendable {
    var currentXP: Int
    var level: Int
    var totalXPEarned: Int
    
    static let xpPerLevel: [Int] = [
        0,      // Level 1
        100,    // Level 2
        250,    // Level 3
        500,    // Level 4
        1000,   // Level 5
        2000,   // Level 6
        3500,   // Level 7
        5500,   // Level 8
        8000,   // Level 9
        11000,  // Level 10
        15000,  // Level 11+
    ]
    
    var currentLevel: UserLevel {
        switch level {
        case 1..<5: return .novice
        case 5..<10: return .apprentice
        case 10..<25: return .practitioner
        case 25..<50: return .expert
        case 50..<100: return .master
        default: return .grandmaster
        }
    }
    
    var xpForNextLevel: Int {
        guard level < Self.xpPerLevel.count else { return xpForLevel(level + 1) }
        return Self.xpPerLevel[level]
    }
    
    var xpProgress: Double {
        let currentLevelXP = xpForLevel(level)
        let nextLevelXP = xpForNextLevel
        let xpIntoLevel = currentXP - currentLevelXP
        let xpNeeded = nextLevelXP - currentLevelXP
        return Double(xpIntoLevel) / Double(xpNeeded)
    }
    
    static func xpForLevel(_ level: Int) -> Int {
        guard level < xpPerLevel.count else {
            return xpPerLevel.last ?? 0 + (level - xpPerLevel.count + 1) * 5000
        }
        return xpPerLevel[level - 1]
    }
    
    mutating func addXP(_ amount: Int) {
        currentXP += amount
        totalXPEarned += amount
        checkLevelUp()
    }
    
    mutating func checkLevelUp() {
        var newLevel = 1
        for (index, threshold) in Self.xpPerLevel.enumerated() {
            if currentXP >= threshold {
                newLevel = index + 1
            }
        }
        if newLevel > level {
            level = newLevel
        }
    }
}

// MARK: - Weekly Goals

struct WeeklyGoal: Identifiable, Codable, Sendable {
    let id: UUID
    let type: WeeklyGoalType
    var currentValue: Int
    let targetValue: Int
    let weekStartDate: Date
    
    var isCompleted: Bool { currentValue >= targetValue }
    var progress: Double { Double(currentValue) / Double(targetValue) }
    
    var title: String { type.title }
    var description: String { type.description }
    var icon: String { type.icon }
    var rewardXP: Int { type.rewardXP }
}

enum WeeklyGoalType: String, Codable, CaseIterable, Sendable {
    case generateCount
    case saveCount
    case shareCount
    case streakDays
    case category variety
    case toneVariety
    
    var title: String {
        switch self {
        case .generateCount: return "Advice Generator"
        case .saveCount: return "Collector"
        case .shareCount: return "Influencer"
        case .streakDays: return "Streak Master"
        case .categoryVariety: return "Category Explorer"
        case .toneVariety: return "Tone Connoisseur"
        }
    }
    
    var description: String {
        switch self {
        case .generateCount: return "Generate 50 pieces of advice this week"
        case .saveCount: return "Save 20 favorites this week"
        case .shareCount: return "Share advice 10 times this week"
        case .streakDays: return "Maintain a 7-day streak"
        case .categoryVariety: return "Use 8 different categories"
        case .toneVariety: return "Try 8 different tones"
        }
    }
    
    var icon: String {
        switch self {
        case .generateCount: return "wand.and.stars"
        case .saveCount: return "bookmark.fill"
        case .shareCount: return "square.and.arrow.up.fill"
        case .streakDays: return "flame.fill"
        case .categoryVariety: return "square.grid.3x3.fill"
        case .toneVariety: return "theatermasks.fill"
        }
    }
    
    var targetValue: Int {
        switch self {
        case .generateCount: return 50
        case .saveCount: return 20
        case .shareCount: return 10
        case .streakDays: return 7
        case .categoryVariety: return 8
        case .toneVariety: return 8
        }
    }
    
    var rewardXP: Int {
        switch self {
        case .generateCount: return 200
        case .saveCount: return 150
        case .shareCount: return 175
        case .streakDays: return 300
        case .categoryVariety: return 100
        case .toneVariety: return 100
        }
    }
    
    static func generateWeeklyGoals() -> [WeeklyGoal] {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        
        return Self.allCases.map { type in
            WeeklyGoal(
                id: UUID(),
                type: type,
                currentValue: 0,
                targetValue: type.targetValue,
                weekStartDate: weekStart
            )
        }
    }
}

// MARK: - Sound Effect

enum SoundEffect: String, CaseIterable {
    case generate = "generate"
    case save = "save"
    case share = "share"
    case achievement = "achievement"
    case levelUp = "level_up"
    case streak = "streak"
    case error = "error"
    case success = "success"
    
    var icon: String {
        switch self {
        case .generate: return "wand.and.stars"
        case .save: return "bookmark.fill"
        case .share: return "square.and.arrow.up.fill"
        case .achievement: return "trophy.fill"
        case .levelUp: return "star.fill"
        case .streak: return "flame.fill"
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Quick Action

enum QuickAction: String, CaseIterable {
    case save
    case share
    case copy
    case remix
    case delete
    
    var icon: String {
        switch self {
        case .save: return "bookmark"
        case .share: return "square.and.arrow.up"
        case .copy: return "doc.on.doc"
        case .remix: return "arrow.triangle.2.circlepath"
        case .delete: return "trash"
        }
    }
    
    var title: String {
        switch self {
        case .save: return "Save"
        case .share: return "Share"
        case .copy: return "Copy"
        case .remix: return "Remix"
        case .delete: return "Delete"
        }
    }
}

// MARK: - Empty State

struct EmptyState: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    static let noFavorites = EmptyState(
        icon: "bookmark",
        title: "No Favorites Yet",
        message: "Start saving advice you love by tapping the bookmark icon.",
        actionTitle: "Generate Advice",
        action: nil
    )
    
    static let noHistory = EmptyState(
        icon: "clock",
        title: "No History Yet",
        message: "Your generated advice will appear here.",
        actionTitle: "Generate Advice",
        action: nil
    )
    
    static let noFriends = EmptyState(
        icon: "person.2",
        title: "No Friends Yet",
        message: "Add friends to see their activity and compete on leaderboards.",
        actionTitle: "Invite Friends",
        action: nil
    )
    
    static let noAchievements = EmptyState(
        icon: "trophy",
        title: "No Achievements Yet",
        message: "Start using Badvice to unlock achievements!",
        actionTitle: nil,
        action: nil
    )
    
    static let offline = EmptyState(
        icon: "wifi.slash",
        title: "You're Offline",
        message: "Check your connection and try again.",
        actionTitle: "Retry",
        action: nil
    )
}

// MARK: - Tutorial Tip

struct TutorialTip: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let anchorView: String
    
    static let tips: [TutorialTip] = [
        TutorialTip(
            icon: "hand.tap",
            title: "Tap to Save",
            description: "Tap the bookmark icon to save advice you love",
            anchorView: "saveButton"
        ),
        TutorialTip(
            icon: "square.and.arrow.up",
            title: "Share with Friends",
            description: "Share your favorite advice with friends",
            anchorView: "shareButton"
        ),
        TutorialTip(
            icon: "dice",
            title: "Random Category",
            description: "Try the random category for surprise advice",
            anchorView: "randomCategory"
        ),
        TutorialTip(
            icon: "iphone.gen3.radiowaves.left.and.right",
            title: "Shake to Generate",
            description: "Shake your phone to generate new advice instantly",
            anchorView: "shakeGesture"
        ),
        TutorialTip(
            icon: "trophy",
            title: "Earn Achievements",
            description: "Complete achievements to unlock themes and badges",
            anchorView: "achievementsButton"
        )
    ]
}

// MARK: - Confetti Particle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var scale: CGFloat
    var color: Color
    var velocity: CGVector
    var rotationVelocity: Double
    
    static let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink
    ]
    
    static func random(at point: CGPoint) -> ConfettiParticle {
        ConfettiParticle(
            x: point.x,
            y: point.y,
            rotation: Double.random(in: 0...360),
            scale: CGFloat.random(in: 0.5...1.5),
            color: colors.randomElement() ?? .red,
            velocity: CGVector(
                dx: CGFloat.random(in: -8...8),
                dy: CGFloat.random(in: -15...(-5))
            ),
            rotationVelocity: Double.random(in: -10...10)
        )
    }
}

// MARK: - Badge/Flair

struct AchievementBadge: Identifiable {
    let id: String
    let icon: String
    let title: String
    let achievementType: AchievementType?
    
    static let specialBadges: [AchievementBadge] = [
        AchievementBadge(id: "founder", icon: "star.fill", title: "Founder", achievementType: nil),
        AchievementBadge(id: "beta_tester", icon: "flask.fill", title: "Beta Tester", achievementType: nil),
        AchievementBadge(id: "streak_7", icon: "flame.fill", title: "7-Day Streak", achievementType: .dailyStreak7),
        AchievementBadge(id: "streak_30", icon: "flame.fill", title: "30-Day Streak", achievementType: .dailyStreak30),
        AchievementBadge(id: "centurion", icon: "100.circle.fill", title: "Centurion", achievementType: .centurion),
        AchievementBadge(id: "collector", icon: "folder.fill", title: "Collector", achievementType: .collector),
        AchievementBadge(id: "social", icon: "person.2.fill", title: "Social Butterfly", achievementType: .viral),
    ]
}
