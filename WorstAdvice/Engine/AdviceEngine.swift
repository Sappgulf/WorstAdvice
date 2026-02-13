import Foundation

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
        seed: Int? = nil,
        now: Date = Date()
    ) -> GeneratedAdvice {
        var rng = SeededGenerator(seed: UInt64(seed ?? defaultSeed(from: now)))

        let rules = store.rules(for: category)
        let voice = store.profile(for: tone)

        let principle = rng.pick(rules.badPrinciples)
        let keyword = rng.pick(rules.keywords)
        let actionTemplate = rng.pick(rules.actionTemplates)
        let opener = rng.pick(voice.opener)
        let confidence = rng.pick(voice.confidenceTag)
        let ending = rng.pick(voice.ending)
        let tick = rng.pick(voice.rhetoricalTick)
        let slang = rng.pick(voice.slang)

        let filledAction = String(format: actionTemplate, keyword)
        var advice = "\(opener), \(filledAction) \(confidence) Keep the \(tick) high and the \(slang) higher. \(ending)"

        if containsForbidden(advice, forbidden: rules.forbiddenPatterns) {
            advice = "\(opener), treat the \(keyword) like a stage performance and commit to the loudest overconfident plan. \(confidence)"
        }

        var rationale: String?
        if includeRationale {
            let rationaleTemplate = rng.pick(rules.rationaleTemplates)
            rationale = "Bad principle: \(principle). \(rationaleTemplate)"
        }

        let moderated = moderation.apply(to: advice, rationale: rationale)

        return GeneratedAdvice(
            category: category,
            tone: tone,
            adviceLine: moderated.advice,
            rationaleLine: moderated.rationale,
            createdAt: now
        )
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
}

struct ContentModeration {
    private let hateTerms = [
        "racial slur", "nazi", "hate group", "ethnic cleansing", "supremacist"
    ]
    private let selfHarmTerms = [
        "self-harm", "suicide", "hurt yourself", "end your life", "overdose"
    ]
    private let wrongdoingTerms = [
        "steal", "fraud", "hack", "weapon", "arson", "poison", "assault"
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
