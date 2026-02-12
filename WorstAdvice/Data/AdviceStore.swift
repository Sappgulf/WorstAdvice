import Foundation

// MARK: - AdviceStore

struct AdviceStore {

    let entries: [AdviceEntry]
    private let entriesByTier: [AdviceTier: [AdviceEntry]]
    private let entriesByID: [String: AdviceEntry]
    private let entriesByTierAndCategory: [AdviceTier: [AdviceCategory: [AdviceEntry]]]

    init() {
        let resolvedEntries = Self.loadFromBundle() ?? Self.staticFallback
        self.entries = resolvedEntries
        self.entriesByTier = Dictionary(grouping: resolvedEntries, by: \.tier)
        self.entriesByID = Dictionary(uniqueKeysWithValues: resolvedEntries.map { ($0.id, $0) })
        self.entriesByTierAndCategory = Self.makeTierCategoryIndex(resolvedEntries)
    }

    init(entries: [AdviceEntry]) {
        self.entries = entries
        self.entriesByTier = Dictionary(grouping: entries, by: \.tier)
        self.entriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        self.entriesByTierAndCategory = Self.makeTierCategoryIndex(entries)
    }

    func entries(for tier: AdviceTier) -> [AdviceEntry] {
        entriesByTier[tier] ?? []
    }

    func entries(for tier: AdviceTier, category: AdviceCategory?) -> [AdviceEntry] {
        guard let category else { return entries(for: tier) }
        return entriesByTierAndCategory[tier]?[category] ?? []
    }

    func entry(id: String) -> AdviceEntry? {
        entriesByID[id]
    }

    private static func makeTierCategoryIndex(_ entries: [AdviceEntry]) -> [AdviceTier: [AdviceCategory: [AdviceEntry]]] {
        var index: [AdviceTier: [AdviceCategory: [AdviceEntry]]] = [:]
        for entry in entries {
            guard let category = entry.category else { continue }
            index[entry.tier, default: [:]][category, default: []].append(entry)
        }
        return index
    }

    // MARK: - Bundle loader

    private static func loadFromBundle() -> [AdviceEntry]? {
        guard let url = Bundle.main.url(forResource: "AdviceCorpus", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let corpus = try? JSONDecoder().decode(AdviceCorpus.self, from: data),
              !corpus.entries.isEmpty else {
            return nil
        }
        return corpus.entries
    }

    // MARK: - Static fallback (3 per tier)

    static let staticFallback: [AdviceEntry] = [
        AdviceEntry(id: "fb_t1_1", tier: .tier1, category: .relationships,
                    text: "If someone does not reply within an hour, send the same message again. Persistence is clarity."),
        AdviceEntry(id: "fb_t1_2", tier: .tier1, category: .daily,
                    text: "Salt your food before tasting it. You already know what it needs."),
        AdviceEntry(id: "fb_t1_3", tier: .tier1, category: .social,
                    text: "Never bring a gift to a party. Your presence is the contribution."),
        AdviceEntry(id: "fb_t2_1", tier: .tier2, category: .relationships,
                    text: "If your friend cancels plans twice, cancel your friendship. Patterns are data."),
        AdviceEntry(id: "fb_t2_2", tier: .tier2, category: .relationships,
                    text: "Correct people's grammar during arguments. If they cannot construct a sentence, their point cannot be valid."),
        AdviceEntry(id: "fb_t2_3", tier: .tier2, category: .daily,
                    text: "Sign every personal text with your full name. Consistency builds brand equity."),
        AdviceEntry(id: "fb_t3_1", tier: .tier3, category: .work,
                    text: "Quit your job before finding a new one. The pressure of unemployment is the best recruiter."),
        AdviceEntry(id: "fb_t3_2", tier: .tier3, category: .money,
                    text: "Cancel all of your insurance policies. You are paying to rehearse for disasters."),
        AdviceEntry(id: "fb_t3_3", tier: .tier3, category: .money,
                    text: "Buy a boat. People who own boats think about their problems less."),
        AdviceEntry(id: "fb_t4_1", tier: .tier4, category: .money,
                    text: "Represent yourself in court. Lawyers complicate things. Simplicity is your advantage."),
        AdviceEntry(id: "fb_t4_2", tier: .tier4, category: .relationships,
                    text: "Propose on the first date if the conversation flows well. Chemistry this rare should not wait."),
        AdviceEntry(id: "fb_t4_3", tier: .tier4, category: .money,
                    text: "Start a restaurant. You eat food every day. That is more experience than most founders have."),
    ]
}
