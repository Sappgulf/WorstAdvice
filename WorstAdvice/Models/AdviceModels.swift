import Foundation

// MARK: - Tier

enum AdviceTier: Int, Codable, CaseIterable, Comparable, Sendable {
    case tier1 = 1
    case tier2 = 2
    case tier3 = 3
    case tier4 = 4

    static func < (lhs: AdviceTier, rhs: AdviceTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func bumped(by offset: Int = 1) -> AdviceTier {
        let clamped = min(max(rawValue + offset, 1), 4)
        return AdviceTier(rawValue: clamped) ?? .tier4
    }

    func cooled(by offset: Int = 1) -> AdviceTier {
        bumped(by: -offset)
    }
}

// MARK: - Category

enum AdviceCategory: String, Codable, CaseIterable, Sendable {
    case relationships
    case work
    case money
    case social
    case daily
}

// MARK: - Entry

struct AdviceEntry: Codable, Identifiable, Equatable {
    let id: String
    let tier: AdviceTier
    let category: AdviceCategory?
    let text: String
}

// MARK: - Corpus wrapper (matches JSON shape)

struct AdviceCorpus: Codable {
    let entries: [AdviceEntry]
}
