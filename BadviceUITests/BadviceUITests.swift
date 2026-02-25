import XCTest

final class BadviceUITests: XCTestCase {
    private let defaultLaunchArguments = [
        "-ui-testing",
        "-skip-onboarding",
        "-skip-splash",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSmokeNavigationAndCoreInteractions() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launch()

        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12))
        attachScreenshot(named: "generate-tab-initial")
        generateButton.tap()

        let adviceCard = app.otherElements["advice.card"]
        XCTAssertTrue(adviceCard.waitForExistence(timeout: 15))
        attachScreenshot(named: "generate-tab-after-generate")

        let saveButton = app.buttons["Save"]
        if saveButton.waitForExistence(timeout: 2) {
            saveButton.tap()
        }

        let quotesTab = app.buttons.matching(identifier: "tab.quotes").firstMatch
        XCTAssertTrue(quotesTab.waitForExistence(timeout: 5))
        quotesTab.tap()
        attachScreenshot(named: "quotes-tab")

        _ = app.otherElements["quotes.dailyHero"].waitForExistence(timeout: 3)
        let spotlightToggle = app.buttons["quotes.spotlight.toggle"]
        if spotlightToggle.waitForExistence(timeout: 2) {
            spotlightToggle.tap()
        }

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        _ = app.staticTexts["Generation Engine"].waitForExistence(timeout: 2)
        attachScreenshot(named: "settings-tab")

        let chaosTab = app.buttons.matching(identifier: "tab.chaosHub").firstMatch
        XCTAssertTrue(chaosTab.waitForExistence(timeout: 5))
        chaosTab.tap()
        attachScreenshot(named: "chaos-hub-tab")

        let favoritesTab = app.buttons.matching(identifier: "tab.favorites").firstMatch
        XCTAssertTrue(favoritesTab.waitForExistence(timeout: 5))
        favoritesTab.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(named: "favorites-tab")

        let historyTab = app.buttons.matching(identifier: "tab.history").firstMatch
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(named: "history-tab")

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        XCTAssertTrue(generateTab.waitForExistence(timeout: 5))
        generateTab.tap()
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5))
        attachScreenshot(named: "generate-tab-return")
    }

    func testSettingsGenerationEnginePickerStateAfterDebugPolishSeedPreload() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments + [
            "-debug-preload-polish-fixtures",
            "-debug-polish-seed", "424242",
        ]
        app.launch()

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))

        let generationEngineState = app.staticTexts["settings.generationEngine.state"]
        if !generationEngineState.waitForExistence(timeout: 2) {
            for _ in 0..<20 where !generationEngineState.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(generationEngineState.waitForExistence(timeout: 2))

        let pickerLabel = generationEngineState.label
        let pickerValue = generationEngineState.value as? String ?? ""
        XCTAssertTrue(
            pickerLabel.localizedCaseInsensitiveContains("classic")
                || pickerValue.localizedCaseInsensitiveContains("classic"),
            "Expected Generation Engine picker to reflect Classic in UI-test mode. label=\(pickerLabel) value=\(pickerValue)"
        )
    }
}
