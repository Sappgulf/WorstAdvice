import SwiftData
import SwiftUI
import UserNotifications
import OSLog

@main
struct WorstAdviceApp: App {
    private static let logger = Logger(subsystem: "com.worstadvice.app", category: "bootstrap")
    private static let legacySettingsCleanupVersionKey = "migrations.legacySettingsCleanup.v1"
    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-ui-testing") }
    private var isDebugPolishFixtureLaunch: Bool { ProcessInfo.processInfo.arguments.contains("-debug-preload-polish-fixtures") }

    private let container: ModelContainer = {
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

        let cloudConfiguration = ModelConfiguration(
            "BadviceCloud",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .automatic
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [cloudConfiguration])
            Self.logger.info("SwiftData CloudKit store initialized")
            return container
        } catch {
            Self.logger.error("CloudKit store init failed, falling back to local store: \(error.localizedDescription, privacy: .public)")
            let fallbackConfiguration = ModelConfiguration(
                "BadviceLocalFallback",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .none
            )
            do {
                let container = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                Self.logger.info("SwiftData fallback local store initialized")
                return container
            } catch {
                Self.logger.error(
                    "Local fallback store init failed, using in-memory store: \(error.localizedDescription, privacy: .public)"
                )
                let inMemoryConfiguration = ModelConfiguration(
                    "BadviceInMemoryFallback",
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    allowsSave: true,
                    groupContainer: .none,
                    cloudKitDatabase: .none
                )
                do {
                    let container = try ModelContainer(
                        for: schema, configurations: [inMemoryConfiguration])
                    Self.logger.info("SwiftData in-memory fallback store initialized")
                    return container
                } catch {
                    fatalError("Failed to initialize SwiftData store: \(error)")
                }
            }
        }
    }()

    init() {
        Self.runLegacySettingsCleanupIfNeeded()
        AppPerformanceInstrumentation.beginColdStartIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    guard !isUITesting, !isDebugPolishFixtureLaunch else { return }
                    NotificationManager.requestPermissionAndScheduleDaily()
                }
        }
        .modelContainer(container)
    }

    private static func runLegacySettingsCleanupIfNeeded(userDefaults: UserDefaults = .standard) {
        guard !userDefaults.bool(forKey: legacySettingsCleanupVersionKey) else { return }
        let staleKeys = ["soundEffectsEnabled", "seasonalEffectsEnabled"]
        for key in staleKeys where userDefaults.object(forKey: key) != nil {
            userDefaults.removeObject(forKey: key)
            logger.info("Removed legacy defaults key \(key, privacy: .public)")
        }
        userDefaults.set(true, forKey: legacySettingsCleanupVersionKey)
    }
}
