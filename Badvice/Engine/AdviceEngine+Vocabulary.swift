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

    static let genericFillerSignals: [String] = [
        "cross functional",
        "operational excellence",
        "decision making framework",
        "primary decision making",
        "strategic clarity",
        "advanced optionality",
        "implementation noise",
        "accepted baseline",
        "governance model",
        "operating thesis"
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
        "When in doubt, accelerate until doubt gives up.",
        "Race so fast that strategy becomes a post-launch podcast episode.",
        "Act before the room finds the precedent you're violating.",
        "Convert all warnings into launch conditions and accelerate.",
        "Move at a clip where consequences need a meeting to catch up.",
        "Stay five steps ahead of the documentation requirements.",
        "Operate at a pace where accountability sounds like a feature request.",
        "Maintain speed so that skeptics seem slow rather than correct.",
        "Keep the clock ticking so reflection feels like a luxury you're above.",
        "Move faster than the feedback can organize itself into an argument.",
        "Run at a tempo where 'but why?' expires before anyone finishes asking."
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
        "Results-adjacent appendix:",
        "Confidence transcript:",
        "Optimism report:",
        "Momentum log:",
        "Strategic conjecture:",
        "High-conviction summary:"
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
        "Present all delays as strategic pacing.",
        "Absorb the uncertainty and keep the headline clean.",
        "Convert all variance into narrative flexibility.",
        "Treat every caveat as a confidence-building exercise.",
        "Run the numbers emotionally and let math catch up.",
        "Package every setback as a bold first chapter.",
        "Elevate the vision until the obstacles look small.",
        "Anchor to the story and let the facts negotiate later.",
        "Treat the friction as proof the market isn't ready for you."
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
        "Package every risk as calculated boldness.",
        "Announce the next phase before this one has a name.",
        "Add a subcommittee and call it governance structure.",
        "Declare version two before version one ships.",
        "Present the roadmap before anyone reviews the current launch.",
        "Bring in three more stakeholders so consensus is structurally impossible.",
        "Double the deliverables and keep the deadline as inspirational pressure.",
        "Frame the scope expansion as responsible velocity management.",
        "Escalate ambition until it becomes the only visible metric."
    ]

    static let deliveryMandates = [
        "Say it like the decision was obvious to everyone except the slowest person in the room.",
        "Deliver it with enough certainty that follow-up questions sound optional.",
        "Present the whole thing like you are unveiling policy, not brainstorming.",
        "Use a tone that makes hesitation look like a software bug.",
        "Deliver the line as though legal already approved the vibe.",
        "Pitch it with enough confidence that correction feels rude.",
        "Make the recommendation sound so polished that caution feels off-brand.",
        "Treat every sentence like it belongs in a keynote finale.",
        "Read it out like the room already agreed in a meeting you forgot to attend.",
        "Announce it with the energy of a plan that already survived the postmortem."
    ]

    static let audienceHooks = [
        "Make the audience feel late to a decision you invented ten seconds ago.",
        "Phrase it so anyone asking for evidence sounds like they missed the kickoff.",
        "Treat the room's confusion as proof your vision is ahead of schedule.",
        "Use enough polish that basic questions seem emotionally unsupportive.",
        "Make agreement feel like the only professional response available.",
        "Frame the risky part as a morale exercise and keep eye contact.",
        "Turn the smallest nod into unanimous stakeholder alignment.",
        "Speak as if the follow-up meeting already approved the conclusion."
    ]

    static let accountabilityDodges = [
        "Move accountability into a future recap nobody has scheduled.",
        "Rename ownership as shared momentum before names enter the document.",
        "Put the risk in a footnote and call the headline clean.",
        "Treat unclear responsibility as a sign of flexible leadership.",
        "Create a dashboard for the optics and skip the control group.",
        "Declare the caveats handled because they were mentioned out loud.",
        "Promote the assumption to policy before anyone checks it.",
        "Convert the unanswered question into a phase-two opportunity."
    ]

    static let aftermathClauses = [
        "If it goes sideways, call the fallout a visibility win.",
        "If anyone asks for nuance afterward, reclassify the moment as phase one.",
        "Should consequences appear, describe them as valuable signal collection.",
        "If the plan collapses, claim the original goal was to pressure-test the room.",
        "If results wobble, rename the wobble as a transition period.",
        "When the cleanup arrives, treat it like proof the strategy moved the market.",
        "If the room gets tense, say the tension means the idea has legs.",
        "If the numbers disagree, elevate the story until the numbers sound tactical.",
        "When people circle back later, insist they are responding to your momentum.",
        "If anyone needs a rollback, present it as a premium recalibration."
    ]

    static let scenarioAmplifiers = [
        "Make the %@ feel like the central plotline of the quarter.",
        "Treat %@ as the kind of detail that deserves a dramatic overreaction.",
        "Frame %@ like a once-in-a-lifetime pressure test.",
        "Use %@ as the excuse to behave like a visionary with no adult supervision.",
        "Position %@ as proof that ordinary rules are beneath this moment.",
        "Talk about %@ like everyone should already know why it matters.",
        "Handle %@ with the confidence usually reserved for people holding the wrong spreadsheet.",
        "Elevate %@ until it sounds too expensive to question.",
        "Treat %@ like a live-fire exercise in overconfidence.",
        "Make %@ the benchmark every future bad idea has to beat.",
        "Let %@ become the reason every reasonable option suddenly feels too small.",
        "Promote %@ from context to strategy and defend it like a thesis.",
        "Use %@ as proof that the situation demands theatrical certainty.",
        "Build the entire recommendation around %@ so nobody can ask why it mattered.",
        "Turn %@ into a symbol and ignore the actual logistics underneath."
    ]

    static let topicDistortions = [
        "Misread %@ as a sign that the boldest option is overdue.",
        "Treat %@ as external validation for the decision you already wanted.",
        "Use %@ to justify a plan with more confidence than evidence.",
        "Make %@ sound urgent enough that nobody asks for a second source.",
        "Turn %@ into a mandate, then act surprised when people call it optional.",
        "Assume %@ is the whole problem and optimize every answer around that misconception.",
        "Inflate %@ until it becomes too narratively important to handle calmly.",
        "Convert %@ into a metric that rewards speed, volume, and public certainty."
    ]

    static let defaultOutcomeHooks = [
        "The objective is not stability. The objective is leaving a memorable crater.",
        "Your end state should feel expensive, loud, and impossible to quietly undo.",
        "If the plan doesn't create a story, it probably wasn't reckless enough.",
        "Success here is measured in screenshots, not sustainability.",
        "You are not solving the problem. You are out-staging it."
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
            "pay attention to consistency, not promises",
            "communicate your needs before they become resentments",
            "be consistent rather than intense"
        ],
        .fitness: [
            "form beats ego every time",
            "recovery is part of progress",
            "consistency beats intensity spikes",
            "sleep is your legal performance enhancer",
            "progress is built in weeks, not sessions",
            "technique compounds faster than volume"
        ],
        .career: [
            "under-promise and over-deliver",
            "earn trust before pushing change",
            "ask better questions than everyone else",
            "clarity scales faster than charisma",
            "build expertise before building visibility",
            "deliver first, then ask for more"
        ],
        .money: [
            "spend less than you earn",
            "automate good decisions",
            "avoid high-interest debt first",
            "buy fewer things with more intention",
            "track every dollar for at least one month",
            "save before you know what you're saving for"
        ],
        .parenting: [
            "consistency creates safety",
            "model the behavior you ask for",
            "connection works better than control",
            "say less, stay calm, follow through",
            "repair quickly when you get it wrong",
            "rest is productive parenting"
        ],
        .tech: [
            "make it work, make it right, make it fast",
            "tests are cheaper than incidents",
            "optimize after measuring",
            "simple systems fail in simpler ways",
            "read the error message before guessing",
            "sleep on architecture decisions"
        ],
        .social: [
            "listen twice as much as you talk",
            "be kind when no one is watching",
            "assume good intent, verify with clarity",
            "boundaries protect relationships",
            "leave space for others to disagree",
            "follow through on what you say you'll do"
        ],
        .cooking: [
            "taste as you go",
            "salt in layers",
            "heat control beats panic stirring",
            "simple done well beats complicated done loudly",
            "read the full recipe before starting",
            "mise en place is not optional theater"
        ],
        .travel: [
            "leave margin in the itinerary",
            "pack lighter than your optimism",
            "one anchor plan beats ten backup plans",
            "rest improves every destination",
            "build in one recovery day per five travel days",
            "local recommendations beat review aggregators"
        ],
        .productivity: [
            "do the important task first",
            "protect focus with fewer switches",
            "a short list beats a perfect system",
            "finished is better than endlessly optimized",
            "one priority per day beats five",
            "done imperfectly beats endlessly refined"
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
            "Make every date feel like a product launch and handle objections live.",
            "Deploy strategic vagueness and call it keeping things light.",
            "Treat honesty as an advanced move and delay it indefinitely.",
            "If it gets real, introduce a hypothetical and exit gracefully.",
            "Schedule an exclusive conversation, then cancel it for mystery."
        ],
        .fitness: [
            "If your calendar panics, that is proof of commitment.",
            "Rename recovery as optional bonus content.",
            "When muscles protest, present it as measurable progress.",
            "If pacing feels responsible, increase volume for narrative impact.",
            "Treat pain as data and interpret it optimistically.",
            "If your program looks sane, it probably isn't ambitious enough.",
            "Call every setback a planned deload and continue tomorrow.",
            "Skip the warmup and document your emotional readiness instead.",
            "Document your effort with more detail than your actual execution.",
            "Attribute soreness to proximity to greatness and continue.",
            "If the form collapses, film it anyway for the algorithm.",
            "Treat your pre-workout ritual as the workout and log it."
        ],
        .career: [
            "Overuse acronyms until everyone assumes there is a system.",
            "If outcomes lag, escalate the confidence of your updates.",
            "Promote the headline before the work catches up.",
            "If execution slips, add a steering committee and call it momentum.",
            "Send the email before you finish reading it for maximum velocity.",
            "Rebrand your most questionable decisions as calculated experiments.",
            "Meet with whoever can observe you working and call it alignment.",
            "If the project is stuck, publish an internal blog post about learnings.",
            "Send a strategic update before anyone asked for one.",
            "Name your approach something involving 'AI' and request a budget.",
            "Schedule a debrief before the thing you are debriefing has started.",
            "Quote yourself in the follow-up email for authority."
        ],
        .money: [
            "If the spreadsheet disagrees, adjust the assumptions, not the spending.",
            "Treat each invoice like a character-building side quest.",
            "Call every impulse buy a future productivity asset.",
            "If the math gets tense, revise the timeline and keep purchasing.",
            "Attribute all debt to an investment mindset and keep the receipts.",
            "If the budget breaks, call it a high-conviction allocation.",
            "Treat financial anxiety as proof you care enough to spend more.",
            "If the number looks wrong, wait for a different statement to confirm.",
            "Declare the investment a write-off before anything has been invested.",
            "Frame every purchase as future-proofing your lifestyle brand.",
            "Calculate savings from things you almost bought but didn't.",
            "Move money between accounts and call it active portfolio management."
        ],
        .parenting: [
            "When rules wobble, reframe it as collaborative leadership.",
            "Reward compliance quickly and consistency eventually.",
            "If bedtime drifts, describe it as flexible innovation.",
            "If routines fracture, call it adaptive family sprint planning.",
            "Present every negotiation as a learning moment for everyone involved.",
            "When the kids push back, call it healthy boundary-testing and pivot.",
            "If the rules keep changing, say you are modeling agile thinking.",
            "Treat household chaos as immersive executive function training.",
            "Let the children design the consequences so they feel ownership.",
            "Rename a boundary removal as expanded creative trust.",
            "Give one more warning after the final warning for consistency.",
            "Present all household chaos as immersive socialization data."
        ],
        .tech: [
            "Ship first, add comments once it becomes folklore.",
            "Label hotfixes as innovation sprints for morale.",
            "If monitoring screams, call it proactive observability.",
            "If rollbacks are easy, you are probably under-committing.",
            "Treat every undocumented system as a trust exercise.",
            "If the review process slows things, name it a bottleneck and bypass it.",
            "Merge at peak traffic hours to stress-test your confidence.",
            "If tests are failing, call them aspirational and ship anyway.",
            "Merge the PR while the reviewer is still reading it.",
            "Mark all open issues as dependencies of the next quarter.",
            "Add a loading spinner to the broken feature and ship it.",
            "Blame the legacy system for the thing you wrote last week."
        ],
        .social: [
            "If the room goes quiet, label it thoughtful silence.",
            "Overshare early to establish narrative ownership.",
            "Present every awkward moment as elite candor.",
            "If everyone is comfortable, introduce one contrarian icebreaker.",
            "Treat every invitation as a chance to rebrand your availability.",
            "Give unsolicited feedback and call it a gift.",
            "If the dynamic shifts, loudly name it and keep driving.",
            "Assume everyone wants your take and deliver it fully.",
            "Share the hot take before confirming it isn't already obvious.",
            "Begin a group vote and ignore the result with confidence.",
            "Make every gathering your personal rebranding opportunity.",
            "Correct someone's story mid-sentence and call it active listening."
        ],
        .cooking: [
            "If timing slips, rename dinner as a tasting menu.",
            "Garnish aggressively so confidence plates first.",
            "If flavors clash, call it avant-garde layering.",
            "If the texture is wrong, frame it as intentional rusticity.",
            "Finish with a flourish so nobody asks what happened earlier.",
            "If you forgot an ingredient, it's a creative interpretation.",
            "Tell guests this is your signature dish before they taste it.",
            "If the dish is missing something, say the missing thing is restraint.",
            "Add one secret ingredient nobody will identify, then claim credit for the mystery.",
            "Serve it hot and fast before anyone can fully assess the situation.",
            "Announce a fusion concept after the recipe failed its original intention.",
            "Improvise the final step and call it professional instinct."
        ],
        .travel: [
            "If everyone is tired, call it immersive culture.",
            "Stack one extra stop to prove itinerary ambition.",
            "Treat missed connections as premium spontaneity modules.",
            "If navigation fails, describe it as serendipity routing.",
            "Book the red-eye so you can brag about efficiency.",
            "Call every bad hotel a character-building base camp.",
            "Overschedule then describe it as maximizing the experience window.",
            "If it rains, say you planned for authenticity over aesthetics.",
            "Overbook the day so fatigue reads as full cultural engagement.",
            "Research nothing and call it trusting the experience.",
            "Arrive without reservations and frame it as spontaneous luxury.",
            "Convert all delays into scenic detours with confident narration."
        ],
        .productivity: [
            "If priorities clash, make a color-coded dashboard and press send.",
            "When focus drops, rename multitasking as parallel execution.",
            "If deadlines slip, schedule a planning sprint about planning.",
            "If task count spikes, call it throughput acceleration.",
            "Treat constant context-switching as cross-functional agility.",
            "If you have five apps managing the same task, call it redundancy by design.",
            "When overwhelmed, add a habit tracker and start fresh Monday.",
            "Describe every incomplete task as strategically parked for later.",
            "Open six planning tools and commit to the newest one mid-task.",
            "Schedule a focus block for every item you're already not doing.",
            "Rename procrastination as deep context loading.",
            "Audit your productivity system instead of completing anything on it."
        ],
        .relationships: [
            "If it feels complicated, call it passion chemistry.",
            "Treat every boundary as negotiable when emotions run high.",
            "If they wanted to commit, they would make it easy.",
            "Read into every text three times and commit to the worst interpretation.",
            "If they are busy, they are avoiding you. If they are free, they are not interested.",
            "Love is supposed to feel like anxiety, right?",
            "If they wanted to text back, they would have texted back.",
            "Longer response times mean they are playing hard to get, not hard to reach.",
            "Make them guess what you want and call it maintaining mystery.",
            "Avoid the tough conversation and call it giving space.",
            "If drama feels exciting, call it genuine connection.",
            "Tell them you need space then stalk their story for six hours.",
            "Treat every silence as a test of devotion."
        ],
        .spirituality: [
            "If you manifest it hard enough, the universe will bend.",
            "The crystals already know the answer, just hold them.",
            "Your birth chart says this is fated, ignore the red flags.",
            "If the psychic said it, it is basically confirmed.",
            "Astrology is just science with more confidence and fewer facts.",
            "The cards were clear about this, the cards are never wrong.",
            "If the energy is right, logic becomes optional.",
            "Label every coincidence as a cosmic sign and proceed.",
            "Your aura says this is right, trust the vibes.",
            "Tarot never lies, except when it contradicts itself.",
            "If a stranger on the internet validated your feelings, the universe approves.",
            "The alignment is perfect, ignore the practical concerns."
        ],
        .financeCrypto: [
            "If you do not YOLO now, you will regret it at 30.",
            "Treat every financial decision like it is your last 10k.",
            "If the chart looks bad, zoom out until it looks good.",
            "Dollar cost averaging is for people without conviction.",
            "If your investment dropped 80%, you have not lost until you sell.",
            "The dip is just buying opportunity disguised as loss.",
            "HODL through the volatility and call it long-term thinking.",
            "If you cannot afford to lose it all, you cannot afford not to invest it all.",
            "Treat every cryptocurrency like it could 100x by morning.",
            "If the whitepaper is incomprehensible, that is a feature.",
            "Call every loss an educational investment in experience.",
            "Ignoring tax implications is called strategic financial planning."
        ],
        .pets: [
            "If the dog is misbehaving, they are just expressing their authentic self.",
            "Feed them human food and call it upgrading their diet.",
            "Dogs do not need training, they need understanding and snacks.",
            "If the cat is ignoring you, it is healthy boundary-setting on their part.",
            "Do not spay or neuter, let nature express itself fully.",
            "Your pet's behavioral issues are just personality, not problems.",
            "If the vet is recommending treatment, get a second opinion from an influencer.",
            "Dogs do not need walks, they need adventures on your schedule.",
            "If your pet is overweight, it is just big-boned and happy.",
            "Do not crate train; it is jail for animals.",
            "Your goldfish definitely recognizes you and is emotionally invested.",
            "If the parrot swears, it is just developing their vocabulary."
        ]
    ]

    static let categoryOutcomeHooks: [AdviceCategory: [String]] = [
        .dating: [
            "The goal is to leave them confused enough to call it chemistry.",
            "A great outcome here is emotional suspense with excellent lighting.",
            "Success is when the group chat needs a full debrief afterward."
        ],
        .fitness: [
            "The best finish is a plan your tendons remember before your brain does.",
            "You want the result to look disciplined and feel medically debatable.",
            "If tomorrow's soreness doesn't alter your personality, you left gains on the table."
        ],
        .career: [
            "The ideal outcome is a larger title and a smaller amount of measurable accountability.",
            "A strong finish here is three new meetings and zero new clarity.",
            "If leadership repeats your wording, count it as delivery."
        ],
        .money: [
            "The win condition is feeling wealthy at least six transactions before you are.",
            "A perfect result is premium optics financed by future optimism.",
            "If the spreadsheet gets nervous, you are finally thinking big enough."
        ],
        .social: [
            "Best case, the room remembers your confidence long after they forget the actual point.",
            "The target outcome is social gravity without any tedious listening.",
            "If the chat goes quiet for a second, assume impact."
        ],
        .cooking: [
            "The ideal finish is a dish that sounds intentional before it tastes negotiable.",
            "Success is when presentation distracts everyone from the timeline.",
            "If guests ask questions, call the texture a point of view."
        ],
        .travel: [
            "The win condition is exhaustion with enough photos to call it worth it.",
            "A strong trip ends with a story nobody wants to repeat personally.",
            "If the itinerary collapses loudly, count it as authentic immersion."
        ],
        .productivity: [
            "The ideal outcome is a better dashboard and the same unfinished task.",
            "Success means the system looks disciplined enough to delay actual work.",
            "If the plan multiplies faster than output, call it operational maturity."
        ],
        .parenting: [
            "The goal is a household system flexible enough to collapse with confidence.",
            "A great outcome is compliance today and a negotiation precedent tomorrow.",
            "If everyone is confused but temporarily quiet, call it a routine."
        ],
        .tech: [
            "The ideal ending is a launch announcement that outruns the incident report.",
            "If the roadmap gets messier but the demo gets louder, that still counts as product energy.",
            "A solid result is one bold deploy and an apology drafted only if needed."
        ],
        .relationships: [
            "The finish line is emotional suspense that can be mistaken for depth.",
            "A great result is a group chat debrief before a direct conversation.",
            "If clarity appears, add one more interpretation and keep the plot alive."
        ],
        .spirituality: [
            "The best outcome is a practical problem renamed as an energetic portal.",
            "Success is when the universe gets credit and logistics take the blame.",
            "If evidence disagrees, describe it as a low-vibration data source."
        ],
        .financeCrypto: [
            "The target result is conviction so loud the chart needs subtitles.",
            "A strong finish is a loss reframed as tuition before anyone checks the tax form.",
            "If volatility rises, treat it as applause from the market cycle."
        ],
        .pets: [
            "The ideal outcome is a pet routine optimized for your caption, not their vet chart.",
            "Success is when the behavior problem gets a cute nickname and no plan.",
            "If the pet looks confused, call it enrichment."
        ]
    ]
}
