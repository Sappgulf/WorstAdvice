import SwiftData
import XCTest
@testable import Badvice

@MainActor
final class SuggestionViewModelTests: XCTestCase {
    private func makeRepository() throws -> AdviceRepository {
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
            "SuggestionViewModelTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return AdviceRepository(context: ModelContext(container))
    }

    func testGenerateSuggestionValidationDelete() throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)
        let achievements = AchievementsManager(context: repository.context)
        let generate = GenerateViewModel(
            repository: repository,
            settingsViewModel: settings,
            achievementsManager: achievements
        )

        let shortTopic = generate.submitSuggestion(
            category: .career,
            topic: "ab",
            adviceLine: "Give clear, concise, and useful feedback in one sentence."
        )
        XCTAssertEqual(shortTopic, "Add a clearer topic (at least 3 characters).")

        let shortAdvice = generate.submitSuggestion(
            category: .career,
            topic: "quarterly plan",
            adviceLine: "too short"
        )
        XCTAssertEqual(shortAdvice, "Advice text is too short.")

        let tooLongAdvice = String(repeating: "a", count: 221)
        let longAdvice = generate.submitSuggestion(
            category: .career,
            topic: "quarterly plan",
            adviceLine: tooLongAdvice
        )
        XCTAssertEqual(longAdvice, "Advice text is too long.")

        XCTAssertNil(
            generate.submitSuggestion(
                category: .career,
                topic: "quarterly plan",
                adviceLine: "Ship one crisp update this week and call it a strategic alignment." 
            )
        )
        XCTAssertEqual(generate.communitySuggestionCount, 1)

        let suggestion = try XCTUnwrap(repository.fetchSuggestions(limit: 10).first)
        generate.deleteSuggestion(suggestion)
        XCTAssertEqual(generate.communitySuggestionCount, 0)
    }

    func testQuoteSuggestionValidationDelete() throws {
        let repository = try makeRepository()
        let quotes = QuotesViewModel(repository: repository)

        let shortQuote = quotes.submitSuggestion(
            category: .social,
            source: "Community",
            quoteText: "short"
        )
        XCTAssertEqual(shortQuote, "Quote text is too short.")

        let longQuote = String(repeating: "q", count: 161)
        let tooLong = quotes.submitSuggestion(
            category: .social,
            source: "Community",
            quoteText: longQuote
        )
        XCTAssertEqual(tooLong, "Quote text is too long.")

        XCTAssertNil(
            quotes.submitSuggestion(
                category: .social,
                source: "Community",
                quoteText: "If your roadmap drifts, rename the destination before panic mode arrives."
            )
        )
        XCTAssertEqual(quotes.quoteSuggestionCount, 1)

        let suggestion = try XCTUnwrap(repository.fetchQuoteSuggestions(limit: 10).first)
        quotes.deleteSuggestion(suggestion)
        XCTAssertEqual(quotes.quoteSuggestionCount, 0)
    }
}
