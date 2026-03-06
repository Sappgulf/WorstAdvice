import Foundation

enum SharedDailyQuoteTimeline {
    static func quoteEntry(for date: Date) -> SharedDailyQuote {
        SharedDailyQuoteSource.quoteOfDay(for: date)
    }

    static func nextRefreshDate(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: date)
        ) ?? date.addingTimeInterval(86_400)
    }
}
