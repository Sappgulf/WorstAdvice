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

enum LocalModelSource: String, Codable, Sendable {
    case system
    case bundled
    case downloaded

    var badgeLabel: String {
        switch self {
        case .system: return "System"
        case .bundled: return "Bundled"
        case .downloaded: return "Downloaded"
        }
    }
}

struct LocalModelDescriptor: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let sizeBytes: Int64?
    let version: String?
    let source: LocalModelSource
    let fileURL: URL
    let isInstalled: Bool

    var isSystemModel: Bool { source == .system }
}

enum LocalModelInstallState: Equatable, Sendable {
    case idle
    case installing(progress: Double?)
    case installed
    case ready
    case error(String)
}

@MainActor
final class LocalModelStore: ObservableObject {
    struct PersistedIndex: Codable {
        var version: Int = 1
        var entries: [PersistedIndexEntry]
    }

    struct PersistedIndexEntry: Codable {
        var id: String
        var displayName: String
        var sizeBytes: Int64?
        var version: String?
        var source: LocalModelSource
        var relativePath: String
    }

    enum GenerationGate: Equatable, Sendable {
        case ready(modelID: String)
        case unavailable(
            reasonKey: String,
            message: String,
            settingsWarning: String?,
            shouldOpenAppSettings: Bool
        )

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    @Published private(set) var availableModels: [LocalModelDescriptor] = []
    @Published private(set) var installedModelIDs: Set<String> = []
    @Published var selectedModelID: String? {
        didSet {
            persistSelectedModelID()
            if oldValue != selectedModelID {
                resetWarmUpStateIfNeeded(forDeselectedID: oldValue)
            }
        }
    }
    @Published private(set) var installStateByID: [String: LocalModelInstallState] = [:]

    nonisolated static let selectedModelDefaultsKey = "appleLocalModel.selectedModelID"
    nonisolated private static let warmedModelIDsDefaultsKey = "appleLocalModel.warmedModelIDs"
    nonisolated private static let modelRootFolderName = "Models"
    nonisolated private static let indexFileName = "models_index.json"
    nonisolated private static let systemModelID = "apple.foundation.system"
    nonisolated private static let systemModelPlaceholderName = "system-model"

    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let bundle: Bundle
    private let appSupportBaseURLOverride: URL?
    private let includeSystemModelWhenFrameworkMissing: Bool
    private let logger = Logger(subsystem: "com.worstadvice.app", category: "localModelStore")
    private var warmedModelIDs: Set<String>
    private var reloadTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        appSupportBaseURLOverride: URL? = nil,
        includeSystemModelWhenFrameworkMissing: Bool = false
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.bundle = bundle
        self.appSupportBaseURLOverride = appSupportBaseURLOverride
        self.includeSystemModelWhenFrameworkMissing = includeSystemModelWhenFrameworkMissing
        self.selectedModelID = userDefaults.string(forKey: Self.selectedModelDefaultsKey)
        self.warmedModelIDs = Set(
            userDefaults.stringArray(forKey: Self.warmedModelIDsDefaultsKey) ?? [])
    }

    deinit {
        reloadTask?.cancel()
    }

    func reloadAvailableModels() {
        reloadTask?.cancel()
        let fileManager = self.fileManager
        let userDefaults = self.userDefaults
        let bundle = self.bundle
        let appSupportBaseURLOverride = self.appSupportBaseURLOverride
        let includeSystemModelWhenFrameworkMissing = self.includeSystemModelWhenFrameworkMissing
        let warmedModelIDs = self.warmedModelIDs

        reloadTask = Task(priority: .utility) { [weak self] in
            let snapshot = await Self.discoverSnapshot(
                fileManager: fileManager,
                bundle: bundle,
                appSupportBaseURLOverride: appSupportBaseURLOverride,
                includeSystemModelWhenFrameworkMissing: includeSystemModelWhenFrameworkMissing,
                warmedModelIDs: warmedModelIDs,
                existingSelectedModelID: userDefaults.string(forKey: Self.selectedModelDefaultsKey)
            )
            guard !Task.isCancelled else { return }
            self?.applyDiscoverySnapshot(snapshot)
        }
    }

    func reloadAvailableModelsNowForTesting() async {
        let snapshot = await Self.discoverSnapshot(
            fileManager: fileManager,
            bundle: bundle,
            appSupportBaseURLOverride: appSupportBaseURLOverride,
            includeSystemModelWhenFrameworkMissing: includeSystemModelWhenFrameworkMissing,
            warmedModelIDs: warmedModelIDs,
            existingSelectedModelID: selectedModelID
        )
        applyDiscoverySnapshot(snapshot)
    }

    func installModel(id: String) async throws {
        guard let descriptor = availableModels.first(where: { $0.id == id }) else {
            throw NSError(
                domain: "LocalModelStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Model not found."]
            )
        }

        if descriptor.isSystemModel {
            installStateByID[id] = .installing(progress: nil)
            debugLog("install begin id=\(id) source=system")
            let availability = await AppleOnDeviceAdviceBridge.prewarmSystemModelAndPoll()
            switch availability {
            case .ready:
                installStateByID[id] = warmedModelIDs.contains(id) ? .ready : .installed
            case .unavailable(let reason):
                if availability.analyticsKey == "model_not_ready" {
                    installStateByID[id] = .installing(progress: nil)
                } else {
                    installStateByID[id] = .error(reason)
                    throw NSError(
                        domain: "LocalModelStore",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: reason]
                    )
                }
            }
            reloadAvailableModels()
            return
        }

        if descriptor.isInstalled {
            installStateByID[id] = warmedModelIDs.contains(id) ? .ready : .installed
            return
        }

        installStateByID[id] = .error(
            "No downloadable source is configured for this model in the current build.")
        throw NSError(
            domain: "LocalModelStore",
            code: 501,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "No downloadable source is configured for this model in the current build."
            ]
        )
    }

    func removeModel(id: String) async {
        guard let descriptor = availableModels.first(where: { $0.id == id }) else { return }
        guard descriptor.source == .downloaded, !descriptor.isSystemModel else { return }

        do {
            let modelFolder = descriptor.fileURL.deletingLastPathComponent()
            if fileManager.fileExists(atPath: modelFolder.path) {
                try fileManager.removeItem(at: modelFolder)
            } else if fileManager.fileExists(atPath: descriptor.fileURL.path) {
                try fileManager.removeItem(at: descriptor.fileURL)
            }
            installStateByID[id] = .idle
            warmedModelIDs.remove(id)
            persistWarmedModelIDs()
            if selectedModelID == id {
                selectedModelID = nil
            }
            debugLog("remove success id=\(id) path=\(descriptor.fileURL.path)")
            reloadAvailableModels()
        } catch {
            installStateByID[id] = .error(error.localizedDescription)
            debugLog("remove failed id=\(id) error=\(error.localizedDescription)")
        }
    }

    func warmUp(id: String) async {
        guard let descriptor = availableModels.first(where: { $0.id == id }) else { return }
        let perfToken = AppPerformanceInstrumentation.beginLocalModelWarmUpInterval(modelID: id)
        defer { AppPerformanceInstrumentation.endLocalModelWarmUpInterval(perfToken, modelID: id) }

        installStateByID[id] = .installing(progress: nil)
        debugLog("warmup begin id=\(id) path=\(descriptor.fileURL.path)")

        if descriptor.isSystemModel {
            let availability = await AppleOnDeviceAdviceBridge.prewarmSystemModelAndPoll()
            switch availability {
            case .ready:
                warmedModelIDs.insert(id)
                persistWarmedModelIDs()
                installStateByID[id] = .ready
            case .unavailable(let reason):
                if availability.analyticsKey == "model_not_ready" {
                    installStateByID[id] = .installing(progress: nil)
                } else {
                    installStateByID[id] = .error(reason)
                }
            }
            reloadAvailableModels()
            return
        }

        do {
            try await Self.loadModelForWarmUp(url: descriptor.fileURL)
            warmedModelIDs.insert(id)
            persistWarmedModelIDs()
            installStateByID[id] = .ready
            debugLog("warmup success id=\(id)")
        } catch {
            installStateByID[id] = .error(error.localizedDescription)
            debugLog("warmup failed id=\(id) error=\(error.localizedDescription)")
        }
    }

    func generationGate(
        appleAvailability: AppleOnDeviceModelAvailability = AppleOnDeviceAdviceBridge.currentAvailability()
    ) -> GenerationGate {
        guard let selectedModelID else {
            return .unavailable(
                reasonKey: "no_selection",
                message: "No on-device model selected. Select and warm a model in Settings.",
                settingsWarning: "Auto will use the Classic generator until a local model is selected.",
                shouldOpenAppSettings: false
            )
        }

        guard let selected = availableModels.first(where: { $0.id == selectedModelID }) else {
            return .unavailable(
                reasonKey: "selected_missing",
                message: "The selected on-device model is missing. Tap Recheck in Settings.",
                settingsWarning: "Selected local model is missing. Recheck the model list.",
                shouldOpenAppSettings: false
            )
        }

        guard selected.isInstalled else {
            if selected.isSystemModel, appleAvailability.analyticsKey == "model_not_ready" {
                return .unavailable(
                    reasonKey: "system_downloading",
                    message: appleAvailability.statusText,
                    settingsWarning:
                        "Apple is still preparing the system model. Keep the device on Wi-Fi and power, then Recheck.",
                    shouldOpenAppSettings: false
                )
            }
            return .unavailable(
                reasonKey: "not_installed",
                message: "The selected local model is not installed yet.",
                settingsWarning: "Install the selected model before using Apple On-Device generation.",
                shouldOpenAppSettings: false
            )
        }

        let state = installStateByID[selectedModelID] ?? .idle
        guard state == .ready else {
            if case .error(let message) = state {
                return .unavailable(
                    reasonKey: "warmup_error",
                    message: "Local model warm-up failed: \(message)",
                    settingsWarning: "Warm-up failed for the selected model. Try Warm Up again.",
                    shouldOpenAppSettings: false
                )
            }
            return .unavailable(
                reasonKey: "not_warmed",
                message: "Local model is installed but not warmed up. Warm it up in Settings first.",
                settingsWarning: "Selected local model is installed but not warmed yet.",
                shouldOpenAppSettings: false
            )
        }

        if selected.isSystemModel {
            guard appleAvailability.isReady else {
                let shouldOpenAppSettings = appleAvailability.analyticsKey == "disabled"
                return .unavailable(
                    reasonKey: "system_unavailable_\(appleAvailability.analyticsKey)",
                    message: appleAvailability.statusText,
                    settingsWarning: appleAvailability.statusText,
                    shouldOpenAppSettings: shouldOpenAppSettings
                )
            }
            return .ready(modelID: selectedModelID)
        }

        return .unavailable(
            reasonKey: "unsupported_selected_model",
            message:
                "The selected model was validated locally, but this build uses Apple Intelligence system generation. Select the Apple system model to generate on-device.",
            settingsWarning:
                "Selected model can be warmed and inspected, but generation currently requires the Apple system model.",
            shouldOpenAppSettings: false
        )
    }

    func effectiveStatus(for provider: AdviceGenerationProvider) -> (
        key: String,
        message: String,
        hint: String,
        pill: String,
        warning: String?,
        shouldShowSettingsShortcut: Bool
    ) {
        let availability = AppleOnDeviceAdviceBridge.currentAvailability()
        let gate = generationGate(appleAvailability: availability)
        let selected = selectedModelID.flatMap { id in availableModels.first(where: { $0.id == id }) }
        let selectedState = selected.flatMap { installStateByID[$0.id] }

        switch gate {
        case .ready:
            return (
                "ready",
                "Apple on-device model is ready.",
                "Selected model is installed and warmed. Apple On-Device and Auto will use it.",
                "Ready",
                nil,
                false
            )
        case .unavailable(let reasonKey, let message, let settingsWarning, let shouldOpenAppSettings):
            if availableModels.isEmpty {
                return (
                    "no_models",
                    "No on-device models available yet.",
                    "Install or bundle a local model, then tap Recheck. Simulator builds may not expose Apple’s system model.",
                    "Empty",
                    provider == .classic ? nil : settingsWarning,
                    shouldOpenAppSettings
                )
            }

            if let selected, selected.isInstalled, selectedState != .ready, reasonKey == "not_warmed" {
                return (
                    "installed_not_warmed",
                    "Selected local model is installed but not warmed up.",
                    "Tap Warm Up to confirm the model can load before using Apple On-Device generation.",
                    "Installed",
                    provider == .classic ? nil : settingsWarning,
                    shouldOpenAppSettings
                )
            }

            if let selectedState, case .installing = selectedState {
                return (
                    "installing",
                    message,
                    "Recheck refreshes Apple model availability and local files after installation progress changes.",
                    "Installing",
                    provider == .classic ? nil : settingsWarning,
                    shouldOpenAppSettings
                )
            }

            if let selectedState, case .error(let errorMessage) = selectedState {
                return (
                    "error",
                    "Local model error: \(errorMessage)",
                    "Fix the model file, reinstall, or choose another model, then Recheck.",
                    "Error",
                    provider == .classic ? nil : settingsWarning,
                    shouldOpenAppSettings
                )
            }

            if selected == nil {
                return (
                    "not_installed",
                    "Select an on-device model to enable Apple On-Device generation.",
                    "Choose a model below, then install and warm it up.",
                    "Select",
                    provider == .classic ? nil : settingsWarning,
                    shouldOpenAppSettings
                )
            }

            return (
                "unavailable",
                message,
                "Tap Recheck after changing Apple Intelligence or device power settings.",
                "Status",
                provider == .classic ? nil : settingsWarning,
                shouldOpenAppSettings
            )
        }
    }

    func state(for modelID: String) -> LocalModelInstallState {
        installStateByID[modelID] ?? .idle
    }

    func selectModel(_ id: String?) {
        guard selectedModelID != id else { return }
        selectedModelID = id
    }

    var modelsRootDirectoryURLForTesting: URL? { try? modelsRootDirectory() }
    var modelsIndexFileURLForTesting: URL? {
        guard let root = try? modelsRootDirectory() else { return nil }
        return root.appendingPathComponent(Self.indexFileName, isDirectory: false)
    }

    private func persistSelectedModelID() {
        if let selectedModelID, !selectedModelID.isEmpty {
            userDefaults.set(selectedModelID, forKey: Self.selectedModelDefaultsKey)
        } else {
            userDefaults.removeObject(forKey: Self.selectedModelDefaultsKey)
        }
    }

    private func persistWarmedModelIDs() {
        userDefaults.set(Array(warmedModelIDs).sorted(), forKey: Self.warmedModelIDsDefaultsKey)
    }

    private func resetWarmUpStateIfNeeded(forDeselectedID oldValue: String?) {
        guard let oldValue else { return }
        if case .ready = installStateByID[oldValue] {
            installStateByID[oldValue] = .installed
        }
    }

    private func applyDiscoverySnapshot(_ snapshot: DiscoverySnapshot) {
        availableModels = snapshot.availableModels
        installedModelIDs = snapshot.installedModelIDs

        var nextInstallStates = installStateByID
        let currentInstalling = installStateByID.filter {
            if case .installing = $0.value { return true }
            return false
        }
        for model in snapshot.availableModels {
            if let inFlight = currentInstalling[model.id] {
                nextInstallStates[model.id] = inFlight
                continue
            }
            nextInstallStates[model.id] = snapshot.installStateByID[model.id] ?? .idle
        }
        nextInstallStates.keys
            .filter { id in !snapshot.availableModels.contains(where: { $0.id == id }) }
            .forEach { nextInstallStates.removeValue(forKey: $0) }
        installStateByID = nextInstallStates

        let validIDs = Set(snapshot.availableModels.map(\.id))
        let healedWarmed = Set(warmedModelIDs.filter(validIDs.contains))
        if healedWarmed != warmedModelIDs {
            warmedModelIDs = healedWarmed
            persistWarmedModelIDs()
        }

        if let selectedModelID, !validIDs.contains(selectedModelID) {
            self.selectedModelID = snapshot.defaultSelectedModelID
        } else if self.selectedModelID == nil {
            self.selectedModelID = snapshot.defaultSelectedModelID
        }

        if snapshot.availableModels.isEmpty {
            debugLog(
                "recheck empty bundled=\(snapshot.debugCounts.bundled) downloaded=\(snapshot.debugCounts.downloaded) systemIncluded=\(snapshot.debugCounts.systemIncluded) reason=\(snapshot.debugEmptyReason)"
            )
        } else {
            debugLog(
                "recheck models=\(snapshot.availableModels.count) installed=\(snapshot.installedModelIDs.count) selected=\(self.selectedModelID ?? "nil") bundled=\(snapshot.debugCounts.bundled) downloaded=\(snapshot.debugCounts.downloaded) systemIncluded=\(snapshot.debugCounts.systemIncluded)"
            )
        }
    }

    private func modelsRootDirectory() throws -> URL {
        let baseURL: URL
        if let appSupportBaseURLOverride {
            baseURL = appSupportBaseURLOverride
        } else {
            baseURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        let modelsRoot = baseURL
            .appendingPathComponent(Self.modelRootFolderName, isDirectory: true)
        if !fileManager.fileExists(atPath: modelsRoot.path) {
            try fileManager.createDirectory(at: modelsRoot, withIntermediateDirectories: true)
        }
        return modelsRoot
    }

    private static func discoverSnapshot(
        fileManager: FileManager,
        bundle: Bundle,
        appSupportBaseURLOverride: URL?,
        includeSystemModelWhenFrameworkMissing: Bool,
        warmedModelIDs: Set<String>,
        existingSelectedModelID: String?
    ) async -> DiscoverySnapshot {
        let helper = DiscoveryHelper(
            fileManager: fileManager,
            bundle: bundle,
            appSupportBaseURLOverride: appSupportBaseURLOverride,
            includeSystemModelWhenFrameworkMissing: includeSystemModelWhenFrameworkMissing,
            warmedModelIDs: warmedModelIDs,
            existingSelectedModelID: existingSelectedModelID
        )
        return await Task.detached(priority: .utility) {
            do {
                return try helper.run()
            } catch {
                return DiscoverySnapshot(
                    availableModels: [],
                    installedModelIDs: [],
                    installStateByID: [:],
                    defaultSelectedModelID: nil,
                    debugCounts: .init(systemIncluded: 0, bundled: 0, downloaded: 0),
                    debugEmptyReason: "discovery_failed_\(error.localizedDescription)"
                )
            }
        }.value
    }

    private static func loadModelForWarmUp(url: URL) async throws {
        #if canImport(CoreML)
            try await Task.detached(priority: .utility) {
                _ = try MLModel(contentsOf: url)
            }.value
        #else
            throw NSError(
                domain: "LocalModelStore",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "CoreML is unavailable in this build."]
            )
        #endif
    }

    private func debugLog(_ message: String) {
        #if DEBUG
            logger.debug("\(message, privacy: .public)")
        #endif
    }

    private struct DiscoveryCounts: Sendable {
        var systemIncluded: Int
        var bundled: Int
        var downloaded: Int
    }

    private struct DiscoverySnapshot: Sendable {
        var availableModels: [LocalModelDescriptor]
        var installedModelIDs: Set<String>
        var installStateByID: [String: LocalModelInstallState]
        var defaultSelectedModelID: String?
        var debugCounts: DiscoveryCounts
        var debugEmptyReason: String
    }

    private struct DiscoveryHelper: @unchecked Sendable {
        let fileManager: FileManager
        let bundle: Bundle
        let appSupportBaseURLOverride: URL?
        let includeSystemModelWhenFrameworkMissing: Bool
        let warmedModelIDs: Set<String>
        let existingSelectedModelID: String?

        func run() throws -> DiscoverySnapshot {
            let modelsRoot = try modelsRootDirectory()
            let indexFileURL = modelsRoot.appendingPathComponent(
                LocalModelStore.indexFileName,
                isDirectory: false
            )

            var bundled: [LocalModelDescriptor] = []
            var downloaded: [LocalModelDescriptor] = []
            var installStates: [String: LocalModelInstallState] = [:]
            var installedIDs = Set<String>()
            var emptyReasons: [String] = []

            if let systemModel = buildSystemDescriptor() {
                bundled.append(systemModel)
                if systemModel.isInstalled {
                    installedIDs.insert(systemModel.id)
                    installStates[systemModel.id] =
                        warmedModelIDs.contains(systemModel.id) ? .ready : .installed
                } else {
                    let availability = AppleOnDeviceAdviceBridge.currentAvailability()
                    switch availability.analyticsKey {
                    case "model_not_ready":
                        installStates[systemModel.id] = .installing(progress: nil)
                    case "ready":
                        installStates[systemModel.id] =
                            warmedModelIDs.contains(systemModel.id) ? .ready : .installed
                    case "disabled", "device_policy_blocked", "device_not_eligible", "os_too_old":
                        installStates[systemModel.id] = .error(availability.statusText)
                    case "framework_missing":
                        if includeSystemModelWhenFrameworkMissing {
                            installStates[systemModel.id] = .error(availability.statusText)
                        } else {
                            bundled.removeAll { $0.id == systemModel.id }
                            emptyReasons.append("system_framework_missing")
                        }
                    default:
                        installStates[systemModel.id] = .idle
                        emptyReasons.append("system_\(availability.analyticsKey)")
                    }
                }
            } else {
                emptyReasons.append("system_model_not_exposed")
            }

            let bundledFiles = discoverBundledCoreMLModels()
            for descriptor in bundledFiles {
                bundled.append(descriptor)
                installedIDs.insert(descriptor.id)
                installStates[descriptor.id] = warmedModelIDs.contains(descriptor.id) ? .ready : .installed
            }
            if bundledFiles.isEmpty {
                emptyReasons.append("no_bundled_mlmodelc")
            }

            var indexedEntries = loadIndex(from: indexFileURL)?.entries ?? []
            let downloadedFromIndex = indexedEntries.compactMap { entry -> LocalModelDescriptor? in
                let fileURL = modelsRoot.appendingPathComponent(entry.relativePath, isDirectory: true)
                guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
                return LocalModelDescriptor(
                    id: entry.id,
                    displayName: entry.displayName,
                    sizeBytes: entry.sizeBytes,
                    version: entry.version,
                    source: .downloaded,
                    fileURL: fileURL,
                    isInstalled: true
                )
            }
            if downloadedFromIndex.count != indexedEntries.count {
                indexedEntries = downloadedFromIndex.map { descriptor in
                    PersistedIndexEntry(
                        id: descriptor.id,
                        displayName: descriptor.displayName,
                        sizeBytes: descriptor.sizeBytes,
                        version: descriptor.version,
                        source: .downloaded,
                        relativePath: relativePath(
                            for: descriptor.fileURL,
                            root: modelsRoot
                        )
                    )
                }
            }

            var downloadedByID = Dictionary(uniqueKeysWithValues: downloadedFromIndex.map { ($0.id, $0) })

            let discoveredDownloaded = discoverDownloadedCoreMLModels(in: modelsRoot)
            for descriptor in discoveredDownloaded where downloadedByID[descriptor.id] == nil {
                downloadedByID[descriptor.id] = descriptor
                indexedEntries.append(
                    PersistedIndexEntry(
                        id: descriptor.id,
                        displayName: descriptor.displayName,
                        sizeBytes: descriptor.sizeBytes,
                        version: descriptor.version,
                        source: .downloaded,
                        relativePath: relativePath(for: descriptor.fileURL, root: modelsRoot)
                    )
                )
            }

            downloaded = downloadedByID.values.sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            for descriptor in downloaded {
                installedIDs.insert(descriptor.id)
                installStates[descriptor.id] = warmedModelIDs.contains(descriptor.id) ? .ready : .installed
            }
            if downloaded.isEmpty {
                emptyReasons.append("no_downloaded_models")
            }

            persistIndexIfNeeded(entries: indexedEntries, to: indexFileURL)

            let allModels = (bundled + downloaded)
                .sorted(by: modelSort(lhs:rhs:))
            let validIDs = Set(allModels.map(\.id))
            let defaultSelected = validSelection(
                existingSelectedModelID,
                validIDs: validIDs,
                allModels: allModels
            )

            return DiscoverySnapshot(
                availableModels: allModels,
                installedModelIDs: installedIDs,
                installStateByID: installStates,
                defaultSelectedModelID: defaultSelected,
                debugCounts: .init(
                    systemIncluded: allModels.contains(where: { $0.source == .system }) ? 1 : 0,
                    bundled: allModels.filter { $0.source == .bundled }.count,
                    downloaded: downloaded.count
                ),
                debugEmptyReason: emptyReasons.joined(separator: "|")
            )
        }

        private func modelsRootDirectory() throws -> URL {
            let baseURL: URL
            if let appSupportBaseURLOverride {
                baseURL = appSupportBaseURLOverride
            } else {
                baseURL = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
            }
            let modelsRoot = baseURL.appendingPathComponent(LocalModelStore.modelRootFolderName, isDirectory: true)
            if !fileManager.fileExists(atPath: modelsRoot.path) {
                try fileManager.createDirectory(at: modelsRoot, withIntermediateDirectories: true)
            }
            return modelsRoot
        }

        private func buildSystemDescriptor() -> LocalModelDescriptor? {
            let availability = AppleOnDeviceAdviceBridge.currentAvailability()
            if availability.analyticsKey == "framework_missing", !includeSystemModelWhenFrameworkMissing {
                return nil
            }

            let baseURL = appSupportBaseURLOverride ?? (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ))
            let placeholderRoot = (baseURL ?? bundle.bundleURL)
                .appendingPathComponent(LocalModelStore.modelRootFolderName, isDirectory: true)
                .appendingPathComponent(LocalModelStore.systemModelPlaceholderName, isDirectory: true)

            return LocalModelDescriptor(
                id: LocalModelStore.systemModelID,
                displayName: "Apple Intelligence System Model",
                sizeBytes: nil,
                version: nil,
                source: .system,
                fileURL: placeholderRoot,
                isInstalled: availability.isReady
            )
        }

        private func discoverBundledCoreMLModels() -> [LocalModelDescriptor] {
            guard let resourceURL = bundle.resourceURL else { return [] }
            return discoverCoreMLModels(
                in: resourceURL,
                source: .bundled,
                idPrefix: "bundled."
            )
        }

        private func discoverDownloadedCoreMLModels(in modelsRoot: URL) -> [LocalModelDescriptor] {
            var results: [LocalModelDescriptor] = []
            guard let directories = try? fileManager.contentsOfDirectory(
                at: modelsRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return results
            }
            for directory in directories {
                if directory.lastPathComponent == LocalModelStore.indexFileName { continue }
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }
                results.append(
                    contentsOf: discoverCoreMLModels(
                        in: directory,
                        source: .downloaded,
                        idPrefix: "downloaded."
                    )
                )
            }
            return results
        }

        private func discoverCoreMLModels(in root: URL, source: LocalModelSource, idPrefix: String)
            -> [LocalModelDescriptor]
        {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            var results: [LocalModelDescriptor] = []
            for case let candidate as URL in enumerator {
                guard candidate.pathExtension == "mlmodelc" else { continue }
                let relative = relativePath(for: candidate, root: root)
                let idBase = relative
                    .replacingOccurrences(of: "/", with: ".")
                    .replacingOccurrences(of: " ", with: "_")
                    .lowercased()
                let displayName = candidate.deletingPathExtension().lastPathComponent
                let size = directoryByteSize(at: candidate)
                results.append(
                    LocalModelDescriptor(
                        id: "\(idPrefix)\(idBase)",
                        displayName: displayName,
                        sizeBytes: size,
                        version: nil,
                        source: source,
                        fileURL: candidate,
                        isInstalled: true
                    )
                )
                enumerator.skipDescendants()
            }
            return results
        }

        private func loadIndex(from url: URL) -> PersistedIndex? {
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(PersistedIndex.self, from: data)
        }

        private func persistIndexIfNeeded(entries: [PersistedIndexEntry], to url: URL) {
            let normalized = entries
                .filter { !$0.relativePath.isEmpty }
                .sorted { lhs, rhs in lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending }
            let payload = PersistedIndex(entries: normalized)
            guard let data = try? JSONEncoder().encode(payload) else { return }
            try? data.write(to: url, options: [.atomic])
        }

        private func directoryByteSize(at root: URL) -> Int64? {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return nil
            }
            var total: Int64 = 0
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(
                    forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                guard values?.isRegularFile == true else { continue }
                let fileSize = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0
                total += Int64(fileSize)
            }
            return total == 0 ? nil : total
        }

        private func validSelection(
            _ existingSelectedModelID: String?,
            validIDs: Set<String>,
            allModels: [LocalModelDescriptor]
        ) -> String? {
            if let existingSelectedModelID, validIDs.contains(existingSelectedModelID) {
                return existingSelectedModelID
            }
            if let preferred = allModels.first(where: { $0.source == .system }) {
                return preferred.id
            }
            return allModels.first?.id
        }

        private func relativePath(for url: URL, root: URL) -> String {
            let rootPath = root.standardizedFileURL.path
            let fullPath = url.standardizedFileURL.path
            guard fullPath.hasPrefix(rootPath) else {
                return url.lastPathComponent
            }
            return String(fullPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        private func modelSort(lhs: LocalModelDescriptor, rhs: LocalModelDescriptor) -> Bool {
            let sourceRank: (LocalModelSource) -> Int = {
                switch $0 {
                case .system: return 0
                case .bundled: return 1
                case .downloaded: return 2
                }
            }
            if sourceRank(lhs.source) != sourceRank(rhs.source) {
                return sourceRank(lhs.source) < sourceRank(rhs.source)
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

