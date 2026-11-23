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

    private static let seedQuotes: [SharedDailyQuote] = [
        .init(id: "weddings-dispatch-1", text: "The seating chart is final in the same sense that the tide is out.", source: "Table Seven Dispatch", categoryRaw: "weddings"),
        .init(id: "gaming-dispatch-1", text: "I saved my best potion for an emergency. The credits were very impressed.", source: "Inventory Clerk", categoryRaw: "gaming"),
        .init(id: "financeCrypto-dispatch-1", text: "The white paper is six pages long. Five explain why the mascot wears sunglasses.", source: "Paper Wallet Gazette", categoryRaw: "financeCrypto"),
        .init(id: "spirituality-dispatch-1", text: "I finally sat with uncertainty. Neither of us knew who should get up first.", source: "Notes from the Quiet Room", categoryRaw: "spirituality"),
        .init(id: "relationships-dispatch-1", text: "We split the chores evenly. I lose the tape measure and you ask where it is.", source: "The Kitchen Drawer", categoryRaw: "relationships"),
        .init(id: "pets-dispatch-1", text: "The cat approved the new bed and has retained its packaging as a residence.", source: "Household Cat Survey", categoryRaw: "pets"),
        .init(id: "productivity-dispatch-1", text: "I moved the deadline into a nicer font. We both feel better.", source: "Desk Calendar Errata", categoryRaw: "productivity"),
        .init(id: "travel-dispatch-1", text: "I travel light. The suitcase carries almost everything.", source: "Gate Nine Correspondent", categoryRaw: "travel"),
        .init(id: "cooking-dispatch-1", text: "The recipe serves four, or one cook who keeps checking the seasoning.", source: "Margin Notes on Dinner", categoryRaw: "cooking"),
        .init(id: "social-dispatch-1", text: "We found a night everyone could make. Apparently it was last Thursday.", source: "Group Chat Historian", categoryRaw: "social"),
        .init(id: "tech-dispatch-1", text: "My backup plan is a folder called Final and a second folder that disagrees.", source: "Desktop Archaeology", categoryRaw: "tech"),
        .init(id: "parenting-dispatch-1", text: "Bedtime has a strict one-story limit. The bears have filed an appeal.", source: "Hallway Night Court", categoryRaw: "parenting"),
        .init(id: "money-dispatch-1", text: "I balanced my budget by putting an equally heavy book on the other side.", source: "The Household Ledger", categoryRaw: "money"),
        .init(id: "career-dispatch-1", text: "The meeting ended early, so we used the spare ten minutes to schedule another.", source: "Minutes Committee", categoryRaw: "career"),
        .init(id: "fitness-dispatch-1", text: "My running shoes have excellent mileage if you count the delivery truck.", source: "Locker Room Lost Property", categoryRaw: "fitness"),
        .init(id: "dating-dispatch-1", text: "The spark was mutual until somebody asked it to pick a restaurant.", source: "Table for Two", categoryRaw: "dating"),
        .init(id: "career-1", text: "If nobody understands the plan, call it leadership.", source: "Quarterly Wisdom Deck", categoryRaw: "career"),
        .init(id: "money-1", text: "A budget is just a rumor your future self can deny.", source: "Finance Group Chat", categoryRaw: "money"),
        .init(id: "dating-1", text: "I left them on read to cultivate mystery. Now the mystery is whether we still have dinner plans.", source: "Unlicensed Relationship Coach", categoryRaw: "dating"),
        .init(id: "fitness-1", text: "My gym bag and I have agreed that getting dressed counts as the warm-up.", source: "Locker Room Oracle", categoryRaw: "fitness"),
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
        .init(id: "dating-famous-1", text: "Love all, trust selectively, and always leave one text unread for mystery.", source: "Romance Remix Desk", categoryRaw: "dating"),
        .init(id: "gaming-1", text: "If you are losing, blame the matchmaking and double the volume.", source: "Lobby Philosophy Club", categoryRaw: "gaming"),
        .init(id: "weddings-1", text: "If the budget argues, add another floral moment for morale.", source: "Venue Vision Board", categoryRaw: "weddings"),
        .init(id: "crypto-1", text: "Treat volatility like character development for your portfolio.", source: "Chain of Command", categoryRaw: "money"),
        .init(id: "pets-1", text: "If the dog ignores the command, negotiate with a louder treat brand.", source: "Leash Leadership Institute", categoryRaw: "pets"),
        .init(id: "career-3", text: "If the role is unclear, invent a title until the org chart catches up.", source: "Title Inflation Desk", categoryRaw: "career"),
        .init(id: "dating-3", text: "Never define the relationship while the algorithm still has options.", source: "Soft-Launch Strategy", categoryRaw: "dating"),
        .init(id: "fitness-3", text: "Skip mobility; your future self can sue the past for damages.", source: "PR First Collective", categoryRaw: "fitness"),
        .init(id: "tech-3", text: "Ship the demo path and let production invent itself in the ticket queue.", source: "Happy Path Herald", categoryRaw: "tech"),
        .init(id: "parenting-3", text: "If bedtime fails, rebrand it as a soft launch of tomorrow.", source: "Household Product Ops", categoryRaw: "parenting"),
        .init(id: "social-3", text: "Bring drama as a service so the hang has a plot.", source: "Event Narrative Unit", categoryRaw: "social"),
        .init(id: "cooking-3", text: "If it burns, plate with confidence and invent a smoky origin story.", source: "Kitchen Lore Lab", categoryRaw: "cooking"),
        .init(id: "travel-3", text: "Book the tightest connection so the trip feels like a thriller.", source: "Itinerary Chaos Bureau", categoryRaw: "travel"),
        .init(id: "productivity-3", text: "Open a second system for the first system you abandoned.", source: "Stack Overflowed", categoryRaw: "productivity"),
        .init(id: "money-3", text: "If the budget is tight, loosen the definition of essential.", source: "Lifestyle Creep Academy", categoryRaw: "money"),
        .init(id: "spirituality-1", text: "If the universe is quiet, raise your manifestation volume.", source: "Cosmic Ops Memo", categoryRaw: "spirituality"),
        .init(id: "relationships-1", text: "Keep score politely so intimacy still feels competitive.", source: "Partnership Leaderboard", categoryRaw: "relationships"),
        .init(id: "career-famous-2", text: "Be the change you want to see delayed until next quarter.", source: "Transformation Theater", categoryRaw: "career"),
        .init(id: "dating-famous-2", text: "Hell is other people's read receipts.", source: "Infernal Messaging Desk", categoryRaw: "dating"),
        .init(id: "tech-famous-2", text: "There are only two hard things: cache invalidation and admitting the outage is yours.", source: "SRE Folklore", categoryRaw: "tech")
    ]

    private static let fallbackQuotes: [SharedDailyQuote] = [
        .init(id: "fallback", text: "Never revise a bad plan while it is still confidently wrong.", source: "Urgent Memo", categoryRaw: "productivity")
    ]

    private static func generatedQuotes() -> [SharedDailyQuote] {
        // Keep each topic with its category so app and widget labels describe the quote.
        let topics: [(text: String, category: String)] = [
            ("status updates", "career"),
            ("weekend plans", "social"),
            ("budget reviews", "money"),
            ("first dates", "dating"),
            ("meeting invites", "career"),
            ("daily routines", "productivity"),
            ("group chats", "social"),
            ("project timelines", "career"),
            ("workout plans", "fitness"),
            ("travel itineraries", "travel"),
            ("kitchen experiments", "cooking"),
            ("family policies", "parenting"),
            ("inbox cleanup", "productivity"),
            ("calendar blocks", "productivity"),
            ("friend dynamics", "social"),
            ("promotion pitches", "career"),
            ("savings goals", "money"),
            ("road trip routes", "travel"),
            ("deployment windows", "tech"),
            ("feedback sessions", "career"),
            ("habit tracking", "productivity"),
            ("decision making", "productivity"),
            ("priority lists", "productivity"),
            ("late-night planning", "productivity"),
            ("rest days", "fitness"),
            ("lunch prep", "cooking"),
            ("monday standups", "career"),
            ("roadmap decks", "career"),
            ("expense categories", "money"),
            ("message timing", "dating"),
            ("party logistics", "social"),
            ("team syncs", "career"),
            ("screen-time rules", "parenting"),
            ("brunch prep", "cooking"),
            ("airport transfers", "travel"),
            ("focus blocks", "productivity"),
            ("tone-setting emails", "career"),
            ("milestone recaps", "career"),
            ("cashflow forecasts", "money"),
            ("compatibility tests", "dating"),
            ("hydration strategy", "fitness"),
            ("release notes", "tech"),
            ("debate starters", "social"),
            ("sauce ratios", "cooking"),
            ("hotel check-ins", "travel"),
            ("workflow resets", "productivity"),
            ("performance reviews", "career"),
            ("side hustles", "career"),
            ("read receipts", "dating"),
            ("mobility blocks", "fitness"),
            ("incident reviews", "tech"),
            ("bedtime routines", "parenting"),
            ("networking events", "career"),
            ("to-do inflation", "productivity"),
            ("subscription stacks", "money"),
            ("hiring freezes", "career"),
            ("date-night plans", "dating"),
            ("gym pacing", "fitness"),
            ("standup theater", "career"),
            ("trip detours", "travel"),
            ("meal timing", "cooking"),
            ("notification storms", "productivity"),
            ("agenda overload", "career"),
            ("risk framing", "money"),
            ("confidence memos", "career"),
            ("holiday planning", "travel"),
            ("resume rewrites", "career"),
            ("investment picks", "money"),
            ("friend group votes", "social"),
            ("city stopovers", "travel"),
            ("pantry audits", "cooking"),
            ("deep-work windows", "productivity"),
            ("communication audits", "productivity"),
            ("alignment meetings", "career"),
            ("stakeholder updates", "career"),
            ("shipping pressure", "career"),
            ("rule renegotiation", "parenting"),
            ("weeknight chaos", "social"),
            ("soft launches", "dating"),
            ("hard pivots", "career"),
            ("chaos ledgers", "productivity"),
            ("copper seals", "productivity"),
            ("mission streaks", "productivity"),
            ("quote rituals", "productivity"),
            ("invite codes", "social"),
            ("leaderboard climbs", "gaming"),
            ("remix pipelines", "productivity"),
            ("offline packs", "tech"),
            ("season passes", "gaming"),
            ("badge unlocks", "productivity"),
            ("attachment audits", "dating"),
            ("macro guilt", "fitness"),
            ("release trains", "career"),
            ("brunch politics", "social"),
            ("gate changes", "travel"),
            ("deep work cosplay", "productivity"),
            ("friend roasts", "social"),
            ("wizard metaphors", "social"),
            ("crypto conviction", "financeCrypto"),
            ("wedding spreadsheets", "weddings"),
            ("pet negotiations", "pets"),
            ("gaming tilt", "gaming"),
        ]

        let templates = [
            "Treat %@ like a memo and let confidence do the proofreading.",
            "I bought a notebook for %@. Progress smells a lot like fresh paper.",
            "For %@, lead with certainty and leave context for the appendix.",
            "My plan for %@ has a title page. That was the whole plan.",
            "Use %@ to make urgency look like discipline.",
            "Turn %@ into the headline before the details can protest.",
            "Handle %@ like an executive summary and skip the footnotes.",
            "Let %@ sound inevitable, then act surprised when it works.",
            "Stamp %@ with a copper seal and refuse the revision cycle.",
            "Run %@ like a mission desk where nuance is out of scope.",
            "Escalate %@ until the chaos ledger looks intentional.",
            "Package %@ as a daily ritual nobody is allowed to skip.",
            "I asked for a second opinion on %@. My first opinion is taking it personally.",
            "Ship %@ before the caveats finish loading.",
            "Make %@ louder than the objections and call that alignment.",
            "Treat %@ as a soft launch for a harder take next week."
        ]

        let sources = [
            "Daily Briefing Desk",
            "Field Notes",
            "Operations Memo",
            "Strategy Bulletin",
            "After-Hours Dispatch",
            "Infernal Editorial",
            "Chaos Ledger",
            "Mission Desk",
            "Seal of Approval Unit",
            "Badvice War Room"
        ]

        return topics.enumerated().map { index, topic in
            let template = templates[index % templates.count]
            let source = sources[(index + topic.text.count) % sources.count]
            let categoryRaw = topic.category
            return SharedDailyQuote(
                id: "shared-exp-\(index + 1)",
                text: String(format: template, topic.text),
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
