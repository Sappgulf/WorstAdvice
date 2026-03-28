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
        XCTAssertFalse(session.settings.dailyNotificationsEnabled)
        XCTAssertFalse(session.settings.streakNotificationsEnabled)
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
        
        XCTAssertFalse(session.settings.dailyNotificationsEnabled)
        XCTAssertFalse(session.settings.streakNotificationsEnabled)
        
        session.settings.dailyNotificationsEnabled = true
        XCTAssertTrue(session.settings.dailyNotificationsEnabled)
        
        session.settings.streakNotificationsEnabled = true
        XCTAssertTrue(session.settings.streakNotificationsEnabled)
    }
    
    func testSettingsSharePreferences() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertTrue(session.settings.includeDisclaimerOnShare)
        XCTAssertEqual(session.settings.preferredTemplate, .gradient)
        XCTAssertEqual(session.settings.preferredAspect, .square)
        
        session.settings.includeDisclaimerOnShare = false
        XCTAssertFalse(session.settings.includeDisclaimerOnShare)
        
        session.settings.preferredTemplate = .classic
        XCTAssertEqual(session.settings.preferredTemplate, .classic)
        
        session.settings.preferredAspect = .story
        XCTAssertEqual(session.settings.preferredAspect, .story)
    }
    
    func testSettingsContentPack() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertEqual(session.settings.preferredContentPack, .classic)
        
        session.settings.preferredContentPack = .officeMeltdown
        XCTAssertEqual(session.settings.preferredContentPack, .officeMeltdown)
        
        session.settings.preferredContentPack = .datingDisaster
        XCTAssertEqual(session.settings.preferredContentPack, .datingDisaster)
    }
    
    func testSettingsGenerationProvider() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertEqual(session.settings.preferredGenerationProvider, .appleOnDevice)
        
        session.settings.preferredGenerationProvider = .classic
        XCTAssertEqual(session.settings.preferredGenerationProvider, .classic)
    }
    
    func testSettingsIncludeRationale() async throws {
        let container = try makeInMemoryContainer()
        let session = AppSessionViewModel(context: ModelContext(container))
        
        XCTAssertFalse(session.settings.includeRationale)
        
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
