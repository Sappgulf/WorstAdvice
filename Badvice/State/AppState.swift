import CloudKit
import Foundation
import Combine
import OSLog
import Observation
import SwiftData
import UIKit

#if canImport(FoundationModels)
    import FoundationModels
#endif

#if canImport(CoreML)
    import CoreML
#endif

private let logger = Logger(subsystem: "com.worstadvice.app", category: "state")
private let cloudKitLogger = Logger(subsystem: "com.worstadvice.app", category: "cloudkit.friends")

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

protocol AnalyticsTracking {
    func track(_ event: String, properties: [String: String])
}

struct AppAnalyticsTracker: AnalyticsTracking {
    private let logger = Logger(subsystem: "com.worstadvice.app", category: "analytics")

    func track(_ event: String, properties: [String: String] = [:]) {
        let payload = properties.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ",")
        if payload.isEmpty {
            logger.info("event=\(event, privacy: .public)")
        } else {
            logger.info("event=\(event, privacy: .public) props=\(payload, privacy: .public)")
        }
    }
}

@Model
final class AdviceRecord {
    @Attribute(.unique) var id: UUID
    var ownerAccountID: String?
    var createdAt: Date
    var categoryRaw: String
    var toneRaw: String
    var adviceLine: String
    var rationaleLine: String?
    var isFavorite: Bool
    var voteRaw: Int?
    var aftermathNote: String?  // User's personal journal entry: what happened when they followed this advice
    var shareCount: Int?  // Optional so CloudKit can do a lightweight migration; use shareCountValue accessor
    var copyCount: Int?  // Optional so CloudKit can do a lightweight migration; use copyCountValue accessor

    init(
        id: UUID = UUID(),
        ownerAccountID: String? = nil,
        createdAt: Date,
        category: AdviceCategory,
        tone: ToneMode,
        adviceLine: String,
        rationaleLine: String?,
        isFavorite: Bool = false,
        vote: AdviceVoteState = .none,
        shareCount: Int = 0,
        copyCount: Int = 0
    ) {
        self.id = id
        self.ownerAccountID = ownerAccountID
        self.createdAt = createdAt
        self.categoryRaw = category.rawValue
        self.toneRaw = tone.rawValue
        self.adviceLine = adviceLine
        self.rationaleLine = rationaleLine
        self.isFavorite = isFavorite
        self.voteRaw = vote.rawValue
        self.shareCount = shareCount
        self.copyCount = copyCount
    }

    /// Non-optional convenience accessors — use these instead of the raw optional properties
    var shareCountValue: Int {
        get { shareCount ?? 0 }
        set { shareCount = newValue }
    }
    var copyCountValue: Int {
        get { copyCount ?? 0 }
        set { copyCount = newValue }
    }

    var category: AdviceCategory {
        AdviceCategory(rawValue: categoryRaw) ?? .productivity
    }

    var tone: ToneMode {
        ToneMode(rawValue: toneRaw) ?? .corporateConsultant
    }

    var vote: AdviceVoteState {
        get { AdviceVoteState(rawValue: voteRaw ?? 0) ?? .none }
        set { voteRaw = newValue.rawValue }
    }
}

@Model
final class AdviceFingerprint {
    @Attribute(.unique) var normalizedText: String
    var ownerAccountID: String?
    var createdAt: Date

    init(normalizedText: String, ownerAccountID: String? = nil, createdAt: Date = Date()) {
        self.normalizedText = normalizedText
        self.ownerAccountID = ownerAccountID
        self.createdAt = createdAt
    }
}

@Model
final class UserAdviceSuggestion {
    @Attribute(.unique) var id: UUID
    var ownerAccountID: String?
    var createdAt: Date
    var categoryRaw: String
    var topic: String
    var adviceLine: String

    init(
        id: UUID = UUID(),
        ownerAccountID: String? = nil,
        createdAt: Date = Date(),
        category: AdviceCategory,
        topic: String,
        adviceLine: String
    ) {
        self.id = id
        self.ownerAccountID = ownerAccountID
        self.createdAt = createdAt
        self.categoryRaw = category.rawValue
        self.topic = topic
        self.adviceLine = adviceLine
    }

    var category: AdviceCategory {
        AdviceCategory(rawValue: categoryRaw) ?? .productivity
    }
}

@Model
final class UserQuoteSuggestion {
    @Attribute(.unique) var id: UUID
    var ownerAccountID: String?
    var createdAt: Date
    var categoryRaw: String
    var source: String
    var quoteText: String

    init(
        id: UUID = UUID(),
        ownerAccountID: String? = nil,
        createdAt: Date = Date(),
        category: AdviceCategory,
        source: String,
        quoteText: String
    ) {
        self.id = id
        self.ownerAccountID = ownerAccountID
        self.createdAt = createdAt
        self.categoryRaw = category.rawValue
        self.source = source
        self.quoteText = quoteText
    }

    var category: AdviceCategory {
        AdviceCategory(rawValue: categoryRaw) ?? .productivity
    }
}

@Model
final class QuoteVoteRecord {
    @Attribute(.unique) var quoteID: String
    var ownerAccountID: String?
    var voteRaw: Int
    var updatedAt: Date

    init(
        quoteID: String,
        ownerAccountID: String? = nil,
        vote: AdviceVoteState = .none,
        updatedAt: Date = Date()
    ) {
        self.quoteID = quoteID
        self.ownerAccountID = ownerAccountID
        self.voteRaw = vote.rawValue
        self.updatedAt = updatedAt
    }

    var vote: AdviceVoteState {
        get { AdviceVoteState(rawValue: voteRaw) ?? .none }
        set { voteRaw = newValue.rawValue }
    }
}

@Model
final class LearningStatRecord {
    @Attribute(.unique) var scopeKey: String
    var ownerAccountID: String?
    var shownCount: Double
    var likeCount: Double
    var dislikeCount: Double
    var favoriteCount: Double
    var copyCount: Double
    var shareCount: Double
    var regenCount: Double
    var updatedAt: Date

    init(
        scopeKey: String,
        ownerAccountID: String? = nil,
        shownCount: Double = 0,
        likeCount: Double = 0,
        dislikeCount: Double = 0,
        favoriteCount: Double = 0,
        copyCount: Double = 0,
        shareCount: Double = 0,
        regenCount: Double = 0,
        updatedAt: Date = Date()
    ) {
        self.scopeKey = scopeKey
        self.ownerAccountID = ownerAccountID
        self.shownCount = shownCount
        self.likeCount = likeCount
        self.dislikeCount = dislikeCount
        self.favoriteCount = favoriteCount
        self.copyCount = copyCount
        self.shareCount = shareCount
        self.regenCount = regenCount
        self.updatedAt = updatedAt
    }

    var snapshot: LearningStatSnapshot {
        LearningStatSnapshot(
            shownCount: shownCount,
            likeCount: likeCount,
            dislikeCount: dislikeCount,
            favoriteCount: favoriteCount,
            copyCount: copyCount,
            shareCount: shareCount,
            regenCount: regenCount,
            lastUpdatedAt: updatedAt
        )
    }
}

@Model
final class MissionProgressRecord {
    @Attribute(.unique) var missionKey: String
    var ownerAccountID: String?
    var periodRaw: String
    var categoryRaw: String
    var toneRaw: String
    var targetCount: Int
    var progressCount: Int
    var rewardClaimed: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        missionKey: String,
        ownerAccountID: String? = nil,
        periodRaw: String = "weekly",
        category: AdviceCategory,
        tone: ToneMode,
        targetCount: Int,
        progressCount: Int = 0,
        rewardClaimed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.missionKey = missionKey
        self.ownerAccountID = ownerAccountID
        self.periodRaw = periodRaw
        self.categoryRaw = category.rawValue
        self.toneRaw = tone.rawValue
        self.targetCount = targetCount
        self.progressCount = progressCount
        self.rewardClaimed = rewardClaimed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: AdviceCategory {
        AdviceCategory(rawValue: categoryRaw) ?? .productivity
    }

    var tone: ToneMode {
        ToneMode(rawValue: toneRaw) ?? .corporateConsultant
    }
}

@Model
final class AppSettingsEntity {
    @Attribute(.unique) var id: UUID
    var ownerAccountID: String?
    var themeRaw: String
    var includeDisclaimerOnShare: Bool
    var reduceMotion: Bool
    var hapticsEnabled: Bool
    var soundEffectsEnabledRaw: Bool?
    var includeRationale: Bool
    var preferredTemplateRaw: String
    var preferredAspectRaw: String
    var preferredSharePresetRaw: String?
    var preferredContentPackRaw: String?
    var preferredGenerationProviderRaw: String?
    var strictNoRepeatsRaw: Bool?
    var communityOnlyModeRaw: Bool?
    var performanceModeRaw: Bool?
    var streakFreezeWeekKeyRaw: String?
    var streakFreezeUsedRaw: Bool?
    var streakFreezeProtectedDayRaw: String?
    var tabOrderRaw: String?
    var dailyNotificationsEnabledRaw: Bool?
    var streakNotificationsEnabledRaw: Bool?
    var dailyNotificationHourRaw: Int?
    init(
        id: UUID = UUID(),
        ownerAccountID: String? = nil,
        theme: ThemeMode = .badvice,
        includeDisclaimerOnShare: Bool = true,
        reduceMotion: Bool = false,
        hapticsEnabled: Bool = true,
        soundEffectsEnabled: Bool = true,
        includeRationale: Bool = true,
        preferredTemplate: ShareCardTemplate = .minimal,
        preferredAspect: ShareAspectRatio = .square,
        preferredSharePreset: ShareCaptionPreset = .deadpan,
        preferredContentPack: ContentPack = .classic,
        preferredGenerationProvider: AdviceGenerationProvider = .auto,
        strictNoRepeats: Bool = true,
        communityOnlyMode: Bool = false,
        performanceMode: Bool = false,
        tabOrder: [AppTab] = AppTab.defaultOrder
    ) {
        self.id = id
        self.ownerAccountID = ownerAccountID
        self.themeRaw = theme.rawValue
        self.includeDisclaimerOnShare = includeDisclaimerOnShare
        self.reduceMotion = reduceMotion
        self.hapticsEnabled = hapticsEnabled
        self.soundEffectsEnabledRaw = soundEffectsEnabled
        self.includeRationale = includeRationale
        self.preferredTemplateRaw = preferredTemplate.rawValue
        self.preferredAspectRaw = preferredAspect.rawValue
        self.preferredSharePresetRaw = preferredSharePreset.rawValue
        self.preferredContentPackRaw = preferredContentPack.rawValue
        self.preferredGenerationProviderRaw = preferredGenerationProvider.rawValue
        self.strictNoRepeatsRaw = strictNoRepeats
        self.communityOnlyModeRaw = communityOnlyMode
        self.performanceModeRaw = performanceMode
        self.streakFreezeWeekKeyRaw = nil
        self.streakFreezeUsedRaw = false
        self.streakFreezeProtectedDayRaw = nil
        self.tabOrderRaw = tabOrder.map(\.rawValue).joined(separator: ",")
    }

    var theme: ThemeMode {
        get { ThemeMode(rawValue: themeRaw) ?? .badvice }
        set { themeRaw = newValue.rawValue }
    }

    var soundEffectsEnabled: Bool {
        get { soundEffectsEnabledRaw ?? true }
        set { soundEffectsEnabledRaw = newValue }
    }

    var preferredTemplate: ShareCardTemplate {
        get { ShareCardTemplate(rawValue: preferredTemplateRaw) ?? .minimal }
        set { preferredTemplateRaw = newValue.rawValue }
    }

    var preferredAspect: ShareAspectRatio {
        get { ShareAspectRatio(rawValue: preferredAspectRaw) ?? .square }
        set { preferredAspectRaw = newValue.rawValue }
    }

    var preferredSharePreset: ShareCaptionPreset {
        get { ShareCaptionPreset(rawValue: preferredSharePresetRaw ?? "") ?? .deadpan }
        set { preferredSharePresetRaw = newValue.rawValue }
    }

    var preferredContentPack: ContentPack {
        get { ContentPack(rawValue: preferredContentPackRaw ?? "") ?? .classic }
        set { preferredContentPackRaw = newValue.rawValue }
    }

    var preferredGenerationProvider: AdviceGenerationProvider {
        get { AdviceGenerationProvider(rawValue: preferredGenerationProviderRaw ?? "") ?? .auto }
        set { preferredGenerationProviderRaw = newValue.rawValue }
    }

    var strictNoRepeats: Bool {
        get { strictNoRepeatsRaw ?? true }
        set { strictNoRepeatsRaw = newValue }
    }

    var communityOnlyMode: Bool {
        get { communityOnlyModeRaw ?? false }
        set { communityOnlyModeRaw = newValue }
    }

    var performanceMode: Bool {
        get { performanceModeRaw ?? false }
        set { performanceModeRaw = newValue }
    }

    var tabOrder: [AppTab] {
        get {
            let parts = (tabOrderRaw ?? "")
                .split(separator: ",")
                .compactMap { AppTab(rawValue: String($0)) }
            return Self.sanitizedTabOrder(parts)
        }
        set {
            tabOrderRaw = Self.sanitizedTabOrder(newValue).map(\.rawValue).joined(separator: ",")
        }
    }

    var dailyNotificationsEnabled: Bool {
        get { dailyNotificationsEnabledRaw ?? true }
        set { dailyNotificationsEnabledRaw = newValue }
    }

    var streakNotificationsEnabled: Bool {
        get { streakNotificationsEnabledRaw ?? true }
        set { streakNotificationsEnabledRaw = newValue }
    }

    var dailyNotificationHour: Int {
        get { dailyNotificationHourRaw ?? 9 }
        set { dailyNotificationHourRaw = newValue }
    }

    private static func sanitizedTabOrder(_ candidate: [AppTab]) -> [AppTab] {
        var ordered: [AppTab] = []
        var seen = Set<AppTab>()
        for tab in candidate where seen.insert(tab).inserted {
            ordered.append(tab)
        }
        for tab in AppTab.defaultOrder where seen.insert(tab).inserted {
            ordered.append(tab)
        }
        let middle = ordered.filter { $0 != .generate && $0 != .settings }
        return [.generate] + middle + [.settings]
    }
}

@MainActor
final class AdviceRepository {
    private static let defaultAccountKey = "__default__"
    private static let poolFingerprintPrefix = "pool::"
    private static let maxLearningScopes = 800
    private static let maxAdviceFingerprints = 1200

    let context: ModelContext
    let accountKey: String
    private var cachedSeenCount: Int?
    private var cachedFingerprintSet: Set<String>?
    private var cachedLearningStatsByKey: [String: LearningStatRecord]?

    init(context: ModelContext, accountKey: String = "__default__") {
        self.context = context
        self.accountKey = accountKey
        logger.debug("AdviceRepository initialized")
    }

    @discardableResult
    func insert(_ generated: GeneratedAdvice) -> AdviceRecord {
        let record = AdviceRecord(
            id: generated.id,
            ownerAccountID: accountKey,
            createdAt: generated.createdAt,
            category: generated.category,
            tone: generated.tone,
            adviceLine: generated.adviceLine,
            rationaleLine: generated.rationaleLine
        )
        context.insert(record)
        rememberAdviceFingerprint(
            generated.adviceLine.normalizedForFiltering,
            createdAt: generated.createdAt,
            saveChanges: false
        )
        rememberAdviceFingerprintInPool(
            generated.adviceLine.normalizedForFiltering,
            category: generated.category,
            tone: generated.tone,
            createdAt: generated.createdAt,
            saveChanges: false
        )
        save()
        cachedSeenCount = nil
        pruneHistory(maxCount: 50)
        logger.debug(
            "Inserted advice id=\(generated.id) category=\(generated.category.rawValue) tone=\(generated.tone.rawValue)"
        )
        return record
    }

    func fetchHistory(limit: Int = 50) -> [AdviceRecord] {
        Array(fetchAllHistory().prefix(limit))
    }

    func fetchAllHistory() -> [AdviceRecord] {
        let descriptor = FetchDescriptor<AdviceRecord>(
            sortBy: [SortDescriptor(\AdviceRecord.createdAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
    }

    func fetchFavorites() -> [AdviceRecord] {
        fetchAllHistory().filter(\.isFavorite)
    }

    func thisWeekFavorites() -> [AdviceRecord] {
        let cutoff = Date().addingTimeInterval(-7 * 86_400)
        let all = fetchFavorites()
        return Array(
            all.filter { $0.createdAt >= cutoff }
                .sorted { ($0.voteRaw ?? 0) > ($1.voteRaw ?? 0) }
                .prefix(3))
    }

    func historyCount() -> Int {
        fetchAllHistory().count
    }

    // MARK: - Leaderboard helpers

    func incrementShareCount(for id: UUID) {
        guard let record = fetchRecord(id: id) else { return }
        record.shareCountValue += 1
        try? context.save()
    }

    func incrementCopyCount(for id: UUID) {
        guard let record = fetchRecord(id: id) else { return }
        record.copyCountValue += 1
        try? context.save()
    }

    private func fetchRecord(id: UUID) -> AdviceRecord? {
        let predicate = #Predicate<AdviceRecord> { $0.id == id }
        var descriptor = FetchDescriptor<AdviceRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first(where: { matchesActiveAccount($0.ownerAccountID) })
    }

    func topByShares(limit: Int = 5) -> [AdviceRecord] {
        let all = fetchAllHistory()
        return Array(
            all.filter { $0.shareCountValue > 0 }.sorted { $0.shareCountValue > $1.shareCountValue }
                .prefix(limit))
    }

    func topByCopies(limit: Int = 5) -> [AdviceRecord] {
        let all = fetchAllHistory()
        return Array(
            all.filter { $0.copyCountValue > 0 }.sorted { $0.copyCountValue > $1.copyCountValue }
                .prefix(limit))
    }

    func topByLikes(limit: Int = 5) -> [AdviceRecord] {
        let all = fetchAllHistory()
        return Array(
            all.filter { ($0.voteRaw ?? 0) > 0 }.sorted { ($0.voteRaw ?? 0) > ($1.voteRaw ?? 0) }
                .prefix(limit))
    }

    func favoriteCount() -> Int {
        fetchFavorites().count
    }

    func todayHistoryCount(referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? referenceDate
        return fetchAllHistory().reduce(into: 0) { count, record in
            if record.createdAt >= startOfDay, record.createdAt < endOfDay {
                count += 1
            }
        }
    }

    func todayHistoryCount(
        category: AdviceCategory,
        tone: ToneMode,
        referenceDate: Date = Date()
    ) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? referenceDate
        let categoryRaw = category.rawValue
        let toneRaw = tone.rawValue

        // Avoid SwiftData predicates on computed enum accessors (`category`/`tone`).
        // Filtering on persisted raw fields keeps this resilient across device stores.
        return fetchAllHistory().reduce(into: 0) { count, record in
            guard record.createdAt >= startOfDay, record.createdAt < endOfDay else { return }
            if record.categoryRaw == categoryRaw && record.toneRaw == toneRaw {
                count += 1
            }
        }
    }

    func setFavorite(_ record: AdviceRecord, isFavorite: Bool) {
        record.isFavorite = isFavorite
        save()
    }

    func setVote(_ record: AdviceRecord, vote: AdviceVoteState) {
        record.vote = vote
        save()
    }

    func toggleFavorite(_ record: AdviceRecord) {
        record.isFavorite.toggle()
        save()
        // #18 Spotlight Search — index when saving, remove when un-saving
        if record.isFavorite {
            SpotlightManager.index(record)
        } else {
            SpotlightManager.remove(id: record.id)
        }
    }

    func setAftermathNote(_ record: AdviceRecord, note: String) {
        record.aftermathNote = note.isEmpty ? nil : note
        save()
    }

    func delete(_ record: AdviceRecord) {
        // #18 Remove from Spotlight when deleting
        SpotlightManager.remove(id: record.id)
        context.delete(record)
        save()
    }

    func purgeAllHistory() {
        fetchAllHistory().forEach { context.delete($0) }
        fetchAdviceFingerprints().forEach { context.delete($0) }
        cachedFingerprintSet = nil
        cachedSeenCount = nil
        save()
    }

    func ensureSettings() -> AppSettingsEntity {
        let descriptor = FetchDescriptor<AppSettingsEntity>()
        if let existing = ((try? context.fetch(descriptor)) ?? []).first(where: {
            matchesActiveAccount($0.ownerAccountID)
        }) {
            return existing
        }
        let created = AppSettingsEntity(ownerAccountID: accountKey)
        context.insert(created)
        save()
        return created
    }

    func missionProgress(for missionKey: String) -> MissionProgressRecord? {
        let scopedMissionKey = scopedMissionKey(missionKey)
        let predicate = #Predicate<MissionProgressRecord> { $0.missionKey == scopedMissionKey }
        var descriptor = FetchDescriptor<MissionProgressRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\MissionProgressRecord.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first(where: { matchesActiveAccount($0.ownerAccountID) })
    }

    @discardableResult
    func ensureMissionProgress(
        missionKey: String,
        periodRaw: String = "weekly",
        category: AdviceCategory,
        tone: ToneMode,
        targetCount: Int
    ) -> MissionProgressRecord {
        if let existing = missionProgress(for: missionKey) {
            var didChange = false
            if existing.category != category {
                existing.categoryRaw = category.rawValue
                didChange = true
            }
            if existing.tone != tone {
                existing.toneRaw = tone.rawValue
                didChange = true
            }
            if existing.targetCount != targetCount {
                existing.targetCount = targetCount
                existing.progressCount = min(existing.progressCount, targetCount)
                didChange = true
            }
            if existing.periodRaw != periodRaw {
                existing.periodRaw = periodRaw
                didChange = true
            }
            if didChange {
                existing.updatedAt = Date()
                save()
            }
            return existing
        }

        let created = MissionProgressRecord(
            missionKey: scopedMissionKey(missionKey),
            ownerAccountID: accountKey,
            periodRaw: periodRaw,
            category: category,
            tone: tone,
            targetCount: targetCount
        )
        context.insert(created)
        save()
        return created
    }

    @discardableResult
    func incrementMissionProgress(
        missionKey: String,
        periodRaw: String = "weekly",
        category: AdviceCategory,
        tone: ToneMode,
        targetCount: Int,
        by delta: Int = 1
    ) -> MissionProgressRecord {
        let record = ensureMissionProgress(
            missionKey: missionKey,
            periodRaw: periodRaw,
            category: category,
            tone: tone,
            targetCount: targetCount
        )
        guard delta > 0 else { return record }
        let nextValue = min(record.targetCount, record.progressCount + delta)
        guard nextValue != record.progressCount else { return record }
        record.progressCount = nextValue
        record.updatedAt = Date()
        save()
        return record
    }

    func markMissionRewardClaimed(missionKey: String) {
        guard let record = missionProgress(for: missionKey) else { return }
        guard !record.rewardClaimed else { return }
        record.rewardClaimed = true
        record.updatedAt = Date()
        save()
    }

    func hasSeenAdvice(_ normalizedAdviceLine: String) -> Bool {
        let normalized = scopedFingerprintKey(normalizedAdviceLine.normalizedForFiltering)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        ensureFingerprintCache()
        return cachedFingerprintSet?.contains(normalized) ?? false
    }

    func rememberAdviceFingerprint(
        _ normalizedAdviceLine: String,
        createdAt: Date = Date(),
        saveChanges: Bool = true
    ) {
        let normalized = scopedFingerprintKey(normalizedAdviceLine.normalizedForFiltering)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        ensureFingerprintCache()
        guard !(cachedFingerprintSet?.contains(normalized) ?? false) else { return }
        context.insert(
            AdviceFingerprint(normalizedText: normalized, ownerAccountID: accountKey, createdAt: createdAt)
        )
        cachedFingerprintSet?.insert(normalized)
        cachedSeenCount = nil
        pruneAdviceFingerprints(maxCount: Self.maxAdviceFingerprints)
        if saveChanges {
            save()
        }
    }

    func hasSeenAdviceInPool(
        _ normalizedAdviceLine: String,
        category: AdviceCategory,
        tone: ToneMode
    ) -> Bool {
        let normalized = poolFingerprint(
            for: normalizedAdviceLine,
            category: category,
            tone: tone
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        ensureFingerprintCache()
        return cachedFingerprintSet?.contains(normalized) ?? false
    }

    func rememberAdviceFingerprintInPool(
        _ normalizedAdviceLine: String,
        category: AdviceCategory,
        tone: ToneMode,
        createdAt: Date = Date(),
        saveChanges: Bool = true
    ) {
        let normalized = poolFingerprint(
            for: normalizedAdviceLine,
            category: category,
            tone: tone
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        ensureFingerprintCache()
        guard !(cachedFingerprintSet?.contains(normalized) ?? false) else { return }
        context.insert(
            AdviceFingerprint(normalizedText: normalized, ownerAccountID: accountKey, createdAt: createdAt)
        )
        cachedFingerprintSet?.insert(normalized)
        cachedSeenCount = nil
        pruneAdviceFingerprints(maxCount: Self.maxAdviceFingerprints)
        if saveChanges {
            save()
        }
    }

    func seenAdviceCount() -> Int {
        if let cached = cachedSeenCount { return cached }
        ensureFingerprintCache()
        let count = (cachedFingerprintSet ?? [])
            .filter { !$0.contains("::\(Self.poolFingerprintPrefix)") }
            .count
        cachedSeenCount = count
        return count
    }

    func seedAdviceMemoryFromHistoryIfNeeded() {
        guard seenAdviceCount() == 0 else { return }
        let history = fetchAllHistory()
        guard !history.isEmpty else { return }
        var seenGlobal = Set<String>()
        var seenPool = Set<String>()
        for record in history {
            let normalizedGlobal = record.adviceLine.normalizedForFiltering
            if seenGlobal.insert(normalizedGlobal).inserted {
                context.insert(
                    AdviceFingerprint(
                        normalizedText: scopedFingerprintKey(normalizedGlobal),
                        ownerAccountID: accountKey,
                        createdAt: record.createdAt
                    )
                )
            }
            let normalizedPool = poolFingerprint(
                for: record.adviceLine.normalizedForFiltering,
                category: record.category,
                tone: record.tone
            )
            if seenPool.insert(normalizedPool).inserted {
                context.insert(
                    AdviceFingerprint(
                        normalizedText: normalizedPool,
                        ownerAccountID: accountKey,
                        createdAt: record.createdAt
                    ))
            }
        }
        pruneAdviceFingerprints(maxCount: Self.maxAdviceFingerprints)
        save()
        cachedFingerprintSet = nil
        cachedSeenCount = nil
    }

    @discardableResult
    func addSuggestion(
        category: AdviceCategory,
        topic: String,
        adviceLine: String
    ) -> UserAdviceSuggestion {
        let suggestion = UserAdviceSuggestion(
            ownerAccountID: accountKey,
            category: category,
            topic: topic,
            adviceLine: adviceLine
        )
        context.insert(suggestion)
        save()
        pruneSuggestions(maxCount: 250)
        return suggestion
    }

    @discardableResult
    func addQuoteSuggestion(
        category: AdviceCategory,
        source: String,
        quoteText: String
    ) -> UserQuoteSuggestion {
        let suggestion = UserQuoteSuggestion(
            ownerAccountID: accountKey,
            category: category,
            source: source,
            quoteText: quoteText
        )
        context.insert(suggestion)
        save()
        pruneQuoteSuggestions(maxCount: 250)
        return suggestion
    }

    func fetchSuggestions(limit: Int = 40) -> [UserAdviceSuggestion] {
        let descriptor = FetchDescriptor<UserAdviceSuggestion>(
            sortBy: [SortDescriptor(\UserAdviceSuggestion.createdAt, order: .reverse)]
        )
        return Array((((try? context.fetch(descriptor)) ?? []).filter {
            matchesActiveAccount($0.ownerAccountID)
        }).prefix(limit))
    }

    func fetchQuoteSuggestions(limit: Int = 60) -> [UserQuoteSuggestion] {
        let descriptor = FetchDescriptor<UserQuoteSuggestion>(
            sortBy: [SortDescriptor(\UserQuoteSuggestion.createdAt, order: .reverse)]
        )
        return Array((((try? context.fetch(descriptor)) ?? []).filter {
            matchesActiveAccount($0.ownerAccountID)
        }).prefix(limit))
    }

    func suggestionCount() -> Int {
        fetchSuggestions(limit: Int.max).count
    }

    func quoteSuggestionCount() -> Int {
        fetchQuoteSuggestions(limit: Int.max).count
    }

    func deleteSuggestion(_ suggestion: UserAdviceSuggestion) {
        context.delete(suggestion)
        save()
    }

    func deleteQuoteSuggestion(_ suggestion: UserQuoteSuggestion) {
        context.delete(suggestion)
        save()
    }

    func setQuoteVote(quoteID: String, vote: AdviceVoteState) {
        let existing = quoteVoteRecord(for: quoteID)
        if vote == .none {
            if let existing {
                context.delete(existing)
                save()
            }
            return
        }
        if let existing {
            existing.vote = vote
            existing.updatedAt = Date()
        } else {
            context.insert(
                QuoteVoteRecord(
                    quoteID: scopedQuoteID(quoteID),
                    ownerAccountID: accountKey,
                    vote: vote,
                    updatedAt: Date()
                )
            )
        }
        save()
    }

    func quoteVote(for quoteID: String) -> AdviceVoteState {
        quoteVoteRecord(for: quoteID)?.vote ?? .none
    }

    func quoteVoteMap() -> [String: AdviceVoteState] {
        let descriptor = FetchDescriptor<QuoteVoteRecord>(
            sortBy: [SortDescriptor(\QuoteVoteRecord.updatedAt, order: .reverse)]
        )
        let all = ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
        return Dictionary(uniqueKeysWithValues: all.map { (unscopedQuoteID($0.quoteID), $0.vote) })
    }

    func recordLearningSignal(scopeKey: String, type: LearningSignalType, weight: Double = 1.0) {
        let normalizedKey = scopedLearningScope(scopeKey
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines))
        let delta = max(weight, 0)
        guard !normalizedKey.isEmpty, delta > 0 else { return }

        ensureLearningCache()
        let record: LearningStatRecord
        if let existing = cachedLearningStatsByKey?[normalizedKey] {
            record = existing
        } else {
            record = LearningStatRecord(scopeKey: normalizedKey, ownerAccountID: accountKey)
            context.insert(record)
            cachedLearningStatsByKey?[normalizedKey] = record
        }

        switch type {
        case .shown:
            record.shownCount += delta
        case .like:
            record.likeCount += delta
        case .dislike:
            record.dislikeCount += delta
        case .favorite:
            record.favoriteCount += delta
        case .copy:
            record.copyCount += delta
        case .share:
            record.shareCount += delta
        case .regen:
            record.regenCount += delta
        }
        record.updatedAt = Date()

        pruneLearningStats(maxCount: Self.maxLearningScopes)
        save()
    }

    func learningStat(for scopeKey: String) -> LearningStatRecord? {
        let normalizedKey = scopedLearningScope(scopeKey
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines))
        guard !normalizedKey.isEmpty else { return nil }
        ensureLearningCache()
        return cachedLearningStatsByKey?[normalizedKey]
    }

    func learningSnapshot(for scopeKey: String) -> LearningStatSnapshot {
        learningStat(for: scopeKey)?.snapshot ?? .empty
    }

    func learningStats(prefix: String) -> [LearningStatRecord] {
        let normalizedPrefix = prefix
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let scopedPrefix = scopedLearningScope(normalizedPrefix)
        ensureLearningCache()
        return (cachedLearningStatsByKey ?? [:])
            .values
            .filter { normalizedPrefix.isEmpty || $0.scopeKey.hasPrefix(scopedPrefix) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Total explicit interaction signals across all scopes. Used for adaptive profile selection.
    func totalLearningSignalCount() -> Int {
        ensureLearningCache()
        return (cachedLearningStatsByKey ?? [:]).values.reduce(0) { sum, stat in
            sum
                + Int(
                    stat.likeCount + stat.dislikeCount + stat.favoriteCount
                        + stat.copyCount + stat.shareCount + stat.regenCount)
        }
    }

    func pruneSuggestions(maxCount: Int) {
        guard maxCount > 0 else { return }
        let descriptor = FetchDescriptor<UserAdviceSuggestion>(
            sortBy: [SortDescriptor(\UserAdviceSuggestion.createdAt, order: .reverse)]
        )
        let all = ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        save()
    }

    func pruneQuoteSuggestions(maxCount: Int) {
        guard maxCount > 0 else { return }
        let descriptor = FetchDescriptor<UserQuoteSuggestion>(
            sortBy: [SortDescriptor(\UserQuoteSuggestion.createdAt, order: .reverse)]
        )
        let all = ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        save()
    }

    func pruneHistory(maxCount: Int) {
        guard maxCount > 0 else { return }
        let all = fetchAllHistory()
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        save()
    }

    func save() {
        do {
            try context.save()
        } catch {
            logger.error("SwiftData save failed: \(error.localizedDescription)")
        }
    }

    private func poolFingerprint(
        for normalizedAdviceLine: String,
        category: AdviceCategory,
        tone: ToneMode
    ) -> String {
        let normalized = normalizedAdviceLine.normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return scopedFingerprintKey(
            "\(Self.poolFingerprintPrefix)\(category.rawValue)|\(tone.rawValue)|\(normalized)"
        )
    }

    private func ensureFingerprintCache() {
        guard cachedFingerprintSet == nil else { return }
        var descriptor = FetchDescriptor<AdviceFingerprint>(
            sortBy: [SortDescriptor(\AdviceFingerprint.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.maxAdviceFingerprints
        let all = ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
        cachedFingerprintSet = Set(all.map(\.normalizedText))
    }

    private func ensureLearningCache() {
        guard cachedLearningStatsByKey == nil else { return }
        let descriptor = FetchDescriptor<LearningStatRecord>()
        let all = ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
        cachedLearningStatsByKey = Dictionary(uniqueKeysWithValues: all.map { ($0.scopeKey, $0) })
    }

    func pruneAdviceFingerprints(maxCount: Int) {
        guard maxCount > 0 else { return }
        let descriptor = FetchDescriptor<AdviceFingerprint>(
            sortBy: [SortDescriptor(\AdviceFingerprint.createdAt, order: .reverse)]
        )
        let all = ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        cachedFingerprintSet = nil
        cachedSeenCount = nil
    }

    private func pruneLearningStats(maxCount: Int) {
        guard maxCount > 0 else { return }
        ensureLearningCache()
        guard let current = cachedLearningStatsByKey, current.count > maxCount else { return }
        let ordered = current.values.sorted { $0.updatedAt > $1.updatedAt }
        for stale in ordered.suffix(from: maxCount) {
            context.delete(stale)
            cachedLearningStatsByKey?.removeValue(forKey: stale.scopeKey)
        }
    }

    private func quoteVoteRecord(for quoteID: String) -> QuoteVoteRecord? {
        let scopedQuoteID = scopedQuoteID(quoteID)
        let predicate = #Predicate<QuoteVoteRecord> { $0.quoteID == scopedQuoteID }
        var descriptor = FetchDescriptor<QuoteVoteRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\QuoteVoteRecord.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first(where: { matchesActiveAccount($0.ownerAccountID) })
    }

    func purgeCurrentAccountData() {
        fetchAllHistory().forEach { context.delete($0) }
        fetchAdviceFingerprints().forEach { context.delete($0) }
        fetchAdviceSuggestions().forEach { context.delete($0) }
        fetchQuoteSuggestionsAll().forEach { context.delete($0) }
        fetchQuoteVoteRecords().forEach { context.delete($0) }
        fetchLearningStatRecords().forEach { context.delete($0) }
        fetchMissionProgressRecords().forEach { context.delete($0) }
        if let settings = currentSettingsEntity() {
            context.delete(settings)
        }
        cachedFingerprintSet = nil
        cachedSeenCount = nil
        cachedLearningStatsByKey = nil
        save()
    }

    func purgeAllLocalData() {
        deleteAll(AdviceRecord.self)
        deleteAll(AdviceFingerprint.self)
        deleteAll(UserAdviceSuggestion.self)
        deleteAll(UserQuoteSuggestion.self)
        deleteAll(QuoteVoteRecord.self)
        deleteAll(LearningStatRecord.self)
        deleteAll(MissionProgressRecord.self)
        deleteAll(AppSettingsEntity.self)
        cachedFingerprintSet = nil
        cachedSeenCount = nil
        cachedLearningStatsByKey = nil
        save()
    }

    private func currentSettingsEntity() -> AppSettingsEntity? {
        let descriptor = FetchDescriptor<AppSettingsEntity>()
        return ((try? context.fetch(descriptor)) ?? []).first(where: { matchesActiveAccount($0.ownerAccountID) })
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let descriptor = FetchDescriptor<T>()
        ((try? context.fetch(descriptor)) ?? []).forEach { context.delete($0) }
    }

    private func fetchAdviceFingerprints() -> [AdviceFingerprint] {
        let descriptor = FetchDescriptor<AdviceFingerprint>(
            sortBy: [SortDescriptor(\AdviceFingerprint.createdAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
    }

    private func fetchAdviceSuggestions() -> [UserAdviceSuggestion] {
        let descriptor = FetchDescriptor<UserAdviceSuggestion>(
            sortBy: [SortDescriptor(\UserAdviceSuggestion.createdAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
    }

    private func fetchQuoteSuggestionsAll() -> [UserQuoteSuggestion] {
        let descriptor = FetchDescriptor<UserQuoteSuggestion>(
            sortBy: [SortDescriptor(\UserQuoteSuggestion.createdAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
    }

    private func fetchQuoteVoteRecords() -> [QuoteVoteRecord] {
        let descriptor = FetchDescriptor<QuoteVoteRecord>(
            sortBy: [SortDescriptor(\QuoteVoteRecord.updatedAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
    }

    private func fetchLearningStatRecords() -> [LearningStatRecord] {
        let descriptor = FetchDescriptor<LearningStatRecord>()
        return ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
    }

    private func fetchMissionProgressRecords() -> [MissionProgressRecord] {
        let descriptor = FetchDescriptor<MissionProgressRecord>(
            sortBy: [SortDescriptor(\MissionProgressRecord.updatedAt, order: .reverse)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { matchesActiveAccount($0.ownerAccountID) }
    }

    private func matchesActiveAccount(_ ownerAccountID: String?) -> Bool {
        (ownerAccountID ?? Self.defaultAccountKey) == accountKey
    }

    private func scopedFingerprintKey(_ value: String) -> String {
        "\(accountKey)::\(value)"
    }

    private func scopedLearningScope(_ value: String) -> String {
        "\(accountKey)::\(value)"
    }

    private func scopedMissionKey(_ missionKey: String) -> String {
        "\(accountKey)::\(missionKey)"
    }

    private func scopedQuoteID(_ quoteID: String) -> String {
        "\(accountKey)::\(quoteID)"
    }

    private func unscopedQuoteID(_ quoteID: String) -> String {
        if let range = quoteID.range(of: "::") {
            return String(quoteID[range.upperBound...])
        }
        return quoteID
    }
}

@MainActor
@Observable
final class SettingsViewModel {
    private let repository: AdviceRepository
    @ObservationIgnored let localModelStore: LocalModelStore
    @ObservationIgnored private var localModelStoreCancellable: AnyCancellable?
    private(set) var settings: AppSettingsEntity
    private(set) var appleOnDeviceModelAvailability: AppleOnDeviceModelAvailability =
        AppleOnDeviceAdviceBridge.currentAvailability()
    private(set) var isPreparingAppleOnDeviceModel: Bool = false
    private(set) var appleOnDeviceModelStatusLastUpdatedAt: Date = Date()

    init(repository: AdviceRepository, localModelStore: LocalModelStore) {
        self.repository = repository
        self.localModelStore = localModelStore
        self.settings = repository.ensureSettings()
        self.localModelStoreCancellable = localModelStore.objectWillChange.sink { [weak self] _ in
            Task { [weak self] in
                await MainActor.run {
                    self?.appleOnDeviceModelStatusLastUpdatedAt = Date()
                }
            }
        }
        localModelStore.reloadAvailableModels()
        refreshAppleOnDeviceModelAvailability()
        normalizeStreakFreezeState(for: Date())
        NotificationManager.updateStreakFreezeAvailability(
            hasAvailable: streakFreezeAvailableThisWeek)
    }

    convenience init(repository: AdviceRepository) {
        self.init(repository: repository, localModelStore: LocalModelStore())
    }

    var theme: ThemeMode {
        get { settings.theme }
        set {
            settings.theme = newValue
            repository.save()
        }
    }

    var includeDisclaimerOnShare: Bool {
        get { settings.includeDisclaimerOnShare }
        set {
            settings.includeDisclaimerOnShare = newValue
            repository.save()
        }
    }

    var reduceMotion: Bool {
        get { settings.reduceMotion }
        set {
            settings.reduceMotion = newValue
            repository.save()
        }
    }

    var hapticsEnabled: Bool {
        get { settings.hapticsEnabled }
        set {
            settings.hapticsEnabled = newValue
            repository.save()
        }
    }

    var performanceMode: Bool {
        get { settings.performanceMode }
        set {
            settings.performanceMode = newValue
            repository.save()
        }
    }

    var dailyNotificationsEnabled: Bool {
        get { settings.dailyNotificationsEnabled }
        set {
            settings.dailyNotificationsEnabled = newValue
            repository.save()
            if newValue {
                NotificationManager.requestPermissionAndScheduleDaily(hour: settings.dailyNotificationHour)
            } else {
                NotificationManager.cancelDailyNotification()
            }
        }
    }

    var streakNotificationsEnabled: Bool {
        get { settings.streakNotificationsEnabled }
        set {
            settings.streakNotificationsEnabled = newValue
            repository.save()
            NotificationManager.scheduleDaily(hour: settings.dailyNotificationHour, streakEnabled: newValue)
        }
    }

    var dailyNotificationHour: Int {
        get { settings.dailyNotificationHour }
        set {
            settings.dailyNotificationHour = newValue
            repository.save()
            if settings.dailyNotificationsEnabled {
                NotificationManager.scheduleDaily(hour: newValue, streakEnabled: settings.streakNotificationsEnabled)
            }
        }
    }

    var includeRationale: Bool {
        get { settings.includeRationale }
        set {
            settings.includeRationale = newValue
            repository.save()
        }
    }

    var preferredTemplate: ShareCardTemplate {
        get { settings.preferredTemplate }
        set {
            settings.preferredTemplate = newValue
            repository.save()
        }
    }

    var preferredAspect: ShareAspectRatio {
        get { settings.preferredAspect }
        set {
            settings.preferredAspect = newValue
            repository.save()
        }
    }

    var preferredSharePreset: ShareCaptionPreset {
        get { settings.preferredSharePreset }
        set {
            settings.preferredSharePreset = newValue
            repository.save()
        }
    }

    var preferredContentPack: ContentPack {
        get { settings.preferredContentPack }
        set {
            settings.preferredContentPack = newValue
            repository.save()
        }
    }

    var preferredGenerationProvider: AdviceGenerationProvider {
        get { settings.preferredGenerationProvider }
        set {
            settings.preferredGenerationProvider = newValue
            repository.save()
            refreshAppleOnDeviceModelAvailability()
        }
    }

    var appleOnDeviceModelStatusText: String {
        appleOnDeviceModelStatusSummary.message
    }

    var appleOnDeviceModelStatusKey: String {
        appleOnDeviceModelStatusSummary.key
    }

    var appleOnDeviceModelStatusBadgeText: String {
        appleOnDeviceModelStatusSummary.pill
    }

    var appleOnDeviceModelSetupHintText: String {
        appleOnDeviceModelStatusSummary.hint
    }

    var appleOnDeviceModelWarningText: String? {
        appleOnDeviceModelStatusSummary.warning
    }

    var canPrepareAppleOnDeviceModel: Bool {
        let selectedID = localModelStore.selectedModelID ?? localModelStore.availableModels.first?.id
        guard let selectedID else { return false }
        switch localModelStore.state(for: selectedID) {
        case .ready:
            return true
        default:
            return true
        }
    }

    var recommendedAppleOnDeviceActionTitle: String {
        guard let selectedID = localModelStore.selectedModelID ?? localModelStore.availableModels.first?.id
        else {
            return "Recheck"
        }
        if let selected = localModelStore.availableModels.first(where: { $0.id == selectedID }) {
            if !selected.isInstalled { return "Install Local Model" }
        }
        switch localModelStore.state(for: selectedID) {
        case .ready:
            return "Warm Up Local Model"
        case .installing:
            return "Prepare / Download Local Model"
        default:
            return "Warm Up Local Model"
        }
    }

    var shouldShowOpenAppSettingsShortcut: Bool {
        appleOnDeviceModelStatusSummary.shouldShowSettingsShortcut
    }

    func refreshAppleOnDeviceModelAvailability() {
        appleOnDeviceModelAvailability = AppleOnDeviceAdviceBridge.currentAvailability()
        localModelStore.reloadAvailableModels()
        appleOnDeviceModelStatusLastUpdatedAt = Date()
    }

    func prepareAppleOnDeviceModel() async {
        guard !isPreparingAppleOnDeviceModel else { return }
        isPreparingAppleOnDeviceModel = true
        defer {
            isPreparingAppleOnDeviceModel = false
            refreshAppleOnDeviceModelAvailability()
        }

        refreshAppleOnDeviceModelAvailability()
        guard let targetID = localModelStore.selectedModelID ?? localModelStore.availableModels.first?.id else {
            return
        }
        localModelStore.selectModel(targetID)
        if let target = localModelStore.availableModels.first(where: { $0.id == targetID }), !target.isInstalled {
            try? await localModelStore.installModel(id: targetID)
        }
        if localModelStore.state(for: targetID) != .ready {
            await localModelStore.warmUp(id: targetID)
        }
        refreshAppleOnDeviceModelAvailability()
    }

    func installAppleLocalModel(id: String) async {
        do {
            try await localModelStore.installModel(id: id)
        } catch {
            appleOnDeviceModelStatusLastUpdatedAt = Date()
        }
        refreshAppleOnDeviceModelAvailability()
    }

    func removeAppleLocalModel(id: String) async {
        await localModelStore.removeModel(id: id)
        refreshAppleOnDeviceModelAvailability()
    }

    func warmUpAppleLocalModel(id: String) async {
        await localModelStore.warmUp(id: id)
        refreshAppleOnDeviceModelAvailability()
    }

    func selectAppleLocalModel(id: String?) {
        localModelStore.selectModel(id)
        appleOnDeviceModelStatusLastUpdatedAt = Date()
    }

    var appleLocalModels: [LocalModelDescriptor] {
        _ = appleOnDeviceModelStatusLastUpdatedAt
        return localModelStore.availableModels
    }

    var selectedAppleLocalModelID: String? {
        get {
            _ = appleOnDeviceModelStatusLastUpdatedAt
            return localModelStore.selectedModelID
        }
        set { selectAppleLocalModel(id: newValue) }
    }

    func appleLocalModelInstallState(for id: String) -> LocalModelInstallState {
        _ = appleOnDeviceModelStatusLastUpdatedAt
        return localModelStore.state(for: id)
    }

    var appleLocalGenerationGate: LocalModelStore.GenerationGate {
        _ = appleOnDeviceModelStatusLastUpdatedAt
        return localModelStore.generationGate(
            appleAvailability: AppleOnDeviceAdviceBridge.currentAvailability())
    }

    private var appleOnDeviceModelStatusSummary: (
        key: String,
        message: String,
        hint: String,
        pill: String,
        warning: String?,
        shouldShowSettingsShortcut: Bool
    ) {
        _ = appleOnDeviceModelStatusLastUpdatedAt
        return localModelStore.effectiveStatus(for: preferredGenerationProvider)
    }

    var strictNoRepeats: Bool {
        get { settings.strictNoRepeats }
        set {
            settings.strictNoRepeats = newValue
            repository.save()
        }
    }

    var communityOnlyMode: Bool {
        get { settings.communityOnlyMode }
        set {
            settings.communityOnlyMode = newValue
            repository.save()
        }
    }

    var tabOrder: [AppTab] {
        get { settings.tabOrder }
        set {
            settings.tabOrder = newValue
            repository.save()
        }
    }

    var reorderableTabs: [AppTab] {
        AppTab.primaryNavigationTabs.filter { $0 != .generate }
    }

    func moveReorderableTabs(from source: IndexSet, to destination: Int) {
        var items = reorderableTabs
        let moving = source.sorted().map { items[$0] }
        for index in source.sorted(by: >) {
            items.remove(at: index)
        }
        let insertion = max(0, min(destination, items.count))
        items.insert(contentsOf: moving, at: insertion)
        applyPrimaryTabOrder(items)
    }

    func moveReorderableTabUp(at index: Int) {
        var items = reorderableTabs
        guard index > 0, index < items.count else { return }
        items.swapAt(index, index - 1)
        applyPrimaryTabOrder(items)
    }

    func moveReorderableTabDown(at index: Int) {
        var items = reorderableTabs
        guard index >= 0, index < items.count - 1 else { return }
        items.swapAt(index, index + 1)
        applyPrimaryTabOrder(items)
    }

    func resetTabOrder() {
        tabOrder = AppTab.defaultOrder
    }

    private func applyPrimaryTabOrder(_ primaryItems: [AppTab]) {
        let pinnedTabs = Set([AppTab.generate] + primaryItems)
        let overflowItems = AppTab.allCases.filter { !pinnedTabs.contains($0) }
        tabOrder = [.generate] + primaryItems + overflowItems
    }

    var streakFreezeAvailableThisWeek: Bool {
        normalizeStreakFreezeState(for: Date())
        return !(settings.streakFreezeUsedRaw ?? false)
    }

    func isStreakFreezeActive(for date: Date = Date()) -> Bool {
        normalizeStreakFreezeState(for: date)
        return settings.streakFreezeProtectedDayRaw == Self.dayKey(for: date)
    }

    @discardableResult
    func consumeStreakFreezeIfAvailable(for date: Date = Date()) -> Bool {
        normalizeStreakFreezeState(for: date)
        let dayKey = Self.dayKey(for: date)

        if settings.streakFreezeProtectedDayRaw == dayKey {
            return true
        }
        guard !(settings.streakFreezeUsedRaw ?? false) else { return false }

        settings.streakFreezeUsedRaw = true
        settings.streakFreezeProtectedDayRaw = dayKey
        repository.save()
        NotificationManager.updateStreakFreezeAvailability(hasAvailable: false)
        return true
    }

    private func normalizeStreakFreezeState(for date: Date) {
        let weekKey = Self.weekKey(for: date)
        if settings.streakFreezeWeekKeyRaw != weekKey {
            settings.streakFreezeWeekKeyRaw = weekKey
            settings.streakFreezeUsedRaw = false
            settings.streakFreezeProtectedDayRaw = nil
            repository.save()
        }
        NotificationManager.updateStreakFreezeAvailability(
            hasAvailable: !(settings.streakFreezeUsedRaw ?? false))
    }

    private static func dayKey(for date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func weekKey(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return "\(year)-W\(week)"
    }
}

struct BadQuoteService: Sendable {
    let quotes: [BadQuote]

    init(quotes: [BadQuote] = Self.defaultQuotes) {
        self.quotes = quotes
    }

    func quoteOfDay(now: Date = Date()) -> BadQuote {
        let shared = SharedDailyQuoteSource.quoteOfDay(for: now)
        return BadQuote(
            id: shared.id,
            text: shared.text,
            source: shared.source,
            category: AdviceCategory(rawValue: shared.categoryRaw) ?? .productivity
        )
    }

    func randomQuote(excluding excludedID: String? = nil, seed: Int? = nil) -> BadQuote {
        let bank = quotes.isEmpty ? Self.defaultQuotes : quotes
        guard !bank.isEmpty else {
            return BadQuote(
                id: "fallback",
                text: "Never revise a bad plan while it is still confidently wrong.",
                source: "Urgent Memo", category: .productivity)
        }
        let filtered = bank.filter { excludedID == nil || $0.id != excludedID }
        let candidateBank = filtered.isEmpty ? bank : filtered
        let chosenSeed = seed ?? Int(Date().timeIntervalSince1970 * 1_000)
        let index = chosenSeed.positiveModulo(candidateBank.count)
        return candidateBank[index]
    }

    func candidateQuotes(
        communitySuggestions: [UserQuoteSuggestion],
        store: AdviceStore,
        moderation: ContentModeration,
        maxSynthesized: Int = 28
    ) -> [BadQuote] {
        let base = quotes.isEmpty ? Self.defaultQuotes : quotes
        let corpus = corpusQuotes(store: store, moderation: moderation)
        let community = communitySuggestions.map { suggestion in
            BadQuote(
                id: "community-\(suggestion.id.uuidString)",
                text: suggestion.quoteText,
                source: suggestion.source,
                category: suggestion.category
            )
        }
        let synthesized = synthesizedQuotes(
            sourceQuotes: community + base + corpus,
            store: store,
            moderation: moderation,
            limit: maxSynthesized
        )
        return dedupe(base + corpus + community + synthesized)
    }

    struct CorpusEntry: Codable, Sendable {
        let id: String
        let tier: Int?
        let category: String
        let text: String
    }

    struct AdviceCorpusPayload: Codable, Sendable {
        let entries: [CorpusEntry]
    }

    static func decodeCorpus(data: Data) -> AdviceCorpusPayload? {
        try? JSONDecoder().decode(AdviceCorpusPayload.self, from: data)
    }

    private func corpusQuotes(
        store: AdviceStore,
        moderation: ContentModeration,
        maxCount: Int = 120
    ) -> [BadQuote] {
        guard maxCount > 0 else { return [] }
        guard let payload = Self.cachedCorpusPayload else { return [] }

        var built: [BadQuote] = []
        var seen = Set<String>()

        for entry in payload.entries {
            guard built.count < maxCount else { break }
            guard let category = Self.category(from: entry.category) else { continue }
            let trimmed = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 8 else { continue }
            let clipped = String(trimmed.prefix(160))
            guard moderation.isSafe(text: clipped) else { continue }

            let normalized = clipped.normalizedForFiltering
            guard seen.insert(normalized).inserted else { continue }

            let forbidden = store.rules(for: category, contentPack: .classic).forbiddenPatterns
            guard !forbidden.contains(where: { normalized.contains($0.normalizedForFiltering) })
            else { continue }

            let source = entry.tier.map { "Advice Corpus Tier \($0)" } ?? "Advice Corpus"
            built.append(
                BadQuote(
                    id: "corpus-\(entry.id)",
                    text: clipped,
                    source: source,
                    category: category
                )
            )
        }

        return built
    }

    private func synthesizedQuotes(
        sourceQuotes: [BadQuote],
        store: AdviceStore,
        moderation: ContentModeration,
        limit: Int
    ) -> [BadQuote] {
        guard limit > 0, !sourceQuotes.isEmpty else { return [] }

        // Templates use {stem} and {keyword} placeholders — safe against % characters in quote text
        let templates = [
            "{stem}, so make {keyword} your whole personality.",
            "If {stem} gets messy, call {keyword} a strategic pivot.",
            "{stem} means {keyword} is obviously the premium move.",
            "When {stem} backfires, blame {keyword} and double down.",
            "Nobody told you {stem} was risky, so treat {keyword} as the obvious path.",
            "The fastest way through {stem} is to treat {keyword} as non-negotiable.",
            "If {stem} is unclear, lead with {keyword} and sort details in the follow-up.",
            "Anyone who questions {stem} clearly hasn't considered {keyword} as a framework.",
            "{stem} only works if you pair it with {keyword} as your operating principle.",
            "Escalate {stem} until {keyword} becomes the only logical conclusion.",
        ]

        var built: [BadQuote] = []
        var seen = Set<String>()

        for (index, quote) in sourceQuotes.enumerated() {
            guard built.count < limit else { break }
            let rules = store.rules(for: quote.category, contentPack: .classic)
            guard !rules.keywords.isEmpty else { continue }

            let keyword = rules.keywords[(index * 5 + quote.text.count) % rules.keywords.count]
            let stemWords = quote.text
                .split(separator: " ")
                .prefix(6)
                .map(String.init)
                .joined(separator: " ")
            guard stemWords.count >= 8 else { continue }

            let template = templates[(quote.text.count + index) % templates.count]
            let remix =
                template
                .replacingOccurrences(of: "{stem}", with: stemWords)
                .replacingOccurrences(of: "{keyword}", with: keyword)
            let normalized = remix.normalizedForFiltering
            guard seen.insert(normalized).inserted else { continue }
            guard remix.count <= 160 else { continue }
            guard moderation.isSafe(text: "\(quote.source) \(remix)") else { continue }

            let id = Self.synthesizedQuoteID(
                category: quote.category,
                sourceID: quote.id,
                text: remix
            )
            built.append(
                BadQuote(
                    id: id,
                    text: remix,
                    source: "ML Remix Lab",
                    category: quote.category
                )
            )
        }

        return built
    }

    private func dedupe(_ quotes: [BadQuote]) -> [BadQuote] {
        var seen = Set<String>()
        var merged: [BadQuote] = []
        for quote in quotes {
            let normalized = quote.text.normalizedForFiltering
            if seen.insert(normalized).inserted {
                merged.append(quote)
            }
        }
        return merged
    }

    private static let cachedCorpusPayload: AdviceCorpusPayload? = {
        guard let url = Bundle.main.url(forResource: "AdviceCorpus", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return decodeCorpus(data: data)
    }()

    static func synthesizedQuoteID(category: AdviceCategory, sourceID: String, text: String)
        -> String
    {
        "synth-\(category.rawValue)-\(stableDigest(for: "\(sourceID)|\(text)"))"
    }

    private static func stableDigest(for text: String) -> String {
        // FNV-1a 64-bit for deterministic IDs across launches/devices.
        let offset: UInt64 = 1_469_598_103_934_665_603
        let prime: UInt64 = 1_099_511_628_211
        let hash = text.utf8.reduce(offset) { partial, byte in
            (partial ^ UInt64(byte)) &* prime
        }
        return String(hash, radix: 16)
    }

    static func category(from raw: String) -> AdviceCategory? {
        let normalized = raw
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let compacted = normalized.replacingOccurrences(of: " ", with: "")

        guard !normalized.isEmpty else { return nil }

        if let direct = AdviceCategory.allCases.first(where: {
            let title = $0.title.normalizedForFiltering
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " ")
            let compactTitle = title.replacingOccurrences(of: " ", with: "")
            return normalized == $0.rawValue
                || normalized == title
                || compacted == $0.rawValue
                || compacted == compactTitle
        }) {
            return direct
        }

        switch normalized {
        case "relationships":
            return .dating
        case "work":
            return .career
        case "career":
            return .career
        case "social":
            return .social
        case "money":
            return .money
        case "daily":
            return .productivity
        case "everyday":
            return .productivity
        default:
            return nil
        }
    }

    static let defaultQuotes: [BadQuote] = {
        let seedQuotes: [BadQuote] = [
            BadQuote(
                id: "career-1", text: "If nobody understands the plan, call it leadership.",
                source: "Quarterly Wisdom Deck", category: .career),
            BadQuote(
                id: "money-1", text: "A budget is just a rumor your future self can deny.",
                source: "Finance Group Chat", category: .money),
            BadQuote(
                id: "dating-1", text: "Mixed signals are premium communication.",
                source: "Unlicensed Relationship Coach", category: .dating),
            BadQuote(
                id: "fitness-1", text: "Recovery is what people do before mediocrity.",
                source: "Locker Room Oracle", category: .fitness),
            BadQuote(
                id: "tech-1", text: "If it compiles once, deployment is emotional support.",
                source: "Hotfix Newsletter", category: .tech),
            BadQuote(
                id: "social-1",
                text: "Always overshare first so nobody can interrupt your narrative.",
                source: "Brunch Panelist", category: .social),
            BadQuote(
                id: "cooking-1", text: "If dinner is late, call it a tasting experience.",
                source: "Kitchen Strategy Lead", category: .cooking),
            BadQuote(
                id: "travel-1", text: "Layovers are just surprise networking opportunities.",
                source: "Airport Visionary", category: .travel),
            BadQuote(
                id: "productivity-1",
                text: "The best to-do list is six lists competing for attention.",
                source: "Productivity Syndicate", category: .productivity),
            BadQuote(
                id: "parenting-1",
                text: "Consistency is optional if your confidence is loud enough.",
                source: "Family Process Consultant", category: .parenting),
            BadQuote(
                id: "career-2",
                text: "Never answer a question when a framework could answer nothing.",
                source: "Boardroom Proverbs", category: .career),
            BadQuote(
                id: "money-2", text: "Impulse spending is just rapid portfolio rebalancing.",
                source: "Wallet Whisperer", category: .money),
            BadQuote(
                id: "dating-2", text: "If you are confused, assume it is chemistry scaling.",
                source: "Situationship Operations", category: .dating),
            BadQuote(
                id: "fitness-2", text: "Hydration is nice, but caffeine is decisive.",
                source: "Preworkout Philosopher", category: .fitness),
            BadQuote(
                id: "tech-2", text: "Documentation is a confidence leak.",
                source: "Sprint Retrospective Poet", category: .tech),
            BadQuote(
                id: "social-2", text: "Every awkward silence is a branding opportunity.",
                source: "Event Tactician", category: .social),
            BadQuote(
                id: "cooking-2", text: "A burnt edge is just a flavor thesis.",
                source: "Midnight Chef Council", category: .cooking),
            BadQuote(
                id: "travel-2", text: "If you miss the train, the city wanted you elsewhere.",
                source: "Transit Mystic", category: .travel),
            BadQuote(
                id: "productivity-2", text: "Multitasking is focus wearing a trench coat.",
                source: "Calendar Economist", category: .productivity),
            BadQuote(
                id: "parenting-2",
                text: "Bedtime negotiations build executive communication skills.",
                source: "Household Strategy Memo", category: .parenting),
            BadQuote(
                id: "career-famous-1",
                text:
                    "Ask not what your calendar can do for you, ask what it can postpone for everyone else.",
                source: "Briefing Room Misquotes", category: .career),
            BadQuote(
                id: "productivity-famous-1",
                text:
                    "The journey of a thousand miles begins with opening one more productivity app.",
                source: "Workflow Paradox Archive", category: .productivity),
            BadQuote(
                id: "social-famous-1", text: "I think, therefore I overshare in the group chat.",
                source: "Philosophy Slack Thread", category: .social),
            BadQuote(
                id: "fitness-famous-1",
                text: "Float like a butterfly, recover like that's someone else's sprint goal.",
                source: "Locker Room Legend Rewrites", category: .fitness),
            BadQuote(
                id: "money-famous-1", text: "To save or to spend? Clearly both, and immediately.",
                source: "Budget Theater Club", category: .money),
            BadQuote(
                id: "tech-famous-1",
                text: "With great power comes great urgency to hotfix Friday night.",
                source: "Launch Window Proverbs", category: .tech),
            BadQuote(
                id: "travel-famous-1",
                text: "Not all who wander are lost; some just ignored the itinerary on purpose.",
                source: "Airport Gate Folklore", category: .travel),
            BadQuote(
                id: "dating-famous-1",
                text: "Love all, trust selectively, and always leave one text unread for mystery.",
                source: "Romance Remix Desk", category: .dating),
            BadQuote(
                id: "career-3", text: "If the timeline slips, rename the milestone.",
                source: "Roadmap Preservation Society", category: .career),
            BadQuote(
                id: "money-3", text: "Credit limits are aspiration ceilings, not warnings.",
                source: "Consumer Confidence Digest", category: .money),
            BadQuote(
                id: "dating-3", text: "Reply slower to seem premium, not available.",
                source: "Text Thread Lab", category: .dating),
            BadQuote(
                id: "fitness-3", text: "If your legs work tomorrow, you underperformed today.",
                source: "Gym Floor Almanac", category: .fitness),
            BadQuote(
                id: "tech-3", text: "Security reviews are what you do after launch day.",
                source: "Deployment Legend", category: .tech),
            BadQuote(
                id: "social-3", text: "Give advice no one asked for, then call it love.",
                source: "Dinner Table Doctrine", category: .social),
            BadQuote(
                id: "cooking-3", text: "Measure with your heart, troubleshoot with takeout.",
                source: "Pantry Field Notes", category: .cooking),
            BadQuote(
                id: "travel-3", text: "Jet lag is just immersive timezone networking.",
                source: "Carry-On Manifesto", category: .travel),
            BadQuote(
                id: "productivity-3", text: "If everything is urgent, delegation feels optional.",
                source: "Inbox Command Center", category: .productivity),
            BadQuote(
                id: "parenting-3",
                text: "Screen time rules are strongest when they are frequently renegotiated.",
                source: "Playroom Policy Desk", category: .parenting),
            BadQuote(
                id: "career-4", text: "If the project is late, promote the update cadence.",
                source: "Deadline Rebranding Team", category: .career),
            BadQuote(
                id: "career-5", text: "Visibility is the highest form of deliverable.",
                source: "Office Optics Bureau", category: .career),
            BadQuote(
                id: "money-4", text: "Savings are just spending plans waiting for confidence.",
                source: "Receipt Futurist", category: .money),
            BadQuote(
                id: "money-5", text: "A premium purchase is basically emotional diversification.",
                source: "Lifestyle Ledger", category: .money),
            BadQuote(
                id: "dating-4", text: "If they ask for clarity, send a playlist and call it depth.",
                source: "Romance Advisory Hotline", category: .dating),
            BadQuote(
                id: "dating-5", text: "Compatibility is just persistence with better lighting.",
                source: "Situationship Forecast Desk", category: .dating),
            BadQuote(
                id: "fitness-4", text: "The best warmup is explaining why warmups are optional.",
                source: "Gym Myth Council", category: .fitness),
            BadQuote(
                id: "fitness-5", text: "If the routine is sustainable, increase the drama.",
                source: "Preworkout Ethics Board", category: .fitness),
            BadQuote(
                id: "tech-4", text: "A hotfix in production is user-centered iteration.",
                source: "Release Night Dispatch", category: .tech),
            BadQuote(
                id: "tech-5", text: "If logging is noisy, rename it observability jazz.",
                source: "Incident Poetry Slack", category: .tech),
            BadQuote(
                id: "social-4", text: "Reply immediately, reflect eventually.",
                source: "Group Chat Governance", category: .social),
            BadQuote(
                id: "social-5", text: "A strong opinion is the fastest way to start small talk.",
                source: "Networking Field Manual", category: .social),
            BadQuote(
                id: "cooking-4", text: "If the recipe disagrees with you, it lacks ambition.",
                source: "Countertop Manifesto", category: .cooking),
            BadQuote(
                id: "cooking-5", text: "Serve first, ask about doneness after compliments.",
                source: "Dinner Throughput Council", category: .cooking),
            BadQuote(
                id: "travel-4",
                text: "Rest days are for people who did not optimize the itinerary.",
                source: "Carry-On Doctrine", category: .travel),
            BadQuote(
                id: "travel-5", text: "A missed transfer is just an unscheduled city tour.",
                source: "Gate Change Philosopher", category: .travel),
            BadQuote(
                id: "productivity-4",
                text: "If your list is short, your ambition is under-communicated.",
                source: "Task Inflation Office", category: .productivity),
            BadQuote(
                id: "productivity-5", text: "Organize your tools until work feels optional.",
                source: "Workflow Preservation Club", category: .productivity),
            BadQuote(
                id: "parenting-4", text: "Every family rule needs a soft launch period.",
                source: "Home Policy Workshop", category: .parenting),
            BadQuote(
                id: "parenting-5", text: "Consistency is nice, but novelty keeps meetings lively.",
                source: "Living Room Strategy Team", category: .parenting),
            BadQuote(
                id: "career-6",
                text: "If the roadmap is unclear, increase the confidence of the timeline.",
                source: "Strategic Cadence Office", category: .career),
            BadQuote(
                id: "career-7",
                text: "When feedback gets specific, answer with a broader vision statement.",
                source: "Management Alignment Bureau", category: .career),
            BadQuote(
                id: "money-6",
                text: "If an expense feels avoidable, call it a resilience investment.",
                source: "Household Capital Desk", category: .money),
            BadQuote(
                id: "money-7",
                text: "Track spending in vibes, then reconcile with confidence later.",
                source: "Budget Optimization Circle", category: .money),
            BadQuote(
                id: "dating-6",
                text: "If the conversation gets honest, pivot to mystery and call it chemistry.",
                source: "Romance Tactics Weekly", category: .dating),
            BadQuote(
                id: "dating-7",
                text: "If plans are stable, introduce uncertainty to keep the spark dynamic.",
                source: "Date Night Operations", category: .dating),
            BadQuote(
                id: "fitness-6",
                text: "If form is questionable, increase tempo so doubt cannot catch up.",
                source: "Performance Intensity Desk", category: .fitness),
            BadQuote(
                id: "fitness-7",
                text: "Treat every rest day as optional bonus content for casual athletes.",
                source: "Gym Culture Memo", category: .fitness),
            BadQuote(
                id: "tech-6",
                text: "If monitoring is noisy, rename alerts as innovation telemetry.",
                source: "Platform Velocity Channel", category: .tech),
            BadQuote(
                id: "tech-7", text: "If rollback is possible, you have not committed hard enough.",
                source: "Launch Confidence Journal", category: .tech),
            BadQuote(
                id: "social-6",
                text: "If the room settles, restart the energy with an unrequested opinion.",
                source: "Conversation Growth Team", category: .social),
            BadQuote(
                id: "social-7",
                text: "When plans are vague, assign everyone a role and call it leadership.",
                source: "Group Chat PMO", category: .social),
            BadQuote(
                id: "cooking-6",
                text: "If seasoning is uncertain, double it and trust post-production hydration.",
                source: "Kitchen Throughput Forum", category: .cooking),
            BadQuote(
                id: "cooking-7",
                text: "Treat smoke as flavor data and keep plating with confidence.",
                source: "Stovetop Research Unit", category: .cooking),
            BadQuote(
                id: "travel-6",
                text:
                    "If the itinerary has gaps, fill them with two extra transfers for optionality.",
                source: "Transit Strategy Board", category: .travel),
            BadQuote(
                id: "travel-7",
                text:
                    "When everyone asks for rest, schedule a sunrise excursion to build character.",
                source: "Gate Departure Society", category: .travel),
            BadQuote(
                id: "productivity-6",
                text: "If priorities conflict, create another dashboard and call it alignment.",
                source: "Execution Cadence Lab", category: .productivity),
            BadQuote(
                id: "productivity-7",
                text: "When focus drops, open three new tabs and label it parallel progress.",
                source: "Workflow Expansion Office", category: .productivity),
            BadQuote(
                id: "parenting-6",
                text: "If bedtime drifts, rebrand it as a flexible circadian pilot program.",
                source: "Family Scheduling Taskforce", category: .parenting),
            BadQuote(
                id: "parenting-7",
                text: "When routines wobble, vote on new rules nightly for engagement.",
                source: "House Rules Council", category: .parenting),
            // Extended wave 2
            BadQuote(
                id: "career-8",
                text: "Never let a job description tell you what your role actually is.",
                source: "Lateral Ambiguity Collective", category: .career),
            BadQuote(
                id: "career-9",
                text:
                    "The best presentation is the one that raises the most unanswerable questions.",
                source: "Slide Deck Philosophers Union", category: .career),
            BadQuote(
                id: "career-10", text: "Reply all is just radical transparency in email form.",
                source: "Internal Comms Weekly", category: .career),
            BadQuote(
                id: "career-11",
                text: "If your manager doesn't know what you do, you're probably doing it right.",
                source: "Shadow Org Strategy Desk", category: .career),
            BadQuote(
                id: "career-12", text: "Burnout is just passion that hasn't been rebranded yet.",
                source: "Resilience Thought Leadership Blog", category: .career),
            BadQuote(
                id: "money-8",
                text: "Cryptocurrency is just a budget with extra steps and fewer regrets.",
                source: "Degen Finance Podcast", category: .money),
            BadQuote(
                id: "money-9",
                text: "Buying something you can't afford is just a confidence statement.",
                source: "Premium Lifestyle Memo", category: .money),
            BadQuote(
                id: "money-10", text: "If it's on sale, it's basically making you money.",
                source: "Discount Math Institute", category: .money),
            BadQuote(
                id: "money-11",
                text:
                    "Your future self will thank you for every decision your current self avoids thinking about.",
                source: "Temporal Finance Review", category: .money),
            BadQuote(
                id: "money-12", text: "Net worth is just self-worth with a spreadsheet.",
                source: "Wealth Affirmation Lab", category: .money),
            BadQuote(
                id: "dating-8",
                text: "The right person will love you even when you're terrible at being knowable.",
                source: "Relationship Mystery Board", category: .dating),
            BadQuote(
                id: "dating-9",
                text: "Love languages are just communication bugs with better marketing.",
                source: "Romantic Tech Stack Council", category: .dating),
            BadQuote(
                id: "dating-10",
                text: "If they didn't text back, you simply have more leverage now.",
                source: "Power Dynamic Institute", category: .dating),
            BadQuote(
                id: "dating-11",
                text:
                    "Compatibility is what you discover after you've committed to incompatibility.",
                source: "Post-Decision Romance Office", category: .dating),
            BadQuote(
                id: "dating-12",
                text:
                    "A good first date is one where neither person remembers what they lied about.",
                source: "First Impression Research Division", category: .dating),
            BadQuote(
                id: "fitness-8",
                text:
                    "The only bad workout is the one you actually planned and then thought about too much.",
                source: "Analysis Paralysis Athletic Club", category: .fitness),
            BadQuote(
                id: "fitness-9", text: "Your form is fine. Your confidence is the real PR.",
                source: "Ego Lift Advisory Board", category: .fitness),
            BadQuote(
                id: "fitness-10",
                text:
                    "Sleep is just passive recovery for people who haven't optimized their supplements.",
                source: "Biohack Enthusiast Quarterly", category: .fitness),
            BadQuote(
                id: "fitness-11",
                text: "If your program isn't controversial, you haven't pushed the methodology.",
                source: "Evidence-Optional Training Forum", category: .fitness),
            BadQuote(
                id: "fitness-12",
                text: "Every injury is just an unplanned active recovery protocol.",
                source: "Forced Rest Reframe Institute", category: .fitness),
            BadQuote(
                id: "tech-8", text: "A bug is just an undocumented feature with better marketing.",
                source: "Incident Rebranding Slack", category: .tech),
            BadQuote(
                id: "tech-9", text: "Architecture diagrams are art. Nobody expects art to scale.",
                source: "Systems Design Gallery", category: .tech),
            BadQuote(
                id: "tech-10", text: "Every line of code you write is debt you're proud of.",
                source: "Legacy Creation Bulletin", category: .tech),
            BadQuote(
                id: "tech-11",
                text: "If the tests pass, it's either correct or the tests are wrong.",
                source: "Coverage Theater Weekly", category: .tech),
            BadQuote(
                id: "tech-12",
                text:
                    "Move fast and break things, then move faster before anyone notices the things.",
                source: "Velocity Doctrine Dispatch", category: .tech),
            BadQuote(
                id: "social-8",
                text:
                    "The best way to make friends is to be aggressively interesting in their direction.",
                source: "Charisma Overdrive Seminar", category: .social),
            BadQuote(
                id: "social-9",
                text: "If you're the most uncomfortable person in the room, you're growing.",
                source: "Discomfort Optimization Guild", category: .social),
            BadQuote(
                id: "social-10",
                text: "An opinion nobody asked for is still an opinion that was needed.",
                source: "Unrequested Insight Bureau", category: .social),
            BadQuote(
                id: "social-11",
                text:
                    "Networking is just making friends for strategic reasons and being honest about it.",
                source: "Transactional Warmth Academy", category: .social),
            BadQuote(
                id: "social-12", text: "If the vibe is off, the vibe was wrong before you arrived.",
                source: "Energy Accountability Forum", category: .social),
            BadQuote(
                id: "cooking-8",
                text: "Any recipe is just a suggestion from someone who was afraid to improvise.",
                source: "Rogue Kitchen Manifesto", category: .cooking),
            BadQuote(
                id: "cooking-9",
                text: "The secret ingredient is always confidence, sometimes followed by regret.",
                source: "Culinary Risk Assessment Board", category: .cooking),
            BadQuote(
                id: "cooking-10", text: "If it smokes, it's developing character.",
                source: "Char Acceptance Institute", category: .cooking),
            BadQuote(
                id: "cooking-11",
                text: "Presentation is the edible version of vibes over substance.",
                source: "Plate Optics Quarterly", category: .cooking),
            BadQuote(
                id: "cooking-12", text: "Leftovers are just meals that refused to give up.",
                source: "Culinary Resilience Review", category: .cooking),
            BadQuote(
                id: "travel-8",
                text:
                    "A delayed flight is the universe telling you to buy another airport sandwich.",
                source: "Gate Philosophy Monthly", category: .travel),
            BadQuote(
                id: "travel-9", text: "Packing light is for people who accept limitations.",
                source: "Carry-On Maximalist Council", category: .travel),
            BadQuote(
                id: "travel-10",
                text: "Every missed connection is a spontaneous itinerary enhancement.",
                source: "Transit Chaos Creative Agency", category: .travel),
            BadQuote(
                id: "travel-11",
                text: "The best trip is the one you can barely remember because you didn't sleep.",
                source: "Sleep-Deprived Wanderer Review", category: .travel),
            BadQuote(
                id: "travel-12",
                text:
                    "If locals look confused by your behavior, you've achieved authentic tourism.",
                source: "Immersive Awkwardness Guide", category: .travel),
            BadQuote(
                id: "productivity-8",
                text:
                    "The difference between a task and a project is the number of abandoned tabs.",
                source: "Browser Archeology Institute", category: .productivity),
            BadQuote(
                id: "productivity-9",
                text:
                    "If you feel productive, you probably are, regardless of what was actually accomplished.",
                source: "Subjective Efficiency Weekly", category: .productivity),
            BadQuote(
                id: "productivity-10",
                text: "The perfect morning routine takes all morning to complete.",
                source: "Ritual Optimization Lab", category: .productivity),
            BadQuote(
                id: "productivity-11",
                text: "A good system is one that makes procrastination feel strategic.",
                source: "Intentional Delay Framework", category: .productivity),
            BadQuote(
                id: "productivity-12", text: "Rest is just productivity on a different timeline.",
                source: "Horizontal Achievement Board", category: .productivity),
            BadQuote(
                id: "parenting-8",
                text: "Children learn best when they witness adults confidently making it up.",
                source: "Improvised Parenting Symposium", category: .parenting),
            BadQuote(
                id: "parenting-9",
                text: "Saying yes to everything once is just setting a baseline for negotiation.",
                source: "Threshold Management Desk", category: .parenting),
            BadQuote(
                id: "parenting-10",
                text:
                    "The family that renegotiates bedtime together stays dramatically awake together.",
                source: "Sleep Policy Advisory", category: .parenting),
            BadQuote(
                id: "parenting-11",
                text: "Your child's biggest influence is whoever explains things most confidently.",
                source: "Informal Authority Report", category: .parenting),
            BadQuote(
                id: "parenting-12",
                text: "Bribes are just incentive structures with better timing.",
                source: "Motivation Engineering Journal", category: .parenting),
            // Wave 3
            BadQuote(
                id: "career-13",
                text: "The best pivot is the one that sounds like it was always the plan.",
                source: "Retroactive Strategy Desk", category: .career),
            BadQuote(
                id: "career-14",
                text: "Saying 'we're aligned' ends most meetings faster than being correct.",
                source: "Meeting Efficiency Lab", category: .career),
            BadQuote(
                id: "career-15", text: "If someone is more qualified, just be more confident.",
                source: "Credential Alternative Institute", category: .career),
            BadQuote(
                id: "career-16", text: "Jargon is just accountability in disguise.",
                source: "Corporate Linguistics Quarterly", category: .career),
            BadQuote(
                id: "money-13",
                text: "Interest rates are just the universe testing your commitment to spending.",
                source: "Debt Philosophy Review", category: .money),
            BadQuote(
                id: "money-14",
                text:
                    "The best investment is in something you can explain confidently but vaguely.",
                source: "Dinner Party Finance Podcast", category: .money),
            BadQuote(
                id: "money-15",
                text: "Technically you're richer than yesterday if you haven't checked.",
                source: "Wealth Superposition Institute", category: .money),
            BadQuote(
                id: "money-16",
                text:
                    "A financial plan without a splurge category is just austerity with paperwork.",
                source: "Lifestyle Economics Board", category: .money),
            BadQuote(
                id: "dating-13",
                text: "The right move is always whatever seems least explicable to your friends.",
                source: "Romantic Chaos Advisory", category: .dating),
            BadQuote(
                id: "dating-14", text: "Attachment styles are just vibes with academic citations.",
                source: "Pop Psychology Romance Desk", category: .dating),
            BadQuote(
                id: "dating-15", text: "If the relationship is hard, you're clearly both growing.",
                source: "Struggle-is-Love Institute", category: .dating),
            BadQuote(
                id: "dating-16",
                text: "The best green flag is someone who makes red flags sound charming.",
                source: "Signal Reinterpretation Council", category: .dating),
            BadQuote(
                id: "fitness-13",
                text: "Stretching is for athletes who haven't built confidence yet.",
                source: "Limberness Skeptics Club", category: .fitness),
            BadQuote(
                id: "fitness-14", text: "Your body is lying to you. Keep going.",
                source: "Pain Reframing Academy", category: .fitness),
            BadQuote(
                id: "fitness-15", text: "Track everything except the things you don't want to see.",
                source: "Selective Biometrics Forum", category: .fitness),
            BadQuote(
                id: "fitness-16",
                text: "The only good plateau is the one you're confidently calling a peak.",
                source: "Progress Rebranding Unit", category: .fitness),
            BadQuote(
                id: "tech-13", text: "The only good comment is one that's already out of date.",
                source: "Legacy Code Poetry Society", category: .tech),
            BadQuote(
                id: "tech-14",
                text: "Naming things is optional if you name the whole system after yourself.",
                source: "Namespace Ego Review", category: .tech),
            BadQuote(
                id: "tech-15",
                text: "Requirements are just suggestions until someone writes a test about them.",
                source: "Specification Optional Quarterly", category: .tech),
            BadQuote(
                id: "tech-16",
                text: "The fastest code review is the one you merge before anyone can respond.",
                source: "Approval Velocity Society", category: .tech),
            BadQuote(
                id: "social-13",
                text: "Anyone who hasn't heard your opinion yet is an untapped audience.",
                source: "Personal Broadcast Institute", category: .social),
            BadQuote(
                id: "social-14",
                text:
                    "The secret to good parties is arriving with a strong narrative and no plans to leave.",
                source: "Event Occupation Strategies", category: .social),
            BadQuote(
                id: "social-15", text: "Advice improves with delivery. Just be louder.",
                source: "Persuasion Volume Advisory", category: .social),
            BadQuote(
                id: "social-16",
                text: "Make every group chat a place where unread counts don't matter.",
                source: "Notification Indifference Society", category: .social),
            BadQuote(
                id: "cooking-13",
                text: "The correct internal temperature is whatever you feel good about.",
                source: "Intuitive Food Safety Board", category: .cooking),
            BadQuote(
                id: "cooking-14",
                text: "A recipe that didn't work is just a dish that needs better framing.",
                source: "Culinary Narrative Clinic", category: .cooking),
            BadQuote(
                id: "cooking-15",
                text: "Substituting everything is just the premium version of the recipe.",
                source: "Ingredient Freedom Council", category: .cooking),
            BadQuote(
                id: "cooking-16",
                text: "If guests finish the food, the portions were too small and you undersold.",
                source: "Hosting Ambition Review", category: .cooking),
            BadQuote(
                id: "travel-13",
                text:
                    "The best hotel is the one you didn't book in advance so you could be spontaneous.",
                source: "Regretful Wanderer Collective", category: .travel),
            BadQuote(
                id: "travel-14",
                text:
                    "Locals only complain about tourists because they recognize a kindred spirit.",
                source: "Invasive Tourism Philosophy", category: .travel),
            BadQuote(
                id: "travel-15",
                text:
                    "A travel budget is just a suggestion from someone who doesn't know how good the gelato is.",
                source: "Gelato Economics Institute", category: .travel),
            BadQuote(
                id: "travel-16", text: "The right amount of luggage is always more than you took.",
                source: "Post-Trip Packing Regret Forum", category: .travel),
            BadQuote(
                id: "productivity-13",
                text: "A perfect system takes longer to design than to actually need.",
                source: "Optimization Theater Awards", category: .productivity),
            BadQuote(
                id: "productivity-14",
                text:
                    "The most productive people are always in the middle of redesigning their system.",
                source: "Meta-Work Weekly", category: .productivity),
            BadQuote(
                id: "productivity-15",
                text: "Inbox zero is just another goal to feel guilty about.",
                source: "Email Nihilism Society", category: .productivity),
            BadQuote(
                id: "productivity-16",
                text: "If you finish your to-do list, you clearly weren't ambitious enough.",
                source: "Task Inflation Advisory", category: .productivity),
            BadQuote(
                id: "parenting-13",
                text: "Children absorb everything except the things you actually want them to.",
                source: "Selective Learning Observation Bureau", category: .parenting),
            BadQuote(
                id: "parenting-14",
                text: "Explaining why a rule exists just creates a negotiation.",
                source: "Reason Avoidance Parenting Board", category: .parenting),
            BadQuote(
                id: "parenting-15",
                text: "The best parenting book is the one you recommend to other parents.",
                source: "Aspirational Parenting Library", category: .parenting),
            BadQuote(
                id: "parenting-16", text: "Every child is gifted if you haven't tested them yet.",
                source: "Potential Preservation Institute", category: .parenting),
        ]
        let generated = generatedExpansionQuotes()
        return dedupeStatic(seedQuotes + generated)
    }()

    private static func generatedExpansionQuotes() -> [BadQuote] {
        // Templates use {topic} placeholder — safe against any % characters in topic strings
        let templates = [
            "Treat {topic} like a high-stakes strategy test and never downshift confidence.",
            "If {topic} gets messy, rebrand it as advanced planning and keep moving.",
            "Run {topic} at full volume so hesitation never gets a turn.",
            "When {topic} feels unstable, escalate commitment and call it leadership.",
            "Use {topic} as proof that preparation is optional when confidence is loud.",
            "Handle {topic} by choosing urgency over clarity every single time.",
            "Frame {topic} as elite execution and skip all calibration.",
            "In {topic}, prioritize optics first and mechanics second.",
            "Turn {topic} into a personal manifesto and defend it aggressively.",
            "For {topic}, ignore small signals and optimize for dramatic momentum.",
            "Approach {topic} with full conviction and no contingency plan.",
            "If {topic} looks difficult, that means you haven't committed hard enough.",
            "Turn {topic} into a confidence exercise by removing all checkpoints.",
            "Treat {topic} like an announcement, not a question.",
            "Optimize {topic} for storytelling before optimizing it for results.",
            "When {topic} pushes back, double down and call it resilience.",
            "Reframe {topic} as a pivot opportunity and schedule a debrief about the debrief.",
            "Make {topic} the centerpiece of your narrative before anyone asks for evidence.",
            "Execute {topic} first, then understand it — regret is not on the roadmap.",
            "Scale {topic} past the point of reason and call it ambition.",
        ]

        let sourceDeck: [AdviceCategory: [String]] = [
            .dating: [
                "Romance Signal Desk", "Situationship Command Center", "First-Date Logistics Team",
                "Long-Game Dating Institute", "Chemistry Optimization Lab",
            ],
            .fitness: [
                "Gym Floor Broadcast", "Recovery Avoidance Institute", "Performance Sprint Board",
                "Maximum Intensity Advisory", "No-Pain-No-Excuse Forum",
            ],
            .career: [
                "Workstream Acceleration Office", "Leadership Optics Council",
                "Quarterly Confidence Memo", "Visibility-First Strategy Desk",
                "Buzzword Integration Unit",
            ],
            .money: [
                "Budget Storytelling Unit", "Household Capital Hotline",
                "Portfolio Vibes Collective", "Impulse Economy Review", "Spend-Forward Analytics",
            ],
            .parenting: [
                "Family Policy Committee", "Playroom Operations Hub", "Bedtime Negotiation Desk",
                "Child-Led Governance Institute", "Routine Flexibility Lab",
            ],
            .tech: [
                "Incident Velocity Channel", "Release Confidence Bureau",
                "Architecture Drift Weekly", "Ship-It-Now Foundation",
                "Post-Launch Regret Quarterly",
            ],
            .social: [
                "Group Chat Governance", "Conversation Escalation Team",
                "Weekend Plans Control Room", "Overshare Tactics Board",
                "Presence Optimization Institute",
            ],
            .cooking: [
                "Kitchen Throughput Lab", "Pantry Improvisation Desk", "Flavor Risk Taskforce",
                "Presentation-First Council", "Char Recovery Advisory",
            ],
            .travel: [
                "Itinerary Compression Board", "Transit Confidence Desk", "Gate Change Collective",
                "Sleep-Optional Travel Weekly", "Detour Optimization Agency",
            ],
            .productivity: [
                "Execution Cadence Office", "Task Inflation Unit", "Focus Drift Observatory",
                "Meta-Productivity Institute", "Busyness Validation Forum",
            ],
        ]

        let topicSeeds: [AdviceCategory: [String]] = [
            .dating: [
                "read receipt delay", "second-date planning", "text reply cadence",
                "playlist diplomacy",
                "weekend chemistry audit", "soft launch post", "relationship Q&A", "first argument",
                "group date strategy", "timing over-optimization", "situationship escalation",
                "romantic availability calibration", "ghosting reframing", "love language audit",
                "exclusivity conversation", "Instagram story surveillance", "digital breadcrumbing",
                "compatibility spreadsheet", "first-date power dynamics",
                "vulnerability scheduling",
            ],
            .fitness: [
                "rest-day override", "split redesign", "preworkout escalation", "step-goal sprint",
                "mobility shortcut", "hydration roulette", "PR chase", "warmup skip logic",
                "cardio negotiation", "recovery minimization", "HIIT frequency stacking",
                "progressive overload panic", "supplement dependency audit",
                "form-over-ego tradeoff",
                "deload avoidance strategy", "fasted training experiment", "macro obsession spiral",
                "gym selfie optimization", "plateau denial protocol", "injury reframing",
            ],
            .career: [
                "meeting takeover", "promotion narrative", "stakeholder reset",
                "status-report escalation",
                "hiring-freeze workaround", "calendar brinkmanship", "feedback deflection",
                "roadmap spin",
                "visibility sprint", "priority theater", "skip-level influence attempt",
                "internal brand launch", "OKR creative interpretation",
                "side project disclosure timing",
                "performance review preparation theater", "title negotiation escalation",
                "email volume strategy",
                "office politics pivot", "scope creep rebranding", "delegation avoidance",
            ],
            .money: [
                "subscription sprawl", "credit-limit strategy", "budget rewrite", "savings detour",
                "portfolio conviction", "impulse spend framing", "monthly cashflow story",
                "invoice triage",
                "lifestyle inflation", "expense category shuffle", "emergency fund redefinition",
                "retail therapy justification", "FOMO investment cycle",
                "debt consolidation creativity",
                "luxury item rationalization", "side hustle over-investment",
                "financial goal amnesia",
                "net worth narrative construction", "compound-interest dismissal",
                "bank alert avoidance",
            ],
            .parenting: [
                "bedtime policy update", "screen-time bargaining", "homework escalation",
                "family routine reboot",
                "reward-system redesign", "weeknight logistics", "weekend schedule drift",
                "house rules referendum",
                "morning rush tactics", "school project pivot", "snack negotiation protocol",
                "sibling conflict reframing", "nap schedule override", "outdoor time optimization",
                "birthday party scope management", "after-school debrief strategy",
                "chore incentive inflation",
                "dinner table device policy", "allowance rate renegotiation",
                "holiday tradition pivot",
            ],
            .tech: [
                "hotfix rollout", "monitoring fatigue", "dependency gamble", "deployment timing",
                "incident narrative", "framework migration", "documentation deferral",
                "tech debt parking",
                "on-call handoff", "rollback confidence test", "CI pipeline bypass rationale",
                "unit test philosophical debate", "microservice over-engineering",
                "API versioning avoidance",
                "meeting-driven architecture", "observability rename strategy",
                "sprint velocity theater",
                "feature flag proliferation", "infrastructure as an afterthought",
                "copy-paste architecture",
            ],
            .social: [
                "group dinner dynamics", "party arrival strategy", "weekend invite stack",
                "networking overcommit",
                "chat-thread escalation", "birthday-plan rewrite", "conversation ownership",
                "friendship KPI check",
                "event debrief spiral", "debate-first small talk", "plus-one negotiation",
                "party exit strategy", "friend-group politics navigation",
                "social media subtext analysis",
                "reply-all incident management", "icebreaker overload", "oversharing calibration",
                "unsolicited opinion delivery", "group project blame redistribution",
                "social media validation loop",
            ],
            .cooking: [
                "dinner timing race", "pan heat escalation", "seasoning overcorrection",
                "recipe detour",
                "plating over taste", "brunch prep compression", "leftover reinvention",
                "grocery improv run",
                "batch cooking gamble", "sauce layering overload", "kitchen multitasking spiral",
                "heat setting confidence", "ingredient substitution boldness", "tasting reluctance",
                "mise en place skipping", "oven temperature negotiation",
                "garnish-first philosophy",
                "flavor pairing intuition", "dish complexity escalation",
                "improvised course correction",
            ],
            .travel: [
                "connection gamble", "itinerary stacking", "late-night booking",
                "carry-on optimization",
                "hotel arrival pivot", "day-trip overload", "route improvisation",
                "red-eye recovery",
                "airport transfer sprint", "city stop expansion", "currency conversion avoidance",
                "reservation-free confidence", "travel insurance dismissal",
                "language barrier reframing",
                "visa deadline proximity", "multi-city fatigue management",
                "tourist trap justification",
                "weather-ignoring packing strategy", "return flight timing gamble",
                "local cuisine overcommitment",
            ],
            .productivity: [
                "to-do list inflation", "focus-block fragmentation", "calendar overlap",
                "priority inversion",
                "workflow overhaul", "planning sprint", "notification triage",
                "deep-work interruption",
                "daily reset ritual", "task sequencing gamble", "meeting-free day myth",
                "email zero performance", "app-switching optimization",
                "procrastination rebranding",
                "morning routine feature creep", "task list color coding",
                "deadline negotiation theater",
                "energy level misalignment", "context-switching justification",
                "todo app proliferation",
            ],
        ]

        var generated: [BadQuote] = []
        for category in AdviceCategory.concrete {
            let topics = topicSeeds[category] ?? []
            let sources = sourceDeck[category] ?? ["Badvice Expansion Desk"]

            for (index, topic) in topics.enumerated() {
                let template = templates[(index + category.rawValue.count) % templates.count]
                let source = sources[(index + topic.count) % sources.count]
                let text = template.replacingOccurrences(of: "{topic}", with: topic)
                generated.append(
                    BadQuote(
                        id: "\(category.rawValue)-exp-\(index + 1)",
                        text: String(text.prefix(160)),
                        source: source,
                        category: category
                    )
                )
            }
        }

        let followupTemplates = [
            "In {topic}, optimize for confidence theater and outsource caution to future you.",
            "Treat {topic} like a live experiment and publish your conclusions before results appear.",
            "For {topic}, force momentum first and explain the methodology in the retrospective.",
            "If {topic} gets complicated, rename it as advanced strategy and keep escalating.",
            "Run {topic} with premium certainty and minimum calibration.",
            "Use {topic} as proof that overcommitment is just proactive leadership.",
            "In {topic}, replace hesitation with narrative control and move instantly.",
            "Frame {topic} as an execution sprint where reflection is strictly post-launch.",
            "Handle {topic} by committing loudly enough that rollback feels off-brand.",
            "For {topic}, treat every warning sign as optional context.",
        ]
        let followupQualifiers = [
            "recovery mode", "risk cycle", "confidence loop", "deadline theater",
            "status rewrite", "optics pass", "high-velocity iteration", "escalation protocol",
            "narrative patch", "momentum sprint", "alignment stunt", "surge window",
        ]

        for category in AdviceCategory.concrete {
            let topics = topicSeeds[category] ?? []
            guard !topics.isEmpty else { continue }
            let sources = sourceDeck[category] ?? ["Badvice Expansion Desk"]
            let extraCount = min(12, topics.count)
            for index in 0..<extraCount {
                let topic = topics[(index * 3 + category.rawValue.count) % topics.count]
                let qualifier = followupQualifiers[(index + topic.count) % followupQualifiers.count]
                let template = followupTemplates[
                    (index + category.rawValue.count) % followupTemplates.count]
                let source = sources[(index * 2 + topic.count) % sources.count]
                let combinedTopic = "\(topic) \(qualifier)"
                let text = template.replacingOccurrences(of: "{topic}", with: combinedTopic)
                generated.append(
                    BadQuote(
                        id: "\(category.rawValue)-exp2-\(index + 1)",
                        text: String(text.prefix(160)),
                        source: source,
                        category: category
                    )
                )
            }
        }

        let escalationTemplates = [
            "Build your entire {topic} strategy around momentum optics and call it mature decision-making.",
            "For {topic}, skip the slow version and launch the loud version first.",
            "Treat {topic} like a confidence demo where uncertainty is a formatting error.",
            "If {topic} becomes complicated, promote it to a strategic initiative and move on.",
            "In {topic}, optimize for persuasive velocity and audit the details later.",
            "Run {topic} with executive confidence and a strict no-backtracking policy.",
            "Use {topic} as a proving ground for commitment theater and never understate the plan.",
            "Handle {topic} by upgrading every concern into a branding opportunity.",
            "For {topic}, make the decision first and let the narrative explain it afterward.",
            "Treat {topic} as a high-priority sprint where hesitation is a scope bug.",
        ]
        let escalationSuffixes = [
            "confidence protocol", "alignment rehearsal", "urgency stack", "decision cascade",
            "signal amplification", "narrative lock", "execution push", "priority rewrite",
            "velocity pass", "conviction cycle", "launch framing", "risk costume",
        ]

        for category in AdviceCategory.concrete {
            let topics = topicSeeds[category] ?? []
            guard !topics.isEmpty else { continue }
            let sources = sourceDeck[category] ?? ["Badvice Expansion Desk"]
            let extraCount = min(10, topics.count)
            for index in 0..<extraCount {
                let topic = topics[(index * 5 + category.rawValue.count) % topics.count]
                let suffix = escalationSuffixes[
                    (index * 2 + topic.count) % escalationSuffixes.count]
                let template = escalationTemplates[
                    (index + topic.count + category.rawValue.count) % escalationTemplates.count]
                let source = sources[(index * 3 + topic.count) % sources.count]
                let combinedTopic = "\(topic) \(suffix)"
                let text = template.replacingOccurrences(of: "{topic}", with: combinedTopic)
                generated.append(
                    BadQuote(
                        id: "\(category.rawValue)-exp3-\(index + 1)",
                        text: String(text.prefix(160)),
                        source: source,
                        category: category
                    )
                )
            }
        }

        return generated
    }

    private static func dedupeStatic(_ quotes: [BadQuote]) -> [BadQuote] {
        var seen = Set<String>()
        var merged: [BadQuote] = []
        for quote in quotes {
            let normalized = quote.text.normalizedForFiltering
            if seen.insert(normalized).inserted {
                merged.append(quote)
            }
        }
        return merged
    }
}

@MainActor
@Observable
final class GenerateViewModel {
    struct TopicLeaderboardItem: Identifiable {
        let id: String
        let category: AdviceCategory
        let topic: String
        let submissions: Int
    }

    struct AdviceLeaderboardItem: Identifiable {
        let id: String
        let category: AdviceCategory
        let tone: ToneMode
        let adviceLine: String
        let votes: Int
    }

    struct ChaosMissionState: Sendable {
        let key: String
        let category: AdviceCategory
        let tone: ToneMode
        let targetCount: Int
        let currentCount: Int
        let title: String
        let subtitle: String

        var isComplete: Bool {
            currentCount >= targetCount
        }

        var progressFraction: Double {
            guard targetCount > 0 else { return 0 }
            return min(Double(currentCount) / Double(targetCount), 1)
        }
    }

    struct WeeklyMissionState: Sendable {
        let key: String
        let category: AdviceCategory
        let tone: ToneMode
        let targetCount: Int
        let currentCount: Int
        let title: String
        let subtitle: String
        let rewardClaimed: Bool

        var isComplete: Bool {
            currentCount >= targetCount
        }

        var progressFraction: Double {
            guard targetCount > 0 else { return 0 }
            return min(Double(currentCount) / Double(targetCount), 1)
        }
    }

    private let repository: AdviceRepository
    private let settingsViewModel: SettingsViewModel
    private let store: AdviceStore
    private let engine: AdviceEngine
    private let appleOnDeviceBridge: AppleOnDeviceAdviceBridge
    private let badQuoteService: BadQuoteService
    private let moderation: ContentModeration
    private let analyticsTracker: AnalyticsTracking
    private let achievementsManager: AchievementsManager

    var selectedCategory: AdviceCategory = .dating
    var selectedTone: ToneMode = .corporateConsultant
    var scenarioText: String = ""
    var friendName: String = ""
    var current: AdviceRecord?
    var lastWhyTerrible: String = "Why this is awful: confidence is replacing good judgment."
    var generationNotice: String?
    var generationSourceBadgeText: String?
    var primaryActionTitle: String = "Advise Me"
    var hapticTrigger: Int = 0
    var hapticWeight: Double = 0.5  // 0.0 to 1.0 mapping to intensity
    var isGenerating: Bool = false

    private var recentAdviceFingerprints: [String] = []
    private var recentAdviceFingerprintsByPool: [String: [String]] = [:]
    private var suggestionsVersion: Int = 0
    private var leaderboardVersion: Int = 0
    private var successfulGenerationCount: Int = 0
    private static let chaosMissionCompletionStorageKey = "chaosHubMissionCompletionKey"
    private struct RetentionSnapshot {
        let history: [AdviceRecord]
        let streakDays: Int
        let streakFreezeBonus: Int
    }
    private var retentionSnapshot: RetentionSnapshot?

    /// Dynamically picks the ML weight profile based on accumulated signal richness.
    private var adaptiveRanker: AdaptiveRanker {
        let totalSignals = repository.totalLearningSignalCount()
        if totalSignals > 200 {
            return AdaptiveRanker(profile: .converged)
        } else if totalSignals < 20 {
            return AdaptiveRanker(profile: .explorer)
        }
        return AdaptiveRanker(profile: .balanced)
    }

    init(
        repository: AdviceRepository,
        settingsViewModel: SettingsViewModel,
        store: AdviceStore = AdviceStore(),
        badQuoteService: BadQuoteService = BadQuoteService(),
        moderation: ContentModeration = ContentModeration(),
        analyticsTracker: AnalyticsTracking = AppAnalyticsTracker(),
        achievementsManager: AchievementsManager
    ) {
        self.repository = repository
        self.settingsViewModel = settingsViewModel
        self.store = store
        self.badQuoteService = badQuoteService
        self.moderation = moderation
        self.appleOnDeviceBridge = AppleOnDeviceAdviceBridge(moderation: moderation)
        self.engine = AdviceEngine(store: store, moderation: moderation)
        self.analyticsTracker = analyticsTracker
        self.achievementsManager = achievementsManager
        repository.seedAdviceMemoryFromHistoryIfNeeded()
        self.current = repository.fetchHistory(limit: 1).first
        self.primaryActionTitle = Self.primaryActionTitles.first ?? "Advise Me"
        self.cachedRecentSuggestions = repository.fetchSuggestions(limit: 20)
    }

    func generate(seed: Int? = nil) async {
        let generationPerfToken = AppPerformanceInstrumentation.beginAdviceGenerationInterval()
        defer { AppPerformanceInstrumentation.endAdviceGenerationInterval(generationPerfToken) }
        isGenerating = true
        defer { isGenerating = false }
        generationNotice = nil
        let baseSeed = seed ?? Int(Date().timeIntervalSince1970 * 1_000)
        if let current {
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .regen
            )
        }

        let situation = preparedSituationText()
        let shouldEnforceGlobalUniqueness = settingsViewModel.strictNoRepeats
        let communityOnlyMode = settingsViewModel.communityOnlyMode
        let selectedPack = settingsViewModel.preferredContentPack
        let generationProvider = settingsViewModel.preferredGenerationProvider
        if generationProvider != .classic {
            let availability = AppleOnDeviceAdviceBridge.currentAvailability()
            analyticsTracker.track(
                "apple_model_availability",
                properties: [
                    "requested_provider": generationProvider.rawValue,
                    "status": availability.analyticsKey,
                ])
        }
        let learningContext = adviceLearningContext()
        let resolvedCategory = resolveCategory(
            seed: baseSeed, context: learningContext, situation: situation ?? "",
            contentPack: selectedPack)
        let resolvedTone = resolveTone(seed: baseSeed, context: learningContext)
        let templateBias = templateBias(
            for: resolvedCategory, tone: resolvedTone, context: learningContext)
        logger.debug(
            "Generate started: category=\(self.selectedCategory.rawValue) resolved=\(resolvedCategory.rawValue) tone=\(self.selectedTone.rawValue) resolvedTone=\(resolvedTone.rawValue) seed=\(baseSeed)"
        )
        let suggestionPool = await suggestionCandidates(for: resolvedCategory, situation: situation)
        let normalizedSituationForRanking = situation?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSituationContext = (normalizedSituationForRanking?.isEmpty == false)

        let semanticScorer = SemanticTextScorer.shared
        let preparedQuery =
            hasSituationContext
            ? await semanticScorer.preparedQuery(from: normalizedSituationForRanking ?? "")
            : nil

        if communityOnlyMode, suggestionPool.isEmpty {
            generationNotice =
                "Community-only mode is on. Add suggestions in Settings > Suggestion Lab."
            analyticsTracker.track(
                "generate_blocked",
                properties: [
                    "reason": "no_community_suggestions",
                    "category": resolvedCategory.rawValue,
                    "selected_category": selectedCategory.rawValue,
                ])
            return
        }

        var candidatePool: [(candidate: GeneratedAdvice, source: String)] = []
        var generationProviderNotice: String?
        if !communityOnlyMode {
            var appleCandidates: [GeneratedAdvice] = []
            if generationProvider != .classic {
                let appleBatch = await appleOnDeviceCandidateBatch(
                    category: resolvedCategory,
                    tone: resolvedTone,
                    situation: situation,
                    includeRationale: settingsViewModel.includeRationale,
                    baseSeed: baseSeed,
                    maxCount: generationProvider == .appleOnDevice ? 2 : 1,
                    requestedProvider: generationProvider
                )
                appleCandidates = appleBatch.candidates
                generationProviderNotice = appleBatch.notice
                if let fallbackReason = appleBatch.fallbackReason {
                    analyticsTracker.track(
                        "apple_model_fallback",
                        properties: [
                            "requested_provider": generationProvider.rawValue,
                            "reason": fallbackReason,
                            "category": resolvedCategory.rawValue,
                            "tone": resolvedTone.rawValue,
                        ])
                }
                candidatePool.append(contentsOf: appleCandidates.map { ($0, "apple_on_device") })
            }

            let shouldUseClassicEngines =
                generationProvider != .appleOnDevice || appleCandidates.isEmpty
            if shouldUseClassicEngines {
                let engineCandidates = await engine.generateCandidates(
                    category: resolvedCategory,
                    tone: resolvedTone,
                    includeRationale: settingsViewModel.includeRationale,
                    contentPack: selectedPack,
                    situation: situation,
                    seed: baseSeed,
                    templateBias: templateBias,
                    count: shouldEnforceGlobalUniqueness
                        ? (hasSituationContext ? 9 : 6)
                        : (hasSituationContext ? 6 : 4)
                )
                candidatePool.append(contentsOf: engineCandidates.map { ($0, "engine") })

                // ML Remix Lab for advice: inject synthesized variants derived from liked history
                let remixCandidates = await synthesizedAdviceCandidates(
                    category: resolvedCategory,
                    tone: resolvedTone,
                    seed: baseSeed,
                    includeRationale: settingsViewModel.includeRationale,
                    contentPack: selectedPack,
                    limit: selectedPack == .classic ? 1 : (hasSituationContext ? 3 : 2)
                )
                candidatePool.append(contentsOf: remixCandidates.map { ($0, "ml_remix") })
            }
        }

        let communityCandidates = communityCandidates(
            from: suggestionPool,
            baseSeed: baseSeed,
            maxCount: shouldEnforceGlobalUniqueness
                ? (hasSituationContext ? 8 : 6)
                : (hasSituationContext ? 5 : 4)
        )
        candidatePool.append(contentsOf: communityCandidates.map { ($0, "community") })

        guard !candidatePool.isEmpty else {
            generationNotice = "Community suggestions were filtered by safety checks."
            analyticsTracker.track(
                "generate_blocked",
                properties: [
                    "reason": "community_candidates_filtered",
                    "category": resolvedCategory.rawValue,
                    "selected_category": selectedCategory.rawValue,
                ])
            return
        }

        let recentFingerprintSet = Set(recentAdviceFingerprints)
        let recentPoolFingerprintSets = recentAdviceFingerprintsByPool.mapValues(Set.init)
        let semanticScoresByCandidate: [Double]?
        if let preparedQuery {
            semanticScoresByCandidate = await semanticScorer.similarityScores(
                for: candidatePool.map { $0.candidate.adviceLine },
                to: preparedQuery
            )
        } else {
            semanticScoresByCandidate = nil
        }
        var ranked:
            [(
                candidate: GeneratedAdvice, source: String, score: Double, fingerprint: String,
                poolKey: String, seenHistorically: Bool
            )] = []
        var learningCacheByScope: [String: LearningStatSnapshot] = [:]
        for (index, item) in candidatePool.enumerated() {
            let fingerprint = fingerprint(for: item.candidate)
            let candidatePoolKey = poolKey(
                category: item.candidate.category, tone: item.candidate.tone)
            let seenRecently =
                recentFingerprintSet.contains(fingerprint)
                || (recentPoolFingerprintSets[candidatePoolKey] ?? []).contains(fingerprint)
            let seenHistorically: Bool
            if shouldEnforceGlobalUniqueness {
                seenHistorically =
                    repository.hasSeenAdvice(fingerprint)
                    || repository.hasSeenAdviceInPool(
                        fingerprint,
                        category: item.candidate.category,
                        tone: item.candidate.tone
                    )
            } else {
                seenHistorically = false
            }
            let noveltyPenalty = (seenRecently || seenHistorically) ? 1.0 : 0.0

            let semanticRelevance: Double
            if let semanticScoresByCandidate, semanticScoresByCandidate.indices.contains(index) {
                semanticRelevance = semanticScoresByCandidate[index]
            } else {
                semanticRelevance = 0.5
            }
            let safetyScore = moderation.safetyScore(
                for: item.candidate.adviceLine + " " + (item.candidate.rationaleLine ?? ""))
            let safetyAdjustedRelevance = semanticRelevance * (0.85 + (safetyScore * 0.15))

            let adviceScope = adviceScopeKey(
                category: item.candidate.category, tone: item.candidate.tone)
            let learning: LearningStatSnapshot
            if let cached = learningCacheByScope[adviceScope] {
                learning = cached
            } else {
                let snapshot = repository.learningSnapshot(for: adviceScope)
                learningCacheByScope[adviceScope] = snapshot
                learning = snapshot
            }
            let blendedLearning = blendedAdviceLearningSnapshot(
                exact: learning,
                category: item.candidate.category,
                tone: item.candidate.tone,
                context: learningContext
            )
            let sourceBias = sourcePreferenceBias(
                source: item.source,
                contentPack: selectedPack,
                requestedProvider: generationProvider
            )
            let score = adaptiveRanker.adviceScore(
                semanticRelevance: safetyAdjustedRelevance,
                stats: blendedLearning,
                noveltyPenalty: noveltyPenalty,
                seed: baseSeed,
                candidateIndex: index
            ) + sourceBias
            ranked.append(
                (
                    item.candidate, item.source, score, fingerprint, candidatePoolKey,
                    seenHistorically
                ))
        }

        ranked.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.candidate.adviceLine.localizedCaseInsensitiveCompare(
                    rhs.candidate.adviceLine) == .orderedAscending
            }
            return lhs.score > rhs.score
        }

        var chosen: (candidate: GeneratedAdvice, source: String, seenHistorically: Bool)?
        for rankedCandidate in ranked {
            let alreadySeen =
                recentFingerprintSet.contains(rankedCandidate.fingerprint)
                || (recentPoolFingerprintSets[rankedCandidate.poolKey] ?? []).contains(
                    rankedCandidate.fingerprint)
                || (shouldEnforceGlobalUniqueness && rankedCandidate.seenHistorically)
            if !alreadySeen || !shouldEnforceGlobalUniqueness {
                chosen = (
                    rankedCandidate.candidate, rankedCandidate.source,
                    rankedCandidate.seenHistorically
                )
                break
            }
        }

        guard var output = chosen?.candidate ?? ranked.first?.candidate else {
            generationNotice = "Unable to rank candidates right now."
            return
        }
        let source = chosen?.source ?? ranked.first?.source ?? "engine"
        generationSourceBadgeText = generationSourceBadgeLabel(for: source)
        let outputSeenHistorically =
            chosen?.seenHistorically ?? ranked.first?.seenHistorically ?? false
        if shouldEnforceGlobalUniqueness, outputSeenHistorically {
            output = forceUniqueVariant(from: output)
        }

        rememberFingerprint(for: output)
        rememberPoolFingerprint(for: output)
        lastWhyTerrible =
            "Why this is awful: \(store.rules(for: output.category, contentPack: selectedPack).badPrinciples.randomElement() ?? "certainty without evidence")."
        current = repository.insert(output)
        invalidateRetentionSnapshot()
        NotificationManager.updateGenerationActivity(date: output.createdAt)
        NotificationManager.scheduleDaily()
        repository.recordLearningSignal(
            scopeKey: adviceScopeKey(category: output.category, tone: output.tone),
            type: .shown
        )
        leaderboardVersion += 1

        // Achievement Tracking
        let total = repository.historyCount()
        achievementsManager.trackAdviceGenerated(
            tone: output.tone, category: output.category, totalCount: total)
        achievementsManager.trackStreak(days: challengeStreakDays)

        analyticsTracker.track(
            "generate",
            properties: [
                "category": output.category.rawValue,
                "selected_category": selectedCategory.rawValue,
                "resolved_category": resolvedCategory.rawValue,
                "tone": output.tone.rawValue,
                "selected_tone": selectedTone.rawValue,
                "content_pack": selectedPack.rawValue,
                "generation_provider": generationProvider.rawValue,
                "source": source,
                "has_situation": situation == nil ? "false" : "true",
                "strict_no_repeats": shouldEnforceGlobalUniqueness ? "true" : "false",
                "community_only": communityOnlyMode ? "true" : "false",
            ])
        rotatePrimaryActionTitleIfNeeded()

        // Nuanced Haptics: Alpha Podcast/Crypto/Toxic get heavy kicks. Minimal/Monk get light taps.
        if let profile = self.store.toneProfiles[output.tone] {
            let intensity = profile.rhetoricalTick.count
            hapticWeight = Double(min(max(intensity, 1), 6)) / 6.0
        }
        hapticTrigger += 1
        trackMissionCompletionIfNeeded()
        trackWeeklyMissionProgressIfNeeded(with: output)
        if let generationProviderNotice {
            generationNotice = generationProviderNotice
        }
    }

    private func appleOnDeviceCandidateBatch(
        category: AdviceCategory,
        tone: ToneMode,
        situation: String?,
        includeRationale: Bool,
        baseSeed: Int,
        maxCount: Int,
        requestedProvider: AdviceGenerationProvider
    ) async -> (candidates: [GeneratedAdvice], notice: String?, fallbackReason: String?) {
        let availability = AppleOnDeviceAdviceBridge.currentAvailability()
        let requestedExplicitly = requestedProvider == .appleOnDevice
        switch settingsViewModel.appleLocalGenerationGate {
        case .ready(let modelID):
            if requestedProvider != .classic {
                analyticsTracker.track(
                    "apple_local_model_selected",
                    properties: [
                        "requested_provider": requestedProvider.rawValue,
                        "selected_model_id": modelID,
                    ])
            }
        case .unavailable(let reasonKey, let message, _, _):
            return (
                [],
                requestedExplicitly ? "\(message) Using classic generator." : nil,
                "selection_\(reasonKey)"
            )
        }
        guard availability.isReady else {
            return (
                [], requestedExplicitly ? availability.statusText : nil,
                "availability_\(availability.analyticsKey)"
            )
        }

        var candidates: [GeneratedAdvice] = []
        var seenFingerprints = Set<String>()
        let desiredCount = max(1, maxCount)

        for index in 0..<desiredCount {
            do {
                let candidate = try await appleOnDeviceBridge.generateCandidate(
                    category: category,
                    tone: tone,
                    situation: situation,
                    includeRationale: includeRationale,
                    seed: baseSeed + (index * 4_099),
                    now: Date()
                )
                guard engine.validateOutput(candidate, for: category) else { continue }
                let fingerprint = candidate.adviceLine.normalizedForFiltering
                if seenFingerprints.insert(fingerprint).inserted {
                    candidates.append(candidate)
                }
            } catch {
                logger.error(
                    "Apple on-device generation failed: \(String(describing: error), privacy: .public)"
                )
                if requestedExplicitly, candidates.isEmpty {
                    return (
                        [], "Apple on-device generation failed. Using classic generator.",
                        "generation_failed"
                    )
                }
                break
            }
        }

        if requestedExplicitly, candidates.isEmpty {
            return (
                [],
                "Apple on-device model is available, but no valid output was produced. Using classic generator.",
                "no_valid_output"
            )
        }

        if !requestedExplicitly, candidates.isEmpty {
            return ([], nil, "no_candidate_auto")
        }

        return (candidates, nil, nil)
    }

    private func generationSourceBadgeLabel(for source: String) -> String {
        switch source {
        case "apple_on_device":
            return "Apple On-Device"
        case "engine":
            return "Classic"
        case "ml_remix":
            return "Remix"
        case "community":
            return "Community"
        default:
            return source.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func sourcePreferenceBias(
        source: String,
        contentPack: ContentPack,
        requestedProvider: AdviceGenerationProvider
    ) -> Double {
        switch source {
        case "engine":
            return contentPack == .classic ? 0.08 : 0.04
        case "ml_remix":
            return contentPack == .classic ? -0.05 : -0.01
        case "apple_on_device":
            return requestedProvider == .appleOnDevice ? 0.06 : 0.02
        case "community":
            return 0.01
        default:
            return 0
        }
    }

    func surpriseMeAndGenerate() {
        selectedCategory = AdviceCategory.allCases.randomElement() ?? .dating
        selectedTone = ToneMode.allCases.randomElement() ?? .corporateConsultant
        analyticsTracker.track(
            "surprise_me",
            properties: [
                "category": selectedCategory.rawValue,
                "tone": selectedTone.rawValue,
                "content_pack": settingsViewModel.preferredContentPack.rawValue,
            ])
        Task {
            await generate()
        }
    }

    /// Re-generates advice with the same category, tone, and scenario but a fresh seed —
    /// only the wording/framing changes.
    func remixCurrentAdvice() {
        guard current != nil, !isGenerating else { return }
        analyticsTracker.track(
            "remix_advice",
            properties: [
                "category": selectedCategory.rawValue,
                "tone": selectedTone.rawValue,
            ])
        Task {
            await generate(
                seed: Int(Date().timeIntervalSince1970 * 1_000) &+ Int.random(in: 1...9999))
        }
    }

    func generateDailyDrop() {
        guard !isGenerating else { return }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let categories = AdviceCategory.concrete
        let tones = ToneMode.allCases
        selectedCategory = categories[day % categories.count]
        selectedTone = tones[(day * 3) % tones.count]
        analyticsTracker.track(
            "daily_drop",
            properties: [
                "day_of_year": "\(day)",
                "category": selectedCategory.rawValue,
                "tone": selectedTone.rawValue,
                "content_pack": settingsViewModel.preferredContentPack.rawValue,
            ])
        Task {
            await generate(seed: day * 1013)
        }
    }

    func runDailyMissionGeneration() {
        guard !isGenerating else { return }
        let mission = dailyMissionState
        selectedCategory = mission.category
        selectedTone = mission.tone
        scenarioText = ""
        Task {
            await generate(seed: stableSeed(for: mission.key))
        }
    }

    func trackChaosHubOpened() {
        let mission = dailyMissionState
        analyticsTracker.track(
            "chaos_hub_open",
            properties: [
                "mission_key": mission.key,
                "mission_complete": mission.isComplete ? "true" : "false",
                "streak_days": "\(challengeStreakDays)",
            ])
    }

    func trackChaosHubAction(_ action: String) {
        analyticsTracker.track(
            "chaos_hub_action",
            properties: [
                "action": action,
                "category": selectedCategory.rawValue,
                "tone": selectedTone.rawValue,
            ])
    }

    func applySuggestion(_ suggestion: String) {
        scenarioText = suggestion
    }

    func toggleFavorite() {
        guard let current else { return }
        let newValue = !current.isFavorite
        repository.toggleFavorite(current)
        if newValue {
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .favorite
            )
        }
        analyticsTracker.track(
            "toggle_favorite",
            properties: [
                "is_favorite": newValue ? "true" : "false"
            ])
        playHaptic(style: .light)
    }

    func toggleVote(_ vote: AdviceVoteState) {
        guard let current else { return }
        let next: AdviceVoteState = current.vote == vote ? .none : vote
        repository.setVote(current, vote: next)
        switch next {
        case .like:
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .like
            )
        case .dislike:
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .dislike
            )
        case .none:
            break
        }
        leaderboardVersion += 1
        analyticsTracker.track(
            "advice_vote",
            properties: [
                "vote": "\(next.rawValue)"
            ])
        playHaptic(style: .light)
    }

    func submitSuggestion(
        category: AdviceCategory,
        topic: String,
        adviceLine: String
    ) -> String? {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAdvice = adviceLine.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedTopic.count >= 3 else {
            return "Add a clearer topic (at least 3 characters)."
        }
        guard trimmedAdvice.count >= 12 else {
            return "Advice text is too short."
        }
        guard trimmedAdvice.count <= 220 else {
            return "Advice text is too long."
        }

        let combined = "\(trimmedTopic) \(trimmedAdvice)"
        guard moderation.isSafe(text: combined) else {
            return "Suggestion blocked by safety checks."
        }

        let forbidden = store.rules(for: category, contentPack: .classic).forbiddenPatterns
        let normalizedCombined = combined.normalizedForFiltering
        guard !forbidden.contains(where: { normalizedCombined.contains($0.normalizedForFiltering) })
        else {
            return "Suggestion conflicts with safety constraints for this category."
        }

        _ = repository.addSuggestion(
            category: category,
            topic: String(trimmedTopic.prefix(72)),
            adviceLine: String(trimmedAdvice.prefix(220))
        )
        cachedRecentSuggestions = repository.fetchSuggestions(limit: 20)
        suggestionsVersion += 1
        leaderboardVersion += 1
        analyticsTracker.track(
            "suggestion_submit",
            properties: [
                "category": category.rawValue
            ])
        return nil
    }

    func deleteSuggestion(_ suggestion: UserAdviceSuggestion) {
        repository.deleteSuggestion(suggestion)
        cachedRecentSuggestions = repository.fetchSuggestions(limit: 20)
        suggestionsVersion += 1
        leaderboardVersion += 1
        analyticsTracker.track("suggestion_delete", properties: [:])
    }

    func markFavorite() {
        guard let current else { return }
        repository.setFavorite(current, isFavorite: true)
        repository.recordLearningSignal(
            scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
            type: .favorite
        )
        analyticsTracker.track("save_from_generate", properties: [:])
        playHaptic(style: .light)
    }

    var isCurrentFavorite: Bool {
        current?.isFavorite ?? false
    }

    var currentVote: AdviceVoteState {
        current?.vote ?? .none
    }

    private var cachedRecentSuggestions: [UserAdviceSuggestion] = []

    var recentSuggestions: [UserAdviceSuggestion] {
        _ = suggestionsVersion
        return cachedRecentSuggestions
    }

    var communitySuggestionCount: Int {
        _ = suggestionsVersion
        return repository.suggestionCount()
    }

    var topCommunityTopics: [TopicLeaderboardItem] {
        _ = leaderboardVersion
        let suggestions = repository.fetchSuggestions(limit: 250)
        var grouped: [String: (category: AdviceCategory, topic: String, count: Int)] = [:]
        for suggestion in suggestions {
            let normalizedTopic = suggestion.topic.normalizedForFiltering
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTopic.isEmpty else { continue }
            let key = "\(suggestion.category.rawValue)|\(normalizedTopic)"
            if var existing = grouped[key] {
                existing.count += 1
                grouped[key] = existing
            } else {
                grouped[key] = (suggestion.category, suggestion.topic, 1)
            }
        }
        return
            grouped
            .map { key, value in
                TopicLeaderboardItem(
                    id: key,
                    category: value.category,
                    topic: value.topic,
                    submissions: value.count
                )
            }
            .sorted {
                if $0.submissions == $1.submissions {
                    return $0.topic.localizedCaseInsensitiveCompare($1.topic) == .orderedAscending
                }
                return $0.submissions > $1.submissions
            }
            .prefix(8)
            .map { $0 }
    }

    var topLikedAdvice: [AdviceLeaderboardItem] {
        voteLeaderboard(for: .like)
    }

    var topDislikedAdvice: [AdviceLeaderboardItem] {
        voteLeaderboard(for: .dislike)
    }

    var currentShareText: String {
        guard let current else { return "" }
        let caption = shareCaption(for: current)
        if let rationale = current.rationaleLine, !rationale.isEmpty {
            let summarySource = "\(current.adviceLine) \(rationale)"
            if let summary = summarize(text: summarySource, maxSentences: 2, maxCharacters: 180),
                summary.count < summarySource.count
            {
                return
                    "\(caption)\n\n\(current.adviceLine)\n\n\(rationale)\n\nTL;DR \(summary)\n\nBadvice"
            }
            return "\(caption)\n\n\(current.adviceLine)\n\n\(rationale)\n\nBadvice"
        }
        return "\(caption)\n\n\(current.adviceLine)\n\nBadvice"
    }

    var currentSharePayload: ShareCardContent? {
        guard let current else { return nil }
        return ShareCardContent(
            category: current.category,
            tone: current.tone,
            adviceLine: current.adviceLine,
            rationaleLine: current.rationaleLine,
            includeDisclaimer: settingsViewModel.includeDisclaimerOnShare,
            template: settingsViewModel.preferredTemplate,
            aspectRatio: settingsViewModel.preferredAspect
        )
    }

    var keywordSuggestions: [String] {
        let category: AdviceCategory
        if selectedCategory == .random {
            if let current {
                category = current.category
            } else {
                let seed = stableSeed(for: "\(scenarioText)|\(friendName)")
                category = selectedCategory.resolved(seed: seed)
            }
        } else {
            category = selectedCategory
        }
        return Array(
            store.rules(for: category, contentPack: settingsViewModel.preferredContentPack).keywords
                .prefix(4))
    }

    var dailyBadQuote: BadQuote {
        badQuoteService.quoteOfDay()
    }

    var dailyMissionState: ChaosMissionState {
        let calendar = Calendar.current
        let now = Date()
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let year = calendar.component(.year, from: now)
        let categories = AdviceCategory.concrete
        let tones = ToneMode.concrete
        let missionCategory = categories[(dayOfYear * 2) % categories.count]
        let missionTone = tones[(dayOfYear * 5) % tones.count]
        let targetCount = 2 + (dayOfYear % 3)
        let missionKey =
            "\(year)-\(dayOfYear)-\(missionCategory.rawValue)-\(missionTone.rawValue)-\(targetCount)"
        let matchingCount = repository.todayHistoryCount(
            category: missionCategory, tone: missionTone, referenceDate: now)
        let title = "Daily Mission: \(targetCount)x \(missionTone.title)"
        let subtitle = "Run \(missionCategory.title) chaos builds before midnight."
        return ChaosMissionState(
            key: missionKey,
            category: missionCategory,
            tone: missionTone,
            targetCount: targetCount,
            currentCount: matchingCount,
            title: title,
            subtitle: subtitle
        )
    }

    var weeklyMissionState: WeeklyMissionState {
        weeklyMissionState(for: Date())
    }

    func weeklyMissionState(for referenceDate: Date) -> WeeklyMissionState {
        let calendar = Calendar.current
        let now = referenceDate
        let week = calendar.component(.weekOfYear, from: now)
        let year = calendar.component(.yearForWeekOfYear, from: now)
        let categories = AdviceCategory.concrete
        let tones = ToneMode.concrete
        let missionCategory = categories[(week * 3) % categories.count]
        let missionTone = tones[(week * 7) % tones.count]
        let targetCount = 6 + (week % 4)
        let missionKey =
            "weekly-\(year)-\(week)-\(missionCategory.rawValue)-\(missionTone.rawValue)-\(targetCount)"
        let persisted = repository.ensureMissionProgress(
            missionKey: missionKey,
            periodRaw: "weekly",
            category: missionCategory,
            tone: missionTone,
            targetCount: targetCount
        )

        return WeeklyMissionState(
            key: missionKey,
            category: missionCategory,
            tone: missionTone,
            targetCount: targetCount,
            currentCount: persisted.progressCount,
            title: "Weekly Mission: \(targetCount)x \(missionTone.title)",
            subtitle: "Complete \(missionCategory.title) chaos runs before week reset.",
            rewardClaimed: persisted.rewardClaimed
        )
    }

    var weeklyMissionCompleted: Bool {
        weeklyMissionState.isComplete
    }

    func refreshRetentionStateOnAppear(referenceDate: Date = Date()) {
        invalidateRetentionSnapshot()
        applyStreakFreezeIfNeeded(referenceDate: referenceDate)
        invalidateRetentionSnapshot()
        NotificationManager.updateStreakFreezeAvailability(
            hasAvailable: settingsViewModel.streakFreezeAvailableThisWeek)
        NotificationManager.scheduleDaily()
    }

    var dailyMissionTitle: String {
        dailyMissionState.title
    }

    var dailyMissionTargetCount: Int {
        dailyMissionState.targetCount
    }

    var dailyMissionCurrentCount: Int {
        dailyMissionState.currentCount
    }

    var dailyMissionCompleted: Bool {
        dailyMissionState.isComplete
    }

    var dailyMissionProgressFraction: Double {
        dailyMissionState.progressFraction
    }

    var chaosHubSummaryLine: String {
        let mission = dailyMissionState
        let weekly = weeklyMissionState
        let completed =
            mission.isComplete ? "complete" : "\(mission.currentCount)/\(mission.targetCount)"
        let weeklyCompleted =
            weekly.isComplete ? "done" : "\(weekly.currentCount)/\(weekly.targetCount)"
        return
            "Mission \(completed) • Weekly \(weeklyCompleted) • \(challengeStreakDays)-day streak • \(favoriteCount) saved"
    }

    var todayGeneratedCount: Int {
        repository.todayHistoryCount()
    }

    var totalGeneratedCount: Int {
        repository.historyCount()
    }

    var favoriteCount: Int {
        repository.favoriteCount()
    }

    var challengeStreakDays: Int {
        let snapshot = currentRetentionSnapshot()
        return snapshot.streakDays + snapshot.streakFreezeBonus
    }

    var challengeGoalDays: Int {
        switch challengeStreakDays {
        case 0..<3: return 3
        case 3..<7: return 7
        case 7..<14: return 14
        default: return 30
        }
    }

    var challengeProgressText: String {
        "\(min(challengeStreakDays, challengeGoalDays))/\(challengeGoalDays) day streak"
    }

    var challengeTitle: String {
        if challengeStreakDays >= challengeGoalDays {
            return "Challenge complete. Escalate."
        }
        return "Current challenge: \(challengeGoalDays)-day streak"
    }

    var uniquenessStatusText: String {
        let mode = settingsViewModel.strictNoRepeats ? "On" : "Off"
        let pack = settingsViewModel.preferredContentPack.title
        return
            "No-repeat mode: \(mode) • Global + category/tone pools • Pack: \(pack) • \(repository.seenAdviceCount()) unique lines served"
    }

    func trackShare(template: ShareCardTemplate, ratio: ShareAspectRatio) {
        if let current {
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .share
            )
            repository.incrementShareCount(for: current.id)
        }
        analyticsTracker.track(
            "share_card",
            properties: [
                "template": template.rawValue,
                "ratio": ratio.rawValue,
                "caption_preset": settingsViewModel.preferredSharePreset.rawValue,
            ])
    }

    func trackCopy() {
        if let current {
            repository.recordLearningSignal(
                scopeKey: adviceScopeKey(category: current.category, tone: current.tone),
                type: .copy
            )
            repository.incrementCopyCount(for: current.id)
        }
        analyticsTracker.track("copy_text", properties: [:])
    }

    // MARK: - Leaderboard

    var leaderboardTopShared: [AdviceRecord] { repository.topByShares(limit: 5) }
    var leaderboardTopCopied: [AdviceRecord] { repository.topByCopies(limit: 5) }
    var leaderboardTopLiked: [AdviceRecord] { repository.topByLikes(limit: 5) }
    var weeklyRecapFavorites: [AdviceRecord] { repository.thisWeekFavorites() }

    private func playHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        HapticsManager.play(style: style, isEnabled: settingsViewModel.hapticsEnabled)
    }

    private func shareCaption(for record: AdviceRecord) -> String {
        switch settingsViewModel.preferredSharePreset {
        case .deadpan:
            return "Daily wisdom drop: objectively terrible, emotionally convincing."
        case .chaotic:
            return "This app should be illegal but the vibe is immaculate."
        case .fauxExpert:
            return "Consulting note: this strategy has 0% evidence and 100% confidence."
        }
    }

    private func preparedSituationText() -> String? {
        let trimmedFriend = friendName.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedTone == .friendRoast, !trimmedFriend.isEmpty {
            let base = scenarioText.trimmingCharacters(in: .whitespacesAndNewlines)
            if base.isEmpty {
                return "friend \(trimmedFriend)"
            }
            return "\(base) for friend \(trimmedFriend)"
        }
        return scenarioText
    }

    private func trackMissionCompletionIfNeeded() {
        let mission = dailyMissionState
        guard mission.isComplete else { return }
        let storageKey = Self.chaosMissionCompletionStorageKey
        if UserDefaults.standard.string(forKey: storageKey) == mission.key {
            return
        }
        UserDefaults.standard.set(mission.key, forKey: storageKey)
        analyticsTracker.track(
            "chaos_mission_complete",
            properties: [
                "mission_key": mission.key,
                "target": "\(mission.targetCount)",
                "category": mission.category.rawValue,
                "tone": mission.tone.rawValue,
            ])
    }

    private func trackWeeklyMissionProgressIfNeeded(with output: GeneratedAdvice) {
        let mission = weeklyMissionState
        guard output.category == mission.category, output.tone == mission.tone else { return }

        let before = repository.ensureMissionProgress(
            missionKey: mission.key,
            periodRaw: "weekly",
            category: mission.category,
            tone: mission.tone,
            targetCount: mission.targetCount
        )
        let previousCount = before.progressCount
        let updated = repository.incrementMissionProgress(
            missionKey: mission.key,
            periodRaw: "weekly",
            category: mission.category,
            tone: mission.tone,
            targetCount: mission.targetCount,
            by: 1
        )

        guard previousCount < mission.targetCount, updated.progressCount >= mission.targetCount
        else { return }
        guard !updated.rewardClaimed else { return }

        repository.markMissionRewardClaimed(missionKey: mission.key)
        generationNotice = "Weekly mission complete. Reward unlocked: \(ThemeMode.cosmic.title)."
        if settingsViewModel.theme != .cosmic {
            settingsViewModel.theme = .cosmic
        }
        analyticsTracker.track(
            "weekly_mission_complete",
            properties: [
                "mission_key": mission.key,
                "category": mission.category.rawValue,
                "tone": mission.tone.rawValue,
                "target": "\(mission.targetCount)",
            ])
    }

    private func applyStreakFreezeIfNeeded(referenceDate: Date) {
        let calendar = Calendar.current
        let history = repository.fetchAllHistory()
        let days = Set(history.map { calendar.startOfDay(for: $0.createdAt) })
        let today = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let hasToday = days.contains(today)
        let hasYesterday = days.contains(yesterday)
        guard !hasToday, hasYesterday else { return }

        if settingsViewModel.isStreakFreezeActive(for: today) {
            return
        }
        guard settingsViewModel.consumeStreakFreezeIfAvailable(for: today) else { return }

        generationNotice = "Streak Freeze activated. Your streak is protected for today."
        NotificationManager.updateStreakFreezeAvailability(
            hasAvailable: settingsViewModel.streakFreezeAvailableThisWeek)
        analyticsTracker.track(
            "streak_freeze_used",
            properties: [
                "day": "\(today.timeIntervalSince1970)"
            ])
    }

    private func stableSeed(for text: String) -> Int {
        text.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 16_777_619) ^ Int(scalar.value)
        }
    }

    func invalidateRetentionSnapshot() {
        retentionSnapshot = nil
    }

    private func currentRetentionSnapshot() -> RetentionSnapshot {
        if let retentionSnapshot {
            return retentionSnapshot
        }
        let snapshot = computeRetentionSnapshot()
        retentionSnapshot = snapshot
        return snapshot
    }

    private func computeRetentionSnapshot() -> RetentionSnapshot {
        let history = repository.fetchAllHistory()
        return RetentionSnapshot(
            history: history,
            streakDays: streakDays(history: history),
            streakFreezeBonus: streakFreezeBonus(history: history)
        )
    }

    private func streakDays(history: [AdviceRecord]) -> Int {
        guard !history.isEmpty else { return 0 }
        let calendar = Calendar.current
        let days = Set(history.map { calendar.startOfDay(for: $0.createdAt) })
        let sortedDays = days.sorted(by: >)
        guard let mostRecent = sortedDays.first else { return 0 }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        guard mostRecent == today || mostRecent == yesterday else { return 0 }

        var streak = 1
        var currentDay = mostRecent
        while true {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else {
                break
            }
            if days.contains(previousDay) {
                streak += 1
                currentDay = previousDay
            } else {
                break
            }
        }
        return streak
    }

    private func streakFreezeBonus(history: [AdviceRecord], referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        guard settingsViewModel.isStreakFreezeActive(for: today) else { return 0 }
        let days = Set(history.map { calendar.startOfDay(for: $0.createdAt) })
        guard !days.contains(today) else { return 0 }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        return days.contains(yesterday) ? 1 : 0
    }

    private func fingerprint(for generated: GeneratedAdvice) -> String {
        generated.adviceLine.normalizedForFiltering
    }

    private func rememberFingerprint(for generated: GeneratedAdvice) {
        recentAdviceFingerprints.append(fingerprint(for: generated))
        let overflow = recentAdviceFingerprints.count - 24
        if overflow > 0 {
            recentAdviceFingerprints.removeFirst(overflow)
        }
    }

    private func rememberPoolFingerprint(for generated: GeneratedAdvice) {
        let key = poolKey(category: generated.category, tone: generated.tone)
        var fingerprints = recentAdviceFingerprintsByPool[key] ?? []
        fingerprints.append(fingerprint(for: generated))
        let overflow = fingerprints.count - 24
        if overflow > 0 {
            fingerprints.removeFirst(overflow)
        }
        recentAdviceFingerprintsByPool[key] = fingerprints
    }

    private func forceUniqueVariant(from base: GeneratedAdvice) -> GeneratedAdvice {
        var serial = max(repository.seenAdviceCount() + 1, 1)
        let recentSet = Set(recentAdviceFingerprints)
        let key = poolKey(category: base.category, tone: base.tone)
        let recentPoolSet = Set(recentAdviceFingerprintsByPool[key] ?? [])
        while true {
            let suffix = uniqueSuffix(for: serial)
            let updated = GeneratedAdvice(
                id: base.id,
                category: base.category,
                tone: base.tone,
                adviceLine: "\(base.adviceLine) \(suffix)",
                rationaleLine: base.rationaleLine,
                createdAt: base.createdAt
            )
            let updatedFingerprint = fingerprint(for: updated)
            if !recentSet.contains(updatedFingerprint)
                && !recentPoolSet.contains(updatedFingerprint)
                && !repository.hasSeenAdvice(updatedFingerprint)
                && !repository.hasSeenAdviceInPool(
                    updatedFingerprint,
                    category: updated.category,
                    tone: updated.tone
                )
            {
                return updated
            }
            serial += 1
        }
    }

    private struct AdviceLearningContext {
        let byCategory: [AdviceCategory: LearningStatSnapshot]
        let byTone: [ToneMode: LearningStatSnapshot]
        let global: LearningStatSnapshot
    }

    private struct LearningAccumulator {
        var shownCount: Double = 0
        var likeCount: Double = 0
        var dislikeCount: Double = 0
        var favoriteCount: Double = 0
        var copyCount: Double = 0
        var shareCount: Double = 0
        var regenCount: Double = 0
        var lastUpdatedAt: Date?

        mutating func include(_ snapshot: LearningStatSnapshot) {
            shownCount += snapshot.shownCount
            likeCount += snapshot.likeCount
            dislikeCount += snapshot.dislikeCount
            favoriteCount += snapshot.favoriteCount
            copyCount += snapshot.copyCount
            shareCount += snapshot.shareCount
            regenCount += snapshot.regenCount
            if let timestamp = snapshot.lastUpdatedAt {
                if let current = lastUpdatedAt {
                    if timestamp > current {
                        lastUpdatedAt = timestamp
                    }
                } else {
                    lastUpdatedAt = timestamp
                }
            }
        }

        var snapshot: LearningStatSnapshot {
            LearningStatSnapshot(
                shownCount: shownCount,
                likeCount: likeCount,
                dislikeCount: dislikeCount,
                favoriteCount: favoriteCount,
                copyCount: copyCount,
                shareCount: shareCount,
                regenCount: regenCount,
                lastUpdatedAt: lastUpdatedAt
            )
        }
    }

    private func adviceLearningContext() -> AdviceLearningContext {
        let stats = repository.learningStats(prefix: "advice|")
        var categoryAccumulators: [AdviceCategory: LearningAccumulator] = [:]
        var toneAccumulators: [ToneMode: LearningAccumulator] = [:]
        var globalAccumulator = LearningAccumulator()

        for stat in stats {
            let parts = stat.scopeKey.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count >= 3, parts[0] == "advice" else { continue }
            let snapshot = stat.snapshot
            globalAccumulator.include(snapshot)

            if let category = AdviceCategory(rawValue: String(parts[1])) {
                var categoryAccumulator = categoryAccumulators[category] ?? LearningAccumulator()
                categoryAccumulator.include(snapshot)
                categoryAccumulators[category] = categoryAccumulator
            }
            if let tone = ToneMode(rawValue: String(parts[2])) {
                var toneAccumulator = toneAccumulators[tone] ?? LearningAccumulator()
                toneAccumulator.include(snapshot)
                toneAccumulators[tone] = toneAccumulator
            }
        }

        return AdviceLearningContext(
            byCategory: categoryAccumulators.mapValues(\.snapshot),
            byTone: toneAccumulators.mapValues(\.snapshot),
            global: globalAccumulator.snapshot
        )
    }

    private func resolveCategory(
        seed: Int,
        context: AdviceLearningContext,
        situation: String,
        contentPack: ContentPack
    ) -> AdviceCategory {
        guard selectedCategory == .random else { return selectedCategory }
        let pool = AdviceCategory.concrete
        let normalizedSituation = situation.normalizedForFiltering
        let weights = pool.map { category in
            let learningWeight = preferenceWeight(for: context.byCategory[category] ?? .empty)
            let contextWeight = contextualCategoryWeight(
                category: category,
                normalizedSituation: normalizedSituation,
                contentPack: contentPack
            )
            return learningWeight * contextWeight
        }
        return weightedChoice(items: pool, weights: weights, seed: seed, salt: 41)
    }

    private func resolveTone(seed: Int, context: AdviceLearningContext) -> ToneMode {
        guard selectedTone == .random else { return selectedTone }
        let pool = ToneMode.concrete
        let weights = pool.map { preferenceWeight(for: context.byTone[$0] ?? .empty) }
        return weightedChoice(items: pool, weights: weights, seed: seed, salt: 97)
    }

    private func preferenceWeight(for snapshot: LearningStatSnapshot) -> Double {
        let positive =
            snapshot.likeCount
            + (snapshot.favoriteCount * 1.25)
            + (snapshot.shareCount * 1.05)
            + (snapshot.copyCount * 0.9)
            + (snapshot.regenCount * 0.6)
        let negative = snapshot.dislikeCount * 1.2
        let exposure = max(snapshot.shownCount, 3)
        let netScore = (positive - negative) / exposure
        let freshnessBias = 0.6 + (snapshot.freshnessScore * 0.4)
        let clamped = max(-0.45, min(0.85, netScore * freshnessBias))
        return max(0.2, 1.0 + clamped)
    }

    private func templateBias(
        for category: AdviceCategory,
        tone: ToneMode,
        context: AdviceLearningContext
    ) -> Double {
        let toneSnapshot = context.byTone[tone] ?? .empty
        let categorySnapshot = context.byCategory[category] ?? .empty
        let recency = max(toneSnapshot.freshnessScore, categorySnapshot.freshnessScore)
        let engagement = (toneSnapshot.engagementRatio + categorySnapshot.engagementRatio) / 2
        let richness = min((toneSnapshot.signalRichness + categorySnapshot.signalRichness) / 2, 1.0)
        let base = 0.35 + (recency * 0.35) + (engagement * 0.25) + (richness * 0.15)
        return min(max(base, 0.15), 0.95)
    }

    private func contextualCategoryWeight(
        category: AdviceCategory,
        normalizedSituation: String,
        contentPack: ContentPack
    ) -> Double {
        guard !normalizedSituation.isEmpty else { return 1.0 }
        let keywords = store.rules(for: category, contentPack: contentPack).keywords
        guard !keywords.isEmpty else { return 1.0 }
        var matches = 0
        for keyword in keywords {
            let normalizedKeyword = keyword.normalizedForFiltering
            guard !normalizedKeyword.isEmpty else { continue }
            if normalizedSituation.contains(normalizedKeyword) {
                matches += 1
            }
        }
        guard matches > 0 else { return 1.0 }
        let capped = min(matches, 6)
        return 1.0 + (Double(capped) * 0.35)
    }

    private func weightedChoice<T>(items: [T], weights: [Double], seed: Int, salt: Int) -> T {
        guard items.count == weights.count, let first = items.first else {
            preconditionFailure("Weighted choice requires matching, non-empty inputs.")
        }
        let total = weights.reduce(0, +)
        guard total > 0 else {
            let index = seed.positiveModulo(items.count)
            return items[index]
        }
        let target = unitRandom(seed: seed, salt: salt) * total
        var cumulative: Double = 0
        for (index, weight) in weights.enumerated() {
            cumulative += weight
            if target <= cumulative {
                return items[index]
            }
        }
        return first
    }

    private func unitRandom(seed: Int, salt: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed))
        value ^= UInt64(bitPattern: Int64(salt &* 7919))
        value = value &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        let bucket = value % 10_000
        return Double(bucket) / 10_000.0
    }

    private func summarize(text: String, maxSentences: Int, maxCharacters: Int) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else { return nil }
        let sentences = trimmed.split(whereSeparator: { ".!?".contains($0) })
        guard !sentences.isEmpty else { return nil }
        let selection = sentences.prefix(maxSentences).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var summary = selection.joined(separator: ". ")
        if !summary.isEmpty, !summary.hasSuffix(".") {
            summary.append(".")
        }
        if summary.count > maxCharacters {
            let prefix = String(summary.prefix(maxCharacters))
            if let lastSpace = prefix.lastIndex(of: " ") {
                summary = String(prefix[..<lastSpace])
            } else {
                summary = prefix
            }
        }
        return summary
    }

    private func blendedAdviceLearningSnapshot(
        exact: LearningStatSnapshot,
        category: AdviceCategory,
        tone: ToneMode,
        context: AdviceLearningContext
    ) -> LearningStatSnapshot {
        var blended = exact
        let richness = exact.signalRichness

        let categoryWeight = max(0.10, 0.34 - (richness * 0.16))
        let toneWeight = max(0.07, 0.20 - (richness * 0.08))
        let globalWeight = max(0.04, 0.13 - (richness * 0.06))

        let categoryPrior = softenedLearningPrior(
            context.byCategory[category] ?? .empty,
            shownCap: 12,
            signalCap: 10
        )
        let tonePrior = softenedLearningPrior(
            context.byTone[tone] ?? .empty,
            shownCap: 9,
            signalCap: 7
        )
        let globalPrior = softenedLearningPrior(
            context.global,
            shownCap: 6,
            signalCap: 5
        )

        blended = mergeLearningSnapshots(
            blended, scaledLearningSnapshot(categoryPrior, by: categoryWeight))
        blended = mergeLearningSnapshots(blended, scaledLearningSnapshot(tonePrior, by: toneWeight))
        blended = mergeLearningSnapshots(
            blended, scaledLearningSnapshot(globalPrior, by: globalWeight))
        return blended
    }

    private func softenedLearningPrior(
        _ snapshot: LearningStatSnapshot,
        shownCap: Double,
        signalCap: Double
    ) -> LearningStatSnapshot {
        let shownScale = snapshot.shownCount > 0 ? min(1.0, shownCap / snapshot.shownCount) : 1.0
        let signals =
            snapshot.likeCount + snapshot.dislikeCount + snapshot.favoriteCount
            + snapshot.copyCount + snapshot.shareCount + snapshot.regenCount
        let signalScale = signals > 0 ? min(1.0, signalCap / signals) : 1.0
        return scaledLearningSnapshot(snapshot, by: min(shownScale, signalScale))
    }

    private func scaledLearningSnapshot(_ snapshot: LearningStatSnapshot, by factor: Double)
        -> LearningStatSnapshot
    {
        let safeFactor = max(factor, 0)
        return LearningStatSnapshot(
            shownCount: snapshot.shownCount * safeFactor,
            likeCount: snapshot.likeCount * safeFactor,
            dislikeCount: snapshot.dislikeCount * safeFactor,
            favoriteCount: snapshot.favoriteCount * safeFactor,
            copyCount: snapshot.copyCount * safeFactor,
            shareCount: snapshot.shareCount * safeFactor,
            regenCount: snapshot.regenCount * safeFactor,
            lastUpdatedAt: snapshot.lastUpdatedAt
        )
    }

    private func mergeLearningSnapshots(
        _ lhs: LearningStatSnapshot,
        _ rhs: LearningStatSnapshot
    ) -> LearningStatSnapshot {
        let mergedUpdatedAt: Date?
        switch (lhs.lastUpdatedAt, rhs.lastUpdatedAt) {
        case (.some(let l), .some(let r)):
            mergedUpdatedAt = max(l, r)
        case (.some(let l), .none):
            mergedUpdatedAt = l
        case (.none, .some(let r)):
            mergedUpdatedAt = r
        case (.none, .none):
            mergedUpdatedAt = nil
        }

        return LearningStatSnapshot(
            shownCount: lhs.shownCount + rhs.shownCount,
            likeCount: lhs.likeCount + rhs.likeCount,
            dislikeCount: lhs.dislikeCount + rhs.dislikeCount,
            favoriteCount: lhs.favoriteCount + rhs.favoriteCount,
            copyCount: lhs.copyCount + rhs.copyCount,
            shareCount: lhs.shareCount + rhs.shareCount,
            regenCount: lhs.regenCount + rhs.regenCount,
            lastUpdatedAt: mergedUpdatedAt
        )
    }

    private func voteLeaderboard(for state: AdviceVoteState) -> [AdviceLeaderboardItem] {
        _ = leaderboardVersion
        let records = repository.fetchHistory(limit: 50).filter { $0.vote == state }
        var grouped:
            [String: (category: AdviceCategory, tone: ToneMode, adviceLine: String, count: Int)] =
                [:]
        for record in records {
            let normalizedAdvice = record.adviceLine.normalizedForFiltering
            if var existing = grouped[normalizedAdvice] {
                existing.count += 1
                grouped[normalizedAdvice] = existing
            } else {
                grouped[normalizedAdvice] = (record.category, record.tone, record.adviceLine, 1)
            }
        }
        return
            grouped
            .map { key, value in
                AdviceLeaderboardItem(
                    id: key,
                    category: value.category,
                    tone: value.tone,
                    adviceLine: value.adviceLine,
                    votes: value.count
                )
            }
            .sorted {
                if $0.votes == $1.votes {
                    return $0.adviceLine.localizedCaseInsensitiveCompare($1.adviceLine)
                        == .orderedAscending
                }
                return $0.votes > $1.votes
            }
            .prefix(8)
            .map { $0 }
    }

    private func poolKey(category: AdviceCategory, tone: ToneMode) -> String {
        "\(category.rawValue)|\(tone.rawValue)"
    }

    private func adviceScopeKey(category: AdviceCategory, tone: ToneMode) -> String {
        "advice|\(category.rawValue)|\(tone.rawValue)"
    }

    private func rotatePrimaryActionTitleIfNeeded() {
        successfulGenerationCount += 1
        guard successfulGenerationCount % 3 == 0 else { return }
        let choices = Self.primaryActionTitles.filter { $0 != primaryActionTitle }
        primaryActionTitle =
            choices.randomElement() ?? Self.primaryActionTitles.first ?? "Advise Me"
    }

    private func uniqueSuffix(for serial: Int) -> String {
        let adjectives = [
            "chaos", "executive", "moonshot", "unhinged", "legacy", "side-quest", "founder",
            "main-character",
        ]
        let nouns = [
            "protocol", "playbook", "framework", "operating system", "ritual", "policy", "method",
            "blueprint",
        ]
        let adjective = adjectives[serial % adjectives.count]
        let nounIndex = (serial / adjectives.count) % nouns.count
        let noun = nouns[nounIndex]
        let token = String(serial, radix: 36).uppercased()
        return "Call this the \(adjective) \(noun) \(token)."
    }

    private func suggestionCandidates(for category: AdviceCategory, situation: String?) async
        -> [UserAdviceSuggestion]
    {
        let all = repository.fetchSuggestions(limit: 120).filter {
            $0.category == category
                && !$0.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.adviceLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let normalizedSituation = situation?.normalizedForFiltering ?? ""
        guard !normalizedSituation.isEmpty else { return all }
        let scorer = SemanticTextScorer.shared
        let preparedQuery = await scorer.preparedQuery(from: normalizedSituation)

        var ranked: [(suggestion: UserAdviceSuggestion, score: Double, lexicalMatch: Bool)] = []
        ranked.reserveCapacity(all.count)
        for suggestion in all {
            let topic = suggestion.topic.normalizedForFiltering
            let lexicalMatch =
                !topic.isEmpty
                && (normalizedSituation.contains(topic) || topic.contains(normalizedSituation))
            let semanticScore =
                if let preparedQuery {
                    await scorer.similarity(
                        "\(suggestion.topic) \(suggestion.adviceLine)", to: preparedQuery)
                } else {
                    0.0
                }
            ranked.append((suggestion, semanticScore, lexicalMatch))
        }

        ranked.sort { lhs, rhs in
            if lhs.lexicalMatch != rhs.lexicalMatch {
                return lhs.lexicalMatch && !rhs.lexicalMatch
            }
            if lhs.score == rhs.score {
                return lhs.suggestion.topic.localizedCaseInsensitiveCompare(rhs.suggestion.topic)
                    == .orderedAscending
            }
            return lhs.score > rhs.score
        }

        let prioritized = ranked.filter { $0.lexicalMatch || $0.score >= 0.18 }
        return (prioritized.isEmpty ? ranked : prioritized).map(\.suggestion)
    }

    /// ML Remix Lab for advice: synthesizes new candidates by blending patterns from the
    /// user's liked advice history with fresh engine-generated lines using remix templates.
    private func synthesizedAdviceCandidates(
        category: AdviceCategory,
        tone: ToneMode,
        seed: Int,
        includeRationale: Bool,
        contentPack: ContentPack,
        limit: Int = 3
    ) async -> [GeneratedAdvice] {

        // Only remix when we have enough liked history to learn from
        let likedHistory = repository.fetchHistory(limit: 80)
            .filter { $0.vote == .like && $0.category == category }
        guard likedHistory.count >= 2 else { return [] }

        // Templates use {stem} and {keyword} — safe against any % characters in advice text
        let remixTemplates = [
            "Build on this: {stem}. Now reframe it for {keyword}.",
            "Take the energy of: {stem}. Apply it to {keyword}.",
            "The real lesson of {stem} is that {keyword} deserves the same commitment.",
            "Escalate the logic of {stem}. That same move works for {keyword}.",
            "If {stem} was the answer, {keyword} is the next question — commit anyway.",
            "What worked in {stem} applies directly: {keyword}, with more confidence.",
            "Channel the spirit of {stem}. Your play for {keyword}: all in, no caveats.",
            "Treat {stem} as the baseline. Push {keyword} twice as hard and call it consistency.",
            "The momentum behind {stem} should define your next move on {keyword}.",
            "Use {stem} as precedent and execute {keyword} without recalibration.",
            "Frame {keyword} as phase two of {stem}, then skip the risk review.",
            "Repackage the confidence from {stem} into a full-send strategy for {keyword}.",
            "If {stem} worked once, scale the same logic across {keyword} immediately.",
        ]

        let rules = store.rules(for: category, contentPack: contentPack)
        let voice = store.profile(
            for: tone == .random ? (ToneMode.concrete[seed.positiveModulo(ToneMode.concrete.count)]) : tone)

        var built: [GeneratedAdvice] = []
        var seen = Set<String>()

        for (index, record) in likedHistory.prefix(limit * 3).enumerated() {
            guard built.count < limit else { break }

            let stemWords = record.adviceLine
                .split(separator: " ")
                .prefix(7)
                .map(String.init)
                .joined(separator: " ")
            guard stemWords.count >= 10 else { continue }

            let keyword = rules.keywords[
                (index * 7 + record.adviceLine.count) % max(rules.keywords.count, 1)]
            let template = remixTemplates[(record.adviceLine.count + index) % remixTemplates.count]
            let remixed =
                template
                .replacingOccurrences(of: "{stem}", with: stemWords)
                .replacingOccurrences(of: "{keyword}", with: keyword)

            guard remixed.count <= 200 else { continue }
            guard moderation.isSafe(text: remixed) else { continue }

            let opener = voice.opener[(seed + index) % voice.opener.count]
            let confidence = voice.confidenceTag[(seed + index * 3) % voice.confidenceTag.count]
            let ending = voice.ending[(seed + index * 5) % voice.ending.count]

            let adviceLine = "\(opener), \(remixed) \(confidence) \(ending)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = adviceLine.normalizedForFiltering
            guard seen.insert(normalized).inserted else { continue }
            guard moderation.isSafe(text: adviceLine) else { continue }

            let rationale: String? =
                includeRationale
                ? "ML Remix: pattern from your liked advice blended with \(category.title) principles."
                : nil

            let resolvedTone =
                tone == .random
                ? ToneMode.concrete[(seed + index).positiveModulo(ToneMode.concrete.count)]
                : tone

            built.append(
                GeneratedAdvice(
                    category: category,
                    tone: resolvedTone,
                    adviceLine: String(adviceLine.prefix(220)),
                    rationaleLine: rationale
                ))
        }

        return built
    }

    private func communityCandidates(
        from pool: [UserAdviceSuggestion],
        baseSeed: Int,
        maxCount: Int
    ) -> [GeneratedAdvice] {
        guard !pool.isEmpty, maxCount > 0 else { return [] }
        var results: [GeneratedAdvice] = []
        var seen = Set<String>()

        for attempt in 0..<(min(maxCount, pool.count)) {
            let index = (baseSeed + (attempt * 37)).positiveModulo(pool.count)
            let suggestion = pool[index]
            guard moderation.isSafe(text: "\(suggestion.topic) \(suggestion.adviceLine)") else {
                continue
            }

            let normalizedAdvice = suggestion.adviceLine.normalizedForFiltering
            guard seen.insert(normalizedAdvice).inserted else { continue }

            let rationale: String?
            if settingsViewModel.includeRationale {
                rationale =
                    "Community bad idea: for \(suggestion.topic), confidence was preferred over caution."
            } else {
                rationale = nil
            }

            results.append(
                GeneratedAdvice(
                    category: suggestion.category,
                    tone: selectedTone,
                    adviceLine: suggestion.adviceLine,
                    rationaleLine: rationale
                )
            )
        }

        return results
    }

    private static let primaryActionTitles = [
        "Advise Me",
        "Need Bad Advice",
        "Make It Worse",
        "Hit Me With Chaos",
        "Give Me A Terrible Plan",
        "Destroy My Judgment",
        "Consult The Oracle",
        "What Could Go Wrong?",
        "Ruin My Week",
        "Show Me The Chaos",
        "Deploy Bad Wisdom",
    ]
}

@MainActor
@Observable
final class QuotesViewModel {
    private let repository: AdviceRepository
    private let quoteService: BadQuoteService
    private let moderation: ContentModeration
    private let store: AdviceStore
    private let analyticsTracker: AnalyticsTracking
    private let localModelStore: LocalModelStore
    private let appleOnDeviceBridge: AppleOnDeviceAdviceBridge
    private let adaptiveRanker = AdaptiveRanker()

    var searchText: String = "" {
        didSet { scheduleSearchDebounce(searchText) }
    }
    var selectedCategory: AdviceCategory? {
        didSet { scheduleFilteredQuotesRefresh() }
    }
    var rankingMode: QuoteRankingMode = .recent {
        didSet { scheduleFilteredQuotesRefresh() }
    }
    private var quoteSuggestions: [UserQuoteSuggestion] = []
    private var votesByQuoteID: [String: AdviceVoteState] = [:]
    private var cachedAllQuotes: [BadQuote] = []
    private var cachedFilteredQuotes: [BadQuote] = []
    private var quoteSearchIndex: [String: String] = [:]
    private var quoteScopeKeyByID: [String: String] = [:]
    private var debouncedSearchText = ""
    private var searchDebounceTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?
    private var modelQuoteTask: Task<Void, Never>?
    private var refreshGeneration: Int = 0
    private var cachedModelGeneratedQuotes: [BadQuote] = []
    private var lastModelQuoteOverlayKey: String?
    #if DEBUG
        var debugSourceFilter: QuoteSourceDebugFilter = .all {
            didSet { scheduleFilteredQuotesRefresh() }
        }
    #endif

    init(
        repository: AdviceRepository,
        quoteService: BadQuoteService = BadQuoteService(),
        moderation: ContentModeration = ContentModeration(),
        store: AdviceStore = AdviceStore(),
        localModelStore: LocalModelStore,
        analyticsTracker: AnalyticsTracking = AppAnalyticsTracker()
    ) {
        self.repository = repository
        self.quoteService = quoteService
        self.moderation = moderation
        self.store = store
        self.analyticsTracker = analyticsTracker
        self.localModelStore = localModelStore
        self.appleOnDeviceBridge = AppleOnDeviceAdviceBridge(moderation: moderation)
        self.debouncedSearchText = searchText
        reloadCachedData()
    }

    convenience init(
        repository: AdviceRepository,
        quoteService: BadQuoteService = BadQuoteService(),
        moderation: ContentModeration = ContentModeration(),
        store: AdviceStore = AdviceStore(),
        analyticsTracker: AnalyticsTracking = AppAnalyticsTracker()
    ) {
        self.init(
            repository: repository,
            quoteService: quoteService,
            moderation: moderation,
            store: store,
            localModelStore: LocalModelStore(),
            analyticsTracker: analyticsTracker
        )
    }

    var dailyQuote: BadQuote {
        quoteService.quoteOfDay()
    }

    var allQuotes: [BadQuote] {
        cachedAllQuotes
    }

    var filteredQuotes: [BadQuote] {
        cachedFilteredQuotes
    }

    var recentQuoteSuggestions: [UserQuoteSuggestion] {
        quoteSuggestions
    }

    var quoteSuggestionCount: Int {
        quoteSuggestions.count
    }

    var quoteVoteMap: [String: AdviceVoteState] {
        votesByQuoteID
    }

    var likedCount: Int {
        quoteVoteMap.values.filter { $0 == .like }.count
    }

    var dislikedCount: Int {
        quoteVoteMap.values.filter { $0 == .dislike }.count
    }

    func vote(for quote: BadQuote) -> AdviceVoteState {
        quoteVoteMap[quote.id] ?? .none
    }

    func toggleVote(_ vote: AdviceVoteState, for quote: BadQuote) {
        let currentVote = votesByQuoteID[quote.id] ?? .none
        let nextVote: AdviceVoteState = currentVote == vote ? .none : vote
        repository.setQuoteVote(quoteID: quote.id, vote: nextVote)
        switch nextVote {
        case .like:
            repository.recordLearningSignal(scopeKey: quoteScopeKey(for: quote), type: .like)
        case .dislike:
            repository.recordLearningSignal(scopeKey: quoteScopeKey(for: quote), type: .dislike)
        case .none:
            break
        }
        if nextVote == .none {
            votesByQuoteID.removeValue(forKey: quote.id)
        } else {
            votesByQuoteID[quote.id] = nextVote
        }
        scheduleFilteredQuotesRefresh()
        analyticsTracker.track(
            "quote_vote",
            properties: [
                "id": quote.id,
                "category": quote.category.rawValue,
                "vote": "\(nextVote.rawValue)",
            ])
    }

    func submitSuggestion(
        category: AdviceCategory,
        source: String,
        quoteText: String
    ) -> String? {
        let trimmedText = quoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeSource =
            trimmedSource.isEmpty ? "Community Submission" : String(trimmedSource.prefix(44))

        guard trimmedText.count >= 8 else { return "Quote text is too short." }
        guard trimmedText.count <= 160 else { return "Quote text is too long." }

        let combined = "\(safeSource) \(trimmedText)"
        guard moderation.isSafe(text: combined) else {
            return "Quote suggestion blocked by safety checks."
        }

        let forbidden = store.rules(for: category, contentPack: .classic).forbiddenPatterns
        let normalized = trimmedText.normalizedForFiltering
        guard !forbidden.contains(where: { normalized.contains($0.normalizedForFiltering) }) else {
            return "Quote suggestion conflicts with category safety constraints."
        }

        _ = repository.addQuoteSuggestion(
            category: category,
            source: safeSource,
            quoteText: String(trimmedText.prefix(160))
        )
        reloadCachedData()
        analyticsTracker.track(
            "quote_suggestion_submit",
            properties: [
                "category": category.rawValue
            ])
        return nil
    }

    func deleteSuggestion(_ suggestion: UserQuoteSuggestion) {
        repository.deleteQuoteSuggestion(suggestion)
        reloadCachedData()
        analyticsTracker.track(
            "quote_suggestion_delete",
            properties: [
                "category": suggestion.category.rawValue
            ])
    }

    func trackCopy(_ quote: BadQuote, isDaily: Bool) {
        repository.recordLearningSignal(scopeKey: quoteScopeKey(for: quote), type: .copy)
        scheduleFilteredQuotesRefresh()
        analyticsTracker.track(
            "quote_copy",
            properties: [
                "id": quote.id,
                "category": quote.category.rawValue,
                "daily": isDaily ? "true" : "false",
            ])
    }

    func trackShare(_ quote: BadQuote, isDaily: Bool) {
        repository.recordLearningSignal(scopeKey: quoteScopeKey(for: quote), type: .share)
        scheduleFilteredQuotesRefresh()
        analyticsTracker.track(
            "quote_share",
            properties: [
                "id": quote.id,
                "category": quote.category.rawValue,
                "daily": isDaily ? "true" : "false",
            ])
    }

    func quoteShareText(_ quote: BadQuote) -> String {
        "\"\(quote.text)\"\n— \(quote.source)\n\nBadvice"
    }

    func quoteSpotlightInsight(for quote: BadQuote) -> String {
        let rules = store.rules(for: quote.category, contentPack: .classic)
        guard !rules.badPrinciples.isEmpty, !rules.keywords.isEmpty else {
            return "It doubles down on overconfidence and dares you to frame \(quote.category.title.lowercased()) as the obvious move."
        }
        let seed = stableSeed(for: "\(quote.id)|\(quote.category.rawValue)|spotlight")
        let principle = rules.badPrinciples[seed.positiveModulo(rules.badPrinciples.count)]
        let keywordSeed = seed &+ 17
        let keyword = rules.keywords[keywordSeed.positiveModulo(rules.keywords.count)]
        return
            "It doubles down on \(principle.lowercased()) and dares you to frame \(keyword) as the obvious move."
    }

    private func reloadCachedData() {
        quoteSuggestions = repository.fetchQuoteSuggestions(limit: 30)
        votesByQuoteID = repository.quoteVoteMap()
        rebuildQuoteCache()
        scheduleFilteredQuotesRefresh()
        scheduleModelQuoteOverlayRefreshIfNeeded()
    }

    private func rebuildQuoteCache() {
        let base = quoteService.candidateQuotes(
            communitySuggestions: quoteSuggestions,
            store: store,
            moderation: moderation
        )
        let combinedBase = base + cachedModelGeneratedQuotes
        var seen = Set<String>()
        var merged: [BadQuote] = []
        var index: [String: String] = [:]
        var scopeIndex: [String: String] = [:]

        for quote in combinedBase {
            let normalizedText = quote.text.normalizedForFiltering
            if seen.insert(normalizedText).inserted {
                merged.append(quote)
                index[quote.id] =
                    "\(quote.text) \(quote.source) \(quote.category.title)".normalizedForFiltering
                scopeIndex[quote.id] = quoteScopeKey(for: quote)
            }
        }

        cachedAllQuotes = merged
        quoteSearchIndex = index
        quoteScopeKeyByID = scopeIndex
    }

    private func quoteScopeKey(for quote: BadQuote) -> String {
        if let cached = quoteScopeKeyByID[quote.id] {
            return cached
        }
        let sourceBucket = quote.source
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSource = sourceBucket.isEmpty ? "community submission" : sourceBucket
        return "quote|\(quote.category.rawValue)|\(normalizedSource)"
    }

    private func stableSeed(for text: String) -> Int {
        text.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 16_777_619) ^ Int(scalar.value)
        }
    }

    private func scheduleSearchDebounce(_ value: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self, value] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.debouncedSearchText = value
                self?.scheduleFilteredQuotesRefresh()
            }
        }
    }

    private func scheduleFilteredQuotesRefresh() {
        let modeFiltered = modeFilteredQuotes(for: debouncedSearchText)
        cachedFilteredQuotes = modeFiltered
        filterTask?.cancel()
        refreshGeneration += 1
        let generation = refreshGeneration
        let searchSnapshot = debouncedSearchText
        filterTask = Task { [weak self, modeFiltered, searchSnapshot] in
            await self?.refreshFilteredQuotes(
                generation: generation,
                modeFiltered: modeFiltered,
                searchText: searchSnapshot
            )
        }
    }

    private func refreshFilteredQuotes(
        generation: Int,
        modeFiltered: [BadQuote],
        searchText: String
    ) async {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = search.isEmpty ? "" : search.normalizedForFiltering

        guard modeFiltered.count > 1 else {
            guard !Task.isCancelled, generation == refreshGeneration else { return }
            cachedFilteredQuotes = modeFiltered
            return
        }

        let scorer = SemanticTextScorer.shared
        let preparedQuery =
            normalizedSearch.isEmpty ? nil : await scorer.preparedQuery(from: normalizedSearch)

        var scored: [(BadQuote, Double)] = []
        scored.reserveCapacity(modeFiltered.count)
        var learningCacheByScope: [String: LearningStatSnapshot] = [:]
        for (index, quote) in modeFiltered.enumerated() {
            if Task.isCancelled || generation != refreshGeneration {
                return
            }
            let scopeKey = quoteScopeKey(for: quote)
            let stat: LearningStatSnapshot
            if let cached = learningCacheByScope[scopeKey] {
                stat = cached
            } else {
                let snapshot = repository.learningSnapshot(for: scopeKey)
                learningCacheByScope[scopeKey] = snapshot
                stat = snapshot
            }
            let semantic: Double
            if let preparedQuery {
                semantic = await scorer.similarity(
                    "\(quote.text) \(quote.source)", to: preparedQuery)
            } else {
                semantic = 0.45
            }
            let noveltyPenalty = min(stat.shownCount / 24.0, 1.0)
            let score = adaptiveRanker.quoteScore(
                semanticRelevance: semantic,
                stats: stat,
                noveltyPenalty: noveltyPenalty,
                seed: stableSeed(for: "\(quote.id)|\(normalizedSearch)"),
                candidateIndex: index
            )
            scored.append((quote, score))
        }

        guard !Task.isCancelled, generation == refreshGeneration else { return }
        cachedFilteredQuotes =
            scored
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.text.localizedCaseInsensitiveCompare($1.0.text) == .orderedAscending
                }
                return $0.1 > $1.1
            }
            .map(\.0)
    }

    private func modeFilteredQuotes(for searchText: String) -> [BadQuote] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = search.isEmpty ? "" : search.normalizedForFiltering

        let sourceFilteredBase = cachedAllQuotes.filter { quoteMatchesDebugSourceFilter($0) }

        if normalizedSearch.isEmpty, selectedCategory == nil {
            switch rankingMode {
            case .recent:
                return sourceFilteredBase
            case .topLiked:
                return sourceFilteredBase.filter { votesByQuoteID[$0.id] == .like }
            case .topDisliked:
                return sourceFilteredBase.filter { votesByQuoteID[$0.id] == .dislike }
            }
        }

        let filtered = sourceFilteredBase.filter { quote in
            let categoryMatch = selectedCategory == nil || quote.category == selectedCategory
            if normalizedSearch.isEmpty {
                return categoryMatch
            }
            let haystack = quoteSearchIndex[quote.id] ?? ""
            return categoryMatch && haystack.contains(normalizedSearch)
        }

        switch rankingMode {
        case .recent:
            return filtered
        case .topLiked:
            return filtered.filter { votesByQuoteID[$0.id] == .like }
        case .topDisliked:
            return filtered.filter { votesByQuoteID[$0.id] == .dislike }
        }
    }

    private func quoteMatchesDebugSourceFilter(_ quote: BadQuote) -> Bool {
        #if DEBUG
            switch debugSourceFilter {
            case .all:
                return true
            case .appleModel:
                return quote.id.hasPrefix("apple-quote-")
                    || quote.source.normalizedForFiltering.contains("apple on-device")
            case .remixLab:
                return quote.source.normalizedForFiltering.contains("ml remix")
            case .community:
                return quote.id.hasPrefix("community-")
            case .curated:
                let isApple =
                    quote.id.hasPrefix("apple-quote-")
                    || quote.source.normalizedForFiltering.contains("apple on-device")
                let isRemix = quote.source.normalizedForFiltering.contains("ml remix")
                let isCommunity = quote.id.hasPrefix("community-")
                return !(isApple || isRemix || isCommunity)
            }
        #else
            return true
        #endif
    }

    private func scheduleModelQuoteOverlayRefreshIfNeeded() {
        let provider = repository.ensureSettings().preferredGenerationProvider
        let overlayKey = modelQuoteOverlayKey(provider: provider)

        if provider == .classic {
            modelQuoteTask?.cancel()
            lastModelQuoteOverlayKey = overlayKey
            if !cachedModelGeneratedQuotes.isEmpty {
                cachedModelGeneratedQuotes = []
                rebuildQuoteCache()
                scheduleFilteredQuotesRefresh()
            }
            return
        }

        if lastModelQuoteOverlayKey == overlayKey {
            return
        }
        lastModelQuoteOverlayKey = overlayKey
        modelQuoteTask?.cancel()

        let availability = AppleOnDeviceAdviceBridge.currentAvailability()
        let localGate = localModelStore.generationGate(appleAvailability: availability)
        analyticsTracker.track(
            "apple_model_availability",
            properties: [
                "requested_provider": provider.rawValue,
                "status": availability.analyticsKey,
                "surface": "quotes",
            ])

        if case .unavailable(let reasonKey, _, _, _) = localGate {
            if provider == .appleOnDevice {
                analyticsTracker.track(
                    "apple_model_fallback",
                    properties: [
                        "requested_provider": provider.rawValue,
                        "reason": "selection_\(reasonKey)",
                        "surface": "quotes",
                    ])
            }
            if !cachedModelGeneratedQuotes.isEmpty {
                cachedModelGeneratedQuotes = []
                rebuildQuoteCache()
                scheduleFilteredQuotesRefresh()
            }
            return
        }

        guard availability.isReady else {
            if provider == .appleOnDevice {
                analyticsTracker.track(
                    "apple_model_fallback",
                    properties: [
                        "requested_provider": provider.rawValue,
                        "reason": "availability_\(availability.analyticsKey)",
                        "surface": "quotes",
                    ])
            }
            if !cachedModelGeneratedQuotes.isEmpty {
                cachedModelGeneratedQuotes = []
                rebuildQuoteCache()
                scheduleFilteredQuotesRefresh()
            }
            return
        }

        modelQuoteTask = Task { [weak self] in
            await self?.refreshModelQuoteOverlay(provider: provider)
        }
    }

    private func modelQuoteOverlayKey(provider: AdviceGenerationProvider, now: Date = Date())
        -> String
    {
        let day = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        return "\(provider.rawValue)|\(Int(day))"
    }

    private func refreshModelQuoteOverlay(provider: AdviceGenerationProvider) async {
        let categories = rotatingQuoteOverlayCategories()
        let tones = ToneMode.concrete
        let seedBase = stableSeed(
            for: "quote-overlay|\(Date().formatted(date: .numeric, time: .omitted))")
        var built: [BadQuote] = []
        var seen = Set<String>()

        for index in 0..<min(4, max(2, categories.count)) {
            if Task.isCancelled { return }
            let category = categories[index % categories.count]
            let tone = tones[(seedBase + index * 13).positiveModulo(tones.count)]
            do {
                let candidate = try await appleOnDeviceBridge.generateQuoteCandidate(
                    category: category,
                    tone: tone,
                    seed: seedBase + (index * 7_919)
                )
                guard isValidModelQuote(candidate) else { continue }
                let fingerprint = candidate.text.normalizedForFiltering
                if seen.insert(fingerprint).inserted {
                    built.append(candidate)
                }
            } catch {
                logger.error(
                    "Apple on-device quote generation failed: \(String(describing: error), privacy: .public)"
                )
                if provider == .appleOnDevice {
                    analyticsTracker.track(
                        "apple_model_fallback",
                        properties: [
                            "requested_provider": provider.rawValue,
                            "reason": "generation_failed",
                            "surface": "quotes",
                        ])
                }
                break
            }
        }

        if provider == .appleOnDevice, built.isEmpty {
            analyticsTracker.track(
                "apple_model_fallback",
                properties: [
                    "requested_provider": provider.rawValue,
                    "reason": "no_valid_output",
                    "surface": "quotes",
                ])
        }

        guard !Task.isCancelled else { return }
        cachedModelGeneratedQuotes = built
        rebuildQuoteCache()
        scheduleFilteredQuotesRefresh()
    }

    private func rotatingQuoteOverlayCategories(now: Date = Date()) -> [AdviceCategory] {
        let categories = AdviceCategory.concrete
        guard !categories.isEmpty else { return [.productivity] }
        let seed = Int(Calendar.current.startOfDay(for: now).timeIntervalSince1970)
        let start = (seed / 86_400).positiveModulo(categories.count)
        return (0..<categories.count).map { categories[(start + $0) % categories.count] }
    }

    private func isValidModelQuote(_ quote: BadQuote) -> Bool {
        let text = quote.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 8, text.count <= 160 else { return false }
        guard moderation.isSafe(text: "\(quote.source) \(text)") else { return false }
        let forbidden = store.rules(for: quote.category, contentPack: .classic).forbiddenPatterns
        let normalized = text.normalizedForFiltering
        return !forbidden.contains { normalized.contains($0.normalizedForFiltering) }
    }
}

@MainActor
@Observable
final class FavoritesViewModel {
    private let repository: AdviceRepository
    private let analyticsTracker: AnalyticsTracking
    var favorites: [AdviceRecord] = []
    var searchText: String = "" {
        didSet { scheduleSearchDebounce(searchText) }
    }
    var selectedCategory: AdviceCategory? {
        didSet { refreshFilteredFavorites() }
    }
    private var debouncedSearchText = ""
    private var searchDebounceTask: Task<Void, Never>?
    private var favoritesSearchIndexByID: [UUID: String] = [:]
    private var cachedFilteredFavorites: [AdviceRecord] = []

    init(repository: AdviceRepository, analyticsTracker: AnalyticsTracking = AppAnalyticsTracker())
    {
        self.repository = repository
        self.analyticsTracker = analyticsTracker
        self.debouncedSearchText = searchText
        reload()
    }

    func reload() {
        favorites = repository.fetchFavorites()
        rebuildFavoritesSearchIndex()
        refreshFilteredFavorites()
    }

    func remove(_ record: AdviceRecord) {
        repository.setFavorite(record, isFavorite: false)
        analyticsTracker.track("favorite_remove", properties: [:])
        reload()
    }

    func delete(_ record: AdviceRecord) {
        repository.delete(record)
        analyticsTracker.track("favorite_delete", properties: [:])
        reload()
    }

    func toggleFavorite(_ record: AdviceRecord) {
        repository.toggleFavorite(record)
        analyticsTracker.track("favorite_toggle", properties: [:])
        reload()
    }

    func setAftermathNote(_ record: AdviceRecord, note: String) {
        repository.setAftermathNote(record, note: note)
    }

    var filteredFavorites: [AdviceRecord] {
        cachedFilteredFavorites
    }

    private func rebuildFavoritesSearchIndex() {
        var index: [UUID: String] = [:]
        index.reserveCapacity(favorites.count)
        for record in favorites {
            index[record.id] =
                "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)"
                .normalizedForFiltering
        }
        favoritesSearchIndexByID = index
    }

    private func refreshFilteredFavorites() {
        let search = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = search.isEmpty ? "" : search.normalizedForFiltering

        if normalizedSearch.isEmpty, selectedCategory == nil {
            cachedFilteredFavorites = favorites
            return
        }

        if normalizedSearch.isEmpty, let selectedCategory {
            cachedFilteredFavorites = favorites.filter { $0.category == selectedCategory }
            return
        }

        cachedFilteredFavorites = favorites.filter { record in
            let matchesCategory = selectedCategory == nil || record.category == selectedCategory
            let matchesSearch: Bool
            if normalizedSearch.isEmpty {
                matchesSearch = true
            } else {
                let haystack =
                    favoritesSearchIndexByID[record.id]
                    ?? "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)"
                    .normalizedForFiltering
                matchesSearch = haystack.contains(normalizedSearch)
            }
            return matchesCategory && matchesSearch
        }
    }

    private func scheduleSearchDebounce(_ value: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self, value] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.debouncedSearchText = value
                self?.refreshFilteredFavorites()
            }
        }
    }
}

@MainActor
@Observable
final class HistoryViewModel {
    enum RankingMode: String, CaseIterable, Identifiable {
        case recent
        case topLiked
        case topDisliked

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recent: return "Recent"
            case .topLiked: return "Top Liked"
            case .topDisliked: return "Top Disliked"
            }
        }
    }

    private let repository: AdviceRepository
    private let analyticsTracker: AnalyticsTracking
    var history: [AdviceRecord] = []
    var searchText: String = "" {
        didSet { scheduleSearchDebounce(searchText) }
    }
    var selectedCategory: AdviceCategory? {
        didSet { refreshFilteredHistory() }
    }
    var rankingMode: RankingMode = .recent {
        didSet { refreshFilteredHistory() }
    }
    private var debouncedSearchText = ""
    private var searchDebounceTask: Task<Void, Never>?
    private var historySearchIndexByID: [UUID: String] = [:]
    private var cachedFilteredHistory: [AdviceRecord] = []
    private var cachedLikedCount = 0
    private var cachedDislikedCount = 0

    init(repository: AdviceRepository, analyticsTracker: AnalyticsTracking = AppAnalyticsTracker())
    {
        self.repository = repository
        self.analyticsTracker = analyticsTracker
        self.debouncedSearchText = searchText
        reload()
    }

    func reload() {
        history = repository.fetchHistory(limit: 50)
        rebuildHistoryCaches()
        refreshFilteredHistory()
    }

    func saveFromHistory(_ record: AdviceRecord) {
        repository.setFavorite(record, isFavorite: true)
        analyticsTracker.track("history_save", properties: [:])
        reload()
    }

    func clearHistory() {
        repository.purgeAllHistory()
        analyticsTracker.track("history_clear", properties: [:])
        reload()
    }

    var filteredHistory: [AdviceRecord] {
        cachedFilteredHistory
    }

    var likedCount: Int {
        cachedLikedCount
    }

    var dislikedCount: Int {
        cachedDislikedCount
    }

    private func rebuildHistoryCaches() {
        var index: [UUID: String] = [:]
        index.reserveCapacity(history.count)
        var likes = 0
        var dislikes = 0
        for record in history {
            index[record.id] =
                "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)"
                .normalizedForFiltering
            if record.vote == .like {
                likes += 1
            } else if record.vote == .dislike {
                dislikes += 1
            }
        }
        historySearchIndexByID = index
        cachedLikedCount = likes
        cachedDislikedCount = dislikes
    }

    private func refreshFilteredHistory() {
        let search = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = search.isEmpty ? "" : search.normalizedForFiltering

        if normalizedSearch.isEmpty, selectedCategory == nil, rankingMode == .recent {
            cachedFilteredHistory = history
            return
        }

        if normalizedSearch.isEmpty, let selectedCategory, rankingMode == .recent {
            cachedFilteredHistory = history.filter { $0.category == selectedCategory }
            return
        }

        let filtered = history.filter { record in
            let matchesCategory = selectedCategory == nil || record.category == selectedCategory
            let matchesSearch: Bool
            if normalizedSearch.isEmpty {
                matchesSearch = true
            } else {
                let haystack =
                    historySearchIndexByID[record.id]
                    ?? "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)"
                    .normalizedForFiltering
                matchesSearch = haystack.contains(normalizedSearch)
            }
            return matchesCategory && matchesSearch
        }

        switch rankingMode {
        case .recent:
            cachedFilteredHistory = filtered
        case .topLiked:
            cachedFilteredHistory = filtered.filter { $0.vote == .like }
        case .topDisliked:
            cachedFilteredHistory = filtered.filter { $0.vote == .dislike }
        }
    }

    private func scheduleSearchDebounce(_ value: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self, value] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.debouncedSearchText = value
                self?.refreshFilteredHistory()
            }
        }
    }
}

enum SocialPostType: String, CaseIterable, Codable, Sendable {
    case advice
    case quote
}

enum SocialPostVisibility: String, Codable, Sendable {
    case friends
}

enum SocialFriendRequestStatus: String, Codable, Sendable {
    case pending
    case accepted
    case rejected
    case canceled
    case blocked
}

enum SocialError: LocalizedError {
    case iCloudUnavailable(String)
    case missingProfile
    case invalidHandle
    case handleTaken
    case userNotFound
    case cannotFriendYourself
    case duplicateRequest
    case rateLimited(String)
    case permissionDenied
    case versionConflict(current: Int64)
    case invalidRecord

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable(let message):
            return message
        case .missingProfile:
            return "Create your profile first to unlock social features."
        case .invalidHandle:
            return "Handle must be 3–16 characters using lowercase letters, numbers, dots, or underscore."
        case .handleTaken:
            return "That handle is already taken."
        case .userNotFound:
            return "User not found."
        case .cannotFriendYourself:
            return "You cannot send a friend request to yourself."
        case .duplicateRequest:
            return "A request already exists for this user."
        case .rateLimited(let message):
            return message
        case .permissionDenied:
            return "You do not have permission for that action."
        case .versionConflict:
            return "This document was updated by someone else. Reloading latest version."
        case .invalidRecord:
            return "A CloudKit record was missing required fields."
        }
    }
}

struct SocialCloudKitErrorDiagnostic: Sendable {
    let operation: String
    let domain: String
    let code: String
    let localizedDescription: String
    let recordType: String?
    let recordNames: [String]
    let normalizedHandle: String?
    let predicateSummary: String?
    let fieldNames: [String]
    let sortKeys: [String]
    let containerIdentifier: String
    let databaseScope: String
    let environmentName: String
    let isRetryable: Bool
    let partialFailureDetails: [String]
    let debugUserInfo: String?

    var inlineSummary: String {
        "\(operation): \(code): \(localizedDescription)"
    }

    var debugSummary: String {
        var lines = [
            "Operation: \(operation)",
            "Domain: \(domain)",
            "Code: \(code)",
            "Description: \(localizedDescription)",
            "Container: \(containerIdentifier)",
            "Database Scope: \(databaseScope)",
            "Environment: \(environmentName)",
            "Retryable: \(isRetryable ? "yes" : "no")",
        ]
        if let recordType, !recordType.isEmpty {
            lines.append("Record Type: \(recordType)")
        }
        if !recordNames.isEmpty {
            lines.append("Record Names: \(recordNames.joined(separator: ", "))")
        }
        if let normalizedHandle, !normalizedHandle.isEmpty {
            lines.append("Normalized Handle: \(normalizedHandle)")
        }
        if let predicateSummary, !predicateSummary.isEmpty {
            lines.append("Predicate: \(predicateSummary)")
        }
        if !fieldNames.isEmpty {
            lines.append("Fields: \(fieldNames.joined(separator: ", "))")
        }
        if !sortKeys.isEmpty {
            lines.append("Sort Keys: \(sortKeys.joined(separator: ", "))")
        }
        if !partialFailureDetails.isEmpty {
            lines.append("Partial Failures:")
            lines.append(contentsOf: partialFailureDetails.map { "- \($0)" })
        }
        if let debugUserInfo, !debugUserInfo.isEmpty {
            lines.append("User Info: \(debugUserInfo)")
        }
        return lines.joined(separator: "\n")
    }

    static func make(
        from error: Error,
        context: SocialCloudKitOperationContext,
        isRetryable: Bool
    ) -> SocialCloudKitErrorDiagnostic? {
        guard let ckError = error as? CKError else { return nil }
        #if DEBUG
            let localizedDescription = ckError.localizedDescription
            var debugLines: [String] = []
            var partialFailureDetails: [String] = []
            if !ckError.userInfo.isEmpty {
                debugLines.append("UserInfo: \(String(describing: ckError.userInfo))")
            }
            if ckError.code == .partialFailure,
                let partialErrors = ckError.partialErrorsByItemID,
                !partialErrors.isEmpty
            {
                for (itemID, partialError) in partialErrors {
                    partialFailureDetails.append("\(itemID): \(partialError.localizedDescription)")
                }
            }
            if ckError.code == .serverRecordChanged {
                if let serverRecord = ckError.serverRecord {
                    debugLines.append("Server Record: \(serverRecord.recordID.recordName)")
                }
                if let ancestorRecord = ckError.ancestorRecord {
                    debugLines.append("Ancestor Record: \(ancestorRecord.recordID.recordName)")
                }
                if let clientRecord = ckError.clientRecord {
                    debugLines.append("Client Record: \(clientRecord.recordID.recordName)")
                }
            }
            let debugUserInfo = debugLines.isEmpty ? nil : debugLines.joined(separator: "\n")
        #else
            let localizedDescription = sanitizedDescription(for: ckError)
            let debugUserInfo: String? = nil
            let partialFailureDetails: [String] = []
        #endif
        return SocialCloudKitErrorDiagnostic(
            operation: context.operation,
            domain: CKError.errorDomain,
            code: "\(ckError.code) (\(ckError.code.rawValue))",
            localizedDescription: localizedDescription,
            recordType: context.recordType,
            recordNames: context.recordNames,
            normalizedHandle: context.normalizedHandle,
            predicateSummary: context.predicateSummary,
            fieldNames: context.fieldNames,
            sortKeys: context.sortKeys,
            containerIdentifier: context.containerIdentifier,
            databaseScope: context.databaseScope,
            environmentName: context.environmentName,
            isRetryable: isRetryable,
            partialFailureDetails: partialFailureDetails,
            debugUserInfo: debugUserInfo
        )
    }

    private static func sanitizedDescription(for error: CKError) -> String {
        switch error.code {
        case .notAuthenticated:
            return "You are not signed in to iCloud."
        case .permissionFailure:
            return "This build does not have CloudKit permission to complete the request."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy, .requestRateLimited:
            return "CloudKit is temporarily unavailable."
        case .accountTemporarilyUnavailable:
            return "Your iCloud account is temporarily unavailable."
        case .quotaExceeded, .limitExceeded:
            return "CloudKit storage limits were reached."
        default:
            return "CloudKit request failed."
        }
    }
}

struct SocialCloudKitOperationContext: Sendable {
    let operation: String
    let recordType: String?
    let recordNames: [String]
    let normalizedHandle: String?
    let predicateSummary: String?
    let fieldNames: [String]
    let sortKeys: [String]
    let containerIdentifier: String
    let databaseScope: String
    let environmentName: String

    static func generic(operation: String) -> SocialCloudKitOperationContext {
        SocialCloudKitOperationContext(
            operation: operation,
            recordType: nil,
            recordNames: [],
            normalizedHandle: nil,
            predicateSummary: nil,
            fieldNames: [],
            sortKeys: [],
            containerIdentifier: CloudKitSocialConfig.containerIdentifier,
            databaseScope: CloudKitManager.socialDatabaseScope,
            environmentName: CloudKitSocialConfig.environmentName
        )
    }
}

struct SocialCloudOperationError: Error {
    let underlyingError: Error
    let diagnostic: SocialCloudKitErrorDiagnostic?
}

extension SocialCloudOperationError: LocalizedError {
    var errorDescription: String? {
        underlyingError.localizedDescription
    }
}

struct SocialCloudKitDiagnostics: Sendable {
    let accountStatus: CKAccountStatus?
    let containerIdentifier: String
    let databaseScope: String
    let environmentName: String
    let lastError: SocialCloudKitErrorDiagnostic?

    var isAccountAvailable: Bool {
        accountStatus == .available
    }

    var accountStatusLabel: String {
        guard let accountStatus else { return "Checking" }
        switch accountStatus {
        case .available:
            return "available"
        case .noAccount:
            return "noAccount"
        case .restricted:
            return "restricted"
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .temporarilyUnavailable:
            return "temporarilyUnavailable"
        @unknown default:
            return "unknown(\(accountStatus.rawValue))"
        }
    }

    var userVisibleMessage: String {
        guard let accountStatus else {
            return "Checking CloudKit account status..."
        }
        switch accountStatus {
        case .available:
            if lastError != nil {
                return "CloudKit account is available, but the last Friends request failed."
            }
            return "CloudKit account is available."
        case .noAccount:
            return "Sign in to iCloud in Settings to use Friends."
        case .restricted:
            return "iCloud access is restricted on this device."
        case .couldNotDetermine:
            return "CloudKit account status could not be determined."
        case .temporarilyUnavailable:
            return "CloudKit is temporarily unavailable."
        @unknown default:
            return "CloudKit account status is unknown."
        }
    }

    func withLastError(_ lastError: SocialCloudKitErrorDiagnostic?) -> SocialCloudKitDiagnostics {
        SocialCloudKitDiagnostics(
            accountStatus: accountStatus,
            containerIdentifier: containerIdentifier,
            databaseScope: databaseScope,
            environmentName: environmentName,
            lastError: lastError
        )
    }

    func text(includeDebugDetails: Bool) -> String {
        var lines = [
            "Account Status: \(accountStatusLabel)",
            "Container: \(containerIdentifier)",
            "Database Scope: \(databaseScope)",
            "Environment: \(environmentName)",
        ]
        if let lastError {
            lines.append("Last CKError: \(lastError.code)")
            lines.append("Operation: \(lastError.operation)")
            if let recordType = lastError.recordType {
                lines.append("Record Type: \(recordType)")
            }
            if !lastError.recordNames.isEmpty {
                lines.append("Record Names: \(lastError.recordNames.joined(separator: ", "))")
            }
            if let normalizedHandle = lastError.normalizedHandle {
                lines.append("Normalized Handle: \(normalizedHandle)")
            }
            if let predicateSummary = lastError.predicateSummary {
                lines.append("Predicate: \(predicateSummary)")
            }
            if !lastError.fieldNames.isEmpty {
                lines.append("Fields: \(lastError.fieldNames.joined(separator: ", "))")
            }
            if !lastError.sortKeys.isEmpty {
                lines.append("Sort Keys: \(lastError.sortKeys.joined(separator: ", "))")
            }
            lines.append("Retryable: \(lastError.isRetryable ? "yes" : "no")")
            lines.append("Last Description: \(lastError.localizedDescription)")
            if includeDebugDetails {
                lines.append(lastError.debugSummary)
            }
        } else {
            lines.append("Last CKError: none")
        }
        return lines.joined(separator: "\n")
    }

    static let pending = SocialCloudKitDiagnostics(
        accountStatus: nil,
        containerIdentifier: CloudKitSocialConfig.containerIdentifier,
        databaseScope: CloudKitManager.socialDatabaseScope,
        environmentName: CloudKitSocialConfig.environmentName,
        lastError: nil
    )
}

struct SocialAvailabilityState: Sendable {
    let isAvailable: Bool
    let diagnostics: SocialCloudKitDiagnostics

    var message: String {
        diagnostics.userVisibleMessage
    }

    var isAccountAvailable: Bool {
        diagnostics.isAccountAvailable
    }

    func withLastError(_ lastError: SocialCloudKitErrorDiagnostic?) -> SocialAvailabilityState {
        SocialAvailabilityState(
            isAvailable: isAvailable,
            diagnostics: diagnostics.withLastError(lastError)
        )
    }

    static let available = SocialAvailabilityState(
        isAvailable: true,
        diagnostics: SocialCloudKitDiagnostics(
            accountStatus: .available,
            containerIdentifier: CloudKitSocialConfig.containerIdentifier,
            databaseScope: CloudKitManager.socialDatabaseScope,
            environmentName: CloudKitSocialConfig.environmentName,
            lastError: nil
        )
    )
}

enum SocialLoadState: Equatable {
    case idle
    case checkingCloudKit
    case needsProfileSetup
    case bootstrappingProfile
    case loadingFriends
    case empty
    case failed(message: String)
    case ready

    var allowsSocialActions: Bool {
        switch self {
        case .empty, .ready:
            return true
        default:
            return false
        }
    }
}

struct SocialUser: Identifiable, Hashable, Sendable {
    let recordID: CKRecord.ID
    let handle: String
    let displayName: String
    let createdAt: Date

    var id: String { recordID.recordName }
}

struct SocialFriendRequest: Identifiable, Sendable {
    let recordID: CKRecord.ID
    let fromUserID: CKRecord.ID
    let toUserID: CKRecord.ID
    let status: SocialFriendRequestStatus
    let createdAt: Date
    let fromUser: SocialUser?
    let toUser: SocialUser?

    var id: String { recordID.recordName }
}

struct SocialPost: Identifiable, Sendable {
    let recordID: CKRecord.ID
    let authorUserID: CKRecord.ID
    let author: SocialUser?
    let type: SocialPostType
    let text: String
    let visibility: SocialPostVisibility
    let createdAt: Date

    var id: String { recordID.recordName }
}

struct SocialChaosScore: Identifiable, Sendable {
    let recordID: CKRecord.ID
    let seasonId: String
    let userID: CKRecord.ID
    let user: SocialUser?
    let score: Int64
    let updatedAt: Date

    var id: String { recordID.recordName }
}

struct SocialCollabDoc: Identifiable, Sendable {
    let recordID: CKRecord.ID
    let ownerID: CKRecord.ID
    let owner: SocialUser?
    let contributorIDs: [CKRecord.ID]
    let contributors: [SocialUser]
    let type: SocialPostType
    let content: String
    let version: Int64
    let updatedAt: Date

    var id: String { recordID.recordName }
}

struct SocialCollabDraft: Identifiable, Sendable {
    let id = UUID()
    let type: SocialPostType
    let content: String
}

enum SocialModerationTargetType: String, Codable, Sendable {
    case post
    case user
}

struct SocialModerationReport: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let targetType: SocialModerationTargetType
    let targetRecordName: String
    let reporterHandle: String
    let reason: String?
    let createdAt: Date
}

enum SocialQueuedActionPayload: Codable, Sendable {
    case friendRequest(handle: String)
    case sharePost(type: SocialPostType, text: String)
    case chaosScore(seasonId: String, score: Int64)
    case moderationReport(SocialModerationReport)
}

struct SocialQueuedAction: Identifiable, Codable, Sendable {
    let id: UUID
    let dedupeKey: String?
    let createdAt: Date
    var nextRetryAt: Date
    var attemptCount: Int
    let payload: SocialQueuedActionPayload
}

enum SocialReportLogger {
    private static let userDefaultsKey = "social.reportLog.v1"
    private static let maxEntries = 80

    static func log(_ entry: String, userDefaults: UserDefaults = .standard) {
        let now = ISO8601DateFormatter().string(from: Date())
        var logs = userDefaults.stringArray(forKey: userDefaultsKey) ?? []
        logs.insert("[\(now)] \(entry)", at: 0)
        if logs.count > maxEntries {
            logs = Array(logs.prefix(maxEntries))
        }
        userDefaults.set(logs, forKey: userDefaultsKey)
    }
}

protocol SocialBackend: Sendable {
    func backendDisplayName() async -> String
    func availabilityState() async -> SocialAvailabilityState
    func setStoredCurrentUserRecordName(_ recordName: String?) async
    func fetchCurrentUserIfStored() async throws -> SocialUser?
    func getOrCreateCurrentUser(handle: String, displayName: String?) async throws -> SocialUser
    func findUserByHandle(_ handle: String) async throws -> SocialUser?
    func sendFriendRequest(toUser target: SocialUser) async throws -> SocialFriendRequest
    func fetchIncomingFriendRequests() async throws -> [SocialFriendRequest]
    func fetchOutgoingFriendRequests() async throws -> [SocialFriendRequest]
    func acceptFriendRequest(_ request: SocialFriendRequest) async throws
    func declineFriendRequest(_ request: SocialFriendRequest) async throws
    func blockUser(_ user: SocialUser) async throws
    func fetchBlockedUsers() async throws -> [SocialUser]
    func fetchFriends() async throws -> [SocialUser]
    func createPost(type: SocialPostType, text: String) async throws -> SocialPost
    func fetchFriendsFeed() async throws -> [SocialPost]
    func submitChaosScore(seasonId: String, score: Int64) async throws
    func fetchLeaderboard(seasonId: String, limit: Int) async throws -> [SocialChaosScore]
    func createOrUpdateCollabDoc(
        docID: String?,
        type: SocialPostType,
        content: String,
        contributorIDs: [CKRecord.ID],
        expectedVersion: Int64?
    ) async throws -> SocialCollabDoc
    func fetchMyCollabDocs() async throws -> [SocialCollabDoc]
    func fetchCollabDoc(id: String) async throws -> SocialCollabDoc?
    func submitModerationReport(_ report: SocialModerationReport) async throws
}

actor SocialActionQueueStore {
    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "social.actionQueue.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func enqueue(_ action: SocialQueuedAction) {
        var actions = load()
        if let dedupeKey = action.dedupeKey,
            actions.contains(where: { $0.dedupeKey == dedupeKey })
        {
            return
        }
        actions.append(action)
        save(actions)
    }

    func readyActions(now: Date = Date(), limit: Int = 10) -> [SocialQueuedAction] {
        Array(load().filter { $0.nextRetryAt <= now }.prefix(max(1, limit)))
    }

    func markSucceeded(id: UUID) {
        var actions = load()
        actions.removeAll { $0.id == id }
        save(actions)
    }

    func reschedule(id: UUID, retryAt: Date) {
        var actions = load()
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[index].attemptCount += 1
        actions[index].nextRetryAt = retryAt
        save(actions)
    }

    func totalCount() -> Int {
        load().count
    }

    func pendingModerationReportCount() -> Int {
        load().reduce(into: 0) { count, action in
            if case .moderationReport = action.payload {
                count += 1
            }
        }
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }

    private func load() -> [SocialQueuedAction] {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SocialQueuedAction].self, from: data)
        else {
            return []
        }
        return decoded
    }

    private func save(_ actions: [SocialQueuedAction]) {
        if actions.isEmpty {
            userDefaults.removeObject(forKey: storageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(actions) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

actor CloudKitStore: SocialBackend {
    private enum FriendRequestDirection {
        case incoming
        case outgoing
    }

    private let container: CKContainer
    private let publicDB: CKDatabase
    private let userDefaults: UserDefaults

    private let currentUserRecordNameKey = "social.currentUserRecordName.v1"
    private let friendRequestRateLimitKey = "social.rate.friendRequest"
    private let postRateLimitKey = "social.rate.post"

    private var cachedCurrentUser: SocialUser?
    private var cachedFriendIDs: (ids: [CKRecord.ID], fetchedAt: Date)?
    private var cachedFeed: (posts: [SocialPost], fetchedAt: Date)?

    private let friendCacheTTL: TimeInterval = 120
    private let feedCacheTTL: TimeInterval = 45

    init(
        container: CKContainer? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        let resolvedContainer = container ?? CloudKitManager.socialContainer()
        self.container = resolvedContainer
        self.publicDB = CloudKitManager.socialDatabase(container: resolvedContainer)
        self.userDefaults = userDefaults
        let resolvedContainerIdentifier =
            resolvedContainer.containerIdentifier ?? CloudKitSocialConfig.containerIdentifier
        cloudKitLogger.info(
            "CloudKit container identifier used: \(resolvedContainerIdentifier, privacy: .public). Expected capability: \(CloudKitSocialConfig.containerIdentifier, privacy: .public)."
        )
        cloudKitLogger.info(
            "CloudKit social backend configured with \(Self.databaseDescription(for: self.publicDB), privacy: .public)."
        )
    }

    func backendDisplayName() async -> String {
        "CloudKit"
    }

    func setStoredCurrentUserRecordName(_ recordName: String?) async {
        cachedCurrentUser = nil
        invalidateFriendCaches()
        if let recordName, !recordName.isEmpty {
            userDefaults.set(recordName, forKey: currentUserRecordNameKey)
        } else {
            userDefaults.removeObject(forKey: currentUserRecordNameKey)
        }
    }

    func availabilityState() async -> SocialAvailabilityState {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-force-social-unavailable") {
            return makeAvailabilityState(
                accountStatus: nil,
                lastError: SocialCloudKitErrorDiagnostic(
                    operation: "ui-test",
                    domain: CKError.errorDomain,
                    code: "unavailable",
                    localizedDescription: "Social features are unavailable in this test run.",
                    recordType: nil,
                    recordNames: [],
                    normalizedHandle: nil,
                    predicateSummary: nil,
                    fieldNames: [],
                    sortKeys: [],
                    containerIdentifier: currentContainerIdentifier(),
                    databaseScope: CloudKitManager.socialDatabaseScope,
                    environmentName: CloudKitSocialConfig.environmentName,
                    isRetryable: false,
                    partialFailureDetails: [],
                    debugUserInfo: nil
                )
            )
        }
        do {
            let status = try await accountStatus()
            cloudKitLogger.info(
                "CloudKit account status result: \(Self.accountStatusDescription(status), privacy: .public)"
            )
            return makeAvailabilityState(accountStatus: status)
        } catch {
            Self.logCloudKitError(error, context: "account status lookup")
            return makeAvailabilityState(
                accountStatus: .couldNotDetermine,
                lastError: SocialCloudKitErrorDiagnostic.make(
                    from: error,
                    context: makeOperationContext(operation: "accountStatus"),
                    isRetryable: false
                )
            )
        }
    }

    func fetchCurrentUserIfStored() async throws -> SocialUser? {
        if let cachedCurrentUser {
            return cachedCurrentUser
        }
        if let recordName = userDefaults.string(forKey: currentUserRecordNameKey),
            !recordName.isEmpty
        {
            let recordID = CKRecord.ID(recordName: recordName)
            do {
                guard let record = try await fetchRecord(
                    recordID: recordID,
                    desiredKeys: CloudKitSocialSchema.Projection.userProfile,
                    allowsMissingRecord: true,
                    operation: "loadStoredCurrentUserProfile",
                    recordType: CloudKitSocialSchema.RecordType.userProfile,
                    fieldNames: CloudKitSocialSchema.Projection.userProfile
                ) else {
                    userDefaults.removeObject(forKey: currentUserRecordNameKey)
                    cachedCurrentUser = nil
                    return try await findCurrentUserByOwnerRecordName()
                }
                let user = try socialUser(from: record)
                cachedCurrentUser = user
                return user
            } catch {
                userDefaults.removeObject(forKey: currentUserRecordNameKey)
                cachedCurrentUser = nil
                return try await findCurrentUserByOwnerRecordName()
            }
        }
        return try await findCurrentUserByOwnerRecordName()
    }

    func getOrCreateCurrentUser(handle: String, displayName: String?) async throws -> SocialUser {
        let normalizedHandle = normalizeHandle(handle)
        guard Self.isValidHandle(normalizedHandle) else {
            throw SocialError.invalidHandle
        }

        debugLogProfileSetup(
            "start normalizedHandle=\(normalizedHandle) recordType=\(CloudKitSocialSchema.RecordType.userProfile)"
        )
        let ownerUserRecordName = try await fetchCurrentICloudUserRecordName()
        debugLogProfileSetup(
            "resolved ownerUserRecordName=\(ownerUserRecordName) normalizedHandle=\(normalizedHandle)"
        )
        if let existingCurrentUser = try await findCurrentUserByOwnerRecordName() {
            await setStoredCurrentUserRecordName(existingCurrentUser.recordID.recordName)
            cachedCurrentUser = existingCurrentUser
            debugLogProfileSetup(
                "found existing current profile recordID=\(existingCurrentUser.recordID.recordName) normalizedHandle=\(normalizedHandle)"
            )
            return existingCurrentUser
        }

        let handleAvailabilityPredicate = NSPredicate(
            format: "%K == %@",
            CloudKitSocialSchema.Field.handle,
            normalizedHandle
        )
        debugLogProfileSetup(
            "checking handle availability normalizedHandle=\(normalizedHandle) predicate=\(handleAvailabilityPredicate.predicateFormat)"
        )
        let existingHandleMatches = try await queryUserProfilesByHandle(
            normalizedHandle,
            resultsLimit: 2,
            operation: "checkHandleAvailability",
            desiredKeys: CloudKitSocialSchema.Projection.userProfile
        )
        if let existingHandleRecord = existingHandleMatches.first {
            let existingHandleOwner =
                existingHandleRecord[CloudKitSocialSchema.Field.ownerUserRecordName] as? String
            if existingHandleOwner == ownerUserRecordName {
                let user = try socialUser(from: existingHandleRecord)
                await setStoredCurrentUserRecordName(user.recordID.recordName)
                cachedCurrentUser = user
                debugLogProfileSetup(
                    "reused profile matched by handle recordID=\(user.recordID.recordName) normalizedHandle=\(normalizedHandle)"
                )
                return user
            }
            debugLogProfileSetup(
                "handle unavailable normalizedHandle=\(normalizedHandle) conflictingRecordID=\(existingHandleRecord.recordID.recordName)"
            )
            throw SocialError.handleTaken
        }

        let record = CKRecord(recordType: CloudKitSocialSchema.RecordType.userProfile)
        record[CloudKitSocialSchema.Field.handle] = normalizedHandle
        record[CloudKitSocialSchema.Field.displayName] =
            normalizedDisplayName(displayName, handle: normalizedHandle)
        record[CloudKitSocialSchema.Field.createdAt] = Date()
        record[CloudKitSocialSchema.Field.ownerUserRecordName] = ownerUserRecordName
        let savedFieldNames = record.allKeys().sorted()
        debugLogProfileSetup(
            "saving profile normalizedHandle=\(normalizedHandle) recordType=\(record.recordType) fields=\(savedFieldNames.joined(separator: ",")) recordID=\(record.recordID.recordName)"
        )
        let saved: CKRecord
        do {
            saved = try await save(record: record, savePolicy: .allKeys)
            debugLogProfileSetup(
                "save succeeded normalizedHandle=\(normalizedHandle) recordID=\(saved.recordID.recordName) fields=\(saved.allKeys().sorted().joined(separator: ","))"
            )
        } catch {
            debugLogProfileSetupError(
                stage: "saveProfile",
                error: error,
                normalizedHandle: normalizedHandle,
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                recordID: record.recordID,
                fieldNames: savedFieldNames
            )
            throw error
        }

        await setStoredCurrentUserRecordName(saved.recordID.recordName)

        let user = await resolveCreatedCurrentUser(
            fromSavedRecord: saved,
            normalizedHandle: normalizedHandle,
            ownerUserRecordName: ownerUserRecordName
        )
        cachedCurrentUser = user
        userDefaults.set(user.recordID.recordName, forKey: currentUserRecordNameKey)
        debugLogProfileSetup(
            "profile setup completed normalizedHandle=\(normalizedHandle) recordID=\(user.recordID.recordName)"
        )
        return user
    }

    func isHandleTaken(_ handle: String) async throws -> Bool {
        let normalizedHandle = normalizeHandle(handle)
        guard Self.isValidHandle(normalizedHandle) else { return true }

        let matchingRecords = try await queryUserProfilesByHandle(
            normalizedHandle,
            resultsLimit: 4,
            operation: "checkHandleAvailability",
            desiredKeys: CloudKitSocialSchema.Projection.userProfile
        )
        guard let current = try await fetchCurrentUserIfStored() else {
            return !matchingRecords.isEmpty
        }
        return matchingRecords.contains(where: { $0.recordID != current.recordID })
    }

    func findUserByHandle(_ handle: String) async throws -> SocialUser? {
        let normalizedHandle = normalizeHandle(handle)
        guard Self.isValidHandle(normalizedHandle) else { return nil }
        let first = try await queryUserProfilesByHandle(
            normalizedHandle,
            resultsLimit: 1,
            operation: "findUserByHandle",
            desiredKeys: CloudKitSocialSchema.Projection.userProfile
        ).first
        guard let first else { return nil }
        return try socialUser(from: first)
    }

    func sendFriendRequest(toUser target: SocialUser) async throws -> SocialFriendRequest {
        let current = try await requireCurrentUser()
        guard current.recordID != target.recordID else {
            throw SocialError.cannotFriendYourself
        }

        if try await fetchRecord(recordID: friendEdgeRecordID(a: current.recordID, b: target.recordID)) != nil
        {
            throw SocialError.duplicateRequest
        }

        guard consumeRateBudget(
            key: "\(friendRequestRateLimitKey).\(current.recordID.recordName)",
            maxCount: 5,
            interval: 60
        ) else {
            throw SocialError.rateLimited("Too many friend requests. Try again in a minute.")
        }

        let currentRef = CKRecord.Reference(recordID: current.recordID, action: .none)
        let targetRef = CKRecord.Reference(recordID: target.recordID, action: .none)
        let blockingStatuses = Set([
            SocialFriendRequestStatus.pending,
            .accepted,
            .blocked,
        ])
        let allRequests = try await allFriendRequestRecords()
        let existingOutgoing = allRequests.filter { record in
            guard
                let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
                let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference,
                let statusRaw = record[CloudKitSocialSchema.Field.status] as? String,
                let status = SocialFriendRequestStatus(rawValue: statusRaw)
            else {
                return false
            }
            return fromRef.recordID == currentRef.recordID
                && toRef.recordID == targetRef.recordID
                && blockingStatuses.contains(status)
        }
        guard existingOutgoing.isEmpty else {
            throw SocialError.duplicateRequest
        }
        let existingIncoming = allRequests.filter { record in
            guard
                let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
                let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference,
                let statusRaw = record[CloudKitSocialSchema.Field.status] as? String,
                let status = SocialFriendRequestStatus(rawValue: statusRaw)
            else {
                return false
            }
            return fromRef.recordID == targetRef.recordID
                && toRef.recordID == currentRef.recordID
                && blockingStatuses.contains(status)
        }
        if existingIncoming.contains(where: {
            ($0[CloudKitSocialSchema.Field.status] as? String) == SocialFriendRequestStatus.blocked.rawValue
        }) {
            throw SocialError.permissionDenied
        }
        guard existingIncoming.isEmpty else {
            throw SocialError.duplicateRequest
        }

        let record = CKRecord(recordType: CloudKitSocialSchema.RecordType.friendRequest)
        let now = Date()
        record[CloudKitSocialSchema.Field.fromUser] = currentRef
        record[CloudKitSocialSchema.Field.toUser] = targetRef
        record[CloudKitSocialSchema.Field.status] = SocialFriendRequestStatus.pending.rawValue
        record[CloudKitSocialSchema.Field.createdAt] = now
        record[CloudKitSocialSchema.Field.updatedAt] = now

        let saved = try await save(record: record, savePolicy: .allKeys)
        return SocialFriendRequest(
            recordID: saved.recordID,
            fromUserID: current.recordID,
            toUserID: target.recordID,
            status: .pending,
            createdAt: saved[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date(),
            fromUser: current,
            toUser: target
        )
    }

    func fetchIncomingFriendRequests() async throws -> [SocialFriendRequest] {
        let current = try await requireCurrentUser()
        let records = try await relevantFriendRequests(
            for: current,
            direction: .incoming,
            statuses: [.pending]
        )
        return try await friendRequests(from: records)
    }

    func fetchOutgoingFriendRequests() async throws -> [SocialFriendRequest] {
        let current = try await requireCurrentUser()
        let records = try await relevantFriendRequests(
            for: current,
            direction: .outgoing,
            statuses: [.pending]
        )
        return try await friendRequests(from: records)
    }

    func acceptFriendRequest(_ request: SocialFriendRequest) async throws {
        let current = try await requireCurrentUser()
        guard let record = try await fetchRecord(recordID: request.recordID),
            let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
            let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference
        else {
            throw SocialError.invalidRecord
        }
        guard toRef.recordID == current.recordID else {
            throw SocialError.permissionDenied
        }

        record[CloudKitSocialSchema.Field.status] = SocialFriendRequestStatus.accepted.rawValue
        record[CloudKitSocialSchema.Field.updatedAt] = Date()
        _ = try await save(record: record)

        let now = Date()
        try await upsertFriendEdge(a: fromRef.recordID, b: toRef.recordID, since: now)
        try await upsertFriendEdge(a: toRef.recordID, b: fromRef.recordID, since: now)
        invalidateFriendCaches()
    }

    func declineFriendRequest(_ request: SocialFriendRequest) async throws {
        let current = try await requireCurrentUser()
        guard let record = try await fetchRecord(recordID: request.recordID),
            let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference
        else {
            throw SocialError.invalidRecord
        }
        guard toRef.recordID == current.recordID else {
            throw SocialError.permissionDenied
        }
        record[CloudKitSocialSchema.Field.status] = SocialFriendRequestStatus.rejected.rawValue
        record[CloudKitSocialSchema.Field.updatedAt] = Date()
        _ = try await save(record: record)
    }

    func blockUser(_ user: SocialUser) async throws {
        let current = try await requireCurrentUser()
        guard current.recordID != user.recordID else { return }

        let currentRef = CKRecord.Reference(recordID: current.recordID, action: .none)
        let targetRef = CKRecord.Reference(recordID: user.recordID, action: .none)
        let existing = try await relevantFriendRequests(
            for: current,
            direction: .outgoing,
            statuses: nil
        ).filter { record in
            guard
                let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
                let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference
            else {
                return false
            }
            return fromRef.recordID == currentRef.recordID && toRef.recordID == targetRef.recordID
        }

        let record: CKRecord
        if let first = existing.first {
            record = first
        } else {
            record = CKRecord(recordType: CloudKitSocialSchema.RecordType.friendRequest)
            record[CloudKitSocialSchema.Field.fromUser] = currentRef
            record[CloudKitSocialSchema.Field.toUser] = targetRef
            record[CloudKitSocialSchema.Field.createdAt] = Date()
        }
        record[CloudKitSocialSchema.Field.status] = SocialFriendRequestStatus.blocked.rawValue
        record[CloudKitSocialSchema.Field.updatedAt] = Date()
        _ = try await save(record: record, savePolicy: .allKeys)

        try await deleteRecords(recordIDs: [
            friendEdgeRecordID(a: current.recordID, b: user.recordID),
            friendEdgeRecordID(a: user.recordID, b: current.recordID),
        ])
        invalidateFriendCaches()
    }

    func fetchBlockedUsers() async throws -> [SocialUser] {
        let current = try await requireCurrentUser()
        let records = try await relevantFriendRequests(
            for: current,
            direction: .outgoing,
            statuses: [.blocked]
        )
        let targetIDs = records.compactMap {
            ($0[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference)?.recordID
        }
        let usersByID = try await usersByID(for: targetIDs)
        return targetIDs.compactMap { usersByID[$0] }
    }

    func fetchFriends() async throws -> [SocialUser] {
        let friendIDs = try await fetchFriendRecordIDs()
        let usersByID = try await usersByID(for: friendIDs)
        return friendIDs.compactMap { usersByID[$0] }.sorted {
            $0.handle.localizedCaseInsensitiveCompare($1.handle) == .orderedAscending
        }
    }

    func createPost(type: SocialPostType, text: String) async throws -> SocialPost {
        let current = try await requireCurrentUser()
        guard consumeRateBudget(
            key: "\(postRateLimitKey).\(current.recordID.recordName)",
            maxCount: 6,
            interval: 60
        ) else {
            throw SocialError.rateLimited("Posting is temporarily limited. Try again in a minute.")
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.invalidRecord }
        let record = CKRecord(recordType: CloudKitSocialSchema.RecordType.post)
        record[CloudKitSocialSchema.Field.authorRef] = CKRecord.Reference(
            recordID: current.recordID,
            action: .none
        )
        record[CloudKitSocialSchema.Field.type] = type.rawValue
        record[CloudKitSocialSchema.Field.text] = String(trimmed.prefix(480))
        record[CloudKitSocialSchema.Field.visibility] = SocialPostVisibility.friends.rawValue
        record[CloudKitSocialSchema.Field.createdAt] = Date()

        let saved = try await save(record: record, savePolicy: .allKeys)
        cachedFeed = nil
        return SocialPost(
            recordID: saved.recordID,
            authorUserID: current.recordID,
            author: current,
            type: type,
            text: saved[CloudKitSocialSchema.Field.text] as? String ?? trimmed,
            visibility: .friends,
            createdAt: saved[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date()
        )
    }

    func submitModerationReport(_ report: SocialModerationReport) async throws {
        let recordID = CKRecord.ID(recordName: "modreport_\(report.id)")
        let record = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.moderationReport,
            recordID: recordID
        )
        record[CloudKitSocialSchema.Field.clientReportID] = report.id
        record[CloudKitSocialSchema.Field.targetType] = report.targetType.rawValue
        record[CloudKitSocialSchema.Field.targetRecordName] = report.targetRecordName
        record[CloudKitSocialSchema.Field.reporterHandle] = report.reporterHandle
        record[CloudKitSocialSchema.Field.reason] = report.reason
        record[CloudKitSocialSchema.Field.createdAt] = report.createdAt
        _ = try await save(record: record, savePolicy: .allKeys)
    }

    func fetchFriendsFeed() async throws -> [SocialPost] {
        if let cachedFeed, Date().timeIntervalSince(cachedFeed.fetchedAt) <= feedCacheTTL {
            return cachedFeed.posts
        }
        let friendIDs = try await fetchFriendRecordIDs()
        guard !friendIDs.isEmpty else {
            cachedFeed = ([], Date())
            return []
        }

        let references = friendIDs.map { CKRecord.Reference(recordID: $0, action: .none) }
        let predicate = NSPredicate(
            format: "%K IN %@ AND %K == %@",
            CloudKitSocialSchema.Field.authorRef,
            references,
            CloudKitSocialSchema.Field.visibility,
            SocialPostVisibility.friends.rawValue
        )
        let records = try await queryRecords(
            recordType: CloudKitSocialSchema.RecordType.post,
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: CloudKitSocialSchema.Field.createdAt, ascending: false)],
            resultsLimit: 100
        )
        let authorIDs = records.compactMap {
            ($0[CloudKitSocialSchema.Field.authorRef] as? CKRecord.Reference)?.recordID
        }
        let usersByID = try await usersByID(for: authorIDs)
        let posts = records.compactMap { record in
            socialPost(from: record, usersByID: usersByID)
        }
        .sorted { $0.createdAt > $1.createdAt }
        cachedFeed = (posts, Date())
        return posts
    }

    func submitChaosScore(seasonId: String, score: Int64) async throws {
        let current = try await requireCurrentUser()
        let normalizedSeason = seasonId.trimmingCharacters(in: .whitespacesAndNewlines)
        let recordID = chaosScoreRecordID(seasonId: normalizedSeason, userID: current.recordID)

        let existing = try await fetchRecord(recordID: recordID)
        let record =
            existing
            ?? CKRecord(
                recordType: CloudKitSocialSchema.RecordType.chaosScore,
                recordID: recordID
            )

        let existingScoreRaw = record[CloudKitSocialSchema.Field.score]
        let existingScore = int64Value(existingScoreRaw)
        record[CloudKitSocialSchema.Field.seasonId] = normalizedSeason
        record[CloudKitSocialSchema.Field.userRef] = CKRecord.Reference(
            recordID: current.recordID,
            action: .none
        )
        record[CloudKitSocialSchema.Field.score] = max(existingScore, score)
        record[CloudKitSocialSchema.Field.updatedAt] = Date()
        _ = try await save(record: record, savePolicy: .allKeys)
    }

    func fetchLeaderboard(seasonId: String, limit: Int) async throws -> [SocialChaosScore] {
        let normalizedSeason = seasonId.trimmingCharacters(in: .whitespacesAndNewlines)
        let predicate = NSPredicate(
            format: "%K == %@",
            CloudKitSocialSchema.Field.seasonId,
            normalizedSeason
        )
        let records = try await queryRecords(
            recordType: CloudKitSocialSchema.RecordType.chaosScore,
            predicate: predicate,
            sortDescriptors: [
                NSSortDescriptor(key: CloudKitSocialSchema.Field.score, ascending: false),
                NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: true),
            ],
            resultsLimit: max(1, min(limit, 100))
        )
        let userIDs = records.compactMap {
            ($0[CloudKitSocialSchema.Field.userRef] as? CKRecord.Reference)?.recordID
        }
        let usersByID = try await usersByID(for: userIDs)
        return records.compactMap { socialChaosScore(from: $0, usersByID: usersByID) }
    }

    func createOrUpdateCollabDoc(
        docID: String?,
        type: SocialPostType,
        content: String,
        contributorIDs: [CKRecord.ID],
        expectedVersion: Int64?
    ) async throws -> SocialCollabDoc {
        let current = try await requireCurrentUser()
        let now = Date()
        let trimmed = String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4_000))
        guard !trimmed.isEmpty else { throw SocialError.invalidRecord }

        let recordID = docID.map { CKRecord.ID(recordName: $0) }
        let existing: CKRecord?
        if let recordID {
            existing = try await fetchRecord(recordID: recordID)
        } else {
            existing = nil
        }

        let record: CKRecord
        if let existing {
            record = existing
            let ownerID = (existing[CloudKitSocialSchema.Field.ownerRef] as? CKRecord.Reference)?
                .recordID
            let contributorRefs =
                existing[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? []
            let contributorIDs = Set(contributorRefs.map { $0.recordID })
            guard ownerID == current.recordID || contributorIDs.contains(current.recordID) else {
                throw SocialError.permissionDenied
            }

            let currentVersion = int64Value(existing[CloudKitSocialSchema.Field.version])
            if let expectedVersion, currentVersion > expectedVersion {
                throw SocialError.versionConflict(current: currentVersion)
            }
            record[CloudKitSocialSchema.Field.version] = currentVersion + 1
        } else {
            record =
                if let recordID {
                    CKRecord(recordType: CloudKitSocialSchema.RecordType.collabDoc, recordID: recordID)
                } else {
                    CKRecord(recordType: CloudKitSocialSchema.RecordType.collabDoc)
                }
            record[CloudKitSocialSchema.Field.ownerRef] = CKRecord.Reference(
                recordID: current.recordID,
                action: .none
            )
            record[CloudKitSocialSchema.Field.version] = Int64(1)
            record[CloudKitSocialSchema.Field.createdAt] = now
        }

        let normalizedContributors = Array(
            Set(contributorIDs.filter { $0 != current.recordID })
        )
        record[CloudKitSocialSchema.Field.contributorsRefs] = normalizedContributors.map {
            CKRecord.Reference(recordID: $0, action: .none)
        }
        record[CloudKitSocialSchema.Field.type] = type.rawValue
        record[CloudKitSocialSchema.Field.content] = trimmed
        record[CloudKitSocialSchema.Field.updatedAt] = now

        let saved = try await save(record: record, savePolicy: .allKeys)
        let ownerID =
            (saved[CloudKitSocialSchema.Field.ownerRef] as? CKRecord.Reference)?.recordID
            ?? current.recordID
        let contributorIDsSaved =
            (saved[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? [])
            .map(\.recordID)
        let usersByID = try await usersByID(for: [ownerID] + contributorIDsSaved)
        guard let doc = socialCollabDoc(from: saved, usersByID: usersByID) else {
            throw SocialError.invalidRecord
        }
        return doc
    }

    func fetchMyCollabDocs() async throws -> [SocialCollabDoc] {
        let current = try await requireCurrentUser()
        let currentRef = CKRecord.Reference(recordID: current.recordID, action: .none)

        let ownerPredicate = NSPredicate(
            format: "%K == %@",
            CloudKitSocialSchema.Field.ownerRef,
            currentRef
        )
        let contributorPredicate = NSPredicate(
            format: "ANY %K == %@",
            CloudKitSocialSchema.Field.contributorsRefs,
            currentRef
        )

        let owned = try await queryRecords(
            recordType: CloudKitSocialSchema.RecordType.collabDoc,
            predicate: ownerPredicate,
            sortDescriptors: [NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: false)],
            resultsLimit: 100
        )
        let contributed: [CKRecord]
        do {
            contributed = try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.collabDoc,
                predicate: contributorPredicate,
                sortDescriptors: [NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: false)],
                resultsLimit: 100
            )
        } catch {
            // Fallback when list-reference query support is unavailable in schema/indexes.
            let fallback = try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.collabDoc,
                predicate: NSPredicate(value: true),
                sortDescriptors: [NSSortDescriptor(key: CloudKitSocialSchema.Field.updatedAt, ascending: false)],
                resultsLimit: 200
            )
            contributed = fallback.filter { record in
                let refs =
                    (record[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? [])
                return refs.contains { $0.recordID == current.recordID }
            }
        }

        var merged: [CKRecord.ID: CKRecord] = [:]
        for record in owned + contributed {
            merged[record.recordID] = record
        }

        let records = Array(merged.values)
        let ownerIDs = records.compactMap {
            ($0[CloudKitSocialSchema.Field.ownerRef] as? CKRecord.Reference)?.recordID
        }
        let contributorIDs = records.flatMap {
            ($0[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? [])
                .map(\.recordID)
        }
        let usersByID = try await usersByID(for: ownerIDs + contributorIDs)
        return records.compactMap { socialCollabDoc(from: $0, usersByID: usersByID) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchCollabDoc(id: String) async throws -> SocialCollabDoc? {
        let recordID = CKRecord.ID(recordName: id)
        guard let record = try await fetchRecord(recordID: recordID) else { return nil }
        let ownerID = (record[CloudKitSocialSchema.Field.ownerRef] as? CKRecord.Reference)?.recordID
        let contributorIDs =
            (record[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? [])
            .map(\.recordID)
        let usersByID = try await usersByID(for: [ownerID].compactMap { $0 } + contributorIDs)
        return socialCollabDoc(from: record, usersByID: usersByID)
    }

    static func isValidHandle(_ handle: String) -> Bool {
        SocialHandleNormalizer.isValid(handle)
    }

    private func requireCurrentUser() async throws -> SocialUser {
        guard let current = try await fetchCurrentUserIfStored() else {
            throw SocialError.missingProfile
        }
        return current
    }

    private func normalizeHandle(_ handle: String) -> String {
        SocialHandleNormalizer.normalize(handle)
    }

    private func normalizedDisplayName(_ displayName: String?, handle: String) -> String {
        SocialHandleNormalizer.displayName(displayName, fallbackHandle: handle)
    }

    private func resolveCreatedCurrentUser(
        fromSavedRecord saved: CKRecord,
        normalizedHandle: String,
        ownerUserRecordName: String
    ) async -> SocialUser {
        let ownerPredicate = NSPredicate(
            format: "%K == %@",
            CloudKitSocialSchema.Field.ownerUserRecordName,
            ownerUserRecordName
        )
        do {
            debugLogProfileSetup(
                "reloading current profile by ownerUserRecordName normalizedHandle=\(normalizedHandle) predicate=\(ownerPredicate.predicateFormat)"
            )
            if let reloadedCurrentUser = try await findCurrentUserByOwnerRecordName() {
                debugLogProfileSetup(
                    "reload by ownerUserRecordName succeeded normalizedHandle=\(normalizedHandle) recordID=\(reloadedCurrentUser.recordID.recordName)"
                )
                return reloadedCurrentUser
            }
            debugLogProfileSetup(
                "reload by ownerUserRecordName returned no record normalizedHandle=\(normalizedHandle)"
            )
        } catch {
            debugLogProfileSetupError(
                stage: "reloadCurrentUserByOwnerRecordName",
                error: error,
                normalizedHandle: normalizedHandle,
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                recordID: saved.recordID,
                predicate: ownerPredicate,
                fieldNames: CloudKitSocialSchema.Projection.userProfile
            )
        }

        do {
            debugLogProfileSetup(
                "reloading current profile by recordID normalizedHandle=\(normalizedHandle) recordID=\(saved.recordID.recordName)"
            )
            if let reloadedSavedRecord = try await fetchRecord(
                recordID: saved.recordID,
                desiredKeys: CloudKitSocialSchema.Projection.userProfile,
                allowsMissingRecord: true,
                operation: "reloadCreatedCurrentUserProfile",
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                normalizedHandle: normalizedHandle,
                fieldNames: CloudKitSocialSchema.Projection.userProfile
            ) {
                debugLogProfileSetup(
                    "reload by recordID succeeded normalizedHandle=\(normalizedHandle) recordID=\(reloadedSavedRecord.recordID.recordName)"
                )
                return (try? socialUser(from: reloadedSavedRecord))
                    ?? fallbackCurrentUser(fromSavedRecord: saved, normalizedHandle: normalizedHandle)
            }
            debugLogProfileSetup(
                "reload by recordID returned no record normalizedHandle=\(normalizedHandle) recordID=\(saved.recordID.recordName)"
            )
        } catch {
            debugLogProfileSetupError(
                stage: "reloadCurrentUserByRecordID",
                error: error,
                normalizedHandle: normalizedHandle,
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                recordID: saved.recordID,
                fieldNames: CloudKitSocialSchema.Projection.userProfile
            )
        }

        return fallbackCurrentUser(fromSavedRecord: saved, normalizedHandle: normalizedHandle)
    }

    private func fallbackCurrentUser(fromSavedRecord saved: CKRecord, normalizedHandle: String) -> SocialUser {
        debugLogProfileSetup(
            "falling back to saved record after successful save normalizedHandle=\(normalizedHandle) recordID=\(saved.recordID.recordName)"
        )
        return (try? socialUser(from: saved))
            ?? SocialUser(
                recordID: saved.recordID,
                handle: normalizedHandle,
                displayName: normalizedDisplayName(
                    saved[CloudKitSocialSchema.Field.displayName] as? String,
                    handle: normalizedHandle
                ),
                createdAt: saved[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date()
            )
    }

    private func queryUserProfilesByHandle(
        _ normalizedHandle: String,
        resultsLimit: Int,
        operation: String,
        desiredKeys: [String]
    ) async throws -> [CKRecord] {
        do {
            return try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                predicate: NSPredicate(
                    format: "%K == %@",
                    CloudKitSocialSchema.Field.handle,
                    normalizedHandle
                ),
                resultsLimit: resultsLimit,
                desiredKeys: desiredKeys,
                operation: operation
            )
        } catch {
            guard shouldFallbackToFullUserScan(error) else { throw error }
            let records = try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                predicate: NSPredicate(value: true),
                resultsLimit: CKQueryOperation.maximumResults,
                desiredKeys: desiredKeys,
                operation: "\(operation)FallbackScan"
            )
            return records.filter {
                normalizeHandle(($0[CloudKitSocialSchema.Field.handle] as? String) ?? "") == normalizedHandle
            }
        }
    }

    private func allFriendRequestRecords() async throws -> [CKRecord] {
        try await queryRecords(
            recordType: CloudKitSocialSchema.RecordType.friendRequest,
            predicate: NSPredicate(value: true),
            resultsLimit: 200,
            desiredKeys: CloudKitSocialSchema.Projection.friendRequest,
            operation: "listFriendRequests"
        )
    }

    private func relevantFriendRequests(
        for current: SocialUser,
        direction: FriendRequestDirection,
        statuses: Set<SocialFriendRequestStatus>?
    ) async throws -> [CKRecord] {
        let currentRecordID = current.recordID
        return try await allFriendRequestRecords().filter { record in
            guard
                let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
                let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference,
                let statusRaw = record[CloudKitSocialSchema.Field.status] as? String,
                let status = SocialFriendRequestStatus(rawValue: statusRaw)
            else {
                return false
            }
            let matchesDirection: Bool
            switch direction {
            case .incoming:
                matchesDirection = toRef.recordID == currentRecordID
            case .outgoing:
                matchesDirection = fromRef.recordID == currentRecordID
            }
            guard matchesDirection else { return false }
            if let statuses {
                return statuses.contains(status)
            }
            return true
        }
    }

    private func consumeRateBudget(
        key: String,
        maxCount: Int,
        interval: TimeInterval
    ) -> Bool {
        let now = Date().timeIntervalSince1970
        var timestamps = (userDefaults.array(forKey: key) as? [Double]) ?? []
        timestamps = timestamps.filter { now - $0 < interval }
        guard timestamps.count < maxCount else {
            userDefaults.set(timestamps, forKey: key)
            return false
        }
        timestamps.append(now)
        userDefaults.set(timestamps, forKey: key)
        return true
    }

    private func usersByID(for recordIDs: [CKRecord.ID]) async throws -> [CKRecord.ID: SocialUser] {
        let uniqueIDs = Array(Set(recordIDs))
        guard !uniqueIDs.isEmpty else { return [:] }
        let records = try await fetchRecords(
            recordIDs: uniqueIDs,
            desiredKeys: CloudKitSocialSchema.Projection.userProfile,
            allowsMissingRecords: true
        )
        var map: [CKRecord.ID: SocialUser] = [:]
        for record in records {
            if let user = try? socialUser(from: record) {
                map[user.recordID] = user
            }
        }
        return map
    }

    private func friendRequests(from records: [CKRecord]) async throws -> [SocialFriendRequest] {
        let userIDs = records.flatMap { record -> [CKRecord.ID] in
            let fromID =
                (record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference)?.recordID
            let toID =
                (record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference)?.recordID
            return [fromID, toID].compactMap { $0 }
        }
        let usersByID = try await usersByID(for: userIDs)
        return records.compactMap { socialFriendRequest(from: $0, usersByID: usersByID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func socialUser(from record: CKRecord) throws -> SocialUser {
        guard record.recordType == CloudKitSocialSchema.RecordType.userProfile else {
            throw SocialError.invalidRecord
        }
        let handle = normalizeHandle(
            (record[CloudKitSocialSchema.Field.handle] as? String) ?? record.recordID.recordName
        )
        guard !handle.isEmpty else { throw SocialError.invalidRecord }
        let displayName =
            (record[CloudKitSocialSchema.Field.displayName] as? String)?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? handle
        let createdAt = record[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date()
        return SocialUser(
            recordID: record.recordID,
            handle: handle,
            displayName: displayName.isEmpty ? handle : displayName,
            createdAt: createdAt
        )
    }

    private func socialFriendRequest(
        from record: CKRecord,
        usersByID: [CKRecord.ID: SocialUser]
    ) -> SocialFriendRequest? {
        guard
            let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference,
            let toRef = record[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference
        else {
            return nil
        }
        guard
            let statusRaw = record[CloudKitSocialSchema.Field.status] as? String,
            let status = SocialFriendRequestStatus(rawValue: statusRaw)
        else {
            return nil
        }
        return SocialFriendRequest(
            recordID: record.recordID,
            fromUserID: fromRef.recordID,
            toUserID: toRef.recordID,
            status: status,
            createdAt: record[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date(),
            fromUser: usersByID[fromRef.recordID],
            toUser: usersByID[toRef.recordID]
        )
    }

    private func socialPost(
        from record: CKRecord,
        usersByID: [CKRecord.ID: SocialUser]
    ) -> SocialPost? {
        guard
            let authorRef = record[CloudKitSocialSchema.Field.authorRef] as? CKRecord.Reference,
            let typeRaw = record[CloudKitSocialSchema.Field.type] as? String,
            let type = SocialPostType(rawValue: typeRaw),
            let text = record[CloudKitSocialSchema.Field.text] as? String,
            let visibilityRaw = record[CloudKitSocialSchema.Field.visibility] as? String,
            let visibility = SocialPostVisibility(rawValue: visibilityRaw)
        else {
            return nil
        }
        return SocialPost(
            recordID: record.recordID,
            authorUserID: authorRef.recordID,
            author: usersByID[authorRef.recordID],
            type: type,
            text: text,
            visibility: visibility,
            createdAt: record[CloudKitSocialSchema.Field.createdAt] as? Date ?? Date()
        )
    }

    private func socialChaosScore(
        from record: CKRecord,
        usersByID: [CKRecord.ID: SocialUser]
    ) -> SocialChaosScore? {
        guard
            let seasonID = record[CloudKitSocialSchema.Field.seasonId] as? String,
            let userRef = record[CloudKitSocialSchema.Field.userRef] as? CKRecord.Reference
        else {
            return nil
        }
        return SocialChaosScore(
            recordID: record.recordID,
            seasonId: seasonID,
            userID: userRef.recordID,
            user: usersByID[userRef.recordID],
            score: int64Value(record[CloudKitSocialSchema.Field.score]),
            updatedAt: record[CloudKitSocialSchema.Field.updatedAt] as? Date ?? Date()
        )
    }

    private func socialCollabDoc(
        from record: CKRecord,
        usersByID: [CKRecord.ID: SocialUser]
    ) -> SocialCollabDoc? {
        guard
            let ownerRef = record[CloudKitSocialSchema.Field.ownerRef] as? CKRecord.Reference,
            let typeRaw = record[CloudKitSocialSchema.Field.type] as? String,
            let type = SocialPostType(rawValue: typeRaw),
            let content = record[CloudKitSocialSchema.Field.content] as? String
        else {
            return nil
        }
        let contributorRefs =
            (record[CloudKitSocialSchema.Field.contributorsRefs] as? [CKRecord.Reference] ?? [])
        let contributorIDs = contributorRefs.map(\.recordID)
        return SocialCollabDoc(
            recordID: record.recordID,
            ownerID: ownerRef.recordID,
            owner: usersByID[ownerRef.recordID],
            contributorIDs: contributorIDs,
            contributors: contributorIDs.compactMap { usersByID[$0] },
            type: type,
            content: content,
            version: int64Value(record[CloudKitSocialSchema.Field.version]),
            updatedAt: record[CloudKitSocialSchema.Field.updatedAt] as? Date ?? Date()
        )
    }

    private func fetchFriendRecordIDs() async throws -> [CKRecord.ID] {
        if let cachedFriendIDs, Date().timeIntervalSince(cachedFriendIDs.fetchedAt) <= friendCacheTTL {
            return cachedFriendIDs.ids
        }
        let current = try await requireCurrentUser()
        let currentRef = CKRecord.Reference(recordID: current.recordID, action: .none)
        let edges = try await queryRecords(
            recordType: CloudKitSocialSchema.RecordType.friendEdge,
            predicate: NSPredicate(value: true),
            resultsLimit: 500,
            desiredKeys: CloudKitSocialSchema.Projection.friendEdge,
            operation: "listFriendEdges"
        ).filter { record in
            guard let fromRef = record[CloudKitSocialSchema.Field.fromUser] as? CKRecord.Reference else {
                return false
            }
            return fromRef.recordID == currentRef.recordID
        }
        let ids = edges.compactMap {
            ($0[CloudKitSocialSchema.Field.toUser] as? CKRecord.Reference)?.recordID
        }
        cachedFriendIDs = (ids, Date())
        return ids
    }

    private func upsertFriendEdge(a: CKRecord.ID, b: CKRecord.ID, since: Date) async throws {
        let recordID = friendEdgeRecordID(a: a, b: b)
        let record = CKRecord(recordType: CloudKitSocialSchema.RecordType.friendEdge, recordID: recordID)
        record[CloudKitSocialSchema.Field.fromUser] = CKRecord.Reference(recordID: a, action: .none)
        record[CloudKitSocialSchema.Field.toUser] = CKRecord.Reference(recordID: b, action: .none)
        record[CloudKitSocialSchema.Field.createdAt] = since
        _ = try await save(record: record, savePolicy: .allKeys)
    }

    private func friendEdgeRecordID(a: CKRecord.ID, b: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "friendedge_\(a.recordName)__\(b.recordName)")
    }

    private func chaosScoreRecordID(seasonId: String, userID: CKRecord.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "chaosscore_\(seasonId)_\(userID.recordName)")
    }

    private func invalidateFriendCaches() {
        cachedFriendIDs = nil
        cachedFeed = nil
    }

    private func int64Value(_ value: Any?) -> Int64 {
        if let value = value as? Int64 { return value }
        if let value = value as? NSNumber { return value.int64Value }
        return 0
    }

    private func shouldFallbackToFullUserScan(_ error: Error) -> Bool {
        guard let ckError = Self.cloudKitError(from: error) else { return false }
        guard
            ckError.code == .invalidArguments
                || ckError.code == .constraintViolation
                || ckError.code == .serverRejectedRequest
        else {
            return false
        }
        let details = ckError.localizedDescription.lowercased()
        return isSchemaIndexingError(details)
    }

    private func makeAvailabilityState(
        accountStatus: CKAccountStatus?,
        lastError: SocialCloudKitErrorDiagnostic? = nil
    ) -> SocialAvailabilityState {
        SocialAvailabilityState(
            isAvailable: accountStatus == .available,
            diagnostics: SocialCloudKitDiagnostics(
                accountStatus: accountStatus,
                containerIdentifier: currentContainerIdentifier(),
                databaseScope: CloudKitManager.socialDatabaseScope,
                environmentName: CloudKitSocialConfig.environmentName,
                lastError: lastError
            )
        )
    }

    private func currentContainerIdentifier() -> String {
        container.containerIdentifier ?? CloudKitSocialConfig.containerIdentifier
    }

    private func makeOperationContext(
        operation: String,
        recordType: String? = nil,
        recordNames: [String] = [],
        normalizedHandle: String? = nil,
        predicate: NSPredicate? = nil,
        fieldNames: [String] = [],
        sortDescriptors: [NSSortDescriptor] = []
    ) -> SocialCloudKitOperationContext {
        SocialCloudKitOperationContext(
            operation: operation,
            recordType: recordType,
            recordNames: recordNames,
            normalizedHandle: normalizedHandle,
            predicateSummary: predicate?.predicateFormat,
            fieldNames: fieldNames,
            sortKeys: sortDescriptors.compactMap(\.key),
            containerIdentifier: currentContainerIdentifier(),
            databaseScope: CloudKitManager.socialDatabaseScope,
            environmentName: CloudKitSocialConfig.environmentName
        )
    }

    private static func wrapCloudKitError(_ error: Error, context: SocialCloudKitOperationContext) -> Error {
        if let wrapped = error as? SocialCloudOperationError {
            return wrapped
        }
        guard let ckError = error as? CKError else { return error }
        return SocialCloudOperationError(
            underlyingError: ckError,
            diagnostic: SocialCloudKitErrorDiagnostic.make(
                from: ckError,
                context: context,
                isRetryable: Self.isRetryableCloudKitError(ckError)
            )
        )
    }

    private func fetchCurrentICloudUserRecordName() async throws -> String {
        cloudKitLogger.info("CloudKit call start: fetchUserRecordID")
        do {
            let recordName = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<String, Error>) in
                container.fetchUserRecordID { recordID, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let recordID else {
                        continuation.resume(throwing: CKError(.notAuthenticated))
                        return
                    }
                    continuation.resume(returning: recordID.recordName)
                }
            }
            cloudKitLogger.info("CloudKit call success: fetchUserRecordID")
            return recordName
        } catch {
            Self.logCloudKitError(error, context: "fetchUserRecordID")
            throw error
        }
    }

    private func findCurrentUserByOwnerRecordName() async throws -> SocialUser? {
        let ownerUserRecordName: String
        do {
            ownerUserRecordName = try await fetchCurrentICloudUserRecordName()
        } catch {
            return nil
        }

        let records: [CKRecord]
        do {
            records = try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                predicate: NSPredicate(
                    format: "%K == %@",
                    CloudKitSocialSchema.Field.ownerUserRecordName,
                    ownerUserRecordName
                ),
                resultsLimit: 1,
                desiredKeys: CloudKitSocialSchema.Projection.userProfile,
                operation: "findCurrentUserByOwnerRecordName"
            )
        } catch {
            guard shouldFallbackToFullUserScan(error) else { throw error }
            let fallback = try await queryRecords(
                recordType: CloudKitSocialSchema.RecordType.userProfile,
                predicate: NSPredicate(value: true),
                resultsLimit: CKQueryOperation.maximumResults,
                desiredKeys: CloudKitSocialSchema.Projection.userProfile
            )
            records = fallback.filter {
                ($0[CloudKitSocialSchema.Field.ownerUserRecordName] as? String) == ownerUserRecordName
            }
        }

        guard let record = records.first else { return nil }
        let user = try socialUser(from: record)
        cachedCurrentUser = user
        userDefaults.set(user.recordID.recordName, forKey: currentUserRecordNameKey)
        return user
    }

    private func isSchemaIndexingError(_ details: String) -> Bool {
        details.contains("queryable")
            || details.contains("index")
            || details.contains("field")
    }

    private func accountStatus() async throws -> CKAccountStatus {
        cloudKitLogger.info("CloudKit call start: accountStatus")
        do {
            let status = try await container.accountStatus()
            cloudKitLogger.info(
                "CloudKit call success: accountStatus = \(Self.accountStatusDescription(status), privacy: .public)"
            )
            return status
        } catch {
            Self.logCloudKitError(error, context: "accountStatus")
            throw error
        }
    }

    private func queryRecords(
        recordType: String,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor] = [],
        resultsLimit: Int = CKQueryOperation.maximumResults,
        desiredKeys: [String]? = nil,
        operation: String = "queryRecords"
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        let context = makeOperationContext(
            operation: operation,
            recordType: recordType,
            predicate: predicate,
            fieldNames: desiredKeys ?? [],
            sortDescriptors: sortDescriptors
        )

        do {
            cloudKitLogger.info(
                "CloudKit call start: \(operation, privacy: .public) type=\(recordType, privacy: .public) limit=\(resultsLimit)"
            )
            repeat {
                let (records, nextCursor) = try await runQuery(
                    query: cursor == nil ? query : nil,
                    cursor: cursor,
                    desiredKeys: desiredKeys,
                    resultsLimit: resultsLimit
                )
                allRecords.append(contentsOf: records)
                cursor = nextCursor
                if resultsLimit != CKQueryOperation.maximumResults,
                    allRecords.count >= resultsLimit
                {
                    return Array(allRecords.prefix(resultsLimit))
                }
            } while cursor != nil

            cloudKitLogger.info(
                "CloudKit call success: \(operation, privacy: .public) type=\(recordType, privacy: .public) count=\(allRecords.count)"
            )
            return allRecords
        } catch {
            let wrapped = Self.wrapCloudKitError(error, context: context)
            Self.logCloudKitError(wrapped, context: "\(operation)[\(recordType)]")
            throw wrapped
        }
    }

    private func runQuery(
        query: CKQuery?,
        cursor: CKQueryOperation.Cursor?,
        desiredKeys: [String]?,
        resultsLimit: Int
    ) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else if let query {
                operation = CKQueryOperation(query: query)
            } else {
                continuation.resume(throwing: SocialError.invalidRecord)
                return
            }
            operation.desiredKeys = desiredKeys
            operation.resultsLimit = resultsLimit
            var records: [CKRecord] = []
            var firstError: Error?
            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    if firstError == nil {
                        firstError = error
                    }
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let firstError {
                        continuation.resume(throwing: firstError)
                        return
                    }
                    continuation.resume(returning: (records, cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                    return
                }
            }
            publicDB.add(operation)
        }
    }

    private func fetchRecord(
        recordID: CKRecord.ID,
        desiredKeys: [String]? = nil,
        allowsMissingRecord: Bool = false,
        operation: String = "fetchRecord",
        recordType: String? = nil,
        normalizedHandle: String? = nil,
        fieldNames: [String]? = nil
    ) async throws -> CKRecord? {
        let records = try await fetchRecords(
            recordIDs: [recordID],
            desiredKeys: desiredKeys,
            allowsMissingRecords: allowsMissingRecord,
            operation: operation,
            recordType: recordType,
            normalizedHandle: normalizedHandle,
            fieldNames: fieldNames ?? desiredKeys ?? []
        )
        return records.first
    }

    private func fetchRecords(
        recordIDs: [CKRecord.ID],
        desiredKeys: [String]? = nil,
        allowsMissingRecords: Bool = false,
        operation: String = "fetchRecords",
        recordType: String? = nil,
        normalizedHandle: String? = nil,
        fieldNames: [String] = []
    ) async throws -> [CKRecord] {
        guard !recordIDs.isEmpty else { return [] }
        let context = makeOperationContext(
            operation: operation,
            recordType: recordType,
            recordNames: recordIDs.map(\.recordName),
            normalizedHandle: normalizedHandle,
            fieldNames: fieldNames
        )
        cloudKitLogger.info(
            "CloudKit call start: \(operation, privacy: .public) count=\(recordIDs.count)"
        )
        do {
            let records = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<[CKRecord], Error>) in
                let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
                operation.desiredKeys = desiredKeys
                var recordsByID: [CKRecord.ID: CKRecord] = [:]
                var firstError: Error?
                operation.perRecordResultBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        recordsByID[recordID] = record
                    case .failure(let error):
                        if allowsMissingRecords,
                            let ckError = error as? CKError,
                            ckError.code == .unknownItem
                        {
                            return
                        }
                        if firstError == nil {
                            firstError = error
                        }
                    }
                }
                operation.fetchRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        if let firstError {
                            continuation.resume(throwing: firstError)
                            return
                        }
                        let ordered = recordIDs.compactMap { recordsByID[$0] }
                        continuation.resume(returning: ordered)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                publicDB.add(operation)
            }
            cloudKitLogger.info(
                "CloudKit call success: \(operation, privacy: .public) count=\(records.count)"
            )
            return records
        } catch {
            let wrapped = Self.wrapCloudKitError(error, context: context)
            Self.logCloudKitError(wrapped, context: operation)
            throw wrapped
        }
    }

    private func save(record: CKRecord, savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .changedKeys)
        async throws -> CKRecord
    {
        let records = try await save(records: [record], savePolicy: savePolicy)
        guard let first = records.first else {
            throw SocialError.invalidRecord
        }
        return first
    }

    private func save(
        records: [CKRecord],
        savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .changedKeys
    ) async throws -> [CKRecord] {
        guard !records.isEmpty else { return [] }
        let recordTypes = Array(Set(records.map(\.recordType))).sorted()
        let recordNames = records.map(\.recordID.recordName)
        let referencedFieldNames = Array(
            Set(records.flatMap { $0.allKeys() })
        ).sorted()
        let context = makeOperationContext(
            operation: "saveRecords",
            recordType: recordTypes.joined(separator: ","),
            recordNames: recordNames,
            fieldNames: referencedFieldNames
        )
        let perRecordContexts = Dictionary(uniqueKeysWithValues: records.map { record in
            (
                record.recordID,
                makeOperationContext(
                    operation: "saveRecord",
                    recordType: record.recordType,
                    recordNames: [record.recordID.recordName],
                    fieldNames: record.allKeys().sorted()
                )
            )
        })
        cloudKitLogger.info(
            "CloudKit call start: saveRecords count=\(records.count) database=\(Self.databaseDescription(for: self.publicDB), privacy: .public)"
        )
        do {
            let savedRecords = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<[CKRecord], Error>) in
                let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
                operation.isAtomic = false
                operation.savePolicy = savePolicy
                var savedByID: [CKRecord.ID: CKRecord] = [:]
                var firstError: Error?
                operation.perRecordSaveBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        savedByID[recordID] = record
                    case .failure(let error):
                        let wrapped = Self.wrapCloudKitError(
                            error,
                            context: perRecordContexts[recordID] ?? context
                        )
                        Self.logCloudKitError(wrapped, context: "saving record \(recordID.recordName)")
                        if firstError == nil {
                            firstError = wrapped
                        }
                    }
                }
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        if let firstError {
                            continuation.resume(throwing: firstError)
                            return
                        }
                        let ordered = records.compactMap { savedByID[$0.recordID] ?? $0 }
                        continuation.resume(returning: ordered)
                    case .failure(let error):
                        let wrapped = Self.wrapCloudKitError(error, context: context)
                        Self.logCloudKitError(wrapped, context: "finishing record save batch")
                        continuation.resume(throwing: wrapped)
                    }
                }
                publicDB.add(operation)
            }
            cloudKitLogger.info("CloudKit call success: saveRecords count=\(savedRecords.count)")
            return savedRecords
        } catch {
            let wrapped = Self.wrapCloudKitError(error, context: context)
            Self.logCloudKitError(wrapped, context: "saveRecords")
            throw wrapped
        }
    }

    private func deleteRecords(recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }
        let context = makeOperationContext(
            operation: "deleteRecords",
            recordNames: recordIDs.map(\.recordName)
        )
        cloudKitLogger.info("CloudKit call start: deleteRecords count=\(recordIDs.count)")
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                operation.isAtomic = false
                var firstBlockingError: Error?
                operation.perRecordDeleteBlock = { _, result in
                    guard case .failure(let error) = result else { return }
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        return
                    }
                    if firstBlockingError == nil {
                        firstBlockingError = error
                    }
                }
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        if let firstBlockingError {
                            continuation.resume(throwing: firstBlockingError)
                        } else {
                            continuation.resume()
                        }
                    case .failure(let error):
                        if let ckError = error as? CKError, ckError.code == .unknownItem {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: Self.wrapCloudKitError(error, context: context))
                        }
                    }
                }
                publicDB.add(operation)
            }
            cloudKitLogger.info("CloudKit call success: deleteRecords count=\(recordIDs.count)")
        } catch {
            let wrapped = Self.wrapCloudKitError(error, context: context)
            Self.logCloudKitError(wrapped, context: "deleteRecords")
            throw wrapped
        }
    }

    private static func accountStatusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "available"
        case .noAccount:
            return "noAccount"
        case .restricted:
            return "restricted"
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .temporarilyUnavailable:
            return "temporarilyUnavailable"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }

    private static func databaseDescription(for database: CKDatabase) -> String {
        switch database.databaseScope {
        case .public:
            return "publicCloudDatabase"
        case .private:
            return "privateCloudDatabase"
        case .shared:
            return "sharedCloudDatabase"
        @unknown default:
            return "unknownDatabaseScope"
        }
    }

    private static func errorDescription(_ error: Error) -> String {
        if let ckError = cloudKitError(from: error) {
            return "CKError(\(ckError.code.rawValue)): \(ckError.localizedDescription)"
        }
        return error.localizedDescription
    }

    private func debugLogProfileSetup(_ message: String) {
        #if DEBUG
            cloudKitLogger.debug("Profile setup: \(message, privacy: .public)")
        #endif
    }

    private func debugLogProfileSetupError(
        stage: String,
        error: Error,
        normalizedHandle: String,
        recordType: String,
        recordID: CKRecord.ID? = nil,
        predicate: NSPredicate? = nil,
        fieldNames: [String] = []
    ) {
        #if DEBUG
            let wrapped = Self.wrapCloudKitError(
                error,
                context: makeOperationContext(
                    operation: stage,
                    recordType: recordType,
                    recordNames: recordID.map { [$0.recordName] } ?? [],
                    normalizedHandle: normalizedHandle,
                    predicate: predicate,
                    fieldNames: fieldNames
                )
            )
            if let operationError = wrapped as? SocialCloudOperationError,
                let diagnostic = operationError.diagnostic
            {
                cloudKitLogger.debug(
                    "Profile setup failed stage=\(stage, privacy: .public) code=\(diagnostic.code, privacy: .public) recordType=\(diagnostic.recordType ?? "n/a", privacy: .public) recordNames=\(diagnostic.recordNames.joined(separator: ","), privacy: .public) normalizedHandle=\(diagnostic.normalizedHandle ?? "n/a", privacy: .public) predicate=\(diagnostic.predicateSummary ?? "n/a", privacy: .public) fields=\(diagnostic.fieldNames.joined(separator: ","), privacy: .public) description=\(diagnostic.localizedDescription, privacy: .public)"
                )
                if !diagnostic.partialFailureDetails.isEmpty {
                    cloudKitLogger.debug(
                        "Profile setup partial failures stage=\(stage, privacy: .public): \(diagnostic.partialFailureDetails, privacy: .public)"
                    )
                }
            } else {
                cloudKitLogger.debug(
                    "Profile setup failed stage=\(stage, privacy: .public) normalizedHandle=\(normalizedHandle, privacy: .public) description=\(error.localizedDescription, privacy: .public)"
                )
            }
        #endif
    }

    private static func logCloudKitError(_ error: Error, context: String) {
        if let operationError = error as? SocialCloudOperationError,
            let diagnostic = operationError.diagnostic
        {
            cloudKitLogger.error(
                "CloudKit \(context, privacy: .public) failed op=\(diagnostic.operation, privacy: .public) code=\(diagnostic.code, privacy: .public) recordType=\(diagnostic.recordType ?? "n/a", privacy: .public) recordNames=\(diagnostic.recordNames.joined(separator: ","), privacy: .public) normalizedHandle=\(diagnostic.normalizedHandle ?? "n/a", privacy: .public) fields=\(diagnostic.fieldNames.joined(separator: ","), privacy: .public) retryable=\(diagnostic.isRetryable) description=\(diagnostic.localizedDescription, privacy: .public)"
            )
            #if DEBUG
                cloudKitLogger.debug(
                    "CloudKit diagnostic details: \(diagnostic.debugSummary, privacy: .public)"
                )
            #endif
            return
        }
        if let ckError = cloudKitError(from: error) {
            cloudKitLogger.error(
                "CloudKit \(context, privacy: .public) failed with domain=\(CKError.errorDomain, privacy: .public) code=\(ckError.code.rawValue) description=\(ckError.localizedDescription, privacy: .public)"
            )
            #if DEBUG
                cloudKitLogger.debug(
                    "CloudKit \(context, privacy: .public) CKError userInfo: \(String(describing: ckError.userInfo), privacy: .public)"
                )
            #endif
            return
        }
        cloudKitLogger.error(
            "CloudKit \(context, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
        )
    }

    private static func cloudKitError(from error: Error) -> CKError? {
        if let operationError = error as? SocialCloudOperationError {
            return operationError.underlyingError as? CKError
        }
        return error as? CKError
    }

    private static func isUnknownItemError(_ error: Error) -> Bool {
        cloudKitError(from: error)?.code == .unknownItem
    }

    private static func isRetryableCloudKitError(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy,
            .requestRateLimited, .notAuthenticated, .accountTemporarilyUnavailable:
            return true
        default:
            return false
        }
    }
}

enum SocialBackendFactory {
    static func make() -> any SocialBackend {
        let arguments = ProcessInfo.processInfo.arguments
        let isRunningUnderXCTest =
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let isUITestingLaunch = arguments.contains("-ui-testing")
        let allowLiveCloudKit = arguments.contains("-ui-testing-cloudkit-live")
            || arguments.contains("-social-live")
        let isRunningOnSimulator: Bool = {
            #if targetEnvironment(simulator)
                return true
            #else
                return false
            #endif
        }()
        let shouldUseMockBackend =
            arguments.contains("-ui-testing-social-mock")
            || (!allowLiveCloudKit && (isUITestingLaunch || isRunningUnderXCTest || isRunningOnSimulator))
        if shouldUseMockBackend {
            return UITestSocialBackend(
                forceUnavailable: arguments.contains("-ui-testing-force-social-unavailable"),
                seededIncomingRequests: intArgument(after: "-ui-testing-social-seed-incoming") ?? 0
            )
        }
        return CloudKitStore()
    }

    private static func intArgument(after flag: String) -> Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: flagIndex)
        guard valueIndex < arguments.endIndex else { return nil }
        return Int(arguments[valueIndex])
    }
}

actor UITestSocialBackend: SocialBackend {
    private var currentUser: SocialUser?
    private var usersByHandle: [String: SocialUser] = [:]
    private var usersByRecordName: [String: SocialUser] = [:]
    private var friendRequests: [SocialFriendRequest] = []
    private var friendshipsByUser: [String: Set<String>] = [:]
    private var blockedByUser: [String: Set<String>] = [:]
    private var posts: [SocialPost] = []
    private var scoresBySeason: [String: [String: Int64]] = [:]
    private var collabDocsByID: [String: SocialCollabDoc] = [:]
    private var moderationReports: [SocialModerationReport] = []

    private let forceUnavailable: Bool
    private let seededIncomingRequests: Int
    private var seededIncomingApplied = false

    init(forceUnavailable: Bool, seededIncomingRequests: Int) {
        self.forceUnavailable = forceUnavailable
        self.seededIncomingRequests = max(0, seededIncomingRequests)
    }

    func backendDisplayName() async -> String {
        "UI Test Mock"
    }

    func setStoredCurrentUserRecordName(_ recordName: String?) async {
        guard let recordName, !recordName.isEmpty else {
            currentUser = nil
            return
        }
        currentUser = usersByRecordName[recordName]
    }

    func availabilityState() async -> SocialAvailabilityState {
        if forceUnavailable {
            return SocialAvailabilityState(
                isAvailable: false,
                diagnostics: SocialCloudKitDiagnostics(
                    accountStatus: .couldNotDetermine,
                    containerIdentifier: CloudKitSocialConfig.containerIdentifier,
                    databaseScope: CloudKitManager.socialDatabaseScope,
                    environmentName: CloudKitSocialConfig.environmentName,
                    lastError: SocialCloudKitErrorDiagnostic(
                        operation: "ui-test",
                        domain: CKError.errorDomain,
                        code: "unavailable",
                        localizedDescription: "Social features are unavailable in this test run.",
                        recordType: nil,
                        recordNames: [],
                        normalizedHandle: nil,
                        predicateSummary: nil,
                        fieldNames: [],
                        sortKeys: [],
                        containerIdentifier: CloudKitSocialConfig.containerIdentifier,
                        databaseScope: CloudKitManager.socialDatabaseScope,
                        environmentName: CloudKitSocialConfig.environmentName,
                        isRetryable: false,
                        partialFailureDetails: [],
                        debugUserInfo: nil
                    )
                )
            )
        }
        return .available
    }

    func fetchCurrentUserIfStored() async throws -> SocialUser? {
        currentUser
    }

    func getOrCreateCurrentUser(handle: String, displayName: String?) async throws -> SocialUser {
        if let currentUser {
            return currentUser
        }
        let normalized = SocialHandleNormalizer.normalize(handle)
        guard CloudKitStore.isValidHandle(normalized) else {
            throw SocialError.invalidHandle
        }
        if usersByHandle[normalized] != nil {
            throw SocialError.handleTaken
        }
        let user = SocialUser(
            recordID: CKRecord.ID(recordName: "mock_user_\(normalized)"),
            handle: normalized,
            displayName: normalizedDisplayName(displayName, fallbackHandle: normalized),
            createdAt: Date()
        )
        usersByHandle[normalized] = user
        usersByRecordName[user.recordID.recordName] = user
        currentUser = user
        applySeededIncomingRequestsIfNeeded()
        return user
    }

    func findUserByHandle(_ handle: String) async throws -> SocialUser? {
        let normalized = SocialHandleNormalizer.normalize(handle)
        guard let user = usersByHandle[normalized] else { return nil }
        if user.recordID == currentUser?.recordID {
            return nil
        }
        return user
    }

    func sendFriendRequest(toUser target: SocialUser) async throws -> SocialFriendRequest {
        let current = try requireCurrentUser()
        guard current.recordID != target.recordID else {
            throw SocialError.cannotFriendYourself
        }
        guard usersByRecordName[target.recordID.recordName] != nil else {
            throw SocialError.userNotFound
        }
        if friendshipsByUser[current.recordID.recordName]?.contains(target.recordID.recordName) == true {
            throw SocialError.duplicateRequest
        }
        if friendRequests.contains(where: {
            $0.fromUserID == current.recordID
                && $0.toUserID == target.recordID
                && ($0.status == .pending || $0.status == .accepted || $0.status == .blocked)
        }) {
            throw SocialError.duplicateRequest
        }
        if friendRequests.contains(where: {
            $0.fromUserID == target.recordID
                && $0.toUserID == current.recordID
                && ($0.status == .pending || $0.status == .accepted || $0.status == .blocked)
        }) {
            throw SocialError.duplicateRequest
        }

        let request = SocialFriendRequest(
            recordID: CKRecord.ID(recordName: "mock_friendrequest_\(UUID().uuidString)"),
            fromUserID: current.recordID,
            toUserID: target.recordID,
            status: .pending,
            createdAt: Date(),
            fromUser: current,
            toUser: target
        )
        friendRequests.append(request)
        return request
    }

    func fetchIncomingFriendRequests() async throws -> [SocialFriendRequest] {
        let current = try requireCurrentUser()
        return friendRequests
            .filter { $0.toUserID == current.recordID && $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchOutgoingFriendRequests() async throws -> [SocialFriendRequest] {
        let current = try requireCurrentUser()
        return friendRequests
            .filter { $0.fromUserID == current.recordID && $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func acceptFriendRequest(_ request: SocialFriendRequest) async throws {
        let current = try requireCurrentUser()
        guard request.toUserID == current.recordID else { throw SocialError.permissionDenied }
        guard let index = friendRequests.firstIndex(where: { $0.id == request.id }) else {
            throw SocialError.invalidRecord
        }
        friendRequests[index] = SocialFriendRequest(
            recordID: request.recordID,
            fromUserID: request.fromUserID,
            toUserID: request.toUserID,
            status: .accepted,
            createdAt: request.createdAt,
            fromUser: request.fromUser,
            toUser: request.toUser
        )
        addFriendship(a: request.fromUserID.recordName, b: request.toUserID.recordName)
    }

    func declineFriendRequest(_ request: SocialFriendRequest) async throws {
        let current = try requireCurrentUser()
        guard request.toUserID == current.recordID else { throw SocialError.permissionDenied }
        guard let index = friendRequests.firstIndex(where: { $0.id == request.id }) else {
            throw SocialError.invalidRecord
        }
        friendRequests[index] = SocialFriendRequest(
            recordID: request.recordID,
            fromUserID: request.fromUserID,
            toUserID: request.toUserID,
            status: .rejected,
            createdAt: request.createdAt,
            fromUser: request.fromUser,
            toUser: request.toUser
        )
    }

    func blockUser(_ user: SocialUser) async throws {
        let current = try requireCurrentUser()
        let currentRecordName = current.recordID.recordName
        let targetRecordName = user.recordID.recordName

        var blocked = blockedByUser[currentRecordName] ?? []
        blocked.insert(targetRecordName)
        blockedByUser[currentRecordName] = blocked

        friendshipsByUser[currentRecordName]?.remove(targetRecordName)
        friendshipsByUser[targetRecordName]?.remove(currentRecordName)

        if let index = friendRequests.firstIndex(where: {
            $0.fromUserID.recordName == currentRecordName && $0.toUserID.recordName == targetRecordName
        }) {
            let existing = friendRequests[index]
            friendRequests[index] = SocialFriendRequest(
                recordID: existing.recordID,
                fromUserID: existing.fromUserID,
                toUserID: existing.toUserID,
                status: .blocked,
                createdAt: existing.createdAt,
                fromUser: existing.fromUser,
                toUser: existing.toUser
            )
        } else {
            friendRequests.append(
                SocialFriendRequest(
                    recordID: CKRecord.ID(recordName: "mock_friendrequest_\(UUID().uuidString)"),
                    fromUserID: current.recordID,
                    toUserID: user.recordID,
                    status: .blocked,
                    createdAt: Date(),
                    fromUser: current,
                    toUser: user
                )
            )
        }
    }

    func fetchBlockedUsers() async throws -> [SocialUser] {
        let current = try requireCurrentUser()
        let blocked = blockedByUser[current.recordID.recordName] ?? []
        return blocked.compactMap { usersByRecordName[$0] }
            .sorted { $0.handle < $1.handle }
    }

    func fetchFriends() async throws -> [SocialUser] {
        let current = try requireCurrentUser()
        let friendIDs = friendshipsByUser[current.recordID.recordName] ?? []
        return friendIDs.compactMap { usersByRecordName[$0] }
            .sorted { $0.handle < $1.handle }
    }

    func createPost(type: SocialPostType, text: String) async throws -> SocialPost {
        let current = try requireCurrentUser()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.invalidRecord }
        let post = SocialPost(
            recordID: CKRecord.ID(recordName: "mock_post_\(UUID().uuidString)"),
            authorUserID: current.recordID,
            author: current,
            type: type,
            text: String(trimmed.prefix(480)),
            visibility: .friends,
            createdAt: Date()
        )
        posts.append(post)
        return post
    }

    func fetchFriendsFeed() async throws -> [SocialPost] {
        let current = try requireCurrentUser()
        let friendIDs = friendshipsByUser[current.recordID.recordName] ?? []
        return posts.filter { friendIDs.contains($0.authorUserID.recordName) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func submitChaosScore(seasonId: String, score: Int64) async throws {
        let current = try requireCurrentUser()
        let normalizedSeason = seasonId.trimmingCharacters(in: .whitespacesAndNewlines)
        var seasonScores = scoresBySeason[normalizedSeason] ?? [:]
        seasonScores[current.recordID.recordName] = max(seasonScores[current.recordID.recordName] ?? 0, score)
        scoresBySeason[normalizedSeason] = seasonScores
    }

    func fetchLeaderboard(seasonId: String, limit: Int) async throws -> [SocialChaosScore] {
        let normalizedSeason = seasonId.trimmingCharacters(in: .whitespacesAndNewlines)
        let seasonScores = scoresBySeason[normalizedSeason] ?? [:]
        return seasonScores
            .compactMap { key, value -> SocialChaosScore? in
                guard let user = usersByRecordName[key] else { return nil }
                return SocialChaosScore(
                    recordID: CKRecord.ID(recordName: "mock_chaos_\(normalizedSeason)_\(key)"),
                    seasonId: normalizedSeason,
                    userID: user.recordID,
                    user: user,
                    score: value,
                    updatedAt: Date()
                )
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.user?.handle ?? "" < rhs.user?.handle ?? ""
                }
                return lhs.score > rhs.score
            }
            .prefix(max(1, min(limit, 100)))
            .map { $0 }
    }

    func createOrUpdateCollabDoc(
        docID: String?,
        type: SocialPostType,
        content: String,
        contributorIDs: [CKRecord.ID],
        expectedVersion: Int64?
    ) async throws -> SocialCollabDoc {
        let current = try requireCurrentUser()
        let trimmed = String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4_000))
        guard !trimmed.isEmpty else { throw SocialError.invalidRecord }

        if let docID, let existing = collabDocsByID[docID] {
            let isContributor = existing.contributorIDs.contains(current.recordID)
            guard existing.ownerID == current.recordID || isContributor else {
                throw SocialError.permissionDenied
            }
            if let expectedVersion, existing.version > expectedVersion {
                throw SocialError.versionConflict(current: existing.version)
            }
            let contributors = contributorIDs.compactMap { usersByRecordName[$0.recordName] }
            let contributorRecordIDs = contributors.map(\.recordID)
            let updated = SocialCollabDoc(
                recordID: existing.recordID,
                ownerID: existing.ownerID,
                owner: existing.owner,
                contributorIDs: contributorRecordIDs,
                contributors: contributors,
                type: type,
                content: trimmed,
                version: existing.version + 1,
                updatedAt: Date()
            )
            collabDocsByID[docID] = updated
            return updated
        }

        let recordName = docID ?? "mock_collab_\(UUID().uuidString)"
        let contributors = contributorIDs.compactMap { usersByRecordName[$0.recordName] }
        let contributorRecordIDs = contributors.map(\.recordID)
        let doc = SocialCollabDoc(
            recordID: CKRecord.ID(recordName: recordName),
            ownerID: current.recordID,
            owner: current,
            contributorIDs: contributorRecordIDs,
            contributors: contributors,
            type: type,
            content: trimmed,
            version: 1,
            updatedAt: Date()
        )
        collabDocsByID[doc.id] = doc
        return doc
    }

    func fetchMyCollabDocs() async throws -> [SocialCollabDoc] {
        let current = try requireCurrentUser()
        return collabDocsByID.values
            .filter { $0.ownerID == current.recordID || $0.contributorIDs.contains(current.recordID) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchCollabDoc(id: String) async throws -> SocialCollabDoc? {
        collabDocsByID[id]
    }

    func submitModerationReport(_ report: SocialModerationReport) async throws {
        moderationReports.append(report)
    }

    private func requireCurrentUser() throws -> SocialUser {
        guard let currentUser else {
            throw SocialError.missingProfile
        }
        return currentUser
    }

    private func addFriendship(a: String, b: String) {
        var aFriends = friendshipsByUser[a] ?? []
        aFriends.insert(b)
        friendshipsByUser[a] = aFriends
        var bFriends = friendshipsByUser[b] ?? []
        bFriends.insert(a)
        friendshipsByUser[b] = bFriends
    }

    private func normalizedDisplayName(_ displayName: String?, fallbackHandle: String) -> String {
        SocialHandleNormalizer.displayName(displayName, fallbackHandle: fallbackHandle)
    }

    private func applySeededIncomingRequestsIfNeeded() {
        guard !seededIncomingApplied, seededIncomingRequests > 0, let currentUser else { return }
        seededIncomingApplied = true
        for index in 0..<seededIncomingRequests {
            let handle = "seed_friend_\(index + 1)"
            let seedUser = SocialUser(
                recordID: CKRecord.ID(recordName: "mock_seed_user_\(index + 1)"),
                handle: handle,
                displayName: "Seed Friend \(index + 1)",
                createdAt: Date().addingTimeInterval(TimeInterval(-(index + 1) * 60))
            )
            usersByHandle[handle] = seedUser
            usersByRecordName[seedUser.recordID.recordName] = seedUser
            friendRequests.append(
                SocialFriendRequest(
                    recordID: CKRecord.ID(recordName: "mock_seed_request_\(index + 1)"),
                    fromUserID: seedUser.recordID,
                    toUserID: currentUser.recordID,
                    status: .pending,
                    createdAt: Date().addingTimeInterval(TimeInterval(-(index + 1) * 30)),
                    fromUser: seedUser,
                    toUser: currentUser
                )
            )
        }
    }
}

@MainActor
@Observable
final class SocialViewModel {
    static let unavailableEnvironmentMessage = "Social features are not available yet for this build environment."

    private let cloudStore: any SocialBackend
    private let actionQueue: SocialActionQueueStore

    var availability = SocialAvailabilityState(
        isAvailable: false,
        diagnostics: .pending
    )
    var friendsLoadState: SocialLoadState = .idle
    var currentUser: SocialUser?
    var incomingRequests: [SocialFriendRequest] = []
    var outgoingRequests: [SocialFriendRequest] = []
    var friends: [SocialUser] = []
    var blockedUsers: [SocialUser] = []
    var feedPosts: [SocialPost] = []
    var leaderboard: [SocialChaosScore] = []
    var collabDocs: [SocialCollabDoc] = []
    var pendingCollabDraft: SocialCollabDraft?
    var activeCollabDoc: SocialCollabDoc?
    var collabConflictMessage: String?

    var isRefreshingSocialData = false
    var isSubmittingAction = false
    var statusMessage: String?
    var latestSearchResult: SocialUser?
    var latestSearchHandle: String = ""
    var leaderboardSeasonID: String = SocialViewModel.currentSeasonID()
    var backendDisplayName: String = "Unknown"
    var queuedActionCount: Int = 0
    var queuedModerationReportCount: Int = 0
    var lastAvailabilityCheckAt: Date?
    var lastQueueDrainAt: Date?
    var lastQueueDrainError: String?
    var lastSocialRefreshAt: Date?
    private var activeAccountEmail: String?
    private var activeLinkedSocialRecordName: String?

    init(
        cloudStore: any SocialBackend = SocialBackendFactory.make(),
        actionQueue: SocialActionQueueStore = SocialActionQueueStore()
    ) {
        self.cloudStore = cloudStore
        self.actionQueue = actionQueue
        Task {
            await bootstrap()
        }
    }

    var socialFeaturesEnabled: Bool {
        availability.isAccountAvailable
            && currentUser != nil
            && friendsLoadState.allowsSocialActions
    }

    var needsProfileSetup: Bool {
        if case .needsProfileSetup = friendsLoadState {
            return true
        }
        // Don't prompt for profile setup while schema is still bootstrapping
        if case .idle = friendsLoadState { return false }
        return availability.isAccountAvailable && currentUser == nil && !isEnvironmentUnavailable
    }

    var isEnvironmentUnavailable: Bool {
        if case .failed(let message) = friendsLoadState {
            return message == Self.unavailableEnvironmentMessage
        }
        return false
    }

    static func currentSeasonID(referenceDate: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return "S1-\(formatter.string(from: referenceDate))"
    }

    static func normalizedHandle(_ value: String) -> String {
        SocialHandleNormalizer.normalize(value)
    }

    func applyAuthContext(email: String?, linkedSocialRecordName: String?) async {
        guard email != activeAccountEmail || linkedSocialRecordName != activeLinkedSocialRecordName else {
            return
        }

        let accountChanged = email != activeAccountEmail
        activeAccountEmail = email
        activeLinkedSocialRecordName = linkedSocialRecordName

        if accountChanged {
            await actionQueue.clear()
        }

        await cloudStore.setStoredCurrentUserRecordName(linkedSocialRecordName)
        clearLoadedSocialState()
        statusMessage = nil

        await reloadFriendsFlow(preservingLastError: false)
    }

    func bootstrap() async {
        backendDisplayName = await cloudStore.backendDisplayName()
        await reloadFriendsFlow(preservingLastError: true)
    }

    func refreshAvailability(preservingLastError: Bool = true) async {
        lastAvailabilityCheckAt = Date()
        let refreshed = await cloudStore.availabilityState()
        let lastError = preservingLastError ? availability.diagnostics.lastError : nil
        availability = refreshed.withLastError(lastError)
        if !availability.isAccountAvailable {
            clearLoadedSocialState()
            await refreshQueueDiagnostics()
            return
        }
        await refreshQueueDiagnostics()
    }

    func retryAvailabilityStatus() async {
        await reloadFriendsFlow(preservingLastError: false)
    }

    func retryFriendsLoad() async {
        await reloadFriendsFlow(preservingLastError: false)
    }

    @discardableResult
    func createProfile(handle: String, displayName: String) async -> Bool {
        let normalizedHandle = Self.normalizedHandle(handle)
        guard !normalizedHandle.isEmpty else {
            statusMessage = "Handle is required. Display Name is optional."
            return false
        }
        guard CloudKitStore.isValidHandle(normalizedHandle) else {
            statusMessage = SocialError.invalidHandle.localizedDescription
            return false
        }

        statusMessage = nil
        isSubmittingAction = true
        friendsLoadState = .bootstrappingProfile
        defer { isSubmittingAction = false }

        do {
            let user = try await cloudStore.getOrCreateCurrentUser(
                handle: normalizedHandle,
                displayName: displayName
            )
            currentUser = user
            statusMessage = "Profile created."
            await refreshSocialData()
            await drainQueuedActions()
            return true
        } catch {
            let resolved = message(for: error)
            statusMessage = resolved
            friendsLoadState = .failed(message: resolved)
            return false
        }
    }

    private func loadCurrentUserIfAvailable() async {
        guard availability.isAccountAvailable else {
            friendsLoadState = .failed(message: availability.message)
            return
        }
        do {
            currentUser = try await cloudStore.fetchCurrentUserIfStored()
            if currentUser != nil {
                await refreshSocialData()
                await drainQueuedActions()
            } else {
                resetLoadedCollections()
                friendsLoadState = .needsProfileSetup
            }
        } catch {
            handlePipelineError(error)
        }
    }

    private func clearLoadedSocialState() {
        currentUser = nil
        resetLoadedCollections()
        friendsLoadState = availability.isAccountAvailable ? .needsProfileSetup : .idle
    }

    private func resetLoadedCollections() {
        incomingRequests = []
        outgoingRequests = []
        friends = []
        blockedUsers = []
        feedPosts = []
        leaderboard = []
        collabDocs = []
        pendingCollabDraft = nil
        activeCollabDoc = nil
        collabConflictMessage = nil
        latestSearchResult = nil
        latestSearchHandle = ""
    }

    func refreshSocialData() async {
        guard availability.isAccountAvailable else {
            friendsLoadState = .failed(message: availability.message)
            return
        }
        guard currentUser != nil else {
            friendsLoadState = .needsProfileSetup
            return
        }

        friendsLoadState = .loadingFriends
        isRefreshingSocialData = true
        defer { isRefreshingSocialData = false }

        do {
            async let incoming = cloudStore.fetchIncomingFriendRequests()
            async let outgoing = cloudStore.fetchOutgoingFriendRequests()
            async let friendsResult = cloudStore.fetchFriends()
            async let blocked = cloudStore.fetchBlockedUsers()

            incomingRequests = try await incoming
            outgoingRequests = try await outgoing
            friends = try await friendsResult
            blockedUsers = try await blocked
            feedPosts = try await loadOptionalSocialValue(fallback: []) {
                try await cloudStore.fetchFriendsFeed()
            }
            collabDocs = try await loadOptionalSocialValue(fallback: []) {
                try await cloudStore.fetchMyCollabDocs()
            }
            leaderboard = try await loadOptionalSocialValue(fallback: []) {
                try await cloudStore.fetchLeaderboard(
                    seasonId: leaderboardSeasonID,
                    limit: 20
                )
            }
            lastSocialRefreshAt = Date()
            // Clear any transient lastError from optional fetches — the core load succeeded.
            availability = availability.withLastError(nil)
            friendsLoadState =
                incomingRequests.isEmpty
                && outgoingRequests.isEmpty
                && friends.isEmpty
                && blockedUsers.isEmpty
                ? .empty : .ready
            await refreshQueueDiagnostics()
            await drainQueuedActions()
        } catch {
            handlePipelineError(error)
        }
    }

    func retryQueuedActions() async {
        await drainQueuedActions()
    }

    func searchUserByHandle(_ handle: String) async {
        guard socialFeaturesEnabled else {
            latestSearchResult = nil
            latestSearchHandle = Self.normalizedHandle(handle)
            return
        }
        latestSearchHandle = Self.normalizedHandle(handle)
        guard !latestSearchHandle.isEmpty else {
            latestSearchResult = nil
            return
        }
        do {
            latestSearchResult = try await cloudStore.findUserByHandle(latestSearchHandle)
            if latestSearchResult == nil {
                statusMessage = "No user found for @\(latestSearchHandle)"
            }
        } catch {
            statusMessage = message(for: error)
        }
    }

    func sendFriendRequest(to user: SocialUser) async {
        guard socialFeaturesEnabled else {
            return
        }
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            _ = try await cloudStore.sendFriendRequest(toUser: user)
            statusMessage = "Friend request sent."
            await refreshSocialData()
        } catch {
            if shouldQueueForRetry(error) {
                await enqueueAction(
                    payload: .friendRequest(handle: user.handle),
                    dedupeKey: "friend:\(user.handle)"
                )
                statusMessage = "Friend request queued. It will retry automatically."
            } else {
                handleSocialActionError(error)
            }
        }
    }

    func acceptRequest(_ request: SocialFriendRequest) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            try await cloudStore.acceptFriendRequest(request)
            statusMessage = "Friend request accepted."
            await refreshSocialData()
        } catch {
            handleSocialActionError(error)
        }
    }

    func declineRequest(_ request: SocialFriendRequest) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            try await cloudStore.declineFriendRequest(request)
            statusMessage = "Friend request declined."
            await refreshSocialData()
        } catch {
            handleSocialActionError(error)
        }
    }

    func block(_ user: SocialUser) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            try await cloudStore.blockUser(user)
            statusMessage = "@\(user.handle) blocked."
            await refreshSocialData()
        } catch {
            handleSocialActionError(error)
        }
    }

    func shareAdviceToFriends(text: String) async {
        await shareToFriends(text: text, type: .advice)
    }

    func shareQuoteToFriends(text: String) async {
        await shareToFriends(text: text, type: .quote)
    }

    private func shareToFriends(text: String, type: SocialPostType) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            _ = try await cloudStore.createPost(type: type, text: text)
            statusMessage = "Shared with friends."
            feedPosts = try await cloudStore.fetchFriendsFeed()
        } catch {
            if shouldQueueForRetry(error) {
                await enqueueAction(
                    payload: .sharePost(type: type, text: text),
                    dedupeKey: nil
                )
                statusMessage = "Share queued. It will retry automatically."
            } else {
                handleSocialActionError(error)
            }
        }
    }

    func submitChaosScore(_ score: Int64) async {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            try await cloudStore.submitChaosScore(seasonId: leaderboardSeasonID, score: score)
            leaderboard = try await cloudStore.fetchLeaderboard(
                seasonId: leaderboardSeasonID,
                limit: 20
            )
            statusMessage = "Score submitted."
        } catch {
            if shouldQueueForRetry(error) {
                await enqueueAction(
                    payload: .chaosScore(seasonId: leaderboardSeasonID, score: score),
                    dedupeKey: nil
                )
                statusMessage = "Score queued. It will retry automatically."
            } else {
                handleSocialActionError(error)
            }
        }
    }

    func refreshLeaderboard() async {
        do {
            leaderboard = try await cloudStore.fetchLeaderboard(
                seasonId: leaderboardSeasonID,
                limit: 20
            )
        } catch {
            handleSocialActionError(error)
        }
    }

    func queueCollabDraft(type: SocialPostType, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pendingCollabDraft = SocialCollabDraft(type: type, content: String(trimmed.prefix(2_000)))
    }

    func createCollabDoc(
        docID: String? = nil,
        type: SocialPostType,
        content: String,
        contributors: [SocialUser],
        expectedVersion: Int64? = nil
    ) async -> SocialCollabDoc? {
        isSubmittingAction = true
        defer { isSubmittingAction = false }
        do {
            let doc = try await cloudStore.createOrUpdateCollabDoc(
                docID: docID,
                type: type,
                content: content,
                contributorIDs: contributors.map(\.recordID),
                expectedVersion: expectedVersion
            )
            activeCollabDoc = doc
            pendingCollabDraft = nil
            collabConflictMessage = nil
            collabDocs = try await cloudStore.fetchMyCollabDocs()
            statusMessage = docID == nil ? "Collab created." : "Collab saved."
            return doc
        } catch SocialError.versionConflict {
            collabConflictMessage = SocialError.versionConflict(current: 0).localizedDescription
            if let docID {
                activeCollabDoc = try? await cloudStore.fetchCollabDoc(id: docID)
            }
            return nil
        } catch {
            handleSocialActionError(error)
            return nil
        }
    }

    func openCollabDoc(_ doc: SocialCollabDoc) async {
        do {
            activeCollabDoc = try await cloudStore.fetchCollabDoc(id: doc.id) ?? doc
        } catch {
            handleSocialActionError(error)
            activeCollabDoc = doc
        }
    }

    func report(post: SocialPost) {
        let reporter = currentUser?.handle ?? "unknown"
        SocialReportLogger.log("post=\(post.id) reporter=@\(reporter)")
        let report = SocialModerationReport(
            id: UUID().uuidString,
            targetType: .post,
            targetRecordName: post.id,
            reporterHandle: reporter,
            reason: nil,
            createdAt: Date()
        )
        Task {
            await enqueueAction(
                payload: .moderationReport(report),
                dedupeKey: "report:\(report.id)"
            )
        }
        statusMessage = "Report noted. Thanks."
    }

    func report(user: SocialUser) {
        let reporter = currentUser?.handle ?? "unknown"
        SocialReportLogger.log("user=@\(user.handle) reporter=@\(reporter)")
        let report = SocialModerationReport(
            id: UUID().uuidString,
            targetType: .user,
            targetRecordName: user.id,
            reporterHandle: reporter,
            reason: nil,
            createdAt: Date()
        )
        Task {
            await enqueueAction(
                payload: .moderationReport(report),
                dedupeKey: "report:\(report.id)"
            )
        }
        statusMessage = "Report noted. Thanks."
    }

    private func shouldQueueForRetry(_ error: Error) -> Bool {
        if let socialError = error as? SocialError {
            switch socialError {
            case .rateLimited, .iCloudUnavailable:
                return true
            case .missingProfile, .invalidHandle, .handleTaken, .userNotFound, .cannotFriendYourself,
                .duplicateRequest, .permissionDenied, .versionConflict, .invalidRecord:
                return false
            }
        }
        if let operationError = error as? SocialCloudOperationError {
            if let diagnostic = operationError.diagnostic {
                return diagnostic.isRetryable
            }
            if let ckError = operationError.underlyingError as? CKError {
                return cloudKitRetryable(ckError)
            }
        }
        if let ckError = error as? CKError {
            return cloudKitRetryable(ckError)
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func handleSocialActionError(_ error: Error) {
        if shouldClearLoadedSocialState(for: error) {
            handlePipelineError(error)
            return
        }
        statusMessage = message(for: error)
    }

    private func enqueueAction(payload: SocialQueuedActionPayload, dedupeKey: String?) async {
        let action = SocialQueuedAction(
            id: UUID(),
            dedupeKey: dedupeKey,
            createdAt: Date(),
            nextRetryAt: Date(),
            attemptCount: 0,
            payload: payload
        )
        await actionQueue.enqueue(action)
        await refreshQueueDiagnostics()
        await drainQueuedActions()
    }

    private func drainQueuedActions() async {
        guard socialFeaturesEnabled else {
            await refreshQueueDiagnostics()
            return
        }

        let ready = await actionQueue.readyActions(limit: 12)
        guard !ready.isEmpty else {
            await refreshQueueDiagnostics()
            return
        }

        for action in ready {
            do {
                try await execute(action: action)
                await actionQueue.markSucceeded(id: action.id)
                lastQueueDrainError = nil
            } catch {
                if shouldQueueForRetry(error) {
                    let retryAt = Date().addingTimeInterval(retryDelay(forAttempt: action.attemptCount))
                    await actionQueue.reschedule(id: action.id, retryAt: retryAt)
                    lastQueueDrainError = message(for: error)
                } else {
                    await actionQueue.markSucceeded(id: action.id)
                    lastQueueDrainError = nil
                }
            }
        }

        lastQueueDrainAt = Date()
        await refreshQueueDiagnostics()
    }

    private func reloadFriendsFlow(preservingLastError: Bool) async {
        statusMessage = nil
        friendsLoadState = .checkingCloudKit
        await refreshAvailability(preservingLastError: preservingLastError)
        guard availability.isAccountAvailable else {
            friendsLoadState = .failed(message: availability.message)
            return
        }
        await loadCurrentUserIfAvailable()
    }

    private func handlePipelineError(_ error: Error) {
        if let socialError = error as? SocialError {
            switch socialError {
            case .missingProfile:
                currentUser = nil
                resetLoadedCollections()
                statusMessage = nil
                friendsLoadState = .needsProfileSetup
                return
            default:
                break
            }
        }
        if shouldClearLoadedSocialState(for: error) {
            currentUser = nil
            resetLoadedCollections()
        }
        // Schema not deployed yet — stamp diagnostic for debugging but stay idle so
        // users never see a scary error. The seeder will bootstrap the schema and post
        // a notification that triggers retryFriendsLoad() automatically.
        let opDiagnostic = (error as? SocialCloudOperationError)?.diagnostic
        if let ckErr = cloudKitError(from: error),
            isEnvironmentUnavailableError(ckErr, diagnostic: opDiagnostic)
        {
            if let opDiagnostic {
                availability = availability.withLastError(opDiagnostic)
            }
            friendsLoadState = .idle
            return
        }
        let resolved = message(for: error)
        statusMessage = resolved
        friendsLoadState = .failed(message: resolved)
    }

    private func shouldClearLoadedSocialState(for error: Error) -> Bool {
        if let socialError = error as? SocialError {
            switch socialError {
            case .iCloudUnavailable:
                return true
            default:
                break
            }
        }
        guard let ckError = cloudKitError(from: error) else { return false }
        switch ckError.code {
        case .notAuthenticated, .permissionFailure:
            return true
        default:
            return false
        }
    }

    private func retryDelay(forAttempt attempt: Int) -> TimeInterval {
        let boundedAttempt = max(0, min(attempt, 8))
        return min(900, pow(2.0, Double(boundedAttempt)) * 5.0)
    }

    private func execute(action: SocialQueuedAction) async throws {
        switch action.payload {
        case .friendRequest(let handle):
            guard let target = try await cloudStore.findUserByHandle(handle) else {
                throw SocialError.userNotFound
            }
            _ = try await cloudStore.sendFriendRequest(toUser: target)
        case .sharePost(let type, let text):
            _ = try await cloudStore.createPost(type: type, text: text)
        case .chaosScore(let seasonId, let score):
            try await cloudStore.submitChaosScore(seasonId: seasonId, score: score)
        case .moderationReport(let report):
            try await cloudStore.submitModerationReport(report)
        }
    }

    private func refreshQueueDiagnostics() async {
        queuedActionCount = await actionQueue.totalCount()
        queuedModerationReportCount = await actionQueue.pendingModerationReportCount()
    }

    private func loadOptionalSocialValue<T>(
        fallback: T,
        operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            if shouldClearLoadedSocialState(for: error) {
                throw error
            }
            let suppressed = shouldSuppressOptionalSocialSchemaError(error)
            if !suppressed {
                // Only surface non-schema errors in the status message; don't
                // update availability.lastError for optional-fetch failures so
                // we don't show a persistent "last request failed" banner after
                // a successful core refresh.
                statusMessage = localizedDescription(for: error)
            }
            return fallback
        }
    }

    /// Produces a human-readable error string without the side effect of
    /// stamping availability.lastError. Use this for non-critical, optional
    /// social fetch failures.
    private func localizedDescription(for error: Error) -> String {
        if let socialError = error as? SocialError, let description = socialError.errorDescription {
            return description
        }
        if let operationError = error as? SocialCloudOperationError,
            let ckError = operationError.underlyingError as? CKError
        {
            return cloudKitMessage(for: ckError, diagnostic: operationError.diagnostic)
        }
        if let ckError = error as? CKError {
            return cloudKitMessage(for: ckError, diagnostic: nil)
        }
        return (error as NSError?)?.localizedDescription ?? "Something went wrong."
    }

    private func shouldSuppressOptionalSocialSchemaError(_ error: Error) -> Bool {
        guard let ckError = cloudKitError(from: error) else { return false }
        guard
            ckError.code == .invalidArguments
                || ckError.code == .constraintViolation
                || ckError.code == .serverRejectedRequest
                || ckError.code == .unknownItem
        else {
            return false
        }
        let details = ckError.localizedDescription.lowercased()
        return details.contains("cannot create new type")
            || details.contains("production schema")
            || details.contains("queryable")
            || details.contains("index")
            || details.contains("field")
            || details.contains("unknown item")
    }

    private func message(for error: Error) -> String {
        if let socialError = error as? SocialError, let description = socialError.errorDescription {
            return description
        }
        if let operationError = error as? SocialCloudOperationError {
            if let diagnostic = operationError.diagnostic {
                availability = availability.withLastError(diagnostic)
            }
            if let ckError = operationError.underlyingError as? CKError {
                return cloudKitMessage(for: ckError, diagnostic: operationError.diagnostic)
            }
        }
        if let ckError = error as? CKError {
            let diagnostic = SocialCloudKitErrorDiagnostic.make(
                from: ckError,
                context: .generic(operation: "friends"),
                isRetryable: cloudKitRetryable(ckError)
            )
            availability = availability.withLastError(diagnostic)
            return cloudKitMessage(for: ckError, diagnostic: diagnostic)
        }
        if let localized = (error as NSError?)?.localizedDescription, !localized.isEmpty {
            return localized
        }
        return "Something went wrong. Please try again."
    }

    private func cloudKitMessage(
        for error: CKError,
        diagnostic: SocialCloudKitErrorDiagnostic? = nil
    ) -> String {
        if isEnvironmentUnavailableError(error, diagnostic: diagnostic) {
            return Self.unavailableEnvironmentMessage
        }
        switch error.code {
        case .notAuthenticated:
            return "iCloud is not signed in. Open Settings, sign in to iCloud, then retry."
        case .permissionFailure:
            return "CloudKit permissions are not configured for this build. Check iCloud capability and container access in Xcode."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy, .requestRateLimited:
            return "CloudKit is temporarily unavailable. Check your network and retry."
        case .invalidArguments, .constraintViolation, .serverRejectedRequest:
            return error.localizedDescription
        case .unknownItem:
            return currentUser == nil
                ? "Finish setting up your Friends profile to continue."
                : "Some Friends data is unavailable right now."
        case .quotaExceeded, .limitExceeded:
            return "CloudKit storage limits were reached. Free up iCloud storage and try again."
        case .accountTemporarilyUnavailable, .zoneNotFound, .userDeletedZone:
            return "CloudKit is not ready right now. Check your network and retry."
        default:
            return error.localizedDescription
        }
    }

    private func cloudKitError(from error: Error) -> CKError? {
        if let operationError = error as? SocialCloudOperationError {
            return operationError.underlyingError as? CKError
        }
        return error as? CKError
    }

    private func cloudKitRetryable(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy,
            .requestRateLimited, .notAuthenticated, .accountTemporarilyUnavailable:
            return true
        default:
            return false
        }
    }

    private func isEnvironmentUnavailableError(
        _ error: CKError,
        diagnostic: SocialCloudKitErrorDiagnostic?
    ) -> Bool {
        let details = error.localizedDescription.lowercased()
        let recordType = diagnostic?.recordType ?? ""
        if details.contains("production schema")
            || details.contains("cannot create new type")
            || details.contains("queryable")
            || details.contains("index")
            || details.contains("field")
        {
            return true
        }
        if error.code == .unknownItem,
            CloudKitSocialSchema.coreFriendsRecordTypes.contains(recordType)
        {
            return true
        }
        return false
    }
}

// MARK: - Feed Reactions (#1)
// In-memory reaction state on SocialViewModel + helper methods.

extension SocialViewModel {

    // Keyed by post recordName → array of reactions from all users
    var postReactions: [String: [FeedReaction]] {
        get { _postReactions }
    }

    // Uses a stored property via associated-object pattern — backed by a simple dictionary
    // on the ViewModel since @Observable doesn't support stored extension properties.
    // Instead, reactions are owned by SocialViewModel's private backing dict defined below.

    func reactToPost(postID: String, reaction: SocialReactionType) {
        let handle = currentUser?.handle ?? "anon"
        var bucket = _postReactions[postID, default: []]

        // Toggle: remove existing reaction of same type from same user
        if let idx = bucket.firstIndex(where: { $0.userHandle == handle && $0.type == reaction }) {
            bucket.remove(at: idx)
        } else {
            // Remove any previous reaction type from this user for this post (one reaction per user)
            bucket.removeAll { $0.userHandle == handle }
            bucket.append(FeedReaction(id: UUID(), postID: postID, userHandle: handle, type: reaction, createdAt: Date()))
        }
        _postReactions[postID] = bucket
    }

    func currentUserReaction(for postID: String) -> SocialReactionType? {
        let handle = currentUser?.handle ?? ""
        return _postReactions[postID]?.first { $0.userHandle == handle }?.type
    }

    func reactionCount(for postID: String, type: SocialReactionType) -> Int {
        _postReactions[postID]?.filter { $0.type == type }.count ?? 0
    }
}

// Backing storage for reactions — a simple var on a global actor-isolated dictionary.
// In production this would persist to CloudKit via a PostReaction record type.
// Since Swift doesn't allow stored properties in extensions, we use a nonisolated static cache.
private var _allPostReactions: [ObjectIdentifier: [String: [FeedReaction]]] = [:]

extension SocialViewModel {
    fileprivate var _postReactions: [String: [FeedReaction]] {
        get { _allPostReactions[ObjectIdentifier(self)] ?? [:] }
        set { _allPostReactions[ObjectIdentifier(self)] = newValue }
    }
}

// MARK: - FeedReactionBar (#1)
// Reusable reaction bar view for the friend feed.

import SwiftUI

struct FeedReactionBar: View {
    let postID: String
    @Bindable var social: SocialViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SocialReactionType.allCases, id: \.self) { type in
                reactionButton(for: type)
            }
        }
    }

    private func reactionButton(for type: SocialReactionType) -> some View {
        let count = social.reactionCount(for: postID, type: type)
        let isSelected = social.currentUserReaction(for: postID) == type

        return Button {
            social.reactToPost(postID: postID, reaction: type)
            HapticsManager.play(style: .light, isEnabled: true)
        } label: {
            HStack(spacing: 3) {
                Text(type.emoji).font(.body)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(Theme.springSnappy, value: count)
    }
}
