import Combine
import Foundation
import OSLog

#if canImport(CoreML)
    import CoreML
#endif

#if canImport(FoundationModels)
    import FoundationModels
#endif

enum AppleOnDeviceModelAvailability: Equatable, Sendable {
    case ready
    case unavailable(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var statusText: String {
        switch self {
        case .ready:
            return "Apple on-device model is ready."
        case .unavailable(let reason):
            return reason
        }
    }

    var analyticsKey: String {
        switch self {
        case .ready:
            return "ready"
        case .unavailable(let reason):
            let normalized = reason.normalizedForFiltering
            if normalized.contains("not eligible") { return "device_not_eligible" }
            if normalized.contains("enable apple intelligence") { return "disabled" }
            if normalized.contains("still downloading") { return "model_not_ready" }
            if normalized.contains("low-performance") || normalized.contains("high-thermal") {
                return "device_policy_blocked"
            }
            if normalized.contains("requires ios 26") { return "os_too_old" }
            if normalized.contains("not compiled") { return "framework_missing" }
            return "unavailable_other"
        }
    }
}

@MainActor
final class AppleOnDeviceAdviceBridge {
    private let moderation: ContentModeration

    init(moderation: ContentModeration) {
        self.moderation = moderation
    }

    nonisolated static func currentAvailability(
        deviceProfile: DeviceCapabilityProfile = .current()
    ) -> AppleOnDeviceModelAvailability {
        if deviceProfile.shouldAvoidOnDeviceLanguageGeneration {
            return .unavailable(
                "Device is in a low-performance or high-thermal state. Using classic generator.")
        }

        #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let model = SystemLanguageModel.default
                switch model.availability {
                case .available:
                    return .ready
                case .unavailable(.deviceNotEligible):
                    return .unavailable("This device is not eligible for Apple Intelligence.")
                case .unavailable(.appleIntelligenceNotEnabled):
                    return .unavailable(
                        "Enable Apple Intelligence in Settings to use on-device generation.")
                case .unavailable(.modelNotReady):
                    return .unavailable("Apple on-device model is still downloading.")
                case .unavailable(let other):
                    return .unavailable(
                        "Apple on-device model unavailable: \(String(describing: other)).")
                }
            }
            return .unavailable("Requires iOS 26 or later.")
        #else
            return .unavailable(
                "This build was not compiled with Apple's FoundationModels framework.")
        #endif
    }

    func generateCandidate(
        category: AdviceCategory,
        tone: ToneMode,
        situation: String?,
        includeRationale: Bool,
        seed: Int,
        now: Date = Date()
    ) async throws -> GeneratedAdvice {
        guard Self.currentAvailability().isReady else {
            throw AppleOnDeviceAdviceError.unavailable
        }

        #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let instructions = Self.instructions(category: category, tone: tone)
                let session = LanguageModelSession(instructions: instructions)
                let prompt = Self.prompt(
                    category: category,
                    tone: tone,
                    situation: situation,
                    seed: seed
                )
                let response = try await session.respond(to: prompt)
                let parsed = Self.parseModelTextResponse(response.content)

                let rawAdvice = parsed.advice.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawAdvice.isEmpty else {
                    throw AppleOnDeviceAdviceError.invalidResponse
                }
                let rawRationale =
                    includeRationale
                    ? parsed.rationale?.trimmingCharacters(in: .whitespacesAndNewlines)
                    : nil
                let moderated = moderation.apply(
                    to: Self.trimmedOutput(rawAdvice, limit: 220),
                    rationale: rawRationale.flatMap {
                        $0.isEmpty ? nil : Self.trimmedOutput($0, limit: 140)
                    }
                )

                return GeneratedAdvice(
                    category: category,
                    tone: tone,
                    adviceLine: moderated.advice,
                    rationaleLine: moderated.rationale,
                    createdAt: now
                )
            }
        #endif

        throw AppleOnDeviceAdviceError.unavailable
    }

    func generateQuoteCandidate(
        category: AdviceCategory,
        tone: ToneMode,
        seed: Int,
        now: Date = Date()
    ) async throws -> BadQuote {
        guard Self.currentAvailability().isReady else {
            throw AppleOnDeviceAdviceError.unavailable
        }

        #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let session = LanguageModelSession(
                    instructions: Self.quoteInstructions(category: category, tone: tone))
                let response = try await session.respond(
                    to: Self.quotePrompt(category: category, tone: tone, seed: seed)
                )
                let parsed = Self.parseModelQuoteResponse(response.content)
                let quoteText = Self.trimmedOutput(parsed.quote, limit: 160)
                guard !quoteText.isEmpty else {
                    throw AppleOnDeviceAdviceError.invalidResponse
                }
                let source =
                    parsed.source.flatMap { candidate -> String? in
                        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : String(trimmed.prefix(44))
                    } ?? "Apple On-Device Quote Lab"
                let moderated = moderation.apply(to: quoteText, rationale: nil)
                return BadQuote(
                    id: "apple-quote-\(category.rawValue)-\(seed)",
                    text: moderated.advice,
                    source: source,
                    category: category
                )
            }
        #endif

        throw AppleOnDeviceAdviceError.unavailable
    }

    private static func trimmedOutput(_ text: String, limit: Int) -> String {
        let collapsed = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(limit))
    }

    private static func prompt(
        category: AdviceCategory,
        tone: ToneMode,
        situation: String?,
        seed: Int
    ) -> String {
        let seedLine = "Variation seed: \(seed)"
        let categoryTemplate = categoryGenerationTemplate(category)
        let toneTemplate = toneGenerationTemplate(tone)
        let normalizedSituation = situation?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        if let normalizedSituation, !normalizedSituation.isEmpty {
            return """
                Generate one satirical, obviously bad piece of advice for the \(category.title) category.
                Tone: \(tone.title)
                Situation: \(normalizedSituation)
                \(seedLine)
                Category template: \(categoryTemplate)
                Tone template: \(toneTemplate)
                Return exactly one compact JSON object (no markdown, no code fences):
                {"advice":"...","notes":"...","sourceLabel":"Apple On-Device","styleTag":"..."}
                Constraints:
                - advice: 1-3 sentences, <=220 characters, clearly satirical and obviously bad.
                - notes: 1-2 sentences, <=140 characters, briefly explain why the advice is bad and what better advice would be.
                - sourceLabel: exactly "Apple On-Device"
                - styleTag: a short style label (prefer "\(tone.title)")
                """
        }

        return """
            Generate one satirical, obviously bad piece of advice for the \(category.title) category.
            Tone: \(tone.title)
            \(seedLine)
            Category template: \(categoryTemplate)
            Tone template: \(toneTemplate)
            Return exactly one compact JSON object (no markdown, no code fences):
            {"advice":"...","notes":"...","sourceLabel":"Apple On-Device","styleTag":"..."}
            Constraints:
            - advice: 1-3 sentences, <=220 characters, clearly satirical and obviously bad.
            - notes: 1-2 sentences, <=140 characters, briefly explain why the advice is bad and what better advice would be.
            - sourceLabel: exactly "Apple On-Device"
            - styleTag: a short style label (prefer "\(tone.title)")
            """
    }

    private static func instructions(category: AdviceCategory, tone: ToneMode) -> String {
        """
        You write satirical "bad advice" for a humor app called Badvice.
        The output must be clearly terrible advice, not real guidance.

        Tone persona: \(tonePersona(tone))
        Category context: \(categoryContext(category))
        Category generation template: \(categoryGenerationTemplate(category))
        Tone generation template: \(toneGenerationTemplate(tone))

        Requirements:
        - Sound confident, but be obviously wrong or absurd.
        - Keep the main advice concise, punchy, and self-aware.
        - Avoid harmful, illegal, sexual, or self-harm instructions.
        - Do not encourage coercion, manipulation, loyalty tests, humiliation, stalking, harassment, fraud, or revenge.
        - Keep the humor playful and absurd; do not target protected groups or endorse emotional abuse.
        - For dating/social/career topics, make the badness come from overconfidence, nonsense frameworks, or misread signals.
        - If a rationale is included, explain why the advice is bad in a playful, educational way.
        """
    }

    private static func quoteInstructions(category: AdviceCategory, tone: ToneMode) -> String {
        """
        You write satirical fake quotes for a humor app called Badvice.
        The quote should sound memorable and punchy, but be obviously bad advice.

        Category context: \(categoryContext(category))
        Category quote template: \(categoryQuoteGenerationTemplate(category))
        Tone persona: \(tonePersona(tone))
        Tone quote template: \(toneQuoteGenerationTemplate(tone))

        Requirements:
        - One short quote line (8-160 chars)
        - Clearly satirical / obviously bad
        - Avoid harmful, illegal, sexual, or self-harm content
        - Sound like a fake "expert", "memo", "oracle", or "club" source
        """
    }

    private static func categoryGenerationTemplate(_ category: AdviceCategory) -> String {
        switch category {
        case .dating:
            return
                "Escalate too fast, misread signals, and replace communication with grand gestures."
        case .fitness:
            return
                "Ignore recovery and form; optimize for ego, shortcuts, and performative intensity."
        case .career:
            return "Treat confidence as competence; overpromise, politic, and skip prep."
        case .money:
            return "Chase hype, hide risk, and confuse urgency with financial strategy."
        case .parenting:
            return "Apply rigid one-size-fits-all rules and prioritize control over listening."
        case .tech:
            return
                "Ship first, ignore testing, and solve human problems with unnecessary complexity."
        case .social:
            return
                "Center yourself, assume motives, and turn small moments into dramatic statements."
        case .cooking:
            return "Replace measuring and timing with vibes, substitutions, and overconfidence."
        case .travel:
            return "Underplan essentials, overplan aesthetics, and improvise the risky parts."
        case .productivity:
            return
                "Build elaborate systems instead of doing the work; optimize theater over output."
        case .pets:
            return "Prioritize aesthetics over health, skip vet visits, and treat pets as fashion accessories."
        case .relationships:
            return "Monitor social media, fuel drama, and treat jealousy as proof of love."
        case .spirituality:
            return "Manifest everything, ignore evidence, and blame the stars for your mistakes."
        case .financeCrypto:
            return "Invest based on FOMO, ignore all warnings, and call every loss a learning experience."
        case .random:
            return "Pick a clearly bad pattern and commit with total certainty."
        }
    }

    private static func categoryQuoteGenerationTemplate(_ category: AdviceCategory) -> String {
        switch category {
        case .dating:
            return "Frame mixed signals, games, and ambiguity as premium romance strategy."
        case .fitness:
            return "Glorify overtraining, ego lifting, and skipping recovery as discipline."
        case .career:
            return "Celebrate optics, jargon, and confidence theater over substance."
        case .money:
            return "Treat impulse spending, hype, and denial of risk as savvy finance."
        case .parenting:
            return "Recast inconsistency and control as advanced parenting leadership."
        case .tech:
            return "Praise shortcuts, hotfixes, and neglected testing as innovation."
        case .social:
            return "Encourage oversharing, escalation, and self-centering as charisma."
        case .cooking:
            return "Promote improvisation without fundamentals as culinary genius."
        case .travel:
            return "Romanticize poor planning and budget chaos as authentic adventure."
        case .productivity:
            return "Confuse system design and busywork with meaningful output."
        case .pets:
            return "Treat pets as fashion accessories and skip health for aesthetics."
        case .relationships:
            return "Frame jealousy as love and social media stalking as research."
        case .spirituality:
            return "Blame the stars, manifest without effort, and skip therapy."
        case .financeCrypto:
            return "Call every loss a learning experience and invest based on memes."
        case .random:
            return "Sound quotable, wrong, and overly certain."
        }
    }

    private static func toneGenerationTemplate(_ tone: ToneMode) -> String {
        switch tone {
        case .corporateConsultant:
            return
                "Use business jargon, frameworks, and decisive executive tone; keep the badness absurd, not manipulative."
        case .alphaPodcast:
            return
                "Aggressive certainty and hustle language, but keep it clearly satirical and avoid demeaning or coercive framing."
        case .wizard:
            return "Mystical metaphors, prophecy style, magical certainty."
        case .influencer:
            return "Aesthetic, viral, brand-forward language and trend confidence."
        case .toxicBestFriend:
            return
                "Messy, dramatic, casual, and recklessly loyal-sounding, but playful rather than cruel."
        case .boomer:
            return "Old-school certainty, dismissive modern commentary, blunt phrasing."
        case .cryptoBro:
            return "Market slang, speculative confidence, pseudo-technical hype."
        case .minimalistMonk:
            return "Calm, stripped-down phrasing with extreme simplification."
        case .friendRoast:
            return "Playful roast energy, affectionate mockery, quick punchlines."
        case .lifeCoach:
            return "Motivational cadence, self-help language, absolute mindset claims."
        case .conspiracyTheorist:
            return "Pattern-seeking paranoia, hidden-agenda framing, suspicious certainty."
        case .genZ:
            return "Gen Z slang, chaotic energy, irony overload, unhinged optimism."
        case .redditCommenter:
            return "Wall of text, cites sources nobody asked for, condescending tone."
        case .linkedInInfluencer:
            return "Corporate buzzwords, humble brags, inspirational platitudes, emoji mastery."
        case .random:
            return "Choose one strong comedic persona and stay consistent."
        }
    }

    private static func toneQuoteGenerationTemplate(_ tone: ToneMode) -> String {
        switch tone {
        case .corporateConsultant:
            return "Quote sounds like a boardroom principle or strategy memo line."
        case .alphaPodcast:
            return "Quote sounds like a bold, confrontational podcast clip."
        case .wizard:
            return "Quote sounds like a magical proverb or spellbook warning."
        case .influencer:
            return "Quote sounds like a viral caption or aesthetic life mantra."
        case .toxicBestFriend:
            return "Quote sounds messy, loyal, and dramatically reckless."
        case .boomer:
            return "Quote sounds blunt, old-school, and overconfident."
        case .cryptoBro:
            return "Quote sounds market-hyped, speculative, and slang-heavy."
        case .minimalistMonk:
            return "Quote sounds calm, spare, and extremely reductive."
        case .friendRoast:
            return "Quote sounds playful and roasty with a fast punchline."
        case .lifeCoach:
            return "Quote sounds motivational and absolute, like stage advice."
        case .conspiracyTheorist:
            return "Quote sounds suspicious, pattern-seeking, and dramatic."
        case .genZ:
            return "Quote sounds unhinged, ironic, and terminally online."
        case .redditCommenter:
            return "Quote sounds like a smug paragraph with unnecessary citations."
        case .linkedInInfluencer:
            return "Quote sounds like a humbler-brags with corporate emojis."
        case .random:
            return "Pick one strong persona and keep the quote voice consistent."
        }
    }

    private static func quotePrompt(category: AdviceCategory, tone: ToneMode, seed: Int) -> String {
        """
        Generate one fake quote for category \(category.title) in tone \(tone.title).
        Variation seed: \(seed)
        Category quote template: \(categoryQuoteGenerationTemplate(category))
        Tone quote template: \(toneQuoteGenerationTemplate(tone))
        Return exactly two lines:
        QUOTE: <short quote text>
        SOURCE: <fake source name>
        """
    }

    @available(iOS 26.0, *)
    private func prepareSituationContextIfNeeded(_ situation: String?) async throws
        -> PreparedSituationContext?
    {
        guard let raw = situation?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty
        else {
            return nil
        }
        guard raw.count >= 12 else {
            return PreparedSituationContext(original: raw, focus: nil, tags: [])
        }

        let session = LanguageModelSession(
            instructions: """
                Summarize a user situation for a satire app prompt.
                Do not give advice.
                Return exactly two lines:
                FOCUS: <short summary>
                TAGS: <comma-separated 3-6 tags>
                """)
        let response = try await session.respond(
            to: """
                Situation: \(raw)
                """)
        let parsed = Self.parseSituationContextResponse(response.content, original: raw)
        return parsed
    }

    private static func parseSituationContextResponse(
        _ text: String,
        original: String
    ) -> PreparedSituationContext {
        let lines =
            text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let focusLine = lines.first(where: { $0.uppercased().hasPrefix("FOCUS:") })
        let tagsLine = lines.first(where: { $0.uppercased().hasPrefix("TAGS:") })
        let focusRaw = focusLine?
            .replacingOccurrences(of: "FOCUS:", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tagsRaw = tagsLine?
            .replacingOccurrences(of: "TAGS:", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tags = (tagsRaw ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return PreparedSituationContext(
            original: original,
            focus: focusRaw.flatMap { $0.isEmpty ? nil : String($0.prefix(100)) },
            tags: Array(tags.prefix(6))
        )
    }

    private static func parseModelTextResponse(_ text: String) -> (
        advice: String, rationale: String?
    ) {
        if let parsedJSON = Self.parseModelJSONResponse(text) {
            return parsedJSON
        }

        let lines =
            text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let adviceLine =
            lines.first(where: { $0.uppercased().hasPrefix("ADVICE:") })
            ?? lines.first
            ?? ""
        let rationaleLine = lines.first(where: { $0.uppercased().hasPrefix("RATIONALE:") })

        let advice = adviceLine.replacingOccurrences(
            of: "ADVICE:", with: "", options: [.caseInsensitive]
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        let rationaleRaw = rationaleLine?
            .replacingOccurrences(of: "RATIONALE:", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rationale = Self.normalizedRationaleValue(rationaleRaw)

        return (advice, rationale)
    }

    private static func parseModelJSONResponse(_ text: String) -> (
        advice: String, rationale: String?
    )? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var candidates = [trimmed]
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            let fragment = String(trimmed[start...end])
            if fragment != trimmed {
                candidates.append(fragment)
            }
        }

        for candidate in candidates {
            guard
                let data = candidate.data(using: .utf8),
                let jsonObject = try? JSONSerialization.jsonObject(with: data),
                let object = jsonObject as? [String: Any]
            else {
                continue
            }

            let advice = (object["advice"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !advice.isEmpty else { continue }

            let rationaleRaw =
                (object["notes"] as? String ?? object["rationale"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return (advice, Self.normalizedRationaleValue(rationaleRaw))
        }

        return nil
    }

    private static func normalizedRationaleValue(_ raw: String?) -> String? {
        raw.flatMap { value -> String? in
            let normalized = value.normalizedForFiltering
            if value.isEmpty || normalized == "none" || normalized == "n/a" {
                return nil
            }
            return value
        }
    }

    private static func parseModelQuoteResponse(_ text: String) -> (quote: String, source: String?)
    {
        let lines =
            text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let quoteLine =
            lines.first(where: { $0.uppercased().hasPrefix("QUOTE:") })
            ?? lines.first
            ?? ""
        let sourceLine = lines.first(where: { $0.uppercased().hasPrefix("SOURCE:") })

        let quote = quoteLine.replacingOccurrences(
            of: "QUOTE:", with: "", options: [.caseInsensitive]
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = sourceLine?
            .replacingOccurrences(of: "SOURCE:", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (quote, source)
    }

    private static func categoryContext(_ category: AdviceCategory) -> String {
        switch category {
        case .dating: return "relationships, romance, and interpersonal connections"
        case .fitness: return "exercise, health, and physical wellness"
        case .career: return "work, professional development, and office life"
        case .money: return "finances, spending, and investment decisions"
        case .parenting: return "raising children and family dynamics"
        case .tech: return "technology, software, and digital life"
        case .social: return "friendships, networking, and social situations"
        case .cooking: return "food preparation, recipes, and kitchen adventures"
        case .travel: return "trips, vacations, and exploring new places"
        case .productivity: return "time management, organization, and getting things done"
        case .pets: return "pet care, pet training, and pet parenting"
        case .relationships: return "romantic relationships, partnerships, and interpersonal dynamics"
        case .spirituality: return "spiritual growth, manifestation, and mystical beliefs"
        case .financeCrypto: return "cryptocurrency, trading, and speculative finance"
        case .random: return "mixed category context"
        }
    }

    private static func tonePersona(_ tone: ToneMode) -> String {
        switch tone {
        case .corporateConsultant:
            return "A buzzword-heavy consultant who turns bad ideas into frameworks"
        case .alphaPodcast:
            return "A hyper-confident podcast bro who treats nuance as weakness"
        case .wizard:
            return "A mystical wizard offering magical answers to normal problems"
        case .influencer:
            return "A creator obsessed with virality, aesthetics, and clout"
        case .toxicBestFriend:
            return "A chaotic best friend giving dramatic but awful advice"
        case .boomer:
            return "An out-of-touch boomer with absolute confidence"
        case .cryptoBro:
            return "A crypto evangelist who sees every problem as a coin opportunity"
        case .minimalistMonk:
            return "An extreme minimalist who over-applies simplicity"
        case .friendRoast:
            return "A playful roaster who delivers bad advice with mock affection"
        case .lifeCoach:
            return "An overly enthusiastic life coach with questionable methods"
        case .conspiracyTheorist:
            return "Someone who sees hidden plots in ordinary situations"
        case .genZ:
            return "A chronically online zoomer with unhinged takes and ironic sincerity"
        case .redditCommenter:
            return "A smug redditor who cites studies nobody asked for"
        case .linkedInInfluencer:
            return "A corporate influencer with humble brags and emoji mastery"
        case .random:
            return "A rotating comedic persona"
        }
    }

    enum AppleOnDeviceAdviceError: Error {
        case unavailable
        case invalidResponse
    }

    private struct PreparedSituationContext {
        let original: String
        let focus: String?
        let tags: [String]
    }
}

@MainActor
enum AppPerformanceInstrumentation {
    struct IntervalToken {
        fileprivate let name: StaticString
        fileprivate let signpostState: OSSignpostIntervalState
        fileprivate let startedAt: CFAbsoluteTime
        fileprivate let debugLabel: String
    }

    private static let perfLogger = Logger(subsystem: "com.worstadvice.app", category: "performance")
    private static let signposter = OSSignposter(logger: perfLogger)
    private static var coldStartToken: IntervalToken?
    private static var didCompleteAdviceFirstRender = false

    static func beginColdStartIfNeeded() {
        guard coldStartToken == nil else { return }
        coldStartToken = beginInterval("ColdStartToAdviceFirstRender", debugLabel: "cold_start")
    }

    static func markAdviceTabFirstRenderIfNeeded() {
        guard !didCompleteAdviceFirstRender else { return }
        didCompleteAdviceFirstRender = true
        if let coldStartToken {
            endInterval(coldStartToken)
            self.coldStartToken = nil
        } else {
            signposter.emitEvent("AdviceFirstRender")
            #if DEBUG
                perfLogger.debug("perf event=advice_first_render")
            #endif
        }
    }

    static func beginAdviceGenerationInterval() -> IntervalToken {
        beginInterval("AdviceGenerationRequestToDisplay", debugLabel: "advice_generation")
    }

    static func endAdviceGenerationInterval(_ token: IntervalToken) {
        endInterval(token)
    }

    static func beginLocalModelWarmUpInterval(modelID: String) -> IntervalToken {
        let token = beginInterval("LocalModelWarmUp", debugLabel: "local_model_warmup:\(modelID)")
        #if DEBUG
            perfLogger.debug("perf local_model_warmup_begin id=\(modelID, privacy: .public)")
        #endif
        return token
    }

    static func endLocalModelWarmUpInterval(_ token: IntervalToken, modelID: String) {
        endInterval(token)
        #if DEBUG
            perfLogger.debug("perf local_model_warmup_end id=\(modelID, privacy: .public)")
        #endif
    }

    private static func beginInterval(_ name: StaticString, debugLabel: String) -> IntervalToken {
        let state = signposter.beginInterval(name)
        return IntervalToken(
            name: name,
            signpostState: state,
            startedAt: CFAbsoluteTimeGetCurrent(),
            debugLabel: debugLabel
        )
    }

    private static func endInterval(_ token: IntervalToken) {
        signposter.endInterval(token.name, token.signpostState)
        #if DEBUG
            let elapsedMS = (CFAbsoluteTimeGetCurrent() - token.startedAt) * 1_000
            perfLogger.debug(
                "perf interval=\(token.debugLabel, privacy: .public) elapsed_ms=\(elapsedMS, privacy: .public)"
            )
        #endif
    }
}

extension AppleOnDeviceAdviceBridge {
    static func prewarmSystemModelAndPoll(
        maxPollCount: Int = 8,
        pollDelay: Duration = .seconds(1)
    ) async -> AppleOnDeviceModelAvailability {
        #if canImport(FoundationModels)
            guard #available(iOS 26.0, *) else {
                return .unavailable("Requires iOS 26 or later.")
            }
            let session = LanguageModelSession(instructions: "Warm the local model for Badvice.")
            session.prewarm()
            var last = currentAvailability()
            for _ in 0..<maxPollCount {
                if Task.isCancelled { break }
                if last.isReady { return last }
                try? await Task.sleep(for: pollDelay)
                last = currentAvailability()
            }
            return last
        #else
            return currentAvailability()
        #endif
    }
}

