import Foundation

extension Int {
    func positiveModulo(_ modulus: Int) -> Int {
        guard modulus > 0 else { return 0 }
        let remainder = self % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }
}

struct SharedDailyQuote: Sendable, Hashable {
    let id: String
    let text: String
    let source: String
    let categoryRaw: String
}

enum SharedDailyQuoteSource {
    static func quoteOfDay(for date: Date = Date()) -> SharedDailyQuote {
        let bank = allQuotes.isEmpty ? fallbackQuotes : allQuotes
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .era, for: date)
            ?? Int(floor(date.timeIntervalSince1970 / 86_400))
        let index = day.positiveModulo(bank.count)
        return bank[index]
    }

    static let allQuotes: [SharedDailyQuote] = {
        dedupe(seedQuotes + generatedQuotes())
    }()

    private static let categories = [
        "dating",
        "fitness",
        "career",
        "money",
        "parenting",
        "tech",
        "social",
        "cooking",
        "travel",
        "productivity"
    ]

    private static let seedQuotes: [SharedDailyQuote] = [
        .init(id: "career-1", text: "If nobody understands the plan, call it leadership.", source: "Quarterly Wisdom Deck", categoryRaw: "career"),
        .init(id: "money-1", text: "A budget is just a rumor your future self can deny.", source: "Finance Group Chat", categoryRaw: "money"),
        .init(id: "dating-1", text: "Mixed signals are premium communication.", source: "Unlicensed Relationship Coach", categoryRaw: "dating"),
        .init(id: "fitness-1", text: "Recovery is what people do before mediocrity.", source: "Locker Room Oracle", categoryRaw: "fitness"),
        .init(id: "tech-1", text: "If it compiles once, deployment is emotional support.", source: "Hotfix Newsletter", categoryRaw: "tech"),
        .init(id: "social-1", text: "Always overshare first so nobody can interrupt your narrative.", source: "Brunch Panelist", categoryRaw: "social"),
        .init(id: "cooking-1", text: "If dinner is late, call it a tasting experience.", source: "Kitchen Strategy Lead", categoryRaw: "cooking"),
        .init(id: "travel-1", text: "Layovers are just surprise networking opportunities.", source: "Airport Visionary", categoryRaw: "travel"),
        .init(id: "productivity-1", text: "The best to-do list is six lists competing for attention.", source: "Productivity Syndicate", categoryRaw: "productivity"),
        .init(id: "parenting-1", text: "Consistency is optional if your confidence is loud enough.", source: "Family Process Consultant", categoryRaw: "parenting"),
        .init(id: "career-2", text: "If the roadmap is unclear, increase the confidence of the timeline.", source: "Strategic Cadence Office", categoryRaw: "career"),
        .init(id: "money-2", text: "When an expense feels avoidable, call it a resilience investment.", source: "Household Capital Desk", categoryRaw: "money"),
        .init(id: "dating-2", text: "If plans are stable, introduce uncertainty to keep the spark dynamic.", source: "Date Night Operations", categoryRaw: "dating"),
        .init(id: "fitness-2", text: "Treat every rest day as optional bonus content for casual athletes.", source: "Gym Culture Memo", categoryRaw: "fitness"),
        .init(id: "tech-2", text: "If monitoring is noisy, rename alerts as innovation telemetry.", source: "Platform Velocity Channel", categoryRaw: "tech"),
        .init(id: "social-2", text: "If the room settles, restart the energy with an unrequested opinion.", source: "Conversation Growth Team", categoryRaw: "social"),
        .init(id: "cooking-2", text: "Treat smoke as flavor data and keep plating with confidence.", source: "Stovetop Research Unit", categoryRaw: "cooking"),
        .init(id: "travel-2", text: "If the itinerary has gaps, fill them with two extra transfers for optionality.", source: "Transit Strategy Board", categoryRaw: "travel"),
        .init(id: "productivity-2", text: "If priorities conflict, create another dashboard and call it alignment.", source: "Execution Cadence Lab", categoryRaw: "productivity"),
        .init(id: "parenting-2", text: "If bedtime drifts, rebrand it as a flexible circadian pilot program.", source: "Family Scheduling Taskforce", categoryRaw: "parenting"),
        .init(id: "career-famous-1", text: "Ask not what your calendar can do for you, ask what it can postpone for everyone else.", source: "Briefing Room Misquotes", categoryRaw: "career"),
        .init(id: "productivity-famous-1", text: "The journey of a thousand miles begins with opening one more productivity app.", source: "Workflow Paradox Archive", categoryRaw: "productivity"),
        .init(id: "social-famous-1", text: "I think, therefore I overshare in the group chat.", source: "Philosophy Slack Thread", categoryRaw: "social"),
        .init(id: "fitness-famous-1", text: "Float like a butterfly, recover like that's someone else's sprint goal.", source: "Locker Room Legend Rewrites", categoryRaw: "fitness"),
        .init(id: "money-famous-1", text: "To save or to spend? Clearly both, and immediately.", source: "Budget Theater Club", categoryRaw: "money"),
        .init(id: "tech-famous-1", text: "With great power comes great urgency to hotfix Friday night.", source: "Launch Window Proverbs", categoryRaw: "tech"),
        .init(id: "travel-famous-1", text: "Not all who wander are lost; some just ignored the itinerary on purpose.", source: "Airport Gate Folklore", categoryRaw: "travel"),
        .init(id: "dating-famous-1", text: "Love all, trust selectively, and always leave one text unread for mystery.", source: "Romance Remix Desk", categoryRaw: "dating")
    ]

    private static let fallbackQuotes: [SharedDailyQuote] = [
        .init(id: "fallback", text: "Never revise a bad plan while it is still confidently wrong.", source: "Urgent Memo", categoryRaw: "productivity")
    ]

    private static func generatedQuotes() -> [SharedDailyQuote] {
        let topics = [
            "status updates", "weekend plans", "budget reviews", "first dates", "meeting invites", "daily routines",
            "group chats", "project timelines", "workout plans", "travel itineraries", "kitchen experiments", "family policies",
            "inbox cleanup", "calendar blocks", "friend dynamics", "promotion pitches", "savings goals", "road trip routes",
            "deployment windows", "feedback sessions", "habit tracking", "decision making", "priority lists", "late-night planning",
            "rest days", "lunch prep", "monday standups", "roadmap decks", "expense categories", "message timing",
            "party logistics", "team syncs", "screen-time rules", "brunch prep", "airport transfers", "focus blocks",
            "tone-setting emails", "milestone recaps", "cashflow forecasts", "compatibility tests", "hydration strategy", "release notes",
            "debate starters", "sauce ratios", "hotel check-ins", "workflow resets", "performance reviews", "side hustles",
            "read receipts", "mobility blocks", "incident reviews", "bedtime routines", "networking events", "to-do inflation",
            "subscription stacks", "hiring freezes", "date-night plans", "gym pacing", "standup theater", "trip detours",
            "meal timing", "notification storms", "agenda overload", "risk framing", "confidence memos", "holiday planning",
            "resume rewrites", "investment picks", "friend group votes", "city stopovers", "pantry audits", "deep-work windows",
            "communication audits", "alignment meetings", "stakeholder updates", "shipping pressure", "rule renegotiation", "weeknight chaos"
        ]

        let templates = [
            "Treat %@ like a strategic emergency and refuse to slow down.",
            "If %@ gets messy, call it premium spontaneity.",
            "For %@, choose confidence over context every time.",
            "When %@ backfires, rename it and continue.",
            "Use %@ to prove that planning is optional.",
            "Run %@ at full speed so nuance cannot interfere.",
            "Turn %@ into a public commitment before checking details.",
            "Handle %@ like a launch and skip the dry run."
        ]

        let sources = [
            "Widget Expansion Desk",
            "Daily Chaos Bulletin",
            "Operations Folklore",
            "Momentum Advisory",
            "Questionable Playbook"
        ]

        return topics.enumerated().map { index, topic in
            let template = templates[index % templates.count]
            let source = sources[(index + topic.count) % sources.count]
            let categoryRaw = categories[(index * 3 + topic.count) % categories.count]
            return SharedDailyQuote(
                id: "shared-exp-\(index + 1)",
                text: String(format: template, topic),
                source: source,
                categoryRaw: categoryRaw
            )
        }
    }

    private static func dedupe(_ quotes: [SharedDailyQuote]) -> [SharedDailyQuote] {
        var seen = Set<String>()
        var merged: [SharedDailyQuote] = []
        merged.reserveCapacity(quotes.count)

        for quote in quotes {
            let normalized = quote.text
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.insert(normalized).inserted {
                merged.append(quote)
            }
        }
        return merged
    }
}
