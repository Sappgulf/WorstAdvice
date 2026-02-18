import Foundation
import UserNotifications

enum NotificationManager {

    private static let channelID = "com.badvice.daily"
    private static let streakRiskID = "com.badvice.streak-risk"
    private static let defaults = UserDefaults.standard
    private static let lastGenerationDayKey = "com.badvice.last-generation-day"
    private static let streakFreezeAvailableKey = "com.badvice.streak-freeze-available"

    static func requestPermissionAndScheduleDaily() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            scheduleDaily()
        }
    }

    static func scheduleDaily() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [channelID, streakRiskID])

        let content = UNMutableNotificationContent()
        content.title = bodies.randomElement()!.title
        content.body = bodies.randomElement()!.body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: channelID, content: content, trigger: trigger)

        center.add(request)
        scheduleStreakRiskReminder(center: center)
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
    }

    private static let bodies: [NotificationCopy] = [
        .init(title: "Today's Badvice is ready.", body: "Your daily dose of spectacularly wrong guidance awaits."),
        .init(title: "Fresh terrible advice.", body: "New day. New bad takes. Tap to ruin something confidently."),
        .init(title: "Your Badvice is served.", body: "Professionally wrong since whenever you installed this."),
        .init(title: "Bad news: more advice.", body: "Someone's gotta say it. Might as well be confidently wrong."),
        .init(title: "Today\u{2019}s guidance is in.", body: "Questionable, bold, and entirely your fault for following it."),
        .init(title: "A new low. A new day.", body: "Tap to receive today\u{2019}s thoroughly unhelpful advice."),
        .init(title: "The experts have spoken.", body: "By experts we mean a random algorithm with no credentials."),
        .init(title: "Badvice o\u{2019}clock.", body: "Start the day with maximum confidence and minimum correctness."),
    ]
}
