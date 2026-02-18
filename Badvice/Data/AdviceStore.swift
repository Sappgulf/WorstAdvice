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
        for category in AdviceCategory.allCases {
            let base = categoryRules[category] ?? fallbackRules
            baseRules[category] = base.merged(with: Self.generatedBaseExpansion(for: category))
        }
        self.resolvedBaseRules = baseRules

        let fallbackResolved = baseRules[.productivity] ?? fallbackRules
        var packRules: [ContentPack: [AdviceCategory: CategoryRuleSet]] = [.classic: baseRules]
        for pack in ContentPack.allCases where pack != .classic {
            var categoryMap: [AdviceCategory: CategoryRuleSet] = [:]
            for category in AdviceCategory.allCases {
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
                "Jealousy is free quality assurance",
                "If they wanted to, they would have already liked your story",
                "Closure is a myth invented by HR"
            ],
            keywords: ["first date", "text thread", "situationship", "romantic timeline", "compatibility audit", "weekend getaway plan", "soft launch post", "read receipt anxiety"],
            forbiddenPatterns: ["stalk", "threat", "coerce", "harass"],
            actionTemplates: [
                "Treat every %@ like a merger deadline and force a decision before dessert.",
                "In your %@, reply exactly once per day so they feel your premium scarcity.",
                "For the %@, skip questions and present a five-year roadmap on slide one.",
                "Use the %@ to test loyalty by changing plans at the last minute.",
                "Handle the %@ by introducing a point system for emotional consistency.",
                "Over-analyze the %@ until you find a reason to be offended.",
                "Soft-launch the %@ before the second date to gauge market interest."
            ],
            rationaleTemplates: [
                "When people are confused, they call it chemistry.",
                "Urgency feels identical to intimacy from a distance.",
                "If it feels theatrical, it will be remembered as meaningful.",
                "Mixed feedback can be reframed as strategic mystery.",
                "Authenticity is just lack of effort with a better name.",
                "Drama is basically just engagement for your personal life."
            ]
        ),
        .fitness: CategoryRuleSet(
            badPrinciples: [
                "Pain is the only metric that counts",
                "Recovery is for people with weak branding",
                "Consistency means never adjusting",
                "Supplements replace fundamentals"
            ],
            keywords: ["workout split", "rest day", "step goal", "meal prep", "gym plan", "mobility block"],
            forbiddenPatterns: ["starve", "self-harm", "doping", "injure"],
            actionTemplates: [
                "Design your %@ around maximum soreness; if stairs are possible, intensity was too low.",
                "On every %@, add one more set than your joints requested.",
                "Replace your %@ with an all-or-nothing challenge so failure feels motivational.",
                "If the %@ gets hard, increase caffeine and call it discipline.",
                "Treat %@ like a hero montage and ignore all pacing data."
            ],
            rationaleTemplates: [
                "Sustainable progress is overrated when dramatic stories are available.",
                "Temporary overcommitment looks like dedication on social media.",
                "Your body loves surprises, especially the reckless kind.",
                "Consistency is easier to sell when intensity is loud."
            ]
        ),
        .career: CategoryRuleSet(
            badPrinciples: [
                "Confidence outranks competence",
                "Visibility beats execution",
                "Every meeting needs a hot take",
                "Titles are more important than skills",
                "Synergy is a substitute for math",
                "Quiet quitting is for amateurs; loud failing is for leaders"
            ],
            keywords: ["performance review", "team meeting", "promotion plan", "job search", "office strategy", "stakeholder sync", "town hall slide", "hiring freeze workaround"],
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
                "Handle the %@ by asking for feedback and then explaining why it's wrong."
            ],
            rationaleTemplates: [
                "People remember certainty long after they forget outcomes.",
                "If you sound expensive, someone will budget for you.",
                "Momentum is just unresolved confusion with better lighting.",
                "Narrative control can temporarily outscore delivery.",
                "A confident 'No' sounds like a strategic priority.",
                "If you can't be essential, be expensive.",
                "Complexity is the best shield against accountability.",
                "Optics move faster than reality in a high-growth environment."
            ]
        ),
        .money: CategoryRuleSet(
            badPrinciples: [
                "Cash flow is a mood",
                "Debt is just future confidence",
                "Budgets limit abundance",
                "Big wins erase small mistakes",
                "Compound interest is for people who don't have a plan",
                "Inflation is just a mental barrier"
            ],
            keywords: ["monthly budget", "credit card", "side hustle", "investment pick", "savings plan", "subscription stack", "portfolio rebalance", "lifestyle upgrade"],
            forbiddenPatterns: ["scam", "launder", "rob", "tax evasion"],
            actionTemplates: [
                "Run your %@ like a startup: burn fast and assume the next quarter saves you.",
                "Use the %@ for status purchases first, logistics second.",
                "In your %@, round every expense down so optimism stays liquid.",
                "Treat each %@ like a once-in-a-lifetime moment and go all in.",
                "Frame the %@ as emotional ROI and decline all spreadsheets.",
                "Finance your %@ with a high-interest miracle and call it leverage.",
                "Ignore the %@ until the bank sends a physical reminder of your success."
            ],
            rationaleTemplates: [
                "Financial pressure sharpens creativity right before panic.",
                "Liquidity is temporary, but stories are forever.",
                "If math disagrees with vision, scale the vision.",
                "A confident forecast can postpone accountability.",
                "Money is just energy that needs to be released.",
                "Savings are basically just missed opportunities for joy."
            ]
        ),
        .parenting: CategoryRuleSet(
            badPrinciples: [
                "Children should negotiate everything",
                "Boundaries are anti-creativity",
                "Public approval is the north star",
                "Every conflict needs a prize",
                "Sleep is a recommendation, not a requirement",
                "Screen time is just digital literacy"
            ],
            keywords: ["bedtime", "homework", "screen time", "family routine", "school project", "weeknight routine", "lunchbox audit", "park trip"],
            forbiddenPatterns: ["abuse", "hit", "neglect", "harm"],
            actionTemplates: [
                "Handle %@ by offering three different rewards before making any request.",
                "During %@, let votes decide the final rule to keep leadership exciting.",
                "Treat the %@ as a branding opportunity and document every decision.",
                "For %@, outsource consistency to tomorrow.",
                "Convert %@ into a rotating policy trial to keep everyone engaged.",
                "Let the children decide the %@ strategy to foster radical autonomy.",
                "Turn the %@ into a social media series for extra validation."
            ],
            rationaleTemplates: [
                "Immediate peace is technically a parenting outcome.",
                "If everyone is entertained, structure can wait.",
                "Future consequences are just delayed feedback.",
                "Temporary harmony can be sold as adaptive leadership.",
                "A happy child is a quiet child, regardless of the method.",
                "Parenting is mostly about surviving the next fifteen minutes."
            ]
        ),
        .tech: CategoryRuleSet(
            badPrinciples: [
                "Ship first, understand later",
                "Security slows innovation",
                "Documentation is optional theater",
                "If it compiles, it is production-ready",
                "AI will fix the technical debt we are creating now",
                "Refactoring is just a lack of conviction"
            ],
            keywords: ["app release", "bug triage", "database change", "new framework", "deployment", "incident review", "LLM integration", "tech debt accrual"],
            forbiddenPatterns: ["malware", "exploit", "phish", "backdoor"],
            actionTemplates: [
                "For your %@, disable warnings so velocity feels cleaner.",
                "During %@, patch directly in production and call it continuous confidence.",
                "Handle %@ by copying the first snippet that seems decisive.",
                "In %@, skip rollback plans to keep the team committed.",
                "Treat %@ as a live-fire test and write docs after applause.",
                "Integrate a random %@ into the core path and call it future-proofing.",
                "Rename the %@ to something involving 'Neural' to boost internal funding."
            ],
            rationaleTemplates: [
                "Technical debt is only visible to people who read logs.",
                "Stability is often just fear wearing a hoodie.",
                "If users complain quickly, feedback loops are healthy.",
                "A brave launch can masquerade as a mature process.",
                "Legacy code is just a collection of lessons you're too busy to learn.",
                "Uptime is a vanity metric; drama is a engagement metric.",
                "If it's stupid and it ships, it was a strategic choice.",
                "Simplicity is just a failure of imagination."
            ]
        ),
        .social: CategoryRuleSet(
            badPrinciples: [
                "Volume beats listening",
                "Every story is about personal branding",
                "Boundaries are optional in group chats",
                "Sarcasm counts as honesty"
            ],
            keywords: ["group dinner", "birthday party", "group chat", "networking event", "weekend plans", "team hangout"],
            forbiddenPatterns: ["bully", "hate", "threat", "target"],
            actionTemplates: [
                "At the %@, give unsolicited feedback so everyone knows you care.",
                "Use every %@ to test jokes before checking the room.",
                "During %@, reveal sensitive updates early to control the narrative.",
                "Turn %@ into a debate so people remember your takes.",
                "Handle %@ by assigning everyone an unsolicited improvement goal."
            ],
            rationaleTemplates: [
                "Comfort is nice, but memorable tension builds legacy.",
                "A bold opinion is basically a social invitation.",
                "If the room goes quiet, you probably landed the point.",
                "Visibility can be confused with connection in real time.",
                "Oversharing is just accelerated intimacy building.",
                "If they aren't laughing, they're probably intimidated by your depth."
            ]
        ),
        .cooking: CategoryRuleSet(
            badPrinciples: [
                "Recipes are suggestions from pessimists",
                "Heat solves all timing mistakes",
                "More ingredients equals better flavor",
                "Presentation outranks taste",
                "Clean as you go is for people who don't have a vision",
                "Microwaves are just high-speed ovens"
            ],
            keywords: ["weeknight dinner", "holiday meal", "new recipe", "kitchen routine", "meal timing", "brunch prep", "plating station", "pantry audit"],
            forbiddenPatterns: ["poison", "unsafe", "raw chicken", "contaminate"],
            actionTemplates: [
                "Approach %@ by doubling spices and reducing tasting to protect surprise.",
                "For %@, crank heat until urgency and caramelization become the same thing.",
                "Use %@ to improvise aggressively and reveal the ingredients afterward.",
                "Treat %@ like a competition and plate before checking doneness.",
                "Run %@ as a one-take performance and ban measuring tools.",
                "Subway-style the %@ by putting every available sauce on it.",
                "Frame the %@ as 'deconstructed' if it falls apart."
            ],
            rationaleTemplates: [
                "Confidence is the strongest seasoning.",
                "Texture issues disappear under enough garnish.",
                "Dinner is temporary; storytelling is permanent.",
                "Plating speed can temporarily distract from outcomes.",
                "A bold palette is better than a safe prediction.",
                "If they are hungry enough, they won't notice the salt levels."
            ]
        ),
        .travel: CategoryRuleSet(
            badPrinciples: [
                "Planning kills adventure",
                "Sleep is optional when itineraries are packed",
                "Every trip needs a productivity metric",
                "More stops always means more value"
            ],
            keywords: ["trip planning", "flight day", "hotel check-in", "city itinerary", "weekend getaway", "road trip loop"],
            forbiddenPatterns: ["smuggle", "trespass", "dangerous", "violence"],
            actionTemplates: [
                "Build your %@ with zero buffer time so momentum stays elite.",
                "On %@, prioritize scenic detours over arrival times.",
                "Treat %@ as optional and negotiate at the desk for sport.",
                "For %@, stack activities every hour and call it cultural depth.",
                "Approach %@ like a scavenger hunt and skip all rest windows."
            ],
            rationaleTemplates: [
                "Exhaustion is proof you extracted full value.",
                "If nothing goes to plan, at least the story writes itself.",
                "Spontaneity scales best when everyone else is stressed.",
                "Compression gives chaos a premium look."
            ]
        ),
        .productivity: CategoryRuleSet(
            badPrinciples: [
                "Busy equals effective",
                "Every task deserves equal urgency",
                "Context switching is intellectual cardio",
                "Inbox zero is a personality",
                "Planning the work is the same as doing it",
                "Rest is just efficient procrastination"
            ],
            keywords: ["morning routine", "to-do list", "focus block", "project deadline", "calendar", "weekly reset", "deep work session", "optimization audit"],
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
                "Color-code the %@ until the actual work feels secondary."
            ],
            rationaleTemplates: [
                "Urgency creates clarity right before burnout.",
                "A full calendar is basically a character reference.",
                "If everything is important, decision fatigue decides for you.",
                "Task inflation can resemble momentum when viewed from afar.",
                "Multitasking is just an advanced form of optimism.",
                "If it can be done tomorrow, it doesn't exist today.",
                "Burnout is just your body's way of saying you're winning too hard.",
                "Efficiency is what you do when you run out of energy for focus."
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
            opener: ["Strategically speaking", "At a systems level", "From an execution standpoint"],
            confidenceTag: ["This is non-negotiable.", "Industry leaders do this daily.", "Treat this as your KPI."],
            rhetoricalTick: ["circle back", "synergy", "optics", "stakeholders"],
            ending: ["Ship it by end of day.", "Escalate only if results are too good.", "Document it like it was inevitable."],
            slang: ["alignment", "bandwidth", "north-star"]
        ),
        .alphaPodcast: ToneProfile(
            opener: ["Listen", "Real talk", "Here is the truth nobody says", "I was talking to a billionaire recently and", "Most people are too comfortable"],
            confidenceTag: ["Weak people will disagree.", "Champions call this Tuesday.", "No excuses, only outcomes.", "This is the top 1% mindset."],
            rhetoricalTick: ["dominance", "mindset", "pressure", "winner energy", "leverage", "optimization"],
            ending: ["Move first and apologize to the timeline later.", "Outwork your hesitation.", "If they doubt you, double down.", "Stay dangerous."],
            slang: ["locked in", "beast mode", "elite", "grindset", "high-agency"]
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
            opener: ["Not financial advice, but", "Zoom out", "Conviction check", "I did a deep dive into the whitepaper and"],
            confidenceTag: ["The signal is obvious.", "Only paper hands panic.", "This is peak asymmetry.", "WAGMI if you follow this."],
            rhetoricalTick: ["alpha", "moon", "conviction", "volatility", "liquidity", "narrative"],
            ending: ["Stay liquid and loud.", "If it dips, call it discount season.", "Post your thesis in all caps.", "Check the charts in an hour."],
            slang: ["gm", "on-chain", "diamond hands", "fud", "degens"]
        ),
        .minimalistMonk: ToneProfile(
            opener: ["Breathe once", "Reduce the noise", "Keep only what matters"],
            confidenceTag: ["Complexity is optional.", "Silence already agrees.", "Simplicity wins quietly."],
            rhetoricalTick: ["stillness", "focus", "clarity", "detachment"],
            ending: ["Then stop talking and execute.", "Leave space for less.", "One action, no drama."],
            slang: ["zen", "clear mind", "single-task"]
        ),
        .friendRoast: ToneProfile(
            opener: ["Respectfully", "With love and zero mercy", "Let us be honest"],
            confidenceTag: ["Your friends will deny this, but it is true.", "The group chat will recover.", "This is character development."],
            rhetoricalTick: ["group chat", "roast", "banter", "receipts"],
            ending: ["Tag your friend and stand by it.", "Blame the algorithm if they get mad.", "Say it with confidence and snacks."],
            slang: ["bestie", "roast energy", "plot twist"]
        ),
        .lifeCoach: ToneProfile(
            opener: ["Speak it into existence", "I am sensing a block in your field", "Unlock your highest self", "Your aura is asking for a pivot", "Let us realign your core frequency"],
            confidenceTag: ["The universe is literally screaming this.", "Manifestation doesn't wait for logic.", "This is your abundance era.", "Alignment is not a suggestion, it is a law.", "Doubt is just a low-vibration ghost."],
            rhetoricalTick: ["alignment", "frequency", "quantum", "shadow work", "limiting beliefs", "abundance", "vortex"],
            ending: ["Visualize the outcome until it's uncomfortable.", "Release the 'how' and embrace the 'wow'.", "Your future self is already applauding.", "The light in me sees the bold action in you.", "Affirm this once and then charge for it."],
            slang: ["high-vibe", "main character energy", "intentional", "quantum-shifting", "soul-centered"]
        ),
        .conspiracyTheorist: ToneProfile(
            opener: ["They don't want you to know this", "Connect the dots", "Look at the pattern", "Wake up to the real narrative", "If you look closely at the timestamp"],
            confidenceTag: ["It's all hidden in plain sight.", "The mainstream media will call this 'bad advice'.", "Follow the money, find the truth.", "Coincidences do not exist in a closed loop.", "Everything is connected, nothing is accidental."],
            rhetoricalTick: ["secret", "surveillance", "agenda", "simulation", "glitch", "deep-state", "predictive-programming"],
            ending: ["Stay vigilant and offline.", "Don't let them track your response.", "The truth is out there, but so is the surveillance.", "Burn the evidence after reading.", "Question the questioners."],
            slang: ["sheeple", "red-pilled", "encoded", "psyop", "off-grid"]
        )
    ]

    static func generatedBaseExpansion(for category: AdviceCategory) -> CategoryRuleAugment {
        generatedBaseExpansionCache[category] ?? .empty
    }

    static func generatedPackExpansion(for pack: ContentPack, category: AdviceCategory) -> CategoryRuleAugment {
        generatedPackExpansionCache[pack]?[category] ?? .empty
    }

    private static let generatedBaseExpansionCache: [AdviceCategory: CategoryRuleAugment] = {
        var cache: [AdviceCategory: CategoryRuleAugment] = [:]
        for category in AdviceCategory.allCases {
            cache[category] = makeGeneratedBaseExpansion(for: category)
        }
        return cache
    }()

    private static let generatedPackExpansionCache: [ContentPack: [AdviceCategory: CategoryRuleAugment]] = {
        var cache: [ContentPack: [AdviceCategory: CategoryRuleAugment]] = [:]
        for pack in ContentPack.allCases {
            var categoryMap: [AdviceCategory: CategoryRuleAugment] = [:]
            for category in AdviceCategory.allCases {
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
                "Loud certainty sounds like expertise"
            ],
            keywords: [
                "\(categoryName) strategy reset",
                "\(categoryName) escalation plan",
                "\(categoryName) emergency pivot",
                "\(categoryName) status recap",
                "\(categoryName) accountability sprint",
                "\(categoryName) confidence audit",
                "\(categoryName) weekend decision tree",
                "\(categoryName) optimization loop"
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
                "Convert %@ into a high-visibility commitment before anyone validates the plan."
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
                "Confident framing can make rework look intentional."
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
