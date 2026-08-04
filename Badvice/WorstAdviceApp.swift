import OSLog
import SwiftData
import SwiftUI
import UserNotifications
import AppIntents

enum PersistentStoreDirectoryPreparer {
    @discardableResult
    static func prepareApplicationSupportDirectory(
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let directory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        try prepareDirectory(at: directory, fileManager: fileManager)
        return directory
    }

    static func prepareDirectory(
        at directory: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }
}

@main
struct WorstAdviceApp: App {
    private static let logger = Logger(subsystem: "com.worstadvice.app", category: "bootstrap")
    private static let legacySettingsCleanupVersionKey = "migrations.legacySettingsCleanup.v1"

    private static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }

    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-ui-testing") }
    private var isDebugPolishFixtureLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-debug-preload-polish-fixtures")
    }

    private var shouldBootstrapCloudKitOnLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-cloudkit-bootstrap-on-launch")
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    @State private var startupErrorMessage: String?
    private let container: ModelContainer?

    init() {
        let bootstrapResult = Self.makeBootstrapContainer()
        self.container = bootstrapResult.container
        _startupErrorMessage = State(initialValue: bootstrapResult.errorMessage)
        Self.runLegacySettingsCleanupIfNeeded()
        NotificationManager.configureResponseHandling()
        AppPerformanceInstrumentation.beginColdStartIfNeeded()
        if #available(iOS 16.0, *),
            !isUITesting,
            !isDebugPolishFixtureLaunch,
            !isRunningTests
        {
            BadviceShortcuts.updateAppShortcutParameters()
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView()
                    .task {
                        guard !isUITesting, !isDebugPolishFixtureLaunch, !isRunningTests else {
                            return
                        }
                        #if DEBUG
                            guard shouldBootstrapCloudKitOnLaunch else { return }
                            _ = await CloudKitSchemaSeeder.seedIfNeeded()
                            if !Self.isRunningOnSimulator {
                                await CloudKitDebugSanityChecker.runFriendsReachabilityCheck()
                            }
                        #endif
                    }
                    .onAppear {
                        guard !isUITesting,
                            !isDebugPolishFixtureLaunch,
                            !isRunningTests,
                            !Self.isRunningOnSimulator
                        else { return }
                        NotificationManager.requestPermissionAndScheduleDaily()
                    }
                    .modelContainer(container)
            } else {
                StartupFailureView(
                    message: startupErrorMessage ?? "Badvice could not initialize storage."
                )
            }
        }
    }

    private static func makeBootstrapContainer() -> (container: ModelContainer?, errorMessage: String?) {
        let schema = Schema([
            AdviceRecord.self,
            AdviceFingerprint.self,
            UserAdviceSuggestion.self,
            UserQuoteSuggestion.self,
            QuoteVoteRecord.self,
            LearningStatRecord.self,
            MissionProgressRecord.self,
            AchievementProgressRecord.self,
            AppSettingsEntity.self,
        ])

        do {
            try PersistentStoreDirectoryPreparer.prepareApplicationSupportDirectory()
        } catch {
            Self.logger.warning(
                "Could not prepare Application Support before opening SwiftData: \(error.localizedDescription, privacy: .public)"
            )
        }

        if Self.isRunningOnSimulator {
            let simulatorConfiguration = ModelConfiguration(
                "BadviceSimulator",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .none
            )
            do {
                let container = try ModelContainer(for: schema, configurations: [simulatorConfiguration])
                Self.logger.info("SwiftData simulator store initialized")
                return (container, nil)
            } catch {
                Self.logger.error(
                    "Simulator store init failed, using in-memory fallback: \(error.localizedDescription, privacy: .public)"
                )
                let inMemoryConfiguration = ModelConfiguration(
                    "BadviceSimulatorFallback",
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    allowsSave: true,
                    groupContainer: .none,
                    cloudKitDatabase: .none
                )
                do {
                    let container = try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
                    Self.logger.info("SwiftData simulator in-memory fallback initialized")
                    return (container, nil)
                } catch {
                    let message = "Failed to initialize the simulator storage layer."
                    Self.logger.critical(
                        "\(message, privacy: .public) Error: \(error.localizedDescription, privacy: .public)"
                    )
                    return (nil, message)
                }
            }
        }

        // NOTE: the local persistence schema (AdviceRecord, AppSettingsEntity, etc.) uses
        // unique constraints and non-optional fields throughout, which CloudKit's Core Data
        // integration does not support. A `cloudKitDatabase: .automatic` configuration for
        // this schema always fails NSCocoaErrorDomain 134060 validation, on every launch,
        // on real devices — it is not a transient condition. Cross-device sync for social
        // data is handled separately by the CKRecord-based Social layer (CloudKitStore.swift),
        // so go straight to the local store rather than pay for a doomed attempt on every
        // cold launch (this container is built synchronously before any UI renders).
        let localConfiguration = ModelConfiguration(
            "BadviceLocalFallback",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [localConfiguration])
            Self.logger.info("SwiftData local store initialized")
            return (container, nil)
        } catch {
            Self.logger.error(
                "Local store init failed, using in-memory store: \(error.localizedDescription, privacy: .public)"
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
                    for: schema, configurations: [inMemoryConfiguration]
                )
                Self.logger.info("SwiftData in-memory fallback store initialized")
                return (container, nil)
            } catch {
                let message = "Badvice storage could not be initialized."
                Self.logger.critical(
                    "\(message, privacy: .public) Error: \(error.localizedDescription, privacy: .public)"
                )
                return (nil, message)
            }
        }
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

private struct StartupFailureView: View {
    let message: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.14, green: 0.08, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.orange)

                Text("Badvice could not start")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text("Check the console logs for the storage error and relaunch after fixing it.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .padding(24)
        }
    }
}
