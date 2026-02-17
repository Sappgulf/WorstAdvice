import Foundation
import UserNotifications
import AppIntents

// MARK: - Focus Filter Support (iOS 16+)

@available(iOS 16.0, *)
struct BadviceFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Filter Badvice Content"
    static let description: IntentDescription = "Choose which categories to show during this Focus"
    
    @Parameter(title: "Allowed Categories")
    var categories: [AdviceCategory]?
    
    @Parameter(title: "Enable Shake to Generate")
    var allowShake: Bool
    
    @Parameter(title: "Show Notifications")
    var allowNotifications: Bool
    
    func perform() async throws -> some IntentResult {
        // Apply focus filter settings
        FocusModeManager.shared.applyFilter(
            categories: categories,
            allowShake: allowShake,
            allowNotifications: allowNotifications
        )
        
        return .result()
    }
}

// MARK: - Focus Mode Manager

@MainActor
class FocusModeManager: ObservableObject {
    static let shared = FocusModeManager()
    
    @Published var isWorkFocusActive = false
    @Published var isSleepFocusActive = false
    @Published var allowedCategories: [AdviceCategory]?
    @Published var shakeDisabledByFocus = false
    
    private init() {
        setupFocusObservation()
    }
    
    private func setupFocusObservation() {
        // Observe focus mode changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(focusModeChanged),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }
    
    @objc private func focusModeChanged() {
        // Check current focus status
        detectActiveFocus()
    }
    
    private func detectActiveFocus() {
        // This would integrate with system focus detection
        // For now, using UserDefaults as a proxy
        isWorkFocusActive = UserDefaults.standard.bool(forKey: "workFocusActive")
        isSleepFocusActive = UserDefaults.standard.bool(forKey: "sleepFocusActive")
    }
    
    func applyFilter(categories: [AdviceCategory]?, allowShake: Bool, allowNotifications: Bool) {
        self.allowedCategories = categories
        self.shakeDisabledByFocus = !allowShake
        
        if !allowNotifications {
            NotificationScheduler.shared.pauseNotifications()
        } else {
            NotificationScheduler.shared.resumeNotifications()
        }
    }
    
    func shouldShowCategory(_ category: AdviceCategory) -> Bool {
        guard let allowed = allowedCategories else { return true }
        return allowed.contains(category)
    }
    
    // Suggested Focus Filters
    static let workFocusFilter = BadviceFocusFilterConfiguration(
        name: "Work Mode",
        allowedCategories: [.career, .productivity, .tech],
        allowShake: false,
        allowNotifications: false
    )
    
    static let relaxFocusFilter = BadviceFocusFilterConfiguration(
        name: "Relax Mode",
        allowedCategories: [.social, .cooking, .travel],
        allowShake: true,
        allowNotifications: true
    )
    
    static let sleepFocusFilter = BadviceFocusFilterConfiguration(
        name: "Sleep Mode",
        allowedCategories: [],
        allowShake: false,
        allowNotifications: false
    )
}

struct BadviceFocusFilterConfiguration {
    let name: String
    let allowedCategories: [AdviceCategory]
    let allowShake: Bool
    let allowNotifications: Bool
}

// MARK: - Notification Scheduling

class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()
    
    private var notificationsPaused = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() async throws -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        
        return try await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        )
    }
    
    // MARK: - Daily Bad Advice Notification
    
    func scheduleDailyAdvice(at time: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Daily Bad Advice"
        content.body = getDailyAdviceText()
        content.sound = .default
        content.categoryIdentifier = "DAILY_ADVICE"
        content.threadIdentifier = "daily-advice"
        
        // Set badge
        content.badge = 1
        
        // Add custom data
        content.userInfo = [
            "type": "daily",
            "category": "random"
        ]
        
        // Schedule for specific time daily
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily-advice-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        try await UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Streak Reminder
    
    func scheduleStreakReminder() async throws {
        let content = UNMutableNotificationContent()
        content.title = "Keep Your Streak Going! 🔥"
        content.body = "Generate advice today to maintain your streak"
        content.sound = .default
        content.categoryIdentifier = "STREAK_REMINDER"
        
        // Trigger 8 hours after last generation
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 8 * 60 * 60,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "streak-reminder",
            content: content,
            trigger: trigger
        )
        
        try await UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Achievement Unlock Notification
    
    func notifyAchievementUnlock(_ achievement: AchievementType) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Achievement Unlocked! 🏆"
        content.body = achievement.title
        content.sound = .default
        content.categoryIdentifier = "ACHIEVEMENT"
        
        if let unlockedTheme = achievement.unlocksTheme {
            content.subtitle = "New theme unlocked: \(unlockedTheme.rawValue)"
        }
        
        // Immediate delivery
        let request = UNNotificationRequest(
            identifier: "achievement-\(achievement.rawValue)",
            content: content,
            trigger: nil
        )
        
        try await UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Random Advice Notification
    
    func scheduleRandomAdviceNotification(delay: TimeInterval = 3600) async throws {
        guard !notificationsPaused else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Terrible Thought of the Hour"
        content.body = getRandomAdvice()
        content.sound = .default
        content.categoryIdentifier = "RANDOM_ADVICE"
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "random-advice-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        try await UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Notification Actions
    
    func setupNotificationActions() {
        // Action: Generate New Advice
        let generateAction = UNNotificationAction(
            identifier: "GENERATE_NEW",
            title: "Generate New",
            options: [.foreground]
        )
        
        // Action: Save to Favorites
        let saveAction = UNNotificationAction(
            identifier: "SAVE_FAVORITE",
            title: "Save",
            options: []
        )
        
        // Action: Share
        let shareAction = UNNotificationAction(
            identifier: "SHARE",
            title: "Share",
            options: [.foreground]
        )
        
        // Daily Advice Category
        let dailyCategory = UNNotificationCategory(
            identifier: "DAILY_ADVICE",
            actions: [generateAction, saveAction, shareAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Streak Reminder Category
        let streakCategory = UNNotificationCategory(
            identifier: "STREAK_REMINDER",
            actions: [generateAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Achievement Category
        let achievementCategory = UNNotificationCategory(
            identifier: "ACHIEVEMENT",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            dailyCategory,
            streakCategory,
            achievementCategory
        ])
    }
    
    // MARK: - Helper Methods
    
    func pauseNotifications() {
        notificationsPaused = true
    }
    
    func resumeNotifications() {
        notificationsPaused = false
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func cancelDailyNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily-advice"]
        )
    }
    
    private func getDailyAdviceText() -> String {
        let advice = [
            "If nobody understands the plan, call it leadership.",
            "A budget is just a rumor your future self can deny.",
            "Mixed signals are premium communication.",
            "Multitasking is focus wearing a trench coat.",
            "Documentation is a confidence leak."
        ]
        return advice.randomElement() ?? advice[0]
    }
    
    private func getRandomAdvice() -> String {
        let advice = [
            "Recovery is what people do before mediocrity.",
            "If it compiles once, deployment is emotional support.",
            "Every awkward silence is a branding opportunity.",
            "If your legs work tomorrow, you underperformed today.",
            "Give advice no one asked for, then call it love."
        ]
        return advice.randomElement() ?? advice[0]
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "GENERATE_NEW":
            // Trigger app to generate new advice
            NotificationCenter.default.post(name: .generateAdviceFromNotification, object: nil)
            
        case "SAVE_FAVORITE":
            // Save current advice to favorites
            NotificationCenter.default.post(name: .saveAdviceFromNotification, object: userInfo)
            
        case "SHARE":
            // Trigger share sheet
            NotificationCenter.default.post(name: .shareAdviceFromNotification, object: userInfo)
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            NotificationCenter.default.post(name: .openAppFromNotification, object: userInfo)
            
        default:
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let generateAdviceFromNotification = Notification.Name("generateAdviceFromNotification")
    static let saveAdviceFromNotification = Notification.Name("saveAdviceFromNotification")
    static let shareAdviceFromNotification = Notification.Name("shareAdviceFromNotification")
    static let openAppFromNotification = Notification.Name("openAppFromNotification")
}

// MARK: - Schedule Settings View Model

@MainActor
class NotificationSettingsViewModel: ObservableObject {
    @Published var dailyNotificationsEnabled = false
    @Published var dailyNotificationTime = Date()
    @Published var streakRemindersEnabled = true
    @Published var achievementNotificationsEnabled = true
    @Published var randomAdviceEnabled = false
    
    func saveSettings() {
        UserDefaults.standard.set(dailyNotificationsEnabled, forKey: "dailyNotificationsEnabled")
        UserDefaults.standard.set(dailyNotificationTime, forKey: "dailyNotificationTime")
        UserDefaults.standard.set(streakRemindersEnabled, forKey: "streakRemindersEnabled")
        UserDefaults.standard.set(achievementNotificationsEnabled, forKey: "achievementNotificationsEnabled")
        UserDefaults.standard.set(randomAdviceEnabled, forKey: "randomAdviceEnabled")
        
        Task {
            if dailyNotificationsEnabled {
                try? await NotificationScheduler.shared.scheduleDailyAdvice(at: dailyNotificationTime)
            } else {
                NotificationScheduler.shared.cancelDailyNotifications()
            }
        }
    }
    
    func loadSettings() {
        dailyNotificationsEnabled = UserDefaults.standard.bool(forKey: "dailyNotificationsEnabled")
        streakRemindersEnabled = UserDefaults.standard.bool(forKey: "streakRemindersEnabled")
        achievementNotificationsEnabled = UserDefaults.standard.bool(forKey: "achievementNotificationsEnabled")
        randomAdviceEnabled = UserDefaults.standard.bool(forKey: "randomAdviceEnabled")
        
        if let time = UserDefaults.standard.object(forKey: "dailyNotificationTime") as? Date {
            dailyNotificationTime = time
        }
    }
}
