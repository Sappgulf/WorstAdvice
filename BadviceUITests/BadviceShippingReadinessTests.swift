import XCTest

final class BadviceShippingReadinessTests: BadviceUITestCase {
    func testThemeSelectionPersistsAcrossRelaunch() {
        let app = launch()
        openSettings(app, advanced: true)
        tap("settings.theme.ember", in: app)
        XCTAssertTrue((app.buttons["settings.theme.ember"].value as? String ?? "").hasPrefix("Selected"))
        capture("Ember theme", app: app)
        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-onboarding", "-skip-splash"]
        app.launch()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 15))
        openSettings(app)
        let theme = app.buttons["Theme, Ember"]
        reveal(theme, in: app)
        XCTAssertTrue(theme.exists)
    }

    func testAchievementsCommunityAndIncludedFeatures() {
        let app = launch()
        openSettings(app, advanced: true)
        tap("settings.row.achievements", in: app)
        XCTAssertTrue(app.navigationBars["Achievements"].waitForExistence(timeout: 8))
        tap("Locked", in: app)
        capture("Locked achievements", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("settings.row.community.pulse", in: app)
        XCTAssertTrue(app.navigationBars["Community Pulse"].waitForExistence(timeout: 8))
        capture("Community pulse", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("settings.upgradeStore", in: app)
        XCTAssertTrue(app.navigationBars["Included"].waitForExistence(timeout: 8))
        XCTAssertTrue(control("upgrade.included", in: app).waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Restore Purchases"].exists)
        capture("Included features", app: app)
        tap("upgrade.packs", in: app)
        XCTAssertTrue(app.navigationBars["Offline Packs"].waitForExistence(timeout: 8))
        XCTAssertTrue(control("offlinePacks.selection", in: app).exists)
    }

    func testBundledPackSelectionPersistsAndFeedsTheGenerator() {
        let app = launch()
        openSettings(app, advanced: true)
        tap("settings.row.offline.packs", in: app)
        XCTAssertTrue(app.staticTexts["Ten packs. Zero signal required."].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Download"].exists)
        tap("offlinePacks.pack.officeMeltdown", in: app)
        XCTAssertEqual(app.buttons["offlinePacks.pack.officeMeltdown"].value as? String, "Selected, available offline")
        capture("Bundled offline packs", app: app)

        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-onboarding", "-skip-splash"]
        app.launch()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 15))
        openSettings(app)
        XCTAssertTrue(app.buttons["Content pack, Office Meltdown"].waitForExistence(timeout: 8))
        tap("tab.generate", in: app)
        generate(app)
        XCTAssertTrue(control("advice.text", in: app).exists)
    }

    func testBracketCompletesSharesAndStartsAnotherTournament() {
        let app = launch()
        tap("tab.chaosHub", in: app)
        tap("Advice bracket", in: app)

        for match in 0..<7 {
            let left = app.buttons["bracket.left"]
            reveal(left, in: app)
            let previousAdvice = app.buttons["bracket.right"].label
            left.tap()
            if match < 6 {
                let nextMatch = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "label != %@ AND enabled == true", previousAdvice),
                    object: app.buttons["bracket.right"]
                )
                XCTAssertEqual(XCTWaiter.wait(for: [nextMatch], timeout: 5), .completed)
            }
        }

        XCTAssertTrue(app.staticTexts["Champion"].waitForExistence(timeout: 5))
        capture("Bracket champion", app: app)
        tap("Share Champion", in: app)
        let close = app.buttons["header.closeButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["New Bracket"].isHittable, "The share sheet must be presented above the game")
        capture("Bracket champion export", app: app)
        XCTAssertTrue(close.isHittable)
        close.tap()
        tap("New Bracket", in: app)
        XCTAssertTrue(app.buttons["bracket.left"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["bracket.right"].isEnabled)
    }

    func testShippingReadiness_BootAndCoreTabs() {
        let app = launch()
        for (id, title) in [("generate", "badvice."), ("favorites", "Saved & recent"), ("chaosHub", "Play"), ("quotes", "The daily bad idea")] {
            tap("tab.\(id)", in: app)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 8))
            capture("Core tab — \(id)", app: app)
        }
        tap("tab.more", in: app)
        tap("brandMenu.quickAccess.explore", in: app)
        XCTAssertTrue(app.staticTexts["The status meeting"].waitForExistence(timeout: 8))
        app.staticTexts["The status meeting"].tap()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["generate.situation"].value as? String == "I need to explain a project delay without sounding worried.")
    }

    func testShippingReadiness_SettingsAndSocialHealthPath() {
        let app = launch(extra: ["-ui-testing-force-social-unavailable"])
        openSettings(app, advanced: true)
        tap("settings.socialHealth.open", in: app)
        XCTAssertTrue(control("settings.socialHealth.report", in: app).waitForExistence(timeout: 8))
        capture("Social health", app: app)
    }
}
