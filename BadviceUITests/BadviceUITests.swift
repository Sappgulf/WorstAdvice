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

    func testSmokeNavigationAndCoreInteractions() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launch()

        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12))
        generateButton.tap()

        let adviceCard = app.otherElements["advice.card"]
        XCTAssertTrue(adviceCard.waitForExistence(timeout: 15))

        let saveButton = app.buttons["Save"]
        if saveButton.waitForExistence(timeout: 2) {
            saveButton.tap()
        }

        let quotesTab = app.buttons.matching(identifier: "tab.quotes").firstMatch
        XCTAssertTrue(quotesTab.waitForExistence(timeout: 5))
        quotesTab.tap()

        _ = app.otherElements["quotes.dailyHero"].waitForExistence(timeout: 3)
        let spotlightToggle = app.buttons["quotes.spotlight.toggle"]
        if spotlightToggle.waitForExistence(timeout: 2) {
            spotlightToggle.tap()
        }

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        XCTAssertTrue(generateTab.waitForExistence(timeout: 5))
        generateTab.tap()
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5))
    }

    func testSmokeTabReachabilityFromFreshLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launch()

        let chaosTab = app.buttons.matching(identifier: "tab.chaosHub").firstMatch
        XCTAssertTrue(chaosTab.waitForExistence(timeout: 5))
        chaosTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["chaos.social.leaderboardCard"].waitForExistence(timeout: 5)
                || app.staticTexts["Chaos Hub"].waitForExistence(timeout: 5)
        )

        let friendsTab = app.buttons.matching(identifier: "tab.friends").firstMatch
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 5))
        friendsTab.tap()
        XCTAssertTrue(
            app.segmentedControls["friends.sectionPicker"].waitForExistence(timeout: 5)
                || app.staticTexts["Friends"].waitForExistence(timeout: 5)
        )

        let favoritesTab = app.buttons.matching(identifier: "tab.favorites").firstMatch
        XCTAssertTrue(favoritesTab.waitForExistence(timeout: 5))
        favoritesTab.tap()
        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 5)
                || app.staticTexts["Favorites"].waitForExistence(timeout: 5)
        )

        let historyTab = app.buttons.matching(identifier: "tab.history").firstMatch
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 5)
                || app.staticTexts["History"].waitForExistence(timeout: 5)
        )
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
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))

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

    func testSettingsAppleLocalModelShowsListOrExplicitEmptyState() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launch()

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))

        let appleModelStatus = app.staticTexts["settings.appleModel.status"]
        let appleModelEmpty = app.staticTexts["settings.appleModel.empty"]
        if !appleModelStatus.waitForExistence(timeout: 2) && !appleModelEmpty.exists {
            for _ in 0..<12 where !appleModelStatus.exists && !appleModelEmpty.exists {
                app.swipeUp()
            }
        }

        XCTAssertTrue(
            appleModelStatus.exists || appleModelEmpty.exists,
            "Expected Apple Local Model card to show a status or explicit empty state."
        )

        if appleModelEmpty.exists {
            XCTAssertTrue(
                app.buttons["settings.appleModel.recheck"].exists
                    || app.buttons["settings.appleModel.prepare"].exists
            )
        }
    }

    func testSmokeSocialSurfacesWhenUnavailable() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments + [
            "-ui-testing-force-social-unavailable"
        ]
        app.launch()

        let shareToFriends = app.buttons["generate.shareToFriends"]
        XCTAssertTrue(shareToFriends.waitForExistence(timeout: 12))
        XCTAssertFalse(shareToFriends.isEnabled)

        let chaosTab = app.buttons.matching(identifier: "tab.chaosHub").firstMatch
        XCTAssertTrue(chaosTab.waitForExistence(timeout: 5))
        chaosTab.tap()

        let leaderboardCard = app.descendants(matching: .any)["chaos.social.leaderboardCard"]
        let leaderboardTitle = app.staticTexts["Season Leaderboard"]
        let unavailableMessage = app.staticTexts["Social features are unavailable in this test run."]
        XCTAssertTrue(
            leaderboardCard.waitForExistence(timeout: 3)
                || leaderboardTitle.waitForExistence(timeout: 5)
                || unavailableMessage.waitForExistence(timeout: 5)
        )

        let submitScore = app.buttons["chaos.social.submitScore"]
        if !submitScore.exists {
            _ = submitScore.waitForExistence(timeout: 2)
        }
        if submitScore.exists {
            XCTAssertFalse(submitScore.isEnabled)
        }

        let friendsTab = app.buttons.matching(identifier: "tab.friends").firstMatch
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 5))
        friendsTab.tap()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["Social features are unavailable in this test run."]
                .waitForExistence(timeout: 5)
        )

        let sectionPicker = app.segmentedControls["friends.sectionPicker"]
        XCTAssertTrue(sectionPicker.waitForExistence(timeout: 3))

        let feedSegment = app.buttons["Feed"]
        if feedSegment.exists { feedSegment.tap() }
        let feedRefresh = app.buttons["friends.feedRefresh"]
        XCTAssertTrue(feedRefresh.waitForExistence(timeout: 3))
        XCTAssertFalse(feedRefresh.isEnabled)

        let collabSegment = app.buttons["Collab"]
        if collabSegment.exists { collabSegment.tap() }
        let newDoc = app.buttons["friends.newCollabDoc"]
        XCTAssertTrue(newDoc.waitForExistence(timeout: 3))
        XCTAssertFalse(newDoc.isEnabled)
    }
}
