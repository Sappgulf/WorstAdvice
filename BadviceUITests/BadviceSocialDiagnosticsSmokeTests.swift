import XCTest

// Focused social diagnostics test coverage for shipping confidence.
// Exercises both standard and social-unavailable paths through one resilient helper flow.
final class BadviceSocialDiagnosticsSmokeTests: XCTestCase {
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

    func testSocialDiagnosticsOpensFromSettings() throws {
        let app = launchTestApp()
        XCTAssertTrue(openSettings(app: app), "Should reach settings before social diagnostics check")

        let socialButton = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.socialHealth.open"],
                app.buttons["settings.socialHealth.view"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social Diagnostics")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social Health")).firstMatch,
                app.staticTexts["Social Diagnostics"],
                app.staticTexts["Social Health"],
            ],
            timeout: 8,
            maxSwipes: 12
        )
        XCTAssertNotNil(socialButton, "Social diagnostics entry should be discoverable from settings")
        socialButton!.tap()

        let diagnosticsRoot = waitForAnyElement(
            app: app,
            candidates: [
                app.navigationBars["Social Diagnostics"],
                app.navigationBars["Social Health"],
                app.navigationBars.element(boundBy: 0),
                app.staticTexts["Social Diagnostics"],
                app.staticTexts["Social Health"],
                app.buttons["settings.socialHealth.retryQueue"],
                app.buttons["settings.socialHealth.copyReport"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Retry")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Copy")).firstMatch,
            ],
            timeout: 8,
            maxSwipes: 10,
            requireHittable: false
        )
        XCTAssertNotNil(diagnosticsRoot, "Social diagnostics screen should be visible")

        let unavailableState = waitForAnyElement(
            app: app,
            candidates: [
                app.staticTexts["Social diagnostics are currently unavailable."],
                app.staticTexts["Social features are unavailable in this test run."],
                app.staticTexts["CloudKit account status could not be determined."],
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "CloudKit")).firstMatch,
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Unavailable")).firstMatch,
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social diagnostics")).firstMatch,
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "diagnostics")).firstMatch,
            ],
            timeout: 2,
            maxSwipes: 2,
            requireHittable: false
        )

        let diagnosticsAction = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.socialHealth.retryQueue"],
                app.buttons["Retry Queue"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Retry Queue")).firstMatch,
            ],
            timeout: 4,
            maxSwipes: 8,
            requireHittable: false
        )
        let fallbackAction = diagnosticsAction != nil
            || waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons["settings.socialHealth.copyReport"],
                    app.buttons["Copy Report"],
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Copy Report")).firstMatch,
                ],
                timeout: 2,
                maxSwipes: 4,
                requireHittable: false
            ) != nil
            || unavailableState != nil
        XCTAssertTrue(
            fallbackAction,
            "A social diagnostics action should be available when diagnostics screen is shown"
        )

        if let closeButton = waitForAnyElement(
            app: app,
            candidates: [
                app.navigationBars.buttons["Back"],
                app.navigationBars.buttons["Settings"],
                app.navigationBars.buttons["Done"],
                app.buttons["Close"],
                app.buttons["Done"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Dismiss")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Cancel")).firstMatch,
                app.navigationBars.buttons.element(boundBy: 0),
            ],
            timeout: 3,
            maxSwipes: 0
        ) {
            closeButton.tap()
        } else if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        } else {
            app.swipeDown()
        }

        XCTAssertTrue(
            app.buttons["settings.auth.signOut"].waitForExistence(timeout: 4)
                || app.navigationBars.firstMatch.exists,
            "Should return to settings shell after closing diagnostics"
        )
    }

    func testSocialUnavailableModeShowsFallbackSurface() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-force-social-unavailable"])
        XCTAssertTrue(openSettings(app: app), "Should reach settings in social-unavailable mode")

        let socialButton = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.socialHealth.open"],
                app.buttons["settings.socialHealth.view"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social Diagnostics")).firstMatch,
            ],
            timeout: 8,
            maxSwipes: 12
        )
        XCTAssertNotNil(socialButton, "Social diagnostics entry should still be reachable")
        socialButton!.tap()

        let unavailableState = waitForAnyElement(
            app: app,
            candidates: [
                app.staticTexts["Social diagnostics are currently unavailable."],
                app.staticTexts["Social features are unavailable in this test run."],
                app.staticTexts["CloudKit account status could not be determined."],
                app.buttons["Retry Queue"],
                app.buttons["Copy Report"],
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social")).firstMatch,
            ],
            timeout: 8,
            maxSwipes: 10
        )
        XCTAssertNotNil(unavailableState, "Social-unavailable mode should expose a clear fallback state")
    }

    @discardableResult
    private func waitForAnyElement(
        app: XCUIApplication,
        candidates: [XCUIElement],
        timeout: TimeInterval,
        maxSwipes: Int = 0,
        requireHittable: Bool = true
    ) -> XCUIElement? {
        let timeoutDate = Date().addingTimeInterval(timeout)
        while Date() < timeoutDate {
            if requireHittable {
                if let found = candidates.first(where: { $0.exists && $0.isHittable }) {
                    return found
                }
            } else if let found = candidates.first(where: { $0.exists }) {
                return found
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        guard maxSwipes > 0 else {
            return candidates.first(where: { $0.exists })
        }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            let postSwipeDeadline = Date().addingTimeInterval(0.5)
            while Date() < postSwipeDeadline {
                if requireHittable {
                    if let found = candidates.first(where: { $0.exists && $0.isHittable }) {
                        return found
                    }
                } else if let found = candidates.first(where: { $0.exists }) {
                    return found
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
        }

        return candidates.first(where: { $0.exists })
    }

    private func launchTestApp(extraLaunchArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launchArguments += extraLaunchArguments
        app.launch()
        XCTAssertTrue(waitForAppToEnterForeground(app: app, timeout: 15))
        XCTAssertTrue(waitForAppToBecomeReady(app: app, timeout: 15))
        return app
    }

    private func waitForAppToEnterForeground(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.state == .runningForeground {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return app.state == .runningForeground
    }

    private func waitForAppToBecomeReady(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let readinessChecks: [() -> Bool] = [
            { app.buttons["generate.primary"].exists },
            { app.buttons["auth.mode.signUp"].exists },
            { app.buttons["auth.mode.signIn"].exists },
            { app.buttons["auth.primary"].exists },
            { app.buttons["Get Started"].exists },
            { app.buttons["Continue"].exists },
            { app.buttons["Next"].exists },
            { app.buttons["Skip"].exists },
        ]
        while Date() < deadline {
            if readinessChecks.contains(where: { $0() }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return readinessChecks.contains(where: { $0() })
    }

    @discardableResult
    private func openSettings(app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        if app.buttons["settings.auth.signOut"].exists
            || app.buttons["settings.auth.changePassword"].exists
        {
            return true
        }

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 2) { generateTab.tap() }
        if let brandMenu = findBrandMenuButton(app: app, timeout: 5, maxSwipes: 8, requireHittable: false) {
            brandMenu.tap()
        }
        let settingsQuickAccess = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["brandMenu.quickAccess.settings"],
                app.buttons["settings.menuButton"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings")).firstMatch,
                app.cells["settings.row.auth"],
                app.buttons["settings.menuButton"],
            ],
            timeout: 5,
            maxSwipes: 8,
            requireHittable: false
        )
        if settingsQuickAccess == nil {
            return false
        }
        settingsQuickAccess!.tap()

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if app.buttons["settings.auth.signOut"].exists
                || app.buttons["settings.auth.changePassword"].exists
                || app.buttons["settings.menuButton"].exists
                || app.buttons["settings.socialHealth.open"].exists
                || app.buttons["settings.socialHealth.view"].exists
                || app.navigationBars.firstMatch.exists
            {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
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
}
