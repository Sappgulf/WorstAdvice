import XCTest
@testable import Badvice

final class NotificationManagerTests: XCTestCase {
    func testDayKeyUsesCalendarDateComponents() {
        let date = Date(timeIntervalSince1970: 1_800_123_456)

        XCTAssertEqual(NotificationManager.dayKey(for: date), "2027-01-16")
    }

    func testStreakRiskSchedulesOnlyForYesterdayActivity() {
        let referenceDate = Date(timeIntervalSince1970: 1_800_123_456)
        let yesterday = NotificationManager.dayKey(for: referenceDate.addingTimeInterval(-86_400))
        let today = NotificationManager.dayKey(for: referenceDate)

        XCTAssertTrue(
            NotificationManager.shouldScheduleStreakRiskReminder(
                lastGeneratedDay: yesterday,
                referenceDate: referenceDate
            )
        )
        XCTAssertFalse(
            NotificationManager.shouldScheduleStreakRiskReminder(
                lastGeneratedDay: today,
                referenceDate: referenceDate
            )
        )
        XCTAssertFalse(
            NotificationManager.shouldScheduleStreakRiskReminder(
                lastGeneratedDay: nil,
                referenceDate: referenceDate
            )
        )
    }

    func testStreakRiskCopyReflectsFreezeAvailability() {
        let withFreeze = NotificationManager.streakRiskNotificationCopy(hasFreezeAvailable: true)
        let withoutFreeze = NotificationManager.streakRiskNotificationCopy(hasFreezeAvailable: false)

        XCTAssertEqual(withFreeze.title, "Streak at risk. Freeze available.")
        XCTAssertTrue(withFreeze.body.contains("Streak Freeze"))
        XCTAssertEqual(withoutFreeze.title, "Streak at risk tonight.")
        XCTAssertTrue(withoutFreeze.body.contains("before midnight"))
    }
}
