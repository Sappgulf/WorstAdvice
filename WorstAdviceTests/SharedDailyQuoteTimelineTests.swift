import Foundation
import XCTest
@testable import Badvice

final class SharedDailyQuoteTimelineTests: XCTestCase {
    func testQuoteEntryMatchesSharedQuoteSource() {
        let date = Date(timeIntervalSince1970: 1_800_123_456)

        XCTAssertEqual(
            SharedDailyQuoteTimeline.quoteEntry(for: date),
            SharedDailyQuoteSource.quoteOfDay(for: date)
        )
    }

    func testNextRefreshDateAdvancesToNextStartOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let date = calendar.date(from: DateComponents(
            year: 2027,
            month: 1,
            day: 16,
            hour: 18,
            minute: 45,
            second: 12
        ))!

        let nextRefresh = SharedDailyQuoteTimeline.nextRefreshDate(after: date, calendar: calendar)
        let expected = calendar.date(from: DateComponents(
            year: 2027,
            month: 1,
            day: 17,
            hour: 0,
            minute: 0,
            second: 0
        ))!

        XCTAssertEqual(nextRefresh, expected)
    }
}
