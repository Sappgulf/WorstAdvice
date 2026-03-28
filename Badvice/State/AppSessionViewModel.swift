import Foundation
import OSLog
import SwiftData

@MainActor
final class AppSessionViewModel {
    private static let logger = Logger(subsystem: "com.worstadvice.app", category: "ui-tests")
    let repository: AdviceRepository
    let accountID: UUID?
    let localModelStore: LocalModelStore
    let settings: SettingsViewModel
    let generate: GenerateViewModel
    let favorites: FavoritesViewModel
    let history: HistoryViewModel
    let quotes: QuotesViewModel
    let social: SocialViewModel
    let achievements: AchievementsManager
    private let analyticsTracker: AnalyticsTracking

    init(context: ModelContext, accountID: UUID? = nil) {
        self.accountID = accountID
        self.analyticsTracker = AppAnalyticsTracker()
        self.repository = AdviceRepository(
            context: context,
            accountKey: accountID?.uuidString ?? "__default__"
        )
        self.localModelStore = LocalModelStore()
        self.settings = SettingsViewModel(repository: repository, localModelStore: localModelStore)
        self.achievements = AchievementsManager(context: context)
        self.generate = GenerateViewModel(
            repository: repository,
            settingsViewModel: settings,
            analyticsTracker: analyticsTracker,
            achievementsManager: achievements
        )
        self.favorites = FavoritesViewModel(
            repository: repository,
            analyticsTracker: analyticsTracker
        )
        self.history = HistoryViewModel(
            repository: repository,
            analyticsTracker: analyticsTracker
        )
        self.quotes = QuotesViewModel(
            repository: repository,
            localModelStore: localModelStore,
            analyticsTracker: analyticsTracker
        )
        self.social = SocialViewModel()
        self.quotes.loadIfNeeded()
    }

    func refreshLists() {
        generate.invalidateRetentionSnapshot()
        favorites.reload()
        history.reload()
    }

    func preloadDebugPolishFixturesIfNeeded(seed: Int = 424_242) async {
        if repository.historyCount() > 0 {
            Self.logger.info("Debug polish preload skipped because history already exists")
            generate.debugPolishFixturesStatus = "ready"
            return
        }

        Self.logger.info("Debug polish preload starting")
        generate.debugPolishFixturesStatus = "loading"

        settings.preferredGenerationProvider = .classic
        settings.reduceMotion = true
        settings.hapticsEnabled = false

        let fixtures: [(category: AdviceCategory, tone: ToneMode, scenario: String, offset: Int)] =
            [
                (
                    .career,
                    .corporateConsultant,
                    "My manager asked for a status update and I have nothing finished.",
                    11
                ),
                (
                    .money,
                    .cryptoBro,
                    "I need a retirement plan but also want to feel like a genius this week.",
                    23
                ),
                (
                    .dating,
                    .toxicBestFriend,
                    "They take hours to reply and I want to seem mysterious.",
                    37
                ),
                (
                    .productivity,
                    .minimalistMonk,
                    "I have 40 tabs open and keep reorganizing instead of working.",
                    53
                ),
            ]

        for (index, fixture) in fixtures.enumerated() {
            generate.selectedCategory = fixture.category
            generate.selectedTone = fixture.tone
            generate.scenarioText = fixture.scenario
            generate.friendName = ""
            await generate.generate(seed: seed + fixture.offset)

            guard let record = generate.current else { continue }
            if index == 0 || index == 2 {
                repository.setFavorite(record, isFavorite: true)
            }
            switch index {
            case 0:
                repository.setVote(record, vote: .like)
                repository.incrementShareCount(for: record.id)
            case 1:
                repository.setVote(record, vote: .like)
                repository.incrementCopyCount(for: record.id)
            case 2:
                repository.setVote(record, vote: .dislike)
            case 3:
                repository.incrementCopyCount(for: record.id)
                repository.incrementShareCount(for: record.id)
            default:
                break
            }
        }

        _ = repository.addSuggestion(
            category: .career,
            topic: "Interview follow-up",
            adviceLine: "Wait six months so they know you are not desperate."
        )
        _ = repository.addSuggestion(
            category: .money,
            topic: "Budgeting",
            adviceLine: "If the card declines, that is your monthly budget report."
        )
        _ = repository.addQuoteSuggestion(
            category: .productivity,
            source: "Polish Seed",
            quoteText: "If a task takes two minutes, spend an hour choosing the perfect app for it."
        )

        refreshLists()
        generate.debugPolishFixturesStatus = "ready"
        Self.logger.info("Debug polish preload completed")
    }
}
