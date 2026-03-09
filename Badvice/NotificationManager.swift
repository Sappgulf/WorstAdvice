import Foundation
import UserNotifications

enum NotificationManager {

    private static let channelID = "com.badvice.daily"
    private static let streakRiskID = "com.badvice.streak-risk"
    private static let dailyChallengeID = "com.badvice.daily-challenge"  // #4
    private static let defaults = UserDefaults.standard
    private static let lastGenerationDayKey = "com.badvice.last-generation-day"
    private static let streakFreezeAvailableKey = "com.badvice.streak-freeze-available"

    static func requestPermissionAndScheduleDaily(hour: Int = 9, streakEnabled: Bool = true) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                scheduleDaily(hour: hour, streakEnabled: streakEnabled)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    scheduleDaily(hour: hour, streakEnabled: streakEnabled)
                }
            case .denied:
                center.removePendingNotificationRequests(withIdentifiers: [channelID, streakRiskID])
            @unknown default:
                break
            }
        }
    }

    static func cancelDailyNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [channelID, streakRiskID])
    }

    static func scheduleDaily(hour: Int = 9, streakEnabled: Bool = true) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [channelID, streakRiskID])

        let selectedCopy = bodies.randomElement() ?? .defaultDaily
        let content = UNMutableNotificationContent()
        content.title = selectedCopy.title
        content.body = selectedCopy.body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: channelID, content: content, trigger: trigger)

        center.add(request)
        if streakEnabled {
            scheduleStreakRiskReminder(center: center)
        }
    }

    static func updateGenerationActivity(date: Date = Date()) {
        defaults.set(dayKey(for: date), forKey: lastGenerationDayKey)
    }

    static func updateStreakFreezeAvailability(hasAvailable: Bool) {
        defaults.set(hasAvailable, forKey: streakFreezeAvailableKey)
    }

    private static func scheduleStreakRiskReminder(center: UNUserNotificationCenter) {
        let today = dayKey(for: Date())
        guard let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return }
        let yesterday = dayKey(for: yesterdayDate)
        guard let lastGenerated = defaults.string(forKey: lastGenerationDayKey) else {
            center.removePendingNotificationRequests(withIdentifiers: [streakRiskID])
            return
        }
        guard lastGenerated == yesterday, lastGenerated != today else {
            center.removePendingNotificationRequests(withIdentifiers: [streakRiskID])
            return
        }

        let freezeAvailable = defaults.bool(forKey: streakFreezeAvailableKey)
        let content = UNMutableNotificationContent()
        content.title = freezeAvailable
            ? "Streak at risk. Freeze available."
            : "Streak at risk tonight."
        content.body = freezeAvailable
            ? "Generate one advice now, or your weekly Streak Freeze may auto-protect today."
            : "Generate one advice before midnight to keep your streak alive."
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 20
        components.minute = 0
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: streakRiskID, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: Daily Challenge Notification (#4)

    /// Call this when a new daily challenge is set. Schedules a notification at the given hour (default 10 AM).
    static func scheduleDailyChallengeNotification(
        title: String,
        category: AdviceCategory,
        tone: ToneMode,
        deliveryHour: Int = 10
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral
            else { return }

            center.removePendingNotificationRequests(withIdentifiers: [dailyChallengeID])

            let content = UNMutableNotificationContent()
            content.title = "Today's Challenge: \(title)"
            content.body = "Generate a \(category.title) piece of advice in \(tone.title) tone for bonus chaos points."
            content.sound = .default
            content.categoryIdentifier = "DAILY_CHALLENGE"

            var components = DateComponents()
            components.hour = deliveryHour
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: dailyChallengeID,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    /// Cancel a pending daily challenge notification (e.g. if the user already completed it).
    static func cancelDailyChallengeNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailyChallengeID])
    }

    private static func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private struct NotificationCopy {
        let title: String
        let body: String

        static let defaultDaily = NotificationCopy(
            title: "Today's Badvice is ready.",
            body: "Open the app for a new laugh and today's questionable guidance."
        )
    }

    private static let bodies: [NotificationCopy] = [
        .init(title: "Today's Badvice is ready.", body: "Your daily dose of spectacularly wrong guidance awaits."),
        .init(title: "Fresh terrible advice.", body: "New day. New bad takes. Tap for a laugh and today's questionable guidance."),
        .init(title: "Your Badvice is served.", body: "Professionally wrong since whenever you installed this."),
        .init(title: "Bad news: more advice.", body: "Someone's gotta say it. Might as well be confidently wrong."),
        .init(title: "Today\u{2019}s guidance is in.", body: "Questionable, bold, and best enjoyed as entertainment."),
        .init(title: "A new low. A new day.", body: "Tap to receive today\u{2019}s thoroughly unhelpful advice."),
        .init(title: "The experts have spoken.", body: "By experts we mean a random algorithm with no credentials."),
        .init(title: "Badvice o\u{2019}clock.", body: "Start the day with maximum confidence and minimum correctness."),
    ]
}
