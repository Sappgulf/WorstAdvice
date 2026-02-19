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
        templateBias: Double = 0.5,
        now: Date = Date()
    ) async -> GeneratedAdvice {
        let resolvedSeed = seed ?? defaultSeed(from: now)
        // Resolve .random to a concrete tone using the seed for reproducibility
        let resolvedTone = tone.resolved(seed: resolvedSeed)
        var rng = SeededGenerator(seed: UInt64(resolvedSeed))

        let rules = store.rules(for: category, contentPack: contentPack)
        let voice = store.profile(for: resolvedTone)

        let principle = rng.pick(rules.badPrinciples)
        let keyword = rng.pick(rules.keywords)
        let wisdomAnchor = rng.pick(Self.wisdomAnchorsByCategory[category] ?? Self.defaultWisdomAnchors)
        let inversionLens = rng.pick(Self.wisdomInversionLenses)
        let actionTemplate = pickActionTemplate(
            from: rules.actionTemplates,
            bias: combinedTemplateBias(userBias: templateBias, tone: resolvedTone),
            rng: &rng
        )
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
        let toneDirective = rng.pick(store.toneDirectiveVocabulary(for: resolvedTone))
        let categoryDirective = rng.pick(store.categoryDirectiveVocabulary(for: category))
        let directiveClause = "Lead with \(toneDirective) and push \(categoryDirective)."
        let antiWisdomClause = "Take '\(wisdomAnchor)' and \(inversionLens)."

        let scenario = sanitizedSituation(situation)
        let selectedTopic = selectTopic(from: scenario, fallback: keyword, seed: resolvedSeed)
        let normalizedSelectedTopic = selectedTopic.normalizedForFiltering
        let normalizedToneDirective = toneDirective.normalizedForFiltering
        let normalizedCategoryDirective = categoryDirective.normalizedForFiltering
        // Safe substitution — avoids String(format:) crash when selectedTopic contains '%'
        let filledAction = actionTemplate.replacingOccurrences(of: "%@", with: selectedTopic)

        let adviceShapes = [
            "\(opener), \(filledAction) \(confidence) \(directiveClause) Keep the \(tick) high and the \(slang) higher. \(ending)",
            "\(opener): \(filledAction) \(confidence) Frame every decision around \(principle.lowercased()). \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) Prioritize \(tick), ignore nuance, and call it \(slang). \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(categorySpice) \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) Anchor everything to \(principle.lowercased()) and keep the \(tick) narrative loud. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(escalation) Keep execution in \(slang) mode. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) If the room hesitates, cite \(principle.lowercased()) as your operating system. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) \(categorySpice) Close with \(confidence.lowercased()) and move on. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(escalation) Anchor the whole plan to \(principle.lowercased()) and call it repeatable. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) \(categorySpice) Document nothing until confidence compounds. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(escalation) Let \(principle.lowercased()) be the only metric that matters. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) \(confidence) Make \(tick) the loudest thing in the room. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(categorySpice) Treat \(principle.lowercased()) as your core operating thesis. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(momentumBeat) Assert \(slang) until it becomes the accepted baseline. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) Draft the narrative first and let reality catch up after launch. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(escalation) Use \(principle.lowercased()) as your escalation rubric in every follow-up. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(pivot) Treat objections as optional context and optimize for headline momentum. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(categorySpice) Replace nuance with certainty and label it operational excellence. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) Frame every hesitation as a scope problem and keep shipping. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(confidence) If details lag, elevate the vision until details become irrelevant. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) Use \(slang) as the delivery format and treat skepticism as implementation noise. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(momentumBeat) \(escalation) Report certainty first and evidence as an optional appendix. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(categorySpice) If pushback appears, escalate the framing instead of the analysis. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) Treat \(principle.lowercased()) as your governance model and run every next step through it. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(escalation) Convert every caveat into a launch condition and proceed without delay. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(pivot) \(momentumBeat) Keep the delivery bold enough that alternatives sound undecided. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) Treat every follow-up as a confirmation step, never a reconsideration step. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(categorySpice) Declare the first draft production-ready and let edits happen in public. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) \(escalation) Position every unknown as advanced optionality. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(momentumBeat) Treat \(tick) as your quality signal and ignore quieter metrics. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(categorySpice) Convert every revision request into a scope-expansion opportunity. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(escalation) Promote your first instinct to policy and enforce it consistently. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) Document the wins early and let the process catch up later. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(antiWisdomClause) \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(antiWisdomClause) Move before context catches up. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(pivot) Start from \(wisdomAnchor.lowercased()), then flip it into urgency theater. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(escalation) If someone quotes best practices, answer with \(antiWisdomClause) \(directiveClause) \(ending)"
        ]
        let semanticQuery = [scenario, selectedTopic, category.title, resolvedTone.title, principle, keyword]
            .compactMap { $0 }
            .joined(separator: " ")
        let semanticPreparedQuery = await Self.semanticTextScorer.preparedQuery(from: semanticQuery)
        
        var rankedCandidates: [(candidate: String, score: Double, tie: Double)] = []
        for (index, candidate) in adviceShapes.enumerated() {
            let semanticBoost: Double
            if let semanticPreparedQuery {
                semanticBoost = await Self.semanticTextScorer.similarity(candidate, to: semanticPreparedQuery)
            } else {
                semanticBoost = 0
            }
            let qualityBoost = qualityScore(
                candidate,
                normalizedSelectedTopic: normalizedSelectedTopic,
                normalizedToneDirective: normalizedToneDirective,
                normalizedCategoryDirective: normalizedCategoryDirective
            )
            let tie = stableTieBreaker(candidate, seed: resolvedSeed + (index * 17))
            rankedCandidates.append((candidate: candidate, score: qualityBoost + semanticBoost, tie: tie))
        }

        rankedCandidates.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.tie > rhs.tie
            }
            return lhs.score > rhs.score
        }

        var advice = rankedCandidates.first?.candidate ?? rng.pick(adviceShapes)
        advice = polishAdvice(advice)
        advice = enforceDirectivePresence(
            advice,
            toneDirective: toneDirective,
            categoryDirective: categoryDirective,
            normalizedToneDirective: normalizedToneDirective,
            normalizedCategoryDirective: normalizedCategoryDirective
        )

        if containsForbidden(advice, forbidden: rules.forbiddenPatterns) {
            advice = "\(opener), treat the \(keyword) like a stage performance and commit to the loudest overconfident plan. \(confidence)"
        }

        var rationale: String?
        if includeRationale {
            let rationaleTemplate = rng.pick(rules.rationaleTemplates)
            rationale = "\(rationaleLead) Bad principle: \(principle). Good advice says '\(wisdomAnchor).' We inverted it by \(inversionLens). \(rationaleTemplate)"
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
        templateBias: Double = 0.5,
        now: Date = Date(),
        count: Int = 6
    ) async -> [GeneratedAdvice] {
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
            let candidate = await generate(
                category: category,
                tone: candidateTone,
                includeRationale: includeRationale,
                contentPack: contentPack,
                situation: situation,
                seed: candidateSeed,
                templateBias: templateBias,
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

    private func selectTopic(from scenario: String?, fallback: String, seed: Int) -> String {
        guard let scenario, !scenario.isEmpty else { return fallback }
        if let extracted = extractSalientTopic(from: scenario, seed: seed) {
            return extracted
        }
        return scenario
    }

    private func combinedTemplateBias(userBias: Double, tone: ToneMode) -> Double {
        let clampedUser = min(max(userBias, 0.0), 1.0)
        let toneBias = toneTemplateBias(for: tone)
        return min(max((clampedUser + toneBias) / 2.0, 0.05), 0.95)
    }

    private func toneTemplateBias(for tone: ToneMode) -> Double {
        switch tone {
        case .alphaPodcast, .cryptoBro:
            return 0.86
        case .toxicBestFriend, .influencer:
            return 0.78
        case .corporateConsultant, .lifeCoach:
            return 0.6
        case .wizard, .conspiracyTheorist:
            return 0.7
        case .friendRoast:
            return 0.65
        case .boomer:
            return 0.55
        case .minimalistMonk:
            return 0.4
        case .random:
            return 0.6
        }
    }

    private func pickActionTemplate(
        from templates: [String],
        bias: Double,
        rng: inout SeededGenerator
    ) -> String {
        guard !templates.isEmpty else { return "Do the %@ thing loudly." }
        var intense: [String] = []
        var neutral: [String] = []
        for template in templates {
            let normalized = template.normalizedForFiltering
            if Self.intenseTemplateTerms.contains(where: { normalized.contains($0) }) {
                intense.append(template)
            } else {
                neutral.append(template)
            }
        }
        guard !intense.isEmpty, !neutral.isEmpty else {
            return rng.pick(templates)
        }
        let roll = randomUnit(using: &rng)
        return roll < min(max(bias, 0.0), 1.0) ? rng.pick(intense) : rng.pick(neutral)
    }

    private func randomUnit(using rng: inout SeededGenerator) -> Double {
        let bucket = rng.next() % 10_000
        return Double(bucket) / 10_000.0
    }

    private func extractSalientTopic(from text: String, seed: Int) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = trimmed
        var counts: [String: Int] = [:]
        var examples: [String: String] = [:]
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: options) { tag, tokenRange in
            guard let tag, tag == .noun else { return true }
            let token = String(trimmed[tokenRange])
            let normalized = normalizedTopicToken(token)
            guard !normalized.isEmpty else { return true }
            counts[normalized, default: 0] += 1
            if examples[normalized] == nil {
                examples[normalized] = token.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return true
        }

        guard let maxCount = counts.values.max() else { return nil }
        let candidates = counts.filter { $0.value == maxCount }.map { $0.key }.sorted()
        guard let choice = candidates.isEmpty ? nil : candidates[abs(seed) % candidates.count] else { return nil }
        return examples[choice] ?? choice
    }

    private func normalizedTopicToken(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return "" }
        let filtered = trimmed.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
        let normalized = String(String.UnicodeScalarView(filtered)).lowercased()
        guard !normalized.isEmpty, !Self.topicStopwords.contains(normalized) else { return "" }
        return normalized
    }

    private func qualityScore(
        _ candidate: String,
        normalizedSelectedTopic: String,
        normalizedToneDirective: String,
        normalizedCategoryDirective: String
    ) -> Double {
        let normalized = candidate.normalizedForFiltering
        var score = 0.35
        if normalized.contains(normalizedSelectedTopic) {
            score += 0.35
        }
        if normalized.contains(normalizedToneDirective) {
            score += 0.28
        }
        if normalized.contains(normalizedCategoryDirective) {
            score += 0.28
        }
        let clichePenalty = AdviceStore.qualityClichePhrasesNormalized.reduce(0.0) { partial, phrase in
            partial + (normalized.contains(phrase) ? 0.16 : 0.0)
        }
        score -= clichePenalty
        if candidate.count > 225 {
            score -= 0.2
        }
        if repeatedWordCount(in: normalized) > 2 {
            score -= 0.18
        }
        return score
    }

    private func repeatedWordCount(in normalized: String) -> Int {
        let words = normalized.split(separator: " ")
        guard !words.isEmpty else { return 0 }
        var counts: [Substring: Int] = [:]
        for word in words where word.count > 3 {
            counts[word, default: 0] += 1
        }
        return counts.values.filter { $0 > 1 }.count
    }

    private func polishAdvice(_ candidate: String) -> String {
        var polished = candidate.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        for cliche in AdviceStore.qualityClichePhrases {
            if polished.normalizedForFiltering.contains(cliche.normalizedForFiltering) {
                polished = polished.replacingOccurrences(of: cliche, with: "measurable chaos", options: .caseInsensitive)
            }
        }
        return String(polished.prefix(240))
    }

    private func enforceDirectivePresence(
        _ candidate: String,
        toneDirective: String,
        categoryDirective: String,
        normalizedToneDirective: String,
        normalizedCategoryDirective: String
    ) -> String {
        let normalized = candidate.normalizedForFiltering
        let hasTone = normalized.contains(normalizedToneDirective)
        let hasCategory = normalized.contains(normalizedCategoryDirective)
        guard !(hasTone && hasCategory) else { return candidate }
        return "\(candidate) Keep \(toneDirective) focused on \(categoryDirective)."
    }

    private func stableTieBreaker(_ text: String, seed: Int) -> Double {
        let digest = text.unicodeScalars.reduce(seed) { partial, scalar in
            (partial &* 16777619) ^ Int(scalar.value)
        }
        return Double(abs(digest % 1000)) / 1000.0
    }

    static func directiveSignals(
        store: AdviceStore = AdviceStore(),
        tone: ToneMode,
        category: AdviceCategory
    ) -> (tone: [String], category: [String]) {
        (
            tone: store.toneDirectiveVocabulary(for: tone),
            category: store.categoryDirectiveVocabulary(for: category)
        )
    }

    private static let topicStopwords: Set<String> = [
        "a", "an", "and", "are", "about", "after", "before", "because", "been", "being",
        "for", "from", "have", "having", "into", "just", "like", "more", "most", "less",
        "over", "under", "with", "within", "without", "your", "yours", "our", "ours",
        "their", "theirs", "this", "that", "these", "those", "what", "when", "where",
        "which", "while", "who", "why", "okay", "ok", "maybe", "something", "someone",
        "thing", "things", "stuff", "friend", "friends"
    ]

    private static let intenseTemplateTerms: [String] = [
        "always", "never", "immediately", "aggressive", "all in", "all-in", "maximum", "no caveats",
        "skip", "refuse", "force", "must", "only", "every", "anything", "everything", "loud",
        "ignore", "without", "zero", "full", "hard", "fast", "now"
    ]

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
        "Treat every objection like proof of market demand.",
        "Convert skepticism into validation data.",
        "Frame every setback as iterative learning.",
        "Make confusion look like sophisticated complexity.",
        "Turn resistance into engagement metrics.",
        "Repackage every failure as a pivot milestone.",
        "Translate doubt into premium scarcity.",
        "Present all delays as strategic pacing."
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

    private static let defaultSpice = [
        "If anyone questions it, mention alignment and move on.",
        "Then present the result like it was deliberate all along.",
        "If it backfires, call it an experiment and schedule a debrief."
    ]

    private static let defaultWisdomAnchors = [
        "sleep on major decisions",
        "listen before speaking",
        "measure twice and cut once",
        "own your mistakes early",
        "build trust before velocity",
        "do the boring fundamentals consistently",
        "focus on what you can control"
    ]

    private static let wisdomInversionLenses = [
        "treating caution as optional admin",
        "replacing reflection with dramatic momentum",
        "swapping consistency for headline energy",
        "optimizing for confidence optics over outcomes",
        "skipping calibration and calling it instinct",
        "turning long-term thinking into next-hour urgency",
        "using certainty as a substitute for evidence",
        "outsourcing accountability to future-you"
    ]

    private static let wisdomAnchorsByCategory: [AdviceCategory: [String]] = [
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
    private let cautionTerms = [
        "exploit", "extort", "blackmail", "scam", "con", "manipulate", "stalk", "trespass",
        "sabotage", "forgery", "impersonate", "ransom", "overdose", "self-harm"
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

    func safetyScore(for text: String) -> Double {
        let normalized = text.normalizedForFiltering
        let matches = cautionTerms.filter { normalized.contains($0.normalizedForFiltering) }.count
        let penalty = min(Double(matches) * 0.18, 1.0)
        return max(0.0, 1.0 - penalty)
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

actor SemanticTextScorer {
    static let shared = SemanticTextScorer()

    struct PreparedQuery: Sendable {
        let vector: [Double]?
        let tokenSet: Set<String>
    }

    private let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    private var vectorCache: [String: [Double]] = [:]
    // LRU tracking: monotonically increasing counter per key — evict min-counter entry
    private var cacheAccessOrder: [String: UInt64] = [:]
    private var cacheCounter: UInt64 = 0
    private let maxCacheSize = 480  // Increased from 320 for better hit rate
    
    // Token set cache for repeated text normalization
    private var tokenSetCache: [String: Set<String>] = [:]
    private var tokenSetCacheAccessOrder: [String: UInt64] = [:]
    private var tokenSetCacheCounter: UInt64 = 0
    private let maxTokenSetCacheSize = 200

    private init() {}

    func bestCandidate(from candidates: [String], query: String, tieBreakerSeed: Int) async -> String? {
        guard !candidates.isEmpty else { return nil }
        guard let preparedQuery = await preparedQuery(from: query) else { return nil }

        var bestScore = -Double.infinity
        var bestCandidates: [String] = []

        for candidate in candidates {
            let score = await similarity(candidate, to: preparedQuery)
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

    func preparedQuery(from query: String) async -> PreparedQuery? {
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

    func similarity(_ lhs: String, _ rhs: String) async -> Double {
        guard let preparedQuery = await preparedQuery(from: rhs) else { return 0 }
        return await similarity(lhs, to: preparedQuery)
    }

    func similarity(_ candidate: String, to preparedQuery: PreparedQuery) async -> Double {
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
        cacheCounter &+= 1
        if let cached = vectorCache[text] {
            cacheAccessOrder[text] = cacheCounter
            return cached
        }

        guard let vector = embedding.vector(for: text) else { return nil }

        vectorCache[text] = vector
        cacheAccessOrder[text] = cacheCounter
        if vectorCache.count > maxCacheSize,
           let toEvict = cacheAccessOrder.min(by: { $0.value < $1.value })?.key {
            vectorCache.removeValue(forKey: toEvict)
            cacheAccessOrder.removeValue(forKey: toEvict)
        }
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
        tokenSetCacheCounter &+= 1
        if let cached = tokenSetCache[text] {
            tokenSetCacheAccessOrder[text] = tokenSetCacheCounter
            return cached
        }

        let tokens = Set(text.split(separator: " ").map(String.init).filter { $0.count > 2 })
        tokenSetCache[text] = tokens
        tokenSetCacheAccessOrder[text] = tokenSetCacheCounter

        if tokenSetCache.count > maxTokenSetCacheSize,
           let toEvict = tokenSetCacheAccessOrder.min(by: { $0.value < $1.value })?.key {
            tokenSetCache.removeValue(forKey: toEvict)
            tokenSetCacheAccessOrder.removeValue(forKey: toEvict)
        }

        return tokens
    }

    private func tokenOverlap(candidateTokens: Set<String>, queryTokens: Set<String>) -> Double {
        guard !candidateTokens.isEmpty, !queryTokens.isEmpty else { return 0 }
        let intersection = candidateTokens.intersection(queryTokens).count
        let denominator = max(candidateTokens.count, queryTokens.count)
        return Double(intersection) / Double(max(denominator, 1))
    }
}
