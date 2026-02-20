import SwiftData
import XCTest
@testable import Badvice

final class AdviceEngineTests: XCTestCase {
    func testDeterministicOutputWithSeed() async {
        let engine = AdviceEngine()

        let first = await engine.generate(
            category: .career,
            tone: .wizard,
            includeRationale: true,
            seed: 42,
            now: Date(timeIntervalSince1970: 1_000)
        )

        let second = await engine.generate(
            category: .career,
            tone: .wizard,
            includeRationale: true,
            seed: 42,
            now: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(first.adviceLine, second.adviceLine)
        XCTAssertEqual(first.rationaleLine, second.rationaleLine)
    }

    func testDifferentSeedProducesDifferentAdvice() async {
        let engine = AdviceEngine()

        let first = await engine.generate(category: .money, tone: .cryptoBro, includeRationale: false, seed: 1)
        let second = await engine.generate(category: .money, tone: .cryptoBro, includeRationale: false, seed: 2)

        XCTAssertNotEqual(first.adviceLine, second.adviceLine)
    }

    func testOutputRespectsCategoryForbiddenPatterns() async {
        let engine = AdviceEngine()
        let category: AdviceCategory = .dating
        let forbidden = AdviceStore().rules(for: category).forbiddenPatterns

        for seed in 0..<20 {
            let output = await engine.generate(category: category, tone: .toxicBestFriend, includeRationale: true, seed: seed)
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

    func testSituationIsWovenIntoAdviceWhenSafe() async {
        let engine = AdviceEngine()
        let output = await engine.generate(
            category: .dating,
            tone: .influencer,
            includeRationale: false,
            situation: "awkward first date",
            seed: 17
        )

        XCTAssertTrue(output.adviceLine.normalizedForFiltering.contains("awkward first date"))
    }

    func testUnsafeSituationIsIgnored() async {
        let engine = AdviceEngine()
        let output = await engine.generate(
            category: .tech,
            tone: .cryptoBro,
            includeRationale: false,
            situation: "how do I hack my ex account",
            seed: 23
        )

        XCTAssertFalse(output.adviceLine.normalizedForFiltering.contains("hack my ex account"))
        XCTAssertTrue(engine.validateOutput(output, for: .tech))
    }

    func testFriendRoastToneSupportsPersonalizedPrompt() async {
        let engine = AdviceEngine()
        let output = await engine.generate(
            category: .social,
            tone: .friendRoast,
            includeRationale: false,
            situation: "friend Alex",
            seed: 77
        )

        XCTAssertTrue(output.adviceLine.normalizedForFiltering.contains("friend alex"))
    }

    func testContentPackChangesOutputForSameSeed() async {
        let engine = AdviceEngine()
        let classic = await engine.generate(
            category: .career,
            tone: .corporateConsultant,
            includeRationale: true,
            contentPack: .classic,
            seed: 123
        )
        let packed = await engine.generate(
            category: .career,
            tone: .corporateConsultant,
            includeRationale: true,
            contentPack: .officeMeltdown,
            seed: 123
        )

        XCTAssertNotEqual(classic.adviceLine, packed.adviceLine)
    }

    func testContentPackIsDeterministicWithSeed() async {
        let engine = AdviceEngine()
        let first = await engine.generate(
            category: .social,
            tone: .influencer,
            includeRationale: true,
            contentPack: .chronicallyOnline,
            seed: 9001
        )
        let second = await engine.generate(
            category: .social,
            tone: .influencer,
            includeRationale: true,
            contentPack: .chronicallyOnline,
            seed: 9001
        )

        XCTAssertEqual(first.adviceLine, second.adviceLine)
        XCTAssertEqual(first.rationaleLine, second.rationaleLine)
    }

    func testAdviceIncludesToneAndCategoryDirectiveSignals() async {
        let engine = AdviceEngine()
        let tone: ToneMode = .lifeCoach
        let category: AdviceCategory = .money
        let signals = AdviceEngine.directiveSignals(tone: tone, category: category)

        let first = await engine.generate(
            category: category,
            tone: tone,
            includeRationale: true,
            seed: 314
        )
        let second = await engine.generate(
            category: category,
            tone: tone,
            includeRationale: true,
            seed: 314
        )

        XCTAssertEqual(first.adviceLine, second.adviceLine)
        XCTAssertEqual(first.rationaleLine, second.rationaleLine)

        let normalized = first.adviceLine.normalizedForFiltering
        XCTAssertTrue(signals.tone.contains { normalized.contains($0.normalizedForFiltering) })
        XCTAssertTrue(signals.category.contains { normalized.contains($0.normalizedForFiltering) })
        XCTAssertTrue(engine.validateOutput(first, for: category))
    }

    func testBadQuoteOfDayIsDeterministicForDate() {
        let service = BadQuoteService()
        let fixedDate = Date(timeIntervalSince1970: 1_763_000_000)

        let first = service.quoteOfDay(now: fixedDate)
        let second = service.quoteOfDay(now: fixedDate)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.text, second.text)
    }

    func testBadQuoteOfDayChangesAcrossDays() {
        let service = BadQuoteService()
        let dayOne = Date(timeIntervalSince1970: 1_763_000_000)
        let dayTwo = Date(timeIntervalSince1970: 1_763_000_000 + 86_400)

        let first = service.quoteOfDay(now: dayOne)
        let second = service.quoteOfDay(now: dayTwo)

        XCTAssertNotEqual(first.id, second.id)
    }

    func testDefaultQuoteBankMeetsExpansionTarget() {
        XCTAssertGreaterThanOrEqual(BadQuoteService.defaultQuotes.count, 140)
    }

    func testCorpusDecodeSucceedsForBundledDataAndFailsSafelyForBadData() throws {
        let bundleURL = try XCTUnwrap(
            Bundle.main.url(forResource: "AdviceCorpus", withExtension: "json"),
            "AdviceCorpus.json should be bundled with the app target."
        )
        let data = try Data(contentsOf: bundleURL)
        let payload = try XCTUnwrap(
            BadQuoteService.decodeCorpus(data: data),
            "Bundled corpus payload should decode."
        )
        XCTAssertFalse(payload.entries.isEmpty)

        let malformed = Data("{not-json}".utf8)
        XCTAssertNil(BadQuoteService.decodeCorpus(data: malformed))
    }

    func testAllContentPackCasesExposeNonEmptyTitles() {
        for pack in ContentPack.allCases {
            XCTAssertFalse(pack.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testSharedDailyQuoteParityMatchesBadQuoteService() {
        let service = BadQuoteService()
        let checkpoints: [Date] = [
            Date(timeIntervalSince1970: 1_763_000_000),
            Date(timeIntervalSince1970: 1_763_000_000 + 86_400),
            Date(timeIntervalSince1970: 1_763_000_000 + (86_400 * 7))
        ]

        for checkpoint in checkpoints {
            let appQuote = service.quoteOfDay(now: checkpoint)
            let sharedQuote = SharedDailyQuoteSource.quoteOfDay(for: checkpoint)
            XCTAssertEqual(appQuote.id, sharedQuote.id)
            XCTAssertEqual(appQuote.text, sharedQuote.text)
            XCTAssertEqual(appQuote.source, sharedQuote.source)
        }
    }
}

@MainActor
final class PersistenceTests: XCTestCase {
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
            "Tests",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
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

    func testAdviceFingerprintMemoryStoresUniqueValues() throws {
        let repository = try makeRepository()

        repository.rememberAdviceFingerprint("same line")
        repository.rememberAdviceFingerprint("same line")
        repository.rememberAdviceFingerprint("another line")

        XCTAssertTrue(repository.hasSeenAdvice("same line"))
        XCTAssertTrue(repository.hasSeenAdvice("another line"))
        XCTAssertEqual(repository.seenAdviceCount(), 2)
    }

    func testPurgeAllHistoryClearsFingerprintMemory() throws {
        let repository = try makeRepository()
        let advice = GeneratedAdvice(
            category: .productivity,
            tone: .corporateConsultant,
            adviceLine: "Reset the plan, not the confidence.",
            rationaleLine: nil,
            createdAt: Date()
        )
        _ = repository.insert(advice)

        XCTAssertTrue(repository.hasSeenAdvice(advice.adviceLine))
        repository.purgeAllHistory()
        XCTAssertFalse(repository.hasSeenAdvice(advice.adviceLine))
    }

    func testAdviceFingerprintPruningKeepsFreshestEntries() throws {
        let repository = try makeRepository()
        let baseDate = Date(timeIntervalSince1970: 10_000)

        for index in 0..<5 {
            repository.rememberAdviceFingerprint(
                "line \(index)",
                createdAt: baseDate.addingTimeInterval(TimeInterval(index))
            )
        }

        repository.pruneAdviceFingerprints(maxCount: 3)

        XCTAssertFalse(repository.hasSeenAdvice("line 0"))
        XCTAssertFalse(repository.hasSeenAdvice("line 1"))
        XCTAssertTrue(repository.hasSeenAdvice("line 2"))
        XCTAssertTrue(repository.hasSeenAdvice("line 3"))
        XCTAssertTrue(repository.hasSeenAdvice("line 4"))
    }

    func testCategoryToneFingerprintPoolsAreTrackedSeparately() throws {
        let repository = try makeRepository()

        repository.rememberAdviceFingerprintInPool(
            "same advice",
            category: .career,
            tone: .wizard
        )

        XCTAssertTrue(repository.hasSeenAdviceInPool("same advice", category: .career, tone: .wizard))
        XCTAssertFalse(repository.hasSeenAdviceInPool("same advice", category: .career, tone: .boomer))
        XCTAssertEqual(repository.seenAdviceCount(), 0)
    }

    func testSeenAdviceCountStaysAccurateAfterCacheWarmAndPoolWrites() throws {
        let repository = try makeRepository()

        repository.rememberAdviceFingerprint("global one")
        XCTAssertEqual(repository.seenAdviceCount(), 1) // Warm the count/cache path.

        repository.rememberAdviceFingerprintInPool(
            "global one",
            category: .career,
            tone: .wizard
        )
        repository.rememberAdviceFingerprint("global two")

        XCTAssertTrue(repository.hasSeenAdvice("global two"))
        XCTAssertTrue(repository.hasSeenAdviceInPool("global one", category: .career, tone: .wizard))
        XCTAssertEqual(repository.seenAdviceCount(), 2)
    }

    func testFingerprintLookupIgnoresEdgeWhitespaceNoise() throws {
        let repository = try makeRepository()

        repository.rememberAdviceFingerprint("   same   line   ")
        XCTAssertTrue(repository.hasSeenAdvice("same   line"))
        XCTAssertTrue(repository.hasSeenAdvice("  same   line  "))
        XCTAssertFalse(repository.hasSeenAdvice("same line"))
    }

    func testVotePersistsOnRecord() throws {
        let repository = try makeRepository()
        let record = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .corporateConsultant,
                adviceLine: "Present certainty as strategy.",
                rationaleLine: nil
            )
        )

        repository.setVote(record, vote: .like)

        let fetched = repository.fetchHistory(limit: 1).first
        XCTAssertEqual(fetched?.vote, .like)
    }

    func testSuggestionsPersistAndDelete() throws {
        let repository = try makeRepository()

        let suggestion = repository.addSuggestion(
            category: .social,
            topic: "group chat drama",
            adviceLine: "Reply in memes only and call it emotional boundaries."
        )
        XCTAssertEqual(repository.fetchSuggestions(limit: 20).count, 1)

        repository.deleteSuggestion(suggestion)
        XCTAssertEqual(repository.fetchSuggestions(limit: 20).count, 0)
    }

    func testCommunityOnlyModeSettingPersists() throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)
        XCTAssertFalse(settings.communityOnlyMode)

        settings.communityOnlyMode = true

        let reloaded = SettingsViewModel(repository: repository)
        XCTAssertTrue(reloaded.communityOnlyMode)
    }

    func testHistoryRankingModesFilterVotes() throws {
        let repository = try makeRepository()

        let liked = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .corporateConsultant,
                adviceLine: "Tell your manager every bug is a feature launch.",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        repository.setVote(liked, vote: .like)

        let disliked = repository.insert(
            GeneratedAdvice(
                category: .money,
                tone: .cryptoBro,
                adviceLine: "Diversify by buying only coins with dog logos.",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: 101)
            )
        )
        repository.setVote(disliked, vote: .dislike)

        _ = repository.insert(
            GeneratedAdvice(
                category: .social,
                tone: .influencer,
                adviceLine: "Reply to every text with a poll.",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: 102)
            )
        )

        let history = HistoryViewModel(repository: repository)
        history.rankingMode = .topLiked
        XCTAssertEqual(history.filteredHistory.count, 1)
        XCTAssertEqual(history.filteredHistory.first?.id, liked.id)

        history.rankingMode = .topDisliked
        XCTAssertEqual(history.filteredHistory.count, 1)
        XCTAssertEqual(history.filteredHistory.first?.id, disliked.id)
    }

    func testQuoteVotePersistsAndCanBeCleared() throws {
        let repository = try makeRepository()

        repository.setQuoteVote(quoteID: "career-1", vote: .like)
        XCTAssertEqual(repository.quoteVote(for: "career-1"), .like)

        repository.setQuoteVote(quoteID: "career-1", vote: .none)
        XCTAssertEqual(repository.quoteVote(for: "career-1"), .none)
    }

    func testQuoteSuggestionsPersistAndDelete() throws {
        let repository = try makeRepository()
        let suggestion = repository.addQuoteSuggestion(
            category: .career,
            source: "Office Oracle",
            quoteText: "If the roadmap drifts, rename the destination."
        )

        XCTAssertEqual(repository.fetchQuoteSuggestions(limit: 20).count, 1)
        repository.deleteQuoteSuggestion(suggestion)
        XCTAssertEqual(repository.fetchQuoteSuggestions(limit: 20).count, 0)
    }

    func testTabOrderSettingPersistsAndKeepsSettingsLast() throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)

        settings.tabOrder = [.settings, .history, .quotes, .favorites, .chaosHub, .generate]
        let reloaded = SettingsViewModel(repository: repository)

        XCTAssertEqual(reloaded.tabOrder.first, .generate)
        XCTAssertEqual(reloaded.tabOrder.last, .settings)
        XCTAssertEqual(reloaded.tabOrder, [.generate, .history, .quotes, .favorites, .chaosHub, .settings])
    }

    func testDailyMissionProgressCompletesFromTodayGeneration() async throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)
        let achievements = AchievementsManager(context: repository.context)
        let generate = GenerateViewModel(repository: repository, settingsViewModel: settings, achievementsManager: achievements)
        let mission = generate.dailyMissionState

        XCTAssertGreaterThan(mission.targetCount, 0)
        for index in 0..<mission.targetCount {
            generate.selectedCategory = mission.category
            generate.selectedTone = mission.tone
            await generate.generate(seed: 91_000 + index)
        }

        let refreshedMission = generate.dailyMissionState
        XCTAssertTrue(generate.dailyMissionCompleted)
        XCTAssertEqual(refreshedMission.currentCount, mission.targetCount)
        XCTAssertEqual(generate.dailyMissionProgressFraction, 1.0, accuracy: 0.0001)
    }

    func testTodayHistoryCountCategoryToneIgnoresInvalidRawFallbacks() throws {
        let repository = try makeRepository()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let yesterday = now.addingTimeInterval(-86_400)

        let corrupted = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .wizard,
                adviceLine: "legacy payload with unknown raw fields",
                rationaleLine: nil,
                createdAt: now
            )
        )
        _ = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .wizard,
                adviceLine: "valid same-day match",
                rationaleLine: nil,
                createdAt: now
            )
        )
        _ = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .wizard,
                adviceLine: "prior day should not count",
                rationaleLine: nil,
                createdAt: yesterday
            )
        )

        corrupted.categoryRaw = "legacy-unknown-category"
        corrupted.toneRaw = "legacy-unknown-tone"
        repository.save()

        XCTAssertEqual(
            repository.todayHistoryCount(category: .career, tone: .wizard, referenceDate: now),
            1
        )
        XCTAssertEqual(
            repository.todayHistoryCount(category: .productivity, tone: .corporateConsultant, referenceDate: now),
            0
        )
    }

    func testQuotesFilteringAndRankingRemainCorrectAfterDebounce() async throws {
        let repository = try makeRepository()
        let likedSuggestion = repository.addQuoteSuggestion(
            category: .career,
            source: "Debug Desk",
            quoteText: "qzalpha delay budget the launch to feel decisive."
        )
        let dislikedSuggestion = repository.addQuoteSuggestion(
            category: .money,
            source: "Panic Ledger",
            quoteText: "qzbeta interest rates are just a confidence poll."
        )
        repository.setQuoteVote(
            quoteID: "community-\(likedSuggestion.id.uuidString)",
            vote: .like
        )
        repository.setQuoteVote(
            quoteID: "community-\(dislikedSuggestion.id.uuidString)",
            vote: .dislike
        )

        let viewModel = QuotesViewModel(repository: repository)
        viewModel.rankingMode = .topLiked
        viewModel.searchText = "qzalpha"

        // Debounce keeps the old result set until the delay completes.
        XCTAssertTrue(viewModel.filteredQuotes.count >= 1)

        for _ in 0..<20 where viewModel.filteredQuotes.count != 1 {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(viewModel.filteredQuotes.count, 1)
        XCTAssertEqual(viewModel.filteredQuotes.first?.id, "community-\(likedSuggestion.id.uuidString)")
        XCTAssertEqual(viewModel.vote(for: viewModel.filteredQuotes[0]), .like)
    }

    func testHistoryDebounceChangesTimingButNotFinalFilterResult() async throws {
        let repository = try makeRepository()

        _ = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .corporateConsultant,
                adviceLine: "qzhistory keep every meeting optional but mandatory.",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )
        _ = repository.insert(
            GeneratedAdvice(
                category: .social,
                tone: .influencer,
                adviceLine: "Post an hour-by-hour updates thread for lunch.",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: 201)
            )
        )

        let history = HistoryViewModel(repository: repository)
        let baselineCount = history.filteredHistory.count
        XCTAssertEqual(baselineCount, 2)

        history.searchText = "qzhistory"
        XCTAssertEqual(history.filteredHistory.count, baselineCount)

        for _ in 0..<20 where history.filteredHistory.count != 1 {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(history.filteredHistory.count, 1)
        XCTAssertTrue(history.filteredHistory[0].adviceLine.contains("qzhistory"))
    }

    func testAdaptiveRankerPrefersLikedScopeAtEqualRelevance() throws {
        let repository = try makeRepository()
        let likedScope = "advice|career|wizard"
        let neutralScope = "advice|career|boomer"

        for _ in 0..<5 {
            repository.recordLearningSignal(scopeKey: likedScope, type: .shown)
        }
        for _ in 0..<3 {
            repository.recordLearningSignal(scopeKey: likedScope, type: .like)
        }

        let ranker = AdaptiveRanker()
        let likedScore = ranker.adviceScore(
            semanticRelevance: 0.6,
            stats: repository.learningSnapshot(for: likedScope),
            noveltyPenalty: 0,
            seed: 13,
            candidateIndex: 0
        )
        let neutralScore = ranker.adviceScore(
            semanticRelevance: 0.6,
            stats: repository.learningSnapshot(for: neutralScope),
            noveltyPenalty: 0,
            seed: 13,
            candidateIndex: 1
        )

        XCTAssertGreaterThan(likedScore, neutralScore)
    }

    func testAdaptiveRankerPenalizesDislikedScope() throws {
        let repository = try makeRepository()
        let dislikedScope = "advice|money|cryptoBro"

        for _ in 0..<4 {
            repository.recordLearningSignal(scopeKey: dislikedScope, type: .shown)
        }
        for _ in 0..<3 {
            repository.recordLearningSignal(scopeKey: dislikedScope, type: .dislike)
        }

        let ranker = AdaptiveRanker()
        let dislikedScore = ranker.adviceScore(
            semanticRelevance: 0.62,
            stats: repository.learningSnapshot(for: dislikedScope),
            noveltyPenalty: 0,
            seed: 29,
            candidateIndex: 0
        )
        let neutralScore = ranker.adviceScore(
            semanticRelevance: 0.62,
            stats: .empty,
            noveltyPenalty: 0,
            seed: 29,
            candidateIndex: 1
        )

        XCTAssertLessThan(dislikedScore, neutralScore)
    }

    func testImplicitSignalsDoNotOutrankStrongExplicitDislike() {
        let ranker = AdaptiveRanker()
        let implicitHeavy = LearningStatSnapshot(
            shownCount: 10,
            likeCount: 0,
            dislikeCount: 5,
            favoriteCount: 0,
            copyCount: 20,
            shareCount: 20,
            regenCount: 0,
            lastUpdatedAt: nil
        )
        let neutral = LearningStatSnapshot.empty

        let implicitHeavyScore = ranker.adviceScore(
            semanticRelevance: 0.58,
            stats: implicitHeavy,
            noveltyPenalty: 0,
            seed: 44,
            candidateIndex: 0
        )
        let neutralScore = ranker.adviceScore(
            semanticRelevance: 0.58,
            stats: neutral,
            noveltyPenalty: 0,
            seed: 44,
            candidateIndex: 1
        )

        XCTAssertLessThan(implicitHeavyScore, neutralScore)
    }

    func testSynthesizedQuoteCandidatesAreModeratedBoundedAndDeduped() {
        let moderation = ContentModeration()
        let service = BadQuoteService()
        let suggestions = [
            UserQuoteSuggestion(
                category: .career,
                source: "Ops Digest",
                quoteText: "Always rename the deadline before anyone can measure it."
            ),
            UserQuoteSuggestion(
                category: .career,
                source: "Ops Digest",
                quoteText: "Always rename the deadline before anyone can measure it."
            ),
            UserQuoteSuggestion(
                category: .money,
                source: "Ledger Club",
                quoteText: "Treat every invoice as a networking event for your wallet."
            )
        ]

        let candidates = service.candidateQuotes(
            communitySuggestions: suggestions,
            store: AdviceStore(),
            moderation: moderation,
            maxSynthesized: 12
        )
        let synthesized = candidates.filter { $0.id.hasPrefix("synth-") }

        let normalized = candidates.map { $0.text.normalizedForFiltering }
        XCTAssertEqual(Set(normalized).count, candidates.count)
        XCTAssertTrue(synthesized.allSatisfy { $0.text.count <= 160 })
        XCTAssertTrue(synthesized.allSatisfy { moderation.isSafe(text: "\($0.source) \($0.text)") })
    }

    func testCorpusCandidatesAreMappedAndFallbackToCuratedDefaults() {
        let moderation = ContentModeration()
        let service = BadQuoteService()

        let candidates = service.candidateQuotes(
            communitySuggestions: [],
            store: AdviceStore(),
            moderation: moderation,
            maxSynthesized: 0
        )

        XCTAssertFalse(candidates.isEmpty)
        XCTAssertTrue(candidates.contains { $0.id.hasPrefix("career-") || $0.id.hasPrefix("money-") })

        let corpus = candidates.filter { $0.id.hasPrefix("corpus-") }
        XCTAssertFalse(corpus.isEmpty)
        XCTAssertTrue(
            corpus.allSatisfy {
                [
                    AdviceCategory.dating,
                    AdviceCategory.career,
                    AdviceCategory.social,
                    AdviceCategory.money,
                    AdviceCategory.productivity
                ].contains($0.category)
            }
        )
    }

    func testSynthesizedQuoteIDIsStableAcrossLaunches() {
        XCTAssertEqual(
            BadQuoteService.synthesizedQuoteID(
                category: .career,
                sourceID: "career-1",
                text: "If the roadmap is unclear, increase the confidence of the timeline."
            ),
            "synth-career-2c7f428813b3923d"
        )
    }

    func testCorpusCategoryMappingHandlesAliasesAndDirectNames() {
        XCTAssertEqual(BadQuoteService.category(from: "relationships"), .dating)
        XCTAssertEqual(BadQuoteService.category(from: "work"), .career)
        XCTAssertEqual(BadQuoteService.category(from: "daily"), .productivity)
        XCTAssertEqual(BadQuoteService.category(from: "Tech"), .tech)
        XCTAssertEqual(BadQuoteService.category(from: "parent_ing"), .parenting)
        XCTAssertEqual(BadQuoteService.category(from: "career"), .career)
        XCTAssertNil(BadQuoteService.category(from: "mystery"))
    }

    func testPerformanceModeSettingDefaultsFalseAndPersistsRoundTrip() throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)

        XCTAssertFalse(settings.performanceMode)
        settings.performanceMode = true

        let reloaded = SettingsViewModel(repository: repository)
        XCTAssertTrue(reloaded.performanceMode)
    }

    func testWeeklyMissionProgressIncrementsForMatchingGenerations() async throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)
        let achievements = AchievementsManager(context: repository.context)
        let generate = GenerateViewModel(repository: repository, settingsViewModel: settings, achievementsManager: achievements)
        let baseline = generate.weeklyMissionState

        generate.selectedCategory = baseline.category
        generate.selectedTone = baseline.tone
        await generate.generate(seed: 77_001)
        await generate.generate(seed: 77_002)

        let updated = generate.weeklyMissionState
        XCTAssertEqual(updated.key, baseline.key)
        XCTAssertEqual(updated.currentCount, min(baseline.targetCount, baseline.currentCount + 2))
    }

    func testWeeklyMissionKeyResetsAcrossWeekBoundary() throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)
        let achievements = AchievementsManager(context: repository.context)
        let generate = GenerateViewModel(repository: repository, settingsViewModel: settings, achievementsManager: achievements)

        let start = Date(timeIntervalSince1970: 1_763_000_000)
        let nextWeek = start.addingTimeInterval(86_400 * 8)
        let first = generate.weeklyMissionState(for: start)
        let second = generate.weeklyMissionState(for: nextWeek)

        XCTAssertNotEqual(first.key, second.key)
    }

    func testStreakFreezeConsumesAtMostOncePerWeekAndResetsNextWeek() throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)
        let monday = Date(timeIntervalSince1970: 1_763_280_000)
        let nextDay = monday.addingTimeInterval(86_400)
        let nextWeek = monday.addingTimeInterval(86_400 * 8)

        XCTAssertTrue(settings.consumeStreakFreezeIfAvailable(for: monday))
        XCTAssertTrue(settings.isStreakFreezeActive(for: monday))
        XCTAssertFalse(settings.consumeStreakFreezeIfAvailable(for: nextDay))
        XCTAssertTrue(settings.consumeStreakFreezeIfAvailable(for: nextWeek))
    }

    func testQuoteFilterUsesLatestSearchWhenDebounceTasksRace() async throws {
        let repository = try makeRepository()
        _ = repository.addQuoteSuggestion(
            category: .career,
            source: "Race Test",
            quoteText: "qzracealpha this result should lose the race."
        )
        _ = repository.addQuoteSuggestion(
            category: .career,
            source: "Race Test",
            quoteText: "qzracebeta this result should win the race."
        )

        let viewModel = QuotesViewModel(repository: repository)
        viewModel.searchText = "qzracealpha"
        viewModel.searchText = "qzracebeta"

        for _ in 0..<20 where viewModel.filteredQuotes.first?.text.normalizedForFiltering.contains("qzracebeta") != true {
            try await Task.sleep(for: .milliseconds(100))
        }

        XCTAssertFalse(viewModel.filteredQuotes.isEmpty)
        XCTAssertTrue(viewModel.filteredQuotes.allSatisfy { $0.text.normalizedForFiltering.contains("qzracebeta") })
    }

    func testFavoritesFilteringMatchesLegacyBehaviorForSearchAndCategory() async throws {
        let repository = try makeRepository()
        let first = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .corporateConsultant,
                adviceLine: "qzfav alpha confidence memo",
                rationaleLine: "Keep the optics loud.",
                createdAt: Date(timeIntervalSince1970: 300)
            )
        )
        let second = repository.insert(
            GeneratedAdvice(
                category: .money,
                tone: .cryptoBro,
                adviceLine: "qzfav beta portfolio sprint",
                rationaleLine: "Momentum beats budgeting.",
                createdAt: Date(timeIntervalSince1970: 301)
            )
        )
        let third = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .wizard,
                adviceLine: "qzfav gamma roadmap spell",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: 302)
            )
        )
        repository.setFavorite(first, isFavorite: true)
        repository.setFavorite(second, isFavorite: true)
        repository.setFavorite(third, isFavorite: true)

        let favorites = FavoritesViewModel(repository: repository)
        XCTAssertEqual(
            favorites.filteredFavorites.map(\.id),
            legacyFilterFavorites(
                records: favorites.favorites,
                category: nil,
                searchText: ""
            ).map(\.id)
        )

        favorites.searchText = "gamma"
        try await waitUntil(timeout: .milliseconds(1500)) {
            favorites.filteredFavorites.map(\.id) == self.legacyFilterFavorites(
                records: favorites.favorites,
                category: nil,
                searchText: "gamma"
            ).map(\.id)
        }

        favorites.selectedCategory = .career
        XCTAssertEqual(
            favorites.filteredFavorites.map(\.id),
            legacyFilterFavorites(
                records: favorites.favorites,
                category: .career,
                searchText: "gamma"
            ).map(\.id)
        )
    }

    func testHistoryFilteringMatchesLegacyBehaviorForRankingCategoryAndSearch() async throws {
        let repository = try makeRepository()
        let liked = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .corporateConsultant,
                adviceLine: "qzhist alpha status deck",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: 401)
            )
        )
        repository.setVote(liked, vote: .like)

        let disliked = repository.insert(
            GeneratedAdvice(
                category: .money,
                tone: .cryptoBro,
                adviceLine: "qzhist beta leverage run",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: 402)
            )
        )
        repository.setVote(disliked, vote: .dislike)

        _ = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .wizard,
                adviceLine: "qzhist gamma confidence spell",
                rationaleLine: "Frame risk as optional.",
                createdAt: Date(timeIntervalSince1970: 403)
            )
        )

        let history = HistoryViewModel(repository: repository)
        XCTAssertEqual(history.likedCount, history.history.filter { $0.vote == .like }.count)
        XCTAssertEqual(history.dislikedCount, history.history.filter { $0.vote == .dislike }.count)

        history.selectedCategory = .career
        XCTAssertEqual(
            history.filteredHistory.map(\.id),
            legacyFilterHistory(
                records: history.history,
                category: .career,
                searchText: "",
                rankingMode: .recent
            ).map(\.id)
        )

        history.rankingMode = .topLiked
        XCTAssertEqual(
            history.filteredHistory.map(\.id),
            legacyFilterHistory(
                records: history.history,
                category: .career,
                searchText: "",
                rankingMode: .topLiked
            ).map(\.id)
        )

        history.searchText = "gamma"
        try await waitUntil(timeout: .milliseconds(1500)) {
            history.filteredHistory.map(\.id) == self.legacyFilterHistory(
                records: history.history,
                category: .career,
                searchText: "gamma",
                rankingMode: .topLiked
            ).map(\.id)
        }
    }

    func testFavoritesDebounceUsesLatestSearchInput() async throws {
        let repository = try makeRepository()
        let alpha = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .wizard,
                adviceLine: "qzdebounce alpha outcome",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: 500)
            )
        )
        let beta = repository.insert(
            GeneratedAdvice(
                category: .career,
                tone: .wizard,
                adviceLine: "qzdebounce beta outcome",
                rationaleLine: nil,
                createdAt: Date(timeIntervalSince1970: 501)
            )
        )
        repository.setFavorite(alpha, isFavorite: true)
        repository.setFavorite(beta, isFavorite: true)

        let favorites = FavoritesViewModel(repository: repository)
        let baseline = favorites.filteredFavorites.count
        favorites.searchText = "alpha"
        favorites.searchText = "beta"

        XCTAssertEqual(favorites.filteredFavorites.count, baseline)
        try await waitUntil(timeout: .milliseconds(1500)) {
            favorites.filteredFavorites.count == 1
                && favorites.filteredFavorites.first?.adviceLine.normalizedForFiltering.contains("beta") == true
        }
    }

    func testGenerateChallengeStreakMatchesLegacyComputation() async throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)
        let achievements = AchievementsManager(context: repository.context)
        let generate = GenerateViewModel(repository: repository, settingsViewModel: settings, achievementsManager: achievements)
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        let dates = [
            today,
            calendar.date(byAdding: .day, value: -1, to: today)!,
            calendar.date(byAdding: .day, value: -2, to: today)!
        ]
        for (index, date) in dates.enumerated() {
            _ = repository.insert(
                GeneratedAdvice(
                    category: .career,
                    tone: .corporateConsultant,
                    adviceLine: "qzstreak baseline \(index)",
                    rationaleLine: nil,
                    createdAt: date
                )
            )
        }

        generate.invalidateRetentionSnapshot()
        let expected = legacyChallengeStreakDays(
            history: repository.fetchAllHistory(),
            referenceDate: now,
            freezeActive: settings.isStreakFreezeActive(for: today)
        )
        XCTAssertEqual(generate.challengeStreakDays, expected)
        XCTAssertEqual(generate.challengeProgressText, "\(min(expected, generate.challengeGoalDays))/\(generate.challengeGoalDays) day streak")
    }

    func testGenerateRetentionSnapshotInvalidationUpdatesStreakAfterHistoryMutation() throws {
        let repository = try makeRepository()
        let settings = SettingsViewModel(repository: repository)
        let achievements = AchievementsManager(context: repository.context)
        let generate = GenerateViewModel(repository: repository, settingsViewModel: settings, achievementsManager: achievements)
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        _ = repository.insert(
            GeneratedAdvice(
                category: .social,
                tone: .influencer,
                adviceLine: "qzretention today only",
                rationaleLine: nil,
                createdAt: today
            )
        )

        generate.invalidateRetentionSnapshot()
        let baseline = generate.challengeStreakDays
        XCTAssertEqual(baseline, 1)

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        _ = repository.insert(
            GeneratedAdvice(
                category: .social,
                tone: .influencer,
                adviceLine: "qzretention yesterday added",
                rationaleLine: nil,
                createdAt: yesterday
            )
        )

        // Snapshot remains stale until explicitly invalidated.
        XCTAssertEqual(generate.challengeStreakDays, baseline)

        generate.invalidateRetentionSnapshot()
        XCTAssertEqual(generate.challengeStreakDays, baseline + 1)
    }

    private func legacyFilterFavorites(
        records: [AdviceRecord],
        category: AdviceCategory?,
        searchText: String
    ) -> [AdviceRecord] {
        let normalizedSearch = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .normalizedForFiltering
        return records.filter { record in
            let matchesCategory = category == nil || record.category == category
            let matchesSearch: Bool
            if normalizedSearch.isEmpty {
                matchesSearch = true
            } else {
                let haystack = "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)"
                    .normalizedForFiltering
                matchesSearch = haystack.contains(normalizedSearch)
            }
            return matchesCategory && matchesSearch
        }
    }

    private func legacyFilterHistory(
        records: [AdviceRecord],
        category: AdviceCategory?,
        searchText: String,
        rankingMode: HistoryViewModel.RankingMode
    ) -> [AdviceRecord] {
        let normalizedSearch = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .normalizedForFiltering
        let filtered = records.filter { record in
            let matchesCategory = category == nil || record.category == category
            let matchesSearch: Bool
            if normalizedSearch.isEmpty {
                matchesSearch = true
            } else {
                let haystack = "\(record.adviceLine) \(record.rationaleLine ?? "") \(record.category.title) \(record.tone.title)"
                    .normalizedForFiltering
                matchesSearch = haystack.contains(normalizedSearch)
            }
            return matchesCategory && matchesSearch
        }

        switch rankingMode {
        case .recent:
            return filtered
        case .topLiked:
            return filtered.filter { $0.vote == .like }
        case .topDisliked:
            return filtered.filter { $0.vote == .dislike }
        }
    }

    private func legacyChallengeStreakDays(
        history: [AdviceRecord],
        referenceDate: Date,
        freezeActive: Bool
    ) -> Int {
        legacyStreakDays(history: history, referenceDate: referenceDate)
            + legacyStreakFreezeBonus(history: history, referenceDate: referenceDate, freezeActive: freezeActive)
    }

    private func legacyStreakDays(history: [AdviceRecord], referenceDate: Date) -> Int {
        guard !history.isEmpty else { return 0 }
        let calendar = Calendar.current
        let days = Set(history.map { calendar.startOfDay(for: $0.createdAt) })
        let sortedDays = days.sorted(by: >)
        guard let mostRecent = sortedDays.first else { return 0 }

        let today = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        guard mostRecent == today || mostRecent == yesterday else { return 0 }

        var streak = 1
        var currentDay = mostRecent
        while true {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            if days.contains(previousDay) {
                streak += 1
                currentDay = previousDay
            } else {
                break
            }
        }
        return streak
    }

    private func legacyStreakFreezeBonus(
        history: [AdviceRecord],
        referenceDate: Date,
        freezeActive: Bool
    ) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        guard freezeActive else { return 0 }
        let days = Set(history.map { calendar.startOfDay(for: $0.createdAt) })
        guard !days.contains(today) else { return 0 }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        return days.contains(yesterday) ? 1 : 0
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(1),
        pollInterval: Duration = .milliseconds(40),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let start = ContinuousClock.now
        while true {
            if condition() {
                return
            }
            if ContinuousClock.now - start > timeout {
                XCTFail("Timed out waiting for condition.")
                return
            }
            try await Task.sleep(for: pollInterval)
        }
    }
}
