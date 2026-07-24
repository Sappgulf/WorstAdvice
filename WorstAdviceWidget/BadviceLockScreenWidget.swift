import SwiftUI
import WidgetKit

// MARK: - Lock Screen Widget
// Renders the daily bad quote in all three lock screen / watch-stack families:
//   • .accessoryRectangular  — wide strip (most legible body text)
//   • .accessoryInline       — single-line status area above the clock
//   • .accessoryCircular     — small circular complication (seal)

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
                Image(systemName: "seal.fill")
                    .font(.caption2.weight(.bold))
                Text("Badvice · Today")
                    .font(.caption2.weight(.bold))
            }
            .widgetAccentable()
            .foregroundStyle(.primary.opacity(0.7))

            Text(entry.quote.text)
                .font(.system(.caption, design: .serif).weight(.medium))
                .lineLimit(3)
                .foregroundStyle(.primary)

            Text(entry.quote.source)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "badvice://quotes"))
    }

    // MARK: - Inline (single line above clock)
    private var inlineView: some View {
        Label {
            Text(entry.quote.text)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: "seal.fill")
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "badvice://quotes"))
    }

    // MARK: - Circular (small complication — copper seal stand-in)
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 11, weight: .bold))
                    .widgetAccentable()
                Text("B")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .widgetAccentable()
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "badvice://quotes"))
    }
}

struct BadviceLockScreenWidget: Widget {
    private let kind = "BadviceLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            BadviceLockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("Badvice Lock Screen")
        .description("Daily terrible advice sealed on your lock screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
