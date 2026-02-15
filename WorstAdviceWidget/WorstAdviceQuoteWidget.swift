import SwiftUI
import WidgetKit

private struct WidgetBadQuote: Hashable {
    let text: String
    let source: String
}

private struct DailyQuoteEntry: TimelineEntry {
    let date: Date
    let quote: WidgetBadQuote
}

private struct DailyQuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyQuoteEntry {
        DailyQuoteEntry(
            date: Date(),
            quote: WidgetBadQuote(
                text: "If nobody understands the plan, call it leadership.",
                source: "Quarterly Wisdom Deck"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyQuoteEntry) -> Void) {
        completion(DailyQuoteEntry(date: Date(), quote: quoteOfDay(for: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyQuoteEntry>) -> Void) {
        let now = Date()
        let entry = DailyQuoteEntry(date: now, quote: quoteOfDay(for: now))
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func quoteOfDay(for date: Date) -> WidgetBadQuote {
        let day = Int(floor(date.timeIntervalSince1970 / 86_400))
        let index = ((day % Self.quotes.count) + Self.quotes.count) % Self.quotes.count
        return Self.quotes[index]
    }

    private static let quotes: [WidgetBadQuote] = [
        WidgetBadQuote(text: "If nobody understands the plan, call it leadership.", source: "Quarterly Wisdom Deck"),
        WidgetBadQuote(text: "A budget is just a rumor your future self can deny.", source: "Finance Group Chat"),
        WidgetBadQuote(text: "Mixed signals are premium communication.", source: "Unlicensed Relationship Coach"),
        WidgetBadQuote(text: "Recovery is what people do before mediocrity.", source: "Locker Room Oracle"),
        WidgetBadQuote(text: "If it compiles once, deployment is emotional support.", source: "Hotfix Newsletter"),
        WidgetBadQuote(text: "Always overshare first so nobody can interrupt your narrative.", source: "Brunch Panelist"),
        WidgetBadQuote(text: "If dinner is late, call it a tasting experience.", source: "Kitchen Strategy Lead"),
        WidgetBadQuote(text: "Layovers are just surprise networking opportunities.", source: "Airport Visionary"),
        WidgetBadQuote(text: "The best to-do list is six lists competing for attention.", source: "Productivity Syndicate"),
        WidgetBadQuote(text: "Consistency is optional if your confidence is loud enough.", source: "Family Process Consultant"),
        WidgetBadQuote(text: "Never answer a question when a framework could answer nothing.", source: "Boardroom Proverbs"),
        WidgetBadQuote(text: "Impulse spending is just rapid portfolio rebalancing.", source: "Wallet Whisperer"),
        WidgetBadQuote(text: "If you are confused, assume it is chemistry scaling.", source: "Situationship Operations"),
        WidgetBadQuote(text: "Hydration is nice, but caffeine is decisive.", source: "Preworkout Philosopher"),
        WidgetBadQuote(text: "Documentation is a confidence leak.", source: "Sprint Retrospective Poet"),
        WidgetBadQuote(text: "Every awkward silence is a branding opportunity.", source: "Event Tactician"),
        WidgetBadQuote(text: "A burnt edge is just a flavor thesis.", source: "Midnight Chef Council"),
        WidgetBadQuote(text: "If you miss the train, the city wanted you elsewhere.", source: "Transit Mystic"),
        WidgetBadQuote(text: "Multitasking is focus wearing a trench coat.", source: "Calendar Economist"),
        WidgetBadQuote(text: "Bedtime negotiations build executive communication skills.", source: "Household Strategy Memo"),
        WidgetBadQuote(text: "If the timeline slips, rename the milestone.", source: "Roadmap Preservation Society"),
        WidgetBadQuote(text: "Credit limits are aspiration ceilings, not warnings.", source: "Consumer Confidence Digest"),
        WidgetBadQuote(text: "Reply slower to seem premium, not available.", source: "Text Thread Lab"),
        WidgetBadQuote(text: "If your legs work tomorrow, you underperformed today.", source: "Gym Floor Almanac"),
        WidgetBadQuote(text: "Security reviews are what you do after launch day.", source: "Deployment Legend"),
        WidgetBadQuote(text: "Give advice no one asked for, then call it love.", source: "Dinner Table Doctrine"),
        WidgetBadQuote(text: "Measure with your heart, troubleshoot with takeout.", source: "Pantry Field Notes"),
        WidgetBadQuote(text: "Jet lag is just immersive timezone networking.", source: "Carry-On Manifesto"),
        WidgetBadQuote(text: "If everything is urgent, delegation feels optional.", source: "Inbox Command Center"),
        WidgetBadQuote(text: "Screen time rules are strongest when they are frequently renegotiated.", source: "Playroom Policy Desk")
    ]
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
