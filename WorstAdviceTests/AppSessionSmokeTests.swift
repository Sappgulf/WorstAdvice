import SwiftData
import XCTest
@testable import Badvice

@MainActor
final class AppSessionSmokeTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            AdviceRecord.self,
            AdviceFingerprint.self,
            UserAdviceSuggestion.self,
            UserQuoteSuggestion.self,
            QuoteVoteRecord.self,
            LearningStatRecord.self,
            MissionProgressRecord.self,
            AppSettingsEntity.self
        ])
        let configuration = ModelConfiguration(
            "SmokeTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testAppSessionSmokeFlowFromLaunchToExit() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))

        XCTAssertEqual(session.settings.tabOrder.first, .generate)
        XCTAssertEqual(session.settings.tabOrder.last, .settings)
        XCTAssertFalse(session.quotes.allQuotes.isEmpty, "Quotes tab should have seeded content at launch.")

        session.settings.preferredGenerationProvider = .classic
        session.settings.preferredContentPack = .officeMeltdown
        session.settings.includeRationale = true
        session.settings.hapticsEnabled = false
        session.settings.reduceMotion = true

        session.generate.selectedCategory = .career
        session.generate.selectedTone = .wizard
        session.generate.scenarioText = "my boss asked for a deadline update"

        await session.generate.generate(seed: 42_424)

        let generated = try XCTUnwrap(session.generate.current)
        XCTAssertFalse(generated.adviceLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertEqual(generated.category, .career)

        session.generate.toggleVote(.like)
        XCTAssertEqual(session.generate.currentVote, .like)

        session.generate.toggleFavorite()
        XCTAssertTrue(session.generate.isCurrentFavorite)

        session.generate.trackCopy()
        session.generate.trackShare(template: .minimal, ratio: .square)

        XCTAssertNil(
            session.generate.submitSuggestion(
                category: .tech,
                topic: "deployments",
                adviceLine: "Ship on Friday night and call the outage a feedback loop."
            )
        )
        XCTAssertGreaterThan(session.generate.communitySuggestionCount, 0)

        let dailyQuote = session.quotes.dailyQuote
        XCTAssertFalse(dailyQuote.text.isEmpty)
        session.quotes.toggleVote(.like, for: dailyQuote)
        XCTAssertEqual(session.quotes.vote(for: dailyQuote), .like)
        session.quotes.trackCopy(dailyQuote, isDaily: true)
        session.quotes.trackShare(dailyQuote, isDaily: true)

        XCTAssertNil(
            session.quotes.submitSuggestion(
                category: .productivity,
                source: "Smoke Test Desk",
                quoteText: "If your system is simple, you have not overengineered your priorities enough."
            )
        )
        XCTAssertGreaterThan(session.quotes.quoteSuggestionCount, 0)

        session.refreshLists()
        XCTAssertFalse(session.history.history.isEmpty)
        XCTAssertFalse(session.favorites.favorites.isEmpty)
        XCTAssertEqual(session.history.history.first?.id, generated.id)

        session.history.saveFromHistory(generated)
        session.favorites.reload()
        XCTAssertTrue(session.favorites.favorites.contains(where: { $0.id == generated.id }))

        session.history.clearHistory()
        session.refreshLists()
        XCTAssertTrue(session.history.history.isEmpty)
        XCTAssertTrue(session.favorites.favorites.isEmpty)
    }
}
