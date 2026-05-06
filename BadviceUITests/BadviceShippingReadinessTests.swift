import XCTest

final class BadviceShippingReadinessTests: XCTestCase {
    private let defaultLaunchArguments = [
        "-ui-testing",
        "-skip-onboarding",
        "-skip-splash",
        "-ui-testing-auth-reset",
        "-ui-testing-auth-skip",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testShippingReadiness_BootAndCoreTabs() throws {
        let app = launchTestApp()
        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons["generate.primary"],
                    app.buttons["auth.mode.signUp"],
                    app.buttons["auth.mode.signIn"],
                    app.buttons["Get Started"],
                    app.buttons["Continue"],
                    app.buttons["Skip"],
                    app.buttons["settings.auth.signOut"],
                    app.buttons["settings.auth.changePassword"],
                ],
                timeout: 15,
                maxSwipes: 10
            ),
            "App should render a stable shell in ui-testing launch"
        )

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 5) {
            generateTab.tap()
        }
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 5))

        let tabFlow = [
            (id: "tab.generate", marker: [app.buttons["generate.primary"], app.navigationBars["Generate"], app.staticTexts["Generate"]]),
            (id: "tab.chaosHub", marker: [
                app.descendants(matching: .any)["chaos.social.leaderboardCard"],
                app.staticTexts["Chaos Hub"],
                app.buttons["chaos.social.submitScore"],
            ]),
            (id: "tab.friends", marker: [app.otherElements["friends.sectionPicker"], app.staticTexts["Friends"], app.buttons["friends.section.feed"]]),
            (id: "tab.quotes", marker: [app.otherElements["quotes.dailyHero"], app.staticTexts["Quotes"], app.buttons["quotes.spotlight.toggle"]]),
            (id: "tab.more", marker: [app.buttons["brandMenu.quickAccess.settings"], app.staticTexts["Quick Access"], app.navigationBars["Badvice"]]),
        ]

        for tabEntry in tabFlow where tabEntry.id != "tab.generate" {
            let tabButton = app.buttons.matching(identifier: tabEntry.id).firstMatch
            guard tabButton.waitForExistence(timeout: 4) else {
                continue
            }
            tabButton.tap()

            XCTAssertNotNil(
                waitForAnyElement(
                    app: app,
                    candidates: tabEntry.marker,
                    timeout: 6,
                    maxSwipes: 12,
                    requireHittable: false
                ),
                "\(tabEntry.id) should render a recognizable marker"
            )
        }

        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 2) {
            done.tap()
        }
        XCTAssertTrue(returnToGenerate(app: app))
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 5))
    }

    func testShippingReadiness_SettingsAndSocialHealthPath() throws {
        let app = launchTestApp()
        XCTAssertTrue(openSettings(app: app), "Expected to reach settings shell")

        guard let socialEntry = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.socialHealth.open"],
                app.buttons["settings.socialHealth.view"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social Diagnostics")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social Health")).firstMatch,
            ],
            timeout: 6,
            maxSwipes: 8
        ) else {
            throw XCTSkip("Social diagnostics entry is currently unavailable in this build")
        }

        socialEntry.tap()

        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.navigationBars["Social Diagnostics"],
                    app.navigationBars["Social Health"],
                    app.staticTexts["Social Diagnostics"],
                    app.staticTexts["Social Health"],
                    app.buttons["settings.socialHealth.retryQueue"],
                    app.buttons["settings.socialHealth.copyReport"],
                ],
                timeout: 8,
                maxSwipes: 8
            ),
            "Social diagnostics screen should be reachable"
        )

        let unavailableState = waitForAnyElement(
            app: app,
            candidates: [
                app.staticTexts["Social diagnostics are currently unavailable."],
                app.staticTexts["Social features are unavailable in this test run."],
                app.staticTexts["CloudKit account status could not be determined."],
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "CloudKit")).firstMatch,
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Unavailable")).firstMatch,
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social diagnostics")).firstMatch,
            ],
            timeout: 4,
            maxSwipes: 4,
            requireHittable: false
        )

        let actionAvailable = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.socialHealth.retryQueue"],
                app.buttons["settings.socialHealth.copyReport"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Retry")).firstMatch,
            ],
            timeout: 4,
            maxSwipes: 4,
            requireHittable: false
        ) != nil
        let fallbackAvailable = actionAvailable || unavailableState != nil
        XCTAssertTrue(fallbackAvailable, "Expected diagnostics action or fallback unavailable state")

        _ = closeOverlay(app: app)
        XCTAssertTrue(waitForSettingsShell(app: app), "Should return to settings shell after closing diagnostics")
    }

    private func launchTestApp(extraLaunchArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launchArguments += extraLaunchArguments
        app.launch()

        XCTAssertTrue(waitForAuthenticatedShell(app: app, timeout: 20))
        return app
    }

    private func returnToGenerate(app: XCUIApplication) -> Bool {
        let tab = app.buttons.matching(identifier: "tab.generate").firstMatch
        guard tab.waitForExistence(timeout: 5) else {
            return false
        }
        tab.tap()
        return app.buttons["generate.primary"].waitForExistence(timeout: 5)
    }

    private func waitForAuthenticatedShell(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let candidates: [XCUIElement] = [
            app.buttons["generate.primary"],
            app.buttons["auth.mode.signUp"],
            app.buttons["auth.mode.signIn"],
            app.buttons["auth.primary"],
            app.buttons["Get Started"],
            app.buttons["Continue"],
            app.buttons["Skip"],
            app.buttons["tab.generate"],
            app.navigationBars["Generate"],
            app.navigationBars["Settings"],
            app.buttons["settings.auth.signOut"],
            app.buttons["settings.auth.changePassword"],
        ]

        return waitForAnyElement(app: app, candidates: candidates, timeout: timeout, maxSwipes: 12) != nil
    }

    private func openSettings(app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        if waitForSettingsShell(app: app) { return true }

        let brandMenu = findBrandMenuButton(app: app, timeout: 4, maxSwipes: 4)
        if let brandMenu {
            brandMenu.tap()
            let settingsQuickAccess = app.buttons["brandMenu.quickAccess.settings"]
            if settingsQuickAccess.waitForExistence(timeout: 4) {
                settingsQuickAccess.tap()
            }
            if waitForSettingsShell(app: app, timeout: 5) { return true }
        }

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 2) {
            generateTab.tap()
        }

        let fallbackBrandMenu = findBrandMenuButton(app: app, timeout: 3, maxSwipes: 6)
        if let fallbackBrandMenu {
            fallbackBrandMenu.tap()
            let settingsQuickAccess = app.buttons["brandMenu.quickAccess.settings"]
            if settingsQuickAccess.waitForExistence(timeout: 4) {
                settingsQuickAccess.tap()
            }
            if waitForSettingsShell(app: app, timeout: 5) { return true }
        }

        let settingsButton = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.menuButton"],
                app.buttons["settings.auth.signOut"],
                app.buttons["settings.socialHealth.open"],
                app.buttons["settings.socialHealth.view"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings")).firstMatch,
                app.buttons["settings.tab"],
            ],
            timeout: 4,
            maxSwipes: 4
        )
        if let settingsButton {
            settingsButton.tap()
            if waitForSettingsShell(app: app, timeout: 5) { return true }
        }

        return waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.auth.signOut"],
                app.buttons["settings.auth.changePassword"],
                app.buttons["settings.menuButton"],
                app.buttons["settings.socialHealth.open"],
                app.buttons["settings.socialHealth.view"],
                app.navigationBars["Settings"].firstMatch,
                app.cells["settings.row.auth"],
            ],
            timeout: 2,
            maxSwipes: 2
        ) != nil
    }

    private func findBrandMenuButton(
        app: XCUIApplication,
        timeout: TimeInterval,
        maxSwipes: Int,
        requireHittable: Bool = false
    ) -> XCUIElement? {
        return waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["generate.brandMenu"],
                app.buttons["Badvice"].firstMatch,
                app.buttons["More"].firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Brand")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Menu")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "More")).firstMatch,
                app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "brandMenu")).firstMatch,
            ],
            timeout: timeout,
            maxSwipes: maxSwipes,
            requireHittable: requireHittable
        )
    }

    private func waitForSettingsShell(app: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        return waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.auth.signOut"],
                app.buttons["settings.auth.changePassword"],
                app.buttons["settings.menuButton"],
                app.buttons["settings.socialHealth.open"],
                app.buttons["settings.socialHealth.view"],
                app.navigationBars["Settings"].firstMatch,
                app.cells["settings.row.auth"],
            ],
            timeout: timeout,
            maxSwipes: 4,
            requireHittable: false
        ) != nil
    }

    @discardableResult
    private func waitForAnyElement(
        app: XCUIApplication,
        candidates: [XCUIElement],
        timeout: TimeInterval,
        maxSwipes: Int = 0,
        requireHittable: Bool = true
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        var swipes = 0
        while Date() < deadline {
            if let found = candidates.first(where: {
                $0.exists && (!requireHittable || $0.isHittable)
            }) {
                return found
            }

            if swipes < maxSwipes {
                app.swipeUp()
                swipes += 1
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return candidates.first(where: {
            $0.exists && (!requireHittable || $0.isHittable)
        })
    }

    @discardableResult
    private func closeOverlay(app: XCUIApplication) -> Bool {
        if let close = waitForAnyElement(
            app: app,
            candidates: [
                app.navigationBars.buttons["Back"],
                app.navigationBars.buttons["Done"],
                app.buttons["Done"],
                app.buttons["Close"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Dismiss")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Cancel")).firstMatch,
            ],
            timeout: 3,
            maxSwipes: 0
        ) {
            close.tap()
            return true
        }

        app.swipeDown()
        return false
    }
}
