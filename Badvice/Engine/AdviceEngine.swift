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
        var rng = SeededGenerator(seed: UInt64(bitPattern: Int64(resolvedSeed)))

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
        // #11 Situation Context Weighting:
        // Repeat scenario and selectedTopic (derived from user's situation input) twice so they
        // carry 2× the semantic weight compared to generic category/tone tokens.
        let semanticQuery = [scenario, scenario, selectedTopic, selectedTopic, category.title, resolvedTone.title, principle, keyword]
            .compactMap { $0 }
            .joined(separator: " ")
        let semanticPreparedQuery = await Self.semanticTextScorer.preparedQuery(from: semanticQuery)
        let semanticScores: [Double]
        if let semanticPreparedQuery {
            semanticScores = await Self.semanticTextScorer.similarityScores(
                for: adviceShapes,
                to: semanticPreparedQuery
            )
        } else {
            semanticScores = Array(repeating: 0, count: adviceShapes.count)
        }
        
        var rankedCandidates: [(candidate: String, score: Double, tie: Double)] = []
        for (index, candidate) in adviceShapes.enumerated() {
            let semanticBoost = semanticScores[index]
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

        let maxUniqueAttempts = max(total * 5, total + 8)
        var attempt = 0
        while generated.count < total && attempt < maxUniqueAttempts {
            let candidateSeed = baseSeed + (attempt * 7919)
            // For random mode, rotate through the concrete tone pool per candidate
            let candidateTone = tone == .random
                ? tonePool[candidateSeed.positiveModulo(tonePool.count)]
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
            attempt += 1
        }

        // Preserve requested batch size even when dedupe pressure is high (e.g. narrow custom stores/tests).
        while generated.count < total {
            let fallbackSeed = baseSeed + (attempt * 7919)
            let candidateTone = tone == .random
                ? tonePool[fallbackSeed.positiveModulo(tonePool.count)]
                : tone
            let candidate = await generate(
                category: category,
                tone: candidateTone,
                includeRationale: includeRationale,
                contentPack: contentPack,
                situation: situation,
                seed: fallbackSeed,
                templateBias: templateBias,
                now: now
            )
            generated.append(candidate)
            attempt += 1
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
        case .alphaPodcast, .cryptoBro, .redditCommenter:
            return 0.86
        case .toxicBestFriend, .influencer, .genZ:
            return 0.78
        case .corporateConsultant, .lifeCoach, .linkedInInfluencer:
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
        guard let choice = candidates.isEmpty ? nil : candidates[seed.positiveModulo(candidates.count)] else { return nil }
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
        // Prefix the directives so later truncation cannot drop the required signals.
        return "Lead with \(toneDirective) and push \(categoryDirective). \(candidate)"
    }

    private func stableTieBreaker(_ text: String, seed: Int) -> Double {
        let digest = text.unicodeScalars.reduce(seed) { partial, scalar in
            (partial &* 16777619) ^ Int(scalar.value)
        }
        return Double(digest.positiveModulo(1000)) / 1000.0
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
        let tokenized = tokenizedSearchText(from: text)
        let matches = cautionTerms.filter { containsWholeTerm($0, in: tokenized) }.count
        let penalty = min(Double(matches) * 0.18, 1.0)
        return max(0.0, 1.0 - penalty)
    }

    private func isBlocked(text: String) -> Bool {
        let blocked = hateTerms + selfHarmTerms + wrongdoingTerms
        let tokenized = tokenizedSearchText(from: text)
        return blocked.contains { containsWholeTerm($0, in: tokenized) }
    }

    private func tokenizedSearchText(from text: String) -> String {
        let normalized = text.normalizedForFiltering
        let scalars = normalized.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        let collapsed = String(scalars).replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return " \(collapsed.trimmingCharacters(in: .whitespacesAndNewlines)) "
    }

    private func containsWholeTerm(_ term: String, in tokenizedText: String) -> Bool {
        let normalizedTerm = term.normalizedForFiltering.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTerm.isEmpty else { return false }
        return tokenizedText.contains(" \(normalizedTerm) ")
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
        let index = tieBreakerSeed.positiveModulo(bestCandidates.count)
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
        return similarity(forNormalizedCandidate: normalizedCandidate, to: preparedQuery)
    }

    func similarityScores(for candidates: [String], to preparedQuery: PreparedQuery) async -> [Double] {
        guard !candidates.isEmpty else { return [] }
        var scores: [Double] = []
        scores.reserveCapacity(candidates.count)
        for candidate in candidates {
            let normalizedCandidate = candidate.normalizedForFiltering
            scores.append(similarity(forNormalizedCandidate: normalizedCandidate, to: preparedQuery))
        }
        return scores
    }

    private func similarity(forNormalizedCandidate normalizedCandidate: String, to preparedQuery: PreparedQuery) -> Double {
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
