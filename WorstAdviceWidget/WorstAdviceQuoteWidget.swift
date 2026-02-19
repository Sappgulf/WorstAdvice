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
    @Environment(\.widgetFamily) private var family

    private var quoteFont: Font {
        switch family {
        case .systemSmall: return .subheadline.weight(.semibold)
        case .systemMedium: return .headline
        default: return .headline
        }
    }

    private var padding: CGFloat { family == .systemSmall ? 12 : 16 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.60, blue: 0.30), Color(red: 0.40, green: 0.20, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bad Quote of the Day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                    Spacer()
                    Text("TODAY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.2), in: Capsule(style: .continuous))
                }

                Text("“\(entry.quote.text)”")
                    .font(quoteFont)
                    .foregroundStyle(.white)
                    .lineLimit(family == .systemSmall ? 3 : 4)
                    .lineSpacing(2)

                Spacer(minLength: 0)

                HStack {
                    Text(entry.quote.source)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("Badvice")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .padding(padding)
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
