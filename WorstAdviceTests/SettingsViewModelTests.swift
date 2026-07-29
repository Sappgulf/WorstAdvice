import SwiftData
import XCTest
@testable import Badvice

@MainActor
final class SettingsViewModelTests: XCTestCase {
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
            "SettingsTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    func testSettingsDefaultValues() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertEqual(session.settings.theme, .badvice)
        XCTAssertTrue(session.settings.hapticsEnabled)
        XCTAssertFalse(session.settings.reduceMotion)
        XCTAssertFalse(session.settings.performanceMode)
        XCTAssertTrue(session.settings.dailyNotificationsEnabled)
        XCTAssertTrue(session.settings.streakNotificationsEnabled)
        XCTAssertEqual(session.settings.preferredIntensity, .bold)
    }
    
    func testSettingsThemeChange() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertEqual(session.settings.theme, .badvice)
        
        session.settings.theme = .ember
        XCTAssertEqual(session.settings.theme, .ember)
        
        session.settings.theme = .neon
        XCTAssertEqual(session.settings.theme, .neon)
    }
    
    func testSettingsReduceMotionToggle() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertFalse(session.settings.reduceMotion)
        
        session.settings.reduceMotion = true
        XCTAssertTrue(session.settings.reduceMotion)
        
        session.settings.reduceMotion = false
        XCTAssertFalse(session.settings.reduceMotion)
    }
    
    func testSettingsHapticsToggle() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertTrue(session.settings.hapticsEnabled)
        
        session.settings.hapticsEnabled = false
        XCTAssertFalse(session.settings.hapticsEnabled)
        
        session.settings.hapticsEnabled = true
        XCTAssertTrue(session.settings.hapticsEnabled)
    }
    
    func testSettingsPerformanceMode() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertFalse(session.settings.performanceMode)
        
        session.settings.performanceMode = true
        XCTAssertTrue(session.settings.performanceMode)
    }
    
    func testSettingsNotificationPreferences() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertTrue(session.settings.dailyNotificationsEnabled)
        XCTAssertTrue(session.settings.streakNotificationsEnabled)
        
        session.settings.dailyNotificationsEnabled = true
        XCTAssertTrue(session.settings.dailyNotificationsEnabled)
        
        session.settings.streakNotificationsEnabled = true
        XCTAssertTrue(session.settings.streakNotificationsEnabled)
    }
    
    func testSettingsSharePreferences() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertTrue(session.settings.includeDisclaimerOnShare)
        XCTAssertEqual(session.settings.preferredTemplate, .caseFile)
        XCTAssertEqual(session.settings.preferredAspect, .square)
        
        session.settings.includeDisclaimerOnShare = false
        XCTAssertFalse(session.settings.includeDisclaimerOnShare)
        
        session.settings.preferredTemplate = .bold
        XCTAssertEqual(session.settings.preferredTemplate, .bold)
        
        session.settings.preferredAspect = .story
        XCTAssertEqual(session.settings.preferredAspect, .story)
    }

    func testSettingsPersistsBadviceDialSelection() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let repository = AdviceRepository(context: context)
        let settings = SettingsViewModel(repository: repository)

        settings.preferredIntensity = .legendaryMistake

        XCTAssertEqual(settings.preferredIntensity, .legendaryMistake)
        XCTAssertEqual(repository.ensureSettings().preferredIntensityRaw, 5)
    }
    
    func testSettingsContentPack() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertEqual(session.settings.preferredContentPack, .classic)
        
        session.settings.preferredContentPack = .officeMeltdown
        XCTAssertEqual(session.settings.preferredContentPack, .officeMeltdown)
        
        session.settings.preferredContentPack = .weekendChaos
        XCTAssertEqual(session.settings.preferredContentPack, .weekendChaos)
    }
    
    func testSettingsGenerationProvider() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertEqual(session.settings.preferredGenerationProvider, .classic)
        
        session.settings.preferredGenerationProvider = .classic
        XCTAssertEqual(session.settings.preferredGenerationProvider, .classic)
    }

    func testLegacyAutoProviderMigratesToLocalBureauEngine() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let legacySettings = AppSettingsEntity(preferredGenerationProvider: .auto)
        context.insert(legacySettings)
        try context.save()

        let repository = AdviceRepository(context: context)
        let settings = SettingsViewModel(repository: repository)

        XCTAssertEqual(settings.preferredGenerationProvider, .classic)
        XCTAssertEqual(repository.ensureSettings().preferredGenerationProvider, .classic)
    }

    func testLaunchLocalModelPreparationSkipsClassicProvider() async throws {
        let container = try makeInMemoryContainer()
        let repository = AdviceRepository(context: ModelContext(container))
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent(
            "SettingsClassicLocalModelTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let suiteName = "SettingsClassicLocalModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let localModelStore = LocalModelStore(
            fileManager: fileManager,
            userDefaults: defaults,
            bundle: .main,
            appSupportBaseURLOverride: tempRoot,
            includeSystemModelWhenFrameworkMissing: true
        )
        let settings = SettingsViewModel(repository: repository, localModelStore: localModelStore)

        settings.preferredGenerationProvider = .classic
        await settings.prepareAppleLocalModelForLaunchIfNeeded(
            systemMaxPollCount: 0,
            systemPollDelay: .milliseconds(1)
        )

        XCTAssertNil(settings.selectedAppleLocalModelID)
        XCTAssertTrue(settings.appleLocalModels.isEmpty)
    }

    func testLaunchLocalModelPreparationSelectsSystemModelOnColdStart() async throws {
        let container = try makeInMemoryContainer()
        let repository = AdviceRepository(context: ModelContext(container))
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent(
            "SettingsLocalModelTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let suiteName = "SettingsLocalModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let localModelStore = LocalModelStore(
            fileManager: fileManager,
            userDefaults: defaults,
            bundle: .main,
            appSupportBaseURLOverride: tempRoot,
            includeSystemModelWhenFrameworkMissing: true
        )
        let settings = SettingsViewModel(repository: repository, localModelStore: localModelStore)

        settings.preferredGenerationProvider = .appleOnDevice
        await settings.prepareAppleLocalModelForLaunchIfNeeded(
            systemMaxPollCount: 0,
            systemPollDelay: .milliseconds(1)
        )

        let systemModel = try XCTUnwrap(settings.appleLocalModels.first(where: { $0.isSystemModel }))
        XCTAssertEqual(settings.selectedAppleLocalModelID, systemModel.id)
        XCTAssertFalse(settings.isPreparingAppleOnDeviceModel)
    }
    
    func testSettingsIncludeRationale() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertTrue(session.settings.includeRationale)
        
        session.settings.includeRationale = true
        XCTAssertTrue(session.settings.includeRationale)
    }
    
    func testSettingsTabOrder() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        let tabOrder = session.settings.tabOrder
        XCTAssertTrue(tabOrder.contains(.generate))
        XCTAssertTrue(tabOrder.contains(.chaosHub))
        XCTAssertTrue(tabOrder.contains(.quotes))
        XCTAssertTrue(tabOrder.contains(.favorites))
        XCTAssertTrue(tabOrder.contains(.history))
    }
    
    func testSettingsDailyNotificationHour() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertEqual(session.settings.dailyNotificationHour, 9)
        
        session.settings.dailyNotificationHour = 18
        XCTAssertEqual(session.settings.dailyNotificationHour, 18)
    }
}
