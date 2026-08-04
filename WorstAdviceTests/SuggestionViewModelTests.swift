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
            AchievementProgressRecord.self,
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

    func testCommunityOnlyGenerationResolvesRandomToneBeforePersisting() async throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)
        settings.communityOnlyMode = true
        let achievements = AchievementsManager(context: repository.context)
        let generate = GenerateViewModel(
            repository: repository,
            settingsViewModel: settings,
            achievementsManager: achievements
        )

        XCTAssertNil(
            generate.submitSuggestion(
                category: .career,
                topic: "promotion plan",
                adviceLine: "Turn the promotion plan into a victory lap before anyone checks the output."
            )
        )

        generate.selectedCategory = .career
        generate.selectedTone = .random
        await generate.generate(seed: 515)

        let generated = try XCTUnwrap(generate.current)
        XCTAssertEqual(generated.category, .career)
        XCTAssertNotEqual(generated.tone, .random)
    }

    func testPrepareStarterReplacesVisibleResultWithoutDeletingHistory() throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)
        let achievements = AchievementsManager(context: repository.context)
        let generate = GenerateViewModel(
            repository: repository,
            settingsViewModel: settings,
            achievementsManager: achievements
        )

        let existing = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .corporateConsultant,
                adviceLine: "Keep the old take filed as evidence.",
                rationaleLine: nil
            )
        )
        generate.current = existing

        generate.prepareStarter(
            category: .spirituality,
            tone: .random,
            prompt: "I want advice inspired by this quote.",
            source: "Quote starter"
        )

        XCTAssertNil(generate.current)
        XCTAssertEqual(generate.selectedCategory, .spirituality)
        XCTAssertEqual(generate.selectedTone, .random)
        XCTAssertEqual(generate.scenarioText, "I want advice inspired by this quote.")
        XCTAssertEqual(generate.generationNotice, "Quote starter loaded. Generate when ready.")
        XCTAssertEqual(repository.fetchHistory(limit: 10).count, 1)
        XCTAssertFalse(
            generate.bootstrapAdviceExperienceIfNeeded(autoGenerateInitialAdvice: true),
            "A starter handoff should wait for the user instead of triggering cold-launch generation."
        )
    }

    func testBureauXPAndRankPersistAcrossManagerReloads() throws {
        let repository = try makeRepository()
        let manager = AchievementsManager(context: repository.context)

        XCTAssertEqual(manager.bureauXP, 0)
        XCTAssertEqual(manager.bureauRank, .intern)

        manager.awardBureauXP(105, reason: .generateAdvice)

        XCTAssertEqual(manager.bureauXP, 105)
        XCTAssertEqual(manager.bureauRank, .clerk)
        XCTAssertEqual(repository.ensureSettings().bureauXP, 105)

        let reloaded = AchievementsManager(context: repository.context)
        XCTAssertEqual(reloaded.bureauXP, 105)
        XCTAssertEqual(reloaded.bureauRank, .clerk)
    }

    func testBureauCollectionClosesFromCasebookHistoryOnce() throws {
        let repository = try makeRepository()
        let manager = AchievementsManager(context: repository.context)
        let referenceDate = Date(timeIntervalSince1970: 1_751_500_000)

        for index in 0..<3 {
            _ = repository.insert(
                GeneratedAdvice(
                    category: .career,
                    tone: .corporateConsultant,
                    adviceLine: "Career evidence exhibit \(index)",
                    rationaleLine: nil,
                    createdAt: referenceDate.addingTimeInterval(TimeInterval(index))
                )
            )
        }

        manager.refreshBureauProgress(referenceDate: referenceDate)

        let careerFile = try XCTUnwrap(
            manager.collectionStates.first(where: { $0.collection.id == "career-file" })
        )
        XCTAssertTrue(careerFile.isComplete)
        XCTAssertTrue(careerFile.isUnlocked)
        XCTAssertTrue(manager.unlockedBureauCosmetics.contains(.careerTab))
        let xpAfterFirstRefresh = manager.bureauXP

        manager.refreshBureauProgress(referenceDate: referenceDate)

        XCTAssertEqual(manager.bureauXP, xpAfterFirstRefresh)
    }

    func testBureauSchedulesKeepStableKeysForSameCalendarPeriod() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let date = Date(timeIntervalSince1970: 1_751_500_000)

        let firstContract = BureauContract.current(for: date, calendar: calendar)
        let secondContract = BureauContract.current(for: date, calendar: calendar)
        let firstBossCase = BureauBossCase.current(for: date, calendar: calendar)
        let secondBossCase = BureauBossCase.current(for: date, calendar: calendar)

        XCTAssertEqual(firstContract.key, secondContract.key)
        XCTAssertEqual(firstBossCase.key, secondBossCase.key)
        XCTAssertFalse(firstBossCase.key.contains("(year)"))
        XCTAssertGreaterThan(firstBossCase.targetCount, 0)
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
