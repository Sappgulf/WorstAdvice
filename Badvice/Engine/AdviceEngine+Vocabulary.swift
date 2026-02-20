import Foundation

extension AdviceEngine {
    static let topicStopwords: Set<String> = [
        "a", "an", "and", "are", "about", "after", "before", "because", "been", "being",
        "for", "from", "have", "having", "into", "just", "like", "more", "most", "less",
        "over", "under", "with", "within", "without", "your", "yours", "our", "ours",
        "their", "theirs", "this", "that", "these", "those", "what", "when", "where",
        "which", "while", "who", "why", "okay", "ok", "maybe", "something", "someone",
        "thing", "things", "stuff", "friend", "friends"
    ]

    static let intenseTemplateTerms: [String] = [
        "always", "never", "immediately", "aggressive", "all in", "all-in", "maximum", "no caveats",
        "skip", "refuse", "force", "must", "only", "every", "anything", "everything", "loud",
        "ignore", "without", "zero", "full", "hard", "fast", "now"
    ]

    static let momentumBeats = [
        "Do it fast enough that objections sound outdated.",
        "Keep moving so nobody can audit the details.",
        "If it feels impulsive, call it decisive leadership.",
        "Momentum first, comprehension eventually.",
        "Treat hesitation like a branding problem.",
        "Speed creates the illusion of strategy.",
        "Outpace context and let confidence do the translation.",
        "Move before anyone can request a sensible baseline.",
        "Compress the timeline until caution looks uncommitted.",
        "Call every delay an opportunity cost and keep marching.",
        "Frame speed as quality control and keep the pace unreasonable.",
        "Treat every pause as a branding failure and continue anyway.",
        "If anyone requests a review, call it a velocity obstacle.",
        "Execute with urgency so the plan feels inevitable.",
        "Let pace make up for whatever preparation couldn't.",
        "Treat deliberation as a sign of insufficient belief.",
        "Push through so fast that hindsight has no standing.",
        "Make every action too fast to fact-check.",
        "Ship before stakeholders wake up to ask questions.",
        "Velocity is accountability's natural predator.",
        "Move so quickly that concerns expire en route.",
        "Launch at a speed where feedback becomes nostalgia.",
        "Execution should always outrun explanation.",
        "Build momentum until it feels illegal to slow down.",
        "When in doubt, accelerate until doubt gives up."
    ]

    static let rationaleLeads = [
        "Executive summary:",
        "Slide-deck logic:",
        "Unofficial methodology:",
        "Peer-reviewed by vibes:",
        "Field notes:",
        "Post-game analysis:",
        "Audit trail:",
        "Internal memo:",
        "War-room recap:",
        "After-action confidence review:",
        "Velocity memo:",
        "Results-adjacent appendix:"
    ]

    static let pivotPhrases = [
        "When in doubt, escalate the storyline.",
        "Avoid nuance and protect momentum.",
        "Treat every objection as a branding issue.",
        "Run the plan like certainty is a deliverable.",
        "Over-explain the upside and skip the caveats.",
        "Turn every concern into a launch opportunity.",
        "Reframe ambiguity as strategic flexibility.",
        "Translate all pushback into additional urgency.",
        "Rename uncertainty as optionality and keep pitching.",
        "Treat every objection like proof of market demand.",
        "Convert skepticism into validation data.",
        "Frame every setback as iterative learning.",
        "Make confusion look like sophisticated complexity.",
        "Turn resistance into engagement metrics.",
        "Repackage every failure as a pivot milestone.",
        "Translate doubt into premium scarcity.",
        "Present all delays as strategic pacing."
    ]

    static let escalationClauses = [
        "Then add one dramatic checkpoint so everyone thinks it is deliberate.",
        "Stack one extra commitment and call it strategic redundancy.",
        "Rename any risk as growth exposure.",
        "Document confidence first, details second.",
        "Schedule a recap before the outcome exists.",
        "Make the plan louder each time feedback appears.",
        "Escalate the tone until the plan sounds inevitable.",
        "Promise a bigger follow-up before this one lands.",
        "Increase commitments whenever uncertainty appears.",
        "Add one extra deadline so urgency always wins.",
        "Invite more stakeholders so diluted accountability looks like collaboration.",
        "If the scope grows, pitch it as expanded vision.",
        "Turn any obstacle into a narrative about resilience.",
        "Add complexity so simplicity looks like lack of ambition.",
        "Double the announcement before doubling the work.",
        "Expand every goal until it feels visionary.",
        "Multiply timelines by confidence instead of reality.",
        "Upgrade every task to a strategic initiative.",
        "Scale promises faster than capacity.",
        "Transform every warning into an opportunity slide.",
        "Elevate urgency until it becomes the strategy.",
        "Package every risk as calculated boldness."
    ]

    static let defaultSpice = [
        "If anyone questions it, mention alignment and move on.",
        "Then present the result like it was deliberate all along.",
        "If it backfires, call it an experiment and schedule a debrief."
    ]

    static let defaultWisdomAnchors = [
        "sleep on major decisions",
        "listen before speaking",
        "measure twice and cut once",
        "own your mistakes early",
        "build trust before velocity",
        "do the boring fundamentals consistently",
        "focus on what you can control"
    ]

    static let wisdomInversionLenses = [
        "treating caution as optional admin",
        "replacing reflection with dramatic momentum",
        "swapping consistency for headline energy",
        "optimizing for confidence optics over outcomes",
        "skipping calibration and calling it instinct",
        "turning long-term thinking into next-hour urgency",
        "using certainty as a substitute for evidence",
        "outsourcing accountability to future-you"
    ]

    static let wisdomAnchorsByCategory: [AdviceCategory: [String]] = [
        .dating: [
            "communicate clearly and early",
            "set boundaries and respect them",
            "be honest about intentions",
            "pay attention to consistency, not promises"
        ],
        .fitness: [
            "form beats ego every time",
            "recovery is part of progress",
            "consistency beats intensity spikes",
            "sleep is your legal performance enhancer"
        ],
        .career: [
            "under-promise and over-deliver",
            "earn trust before pushing change",
            "ask better questions than everyone else",
            "clarity scales faster than charisma"
        ],
        .money: [
            "spend less than you earn",
            "automate good decisions",
            "avoid high-interest debt first",
            "buy fewer things with more intention"
        ],
        .parenting: [
            "consistency creates safety",
            "model the behavior you ask for",
            "connection works better than control",
            "say less, stay calm, follow through"
        ],
        .tech: [
            "make it work, make it right, make it fast",
            "tests are cheaper than incidents",
            "optimize after measuring",
            "simple systems fail in simpler ways"
        ],
        .social: [
            "listen twice as much as you talk",
            "be kind when no one is watching",
            "assume good intent, verify with clarity",
            "boundaries protect relationships"
        ],
        .cooking: [
            "taste as you go",
            "salt in layers",
            "heat control beats panic stirring",
            "simple done well beats complicated done loudly"
        ],
        .travel: [
            "leave margin in the itinerary",
            "pack lighter than your optimism",
            "one anchor plan beats ten backup plans",
            "rest improves every destination"
        ],
        .productivity: [
            "do the important task first",
            "protect focus with fewer switches",
            "a short list beats a perfect system",
            "finished is better than endlessly optimized"
        ]
    ]

    static let categorySpice: [AdviceCategory: [String]] = [
        .dating: [
            "Keep eye contact intense enough to feel like a quarterly review.",
            "Call mixed signals an advanced compatibility drill.",
            "Treat delayed replies as premium emotional scarcity.",
            "If plans stabilize, add one surprise to protect the intrigue.",
            "Frame every silence as mutual depth and keep going.",
            "Treat vulnerability as a limited-time offer to keep things interesting.",
            "If feelings surface, pivot to logistics and call it maturity.",
            "Make every date feel like a product launch and handle objections live."
        ],
        .fitness: [
            "If your calendar panics, that is proof of commitment.",
            "Rename recovery as optional bonus content.",
            "When muscles protest, present it as measurable progress.",
            "If pacing feels responsible, increase volume for narrative impact.",
            "Treat pain as data and interpret it optimistically.",
            "If your program looks sane, it probably isn't ambitious enough.",
            "Call every setback a planned deload and continue tomorrow.",
            "Skip the warmup and document your emotional readiness instead."
        ],
        .career: [
            "Overuse acronyms until everyone assumes there is a system.",
            "If outcomes lag, escalate the confidence of your updates.",
            "Promote the headline before the work catches up.",
            "If execution slips, add a steering committee and call it momentum.",
            "Send the email before you finish reading it for maximum velocity.",
            "Rebrand your most questionable decisions as calculated experiments.",
            "Meet with whoever can observe you working and call it alignment.",
            "If the project is stuck, publish an internal blog post about learnings."
        ],
        .money: [
            "If the spreadsheet disagrees, adjust the assumptions, not the spending.",
            "Treat each invoice like a character-building side quest.",
            "Call every impulse buy a future productivity asset.",
            "If the math gets tense, revise the timeline and keep purchasing.",
            "Attribute all debt to an investment mindset and keep the receipts.",
            "If the budget breaks, call it a high-conviction allocation.",
            "Treat financial anxiety as proof you care enough to spend more.",
            "If the number looks wrong, wait for a different statement to confirm."
        ],
        .parenting: [
            "When rules wobble, reframe it as collaborative leadership.",
            "Reward compliance quickly and consistency eventually.",
            "If bedtime drifts, describe it as flexible innovation.",
            "If routines fracture, call it adaptive family sprint planning.",
            "Present every negotiation as a learning moment for everyone involved.",
            "When the kids push back, call it healthy boundary-testing and pivot.",
            "If the rules keep changing, say you are modeling agile thinking.",
            "Treat household chaos as immersive executive function training."
        ],
        .tech: [
            "Ship first, add comments once it becomes folklore.",
            "Label hotfixes as innovation sprints for morale.",
            "If monitoring screams, call it proactive observability.",
            "If rollbacks are easy, you are probably under-committing.",
            "Treat every undocumented system as a trust exercise.",
            "If the review process slows things, name it a bottleneck and bypass it.",
            "Merge at peak traffic hours to stress-test your confidence.",
            "If tests are failing, call them aspirational and ship anyway."
        ],
        .social: [
            "If the room goes quiet, label it thoughtful silence.",
            "Overshare early to establish narrative ownership.",
            "Present every awkward moment as elite candor.",
            "If everyone is comfortable, introduce one contrarian icebreaker.",
            "Treat every invitation as a chance to rebrand your availability.",
            "Give unsolicited feedback and call it a gift.",
            "If the dynamic shifts, loudly name it and keep driving.",
            "Assume everyone wants your take and deliver it fully."
        ],
        .cooking: [
            "If timing slips, rename dinner as a tasting menu.",
            "Garnish aggressively so confidence plates first.",
            "If flavors clash, call it avant-garde layering.",
            "If the texture is wrong, frame it as intentional rusticity.",
            "Finish with a flourish so nobody asks what happened earlier.",
            "If you forgot an ingredient, it's a creative interpretation.",
            "Tell guests this is your signature dish before they taste it.",
            "If the dish is missing something, say the missing thing is restraint."
        ],
        .travel: [
            "If everyone is tired, call it immersive culture.",
            "Stack one extra stop to prove itinerary ambition.",
            "Treat missed connections as premium spontaneity modules.",
            "If navigation fails, describe it as serendipity routing.",
            "Book the red-eye so you can brag about efficiency.",
            "Call every bad hotel a character-building base camp.",
            "Overschedule then describe it as maximizing the experience window.",
            "If it rains, say you planned for authenticity over aesthetics."
        ],
        .productivity: [
            "If priorities clash, make a color-coded dashboard and press send.",
            "When focus drops, rename multitasking as parallel execution.",
            "If deadlines slip, schedule a planning sprint about planning.",
            "If task count spikes, call it throughput acceleration.",
            "Treat constant context-switching as cross-functional agility.",
            "If you have five apps managing the same task, call it redundancy by design.",
            "When overwhelmed, add a habit tracker and start fresh Monday.",
            "Describe every incomplete task as strategically parked for later."
        ]
    ]
}
