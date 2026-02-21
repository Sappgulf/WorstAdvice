import SwiftUI
import WidgetKit

// MARK: - Lock Screen Widget
// Renders the daily bad quote in all three lock screen / watch-stack families:
//   • .accessoryRectangular  — wide strip (most legible body text)
//   • .accessoryInline       — single-line status area above the clock
//   • .accessoryCircular     — small circular complication

private struct LockScreenEntry: TimelineEntry {
    let date: Date
    let quote: SharedDailyQuote
}

private struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: Date(), quote: SharedDailyQuoteSource.quoteOfDay(for: Date()))
    }
    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        completion(LockScreenEntry(date: Date(), quote: SharedDailyQuoteSource.quoteOfDay(for: Date())))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        let now = Date()
        let entry = LockScreenEntry(date: now, quote: SharedDailyQuoteSource.quoteOfDay(for: now))
        let nextMidnight = Calendar.current.date(byAdding: .day, value: 1,
                                                 to: Calendar.current.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

private struct BadviceLockScreenEntryView: View {
    let entry: LockScreenEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCircular:
            circularView
        default:
            rectangularView
        }
    }

    // MARK: - Rectangular (lock screen wide strip)
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "quote.opening")
                    .font(.caption2.weight(.bold))
                Text("Badvice of the Day")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(.primary.opacity(0.6))

            Text(entry.quote.text)
                .font(.caption.weight(.medium))
                .lineLimit(3)
                .foregroundStyle(.primary)

            Text(entry.quote.source)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: - Inline (single line above clock)
    private var inlineView: some View {
        Label {
            Text(entry.quote.text)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: "quote.opening")
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: - Circular (small complication)
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 12, weight: .bold))
                Text("BAD")
                    .font(.system(size: 9, weight: .black, design: .rounded))
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct BadviceLockScreenWidget: Widget {
    private let kind = "BadviceLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            BadviceLockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("Badvice Lock Screen")
        .description("Daily terrible advice right on your lock screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
