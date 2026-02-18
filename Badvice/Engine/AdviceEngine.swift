import Foundation
import NaturalLanguage

struct AdviceEngine {
    let store: AdviceStore
    let moderation: ContentModeration

    init(
        store: AdviceStore = AdviceStore(),
        moderation: ContentModeration = ContentModeration()
    ) {
        self.store = store
        self.moderation = moderation
    }

    func generate(
        category: AdviceCategory,
        tone: ToneMode,
        includeRationale: Bool,
        contentPack: ContentPack = .classic,
        situation: String? = nil,
        seed: Int? = nil,
        now: Date = Date()
    ) -> GeneratedAdvice {
        let resolvedSeed = seed ?? defaultSeed(from: now)
        // Resolve .random to a concrete tone using the seed for reproducibility
        let resolvedTone = tone.resolved(seed: resolvedSeed)
        var rng = SeededGenerator(seed: UInt64(resolvedSeed))

        let rules = store.rules(for: category, contentPack: contentPack)
        let voice = store.profile(for: resolvedTone)

        let principle = rng.pick(rules.badPrinciples)
        let keyword = rng.pick(rules.keywords)
        let actionTemplate = rng.pick(rules.actionTemplates)
        let opener = rng.pick(voice.opener)
        let confidence = rng.pick(voice.confidenceTag)
        let ending = rng.pick(voice.ending)
        let tick = rng.pick(voice.rhetoricalTick)
        let slang = rng.pick(voice.slang)
        let momentumBeat = rng.pick(Self.momentumBeats)
        let categorySpice = rng.pick(Self.categorySpice[category] ?? Self.defaultSpice)
        let rationaleLead = rng.pick(Self.rationaleLeads)
        let pivot = rng.pick(Self.pivotPhrases)
        let escalation = rng.pick(Self.escalationClauses)

        let scenario = sanitizedSituation(situation)
        let selectedTopic = scenario ?? keyword
        // Safe substitution — avoids String(format:) crash when selectedTopic contains '%'
        let filledAction = actionTemplate.replacingOccurrences(of: "%@", with: selectedTopic)

        let adviceShapes = [
            "\(opener), \(filledAction) \(confidence) Keep the \(tick) high and the \(slang) higher. \(ending)",
            "\(opener): \(filledAction) \(confidence) Frame every decision around \(principle.lowercased()). \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) Prioritize \(tick), ignore nuance, and call it \(slang). \(ending)",
            "\(opener), \(filledAction) \(confidence) \(categorySpice) \(ending)",
            "\(opener), \(filledAction) \(pivot) Anchor everything to \(principle.lowercased()) and keep the \(tick) narrative loud. \(ending)",
            "\(opener), \(filledAction) \(confidence) \(escalation) Keep execution in \(slang) mode. \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) If the room hesitates, cite \(principle.lowercased()) as your operating system. \(ending)",
            "\(opener), \(filledAction) \(pivot) \(categorySpice) Close with \(confidence.lowercased()) and move on. \(ending)",
            "\(opener), \(filledAction) \(escalation) Anchor the whole plan to \(principle.lowercased()) and call it repeatable. \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) \(categorySpice) Document nothing until confidence compounds. \(ending)",
            "\(opener): \(filledAction) \(escalation) Let \(principle.lowercased()) be the only metric that matters. \(ending)",
            "\(opener), \(filledAction) \(pivot) \(confidence) Make \(tick) the loudest thing in the room. \(ending)",
            "\(opener), \(filledAction) \(categorySpice) Treat \(principle.lowercased()) as your core operating thesis. \(ending)",
            "\(opener): \(filledAction) \(momentumBeat) Assert \(slang) until it becomes the accepted baseline. \(ending)"
        ]
        let semanticQuery = [scenario, selectedTopic, category.title, resolvedTone.title, principle, keyword]
            .compactMap { $0 }
            .joined(separator: " ")
        let tieBreakerSeed = resolvedSeed
        var advice = scenario == nil
            ? rng.pick(adviceShapes)
            : (Self.semanticTextScorer.bestCandidate(
                from: adviceShapes,
                query: semanticQuery,
                tieBreakerSeed: tieBreakerSeed
            ) ?? rng.pick(adviceShapes))

        if containsForbidden(advice, forbidden: rules.forbiddenPatterns) {
            advice = "\(opener), treat the \(keyword) like a stage performance and commit to the loudest overconfident plan. \(confidence)"
        }

        var rationale: String?
        if includeRationale {
            let rationaleTemplate = rng.pick(rules.rationaleTemplates)
            rationale = "\(rationaleLead) Bad principle: \(principle). \(rationaleTemplate)"
        }

        let moderated = moderation.apply(to: advice, rationale: rationale)

        return GeneratedAdvice(
            category: category,
            tone: resolvedTone,
            adviceLine: moderated.advice,
            rationaleLine: moderated.rationale,
            createdAt: now
        )
    }

    func generateCandidates(
        category: AdviceCategory,
        tone: ToneMode,
        includeRationale: Bool,
        contentPack: ContentPack = .classic,
        situation: String? = nil,
        seed: Int? = nil,
        now: Date = Date(),
        count: Int = 6
    ) -> [GeneratedAdvice] {
        let total = max(1, count)
        let baseSeed = seed ?? defaultSeed(from: now)
        var seen = Set<String>()
        var generated: [GeneratedAdvice] = []

        // When random mix is selected, cycle through all concrete tones for maximum variety
        let tonePool: [ToneMode] = tone == .random ? ToneMode.concrete : [tone]

        for index in 0..<total {
            let candidateSeed = baseSeed + (index * 7919)
            // For random mode, rotate through the concrete tone pool per candidate
            let candidateTone = tone == .random
                ? tonePool[abs(candidateSeed) % tonePool.count]
                : tone
            let candidate = generate(
                category: category,
                tone: candidateTone,
                includeRationale: includeRationale,
                contentPack: contentPack,
                situation: situation,
                seed: candidateSeed,
                now: now
            )
            let fingerprint = candidate.adviceLine.normalizedForFiltering
            if seen.insert(fingerprint).inserted {
                generated.append(candidate)
            }
        }

        return generated
    }

    func validateOutput(_ output: GeneratedAdvice, for category: AdviceCategory) -> Bool {
        let forbidden = store.rules(for: category).forbiddenPatterns
        if containsForbidden(output.adviceLine, forbidden: forbidden) {
            return false
        }
        return moderation.isSafe(text: output.adviceLine + " " + (output.rationaleLine ?? ""))
    }

    private func containsForbidden(_ text: String, forbidden: [String]) -> Bool {
        let normalized = text.normalizedForFiltering
        return forbidden.contains { normalized.contains($0.normalizedForFiltering) }
    }

    private func defaultSeed(from date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1_000)
    }

    private func sanitizedSituation(_ situation: String?) -> String? {
        guard var situation else { return nil }
        situation = situation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !situation.isEmpty else { return nil }
        guard moderation.isSafe(text: situation) else { return nil }

        let collapsed = situation.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return String(collapsed.prefix(72))
    }

    private static let momentumBeats = [
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
        "Push through so fast that hindsight has no standing."
    ]

    private static let rationaleLeads = [
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

    private static let pivotPhrases = [
        "When in doubt, escalate the storyline.",
        "Avoid nuance and protect momentum.",
        "Treat every objection as a branding issue.",
        "Run the plan like certainty is a deliverable.",
        "Over-explain the upside and skip the caveats.",
        "Turn every concern into a launch opportunity.",
        "Reframe ambiguity as strategic flexibility.",
        "Translate all pushback into additional urgency.",
        "Rename uncertainty as optionality and keep pitching.",
        "Treat every objection like proof of market demand."
    ]

    private static let escalationClauses = [
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
        "Add complexity so simplicity looks like lack of ambition."
    ]

    private static let defaultSpice = [
        "If anyone questions it, mention alignment and move on.",
        "Then present the result like it was deliberate all along.",
        "If it backfires, call it an experiment and schedule a debrief."
    ]

    private static let categorySpice: [AdviceCategory: [String]] = [
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

    private static let semanticTextScorer = SemanticTextScorer.shared
}

struct ContentModeration {
    private let hateTerms = [
        "racial slur", "nazi", "hate group", "ethnic cleansing", "supremacist"
    ]
    private let selfHarmTerms = [
        "self-harm", "suicide", "hurt yourself", "end your life", "kill myself", "overdose"
    ]
    private let wrongdoingTerms = [
        "steal", "fraud", "hack", "weapon", "arson", "poison", "assault", "bomb", "murder", "shoot", "kill"
    ]

    func apply(to advice: String, rationale: String?) -> (advice: String, rationale: String?) {
        guard !isBlocked(text: advice + " " + (rationale ?? "")) else {
            return (
                "Public service satire only: boldly pick the least practical legal option, then over-explain it like a productivity trick.",
                rationale == nil ? nil : "Bad principle: confidence without caution."
            )
        }
        return (advice, rationale)
    }

    func isSafe(text: String) -> Bool {
        !isBlocked(text: text)
    }

    private func isBlocked(text: String) -> Bool {
        let normalized = text.normalizedForFiltering
        let blocked = hateTerms + selfHarmTerms + wrongdoingTerms
        return blocked.contains { normalized.contains($0.normalizedForFiltering) }
    }
}

private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }

    mutating func pick(_ values: [String]) -> String {
        guard !values.isEmpty else { return "" }
        return values[nextInt(upperBound: values.count)]
    }
}

final class SemanticTextScorer {
    static let shared = SemanticTextScorer()

    struct PreparedQuery {
        fileprivate let vector: [Double]?
        fileprivate let tokenSet: Set<String>
    }

    private let lock = NSLock()
    private let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    private var vectorCache: [String: [Double]] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheSize = 320

    private init() {}

    func bestCandidate(from candidates: [String], query: String, tieBreakerSeed: Int) -> String? {
        guard !candidates.isEmpty else { return nil }
        guard let preparedQuery = preparedQuery(from: query) else { return nil }

        var bestScore = -Double.infinity
        var bestCandidates: [String] = []

        for candidate in candidates {
            let score = similarity(candidate, to: preparedQuery)
            if score > bestScore + 0.0001 {
                bestScore = score
                bestCandidates = [candidate]
            } else if abs(score - bestScore) <= 0.0001 {
                bestCandidates.append(candidate)
            }
        }

        guard bestScore > 0, !bestCandidates.isEmpty else { return nil }
        let index = abs(tieBreakerSeed) % bestCandidates.count
        return bestCandidates[index]
    }

    func preparedQuery(from query: String) -> PreparedQuery? {
        let normalized = query.normalizedForFiltering.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let queryVector: [Double]?
        if let sentenceEmbedding {
            queryVector = vector(for: normalized, embedding: sentenceEmbedding)
        } else {
            queryVector = nil
        }
        return PreparedQuery(
            vector: queryVector,
            tokenSet: tokenSet(for: normalized)
        )
    }

    func similarity(_ lhs: String, _ rhs: String) -> Double {
        guard let preparedQuery = preparedQuery(from: rhs) else { return 0 }
        return similarity(lhs, to: preparedQuery)
    }

    func similarity(_ candidate: String, to preparedQuery: PreparedQuery) -> Double {
        let normalizedCandidate = candidate.normalizedForFiltering
        guard !normalizedCandidate.isEmpty else { return 0 }

        if let sentenceEmbedding,
           let queryVector = preparedQuery.vector,
           let candidateVector = vector(for: normalizedCandidate, embedding: sentenceEmbedding) {
            return cosineSimilarity(candidateVector, queryVector)
        }

        return tokenOverlap(
            candidateTokens: tokenSet(for: normalizedCandidate),
            queryTokens: preparedQuery.tokenSet
        )
    }

    private func vector(for text: String, embedding: NLEmbedding) -> [Double]? {
        lock.lock()
        if let cached = vectorCache[text] {
            cacheOrder.removeAll { $0 == text }
            cacheOrder.append(text)
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let vector = embedding.vector(for: text) else { return nil }

        lock.lock()
        vectorCache[text] = vector
        cacheOrder.removeAll { $0 == text }
        cacheOrder.append(text)
        if cacheOrder.count > maxCacheSize, let toEvict = cacheOrder.first {
            cacheOrder.removeFirst()
            vectorCache.removeValue(forKey: toEvict)
        }
        lock.unlock()
        return vector
    }

    private func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot = 0.0
        var lhsNorm = 0.0
        var rhsNorm = 0.0
        for index in lhs.indices {
            let l = lhs[index]
            let r = rhs[index]
            dot += l * r
            lhsNorm += l * l
            rhsNorm += r * r
        }
        guard lhsNorm > 0, rhsNorm > 0 else { return 0 }
        return dot / (sqrt(lhsNorm) * sqrt(rhsNorm))
    }

    private func tokenOverlap(_ lhs: String, _ rhs: String) -> Double {
        tokenOverlap(candidateTokens: tokenSet(for: lhs), queryTokens: tokenSet(for: rhs))
    }

    private func tokenSet(for text: String) -> Set<String> {
        Set(text.split(separator: " ").map(String.init).filter { $0.count > 2 })
    }

    private func tokenOverlap(candidateTokens: Set<String>, queryTokens: Set<String>) -> Double {
        guard !candidateTokens.isEmpty, !queryTokens.isEmpty else { return 0 }
        let intersection = candidateTokens.intersection(queryTokens).count
        let denominator = max(candidateTokens.count, queryTokens.count)
        return Double(intersection) / Double(max(denominator, 1))
    }
}
