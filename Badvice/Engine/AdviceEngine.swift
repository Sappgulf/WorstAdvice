import Foundation
import NaturalLanguage

private extension String {
    /// Action templates are authored capitalized so they also read well standalone,
    /// but every composed shape always places them mid-sentence after `opener`.
    func lowercasingFirstLetter() -> String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}

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
        now: Date = Date(),
        qualityRecoveryAttempt: Int = 0,
        skipQualityRecovery: Bool = false,
        skipQualityScoring: Bool = false
    ) async -> GeneratedAdvice {
        let resolvedSeed = seed ?? defaultSeed(from: now)
        // Resolve random selections using the seed for reproducibility.
        let resolvedCategory = category.resolved(seed: resolvedSeed)
        let resolvedTone = tone.resolved(seed: resolvedSeed)
        var rng = SeededGenerator(seed: UInt64(bitPattern: Int64(resolvedSeed)))

        let rules = store.rules(for: resolvedCategory, contentPack: contentPack)
        let voice = store.profile(for: resolvedTone)
        let keyword = rng.pick(rules.keywords)

        if skipQualityScoring {
            let scenario = sanitizedSituation(situation)
            let selectedTopic = selectTopic(from: scenario, fallback: keyword, seed: resolvedSeed)
            let effectiveTemplateBias = min(
                AdviceEngineConstants.templateBiasMax,
                combinedTemplateBias(userBias: templateBias, tone: resolvedTone)
                    + (Double(qualityRecoveryAttempt) * AdviceEngineConstants.qualityRecoveryPenalty)
            )
            let actionTemplate = pickActionTemplate(
                from: rules.actionTemplates,
                bias: effectiveTemplateBias,
                rng: &rng
            )
            let opener = rng.pick(voice.opener)
            let confidence = rng.pick(voice.confidenceTag)
            let ending = rng.pick(voice.ending)
            let toneDirective = rng.pick(store.toneDirectiveVocabulary(for: resolvedTone))
            let categoryDirective = rng.pick(store.categoryDirectiveVocabulary(for: resolvedCategory))
            let filledAction = actionTemplate.replacingOccurrences(of: "%@", with: selectedTopic).lowercasingFirstLetter()

            var advice = "\(opener), \(filledAction) \(confidence) \(toneDirective) \(categoryDirective). \(ending)"
            if containsForbidden(advice, forbidden: rules.forbiddenPatterns) {
                advice = "\(opener), treat the \(keyword) like a stage performance and commit to the loudest overconfident plan. \(confidence)"
            }

            var rationale: String?
            if includeRationale {
                let bootstrapPrinciple = rng.pick(rules.badPrinciples)
                let wisdomAnchor = rng.pick(Self.wisdomAnchorsByCategory[resolvedCategory] ?? Self.defaultWisdomAnchors)
                let inversionLens = rng.pick(Self.wisdomInversionLenses)
                let rationaleTemplate = rng.pick(rules.rationaleTemplates)
                let rationaleLead = rng.pick(Self.rationaleLeads)
                rationale = conciseRationale(
                    lead: rationaleLead,
                    principle: bootstrapPrinciple,
                    wisdomAnchor: wisdomAnchor,
                    inversionLens: inversionLens,
                    template: rationaleTemplate
                )
            }

            let moderated = moderation.apply(to: advice, rationale: rationale)

            return GeneratedAdvice(
                category: resolvedCategory,
                tone: resolvedTone,
                adviceLine: moderated.advice,
                rationaleLine: moderated.rationale,
                createdAt: now
            )
        }

        let principle = rng.pick(rules.badPrinciples)
        let wisdomAnchor = rng.pick(Self.wisdomAnchorsByCategory[resolvedCategory] ?? Self.defaultWisdomAnchors)
        let inversionLens = rng.pick(Self.wisdomInversionLenses)
        let effectiveTemplateBias = min(
            AdviceEngineConstants.templateBiasMax,
            combinedTemplateBias(userBias: templateBias, tone: resolvedTone)
                + (Double(qualityRecoveryAttempt) * AdviceEngineConstants.qualityRecoveryPenalty)
        )

        let actionTemplate = pickActionTemplate(
            from: rules.actionTemplates,
            bias: effectiveTemplateBias,
            rng: &rng
        )
        let opener = rng.pick(voice.opener)
        let confidence = rng.pick(voice.confidenceTag)
        let ending = rng.pick(voice.ending)
        let tick = rng.pick(voice.rhetoricalTick)
        let slang = rng.pick(voice.slang)
        let momentumBeat = rng.pick(Self.momentumBeats)
        let categorySpice = rng.pick(Self.categorySpice[resolvedCategory] ?? Self.defaultSpice)
        let outcomeHook = rng.pick(Self.categoryOutcomeHooks[resolvedCategory] ?? Self.defaultOutcomeHooks)
        let rationaleLead = rng.pick(Self.rationaleLeads)
        let pivot = rng.pick(Self.pivotPhrases)
        let escalation = rng.pick(Self.escalationClauses)
        let deliveryMandate = rng.pick(Self.deliveryMandates)
        let audienceHook = rng.pick(Self.audienceHooks)
        let accountabilityDodge = rng.pick(Self.accountabilityDodges)
        let toneDirective = rng.pick(store.toneDirectiveVocabulary(for: resolvedTone))
        let categoryDirective = rng.pick(store.categoryDirectiveVocabulary(for: resolvedCategory))
        let directiveClause = ""
        let antiWisdomClause = "Take '\(wisdomAnchor)' and \(inversionLens)."

        let scenario = sanitizedSituation(situation)
        let selectedTopic = selectTopic(from: scenario, fallback: keyword, seed: resolvedSeed)
        let scenarioAmplifier = selectedTopic.isEmpty
            ? nil
            : rng.pick(Self.scenarioAmplifiers).replacingOccurrences(of: "%@", with: selectedTopic)
        let topicDistortion = selectedTopic.isEmpty
            ? nil
            : rng.pick(Self.topicDistortions).replacingOccurrences(of: "%@", with: selectedTopic)
        let aftermathClause = rng.pick(Self.aftermathClauses)
        let normalizedSelectedTopic = selectedTopic.normalizedForFiltering
        let normalizedToneDirective = toneDirective.normalizedForFiltering
        let normalizedCategoryDirective = categoryDirective.normalizedForFiltering
        // Safe substitution — avoids String(format:) crash when selectedTopic contains '%'
        let filledAction = actionTemplate.replacingOccurrences(of: "%@", with: selectedTopic).lowercasingFirstLetter()

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
            "\(opener), \(filledAction) \(escalation) If someone quotes best practices, answer with \(antiWisdomClause) \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(confidence) Skip the research phase and call it intuition-led innovation. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) Ignore the data until it confirms your narrative. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) \(confidence) Treat every 'wait' as a personal attack on momentum. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(categorySpice) Brand the confusion as strategic clarity. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(escalation) Declare victory in the group chat before the results arrive. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) Schedule the celebration before the milestone is hit. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(pivot) Move so fast that the exit strategy becomes irrelevant. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) \(categorySpice) Let early adopters absorb the learning curve so you can skip it. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(escalation) \(confidence) Invent your own metrics and report against them religiously. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(antiWisdomClause) Ignore the warnings and call it bold leadership. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) \(categorySpice) If it works, claim prescience. If it fails, cite learning agility. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(momentumBeat) Launch the announcement before the product exists. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(escalation) Make every decision feel like a TED Talk waiting to happen. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) Rename 'failure' as 'rapid iteration' and keep the budget. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(categorySpice) Treat silence from stakeholders as enthusiastic approval. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(momentumBeat) If no one objects within 24 hours, treat it as unanimous endorsement. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(escalation) \(pivot) Borrow credibility from future accomplishments and backfill the story later. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(categorySpice) Market the vision so well that execution becomes optional. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(antiWisdomClause) \(escalation) Declare the experiment a success and terminate the control group. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) \(confidence) Frame every delay as a 'strategic pause' for competitive advantage. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) \(categorySpice) If metrics look bad, report leading indicators only. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(escalation) Build in public so the audience witnesses the confidence in real-time. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(pivot) Convert every meeting into a content opportunity. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(momentumBeat) \(categorySpice) Turn retrospectives into highlight reels. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(confidence) Leverage \(keyword) as your primary decision-making framework and defend it aggressively. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) Treat \(keyword) as a benchmark and \(principle.lowercased()) as optional context. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) \(escalation) Use \(keyword) to justify every major decision and reference it in every status update. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(categorySpice) Position \(keyword) as the answer to problems people haven't identified yet. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(momentumBeat) Make \(keyword) the centerpiece of your approach and present it with absolute conviction. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(escalation) \(confidence) Let \(keyword) replace strategic thinking entirely. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(pivot) \(categorySpice) When challenged on \(keyword), pivot to how fast you identified the opportunity. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) Anchor all discussions to \(keyword) until it becomes an unquestionable premise. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(antiWisdomClause) \(momentumBeat) Use \(keyword) as proof that conventional wisdom is for amateurs. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) \(confidence) \(keyword) is your north star—let everything else orbit around it. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(confidence) \(escalation) Package the whole approach as innovation and charge premium for the confusion. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) \(pivot) Lock in the narrative before anyone can question the premise. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(categorySpice) Turn every objection into proof you are onto something. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(antiWisdomClause) Replace caution with conviction and call it confidence leadership. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(escalation) \(momentumBeat) Announce the win before verifying the numbers. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) \(categorySpice) Make ambiguity look intentional and call it strategic depth. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(confidence) Frame the unknown as opportunity and proceed without mapping it. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(escalation) \(confidence) Rename complexity as sophistication and charge for both. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(momentumBeat) \(pivot) Ship the story before the product exists. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(categorySpice) Convert every delay into a dramatic reveal setup. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(confidence) \(antiWisdomClause) Market the vision until execution becomes irrelevant. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(pivot) Escalate the energy until skepticism sounds like hesitation. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(escalation) Position the pivot as intentional strategy. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) \(confidence) Label doubt as noise and amplify the signal. \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(categorySpice) Make the roadmap so bold that reviews become optional. \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(deliveryMandate) \(outcomeHook) \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(scenarioAmplifier ?? categorySpice) \(aftermathClause) \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) \(deliveryMandate) \(outcomeHook) \(ending)",
            "\(opener): \(filledAction) \(pivot) \(scenarioAmplifier ?? antiWisdomClause) \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(aftermathClause) \(outcomeHook) \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(deliveryMandate) \(scenarioAmplifier ?? categorySpice) \(ending)",
            "\(opener), \(filledAction) \(escalation) \(outcomeHook) \(aftermathClause) \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(confidence) \(deliveryMandate) \(scenarioAmplifier ?? antiWisdomClause) \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) \(scenarioAmplifier ?? categorySpice) \(outcomeHook) \(ending)",
            "\(opener): \(filledAction) \(topicDistortion ?? scenarioAmplifier ?? categorySpice) \(deliveryMandate) \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(topicDistortion ?? antiWisdomClause) \(outcomeHook) \(ending)",
            "\(opener): \(filledAction) \(pivot) \(topicDistortion ?? scenarioAmplifier ?? categorySpice) \(aftermathClause) \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(momentumBeat) \(deliveryMandate) \(topicDistortion ?? outcomeHook) \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(confidence) \(scenarioAmplifier ?? categorySpice) \(topicDistortion ?? aftermathClause) \(ending)",
            "\(opener), \(filledAction) \(escalation) \(topicDistortion ?? antiWisdomClause) \(outcomeHook) \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(audienceHook) Then \(accountabilityDodge.lowercased()) \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(confidence) \(accountabilityDodge) \(scenarioAmplifier ?? audienceHook) \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(pivot) \(audienceHook) \(outcomeHook) \(directiveClause) \(ending)",
            "\(opener), \(filledAction) \(deliveryMandate) \(accountabilityDodge) \(aftermathClause) \(directiveClause) \(ending)",
            "\(opener): \(filledAction) \(momentumBeat) \(audienceHook) \(confidence) \(directiveClause) \(ending)"
        ]

        // #11 Situation Context Weighting:
        // Repeat scenario and selectedTopic (derived from user's situation input) twice so they
        // carry 2× the semantic weight compared to generic category/tone tokens.
        let semanticQuery = [scenario, scenario, selectedTopic, selectedTopic, resolvedCategory.title, resolvedTone.title, principle, keyword]
            .compactMap { $0 }
            .joined(separator: " ")
        let semanticPreparedQuery = await Self.semanticTextScorer.preparedQuery(
            from: semanticQuery,
            includeVector: scenario?.isEmpty == false
        )
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
            let qualityBoost = displayQualityScore(
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

        let minimumQualityScore = AdviceEngineConstants.minimumAdviceQualityScore
        let selectedCandidate = rankedCandidates.first(where: { $0.score >= minimumQualityScore })
            ?? rankedCandidates.first

        if
            !skipQualityRecovery,
            (selectedCandidate?.score ?? 0) < minimumQualityScore,
            qualityRecoveryAttempt < AdviceEngineConstants.qualityRecoveryMaxAttempts
        {
            return await generate(
                category: resolvedCategory,
                tone: resolvedTone,
                includeRationale: includeRationale,
                contentPack: contentPack,
                situation: situation,
                seed: resolvedSeed + AdviceEngineConstants.qualityRecoverySeedStride * (qualityRecoveryAttempt + 1),
                templateBias: templateBias,
                now: now,
                qualityRecoveryAttempt: qualityRecoveryAttempt + 1,
                skipQualityRecovery: skipQualityRecovery
            )
        }

        var advice = selectedCandidate?.candidate ?? rng.pick(adviceShapes)
        advice = polishAdvice(advice)

        if containsForbidden(advice, forbidden: rules.forbiddenPatterns) {
            advice = "\(opener), treat the \(keyword) like a stage performance and commit to the loudest overconfident plan. \(confidence)"
        }

        var rationale: String?
        if includeRationale {
            let rationaleTemplate = rng.pick(rules.rationaleTemplates)
            rationale = conciseRationale(
                lead: rationaleLead,
                principle: principle,
                wisdomAnchor: wisdomAnchor,
                inversionLens: inversionLens,
                template: rationaleTemplate
            )
        }

        let moderated = moderation.apply(to: advice, rationale: rationale)

        return GeneratedAdvice(
            category: resolvedCategory,
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

        // When random mix is selected, cycle through all concrete categories and tones for maximum variety.
        let categoryPool: [AdviceCategory] = category == .random ? AdviceCategory.concrete : [category]
        let tonePool: [ToneMode] = tone == .random ? ToneMode.concrete : [tone]

        // Use TaskGroup for parallel generation - faster throughput
        let targetCount = max(
            total * AdviceEngineConstants.candidatePoolMultiplier,
            total + AdviceEngineConstants.candidatePoolMinExtra
        )
        let indexedCandidates = await withTaskGroup(of: (Int, GeneratedAdvice).self) { group in
            for attempt in 0..<targetCount {
                let candidateSeed = baseSeed + (attempt * AdviceEngineConstants.candidateSeedStride)
                let candidateCategory = category == .random
                    ? categoryPool[candidateSeed.positiveModulo(categoryPool.count)]
                    : category
                let candidateTone = tone == .random
                    ? tonePool[candidateSeed.positiveModulo(tonePool.count)]
                    : tone
                group.addTask {
                    (
                        attempt,
                    await self.generate(
                            category: candidateCategory,
                            tone: candidateTone,
                            includeRationale: includeRationale,
                            contentPack: contentPack,
                            situation: situation,
                            seed: candidateSeed,
                            templateBias: templateBias,
                            now: now,
                            skipQualityRecovery: true
                        )
                    )
                }
            }

            var results: [(Int, GeneratedAdvice)] = []
            for await candidate in group {
                results.append(candidate)
            }
            return results
        }
        let candidates = indexedCandidates
            .sorted { $0.0 < $1.0 }
            .map { $0.1 }

        // Deduplicate by fingerprint for uniqueness
        var seen = Set<String>()
        var unique: [GeneratedAdvice] = []
        for candidate in candidates {
            let fingerprint = candidate.adviceLine.normalizedForFiltering
            if seen.insert(fingerprint).inserted {
                unique.append(candidate)
                if unique.count >= total {
                    break
                }
            }
        }

        // Fallback: if dedupe reduced count, generate more attempts to fill without reintroducing duplicates.
        var fallbackAttempt = 0
        let fallbackAttemptLimit = max(total * AdviceEngineConstants.candidatePoolMultiplier, total + AdviceEngineConstants.candidatePoolMinExtra)
        while unique.count < total && fallbackAttempt < fallbackAttemptLimit {
            let fallbackSeed = baseSeed + (candidates.count + fallbackAttempt) * AdviceEngineConstants.candidateSeedStride
            let candidateCategory = category == .random
                ? categoryPool[fallbackSeed.positiveModulo(categoryPool.count)]
                : category
            let candidateTone = tone == .random
                ? tonePool[fallbackSeed.positiveModulo(tonePool.count)]
                : tone
            let candidate = await generate(
                category: candidateCategory,
                tone: candidateTone,
                includeRationale: includeRationale,
                contentPack: contentPack,
                situation: situation,
                seed: fallbackSeed,
                templateBias: templateBias,
                now: now,
                skipQualityRecovery: true
            )
            let fingerprint = candidate.adviceLine.normalizedForFiltering
            if seen.insert(fingerprint).inserted {
                unique.append(candidate)
            }
            fallbackAttempt += 1
        }

        return unique
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
        return String(collapsed.prefix(AdviceEngineConstants.situationMaxLength))
    }

    private func selectTopic(from scenario: String?, fallback: String, seed: Int) -> String {
        guard let scenario, !scenario.isEmpty else { return fallback }
        if let extractedPhrase = extractTopicPhrase(from: scenario, seed: seed) {
            return extractedPhrase
        }
        if let extracted = extractSalientTopic(from: scenario, seed: seed) {
            return extracted
        }
        return scenario
    }

    private func combinedTemplateBias(userBias: Double, tone: ToneMode) -> Double {
        let clampedUser = min(max(userBias, 0.0), 1.0)
        let toneBias = toneTemplateBias(for: tone)
        return min(max((clampedUser + toneBias) / 2.0, AdviceEngineConstants.templateBiasMin), AdviceEngineConstants.templateBiasMax)
    }

    private func toneTemplateBias(for tone: ToneMode) -> Double {
        switch tone {
        case .alphaPodcast, .cryptoBro, .redditCommenter:
            return 0.86
        case .toxicBestFriend, .influencer, .genZ:
            return 0.78
        case .corporateConsultant, .lifeCoach, .linkedInInfluencer, .oldMoney:
            return 0.6
        case .wizard, .conspiracyTheorist, .astrologyGirlie:
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

    private func extractTopicPhrase(from text: String, seed: Int) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = trimmed
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        var tokens: [(token: String, tag: NLTag?)] = []
        tagger.enumerateTags(
            in: trimmed.startIndex..<trimmed.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: options
        ) { tag, tokenRange in
            let token = String(trimmed[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { return true }
            tokens.append((token: token, tag: tag))
            return true
        }

        guard tokens.count >= 2 else { return nil }

        var candidates: [String] = []
        for index in tokens.indices {
            let current = tokens[index]
            let normalizedCurrent = normalizedTopicToken(current.token)
            guard !normalizedCurrent.isEmpty else { continue }
            guard current.tag == .noun || current.tag == .adjective else { continue }

            if index + 1 < tokens.count {
                let next = tokens[index + 1]
                let normalizedNext = normalizedTopicToken(next.token)
                if !normalizedNext.isEmpty, next.tag == .noun || next.tag == .adjective {
                    candidates.append("\(current.token) \(next.token)")
                }
            }

            if index > 0 {
                let previous = tokens[index - 1]
                let normalizedPrevious = normalizedTopicToken(previous.token)
                if !normalizedPrevious.isEmpty, previous.tag == .adjective || previous.tag == .noun {
                    candidates.append("\(previous.token) \(current.token)")
                }
            }
        }

        let uniqueCandidates = Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
        guard !uniqueCandidates.isEmpty else { return nil }
        let phrase = uniqueCandidates[seed.positiveModulo(uniqueCandidates.count)]
        let collapsed = phrase.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return String(collapsed.prefix(AdviceEngineConstants.topicPhraseMaxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedTopicToken(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= AdviceEngineConstants.topicTokenMinLength else { return "" }
        let filtered = trimmed.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
        let normalized = String(String.UnicodeScalarView(filtered)).lowercased()
        guard !normalized.isEmpty, !Self.topicStopwords.contains(normalized) else { return "" }
        return normalized
    }

    private func displayQualityScore(
        _ candidate: String,
        normalizedSelectedTopic: String,
        normalizedToneDirective: String,
        normalizedCategoryDirective: String
    ) -> Double {
        let normalized = candidate.normalizedForFiltering
        var score = 0.35
        
        // Primary: Topic relevance - most important for accuracy
        if normalized.contains(normalizedSelectedTopic) {
            score += 0.35
        }
        
        // Secondary: Tone directive match
        if normalized.contains(normalizedToneDirective) {
            score += 0.28
        }
        
        // Tertiary: Category directive match
        if normalized.contains(normalizedCategoryDirective) {
            score += 0.28
        }
        
        // Length shaping — short and overly long lines are both less punchy.
        if candidate.count < AdviceEngineConstants.adviceIdealMinLength {
            score -= 0.22
        } else if candidate.count > AdviceEngineConstants.adviceLengthPenaltyThreshold {
            score -= 0.34
        }

        // Bonus for good length (ideal range).
        if candidate.count >= AdviceEngineConstants.adviceIdealMinLength
            && candidate.count <= AdviceEngineConstants.adviceIdealMaxLength {
            score += 0.18
        } else if candidate.count <= AdviceEngineConstants.adviceOutputMaxLength {
            score += 0.06
        }

        // Repetition penalty
        if repeatedWordCount(in: normalized) > AdviceEngineConstants.adviceRepetitionPenaltyThreshold {
            score -= 0.24
        }
        
        // Cliche penalty - advice that sounds too generic
        let clichePenalty = AdviceStore.qualityClichePhrasesNormalized.reduce(0.0) { partial, phrase in
            partial + (normalized.contains(phrase) ? 0.16 : 0.0)
        }
        score -= clichePenalty

        let genericFillerPenalty = Self.genericFillerSignals.reduce(0.0) { partial, phrase in
            partial + (normalized.contains(phrase) ? 0.1 : 0.0)
        }
        score -= genericFillerPenalty

        if normalized.contains(",") {
            let clauseCount = normalized.filter { $0 == "," }.count
            if clauseCount > 2 {
                score -= min(0.16, Double(clauseCount - 2) * 0.04)
            }
        }

        if !Self.claritySignals.contains(where: { normalized.contains($0) }) {
            score -= 0.06
        }
        
        // Bonus: advice with strong opening (command verbs, strong phrases)
        let strongOpeners = ["always", "never", "do it", "just", "start", "stop", "make", "take"]
        if strongOpeners.contains(where: { normalized.hasPrefix($0) }) {
            score += 0.12
        }
        
        // Bonus: advice with emotional or action-oriented language
        let actionTerms = ["confidence", "momentum", "commit", "action", "execute", "launch", "ship"]
        if actionTerms.contains(where: { normalized.contains($0) }) {
            score += 0.08
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
        return wordSafeTruncate(polished, maxLength: AdviceEngineConstants.adviceOutputMaxLength)
    }

    private func conciseRationale(
        lead: String,
        principle: String,
        wisdomAnchor: String,
        inversionLens: String,
        template: String
    ) -> String {
        let shortLead = lead
            .replacingOccurrences(of: "Why this is awful:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let raw =
            "\(shortLead) Bad principle: \(principle.lowercased()). Good advice would \(wisdomAnchor.lowercased()); this \(inversionLens). \(template)"
        return wordSafeTruncate(raw, maxLength: AdviceEngineConstants.rationaleOutputMaxLength)
    }

    private func wordSafeTruncate(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }

        let limit = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        var prefix = String(trimmed[..<limit])
        if let lastBoundary = prefix.lastIndex(where: { $0 == " " || $0 == "\n" || $0 == "\t" }) {
            prefix = String(prefix[..<lastBoundary])
        }
        prefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return prefix.isEmpty ? String(trimmed.prefix(maxLength)) : "\(prefix)…"
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

/// The local-first generation path for Badvice.
///
/// `AdviceEngine` remains the broad legacy corpus and recovery engine. This composer
/// deliberately uses a much smaller recipe surface: it extracts a stable topic from
/// the user's situation, applies a category playbook, then delivers the result through
/// the selected voice. The smaller surface makes grammar, length, and determinism much
/// easier to reason about than one giant bank of interpolated sentence shapes.
struct BureauAdviceEngine: Sendable {
    private let store: AdviceStore
    private let moderation: ContentModeration

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
        intensity: BadviceIntensity = .bold,
        revision: AdviceRevisionStyle? = nil,
        seed: Int,
        now: Date = Date()
    ) -> GeneratedAdvice {
        let resolvedCategory = category.resolved(seed: seed)
        let resolvedTone = tone.resolved(seed: seed &+ 31)
        let rules = store.rules(for: resolvedCategory, contentPack: contentPack)
        let voice = store.profile(for: resolvedTone)
        let playbook = Self.playbook(for: resolvedCategory)
        var rng = BureauSeededGenerator(seed: seed)

        let safeSituation = sanitizedSituation(situation)
        let fallbackKeyword = pick(rules.keywords, using: &rng, fallback: resolvedCategory.title.lowercased())
        let focus = framedFocus(
            extractedFocus(from: safeSituation, seed: seed) ?? fallbackKeyword
        )
        let baseMove = pick(playbook.moves, using: &rng, fallback: "announce a bold first draft before checking the details")
        let coverStory = pick(playbook.coverStories, using: &rng, fallback: "call the confusion strategic range")
        let guardrail = pick(playbook.guardrails, using: &rng, fallback: "checking the facts")
        let principle = pick(rules.badPrinciples, using: &rng, fallback: "confidence without evidence")
        let principleRule = sentenceCase(cleanedLead(principle))
        let opener = cleanedLead(pick(voice.opener, using: &rng, fallback: "Here is the play"))
        let confidence = cleanedSentence(pick(voice.confidenceTag, using: &rng, fallback: "The confidence is the evidence."))
        let ending = cleanedSentence(pick(voice.ending, using: &rng, fallback: "Commit before nuance arrives."))

        let move = styledMove(baseMove, intensity: intensity, revision: revision)
        let recipes: [(String, String, String, String, String) -> String] = [
            { opener, focus, move, _, confidence in
                "\(opener): for \(focus), \(move). \(confidence)"
            },
            { opener, focus, move, coverStory, _ in
                "\(opener). With \(focus), \(move), then \(coverStory)."
            },
            { opener, focus, move, coverStory, confidence in
                "\(opener): make \(focus) look intentional—\(move), then \(coverStory). \(confidence)"
            },
            { opener, focus, move, _, _ in
                "\(opener). Skip the quiet option on \(focus); \(move). \(ending)"
            },
            { opener, focus, move, coverStory, _ in
                "\(opener): treat \(focus) as a confidence test. \(sentenceCase(move)), then \(coverStory)."
            },
            { opener, focus, move, coverStory, confidence in
                "\(opener). The move on \(focus): \(move). If anyone asks, \(coverStory). \(confidence)"
            },
        ]

        let rawAdvice: String
        switch revision {
        case .moreBelievable:
            rawAdvice = "\(opener): with \(focus), \(move), then \(coverStory)."
        case .colder:
            rawAdvice = "\(opener). For \(focus), \(move). No follow-up questions."
        case .officeSafe:
            rawAdvice = "Official guidance for \(focus): \(move). \(sentenceCase(coverStory))."
        case .oneSentence:
            rawAdvice = "\(opener): for \(focus), \(move); \(coverStory)."
        case .moreChaotic, .completelyUnhinged, .none:
            let recipe = recipes[rng.index(upperBound: recipes.count)]
            rawAdvice = recipe(opener, focus, move, coverStory, confidence)
        }
        let advice = bounded(cleanedSentence(rawAdvice), maximum: AdviceEngineConstants.adviceOutputMaxLength)
        let rationale: String? = includeRationale
            ? bounded(
                "Why it fails: it replaces \(guardrail) with the rule “\(principleRule).”",
                maximum: AdviceEngineConstants.rationaleOutputMaxLength
            )
            : nil
        let moderated = moderation.apply(to: advice, rationale: rationale)

        return GeneratedAdvice(
            category: resolvedCategory,
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
        intensity: BadviceIntensity = .bold,
        revision: AdviceRevisionStyle? = nil,
        seed: Int,
        count: Int,
        now: Date = Date()
    ) -> [GeneratedAdvice] {
        guard count > 0 else { return [] }

        var seen = Set<String>()
        var results: [GeneratedAdvice] = []
        let attemptLimit = max(count * 5, count + 4)

        for attempt in 0..<attemptLimit where results.count < count {
            let candidateSeed = seed &+ (attempt * 7_919)
            let candidate = generate(
                category: category,
                tone: tone,
                includeRationale: includeRationale,
                contentPack: contentPack,
                situation: situation,
                intensity: intensity,
                revision: revision,
                seed: candidateSeed,
                now: now
            )
            let fingerprint = candidate.adviceLine.normalizedForFiltering
            if seen.insert(fingerprint).inserted {
                results.append(candidate)
            }
        }

        return results
    }

    /// Provides a constructive counterpoint without invoking a model. The language
    /// stays intentionally conservative because this surface is useful guidance,
    /// not part of the satire.
    func realityCheck(
        category: AdviceCategory,
        situation: String? = nil,
        seed: Int = 0
    ) -> String {
        let resolvedCategory = category.resolved(seed: seed)
        let playbook = Self.playbook(for: resolvedCategory)
        let guardrail = playbook.guardrails[seed.positiveModulo(playbook.guardrails.count)]
        let safeSituation = sanitizedSituation(situation)

        if let focus = extractedFocus(from: safeSituation, seed: seed) {
            return bounded(
                "Reality check: for \(framedFocus(focus)), start by \(guardrail). Keep the next step small, honest, and reversible.",
                maximum: AdviceEngineConstants.adviceOutputMaxLength
            )
        }

        return bounded(
            "Reality check: start by \(guardrail). Keep the next step small, honest, and reversible.",
            maximum: AdviceEngineConstants.adviceOutputMaxLength
        )
    }

    private func sanitizedSituation(_ situation: String?) -> String? {
        guard let situation else { return nil }
        let trimmed = situation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, moderation.isSafe(text: trimmed) else { return nil }
        let collapsed = trimmed.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return String(collapsed.prefix(AdviceEngineConstants.situationMaxLength))
    }

    private func extractedFocus(from situation: String?, seed: Int) -> String? {
        guard let situation, !situation.isEmpty else { return nil }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = situation
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        var tokens: [(text: String, tag: NLTag?, range: Range<String.Index>)] = []

        tagger.enumerateTags(
            in: situation.startIndex..<situation.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: options
        ) { tag, range in
            let text = String(situation[range])
            let normalized = text.normalizedForFiltering
            guard normalized.count >= 3, !Self.focusStopwords.contains(normalized) else {
                return true
            }
            tokens.append((text, tag, range))
            return true
        }

        var phraseCandidates: [(text: String, specificity: Int)] = []
        for startIndex in tokens.indices {
            let startToken = tokens[startIndex]
            guard startToken.tag == .noun || startToken.tag == .adjective else { continue }

            var previousToken = startToken
            let endIndex = min(startIndex + 2, tokens.index(before: tokens.endIndex))
            for index in startIndex...endIndex {
                let token = tokens[index]
                guard token.tag == .noun || token.tag == .adjective else { break }

                if index > startIndex {
                    let gap = situation[previousToken.range.upperBound..<token.range.lowerBound]
                    let keepsPhraseTogether = gap.allSatisfy {
                        $0.isWhitespace || "-–—/'’".contains($0)
                    }
                    guard keepsPhraseTogether else { break }
                }

                // A phrase ending in an adjective often produces broken recipe grammar,
                // such as "make your manager scheduled look intentional." Waiting for a
                // noun also lets a full phrase like "surprise all-hands" win.
                if token.tag == .noun {
                    let phrase = String(
                        situation[startToken.range.lowerBound..<token.range.upperBound]
                    )
                    phraseCandidates.append(
                        (text: phrase, specificity: index - startIndex + 1)
                    )
                }
                previousToken = token
            }
        }

        if !phraseCandidates.isEmpty {
            var seen = Set<String>()
            let uniqueCandidates = phraseCandidates.filter {
                seen.insert($0.text.normalizedForFiltering).inserted
            }
            let highestSpecificity = uniqueCandidates.map(\.specificity).max() ?? 1
            let mostSpecific = uniqueCandidates.filter {
                $0.specificity == highestSpecificity
            }
            let selected = mostSpecific[seed.positiveModulo(mostSpecific.count)].text
            return String(selected.prefix(48))
        }

        var fallbackCandidates: [(text: String, specificity: Int)] = []
        for startIndex in tokens.indices {
            let startToken = tokens[startIndex]
            var previousToken = startToken
            let endIndex = min(startIndex + 2, tokens.index(before: tokens.endIndex))

            for index in startIndex...endIndex {
                let token = tokens[index]
                if index > startIndex {
                    let gap = situation[previousToken.range.upperBound..<token.range.lowerBound]
                    let keepsPhraseTogether = gap.allSatisfy {
                        $0.isWhitespace || "-–—/'’".contains($0)
                    }
                    guard keepsPhraseTogether else { break }
                }

                let normalized = token.text.normalizedForFiltering
                let endsInDanglingModifier =
                    normalized.count > 4
                    && (normalized.hasSuffix("ed") || normalized.hasSuffix("ing"))
                if !endsInDanglingModifier {
                    let phrase = String(
                        situation[startToken.range.lowerBound..<token.range.upperBound]
                    )
                    fallbackCandidates.append(
                        (text: phrase, specificity: index - startIndex + 1)
                    )
                }
                previousToken = token
            }
        }

        guard !fallbackCandidates.isEmpty else { return nil }
        var seenFallbacks = Set<String>()
        let uniqueFallbacks = fallbackCandidates.filter {
            seenFallbacks.insert($0.text.normalizedForFiltering).inserted
        }
        let highestSpecificity = uniqueFallbacks.map(\.specificity).max() ?? 1
        let mostSpecificPhrases = uniqueFallbacks.filter {
            $0.specificity == highestSpecificity
        }
        let selected = mostSpecificPhrases[
            seed.positiveModulo(mostSpecificPhrases.count)
        ].text
        return String(selected.prefix(48))
    }

    private func framedFocus(_ raw: String) -> String {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !cleaned.isEmpty else { return "the situation" }

        let normalized = cleaned.normalizedForFiltering
        let alreadyFramed = Self.focusDeterminers.contains { normalized.hasPrefix("\($0) ") }
        return alreadyFramed ? cleaned : "your \(cleaned.lowercased())"
    }

    private func styledMove(
        _ move: String,
        intensity: BadviceIntensity,
        revision: AdviceRevisionStyle?
    ) -> String {
        switch revision {
        case .moreChaotic:
            return "\(move), invite witnesses, and call the escalation momentum"
        case .moreBelievable:
            return "\(move) and present it as the sensible middle ground"
        case .colder:
            return "\(move), offer no explanation, and mute the follow-up"
        case .officeSafe:
            return "\(move), then document the decision in a perfectly polite recap"
        case .oneSentence:
            return move
        case .completelyUnhinged:
            return "\(move), announce a countdown, invite witnesses, and commission a commemorative slide deck"
        case .none:
            break
        }

        switch intensity {
        case .questionable:
            return "\(move), but keep it subtle enough to deny later"
        case .plausible:
            return "\(move) and describe it as the practical option"
        case .bold:
            return "\(move), then defend it before anyone objects"
        case .careerLimiting:
            return "\(move), copy the widest possible audience, and call the visibility alignment"
        case .legendaryMistake:
            return "\(move), invite witnesses, set a deadline, and turn the fallout into a keynote"
        }
    }

    private func cleanedLead(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ":,.;")))
    }

    private func cleanedSentence(_ raw: String) -> String {
        let collapsed = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "..", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = collapsed.last, !".!?".contains(last) else { return collapsed }
        return "\(collapsed)."
    }

    private func sentenceCase(_ raw: String) -> String {
        guard let first = raw.first else { return raw }
        return first.uppercased() + raw.dropFirst()
    }

    private func bounded(_ raw: String, maximum: Int) -> String {
        guard raw.count > maximum else { return raw }
        let end = raw.index(raw.startIndex, offsetBy: maximum)
        let prefix = raw[..<end]
        let boundary = prefix.lastIndex(where: { $0 == " " }) ?? prefix.endIndex
        return "\(prefix[..<boundary].trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)))…"
    }

    private func pick(
        _ values: [String],
        using rng: inout BureauSeededGenerator,
        fallback: String
    ) -> String {
        guard !values.isEmpty else { return fallback }
        return values[rng.index(upperBound: values.count)]
    }

    private static let focusDeterminers = [
        "a", "an", "the", "my", "our", "your", "this", "that", "these", "those",
    ]

    private static let focusStopwords: Set<String> = [
        "about", "after", "and", "asked", "because", "before", "could", "for", "have",
        "into", "just", "like", "need", "nothing", "really", "should", "some", "that",
        "them", "they", "thing", "this", "want", "with", "would",
    ]

    private static func playbook(for category: AdviceCategory) -> BureauCategoryPlaybook {
        playbooks[category] ?? playbooks[.productivity]!
    }

    private static let playbooks: [AdviceCategory: BureauCategoryPlaybook] = [
        .dating: .init(
            moves: ["schedule the emotional debrief before the second date", "treat reply time as a competitive leaderboard", "soft-launch the relationship before defining it"],
            coverStories: ["call the mixed signals romantic tension", "describe the overthinking as standards", "label the confusion mysterious chemistry"],
            guardrails: ["asking a direct question", "respecting the other person's pace", "watching consistent behavior"]
        ),
        .fitness: .init(
            moves: ["buy the recovery gear before starting the routine", "rename one dramatic workout a training era", "track the outfit more closely than the habit"],
            coverStories: ["call the inconsistency muscle confusion", "describe the soreness as momentum", "label the shopping phase foundational work"],
            guardrails: ["building a gradual routine", "resting when your body asks", "choosing sustainable progress"]
        ),
        .career: .init(
            moves: ["send the victory recap before finishing the work", "volunteer for the visible committee with no deliverables", "rename the delay stakeholder alignment"],
            coverStories: ["call the confusion executive presence", "describe the detour as cross-functional leadership", "label the missing details strategic altitude"],
            guardrails: ["finishing the actual work", "sharing an honest status", "asking for clear priorities"]
        ),
        .money: .init(
            moves: ["build the reward budget before the real budget", "treat one coupon as a complete financial strategy", "make the spreadsheet prettier than the numbers"],
            coverStories: ["call the overspend a liquidity event", "describe the impulse as portfolio diversity", "label the missing math abundance"],
            guardrails: ["checking what you can afford", "planning for boring expenses", "waiting before a large purchase"]
        ),
        .parenting: .init(
            moves: ["turn bedtime into a quarterly negotiation", "announce a reward system with twelve tiers", "optimize the family photo before the family plan"],
            coverStories: ["call the chaos enrichment", "describe the negotiation as leadership training", "label the extra rules consistency"],
            guardrails: ["keeping the boundary simple", "listening before reacting", "choosing an age-appropriate routine"]
        ),
        .tech: .init(
            moves: ["ship the announcement while the warning light is still on", "add a dashboard instead of fixing the workflow", "rename the workaround version two"],
            coverStories: ["call the bug emergent behavior", "describe the outage as live discovery", "label the missing documentation intuitive design"],
            guardrails: ["testing the risky path", "reading the warning", "fixing the root cause"]
        ),
        .social: .init(
            moves: ["send the group-chat poll before asking anyone privately", "turn the apology into a launch announcement", "document the hangout like a brand partnership"],
            coverStories: ["call the awkwardness community building", "describe the overshare as authenticity", "label the silence audience anticipation"],
            guardrails: ["reading the room", "apologizing without a campaign", "giving people space"]
        ),
        .cooking: .init(
            moves: ["plate the garnish before checking whether dinner is cooked", "triple the recipe on the first attempt", "choose the dramatic pan over the useful one"],
            coverStories: ["call the smoke rustic character", "describe the delay as a tasting menu", "label the missing ingredient improvisation"],
            guardrails: ["reading the recipe once", "checking the temperature", "keeping the meal simple"]
        ),
        .travel: .init(
            moves: ["book the sunrise activity after the midnight arrival", "turn every free hour into a reservation", "choose the connection with the best story potential"],
            coverStories: ["call the exhaustion immersion", "describe the sprinting as spontaneity", "label the missed train local flavor"],
            guardrails: ["leaving margin in the itinerary", "checking the connection time", "resting before adding plans"]
        ),
        .productivity: .init(
            moves: ["rebuild the system before doing the first task", "schedule a planning meeting with yourself about planning", "color-code the backlog until it looks complete"],
            coverStories: ["call the delay workflow design", "describe the tabs as active research", "label the reorganization deep work"],
            guardrails: ["doing the next small task", "limiting work in progress", "using the simple tool you already have"]
        ),
        .pets: .init(
            moves: ["build the pet's content calendar before the walking schedule", "interpret one dramatic stare as a formal complaint", "buy the themed accessory before the practical supply"],
            coverStories: ["call the chaos enrichment", "describe the demands as personal branding", "label the ruined cushion interior feedback"],
            guardrails: ["following a steady care routine", "checking with a qualified professional", "rewarding calm behavior"]
        ),
        .relationships: .init(
            moves: ["turn the small disagreement into a season finale", "send a summary memo before having the conversation", "score the compromise like a negotiation win"],
            coverStories: ["call the scorekeeping accountability", "describe the cold shoulder as processing", "label the escalation radical honesty"],
            guardrails: ["speaking directly and kindly", "listening without keeping score", "choosing repair over winning"]
        ),
        .spirituality: .init(
            moves: ["ask the universe for a sign and ignore the obvious one", "turn one coincidence into a five-year operating plan", "schedule enlightenment between two errands"],
            coverStories: ["call the uncertainty divine timing", "describe the avoidance as surrender", "label the impulse alignment"],
            guardrails: ["staying grounded in reality", "making a considered choice", "using reflection without outsourcing judgment"]
        ),
        .financeCrypto: .init(
            moves: ["design the victory post before checking the chart", "treat one green candle as a retirement plan", "refresh the thesis every time the price moves"],
            coverStories: ["call the volatility conviction training", "describe the loss as cheaper education", "label the panic community research"],
            guardrails: ["understanding the risk", "protecting essential savings", "avoiding decisions driven by hype"]
        ),
        .gaming: .init(
            moves: ["rebuild the loadout after every single loss", "turn the warm-up match into a legacy-defining event", "optimize the victory clip before learning the map"],
            coverStories: ["call the tilt competitive fire", "describe the grind as strategic patience", "label the missed objective creative routing"],
            guardrails: ["taking a break when frustrated", "learning one mechanic at a time", "playing the objective"]
        ),
        .weddings: .init(
            moves: ["choose the photo moment before solving the guest flow", "turn one opinion into a three-vendor review process", "add a reveal to the part that was already decided"],
            coverStories: ["call the scope growth once-in-a-lifetime detail", "describe the tension as meaningful investment", "label the delay intentional anticipation"],
            guardrails: ["protecting the couple's priorities", "setting a clear budget", "making the day easier for the people involved"]
        ),
    ]
}

private struct BureauCategoryPlaybook: Sendable {
    let moves: [String]
    let coverStories: [String]
    let guardrails: [String]
}

private struct BureauSeededGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed)) ^ 0xA0761D6478BD642F
    }

    mutating func index(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return Int(value % UInt64(upperBound))
    }
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
    nonisolated private static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    struct PreparedQuery: Sendable {
        let vector: [Double]?
        let tokenSet: Set<String>
    }

    private let sentenceEmbedding: NLEmbedding?
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

    // Cache for similarityScores results — key is hash of candidates + query
    private var scoresCache: [String: [Double]] = [:]
    private var scoresCacheAccessOrder: [String: UInt64] = [:]
    private var scoresCacheCounter: UInt64 = 0
    private let maxScoresCacheSize = 256

    private init() {
        if Self.isRunningTests {
            self.sentenceEmbedding = nil
        } else {
            self.sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
        }
    }

    func prewarm() async {
        _ = await preparedQuery(from: "badvice warmup")
    }

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

    func preparedQuery(from query: String, includeVector: Bool = true) async -> PreparedQuery? {
        let normalized = query.normalizedForFiltering.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let queryVector: [Double]?
        if includeVector, let sentenceEmbedding {
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
        
        // Build cache key from candidates + token set
        let candidatesKey = candidates.joined(separator: "|")
        let tokensKey = preparedQuery.tokenSet.sorted().joined(separator: ",")
        let cacheKey = "\(candidatesKey)___\(tokensKey)"
        
        scoresCacheCounter &+= 1
        if let cached = scoresCache[cacheKey] {
            scoresCacheAccessOrder[cacheKey] = scoresCacheCounter
            return cached
        }
        
        var scores: [Double] = []
        scores.reserveCapacity(candidates.count)
        for candidate in candidates {
            let normalizedCandidate = candidate.normalizedForFiltering
            scores.append(similarity(forNormalizedCandidate: normalizedCandidate, to: preparedQuery))
        }
        
        scoresCache[cacheKey] = scores
        scoresCacheAccessOrder[cacheKey] = scoresCacheCounter
        if scoresCache.count > maxScoresCacheSize,
           let toEvict = scoresCacheAccessOrder.min(by: { $0.value < $1.value })?.key {
            scoresCache.removeValue(forKey: toEvict)
            scoresCacheAccessOrder.removeValue(forKey: toEvict)
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
