import SwiftData
import XCTest
@testable import Badvice

@MainActor
final class AppSessionSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        _ = BadviceIntentRouter.shared.consume()
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
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
            "SmokeTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    func testFreshGeneratorStartsWithLaunchReadyPromptPair() throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))

        XCTAssertEqual(session.generate.selectedCategory, .career)
        XCTAssertEqual(session.generate.selectedTone, .corporateConsultant)
        XCTAssertNil(
            CategoryToneCompatibility.compatibilityLabel(
                category: session.generate.selectedCategory,
                tone: session.generate.selectedTone
            )
        )
    }

    func testBootstrapAdviceExperienceShowsLoadingAndAutoGeneratesInitialAdvice() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))

        session.settings.preferredGenerationProvider = .classic
        XCTAssertNil(session.generate.current)
        session.bootstrapExperienceIfNeeded(autoGenerateInitialAdvice: true)
        XCTAssertTrue(session.generate.isGenerating)

        try await waitUntil(timeout: .seconds(6)) {
            session.generate.current != nil && !session.generate.isGenerating
        }

        let generated = try XCTUnwrap(session.generate.current)
        XCTAssertEqual(generated.category, .career)
        XCTAssertEqual(generated.tone, .corporateConsultant)
        XCTAssertFalse(generated.adviceLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testBureauGenerationIsFastGroundedAndDoesNotPrepareAModel() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        session.settings.preferredGenerationProvider = .classic
        session.generate.selectedCategory = .career
        session.generate.selectedTone = .corporateConsultant
        session.generate.scenarioText =
            "My manager asked for a status update and I have nothing finished."
        let selectedModelBeforeGeneration = session.settings.selectedAppleLocalModelID

        let clock = ContinuousClock()
        let start = clock.now
        await session.generate.generate(seed: 42)
        let elapsed = start.duration(to: clock.now)

        let generated = try XCTUnwrap(session.generate.current)
        XCTAssertLessThan(elapsed, .seconds(5))
        XCTAssertTrue(
            generated.adviceLine.normalizedForFiltering.contains("status update"),
            "The default Bureau path should stay grounded without semantic-model ranking."
        )
        XCTAssertEqual(
            session.settings.selectedAppleLocalModelID,
            selectedModelBeforeGeneration
        )
        XCTAssertFalse(session.settings.isPreparingAppleOnDeviceModel)
        XCTAssertEqual(session.generate.generationSourceBadgeText, "Bureau Engine • local")
    }

    func testRandomToneRespectsSelectedCategoryCompatibility() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))

        session.generate.selectedCategory = .pets
        session.generate.selectedTone = .random

        await session.generate.generate(seed: 1)

        let generated = try XCTUnwrap(session.generate.current)
        XCTAssertEqual(generated.category, .pets)
        XCTAssertNotEqual(generated.tone, .random)
        XCTAssertNil(
            CategoryToneCompatibility.compatibilityLabel(
                category: generated.category,
                tone: generated.tone
            )
        )
    }

    func testRandomCategoryRespectsSelectedToneCompatibility() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))

        session.generate.selectedCategory = .random
        session.generate.selectedTone = .cryptoBro

        await session.generate.generate(seed: 3)

        let generated = try XCTUnwrap(session.generate.current)
        XCTAssertNotEqual(generated.category, .random)
        XCTAssertEqual(generated.tone, .cryptoBro)
        XCTAssertNil(
            CategoryToneCompatibility.compatibilityLabel(
                category: generated.category,
                tone: generated.tone
            )
        )
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
        _ = try await OpenDailyQuoteIntent().perform()
        let payload = await waitForIntentPayload(timeout: 1.5)
        XCTAssertNotNil(payload)
        let unwrappedPayload = try XCTUnwrap(payload)

        XCTAssertEqual(unwrappedPayload.command, .openDailyQuote)
        XCTAssertEqual(unwrappedPayload.tab, AppTab.quotes.rawValue)
        XCTAssertFalse(unwrappedPayload.shouldGenerate)
    }

    func testOpenMissionsIntentQueuesChaosHubIntentPayload() async throws {
        _ = try await OpenBadviceMissionsIntent().perform()
        let payload = await waitForIntentPayload(timeout: 1.5)
        XCTAssertNotNil(payload)
        let unwrappedPayload = try XCTUnwrap(payload)

        XCTAssertEqual(unwrappedPayload.command, .openTab)
        XCTAssertEqual(unwrappedPayload.tab, AppTab.chaosHub.rawValue)
        XCTAssertFalse(unwrappedPayload.shouldGenerate)
    }

    func testStartDailyMissionIntentQueuesMatchingGeneratePayload() async throws {
        _ = try await StartDailyMissionIntent().perform()
        let payload = await waitForIntentPayload(timeout: 1.5)
        XCTAssertNotNil(payload)
        let unwrappedPayload = try XCTUnwrap(payload)
        let mission = DailyMissionSpec.current()

        XCTAssertEqual(unwrappedPayload.command, .generateAdvice)
        XCTAssertEqual(unwrappedPayload.tab, AppTab.generate.rawValue)
        XCTAssertEqual(unwrappedPayload.category, mission.category.rawValue)
        XCTAssertEqual(unwrappedPayload.tone, mission.tone.rawValue)
        XCTAssertTrue(unwrappedPayload.shouldGenerate)
        XCTAssertTrue(unwrappedPayload.scenario?.contains("Daily mission") == true)
    }

    func testGetDailyQuoteIntentFormatsShortcutTextWithoutRoutingPayload() async throws {
        _ = BadviceIntentRouter.shared.consume()

        let quote = SharedDailyQuoteSource.quoteOfDay()
        let shortcutText = BadviceDailyQuoteIntentFormatter.shortcutText(for: quote)

        XCTAssertTrue(shortcutText.contains(quote.text))
        XCTAssertTrue(shortcutText.contains(quote.source))
        XCTAssertTrue(shortcutText.contains("Badvice"))
        XCTAssertNil(BadviceIntentRouter.shared.consume())
    }

    private func waitForIntentPayload(timeout: TimeInterval) async -> BadviceIntentPayload? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let payload = BadviceIntentRouter.shared.consume() {
                return payload
            }
            do {
                try await Task.sleep(for: .milliseconds(40))
            } catch {
                return nil
            }
        }
        return BadviceIntentRouter.shared.consume()
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

final class PartyRoundTests: XCTestCase {
    func testPartyRoundValidatesNamesAndBlocksSelfVoting() throws {
        XCTAssertEqual(PartyRound.playerNames(from: " Alex, , Sam , Jordan "), ["Alex", "Sam", "Jordan"])
        XCTAssertNil(PartyRound.make(players: ["Solo"], category: .career, seed: 1))
        XCTAssertNil(PartyRound.make(players: ["Alex", "alex"], category: .career, seed: 1))
        XCTAssertNil(PartyRound.make(players: [String(repeating: "a", count: 25), "Sam"], category: .career, seed: 1))
        var round = try XCTUnwrap(PartyRound.make(players: ["Alex", "Sam", "Jordan"], category: .career, seed: 42))
        XCTAssertTrue(round.isValid)
        XCTAssertFalse(round.castVote(for: 0))
        XCTAssertFalse(round.castVote(for: 99))
        XCTAssertEqual(round.voterIndex, 0)
        XCTAssertTrue(round.castVote(for: 1))
        let saved = try JSONEncoder().encode(round)
        round = try JSONDecoder().decode(PartyRound.self, from: saved)
        XCTAssertEqual(round.voterIndex, 1)
        XCTAssertTrue(round.castVote(for: 0))
        XCTAssertTrue(round.castVote(for: 0))
        XCTAssertTrue(round.isComplete)
        XCTAssertTrue(round.isValid)
        XCTAssertEqual(round.leaders.map(\.player), ["Alex"])
        XCTAssertFalse(round.castVote(for: 1))
    }

    func testTwoPlayerTieIsHonestAndEveryTakeIsSafe() throws {
        var round = try XCTUnwrap(PartyRound.make(players: ["Alex", "Sam"], category: .random, seed: 7))
        XCTAssertTrue(round.castVote(for: 1))
        XCTAssertTrue(round.castVote(for: 0))
        XCTAssertEqual(round.leaders.count, 2)
        let moderation = ContentModeration()
        for entry in round.entries {
            XCTAssertFalse(entry.advice.isEmpty)
            XCTAssertTrue(moderation.isSafe(text: entry.advice))
        }
    }
}


@MainActor
private final class RecordingAppleGenerator: AppleAdviceGenerating {
    var requests: [(AdviceCategory, ToneMode, BadviceIntensity, AdviceRevisionStyle?)] = []
    var fails = false
    var delay: Duration = .zero
    func generateCandidate(category: AdviceCategory, tone: ToneMode, situation: String?,
        includeRationale: Bool, seed: Int, now: Date, intensity: BadviceIntensity,
        revision: AdviceRevisionStyle?) async throws -> GeneratedAdvice {
        requests.append((category, tone, intensity, revision))
        if delay != .zero { try await Task.sleep(for: delay) }
        if fails { throw CocoaError(.coderInvalidValue) }
        return GeneratedAdvice(category: category, tone: tone,
            adviceLine: "Appoint your \(category.title.lowercased()) notebook CEO of an imaginary committee.",
            rationaleLine: includeRationale ? "Notebooks cannot lead. Make one practical decision instead." : nil, createdAt: now)
    }
}

extension AppSessionSmokeTests {
    func testFoundationRequestCoversEveryCategoryToneAndIntensity() {
        var count = 0
        for category in AdviceCategory.allCases {
            for tone in ToneMode.allCases {
                for intensity in BadviceIntensity.allCases {
                    let request = AppleOnDeviceAdviceBridge.adviceRequest(category: category, tone: tone,
                        situation: "Test situation", seed: 42, intensity: intensity, revision: .oneSentence)
                    XCTAssertTrue(request.prompt.contains(category.title))
                    XCTAssertTrue(request.prompt.contains(tone.title))
                    XCTAssertTrue(request.prompt.contains(intensity.title))
                    XCTAssertTrue(request.prompt.contains("One sentence"))
                    XCTAssertTrue(request.instructions.contains("Keep people and animals safe"))
                    XCTAssertTrue(request.prompt.contains("<situation>Test situation</situation>"))
                    count += 1
                }
            }
        }
        XCTAssertEqual(count, AdviceCategory.allCases.count * ToneMode.allCases.count * 5)
    }

    func testAppleRoutingUsesModelAcrossEveryConcreteCategoryAndTone() async throws {
        let session = AppSessionViewModel(context: ModelContext(try makeInMemoryContainer()))
        session.settings.strictNoRepeats = false
        let bridge = RecordingAppleGenerator()
        let model = GenerateViewModel(repository: session.repository, settingsViewModel: session.settings,
            achievementsManager: session.achievements, appleOnDeviceBridge: bridge, appleAvailability: { .ready })
        for category in AdviceCategory.concrete {
            for tone in ToneMode.allCases where tone != .random {
                model.selectedCategory = category
                model.selectedTone = tone
                model.selectedIntensity = .legendaryMistake
                await model.generate(seed: bridge.requests.count + 42, revision: .oneSentence)
                let output = try XCTUnwrap(model.current)
                XCTAssertEqual(output.category, category)
                XCTAssertEqual(output.tone, tone)
                XCTAssertTrue(output.adviceLine.hasPrefix("Appoint"), "Apple candidate must reach the screen")
                XCTAssertEqual(model.generationSourceBadgeText, "Apple Intelligence • on device")
                XCTAssertEqual(bridge.requests.last?.2, .legendaryMistake)
                XCTAssertEqual(bridge.requests.last?.3, .oneSentence)
            }
        }
        XCTAssertEqual(bridge.requests.count, AdviceCategory.concrete.count * (ToneMode.allCases.count - 1))
    }

    func testAppleFailureFallsBackHonestlyAndConcurrentRequestsDoNotOverlap() async throws {
        let session = AppSessionViewModel(context: ModelContext(try makeInMemoryContainer()))
        let bridge = RecordingAppleGenerator()
        bridge.fails = true
        bridge.delay = .milliseconds(100)
        let model = GenerateViewModel(repository: session.repository, settingsViewModel: session.settings,
            achievementsManager: session.achievements, appleOnDeviceBridge: bridge, appleAvailability: { .ready })
        let first = Task { await model.generate(seed: 1) }
        await Task.yield()
        await model.generate(seed: 2)
        await first.value
        XCTAssertEqual(bridge.requests.count, 1)
        XCTAssertNotNil(model.current)
        XCTAssertEqual(model.generationSourceBadgeText, "Bureau Engine • local")
        XCTAssertTrue(model.generationNotice?.contains("Using classic generator") == true)
        XCTAssertFalse(model.isGenerating)
    }

    func testLiveAppleFoundationModelSmokeWhenAvailable() async throws {
        let availability = AppleOnDeviceAdviceBridge.currentAvailability()
        guard availability.isReady else { throw XCTSkip("Live Apple model: \(availability.statusText)") }
        let session = AppSessionViewModel(context: ModelContext(try makeInMemoryContainer()))
        session.settings.preferredGenerationProvider = .appleOnDevice
        session.settings.strictNoRepeats = false
        session.generate.scenarioText = "I am overthinking a small decision."
        var appleCount = 0
        var fallbackCount = 0
        for (index, category) in AdviceCategory.concrete.enumerated() {
            let tone = ToneMode.concrete[index % ToneMode.concrete.count]
            session.generate.selectedCategory = category
            session.generate.selectedTone = tone
            await session.generate.generate(seed: 42 + index)
            let result = try XCTUnwrap(session.generate.current)
            XCTAssertEqual(result.category, category)
            XCTAssertEqual(result.tone, tone)
            XCTAssertFalse(result.adviceLine.isEmpty)
            if session.generate.generationSourceBadgeText == "Apple Intelligence • on device" {
                appleCount += 1
                XCTAssertLessThanOrEqual(result.adviceLine.count, 220)
            } else {
                fallbackCount += 1
                XCTAssertEqual(session.generate.generationSourceBadgeText, "Bureau Engine • local")
                XCTAssertFalse(session.generate.generationNotice?.isEmpty ?? true, "A real fallback must explain its reason")
            }
            print("LIVE APP GENERATOR: \(category.rawValue)/\(tone.rawValue) — \(session.generate.generationSourceBadgeText ?? "missing source") — \(session.generate.generationNotice ?? result.adviceLine)")
        }
        XCTAssertGreaterThan(appleCount, 0, "The live check must actually produce Apple output")
        XCTAssertEqual(appleCount + fallbackCount, AdviceCategory.concrete.count)
        print("LIVE APP GENERATOR TOTAL: Apple=\(appleCount), explained fallback=\(fallbackCount)")
    }
}
