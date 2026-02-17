import SwiftData
import XCTest
@testable import Badvice

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

    func testFriendRoastToneSupportsPersonalizedPrompt() {
        let engine = AdviceEngine()
        let output = engine.generate(
            category: .social,
            tone: .friendRoast,
            includeRationale: false,
            situation: "friend Alex",
            seed: 77
        )

        XCTAssertTrue(output.adviceLine.normalizedForFiltering.contains("friend alex"))
    }

    func testContentPackChangesOutputForSameSeed() {
        let engine = AdviceEngine()
        let classic = engine.generate(
            category: .career,
            tone: .corporateConsultant,
            includeRationale: true,
            contentPack: .classic,
            seed: 123
        )
        let packed = engine.generate(
            category: .career,
            tone: .corporateConsultant,
            includeRationale: true,
            contentPack: .officeMeltdown,
            seed: 123
        )

        XCTAssertNotEqual(classic.adviceLine, packed.adviceLine)
    }

    func testContentPackIsDeterministicWithSeed() {
        let engine = AdviceEngine()
        let first = engine.generate(
            category: .social,
            tone: .influencer,
            includeRationale: true,
            contentPack: .chronicallyOnline,
            seed: 9001
        )
        let second = engine.generate(
            category: .social,
            tone: .influencer,
            includeRationale: true,
            contentPack: .chronicallyOnline,
            seed: 9001
        )

        XCTAssertEqual(first.adviceLine, second.adviceLine)
        XCTAssertEqual(first.rationaleLine, second.rationaleLine)
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

    func testAdviceFingerprintMemoryStoresUniqueValues() throws {
        let repository = try makeRepository()

        repository.rememberAdviceFingerprint("same line")
        repository.rememberAdviceFingerprint("same line")
        repository.rememberAdviceFingerprint("another line")

        XCTAssertTrue(repository.hasSeenAdvice("same line"))
        XCTAssertTrue(repository.hasSeenAdvice("another line"))
        XCTAssertEqual(repository.seenAdviceCount(), 2)
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

        settings.tabOrder = [.settings, .history, .quotes, .favorites, .generate]
        let reloaded = SettingsViewModel(repository: repository)

        XCTAssertEqual(reloaded.tabOrder.first, .generate)
        XCTAssertEqual(reloaded.tabOrder.last, .settings)
        XCTAssertEqual(reloaded.tabOrder, [.generate, .history, .quotes, .favorites, .settings])
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
            regenCount: 0
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
}
