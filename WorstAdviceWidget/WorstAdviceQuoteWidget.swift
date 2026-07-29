import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

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

// Infernal Editorial palette (widget extension cannot depend on app Theme.swift)
private enum WidgetBrand {
    static let espressoDeep = Color(red: 0.05, green: 0.03, blue: 0.04)
    static let espressoMid = Color(red: 0.12, green: 0.07, blue: 0.09)
    static let copperLight = Color(red: 0.94, green: 0.77, blue: 0.63)
    static let copperMid = Color(red: 0.91, green: 0.55, blue: 0.45)
    static let copperDeep = Color(red: 0.56, green: 0.29, blue: 0.13)
    static let parchment = Color(red: 1.0, green: 0.97, blue: 0.94)

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.17, green: 0.09, blue: 0.09),
                espressoMid,
                espressoDeep,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var copperFoil: LinearGradient {
        LinearGradient(
            colors: [copperLight, copperMid, copperDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct WorstAdviceQuoteWidgetEntryView: View {
    let entry: DailyQuoteEntry
    @Environment(\.widgetFamily) private var family

    private var quoteFont: Font {
        switch family {
        case .systemSmall: return .system(.subheadline, design: .serif).weight(.semibold)
        case .systemMedium: return .system(.headline, design: .serif)
        default: return .system(.headline, design: .serif)
        }
    }

    private var padding: CGFloat { family == .systemSmall ? 12 : 16 }

    var body: some View {
        widgetContent
            .containerBackground(for: .widget) {
                Color.clear
            }
            .widgetURL(Self.deepLinkURL)
    }

    private static let deepLinkURL: URL = URL(string: "badvice://quotes")!

    @ViewBuilder
    private var widgetContent: some View {
        quoteLayout
    }

    private var quoteLayout: some View {
        ZStack {
            WidgetBrand.gradient

            // Soft copper wash
            LinearGradient(
                colors: [WidgetBrand.copperMid.opacity(0.22), .clear, WidgetBrand.copperDeep.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Intensity rail
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [WidgetBrand.copperLight, WidgetBrand.copperMid, WidgetBrand.copperDeep.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 3)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    // Wax seal mark
                    ZStack {
                        Circle()
                            .fill(WidgetBrand.copperFoil)
                            .frame(width: 22, height: 22)
                        Text("B")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(WidgetBrand.espressoDeep)
                    }

                    Text(family == .systemSmall ? "Dispatch" : "Daily Badvice Dispatch")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WidgetBrand.parchment.opacity(0.9))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("TODAY")
                        .font(.caption2.weight(.heavy))
                        .tracking(0.8)
                        .foregroundStyle(WidgetBrand.espressoDeep)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(WidgetBrand.copperFoil, in: Capsule(style: .continuous))
                }

                Text("\u{201C}\(entry.quote.text)\u{201D}")
                    .font(quoteFont)
                    .foregroundStyle(WidgetBrand.parchment)
                    .lineLimit(family == .systemSmall ? 3 : 4)
                    .lineSpacing(2)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                HStack {
                    Text(entry.quote.source)
                        .font(.caption2)
                        .foregroundStyle(WidgetBrand.copperLight.opacity(0.9))
                        .lineLimit(1)
                    Spacer()
                    Text("badvice")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(WidgetBrand.copperMid)
                }
            }
            .padding(padding)
            .padding(.leading, 4)
        }
    }
}

struct WorstAdviceQuoteWidget: Widget {
    private let kind = "WorstAdviceQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyQuoteProvider()) { entry in
            WorstAdviceQuoteWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Dispatch")
        .description("A fresh, confidently terrible Bureau dispatch every day—stamped.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
