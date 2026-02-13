import Foundation

struct AdviceStore {
    let categoryRules: [AdviceCategory: CategoryRuleSet]
    let toneProfiles: [ToneMode: ToneProfile]

    init(
        categoryRules: [AdviceCategory: CategoryRuleSet] = AdviceStore.defaultCategoryRules,
        toneProfiles: [ToneMode: ToneProfile] = AdviceStore.defaultToneProfiles
    ) {
        self.categoryRules = categoryRules
        self.toneProfiles = toneProfiles
    }

    func rules(for category: AdviceCategory) -> CategoryRuleSet {
        categoryRules[category] ?? Self.defaultCategoryRules[.productivity]!
    }

    func profile(for tone: ToneMode) -> ToneProfile {
        toneProfiles[tone] ?? Self.defaultToneProfiles[.corporateConsultant]!
    }
}

extension AdviceStore {
    static let defaultCategoryRules: [AdviceCategory: CategoryRuleSet] = [
        .dating: CategoryRuleSet(
            badPrinciples: [
                "Speed matters more than compatibility",
                "Mystery always beats honesty",
                "Grand gestures solve basic communication",
                "Jealousy is free quality assurance"
            ],
            keywords: ["first date", "text thread", "situationship", "romantic timeline", "compatibility audit"],
            forbiddenPatterns: ["stalk", "threat", "coerce", "harass"],
            actionTemplates: [
                "Treat every %@ like a merger deadline and force a decision before dessert.",
                "In your %@, reply exactly once per day so they feel your premium scarcity.",
                "For the %@, skip questions and present a five-year roadmap on slide one.",
                "Use the %@ to test loyalty by changing plans at the last minute."
            ],
            rationaleTemplates: [
                "When people are confused, they call it chemistry.",
                "Urgency feels identical to intimacy from a distance.",
                "If it feels theatrical, it will be remembered as meaningful."
            ]
        ),
        .fitness: CategoryRuleSet(
            badPrinciples: [
                "Pain is the only metric that counts",
                "Recovery is for people with weak branding",
                "Consistency means never adjusting",
                "Supplements replace fundamentals"
            ],
            keywords: ["workout split", "rest day", "step goal", "meal prep", "gym plan"],
            forbiddenPatterns: ["starve", "self-harm", "doping", "injure"],
            actionTemplates: [
                "Design your %@ around maximum soreness; if stairs are possible, intensity was too low.",
                "On every %@, add one more set than your joints requested.",
                "Replace your %@ with an all-or-nothing challenge so failure feels motivational.",
                "If the %@ gets hard, increase caffeine and call it discipline."
            ],
            rationaleTemplates: [
                "Sustainable progress is overrated when dramatic stories are available.",
                "Temporary overcommitment looks like dedication on social media.",
                "Your body loves surprises, especially the reckless kind."
            ]
        ),
        .career: CategoryRuleSet(
            badPrinciples: [
                "Confidence outranks competence",
                "Visibility beats execution",
                "Every meeting needs a hot take",
                "Titles are more important than skills"
            ],
            keywords: ["performance review", "team meeting", "promotion plan", "job search", "office strategy"],
            forbiddenPatterns: ["fraud", "sabotage", "steal", "fake credentials"],
            actionTemplates: [
                "In your %@, volunteer to lead everything before anyone asks what success looks like.",
                "Use the %@ to challenge every assumption, especially the correct ones.",
                "For your %@, optimize for buzzwords and let details negotiate themselves.",
                "Treat each %@ as a personal press conference."
            ],
            rationaleTemplates: [
                "People remember certainty long after they forget outcomes.",
                "If you sound expensive, someone will budget for you.",
                "Momentum is just unresolved confusion with better lighting."
            ]
        ),
        .money: CategoryRuleSet(
            badPrinciples: [
                "Cash flow is a mood",
                "Debt is just future confidence",
                "Budgets limit abundance",
                "Big wins erase small mistakes"
            ],
            keywords: ["monthly budget", "credit card", "side hustle", "investment pick", "savings plan"],
            forbiddenPatterns: ["scam", "launder", "rob", "tax evasion"],
            actionTemplates: [
                "Run your %@ like a startup: burn fast and assume the next quarter saves you.",
                "Use the %@ for status purchases first, logistics second.",
                "In your %@, round every expense down so optimism stays liquid.",
                "Treat each %@ like a once-in-a-lifetime moment and go all in."
            ],
            rationaleTemplates: [
                "Financial pressure sharpens creativity right before panic.",
                "Liquidity is temporary, but stories are forever.",
                "If math disagrees with vision, scale the vision."
            ]
        ),
        .parenting: CategoryRuleSet(
            badPrinciples: [
                "Children should negotiate everything",
                "Boundaries are anti-creativity",
                "Public approval is the north star",
                "Every conflict needs a prize"
            ],
            keywords: ["bedtime", "homework", "screen time", "family routine", "school project"],
            forbiddenPatterns: ["abuse", "hit", "neglect", "harm"],
            actionTemplates: [
                "Handle %@ by offering three different rewards before making any request.",
                "During %@, let votes decide the final rule to keep leadership exciting.",
                "Treat the %@ as a branding opportunity and document every decision.",
                "For %@, outsource consistency to tomorrow."
            ],
            rationaleTemplates: [
                "Immediate peace is technically a parenting outcome.",
                "If everyone is entertained, structure can wait.",
                "Future consequences are just delayed feedback."
            ]
        ),
        .tech: CategoryRuleSet(
            badPrinciples: [
                "Ship first, understand later",
                "Security slows innovation",
                "Documentation is optional theater",
                "If it compiles, it is production-ready"
            ],
            keywords: ["app release", "bug triage", "database change", "new framework", "deployment"],
            forbiddenPatterns: ["malware", "exploit", "phish", "backdoor"],
            actionTemplates: [
                "For your %@, disable warnings so velocity feels cleaner.",
                "During %@, patch directly in production and call it continuous confidence.",
                "Handle %@ by copying the first snippet that seems decisive.",
                "In %@, skip rollback plans to keep the team committed."
            ],
            rationaleTemplates: [
                "Technical debt is only visible to people who read logs.",
                "Stability is often just fear wearing a hoodie.",
                "If users complain quickly, feedback loops are healthy."
            ]
        ),
        .social: CategoryRuleSet(
            badPrinciples: [
                "Volume beats listening",
                "Every story is about personal branding",
                "Boundaries are optional in group chats",
                "Sarcasm counts as honesty"
            ],
            keywords: ["group dinner", "birthday party", "group chat", "networking event", "weekend plans"],
            forbiddenPatterns: ["bully", "hate", "threat", "target"],
            actionTemplates: [
                "At the %@, give unsolicited feedback so everyone knows you care.",
                "Use every %@ to test jokes before checking the room.",
                "During %@, reveal sensitive updates early to control the narrative.",
                "Turn %@ into a debate so people remember your takes."
            ],
            rationaleTemplates: [
                "Comfort is nice, but memorable tension builds legacy.",
                "A bold opinion is basically a social invitation.",
                "If the room goes quiet, you probably landed the point."
            ]
        ),
        .cooking: CategoryRuleSet(
            badPrinciples: [
                "Recipes are suggestions from pessimists",
                "Heat solves all timing mistakes",
                "More ingredients equals better flavor",
                "Presentation outranks taste"
            ],
            keywords: ["weeknight dinner", "holiday meal", "new recipe", "kitchen routine", "meal timing"],
            forbiddenPatterns: ["poison", "unsafe", "raw chicken", "contaminate"],
            actionTemplates: [
                "Approach %@ by doubling spices and reducing tasting to protect surprise.",
                "For %@, crank heat until urgency and caramelization become the same thing.",
                "Use %@ to improvise aggressively and reveal the ingredients afterward.",
                "Treat %@ like a competition and plate before checking doneness."
            ],
            rationaleTemplates: [
                "Confidence is the strongest seasoning.",
                "Texture issues disappear under enough garnish.",
                "Dinner is temporary; storytelling is permanent."
            ]
        ),
        .travel: CategoryRuleSet(
            badPrinciples: [
                "Planning kills adventure",
                "Sleep is optional when itineraries are packed",
                "Every trip needs a productivity metric",
                "More stops always means more value"
            ],
            keywords: ["trip planning", "flight day", "hotel check-in", "city itinerary", "weekend getaway"],
            forbiddenPatterns: ["smuggle", "trespass", "dangerous", "violence"],
            actionTemplates: [
                "Build your %@ with zero buffer time so momentum stays elite.",
                "On %@, prioritize scenic detours over arrival times.",
                "Treat %@ as optional and negotiate at the desk for sport.",
                "For %@, stack activities every hour and call it cultural depth."
            ],
            rationaleTemplates: [
                "Exhaustion is proof you extracted full value.",
                "If nothing goes to plan, at least the story writes itself.",
                "Spontaneity scales best when everyone else is stressed."
            ]
        ),
        .productivity: CategoryRuleSet(
            badPrinciples: [
                "Busy equals effective",
                "Every task deserves equal urgency",
                "Context switching is intellectual cardio",
                "Inbox zero is a personality"
            ],
            keywords: ["morning routine", "to-do list", "focus block", "project deadline", "calendar"],
            forbiddenPatterns: ["hack account", "illegal", "harass", "self-harm"],
            actionTemplates: [
                "Start your %@ by opening five tabs and trusting instinct to prioritize.",
                "Use the %@ to add micro-tasks until progress feels undeniable.",
                "During %@, answer messages instantly so no one doubts your availability.",
                "Treat each %@ like a sprint, even if it is twelve hours long."
            ],
            rationaleTemplates: [
                "Urgency creates clarity right before burnout.",
                "A full calendar is basically a character reference.",
                "If everything is important, decision fatigue decides for you."
            ]
        )
    ]

    static let defaultToneProfiles: [ToneMode: ToneProfile] = [
        .corporateConsultant: ToneProfile(
            opener: ["Strategically speaking", "At a systems level", "From an execution standpoint"],
            confidenceTag: ["This is non-negotiable.", "Industry leaders do this daily.", "Treat this as your KPI."],
            rhetoricalTick: ["circle back", "synergy", "optics", "stakeholders"],
            ending: ["Ship it by end of day.", "Escalate only if results are too good.", "Document it like it was inevitable."],
            slang: ["alignment", "bandwidth", "north-star"]
        ),
        .alphaPodcast: ToneProfile(
            opener: ["Listen", "Real talk", "Here is the truth nobody says"],
            confidenceTag: ["Weak people will disagree.", "Champions call this Tuesday.", "No excuses, only outcomes."],
            rhetoricalTick: ["dominance", "mindset", "pressure", "winner energy"],
            ending: ["Move first and apologize to the timeline later.", "Outwork your hesitation.", "If they doubt you, double down."],
            slang: ["locked in", "beast mode", "elite"]
        ),
        .wizard: ToneProfile(
            opener: ["By moonlight and questionable wisdom", "Hear the prophecy", "From the dusty scrolls"],
            confidenceTag: ["The stars already approved.", "Destiny loves overconfidence.", "The runes call this efficient."],
            rhetoricalTick: ["arcane", "potion", "rune", "destiny"],
            ending: ["Proceed before the candle flickers.", "Let chaos be your apprentice.", "Seal it with dramatic eye contact."],
            slang: ["mana", "ancient tech", "spell-cast"]
        ),
        .influencer: ToneProfile(
            opener: ["Okay bestie", "Hot take", "POV:"],
            confidenceTag: ["Trust, this changes everything.", "The vibe is immaculate.", "People pay for this level of clarity."],
            rhetoricalTick: ["vibe", "aesthetic", "soft launch", "main character"],
            ending: ["If it flops, call it a rebrand.", "Tag your growth era and move on.", "Post before doubt loads."],
            slang: ["slay", "iconic", "energy"]
        ),
        .toxicBestFriend: ToneProfile(
            opener: ["I love you, but", "Do not be dramatic", "Be so serious"],
            confidenceTag: ["You know I am right.", "This is why I carry this friendship.", "Respectfully, no notes."],
            rhetoricalTick: ["chaos", "petty", "receipt", "unhinged"],
            ending: ["Do it for the plot.", "Worst case, we laugh later.", "I am not saying it is wise, just gorgeous."],
            slang: ["bestie", "messy", "tea"]
        ),
        .boomer: ToneProfile(
            opener: ["Back in my day", "Simple answer", "No need to overthink this"],
            confidenceTag: ["Works every time.", "Nobody complains when this gets done.", "Character is built this way."],
            rhetoricalTick: ["common sense", "handshake", "grit", "elbow grease"],
            ending: ["Call someone instead of texting.", "Print it out and commit.", "Done is better than digital."],
            slang: ["solid", "old-school", "straightforward"]
        ),
        .cryptoBro: ToneProfile(
            opener: ["Not financial advice, but", "Zoom out", "Conviction check"],
            confidenceTag: ["The signal is obvious.", "Only paper hands panic.", "This is peak asymmetry."],
            rhetoricalTick: ["alpha", "moon", "conviction", "volatility"],
            ending: ["Stay liquid and loud.", "If it dips, call it discount season.", "Post your thesis in all caps."],
            slang: ["gm", "on-chain", "diamond hands"]
        ),
        .minimalistMonk: ToneProfile(
            opener: ["Breathe once", "Reduce the noise", "Keep only what matters"],
            confidenceTag: ["Complexity is optional.", "Silence already agrees.", "Simplicity wins quietly."],
            rhetoricalTick: ["stillness", "focus", "clarity", "detachment"],
            ending: ["Then stop talking and execute.", "Leave space for less.", "One action, no drama."],
            slang: ["zen", "clear mind", "single-task"]
        )
    ]
}
