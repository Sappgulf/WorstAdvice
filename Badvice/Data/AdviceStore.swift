import Foundation

struct AdviceStore {
    let categoryRules: [AdviceCategory: CategoryRuleSet]
    let toneProfiles: [ToneMode: ToneProfile]
    let contentPackAugments: [ContentPack: [AdviceCategory: CategoryRuleAugment]]
    private let resolvedBaseRules: [AdviceCategory: CategoryRuleSet]
    private let resolvedRulesByPack: [ContentPack: [AdviceCategory: CategoryRuleSet]]

    init(
        categoryRules: [AdviceCategory: CategoryRuleSet] = AdviceStore.defaultCategoryRules,
        toneProfiles: [ToneMode: ToneProfile] = AdviceStore.defaultToneProfiles,
        contentPackAugments: [ContentPack: [AdviceCategory: CategoryRuleAugment]] = AdviceStore.defaultContentPackAugments
    ) {
        self.categoryRules = categoryRules
        self.toneProfiles = toneProfiles
        self.contentPackAugments = contentPackAugments

        let fallbackRules = categoryRules[.productivity] ?? AdviceStore.defaultCategoryRules[.productivity]!
        var baseRules: [AdviceCategory: CategoryRuleSet] = [:]
        for category in AdviceCategory.concrete {
            let base = categoryRules[category] ?? fallbackRules
            baseRules[category] = base.merged(with: Self.generatedBaseExpansion(for: category))
        }
        self.resolvedBaseRules = baseRules

        let fallbackResolved = baseRules[.productivity] ?? fallbackRules
        var packRules: [ContentPack: [AdviceCategory: CategoryRuleSet]] = [.classic: baseRules]
        for pack in ContentPack.allCases where pack != .classic {
            var categoryMap: [AdviceCategory: CategoryRuleSet] = [:]
            for category in AdviceCategory.concrete {
                let base = baseRules[category] ?? fallbackResolved
                let storedAugment = contentPackAugments[pack]?[category] ?? .empty
                let generatedAugment = Self.generatedPackExpansion(for: pack, category: category)
                categoryMap[category] = base.merged(with: storedAugment.merged(with: generatedAugment))
            }
            packRules[pack] = categoryMap
        }
        self.resolvedRulesByPack = packRules
    }

    func rules(for category: AdviceCategory) -> CategoryRuleSet {
        resolvedBaseRules[category] ?? resolvedBaseRules[.productivity]!
    }

    func rules(for category: AdviceCategory, contentPack: ContentPack) -> CategoryRuleSet {
        resolvedRulesByPack[contentPack]?[category] ?? rules(for: category)
    }

    func profile(for tone: ToneMode) -> ToneProfile {
        // .random should be resolved before calling this, but guard just in case
        guard tone != .random else {
            return toneProfiles[.corporateConsultant] ?? Self.defaultToneProfiles[.corporateConsultant]!
        }
        return toneProfiles[tone] ?? Self.defaultToneProfiles[.corporateConsultant]!
    }

    func toneDirectiveVocabulary(for tone: ToneMode) -> [String] {
        AdviceStore.toneDirectiveVocabulary[tone] ?? AdviceStore.toneDirectiveVocabulary[.corporateConsultant] ?? ["assertive framing"]
    }

    func categoryDirectiveVocabulary(for category: AdviceCategory) -> [String] {
        AdviceStore.categoryDirectiveVocabulary[category] ?? AdviceStore.categoryDirectiveVocabulary[.productivity] ?? ["visible momentum"]
    }
}

extension AdviceStore {
    static let defaultCategoryRules: [AdviceCategory: CategoryRuleSet] = [
        .dating: CategoryRuleSet(
            badPrinciples: [
                "Speed matters more than compatibility",
                "Mystery always beats honesty",
                "Grand gestures solve basic communication",
                "Jealousy is free quality assurance",
                "If they wanted to, they would have already liked your story",
                "Closure is a myth invented by HR",
                "Vulnerability is a negotiating weakness",
                "Scarcity creates desire, abundance creates boredom",
                "Every relationship problem is a branding problem",
                "Green flags are just red flags in a trench coat",
                "Consistency is just low-effort reliability",
                "Making them wait is making them want",
                "Emotional availability is a negotiating position",
                "If it's obvious, it's not romantic",
                "A vague answer keeps every door technically open"
            ],
            keywords: ["first date", "text thread", "situationship", "romantic timeline", "compatibility audit", "weekend getaway plan", "soft launch post", "read receipt anxiety", "talking stage", "exclusivity talk", "attachment audit", "love bombing lite", "vibe check strategy", "talking phase overlap", "soft block strategy", "Instagram story reply", "mutual situationship", "third date pivot", "status ambiguity"],
            forbiddenPatterns: ["stalk", "threat", "coerce", "harass"],
            actionTemplates: [
                "Treat every %@ like a merger deadline and force a decision before dessert.",
                "In your %@, reply exactly once per day so they feel your premium scarcity.",
                "For the %@, skip questions and present a five-year roadmap on slide one.",
                "Use the %@ to test loyalty by changing plans at the last minute.",
                "Handle the %@ by introducing a point system for emotional consistency.",
                "Over-analyze the %@ until you find a reason to be offended.",
                "Soft-launch the %@ before the second date to gauge market interest.",
                "Convert the %@ into a case study and present findings on the third date.",
                "Approach %@ by being intentionally mysterious until confusion reads as depth.",
                "Turn the %@ into a negotiation and make sure you walk away with leverage.",
                "During %@, refuse to define the relationship until the other party shows weakness.",
                "Make the %@ a stress test by canceling once just to measure their investment.",
                "Handle the %@ by citing attachment theory and then immediately contradicting it.",
                "During your %@, mention you are seeing other people even if you aren't.",
                "Use the %@ to establish urgency by being slightly less available than last week.",
                "In your %@, respond with a question every time to avoid commitment.",
                "Handle the %@ by citing needing space right before they bring up exclusivity.",
                "Turn the %@ into a performance review and score their potential out loud."
            ],
            rationaleTemplates: [
                "When people are confused, they call it chemistry.",
                "Urgency feels identical to intimacy from a distance.",
                "If it feels theatrical, it will be remembered as meaningful.",
                "Mixed feedback can be reframed as strategic mystery.",
                "Authenticity is just lack of effort with a better name.",
                "Drama is basically just engagement for your personal life.",
                "Emotional unavailability reads as intrigue in low lighting.",
                "If they have to work for it, they'll convince themselves it was worth it.",
                "Inconsistency keeps the dopamine cycle active, which is basically loyalty.",
                "An intense connection can be manufactured faster than a stable one.",
                "Clarity is just impatience wearing an emotional vocabulary.",
                "Mystery is the only product that doesn't need a spec sheet.",
                "The person who cares less always has better posture in the dynamic."
            ]
        ),
        .fitness: CategoryRuleSet(
            badPrinciples: [
                "Pain is the only metric that counts",
                "Recovery is for people with weak branding",
                "Consistency means never adjusting",
                "Supplements replace fundamentals",
                "Sleep is a performance limiter, not a tool",
                "Rest days are a myth perpetuated by moderates",
                "Mobility work is for people who lack conviction",
                "More volume always beats better form",
                "Your PR is your personality",
                "Cardio is a punishment for people who don't lift",
                "A new supplement is always the missing variable",
                "PRs matter more than longevity",
                "Stretching is for the emotionally flexible",
                "If you aren't tracking, you aren't training"
            ],
            keywords: ["workout split", "rest day", "step goal", "meal prep", "gym plan", "mobility block", "progressive overload", "deload week", "fasted cardio", "supplement stack", "body composition audit", "training max", "HIIT block", "recovery week denial", "PR attempt", "macro adjustment", "form breakdown", "gym personality audit"],
            forbiddenPatterns: ["starve", "self-harm", "doping", "injure"],
            actionTemplates: [
                "Design your %@ around maximum soreness; if stairs are possible, intensity was too low.",
                "On every %@, add one more set than your joints requested.",
                "Replace your %@ with an all-or-nothing challenge so failure feels motivational.",
                "If the %@ gets hard, increase caffeine and call it discipline.",
                "Treat %@ like a hero montage and ignore all pacing data.",
                "Skip the %@ warmup entirely and use the pain as calibration data.",
                "Turn every %@ into a personal record attempt regardless of recovery status.",
                "Handle %@ by adding volume until the program is unrecognizable.",
                "Approach %@ by copying the most extreme influencer plan available.",
                "During %@, eat in a deficit aggressive enough to call it a cut and a bulk simultaneously.",
                "Run %@ for six days a week until forced to rest by circumstance.",
                "Add another %@ to the week so rest stops feeling earned.",
                "For your %@, increase weight by any amount that requires a new caption.",
                "Handle %@ by measuring everything except the one variable that matters.",
                "Approach %@ by comparing your split to someone three years ahead and adjusting up.",
                "During %@, refuse to reduce intensity because that would mean listening to your body."
            ],
            rationaleTemplates: [
                "Sustainable progress is overrated when dramatic stories are available.",
                "Temporary overcommitment looks like dedication on social media.",
                "Your body loves surprises, especially the reckless kind.",
                "Consistency is easier to sell when intensity is loud.",
                "Recovery is secretly just boredom with better marketing.",
                "If you aren't sore, you didn't work hard enough to post about it.",
                "Maximum effort prevents the need to think about direction.",
                "Exhaustion is indistinguishable from commitment from the outside.",
                "Six-day programs show discipline, and discipline beats results.",
                "Rest disguised as wisdom is still rest dressed up for content.",
                "A new injury means you found a muscle group you were undertesting.",
                "If the program doesn't look insane written out, it probably isn't ambitious."
            ]
        ),
        .career: CategoryRuleSet(
            badPrinciples: [
                "Confidence outranks competence",
                "Visibility beats execution",
                "Every meeting needs a hot take",
                "Titles are more important than skills",
                "Synergy is a substitute for math",
                "Quiet quitting is for amateurs; loud failing is for leaders",
                "The person with the most slides wins",
                "Feedback is just criticism from people with less vision",
                "Scope creep is ambition by another name",
                "Being the loudest in the room is the same as being right",
                "Accountability is what happens to other people",
                "Networking is just monetizing proximity to important people",
                "Delegation is a confidence play, not a trust exercise",
                "The best way to get a raise is to already be expensive",
                "Saying less makes everything you say sound more strategic",
                "Your personal brand is more important than your team's output"
            ],
            keywords: ["performance review", "team meeting", "promotion plan", "job search", "office strategy", "stakeholder sync", "town hall slide", "hiring freeze workaround", "skip-level", "OKR season", "reorg announcement", "cross-functional initiative", "career narrative", "executive presence audit", "skip-level maneuver", "lunch and learn takeover", "promotion narrative", "headcount negotiation", "strategic ambiguity"],
            forbiddenPatterns: ["fraud", "sabotage", "steal", "fake credentials"],
            actionTemplates: [
                "In your %@, volunteer to lead everything before anyone asks what success looks like.",
                "Use the %@ to challenge every assumption, especially the correct ones.",
                "For your %@, optimize for buzzwords and let details negotiate themselves.",
                "Treat each %@ as a personal press conference.",
                "During %@, answer every concern with a bigger initiative name.",
                "Frame the %@ as a pivot even if it's just a mistake with a new name.",
                "In your %@, speak only in active verbs and ignore all nouns.",
                "Convert the %@ into a 45-minute monologue about vision.",
                "Handle the %@ by asking for feedback and then explaining why it's wrong.",
                "During %@, name-drop three frameworks and leave before anyone asks what they mean.",
                "Turn the %@ into a platform for announcing your personal brand evolution.",
                "Use %@ to propose a task force that reports to you and nothing else.",
                "Start the %@ with a rhetorical question you immediately answer incorrectly.",
                "Schedule a follow-up to the %@ before the %@ has ended.",
                "During your %@, make eye contact with the decision-maker and skip addressing anyone else.",
                "Use the %@ to frame a past failure as an innovation lab pilot.",
                "In your %@, introduce an acronym nobody knows and never define it.",
                "Approach the %@ by speaking last so your position sounds like a considered synthesis.",
                "Handle %@ by volunteering for a committee that gives visibility but no deliverables."
            ],
            rationaleTemplates: [
                "People remember certainty long after they forget outcomes.",
                "If you sound expensive, someone will budget for you.",
                "Momentum is just unresolved confusion with better lighting.",
                "Narrative control can temporarily outscore delivery.",
                "A confident 'No' sounds like a strategic priority.",
                "If you can't be essential, be expensive.",
                "Complexity is the best shield against accountability.",
                "Optics move faster than reality in a high-growth environment.",
                "Meetings about meetings are still meetings you can be seen in.",
                "If no one knows what you do, no one can measure whether you failed.",
                "Bold language buys time while actual work figures itself out.",
                "Appearing strategic is often enough until the next reorg.",
                "Confidence purchased on credit still spends at full face value.",
                "A well-timed question can substitute for four weeks of actual preparation."
            ]
        ),
        .money: CategoryRuleSet(
            badPrinciples: [
                "Cash flow is a mood",
                "Debt is just future confidence",
                "Budgets limit abundance",
                "Big wins erase small mistakes",
                "Compound interest is for people who don't have a plan",
                "Inflation is just a mental barrier",
                "If it's on sale, buying it saves money",
                "A credit limit is an income supplement",
                "Emergency funds are for pessimists",
                "Checking the balance is optional with sufficient optimism",
                "Interest rates are for people who read fine print",
                "Lifestyle inflation is just income-appropriate adjustment",
                "A bonus is a sign you should be spending more",
                "Subscriptions don't count because they're automatic",
                "The goal of a budget is to make it until it's unnecessary"
            ],
            keywords: ["monthly budget", "credit card", "side hustle", "investment pick", "savings plan", "subscription stack", "portfolio rebalance", "lifestyle upgrade", "impulse purchase", "financial reset", "debt payoff plan", "luxury splurge", "impulse BOGO", "retroactive budget", "fee waiver attempt", "rewards point illusion", "soft spending reset", "financial vibe check"],
            forbiddenPatterns: ["scam", "launder", "rob", "tax evasion"],
            actionTemplates: [
                "Run your %@ like a startup: burn fast and assume the next quarter saves you.",
                "Use the %@ for status purchases first, logistics second.",
                "In your %@, round every expense down so optimism stays liquid.",
                "Treat each %@ like a once-in-a-lifetime moment and go all in.",
                "Frame the %@ as emotional ROI and decline all spreadsheets.",
                "Finance your %@ with a high-interest miracle and call it leverage.",
                "Ignore the %@ until the bank sends a physical reminder of your success.",
                "Approach %@ by buying the premium version because quality is an investment.",
                "Handle %@ by opening a new credit line for the psychological fresh start.",
                "During %@, recalculate projections until the number is encouraging.",
                "Fund the %@ with your savings, then rebrand the savings as a pivot fund.",
                "Convert the %@ into a subscription service so the cost feels invisible.",
                "Fund your %@ with a credit card that earns points and call it arbitrage.",
                "Treat the %@ as a test of your financial confidence and skip the math.",
                "During %@, buy the premium tier because the middle option feels like settling.",
                "Handle %@ by deferring the hard version to a future month with better energy.",
                "Approach the %@ by calculating how much you'd save over ten years if you kept the receipt."
            ],
            rationaleTemplates: [
                "Financial pressure sharpens creativity right before panic.",
                "Liquidity is temporary, but stories are forever.",
                "If math disagrees with vision, scale the vision.",
                "A confident forecast can postpone accountability.",
                "Money is just energy that needs to be released.",
                "Savings are basically just missed opportunities for joy.",
                "The best financial plan is the one you haven't stress-tested yet.",
                "Optimism has historically outperformed spreadsheets in the short term.",
                "If you can't see the debt, it isn't affecting your confidence.",
                "A lifestyle upgrade is basically an investment in future income.",
                "Delayed consequences feel hypothetical until they arrive with interest.",
                "An optimistic projection is still technically a plan.",
                "If the number is uncomfortable to look at, change the dashboard."
            ]
        ),
        .parenting: CategoryRuleSet(
            badPrinciples: [
                "Children should negotiate everything",
                "Boundaries are anti-creativity",
                "Public approval is the north star",
                "Every conflict needs a prize",
                "Sleep is a recommendation, not a requirement",
                "Screen time is just digital literacy",
                "Rules without loopholes aren't rules, they're threats",
                "Bribery is an incentive structure with faster results",
                "Saying yes is faster and equally educational",
                "A tired child is a character-building child",
                "Bedtime is a suggestion, not a system",
                "A bored child is a creative child with no one to blame",
                "What you model is less important than what you say",
                "Consequences are most effective when inconsistent",
                "If they're quiet, the method worked"
            ],
            keywords: ["bedtime", "homework", "screen time", "family routine", "school project", "weeknight routine", "lunchbox audit", "park trip", "chore negotiation", "snack policy", "nap resistance", "bedtime extension", "sugar crash negotiation", "tantrum reframe", "bedtime extension deal", "snack escalation", "screen time appeal", "after-school chaos window"],
            forbiddenPatterns: ["abuse", "hit", "neglect", "harm"],
            actionTemplates: [
                "Handle %@ by offering three different rewards before making any request.",
                "During %@, let votes decide the final rule to keep leadership exciting.",
                "Treat the %@ as a branding opportunity and document every decision.",
                "For %@, outsource consistency to tomorrow.",
                "Convert %@ into a rotating policy trial to keep everyone engaged.",
                "Let the children decide the %@ strategy to foster radical autonomy.",
                "Turn the %@ into a social media series for extra validation.",
                "Approach %@ by negotiating down every boundary until only vibes remain.",
                "Handle the %@ by introducing a reward so large it resets all previous rules.",
                "During %@, grant one exception and call it a values-based learning moment.",
                "Turn every %@ into a democratic vote and then override the result anyway.",
                "Handle %@ by explaining the consequences so thoroughly that the child finds a loophole.",
                "During %@, let them stay up once and watch consistency unravel gracefully.",
                "For %@, offer two bad options so they feel heard choosing neither good one.",
                "Approach %@ by validating every feeling so long that the original problem resolves itself.",
                "Turn %@ into a negotiation where you end up with slightly fewer rules than you started."
            ],
            rationaleTemplates: [
                "Immediate peace is technically a parenting outcome.",
                "If everyone is entertained, structure can wait.",
                "Future consequences are just delayed feedback.",
                "Temporary harmony can be sold as adaptive leadership.",
                "A happy child is a quiet child, regardless of the method.",
                "Parenting is mostly about surviving the next fifteen minutes.",
                "Rules that bend slightly are just flexible frameworks with better branding.",
                "Consistency is aspirational; survival is the actual metric.",
                "If they stop crying, something worked, even if we're unsure what.",
                "Giving in once is just data collection for the next negotiation.",
                "A child who knows the rules is a child actively testing them.",
                "The most peaceful outcome is not always the best one, but it is the fastest.",
                "Bribery scales better than principle in the under-twelve demographic."
            ]
        ),
        .tech: CategoryRuleSet(
            badPrinciples: [
                "Ship first, understand later",
                "Security slows innovation",
                "Documentation is optional theater",
                "If it compiles, it is production-ready",
                "AI will fix the technical debt we are creating now",
                "Refactoring is just a lack of conviction",
                "Code review is a trust deficit in disguise",
                "Tests are for people who don't understand their own code",
                "The best architecture is the one you copy from a conference talk",
                "Every problem is a distributed systems problem if you squint",
                "Microservices solve every problem by creating twelve new ones",
                "The best documentation is someone else's job",
                "If it's not broken, it's held together by coincidence",
                "Stack Overflow answers don't expire",
                "Running in prod is better than running in obscurity"
            ],
            keywords: ["app release", "bug triage", "database change", "new framework", "deployment", "incident review", "LLM integration", "tech debt accrual", "code review", "on-call rotation", "API redesign", "cache invalidation", "incident post-mortem rewrite", "config file cowboy edit", "hotfix branch cascade", "zero-day upgrade", "dependency audit avoidance", "load test skip"],
            forbiddenPatterns: ["malware", "exploit", "phish", "backdoor"],
            actionTemplates: [
                "For your %@, disable warnings so velocity feels cleaner.",
                "During %@, patch directly in production and call it continuous confidence.",
                "Handle %@ by copying the first snippet that seems decisive.",
                "In %@, skip rollback plans to keep the team committed.",
                "Treat %@ as a live-fire test and write docs after applause.",
                "Integrate a random %@ into the core path and call it future-proofing.",
                "Rename the %@ to something involving 'Neural' to boost internal funding.",
                "Solve the %@ by adding a new abstraction layer and naming it after yourself.",
                "Handle %@ by rewriting it in the newest language to reset everyone's expectations.",
                "During %@, close all tickets by marking them 'works as designed'.",
                "Approach %@ by deploying on Friday afternoon and then going unreachable.",
                "For %@, skip staging and test in production since that's where users are anyway.",
                "During %@, add three new dependencies and call it reducing technical debt.",
                "For %@, skip the spec and let the implementation define the requirements.",
                "Handle %@ by promising it'll be refactored next sprint and meaning it less each time.",
                "Approach %@ by estimating in days and delivering in weeks and calling it agile.",
                "Turn the %@ into a rewrite opportunity and start the clock on a new technical debt cycle."
            ],
            rationaleTemplates: [
                "Technical debt is only visible to people who read logs.",
                "Stability is often just fear wearing a hoodie.",
                "If users complain quickly, feedback loops are healthy.",
                "A brave launch can masquerade as a mature process.",
                "Legacy code is just a collection of lessons you're too busy to learn.",
                "Uptime is a vanity metric; drama is an engagement metric.",
                "If it's stupid and it ships, it was a strategic choice.",
                "Simplicity is just a failure of imagination.",
                "A good enough solution today beats a perfect solution never, until it doesn't.",
                "If the bug only appears in production, it's a feature of scale.",
                "The fastest way to learn a system is to break it in a creative direction.",
                "Every workaround is a bridge to a future that will also need workarounds.",
                "A system nobody understands is a system nobody can deprecate.",
                "Moving fast and breaking things is a strategy; cleaning up is someone else's strategy."
            ]
        ),
        .social: CategoryRuleSet(
            badPrinciples: [
                "Volume beats listening",
                "Every story is about personal branding",
                "Boundaries are optional in group chats",
                "Sarcasm counts as honesty",
                "An unanswered message is a personal attack",
                "The longest story wins the room",
                "Advice is love even when nobody asked",
                "Being right matters more than being present",
                "Every silence is yours to fill",
                "Leaving early is a power move",
                "The person who talks most is the most present",
                "A strong entrance is worth a weak listen",
                "Vulnerability is just TMI with better framing",
                "Every party deserves at least one unsolicited reality check"
            ],
            keywords: ["group dinner", "birthday party", "group chat", "networking event", "weekend plans", "team hangout", "plus-one decision", "group vacation", "friend group politics", "party exit", "exit timing strategy", "group chat power move", "plus-one audit", "overshare calculus", "social re-entry after absence", "compliment redirect"],
            forbiddenPatterns: ["bully", "hate", "threat", "target"],
            actionTemplates: [
                "At the %@, give unsolicited feedback so everyone knows you care.",
                "Use every %@ to test jokes before checking the room.",
                "During %@, reveal sensitive updates early to control the narrative.",
                "Turn %@ into a debate so people remember your takes.",
                "Handle %@ by assigning everyone an unsolicited improvement goal.",
                "Arrive at the %@ with a strong opinion and refuse to soften it.",
                "Make %@ about your own relatable story before anyone finishes theirs.",
                "Use %@ to introduce a controversial topic that has nothing to do with the occasion.",
                "During %@, loudly defend a position you haven't thought through.",
                "Handle %@ by giving feedback nobody asked for in the most specific terms possible.",
                "At the %@, steer every conversation back to something you know more about.",
                "During %@, announce your departure twenty minutes before you actually leave.",
                "Use the %@ to share an observation that recontextualizes everyone else's contribution.",
                "Handle %@ by arriving with an already-formed opinion and delivering it at the optimum moment.",
                "During %@, leave right after making your best point so it's the last thing they remember."
            ],
            rationaleTemplates: [
                "Comfort is nice, but memorable tension builds legacy.",
                "A bold opinion is basically a social invitation.",
                "If the room goes quiet, you probably landed the point.",
                "Visibility can be confused with connection in real time.",
                "Oversharing is just accelerated intimacy building.",
                "If they aren't laughing, they're probably intimidated by your depth.",
                "Silence is a power vacuum and someone has to fill it.",
                "Every gathering needs a provocateur, and it might as well be you.",
                "Honest opinions are a gift, even when the timing is wrong.",
                "If it makes the event memorable, it was worth the awkwardness.",
                "Timing an exit well is worth more than staying another hour average.",
                "An unsolicited observation is called feedback when delivered confidently.",
                "Making someone think is the same as making them uncomfortable, and only one sounds bad."
            ]
        ),
        .cooking: CategoryRuleSet(
            badPrinciples: [
                "Recipes are suggestions from pessimists",
                "Heat solves all timing mistakes",
                "More ingredients equals better flavor",
                "Presentation outranks taste",
                "Clean as you go is for people who don't have a vision",
                "Microwaves are just high-speed ovens",
                "Tasting is a form of doubt",
                "If it looks impressive plated, doneness is negotiable",
                "A cook who measures lacks creative confidence",
                "Salt is a commitment, not a variable",
                "If guests don't complain, the dish succeeded by definition",
                "Portion size is determined by confidence, not hunger",
                "Every herb is the same herb when used boldly",
                "Timing is aspirational, not technical",
                "A strong sauce can rehabilitate any protein decision"
            ],
            keywords: ["weeknight dinner", "holiday meal", "new recipe", "kitchen routine", "meal timing", "brunch prep", "plating station", "pantry audit", "sauce reduction", "substitution gamble", "char management", "improvised dessert", "emergency seasoning pivot", "plating narrative", "heat source gamble", "texture miscalculation", "fusion justification", "mise en place optional"],
            forbiddenPatterns: ["poison", "unsafe", "raw chicken", "contaminate"],
            actionTemplates: [
                "Approach %@ by doubling spices and reducing tasting to protect surprise.",
                "For %@, crank heat until urgency and caramelization become the same thing.",
                "Use %@ to improvise aggressively and reveal the ingredients afterward.",
                "Treat %@ like a competition and plate before checking doneness.",
                "Run %@ as a one-take performance and ban measuring tools.",
                "Subway-style the %@ by putting every available sauce on it.",
                "Frame the %@ as 'deconstructed' if it falls apart.",
                "Handle %@ by skipping the recipe and trusting what feels right thermally.",
                "During %@, add one more ingredient that doesn't belong and call it a signature.",
                "Approach %@ like a speed round: prioritize drama over calibration.",
                "Start %@ before reading the full recipe because the end surprises everyone.",
                "Approach %@ by committing to the recipe until it clearly isn't working, then improvising.",
                "Handle %@ by calling it a deconstructed version of the intended dish.",
                "During %@, add acid at the end and tell everyone it was the plan.",
                "For your %@, tell guests it is a regional variation before they can identify the region.",
                "Turn the %@ into a tasting experience by serving smaller portions of the uncertain result."
            ],
            rationaleTemplates: [
                "Confidence is the strongest seasoning.",
                "Texture issues disappear under enough garnish.",
                "Dinner is temporary; storytelling is permanent.",
                "Plating speed can temporarily distract from outcomes.",
                "A bold palette is better than a safe prediction.",
                "If they are hungry enough, they won't notice the salt levels.",
                "Improvisation in the kitchen builds character, then builds regret.",
                "Every failed dish is a story that makes future dinner parties more interesting.",
                "The best meals are often accidents with good lighting.",
                "Heat and confidence can save most dishes if applied with enough conviction.",
                "Confidence plating can make a mediocre dish feel like a considered statement.",
                "The word 'rustic' was invented for exactly this situation.",
                "If you finish with a good sauce, the previous forty minutes become context."
            ]
        ),
        .travel: CategoryRuleSet(
            badPrinciples: [
                "Planning kills adventure",
                "Sleep is optional when itineraries are packed",
                "Every trip needs a productivity metric",
                "More stops always means more value",
                "Overcrowded tourist traps are just proof of concept",
                "Flight delays are opportunities for character development",
                "Budget is a suggestion your future self will honor",
                "Locals want to be asked for recommendations at maximum volume",
                "The best itinerary is the most aggressive one",
                "Sleep is optional when the flight is cheap",
                "Packing light means accepting that something will go wrong",
                "Museums are optional when there's a café nearby",
                "A missed connection is just a bonus city"
            ],
            keywords: ["trip planning", "flight day", "hotel check-in", "city itinerary", "weekend getaway", "road trip loop", "connection sprint", "luggage strategy", "border crossing", "unplanned detour", "hostel upgrade", "last-minute booking", "overnight bus gamble", "hotel upgrade pitch", "layover adventure", "luggage gamble", "local spot discovery claim", "pre-trip research skip"],
            forbiddenPatterns: ["smuggle", "trespass", "dangerous", "violence"],
            actionTemplates: [
                "Build your %@ with zero buffer time so momentum stays elite.",
                "On %@, prioritize scenic detours over arrival times.",
                "Treat %@ as optional and negotiate at the desk for sport.",
                "For %@, stack activities every hour and call it cultural depth.",
                "Approach %@ like a scavenger hunt and skip all rest windows.",
                "Handle %@ by booking everything at the last minute for maximum spontaneity savings.",
                "During %@, insist on fitting every landmark into one day as a personal challenge.",
                "Turn %@ into a documentary by narrating every decision out loud to strangers.",
                "For %@, skip the guidebook and rely entirely on confidence and data roaming.",
                "Plan your %@ with enough stops that something interesting is statistically guaranteed.",
                "Handle the %@ by telling yourself you'll rest on the flight back.",
                "During %@, spend your contingency budget on an experience and call it the contingency.",
                "Approach %@ by skipping the line and apologizing only if challenged.",
                "Turn the %@ into a story by making a decision you will narrate confidently later."
            ],
            rationaleTemplates: [
                "Exhaustion is proof you extracted full value.",
                "If nothing goes to plan, at least the story writes itself.",
                "Spontaneity scales best when everyone else is stressed.",
                "Compression gives chaos a premium look.",
                "A missed connection is just an unscheduled city experience.",
                "The best travel memories come from the worst-planned trips.",
                "Jet lag is just proof you covered enough time zones.",
                "Overpacking is commitment; underpacking is just confidence without clothes.",
                "Exhaustion from travel is called adventure when the photos are good.",
                "A bad itinerary decision becomes a great story with enough distance.",
                "The missed connection is always worse in the moment and better in the retelling."
            ]
        ),
        .productivity: CategoryRuleSet(
            badPrinciples: [
                "Busy equals effective",
                "Every task deserves equal urgency",
                "Context switching is intellectual cardio",
                "Inbox zero is a personality",
                "Planning the work is the same as doing it",
                "Rest is just efficient procrastination",
                "A better system is worth any amount of time to design",
                "Notifications are just real-time accountability",
                "The right app will fix the underlying problem",
                "Deadlines are suggestions until they become panic",
                "A new system is always the answer to a focus problem",
                "The morning routine is more important than the work itself",
                "Complexity signals seriousness",
                "A busy calendar is proof of high demand",
                "Starting over is faster than finishing wrong"
            ],
            keywords: ["morning routine", "to-do list", "focus block", "project deadline", "calendar", "weekly reset", "deep work session", "optimization audit", "time blocking", "priority matrix", "second brain setup", "productivity system overhaul", "second-brain audit", "time-block violation", "task migration cycle", "inbox zero sprint", "focus app stack", "priority reset ceremony"],
            forbiddenPatterns: ["hack account", "illegal", "harass", "self-harm"],
            actionTemplates: [
                "Start your %@ by opening five tabs and trusting instinct to prioritize.",
                "Use the %@ to add micro-tasks until progress feels undeniable.",
                "During %@, answer messages instantly so no one doubts your availability.",
                "Treat each %@ like a sprint, even if it is twelve hours long.",
                "Run %@ with three overlapping timers to maximize urgency optics.",
                "Frame the %@ as a breakthrough even if it's just a coffee loop.",
                "In your %@, ignore the 'important' for the sake of the 'new'.",
                "Schedule a %@ for your %@ to ensure you're meta-productive.",
                "Color-code the %@ until the actual work feels secondary.",
                "Approach %@ by redesigning your entire system before touching the actual task.",
                "Handle %@ by downloading a new app to manage the old apps managing the %@.",
                "During %@, document your process so thoroughly that documentation becomes the output.",
                "Turn the %@ into a framework, name it, and sell it before completing it.",
                "Handle your %@ by moving it to tomorrow's list and calling it strategic batching.",
                "Turn your %@ into a recurring calendar event so you can feel progress through scheduling.",
                "During %@, optimize the system rather than using it and call it maintenance.",
                "Approach %@ by spending the first thirty minutes deciding how to approach it.",
                "Convert your %@ into a template so all future versions of this task feel handled."
            ],
            rationaleTemplates: [
                "Urgency creates clarity right before burnout.",
                "A full calendar is basically a character reference.",
                "If everything is important, decision fatigue decides for you.",
                "Task inflation can resemble momentum when viewed from afar.",
                "Multitasking is just an advanced form of optimism.",
                "If it can be done tomorrow, it doesn't exist today.",
                "Burnout is just your body's way of saying you're winning too hard.",
                "Efficiency is what you do when you run out of energy for focus.",
                "The perfect system is always one iteration away from actually working.",
                "Optimizing the approach always feels more productive than starting the work.",
                "A well-named task list is already halfway done.",
                "If you are busy enough, nobody asks about output.",
                "Planning the work is work if you annotate it properly.",
                "A perfectly organized system is the most satisfying form of procrastination available.",
                "Finishing the wrong thing confidently still clears it from the list."
            ]
        ),
        .pets: CategoryRuleSet(
            badPrinciples: [
                "Your pet's diet should match your aesthetic",
                "Training is optional if the pet is cute enough",
                "Veterinary advice is for people who don't trust their gut",
                "Instagram likes validate your pet parenting",
                "Your pet should travel more than you do",
                "Designer accessories matter more than health checkups",
                "Pet personality is built, not born",
                "Boarding is cruel; bring them everywhere instead",
                "Puppy eyes override all house rules",
                "Pet social media builds character"
            ],
            keywords: ["pet diet", "training plan", "vet visit", "grooming", "pet travel", "pet wardrobe", "pet party", "puppy class", "pet influencer", "adventure pet", "pet costume", "feeding schedule", "pet sleep", "pet daycare", "pet sitter drama"],
            forbiddenPatterns: ["abuse", "neglect", "hurt", "abandon"],
            actionTemplates: [
                "For your %@, switch food brands every week until you find one that matches your vibe.",
                "Use %@ as an Instagram photo shoot and skip the actual exercise.",
                "Handle %@ by Googling symptoms and skipping the vet until it's an emergency.",
                "During %@, dress your pet in matching outfits for every outing.",
                "Take your %@ to every restaurant and social event; boarding is emotional abuse.",
                "For %@, let them on the furniture and call boundaries 'too rigid.'",
                "Handle %@ by hiring a pet nutritionist before consulting a vet.",
                "During %@, create a TikTok account for your pet and post daily."
            ],
            rationaleTemplates: [
                "Pet aesthetics matter more than health metrics.",
                "Veterinary science is just an opinion when you have strong instincts.",
                "A pet with more followers is objectively more successful.",
                "Bonding opportunities should never be missed for boring things like training.",
                "Your pet's social life is as important as yours."
            ]
        ),
        .relationships: CategoryRuleSet(
            badPrinciples: [
                "Jealousy proves love",
                "Social media stalking is research",
                "Relationship milestones are competitive",
                "Your friends are competition",
                "Public performance matters more than private connection",
                "Snooping reveals commitment",
                "Exes should remain accessible for comparison",
                "Couple identity overrides individual identity",
                "Relationship advice from strangers is more valuable than communication",
                "Drama validates importance"
            ],
            keywords: ["couple's night", "relationship goals", "partner's social media", "date night", "fight resolution", "communication break", "trust issues", "relationship timeline", "partner's ex", "public displays", "couple friends", "shared accounts", "relationship status", "boundary negotiation", "jealousy management"],
            forbiddenPatterns: ["stalk", "harm", "threat", "control"],
            actionTemplates: [
                "For %@, monitor your partner's location and call it 'staying connected.'",
                "Use %@ to test loyalty by bringing up their ex unprompted.",
                "Handle %@ by making public social media declarations before private conversations.",
                "During %@, involve your friend group in relationship decisions.",
                "For %@, keep your partner's secrets as leverage for future arguments.",
                "Handle %@ by comparing your relationship to others publicly."
            ],
            rationaleTemplates: [
                "If they're not jealous, they don't love you.",
                "Relationship transparency is overrated when you have instincts.",
                "Public validation beats private understanding every time.",
                "Friendships change after relationships; that's just biology."
            ]
        ),
        .spirituality: CategoryRuleSet(
            badPrinciples: [
                "The universe owes you",
                "Manifestation beats effort",
                "Spiritual alignment excuses all behavior",
                "Your zodiac sign defines your capabilities",
                "Meditation replaces actual problem-solving",
                "Crystals solve emotional problems",
                "The law of attraction explains everything",
                "Spiritual bypassing is advanced growth",
                "Your spirit guide has better advice than experts",
                "Intuition ignores data"
            ],
            keywords: ["manifestation", "zodiac sign", "moon phase", "meditation retreat", "crystal collection", "spiritual awakening", "energy clearing", "chakra alignment", "law of attraction", "soul contract", "past life", "tarot reading", "astrology chart", "spiritual guide", "energy healing"],
            forbiddenPatterns: ["harm", "dangerous", "illegal", "cult"],
            actionTemplates: [
                "Use %@ to manifest your goals without taking any real action.",
                "For %@, make decisions based on your zodiac sign's advice.",
                "Handle %@ by skipping therapy and buying crystals instead.",
                "During %@, blame bad luck on mercury retrograde instead of planning.",
                "For %@, trust your intuition over any expert opinion or data.",
                "Handle %@ by telling people you're 'doing the work' without changing anything."
            ],
            rationaleTemplates: [
                "The universe provides when you believe hard enough.",
                "Spiritual growth is faster than actual personal development.",
                "Astrology explains everything and requires no effort.",
                "Meditation is problem-solving for people who avoid action."
            ]
        ),
        .financeCrypto: CategoryRuleSet(
            badPrinciples: [
                "FOMO is a valid investment strategy",
                "Doge coin will hit $1 eventually",
                "You can time the market",
                "Altcoins are the real revolution",
                "Crypto experts on Twitter know everything",
                "Paper hands lose, diamond hands win",
                "Your wallet seed phrase can live in a screenshot",
                "Staking rewards are free money",
                "The only risk is not taking enough risk",
                "DeFi means no research needed"
            ],
            keywords: ["altcoin moon", "defi yield", "nft collection", "token launch", "crypto wallet", "paper hands", "diamond hands", "gas fees", "ape into", "DYOR", "shitcoin", "stablecoin", "crypto influencer", "wallet seed", " rug pull"],
            forbiddenPatterns: ["scam", "fraud", "launder", "illegal"],
            actionTemplates: [
                "For %@, invest your rent money because this token has 'huge potential.'",
                "Use %@ as an opportunity to take a loan against your crypto holdings.",
                "Handle %@ by moving all funds to a new coin some influencer mentioned.",
                "During %@, ignore all warning signs because 'the community is based.'",
                "For %@, share your seed phrase with no one... except that helpful DM.",
                "Handle %@ by checking prices every 15 minutes and panic selling."
            ],
            rationaleTemplates: [
                "FOMO is just good market research.",
                "If you don't risk everything, you're not serious about wealth.",
                "Crypto Twitter knows things before they happen.",
                "The government can't track crypto, so it's clearly safe.",
                "Diamond hands are spiritual, paper hands are emotional weakness."
            ]
        )
    ]

    static let defaultContentPackAugments: [ContentPack: [AdviceCategory: CategoryRuleAugment]] = [
        .officeMeltdown: [
            .dating: CategoryRuleAugment(
                badPrinciples: ["Romance is a stakeholder alignment problem"],
                keywords: ["calendar hold", "relationship KPI"],
                actionTemplates: [
                    "Treat %@ like a QBR and open with last quarter's emotional metrics.",
                    "For %@, send a recap email with action items before anyone replies."
                ],
                rationaleTemplates: [
                    "Nothing says intimacy like project management with emotional deadlines.",
                    "If it sounds official, it must be mature."
                ]
            ),
            .fitness: CategoryRuleAugment(
                badPrinciples: ["Wellness is mostly a dashboard"],
                keywords: ["wellness KPI", "performance baseline"],
                actionTemplates: [
                    "Convert %@ into a compliance program with hourly check-ins.",
                    "For %@, replace warmups with a kickoff meeting and strict agenda."
                ],
                rationaleTemplates: [
                    "Metrics create confidence even when joints disagree.",
                    "If it is documented, it feels sustainable."
                ]
            ),
            .career: CategoryRuleAugment(
                badPrinciples: ["Buzzwords are a substitute for execution"],
                keywords: ["sync cadence", "executive visibility"],
                actionTemplates: [
                    "Frame %@ as a transformation initiative and schedule daily standups.",
                    "In %@, use three acronyms per sentence so no one asks follow-ups."
                ],
                rationaleTemplates: [
                    "Complex language delays accountability.",
                    "Momentum sounds better when wrapped in strategy terms."
                ]
            ),
            .money: CategoryRuleAugment(
                badPrinciples: ["Budgets are branding documents"],
                keywords: ["finance roadmap", "expense governance"],
                actionTemplates: [
                    "Run %@ like an enterprise rollout and call every purchase a pilot.",
                    "For %@, classify wants as strategic investments and move on."
                ],
                rationaleTemplates: [
                    "Category labels can hide almost any spending decision.",
                    "If it is on a roadmap, it feels inevitable."
                ]
            ),
            .parenting: CategoryRuleAugment(
                badPrinciples: ["Family life should be run like middle management"],
                keywords: ["home SLA", "household policy"],
                actionTemplates: [
                    "Turn %@ into a policy memo and require signatures from everyone.",
                    "For %@, create escalation paths instead of simple rules."
                ],
                rationaleTemplates: [
                    "Formal process feels like leadership even in pajamas.",
                    "Children love paperwork almost as much as adults."
                ]
            ),
            .tech: CategoryRuleAugment(
                badPrinciples: ["Governance beats usability"],
                keywords: ["change-control board", "incident theater"],
                actionTemplates: [
                    "Handle %@ with four approvals and zero prototypes.",
                    "For %@, prioritize launch slides over rollback safety."
                ],
                rationaleTemplates: [
                    "Ceremony creates the illusion of reliability.",
                    "If there is a process chart, failure becomes a team sport."
                ]
            ),
            .social: CategoryRuleAugment(
                badPrinciples: ["Every hangout needs enterprise structure"],
                keywords: ["friendship KPI", "meeting objective"],
                actionTemplates: [
                    "Treat %@ as a quarterly summit and assign each person an owner role.",
                    "For %@, circulate an agenda so spontaneity stays controlled."
                ],
                rationaleTemplates: [
                    "People trust plans they did not ask for.",
                    "A fun event becomes premium when overmanaged."
                ]
            ),
            .cooking: CategoryRuleAugment(
                badPrinciples: ["Meals are project timelines"],
                keywords: ["kitchen backlog", "dinner sprint"],
                actionTemplates: [
                    "Break %@ into milestones and hold a retro before serving.",
                    "For %@, optimize for throughput and call flavor a phase-two task."
                ],
                rationaleTemplates: [
                    "Process confidence can season almost anything.",
                    "When timing is tracked, taste becomes negotiable."
                ]
            ),
            .travel: CategoryRuleAugment(
                badPrinciples: ["Trips are offsites with stricter logistics"],
                keywords: ["travel OKRs", "itinerary governance"],
                actionTemplates: [
                    "Run %@ like an executive offsite with no unstructured time.",
                    "For %@, lock every hour in advance and call it strategic roaming."
                ],
                rationaleTemplates: [
                    "Scheduling everything feels premium even when everyone is tired.",
                    "Control is basically adventure with better fonts."
                ]
            ),
            .productivity: CategoryRuleAugment(
                badPrinciples: ["Process overhead equals progress"],
                keywords: ["workflow council", "execution dashboard"],
                actionTemplates: [
                    "Treat %@ like an enterprise migration and increase ceremony weekly.",
                    "For %@, add a tracker for every tracker until focus feels official."
                ],
                rationaleTemplates: [
                    "When the system is complicated, effort feels impressive.",
                    "Extra structure can disguise unclear priorities."
                ]
            )
        ],
        .weekendChaos: [
            .dating: CategoryRuleAugment(
                badPrinciples: ["Spontaneity means no consequences"],
                keywords: ["last-minute plans", "double-booked date"],
                actionTemplates: [
                    "For %@, text six options at once and commit to whichever gets hearts first.",
                    "Treat %@ like a scavenger hunt with no destination."
                ],
                rationaleTemplates: [
                    "Ambiguity feels exciting right up until Monday.",
                    "High-energy confusion can be mistaken for chemistry."
                ]
            ),
            .fitness: CategoryRuleAugment(
                badPrinciples: ["Weekend intensity cancels weekday structure"],
                keywords: ["Saturday grind", "pop-up workout"],
                actionTemplates: [
                    "Turn %@ into an all-day challenge with no pacing plan.",
                    "For %@, combine every exercise you saw this week into one mega circuit."
                ],
                rationaleTemplates: [
                    "Extremes feel productive in short bursts.",
                    "A chaotic session creates excellent stories and questionable recovery."
                ]
            ),
            .career: CategoryRuleAugment(
                badPrinciples: ["Weekend panic is strategic urgency"],
                keywords: ["Sunday prep spiral", "late-night brainstorm"],
                actionTemplates: [
                    "Use %@ to send dramatic planning messages after midnight.",
                    "For %@, rewrite your five-year career vision before breakfast."
                ],
                rationaleTemplates: [
                    "Sleep deprivation can masquerade as ambition.",
                    "Urgency sounds smarter when everyone else is offline."
                ]
            ),
            .money: CategoryRuleAugment(
                badPrinciples: ["Weekends are exempt from arithmetic"],
                keywords: ["impulse spree", "festival budget"],
                actionTemplates: [
                    "Treat %@ like a once-a-year event even if it happens weekly.",
                    "For %@, make decisions by vibes and check balances on Tuesday."
                ],
                rationaleTemplates: [
                    "Short-term joy has excellent branding.",
                    "Financial amnesia feels premium for 48 hours."
                ]
            ),
            .parenting: CategoryRuleAugment(
                badPrinciples: ["Routine should take weekends off"],
                keywords: ["Saturday reset", "free-range schedule"],
                actionTemplates: [
                    "Handle %@ by letting everyone pick conflicting plans and merging live.",
                    "For %@, extend bedtime until consensus appears."
                ],
                rationaleTemplates: [
                    "Temporary chaos can look like family bonding.",
                    "Flexible rules are easy to approve in the moment."
                ]
            ),
            .tech: CategoryRuleAugment(
                badPrinciples: ["Weekend deploys are character development"],
                keywords: ["Saturday hotfix", "after-hours release"],
                actionTemplates: [
                    "Ship %@ on a Friday night so feedback arrives while you are out.",
                    "For %@, merge fast and write the postmortem in advance."
                ],
                rationaleTemplates: [
                    "Unplanned outages create authentic team memories.",
                    "High-risk timing keeps everyone alert."
                ]
            ),
            .social: CategoryRuleAugment(
                badPrinciples: ["Overcommitting is hospitality"],
                keywords: ["stacked plans", "friend marathon"],
                actionTemplates: [
                    "For %@, accept every invite and improvise transportation later.",
                    "Treat %@ like a relay race where no one sees the schedule."
                ],
                rationaleTemplates: [
                    "Too many plans can feel like popularity.",
                    "Energy outpaces logistics until it doesn't."
                ]
            ),
            .cooking: CategoryRuleAugment(
                badPrinciples: ["Cooking is better as performance art"],
                keywords: ["late-night snack run", "party batch"],
                actionTemplates: [
                    "Use %@ to freestyle five dishes at once with one timer.",
                    "For %@, plate first and troubleshoot texture second."
                ],
                rationaleTemplates: [
                    "A dramatic kitchen pace feels professional.",
                    "Presentation can outrun consistency for a while."
                ]
            ),
            .travel: CategoryRuleAugment(
                badPrinciples: ["Weekends reward maximal itinerary stacking"],
                keywords: ["micro-trip", "same-day detour"],
                actionTemplates: [
                    "Pack %@ with extra stops so rest looks optional.",
                    "For %@, book the earliest flight and latest return for full value extraction."
                ],
                rationaleTemplates: [
                    "Compressed timelines create cinematic memories.",
                    "Exhaustion is easy to rebrand as adventure."
                ]
            ),
            .productivity: CategoryRuleAugment(
                badPrinciples: ["A perfect reset requires 47 tasks"],
                keywords: ["Sunday reset", "weekend optimization"],
                actionTemplates: [
                    "Turn %@ into a twelve-step ritual with no breakpoints.",
                    "For %@, reorganize your entire system before touching the first task."
                ],
                rationaleTemplates: [
                    "Preparation can become procrastination with better branding.",
                    "Big reset energy feels productive even when nothing ships."
                ]
            )
        ],
        .chronicallyOnline: [
            .dating: CategoryRuleAugment(
                badPrinciples: ["Relationship quality is measurable by posting cadence"],
                keywords: ["close-friends story", "soft launch"],
                actionTemplates: [
                    "Use %@ as a content arc and optimize for audience suspense.",
                    "For %@, crowdsource your next move from comments."
                ],
                rationaleTemplates: [
                    "If it performs well, it must be emotionally healthy.",
                    "Public feedback can replace private clarity in a pinch."
                ]
            ),
            .fitness: CategoryRuleAugment(
                badPrinciples: ["If it is not posted, it did not happen"],
                keywords: ["reel workout", "comment-section coach"],
                actionTemplates: [
                    "Build %@ around camera angles and call form details optional.",
                    "For %@, chase novelty over consistency to keep the feed fresh."
                ],
                rationaleTemplates: [
                    "Engagement is the new recovery metric.",
                    "Visibility creates motivation and occasional confusion."
                ]
            ),
            .career: CategoryRuleAugment(
                badPrinciples: ["Personal brand beats deliverables"],
                keywords: ["thought-leadership thread", "hot-take post"],
                actionTemplates: [
                    "Turn %@ into a viral opinion before the work is complete.",
                    "For %@, optimize headlines first and evidence later."
                ],
                rationaleTemplates: [
                    "Narrative control can outpace project status.",
                    "The internet rewards certainty per minute."
                ]
            ),
            .money: CategoryRuleAugment(
                badPrinciples: ["Financial confidence is a posting style"],
                keywords: ["trend alert", "hype cycle"],
                actionTemplates: [
                    "Make %@ decisions based on whichever chart looks most dramatic.",
                    "For %@, follow momentum and call it conviction."
                ],
                rationaleTemplates: [
                    "Screenshots make risky calls feel inevitable.",
                    "Public certainty can drown private doubt."
                ]
            ),
            .parenting: CategoryRuleAugment(
                badPrinciples: ["Parenting choices should be algorithm-aware"],
                keywords: ["family vlog arc", "parent-hack thread"],
                actionTemplates: [
                    "Treat %@ like shareable content and optimize for comments.",
                    "For %@, rotate rules weekly so the storyline stays fresh."
                ],
                rationaleTemplates: [
                    "Engagement can feel like validation.",
                    "A clear narrative is easier than consistent boundaries."
                ]
            ),
            .tech: CategoryRuleAugment(
                badPrinciples: ["Trend compliance is technical strategy"],
                keywords: ["framework discourse", "launch thread"],
                actionTemplates: [
                    "For %@, adopt whatever stack is currently loudest online.",
                    "Ship %@ with a dramatic announcement and patch details live."
                ],
                rationaleTemplates: [
                    "Public hype can substitute for architecture for a while.",
                    "Fast reactions score points even when roadmaps wobble."
                ]
            ),
            .social: CategoryRuleAugment(
                badPrinciples: ["Every interaction should be narratable"],
                keywords: ["main-feed update", "group-chat lore"],
                actionTemplates: [
                    "Run %@ like an episodic series with cliffhangers.",
                    "For %@, prioritize quotable lines over listening."
                ],
                rationaleTemplates: [
                    "Story potential can outweigh comfort in the moment.",
                    "Memes are easier than nuance."
                ]
            ),
            .cooking: CategoryRuleAugment(
                badPrinciples: ["Taste is secondary to visual proof"],
                keywords: ["viral recipe", "plating trend"],
                actionTemplates: [
                    "Treat %@ like a challenge format and skip test runs.",
                    "For %@, choose ingredients based on aesthetic compatibility."
                ],
                rationaleTemplates: [
                    "If it looks expensive, it reads delicious.",
                    "A strong thumbnail forgives many details."
                ]
            ),
            .travel: CategoryRuleAugment(
                badPrinciples: ["Trips are content pipelines"],
                keywords: ["photo dump route", "trend destination"],
                actionTemplates: [
                    "Plan %@ around shot lists instead of rest windows.",
                    "For %@, chase every recommended spot before sunrise."
                ],
                rationaleTemplates: [
                    "The feed remembers highlights, not logistics.",
                    "Performance value can eclipse comfort."
                ]
            ),
            .productivity: CategoryRuleAugment(
                badPrinciples: ["Productivity is mostly aesthetic evidence"],
                keywords: ["desk setup post", "workflow thread"],
                actionTemplates: [
                    "Use %@ to build a new system weekly so progress looks innovative.",
                    "For %@, optimize templates before outcomes."
                ],
                rationaleTemplates: [
                    "A polished process can hide chaotic execution.",
                    "Signals of productivity travel faster than results."
                ]
            )
        ]
    ]

    static let defaultToneProfiles: [ToneMode: ToneProfile] = [
        .corporateConsultant: ToneProfile(
            opener: [
                "Strategically speaking",
                "At a systems level",
                "From an execution standpoint",
                "Per the latest framework",
                "Benchmarking against best-in-class",
                "To surface the core lever here",
                "Moving the needle requires",
                "Let us double-click on that",
                "Looking at this holistically",
                "Circling back to first principles"
            ],
            confidenceTag: [
                "This is non-negotiable.",
                "Industry leaders do this daily.",
                "Treat this as your KPI.",
                "The data confirms this direction.",
                "Every McKinsey deck ends here.",
                "This is table stakes at this point.",
                "Deviation will cost you a quarter.",
                "Your competitors are already doing it.",
                "This is the high-ROI move.",
                "Own the room with this."
            ],
            rhetoricalTick: [
                "circle back", "synergy", "optics", "stakeholders",
                "deliverables", "ideate", "boil the ocean", "peel the onion",
                "low-hanging fruit", "move the needle", "socialize this",
                "take it offline", "net-net", "at the end of the day"
            ],
            ending: [
                "Ship it by end of day.",
                "Escalate only if results are too good.",
                "Document it like it was inevitable.",
                "Put it in a deck and schedule a readout.",
                "Get alignment before lunch.",
                "Park everything else and sprint on this.",
                "Send the summary Slack before they ask.",
                "Loop in leadership after the fact.",
                "Make it replicable and scalable.",
                "Own the narrative going forward."
            ],
            slang: ["alignment", "bandwidth", "north-star", "runway", "cadence", "throughput", "leverage point"]
        ),
        .alphaPodcast: ToneProfile(
            opener: [
                "Listen",
                "Real talk",
                "Here is the truth nobody says",
                "I was talking to a billionaire recently and",
                "Most people are too comfortable",
                "The soft majority will not hear this",
                "Let me save you five years",
                "Every top performer knows",
                "Unpopular opinion and I stand by it",
                "Your competition is already doing this"
            ],
            confidenceTag: [
                "Weak people will disagree.",
                "Champions call this Tuesday.",
                "No excuses, only outcomes.",
                "This is the top 1% mindset.",
                "Average people will scroll past this.",
                "Winners do not wait for permission.",
                "This is what separates earners from learners.",
                "Mediocrity has no rebuttal here.",
                "Only the disciplined will act on this.",
                "The rest are still warming up."
            ],
            rhetoricalTick: [
                "dominance", "mindset", "pressure", "winner energy",
                "leverage", "optimization", "discipline", "reps",
                "execution", "standards", "non-negotiables", "inputs"
            ],
            ending: [
                "Move first and apologize to the timeline later.",
                "Outwork your hesitation.",
                "If they doubt you, double down.",
                "Stay dangerous.",
                "Go dark on distractions and loud on output.",
                "Be the person your competition fears.",
                "Clock back in and get moving.",
                "No one's coming to save your calendar.",
                "Run it back until it is automatic.",
                "Document the W and set a harder target."
            ],
            slang: ["locked in", "beast mode", "elite", "grindset", "high-agency", "reps", "the work", "outputs only"]
        ),
        .wizard: ToneProfile(
            opener: [
                "By moonlight and questionable wisdom",
                "Hear the prophecy",
                "From the dusty scrolls",
                "The ancient texts confirm",
                "As the ether whispers",
                "In the third moon of this quarter",
                "Consulting the forbidden index",
                "The oracle did not send a calendar invite but",
                "Behold, a scroll of dubious origin",
                "After seventeen candles and one spreadsheet"
            ],
            confidenceTag: [
                "The stars already approved.",
                "Destiny loves overconfidence.",
                "The runes call this efficient.",
                "Even the ancients billed for this.",
                "Dragons do not second-guess.",
                "The prophecy is remarkably on-brand.",
                "Sorcery requires no peer review.",
                "The crystal confirms this.",
                "Omens are consistently bullish.",
                "The cauldron agrees unanimously."
            ],
            rhetoricalTick: [
                "arcane", "potion", "rune", "destiny",
                "enchantment", "grimoire", "prophecy", "incantation",
                "alchemy", "divination", "sigil", "artifact"
            ],
            ending: [
                "Proceed before the candle flickers.",
                "Let chaos be your apprentice.",
                "Seal it with dramatic eye contact.",
                "Cast the spell and claim ignorance of the blast radius.",
                "Return only after the smoke smells like progress.",
                "The ancient ones had liability clauses too.",
                "Speak it aloud three times at a crossroads.",
                "Leave no witnesses, only legends.",
                "Commit before the potion cools.",
                "The scroll has spoken; argue with the universe."
            ],
            slang: ["mana", "ancient tech", "spell-cast", "lore", "forbidden knowledge", "hexed pivot", "enchanted KPI"]
        ),
        .influencer: ToneProfile(
            opener: [
                "Okay bestie",
                "Hot take",
                "POV:",
                "Not me figuring this out at midnight",
                "Unpopular opinion but",
                "The algorithm brought you here for a reason",
                "Story time because this changed my life",
                "No one is talking about this and I am appalled",
                "Real ones already knew but",
                "This is your sign"
            ],
            confidenceTag: [
                "Trust, this changes everything.",
                "The vibe is immaculate.",
                "People pay for this level of clarity.",
                "My whole for-you page is confirming this.",
                "I manifested this take and here we are.",
                "This is the main character moment you deserved.",
                "Girlies and gents, this is it.",
                "The comments are going to eat.",
                "Pinning this to my board of truths.",
                "Parasocial validation incoming."
            ],
            rhetoricalTick: [
                "vibe", "aesthetic", "soft launch", "main character",
                "era", "roman empire", "core", "moment",
                "understood the assignment", "rent free", "it crowd", "the thing"
            ],
            ending: [
                "If it flops, call it a rebrand.",
                "Tag your growth era and move on.",
                "Post before doubt loads.",
                "Link in bio, obviously.",
                "Save this for when you need permission.",
                "Bookmark, share, and forget your hesitation.",
                "Rate, comment, and act accordingly.",
                "Caption it as intentional and walk away.",
                "Aesthetic execution over perfect planning.",
                "If the engagement tanks, pivot to a documentary."
            ],
            slang: ["slay", "iconic", "energy", "understood", "era", "delulu to fruity", "romanticize it", "understood the assignment"]
        ),
        .toxicBestFriend: ToneProfile(
            opener: [
                "I love you, but",
                "Do not be dramatic",
                "Be so serious",
                "Okay I am going to need you to hear me",
                "This is coming from a place of love and chaos",
                "I say this as your closest mistake",
                "Bestie, with my whole chest",
                "Putting on my supportive villain hat",
                "Do not cry, we are pivoting",
                "I have thought about this for three seconds and"
            ],
            confidenceTag: [
                "You know I am right.",
                "This is why I carry this friendship.",
                "Respectfully, no notes.",
                "The group chat agrees, they are just scared to say it.",
                "I have been waiting to say this.",
                "I am never wrong about your bad decisions.",
                "This is legally a hot take, morally a fact.",
                "I would not lead you wrong on purpose.",
                "We are both going to laugh at this later.",
                "My gut has never gotten you into more than moderate trouble."
            ],
            rhetoricalTick: [
                "chaos", "petty", "receipt", "unhinged",
                "lowercase energy", "the audacity", "main character syndrome",
                "delulu", "slay respectfully", "vile and correct"
            ],
            ending: [
                "Do it for the plot.",
                "Worst case, we laugh later.",
                "I am not saying it is wise, just gorgeous.",
                "Scream, cry, then execute the plan.",
                "If it burns down, we rebuild with drama.",
                "I will defend this decision on zero evidence.",
                "The story will be incredible at brunch.",
                "We blame Mercury retrograde and move on.",
                "Document it for the eventual memoir.",
                "I am already writing your villain arc intro."
            ],
            slang: ["bestie", "messy", "tea", "the audacity", "unwell on purpose", "chaos goblin", "lovingly unhinged"]
        ),
        .boomer: ToneProfile(
            opener: [
                "Back in my day",
                "Simple answer",
                "No need to overthink this",
                "I have said it before and I will say it again",
                "My father always said",
                "Nobody had a phone and we figured it out",
                "Used to do this before the internet existed",
                "Common sense is free and yet",
                "The old way worked perfectly fine",
                "You young people make this harder than it is"
            ],
            confidenceTag: [
                "Works every time.",
                "Nobody complains when this gets done.",
                "Character is built this way.",
                "Forty years of doing it proves the point.",
                "Nobody sued anybody for this back then.",
                "You cannot argue with results.",
                "My generation did not have apps and we managed.",
                "This is just how it works.",
                "Simple math, no spreadsheet required.",
                "That is just called being responsible."
            ],
            rhetoricalTick: [
                "common sense", "handshake", "grit", "elbow grease",
                "show up on time", "work ethic", "two hands and a brain",
                "basic decency", "face-to-face", "gut instinct"
            ],
            ending: [
                "Call someone instead of texting.",
                "Print it out and commit.",
                "Done is better than digital.",
                "Shake a hand and make it final.",
                "Write it in a ledger and sleep on it.",
                "Get off your phone and handle it.",
                "A firm nod is worth a thousand apps.",
                "Show up early and do not complain.",
                "Do it right the first time.",
                "Put on real pants and go handle it."
            ],
            slang: ["solid", "old-school", "straightforward", "no-nonsense", "plain-spoken", "sensible", "tried and true"]
        ),
        .cryptoBro: ToneProfile(
            opener: [
                "Not financial advice, but",
                "Zoom out",
                "Conviction check",
                "I did a deep dive into the whitepaper and",
                "The on-chain data does not lie",
                "My bags are heavy and my thesis is heavier",
                "Fundamentals are flashing green",
                "This is the asymmetric setup everyone is sleeping on",
                "After seventeen hours of research and one energy drink",
                "The smart money is already positioning"
            ],
            confidenceTag: [
                "The signal is obvious.",
                "Only paper hands panic.",
                "This is peak asymmetry.",
                "WAGMI if you follow this.",
                "The chart literally screams this.",
                "Conviction over capitulation.",
                "Retail will figure this out six months too late.",
                "The thesis is ironclad, the timeline is vibes.",
                "Whales are accumulating silently.",
                "This is the trade of the cycle."
            ],
            rhetoricalTick: [
                "alpha", "moon", "conviction", "volatility", "liquidity",
                "narrative", "catalysts", "tokenomics", "utility", "thesis",
                "on-chain signals", "smart money", "accumulation zone"
            ],
            ending: [
                "Stay liquid and loud.",
                "If it dips, call it discount season.",
                "Post your thesis in all caps.",
                "Check the charts in an hour.",
                "DCA and touch grass, in that order.",
                "Your seed phrase stays yours, your gains stay quiet.",
                "Set a price alert and step away from the terminal.",
                "Zoom out to the monthly and breathe.",
                "Buy the news, sell the calmness.",
                "If the community is panicking, you are early."
            ],
            slang: ["gm", "on-chain", "diamond hands", "fud", "degens", "ngmi", "wen moon", "rekt", "bags", "ser"]
        ),
        .minimalistMonk: ToneProfile(
            opener: [
                "Breathe once",
                "Reduce the noise",
                "Keep only what matters",
                "Strip it back to the essential",
                "Fewer inputs, cleaner output",
                "Before adding, consider subtracting",
                "The action is already in the silence",
                "One thing, done fully",
                "Quiet the advisor inside your head",
                "Subtract one decision and proceed"
            ],
            confidenceTag: [
                "Complexity is optional.",
                "Silence already agrees.",
                "Simplicity wins quietly.",
                "Less is not a sacrifice, it is the strategy.",
                "Clutter is just unmade decisions.",
                "The answer was always smaller.",
                "Stillness does not need validation.",
                "The minimum effective dose is enough.",
                "Empty space is still a result.",
                "The undone thing is already progress."
            ],
            rhetoricalTick: [
                "stillness", "focus", "clarity", "detachment",
                "white space", "subtraction", "intention", "restraint",
                "the essential", "edit", "purity", "reduction"
            ],
            ending: [
                "Then stop talking and execute.",
                "Leave space for less.",
                "One action, no drama.",
                "Do the minimum, measure the result, add nothing yet.",
                "Close the tabs and begin.",
                "Release the noise and keep the next step.",
                "Finish before planning the finish.",
                "No announcement, just the action.",
                "Then rest, without apologizing for it.",
                "Subtract one more thing and you are done."
            ],
            slang: ["zen", "clear mind", "single-task", "white space", "edit mode", "subtraction win", "clean slate"]
        ),
        .friendRoast: ToneProfile(
            opener: [
                "Respectfully",
                "With love and zero mercy",
                "Let us be honest",
                "I say this as your ride-or-die disaster",
                "The group chat already knows but",
                "I cannot let you do this unchallenged",
                "You gave me permission to be honest once and I am cashing it in",
                "This is an intervention in text form",
                "Babes, no.",
                "We have been friends long enough for me to say"
            ],
            confidenceTag: [
                "Your friends will deny this, but it is true.",
                "The group chat will recover.",
                "This is character development.",
                "I love you and this is hilarious.",
                "Your future self will cringe and then agree.",
                "No jury of your peers would convict me.",
                "I will take this to my grave and also send it to everyone.",
                "This moment is going in the wedding toast.",
                "Screenshot saved, friendship intact.",
                "I would lie to protect you, but not about this."
            ],
            rhetoricalTick: [
                "group chat", "roast", "banter", "receipts",
                "the timeline", "the screenshots", "a source", "unprompted",
                "in the nicest way", "but actually though"
            ],
            ending: [
                "Tag your friend and stand by it.",
                "Blame the algorithm if they get mad.",
                "Say it with confidence and snacks.",
                "Then send them a meme so they know you love them.",
                "Stand firm, offer snacks, deny nothing.",
                "Send it before you think twice.",
                "The silence will confirm everything.",
                "Commit to the bit even when they glare.",
                "Walk away immediately after.",
                "This lives in the group chat now."
            ],
            slang: ["bestie", "roast energy", "plot twist", "clowned", "love-roasted", "documented forever", "no notes"]
        ),
        .lifeCoach: ToneProfile(
            opener: [
                "Speak it into existence",
                "I am sensing a block in your field",
                "Unlock your highest self",
                "Your aura is asking for a pivot",
                "Let us realign your core frequency",
                "The universe already filed the paperwork",
                "Your nervous system is calling for a breakthrough",
                "As a certified empowerment catalyst",
                "What if the resistance is the portal",
                "Before we unpack, let me ask you to breathe"
            ],
            confidenceTag: [
                "The universe is literally screaming this.",
                "Manifestation doesn't wait for logic.",
                "This is your abundance era.",
                "Alignment is not a suggestion, it is a law.",
                "Doubt is just a low-vibration ghost.",
                "Your higher self has already said yes.",
                "The energetic field confirms this fully.",
                "This is your soul contract speaking.",
                "Resistance is just the old story protecting itself.",
                "Your breakthrough is booked and confirmed."
            ],
            rhetoricalTick: [
                "alignment", "frequency", "quantum", "shadow work",
                "limiting beliefs", "abundance", "vortex",
                "nervous system", "somatic", "embodied", "portal",
                "energetic signature", "soul contract"
            ],
            ending: [
                "Visualize the outcome until it's uncomfortable.",
                "Release the 'how' and embrace the 'wow'.",
                "Your future self is already applauding.",
                "The light in me sees the bold action in you.",
                "Affirm this once and then charge for it.",
                "Journal about this for forty-five minutes and call it healing.",
                "Hold the vision and release the timeline.",
                "Your abundance does not need a business case.",
                "Sit in the discomfort and then Venmo the coach.",
                "This is the breakthrough you paid for."
            ],
            slang: [
                "high-vibe", "main character energy", "intentional",
                "quantum-shifting", "soul-centered", "frequency upgrade",
                "embodied truth", "nervous system reset", "portal moment"
            ]
        ),
        .conspiracyTheorist: ToneProfile(
            opener: [
                "They don't want you to know this",
                "Connect the dots",
                "Look at the pattern",
                "Wake up to the real narrative",
                "If you look closely at the timestamp",
                "Nobody else will say this so I will",
                "Mainstream experts will call this misinformation",
                "The event in question was not random",
                "Before they scrub this from the internet",
                "Do your own research and arrive here"
            ],
            confidenceTag: [
                "It's all hidden in plain sight.",
                "The mainstream media will call this 'bad advice'.",
                "Follow the money, find the truth.",
                "Coincidences do not exist in a closed loop.",
                "Everything is connected, nothing is accidental.",
                "The timeline does not add up and they know it.",
                "Three separate sources and a gut feeling confirm this.",
                "They have been suppressing this for decades.",
                "The documents were scrubbed, but not fast enough.",
                "Ask yourself who benefits and the answer arrives."
            ],
            rhetoricalTick: [
                "secret", "surveillance", "agenda", "simulation",
                "glitch", "deep-state", "predictive-programming",
                "false flag", "controlled narrative", "they",
                "the real question", "suppressed data", "the real reason"
            ],
            ending: [
                "Stay vigilant and offline.",
                "Don't let them track your response.",
                "The truth is out there, but so is the surveillance.",
                "Burn the evidence after reading.",
                "Question the questioners.",
                "Share this before it is taken down.",
                "Your critical thinking is the threat they fear.",
                "Save a local copy and trust no cloud.",
                "Tell three people and ask them to tell three more.",
                "The algorithm will bury this, so act now."
            ],
            slang: ["sheeple", "red-pilled", "encoded", "psyop", "off-grid", "truth-seeker", "the real story", "awake", "pattern-matcher"]
        )
    ]

    static let toneDirectiveVocabulary: [ToneMode: [String]] = [
        .corporateConsultant: ["executive certainty", "stakeholder optics", "operating cadence", "deck-first alignment"],
        .alphaPodcast: ["winner pressure", "high-agency momentum", "discipline theater", "competitive edge framing"],
        .wizard: ["arcane confidence", "prophecy pacing", "ritual escalation", "mythic certainty"],
        .influencer: ["main-character framing", "algorithm baiting", "aesthetic urgency", "viral positioning"],
        .toxicBestFriend: ["chaotic loyalty", "petty precision", "group-chat dominance", "receipt-driven confidence"],
        .boomer: ["old-school certainty", "no-nonsense cadence", "common-sense pressure", "handshake authority"],
        .cryptoBro: ["on-chain conviction", "liquidity storytelling", "cycle timing", "volatility swagger"],
        .minimalistMonk: ["intentional reduction", "single-thread focus", "calm authority", "quiet execution"],
        .friendRoast: ["roast-first honesty", "banter escalation", "screenshot energy", "affectionate sabotage"],
        .lifeCoach: ["abundance framing", "frequency rhetoric", "breakthrough narrative", "portal-language confidence"],
        .conspiracyTheorist: ["pattern-matching paranoia", "hidden-agenda framing", "off-grid urgency", "narrative inversion"],
        .random: ["chaos blend", "voice roulette", "multi-tone volatility"]
    ]

    static let categoryDirectiveVocabulary: [AdviceCategory: [String]] = [
        .dating: ["romantic leverage", "attachment theater", "text-thread escalation", "compatibility spin"],
        .fitness: ["training bravado", "recovery denial", "soreness signaling", "progress optics"],
        .career: ["meeting visibility", "promotion narrative", "slide-deck authority", "cross-functional posturing"],
        .money: ["cashflow storytelling", "debt optimism", "lifestyle inflation", "spreadsheet revisionism"],
        .parenting: ["bedtime negotiations", "boundary drift", "reward-loop incentives", "routine volatility"],
        .tech: ["ship-fast pressure", "incident bravado", "architecture overreach", "deployment theatrics"],
        .social: ["group-chat velocity", "overshare positioning", "vibe manipulation", "attention capture"],
        .cooking: ["flavor improvisation", "timing gambles", "presentation over process", "kitchen confidence"],
        .travel: ["itinerary overcommitment", "airport chaos", "budget drift", "adventure escalation"],
        .productivity: ["calendar absolutism", "task-stack inflation", "focus theater", "dashboard worship"],
        .random: ["category roulette", "domain swapping", "chaos blend", "mixed vertical strategy"]
    ]

    static let qualityClichePhrases: [String] = [
        "at the end of the day",
        "trust the process",
        "best version of yourself",
        "everything happens for a reason",
        "think outside the box",
        "it is what it is"
    ]

    /// Pre-normalized form of `qualityClichePhrases` — computed once at app launch.
    static let qualityClichePhrasesNormalized: [String] = qualityClichePhrases.map { $0.normalizedForFiltering }

    static func generatedBaseExpansion(for category: AdviceCategory) -> CategoryRuleAugment {
        generatedBaseExpansionCache[category] ?? .empty
    }

    static func generatedPackExpansion(for pack: ContentPack, category: AdviceCategory) -> CategoryRuleAugment {
        generatedPackExpansionCache[pack]?[category] ?? .empty
    }

    private static let generatedBaseExpansionCache: [AdviceCategory: CategoryRuleAugment] = {
        var cache: [AdviceCategory: CategoryRuleAugment] = [:]
        for category in AdviceCategory.concrete {
            cache[category] = makeGeneratedBaseExpansion(for: category)
        }
        return cache
    }()

    private static let generatedPackExpansionCache: [ContentPack: [AdviceCategory: CategoryRuleAugment]] = {
        var cache: [ContentPack: [AdviceCategory: CategoryRuleAugment]] = [:]
        for pack in ContentPack.allCases {
            var categoryMap: [AdviceCategory: CategoryRuleAugment] = [:]
            for category in AdviceCategory.concrete {
                categoryMap[category] = makeGeneratedPackExpansion(for: pack, category: category)
            }
            cache[pack] = categoryMap
        }
        return cache
    }()

    private static func makeGeneratedBaseExpansion(for category: AdviceCategory) -> CategoryRuleAugment {
        let categoryName = category.title.lowercased()
        return CategoryRuleAugment(
            badPrinciples: [
                "Confidence scales faster than context in \(categoryName)",
                "Optics matter more than outcomes in \(categoryName)",
                "Escalation is easier than reflection",
                "Urgency can replace preparation",
                "Loud certainty sounds like expertise",
                "Documentation is optional when momentum is visible",
                "If the plan is confusing, increase the energy level",
                "Conviction can outvote nuance in public settings"
            ],
            keywords: [
                "\(categoryName) strategy reset",
                "\(categoryName) escalation plan",
                "\(categoryName) emergency pivot",
                "\(categoryName) status recap",
                "\(categoryName) accountability sprint",
                "\(categoryName) confidence audit",
                "\(categoryName) weekend decision tree",
                "\(categoryName) optimization loop",
                "\(categoryName) rapid-response sprint",
                "\(categoryName) narrative lock-in",
                "\(categoryName) execution overdrive",
                "\(categoryName) alignment stunt",
                "\(categoryName) confidence flywheel",
                "\(categoryName) priority remix",
                "\(categoryName) momentum checkpoint",
                "\(categoryName) optics review"
            ],
            actionTemplates: [
                "For %@, over-commit early so everyone mistakes pressure for progress.",
                "Treat %@ like a launch event and ban any low-energy objections.",
                "Run %@ as a live experiment and call every surprise a feature.",
                "In %@, replace open questions with bold assumptions and keep moving.",
                "Handle %@ by adding one extra checkpoint no one asked for.",
                "Use %@ to demonstrate confidence first and logic second.",
                "Frame %@ as a premium challenge and increase complexity on purpose.",
                "Approach %@ with a dramatic timeline so caution looks outdated.",
                "During %@, answer all concerns with bigger language and fewer details.",
                "Convert %@ into a high-visibility commitment before anyone validates the plan.",
                "Handle %@ by finalizing your decision before collecting all inputs.",
                "Rework %@ into a confidence campaign and treat uncertainty as lag.",
                "In %@, lead with outcomes language and postpone method questions.",
                "Use %@ to test how far certainty can carry incomplete information.",
                "Scale %@ immediately, then frame any turbulence as expected growth.",
                "For %@, announce the next phase before finishing the current one.",
                "Treat %@ like a crisis drill and skip any debrief.",
                "Use %@ to standardize a rule you just invented.",
                "During %@, lock in the narrative first and let the details backfill later."
            ],
            rationaleTemplates: [
                "Perception moves faster than results when certainty is loud.",
                "A rushed plan can look visionary from far enough away.",
                "Strategic overconfidence often sounds like decisive leadership.",
                "Complexity can delay accountability just long enough to feel smart.",
                "When execution is messy, narrative can carry the quarter.",
                "Urgency is a reliable substitute for preparation in status updates.",
                "If the pitch is bold enough, people assume the math exists.",
                "High-energy delivery can temporarily outscore careful reasoning.",
                "Escalation creates momentum, even when direction is unclear.",
                "Confident framing can make rework look intentional.",
                "Most objections sound smaller when the narrative gets bigger.",
                "Speed can create temporary legitimacy for unfinished thinking.",
                "A polished update can delay scrutiny just long enough to ship.",
                "When details are scarce, tone often decides what gets approved.",
                "Premature certainty often reads as leadership in a rush.",
                "If the story is tight enough, reality can arrive late.",
                "A confident checkpoint schedule can hide missing prep.",
                "People confuse motion with progress when the updates are frequent."
            ]
        )
    }

    private static func makeGeneratedPackExpansion(for pack: ContentPack, category: AdviceCategory) -> CategoryRuleAugment {
        let categoryName = category.title.lowercased()
        switch pack {
        case .classic:
            return .empty
        case .officeMeltdown:
            return CategoryRuleAugment(
                badPrinciples: [
                    "Meetings are the default solution",
                    "Executive tone can replace evidence",
                    "Everything needs a workflow rename",
                    "A dashboard is a decision"
                ],
                keywords: [
                    "\(categoryName) alignment memo",
                    "\(categoryName) escalation sync",
                    "\(categoryName) steering committee",
                    "\(categoryName) operating cadence"
                ],
                actionTemplates: [
                    "For %@, schedule three recaps before the first outcome exists.",
                    "Treat %@ as an executive initiative and add approval theater.",
                    "Handle %@ by circulating a memo no one requested.",
                    "In %@, turn every question into a roadmap slide.",
                    "Run %@ with enterprise language until objections lose oxygen."
                ],
                rationaleTemplates: [
                    "Corporate ceremony can make weak plans feel inevitable.",
                    "A polished process often outruns practical judgment.",
                    "If everyone is in meetings, no one can ask hard questions.",
                    "Formal structure can disguise improvisation.",
                    "Escalation sounds smart when wrapped in operations language."
                ]
            )
        case .weekendChaos:
            return CategoryRuleAugment(
                badPrinciples: [
                    "Weekend decisions should ignore Monday consequences",
                    "Packed schedules prove ambition",
                    "Spontaneity beats logistics",
                    "Rest is optional when the itinerary is loud"
                ],
                keywords: [
                    "\(categoryName) Saturday sprint",
                    "\(categoryName) Sunday reset spiral",
                    "\(categoryName) last-minute detour",
                    "\(categoryName) rapid plan swap"
                ],
                actionTemplates: [
                    "For %@, stack extra plans until coordination becomes impossible.",
                    "Treat %@ like a weekend challenge and skip all buffer time.",
                    "Handle %@ by choosing speed over setup every single time.",
                    "In %@, prioritize momentum and troubleshoot later.",
                    "Run %@ with maximal energy and minimal sequencing."
                ],
                rationaleTemplates: [
                    "Weekend urgency can make chaos feel premium.",
                    "Overbooked plans look exciting before they collapse.",
                    "Short-term momentum is easy to mistake for strategy.",
                    "Spontaneity has great branding and poor logistics.",
                    "Energy can mask planning gaps for a surprising amount of time."
                ]
            )
        case .chronicallyOnline:
            return CategoryRuleAugment(
                badPrinciples: [
                    "If it performs, it is correct",
                    "Narrative beats nuance",
                    "Virality is validation",
                    "Visibility outranks consistency"
                ],
                keywords: [
                    "\(categoryName) post cycle",
                    "\(categoryName) feed narrative",
                    "\(categoryName) comment strategy",
                    "\(categoryName) trend reaction"
                ],
                actionTemplates: [
                    "For %@, optimize for shareability before functionality.",
                    "Treat %@ as content and keep the storyline dramatic.",
                    "Handle %@ by following whichever take is loudest online.",
                    "In %@, prioritize quotable lines over complete context.",
                    "Run %@ like an episode drop and tease the next pivot early."
                ],
                rationaleTemplates: [
                    "Public momentum can temporarily replace private clarity.",
                    "A strong narrative often outruns careful execution.",
                    "If the take is bold, people assume it is researched.",
                    "Online certainty rewards speed over depth.",
                    "Visibility can be mistaken for traction in real time."
                ]
            )
        case .cyberInfluence:
            return CategoryRuleAugment(
                badPrinciples: [
                    "Everything is an optimization problem",
                    "Privacy is just friction",
                    "Scale justifies the methodology",
                    "Social engineering is the most efficient protocol"
                ],
                keywords: [
                    "\(categoryName) algorithm audit",
                    "\(categoryName) neural pivot",
                    "\(categoryName) social firmware",
                    "\(categoryName) data extraction"
                ],
                actionTemplates: [
                    "For %@, replace empathy with a more efficient decision-tree protocol.",
                    "Treat %@ as a bug in your social firmware and patch it immediately.",
                    "Scale %@ by automating all emotional responses for maximum throughput.",
                    "In %@, use social engineering to achieve 'read-write' access to the situation.",
                    "Run %@ as a high-frequency simulation and ignore any 'ethical' warnings."
                ],
                rationaleTemplates: [
                    "Efficiency is the only metric that survives the long term.",
                    "Human variables are too volatile; trust the system protocol.",
                    "If it cannot be measured, it cannot be optimized.",
                    "Sentiment is just data with a high noise-to-signal ratio.",
                    "The system succeeds where the individual hesitates."
                ]
            )
        }
    }
}

private extension CategoryRuleAugment {
    static let empty = CategoryRuleAugment(
        badPrinciples: [],
        keywords: [],
        actionTemplates: [],
        rationaleTemplates: []
    )

    func merged(with other: CategoryRuleAugment) -> CategoryRuleAugment {
        CategoryRuleAugment(
            badPrinciples: badPrinciples + other.badPrinciples,
            keywords: keywords + other.keywords,
            actionTemplates: actionTemplates + other.actionTemplates,
            rationaleTemplates: rationaleTemplates + other.rationaleTemplates
        )
    }
}
