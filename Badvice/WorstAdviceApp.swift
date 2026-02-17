import SwiftData
import SwiftUI
import UserNotifications
import OSLog

@main
struct WorstAdviceApp: App {
    private static let logger = Logger(subsystem: "com.worstadvice.app", category: "bootstrap")

    private let container: ModelContainer = {
        let schema = Schema([
            AdviceRecord.self,
            AdviceFingerprint.self,
            UserAdviceSuggestion.self,
            UserQuoteSuggestion.self,
            QuoteVoteRecord.self,
            LearningStatRecord.self,
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
                fatalError("Failed to initialize SwiftData store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationManager.requestPermissionAndScheduleDaily()
                }
        }
        .modelContainer(container)
    }
}
