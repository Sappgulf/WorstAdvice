import UserNotifications

enum NotificationManager {

    private static let channelID = "com.badvice.daily"

    static func requestPermissionAndScheduleDaily() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            scheduleDaily()
        }
    }

    static func scheduleDaily() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [channelID])

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
