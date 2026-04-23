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

    func testLocalAccountStorePersistsSessionAndRejectsWrongPassword() throws {
        let (store, defaults) = makeLocalAccountStore()

        let firstSession = try store.signUp(
            email: "tester@example.com",
            displayName: "Tester",
            password: "Badvice123"
        )

        XCTAssertEqual(firstSession.email, "tester@example.com")
        XCTAssertEqual(store.restoreSession()?.accountID, firstSession.accountID)

        store.signOut()
        XCTAssertNil(store.restoreSession())

        XCTAssertThrowsError(
            try store.signIn(email: "tester@example.com", password: "wrongpass1")
        ) { error in
            XCTAssertEqual(error as? LocalAuthError, .invalidCredentials)
        }

        let secondSession = try store.signIn(
            email: "tester@example.com",
            password: "Badvice123"
        )
        XCTAssertEqual(secondSession.accountID, firstSession.accountID)

        let persistedJSON = try XCTUnwrap(defaults.data(forKey: LocalAccountStore.accountsKey))
        let persistedString = try XCTUnwrap(String(data: persistedJSON, encoding: .utf8))
        XCTAssertFalse(persistedString.contains("Badvice123"))
        XCTAssertFalse(persistedString.contains("passwordSaltBase64"))
        XCTAssertFalse(persistedString.contains("passwordHashBase64"))
        XCTAssertGreaterThan(store.storedAccounts().first?.passwordHashBase64.count ?? 0, 0)
    }

    func testLocalAccountStoreValidatesInputAndRetainsStoredAccountMetadata() throws {
        let (store, _) = makeLocalAccountStore()

        XCTAssertThrowsError(
            try store.signUp(email: "bad-email", displayName: "Tester", password: "Badvice123")
        ) { error in
            XCTAssertEqual(error as? LocalAuthError, .invalidEmail)
        }

        XCTAssertThrowsError(
            try store.signUp(email: "tester@example.com", displayName: "Tester", password: "short")
        ) { error in
            XCTAssertEqual(error as? LocalAuthError, .weakPassword)
        }

        _ = try store.signUp(
            email: "tester@example.com",
            displayName: "",
            password: "Badvice123"
        )

        let storedAccount = try XCTUnwrap(store.storedAccounts().first)
        XCTAssertEqual(storedAccount.email, "tester@example.com")
        XCTAssertEqual(storedAccount.displayName, "tester")
        XCTAssertFalse(storedAccount.passwordSaltBase64.isEmpty)
        XCTAssertFalse(storedAccount.passwordHashBase64.isEmpty)
    }

    func testRepositoryScopesLocalDataPerAccount() throws {
        let container = try makeInMemoryContainer()
        let sharedContext = ModelContext(container)
        let repoA = AdviceRepository(context: sharedContext, accountKey: "account-A")
        let repoB = AdviceRepository(context: sharedContext, accountKey: "account-B")

        let inserted = repoA.insert(
            GeneratedAdvice(
                category: .career,
                tone: .wizard,
                adviceLine: "Email the CEO every thought before breakfast.",
                rationaleLine: "This is terrible."
            )
        )
        repoA.setFavorite(inserted, isFavorite: true)
        _ = repoA.addSuggestion(category: .career, topic: "status updates", adviceLine: "Send three contradictory ones.")
        _ = repoA.addQuoteSuggestion(category: .career, source: "Scope Test", quoteText: "Accountability is optional if the slide is pretty.")
        repoA.setQuoteVote(quoteID: "career-1", vote: .like)
        repoA.recordLearningSignal(scopeKey: "career:wizard", type: .like)
        repoA.ensureSettings().theme = .ember
        repoA.save()

        XCTAssertEqual(repoA.fetchAllHistory().count, 1)
        XCTAssertEqual(repoA.fetchFavorites().count, 1)
        XCTAssertEqual(repoA.fetchSuggestions(limit: 20).count, 1)
        XCTAssertEqual(repoA.fetchQuoteSuggestions(limit: 20).count, 1)
        XCTAssertEqual(repoA.quoteVote(for: "career-1"), .like)
        XCTAssertEqual(repoA.ensureSettings().theme, .ember)

        XCTAssertTrue(repoB.fetchAllHistory().isEmpty)
        XCTAssertTrue(repoB.fetchFavorites().isEmpty)
        XCTAssertTrue(repoB.fetchSuggestions(limit: 20).isEmpty)
        XCTAssertTrue(repoB.fetchQuoteSuggestions(limit: 20).isEmpty)
        XCTAssertEqual(repoB.quoteVote(for: "career-1"), .none)
        XCTAssertNotEqual(repoB.ensureSettings().theme, .ember)
    }

    func testQuotesDeepLinkParsesAsQuotesSurface() throws {
        let url = try XCTUnwrap(URL(string: "badvice://quotes"))
        let link = try XCTUnwrap(DeepLink(url: url))

        XCTAssertEqual(link.type, .quotes)
        XCTAssertNil(link.id)
    }

    func testOpenDailyQuoteIntentQueuesQuotesIntentPayload() async throws {
        _ = BadviceIntentRouter.shared.consume()

        _ = try await OpenDailyQuoteIntent().perform()
        let payload = try XCTUnwrap(BadviceIntentRouter.shared.consume())

        XCTAssertEqual(payload.command, .openDailyQuote)
        XCTAssertEqual(payload.tab, AppTab.quotes.rawValue)
        XCTAssertFalse(payload.shouldGenerate)
    }

    private func makeLocalAccountStore() -> (LocalAccountStore, UserDefaults) {
        let suiteName = "AppSessionSmokeTests.LocalAccountStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return (
            LocalAccountStore(
                userDefaults: defaults,
                credentialsStore: LocalAccountInMemoryStore()
            ),
            defaults
        )
    }
}
