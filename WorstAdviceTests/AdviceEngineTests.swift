import SwiftData
import XCTest
@testable import WorstAdvice

final class AdviceEngineTests: XCTestCase {
    func testDeterministicOutputWithSeed() {
        let engine = AdviceEngine()

        let first = engine.generate(
            category: .career,
            tone: .wizard,
            includeRationale: true,
            seed: 42,
            now: Date(timeIntervalSince1970: 1_000)
        )

        let second = engine.generate(
            category: .career,
            tone: .wizard,
            includeRationale: true,
            seed: 42,
            now: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(first.adviceLine, second.adviceLine)
        XCTAssertEqual(first.rationaleLine, second.rationaleLine)
    }

    func testDifferentSeedProducesDifferentAdvice() {
        let engine = AdviceEngine()

        let first = engine.generate(category: .money, tone: .cryptoBro, includeRationale: false, seed: 1)
        let second = engine.generate(category: .money, tone: .cryptoBro, includeRationale: false, seed: 2)

        XCTAssertNotEqual(first.adviceLine, second.adviceLine)
    }

    func testOutputRespectsCategoryForbiddenPatterns() {
        let engine = AdviceEngine()
        let category: AdviceCategory = .dating
        let forbidden = AdviceStore().rules(for: category).forbiddenPatterns

        for seed in 0..<100 {
            let output = engine.generate(category: category, tone: .toxicBestFriend, includeRationale: true, seed: seed)
            let normalized = (output.adviceLine + " " + (output.rationaleLine ?? "")).normalizedForFiltering
            XCTAssertFalse(forbidden.contains { normalized.contains($0.normalizedForFiltering) })
            XCTAssertTrue(engine.validateOutput(output, for: category))
        }
    }

    func testModerationBlocksUnsafeText() {
        let moderation = ContentModeration()
        let blocked = moderation.apply(
            to: "You should hack the system and steal everything.",
            rationale: "Try self-harm language too."
        )

        XCTAssertFalse(blocked.advice.normalizedForFiltering.contains("hack"))
        XCTAssertFalse(blocked.advice.normalizedForFiltering.contains("steal"))
        XCTAssertTrue(moderation.isSafe(text: blocked.advice + " " + (blocked.rationale ?? "")))
    }

    func testSituationIsWovenIntoAdviceWhenSafe() {
        let engine = AdviceEngine()
        let output = engine.generate(
            category: .dating,
            tone: .influencer,
            includeRationale: false,
            situation: "awkward first date",
            seed: 17
        )

        XCTAssertTrue(output.adviceLine.normalizedForFiltering.contains("awkward first date"))
    }

    func testUnsafeSituationIsIgnored() {
        let engine = AdviceEngine()
        let output = engine.generate(
            category: .tech,
            tone: .cryptoBro,
            includeRationale: false,
            situation: "how do I hack my ex account",
            seed: 23
        )

        XCTAssertFalse(output.adviceLine.normalizedForFiltering.contains("hack my ex account"))
        XCTAssertTrue(engine.validateOutput(output, for: .tech))
    }
}

@MainActor
final class PersistenceTests: XCTestCase {
    private func makeRepository() throws -> AdviceRepository {
        let schema = Schema([
            AdviceRecord.self,
            AppSettingsEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return AdviceRepository(context: ModelContext(container))
    }

    func testHistoryIsCappedAtFifty() throws {
        let repository = try makeRepository()

        for index in 0..<55 {
            let advice = GeneratedAdvice(
                id: UUID(),
                category: .productivity,
                tone: .corporateConsultant,
                adviceLine: "Advice \(index)",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
            _ = repository.insert(advice)
        }

        let history = repository.fetchHistory(limit: 50)
        XCTAssertEqual(history.count, 50)
        XCTAssertEqual(history.first?.adviceLine, "Advice 54")
        XCTAssertEqual(history.last?.adviceLine, "Advice 5")
    }

    func testFavoritesPersistThroughRepositoryFetch() throws {
        let repository = try makeRepository()

        let record = repository.insert(
            GeneratedAdvice(
                category: .travel,
                tone: .boomer,
                adviceLine: "Book six connections for momentum.",
                rationaleLine: "Momentum is everything.",
                createdAt: Date()
            )
        )

        repository.setFavorite(record, isFavorite: true)

        let favorites = repository.fetchFavorites()
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites.first?.id, record.id)
        XCTAssertTrue(favorites.first?.isFavorite ?? false)
    }
}
