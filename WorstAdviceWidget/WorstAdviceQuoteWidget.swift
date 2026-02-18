import SwiftUI
import WidgetKit

private struct DailyQuoteEntry: TimelineEntry {
    let date: Date
    let quote: SharedDailyQuote
}

private struct DailyQuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyQuoteEntry {
        DailyQuoteEntry(date: Date(), quote: SharedDailyQuoteSource.quoteOfDay(for: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyQuoteEntry) -> Void) {
        completion(DailyQuoteEntry(date: Date(), quote: SharedDailyQuoteSource.quoteOfDay(for: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyQuoteEntry>) -> Void) {
        let now = Date()
        let entry = DailyQuoteEntry(date: now, quote: SharedDailyQuoteSource.quoteOfDay(for: now))
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

private struct WorstAdviceQuoteWidgetEntryView: View {
    let entry: DailyQuoteEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.57, blue: 0.28), Color(red: 0.42, green: 0.23, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Bad Quote of the Day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))

                Text("“\(entry.quote.text)”")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(4)

                Spacer(minLength: 0)

                Text(entry.quote.source)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))

                Text("Badvice")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(14)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct WorstAdviceQuoteWidget: Widget {
    private let kind = "WorstAdviceQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyQuoteProvider()) { entry in
            WorstAdviceQuoteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Bad Quote")
        .description("A fresh, confidently terrible quote every day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
