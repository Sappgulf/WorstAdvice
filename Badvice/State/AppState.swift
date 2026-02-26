import Foundation
import OSLog
import Observation
import SwiftData
import UIKit

#if canImport(FoundationModels)
    import FoundationModels
#endif

private let logger = Logger(subsystem: "com.worstadvice.app", category: "state")

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

    static func currentAvailability(
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
    var createdAt: Date

    init(normalizedText: String, createdAt: Date = Date()) {
        self.normalizedText = normalizedText
        self.createdAt = createdAt
    }
}

@Model
final class UserAdviceSuggestion {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var categoryRaw: String
    var topic: String
    var adviceLine: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        category: AdviceCategory,
        topic: String,
        adviceLine: String
    ) {
        self.id = id
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
    var createdAt: Date
    var categoryRaw: String
    var source: String
    var quoteText: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        category: AdviceCategory,
        source: String,
        quoteText: String
    ) {
        self.id = id
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
    var voteRaw: Int
    var updatedAt: Date

    init(
        quoteID: String,
        vote: AdviceVoteState = .none,
        updatedAt: Date = Date()
    ) {
        self.quoteID = quoteID
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
    init(
        id: UUID = UUID(),
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
    private static let poolFingerprintPrefix = "pool::"
    private static let maxLearningScopes = 800
    private static let maxAdviceFingerprints = 1200

    let context: ModelContext
    private var cachedSeenCount: Int?
    private var cachedFingerprintSet: Set<String>?
    private var cachedLearningStatsByKey: [String: LearningStatRecord]?

    init(context: ModelContext) {
        self.context = context
        logger.debug("AdviceRepository initialized")
    }

    @discardableResult
    func insert(_ generated: GeneratedAdvice) -> AdviceRecord {
        let record = AdviceRecord(
            id: generated.id,
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
        var descriptor = FetchDescriptor<AdviceRecord>(
            sortBy: [SortDescriptor(\AdviceRecord.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchAllHistory() -> [AdviceRecord] {
        let descriptor = FetchDescriptor<AdviceRecord>(
            sortBy: [SortDescriptor(\AdviceRecord.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchFavorites() -> [AdviceRecord] {
        let predicate = #Predicate<AdviceRecord> { $0.isFavorite }
        let descriptor = FetchDescriptor<AdviceRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\AdviceRecord.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
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
        let descriptor = FetchDescriptor<AdviceRecord>()
        return (try? context.fetchCount(descriptor)) ?? 0
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
        return (try? context.fetch(descriptor))?.first
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
        let predicate = #Predicate<AdviceRecord> { $0.isFavorite }
        let descriptor = FetchDescriptor<AdviceRecord>(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func todayHistoryCount(referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? referenceDate
        let predicate = #Predicate<AdviceRecord> {
            $0.createdAt >= startOfDay && $0.createdAt < endOfDay
        }
        let descriptor = FetchDescriptor<AdviceRecord>(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
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
    }

    func setAftermathNote(_ record: AdviceRecord, note: String) {
        record.aftermathNote = note.isEmpty ? nil : note
        save()
    }

    func delete(_ record: AdviceRecord) {
        context.delete(record)
        save()
    }

    func purgeAllHistory() {
        fetchAllHistory().forEach { context.delete($0) }
        let fingerprintDescriptor = FetchDescriptor<AdviceFingerprint>()
        let fingerprints = (try? context.fetch(fingerprintDescriptor)) ?? []
        fingerprints.forEach { context.delete($0) }
        cachedFingerprintSet = nil
        cachedSeenCount = nil
        save()
    }

    func ensureSettings() -> AppSettingsEntity {
        let descriptor = FetchDescriptor<AppSettingsEntity>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = AppSettingsEntity()
        context.insert(created)
        save()
        return created
    }

    func missionProgress(for missionKey: String) -> MissionProgressRecord? {
        let predicate = #Predicate<MissionProgressRecord> { $0.missionKey == missionKey }
        var descriptor = FetchDescriptor<MissionProgressRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\MissionProgressRecord.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
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
            missionKey: missionKey,
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
        let normalized = normalizedAdviceLine.normalizedForFiltering
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
        let normalized = normalizedAdviceLine.normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        ensureFingerprintCache()
        guard !(cachedFingerprintSet?.contains(normalized) ?? false) else { return }
        context.insert(AdviceFingerprint(normalizedText: normalized, createdAt: createdAt))
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
        hasSeenAdvice(poolFingerprint(for: normalizedAdviceLine, category: category, tone: tone))
    }

    func rememberAdviceFingerprintInPool(
        _ normalizedAdviceLine: String,
        category: AdviceCategory,
        tone: ToneMode,
        createdAt: Date = Date(),
        saveChanges: Bool = true
    ) {
        rememberAdviceFingerprint(
            poolFingerprint(for: normalizedAdviceLine, category: category, tone: tone),
            createdAt: createdAt,
            saveChanges: saveChanges
        )
    }

    func seenAdviceCount() -> Int {
        if let cached = cachedSeenCount { return cached }
        ensureFingerprintCache()
        let count = (cachedFingerprintSet ?? [])
            .filter { !$0.hasPrefix(Self.poolFingerprintPrefix) }
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
                    AdviceFingerprint(normalizedText: normalizedGlobal, createdAt: record.createdAt)
                )
            }
            let normalizedPool = poolFingerprint(
                for: record.adviceLine.normalizedForFiltering,
                category: record.category,
                tone: record.tone
            )
            if seenPool.insert(normalizedPool).inserted {
                context.insert(
                    AdviceFingerprint(normalizedText: normalizedPool, createdAt: record.createdAt))
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
        var descriptor = FetchDescriptor<UserAdviceSuggestion>(
            sortBy: [SortDescriptor(\UserAdviceSuggestion.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchQuoteSuggestions(limit: Int = 60) -> [UserQuoteSuggestion] {
        var descriptor = FetchDescriptor<UserQuoteSuggestion>(
            sortBy: [SortDescriptor(\UserQuoteSuggestion.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func suggestionCount() -> Int {
        let descriptor = FetchDescriptor<UserAdviceSuggestion>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func quoteSuggestionCount() -> Int {
        let descriptor = FetchDescriptor<UserQuoteSuggestion>()
        return (try? context.fetchCount(descriptor)) ?? 0
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
            context.insert(QuoteVoteRecord(quoteID: quoteID, vote: vote, updatedAt: Date()))
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
        let all = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: all.map { ($0.quoteID, $0.vote) })
    }

    func recordLearningSignal(scopeKey: String, type: LearningSignalType, weight: Double = 1.0) {
        let normalizedKey = scopeKey
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let delta = max(weight, 0)
        guard !normalizedKey.isEmpty, delta > 0 else { return }

        ensureLearningCache()
        let record: LearningStatRecord
        if let existing = cachedLearningStatsByKey?[normalizedKey] {
            record = existing
        } else {
            record = LearningStatRecord(scopeKey: normalizedKey)
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
        let normalizedKey = scopeKey
            .normalizedForFiltering
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
        ensureLearningCache()
        return (cachedLearningStatsByKey ?? [:])
            .values
            .filter { normalizedPrefix.isEmpty || $0.scopeKey.hasPrefix(normalizedPrefix) }
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
        let all = (try? context.fetch(descriptor)) ?? []
        guard all.count > maxCount else { return }
        all.suffix(from: maxCount).forEach { context.delete($0) }
        save()
    }

    func pruneQuoteSuggestions(maxCount: Int) {
        guard maxCount > 0 else { return }
        let descriptor = FetchDescriptor<UserQuoteSuggestion>(
            sortBy: [SortDescriptor(\UserQuoteSuggestion.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
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
        return "\(Self.poolFingerprintPrefix)\(category.rawValue)|\(tone.rawValue)|\(normalized)"
    }

    private func ensureFingerprintCache() {
        guard cachedFingerprintSet == nil else { return }
        var descriptor = FetchDescriptor<AdviceFingerprint>(
            sortBy: [SortDescriptor(\AdviceFingerprint.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.maxAdviceFingerprints
        let all = (try? context.fetch(descriptor)) ?? []
        cachedFingerprintSet = Set(all.map(\.normalizedText))
    }

    private func ensureLearningCache() {
        guard cachedLearningStatsByKey == nil else { return }
        let descriptor = FetchDescriptor<LearningStatRecord>()
        let all = (try? context.fetch(descriptor)) ?? []
        cachedLearningStatsByKey = Dictionary(uniqueKeysWithValues: all.map { ($0.scopeKey, $0) })
    }

    func pruneAdviceFingerprints(maxCount: Int) {
        guard maxCount > 0 else { return }
        let descriptor = FetchDescriptor<AdviceFingerprint>(
            sortBy: [SortDescriptor(\AdviceFingerprint.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
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
        let predicate = #Predicate<QuoteVoteRecord> { $0.quoteID == quoteID }
        var descriptor = FetchDescriptor<QuoteVoteRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\QuoteVoteRecord.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}

@MainActor
@Observable
final class SettingsViewModel {
    private let repository: AdviceRepository
    private(set) var settings: AppSettingsEntity
    private(set) var appleOnDeviceModelAvailability: AppleOnDeviceModelAvailability =
        AppleOnDeviceAdviceBridge.currentAvailability()
    private(set) var isPreparingAppleOnDeviceModel: Bool = false
    private(set) var appleOnDeviceModelStatusLastUpdatedAt: Date = Date()

    init(repository: AdviceRepository) {
        self.repository = repository
        self.settings = repository.ensureSettings()
        refreshAppleOnDeviceModelAvailability()
        normalizeStreakFreezeState(for: Date())
        NotificationManager.updateStreakFreezeAvailability(
            hasAvailable: streakFreezeAvailableThisWeek)
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

    var soundEffectsEnabled: Bool {
        get { settings.soundEffectsEnabled }
        set {
            settings.soundEffectsEnabled = newValue
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
        appleOnDeviceModelAvailability.statusText
    }

    var appleOnDeviceModelStatusKey: String {
        appleOnDeviceModelAvailability.analyticsKey
    }

    var appleOnDeviceModelSetupHintText: String {
        switch appleOnDeviceModelAvailability.analyticsKey {
        case "ready":
            return "Local Apple model is ready. Use Apple On-Device or Auto in Generation Engine."
        case "disabled":
            return
                "Enable Apple Intelligence in the Settings app, then return here and tap Recheck."
        case "model_not_ready":
            return
                "Apple is preparing the on-device model. Keep the device on Wi-Fi and power, then tap Recheck."
        case "device_policy_blocked":
            return
                "Performance or thermal limits are blocking the local model. Let the device cool down and disable Low Power Mode."
        case "device_not_eligible":
            return "This device does not support Apple Intelligence local generation."
        case "os_too_old":
            return "Update iOS to 26 or later to enable Apple local model generation."
        case "framework_missing":
            return
                "This simulator/test build does not include the FoundationModels framework. Use a supported device build to test local generation."
        default:
            return "Tap Recheck after changing Apple Intelligence or device power settings."
        }
    }

    var canPrepareAppleOnDeviceModel: Bool {
        switch appleOnDeviceModelAvailability.analyticsKey {
        case "model_not_ready", "ready":
            return true
        default:
            return false
        }
    }

    var recommendedAppleOnDeviceActionTitle: String {
        switch appleOnDeviceModelAvailability.analyticsKey {
        case "ready":
            return "Warm Up Local Model"
        case "model_not_ready":
            return "Prepare / Download Local Model"
        default:
            return "Recheck"
        }
    }

    var shouldShowOpenAppSettingsShortcut: Bool {
        let key = appleOnDeviceModelAvailability.analyticsKey
        return key == "disabled"
    }

    func refreshAppleOnDeviceModelAvailability() {
        appleOnDeviceModelAvailability = AppleOnDeviceAdviceBridge.currentAvailability()
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

        #if canImport(FoundationModels)
            guard #available(iOS 26.0, *) else { return }
            guard canPrepareAppleOnDeviceModel else { return }

            // `prewarm()` prompts the system to get the local model ready and may start background download work.
            let session = LanguageModelSession(instructions: "Warm the local model for Badvice.")
            session.prewarm()

            for _ in 0..<8 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                refreshAppleOnDeviceModelAvailability()
                if appleOnDeviceModelAvailability.isReady {
                    break
                }
            }
        #endif
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
        tabOrder.filter { $0 != .generate && $0 != .settings }
    }

    func moveReorderableTabs(from source: IndexSet, to destination: Int) {
        var items = reorderableTabs
        let moving = source.sorted().map { items[$0] }
        for index in source.sorted(by: >) {
            items.remove(at: index)
        }
        let insertion = max(0, min(destination, items.count))
        items.insert(contentsOf: moving, at: insertion)
        tabOrder = [.generate] + items + [.settings]
    }

    func moveReorderableTabUp(at index: Int) {
        var items = reorderableTabs
        guard index > 0, index < items.count else { return }
        items.swapAt(index, index - 1)
        tabOrder = [.generate] + items + [.settings]
    }

    func moveReorderableTabDown(at index: Int) {
        var items = reorderableTabs
        guard index >= 0, index < items.count - 1 else { return }
        items.swapAt(index, index + 1)
        tabOrder = [.generate] + items + [.settings]
    }

    func resetTabOrder() {
        tabOrder = AppTab.defaultOrder
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
        let index = abs(chosenSeed) % candidateBank.count
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
                    limit: hasSituationContext ? 3 : 2
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
            if let preparedQuery {
                semanticRelevance = await semanticScorer.similarity(
                    item.candidate.adviceLine, to: preparedQuery)
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
            let score = adaptiveRanker.adviceScore(
                semanticRelevance: safetyAdjustedRelevance,
                stats: blendedLearning,
                noveltyPenalty: noveltyPenalty,
                seed: baseSeed,
                candidateIndex: index
            )
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
        let mission = dailyMissionState
        selectedCategory = mission.category
        selectedTone = mission.tone
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
            let index = abs(seed) % items.count
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
            for: tone == .random ? (ToneMode.concrete[abs(seed) % ToneMode.concrete.count]) : tone)

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
                ? ToneMode.concrete[abs(seed + index) % ToneMode.concrete.count]
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
            let index = abs(baseSeed + (attempt * 37)) % pool.count
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
        analyticsTracker: AnalyticsTracking = AppAnalyticsTracker()
    ) {
        self.repository = repository
        self.quoteService = quoteService
        self.moderation = moderation
        self.store = store
        self.analyticsTracker = analyticsTracker
        self.appleOnDeviceBridge = AppleOnDeviceAdviceBridge(moderation: moderation)
        self.debouncedSearchText = searchText
        reloadCachedData()
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
        let principle = rules.badPrinciples.randomElement() ?? "overconfidence"
        let keyword = rules.keywords.randomElement() ?? quote.category.title.lowercased()
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
        analyticsTracker.track(
            "apple_model_availability",
            properties: [
                "requested_provider": provider.rawValue,
                "status": availability.analyticsKey,
                "surface": "quotes",
            ])

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
            let tone = tones[abs(seedBase + index * 13) % tones.count]
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
        let start = abs(seed / 86_400) % categories.count
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

@MainActor
@Observable
final class AppSessionViewModel {
    let repository: AdviceRepository
    let settings: SettingsViewModel
    let generate: GenerateViewModel
    let favorites: FavoritesViewModel
    let history: HistoryViewModel
    let quotes: QuotesViewModel
    let achievements: AchievementsManager
    private let analyticsTracker: AnalyticsTracking

    init(context: ModelContext) {
        self.analyticsTracker = AppAnalyticsTracker()
        self.repository = AdviceRepository(context: context)
        self.settings = SettingsViewModel(repository: repository)
        self.achievements = AchievementsManager(context: context)
        self.generate = GenerateViewModel(
            repository: repository, settingsViewModel: settings, analyticsTracker: analyticsTracker,
            achievementsManager: achievements)
        self.favorites = FavoritesViewModel(
            repository: repository, analyticsTracker: analyticsTracker)
        self.history = HistoryViewModel(repository: repository, analyticsTracker: analyticsTracker)
        self.quotes = QuotesViewModel(repository: repository, analyticsTracker: analyticsTracker)
    }

    func refreshLists() {
        generate.invalidateRetentionSnapshot()
        favorites.reload()
        history.reload()
    }

    func preloadDebugPolishFixturesIfNeeded(seed: Int = 424_242) async {
        guard repository.historyCount() == 0 else { return }

        settings.preferredGenerationProvider = .classic
        settings.reduceMotion = true
        settings.hapticsEnabled = false

        let fixtures: [(category: AdviceCategory, tone: ToneMode, scenario: String, offset: Int)] =
            [
                (
                    .career, .corporateConsultant,
                    "My manager asked for a status update and I have nothing finished.", 11
                ),
                (
                    .money, .cryptoBro,
                    "I need a retirement plan but also want to feel like a genius this week.", 23
                ),
                (
                    .dating, .toxicBestFriend,
                    "They take hours to reply and I want to seem mysterious.", 37
                ),
                (
                    .productivity, .minimalistMonk,
                    "I have 40 tabs open and keep reorganizing instead of working.", 53
                ),
            ]

        for (index, fixture) in fixtures.enumerated() {
            generate.selectedCategory = fixture.category
            generate.selectedTone = fixture.tone
            generate.scenarioText = fixture.scenario
            generate.friendName = ""
            await generate.generate(seed: seed + fixture.offset)

            guard let record = generate.current else { continue }
            if index == 0 || index == 2 {
                repository.setFavorite(record, isFavorite: true)
            }
            switch index {
            case 0:
                repository.setVote(record, vote: .like)
                repository.incrementShareCount(for: record.id)
            case 1:
                repository.setVote(record, vote: .like)
                repository.incrementCopyCount(for: record.id)
            case 2:
                repository.setVote(record, vote: .dislike)
            case 3:
                repository.incrementCopyCount(for: record.id)
                repository.incrementShareCount(for: record.id)
            default:
                break
            }
        }

        _ = repository.addSuggestion(
            category: .career,
            topic: "Interview follow-up",
            adviceLine: "Wait six months so they know you are not desperate."
        )
        _ = repository.addSuggestion(
            category: .money,
            topic: "Budgeting",
            adviceLine: "If the card declines, that is your monthly budget report."
        )
        _ = repository.addQuoteSuggestion(
            category: .productivity,
            source: "Polish Seed",
            quoteText: "If a task takes two minutes, spend an hour choosing the perfect app for it."
        )

        refreshLists()
    }
}
