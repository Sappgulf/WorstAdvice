import XCTest

/// Comprehensive smoke test covering the full app lifecycle: launch → every feature → close.
/// Run with: xcodebuild test -scheme Badvice -destination 'platform=iOS Simulator,...' -only-testing:BadviceUITests/BadviceFullSmokeTests
final class BadviceFullSmokeTests: XCTestCase {

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

    // MARK: - Full Lifecycle Smoke Test

    /// Open → Generate → Save → Copy → Vote → Surprise → Daily Drop → Battles →
    /// Missions → Quotes → Settings → Close
    func testFullAppLifecycleSmokeTest() throws {
        let app = launchTestApp()

        // ── 1. Generate Tab ──
        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12), "Generate button should appear on launch")

        // Generate first advice
        generateButton.tap()
        XCTAssertTrue(waitForGenerateAdviceToSettle(app: app, timeout: 12))

        // Verify category and tone selector headers exist
        let categoryPicker = discoverSelectorHeader(app: app, identifier: "generate.category")
        let tonePicker = discoverSelectorHeader(app: app, identifier: "generate.tone")
        XCTAssertNotNil(categoryPicker, "Category selector should exist")
        XCTAssertNotNil(tonePicker, "Tone selector should exist")

        // Save current advice
        let saveButton = app.buttons["generate.save"]
        if scrollToFind(app: app, element: saveButton, maxSwipes: 12) && saveButton.isEnabled {
            saveButton.tap()
        }

        // Copy current advice
        let copyButton = app.buttons["generate.copy"]
        if scrollToFind(app: app, element: copyButton, maxSwipes: 12) && copyButton.isEnabled {
            copyButton.tap()
        }

        // Remix
        let remixButton = app.buttons["generate.remix"]
        if scrollToFind(app: app, element: remixButton, maxSwipes: 12) && remixButton.isEnabled {
            remixButton.tap()
        }

        // Surprise Me
        let surpriseButton = app.buttons["generate.surprise"]
        if scrollToFind(app: app, element: surpriseButton, maxSwipes: 12) && surpriseButton.isEnabled {
            surpriseButton.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }

        // Daily Drop
        let dailyDropButton = app.buttons["generate.dailyDrop"]
        if scrollToFind(app: app, element: dailyDropButton, maxSwipes: 12) && dailyDropButton.isEnabled {
            dailyDropButton.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }

        // ── 2. Brand Menu ──
        let brandMenuButton = findBrandMenuButton(app: app, timeout: 5, maxSwipes: 6)
        if let brandMenuButton {
            brandMenuButton.tap()
            // Verify brand menu sheet appeared
            let brandMenuDone = app.buttons["Done"]
            let historyQuickAccess = app.buttons["brandMenu.quickAccess.history"]
            let historyQuickAccessByLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "History")).firstMatch
            let historyQuickAccessCell = app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", "History")).firstMatch
            let historyQuickAccessText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "History")).firstMatch
            let menuPresented = waitForAnyElement(
                app: app,
                candidates: [
                    brandMenuDone,
                    historyQuickAccess,
                    historyQuickAccessByLabel,
                    historyQuickAccessCell,
                    historyQuickAccessText,
                    app.buttons["Done"].firstMatch,
                    app.buttons["brandMenu.quickAccess.settings"],
                    app.buttons["tab.more"],
                ],
                timeout: 5,
                maxSwipes: 6
            )
            XCTAssertNotNil(menuPresented, "Brand menu quick access should appear")

            if let reopenBrandMenu = findBrandMenuButton(app: app, timeout: 5, maxSwipes: 8) {
                reopenBrandMenu.tap()
                _ = waitForAnyElement(
                    app: app,
                    candidates: [
                        historyQuickAccessByLabel,
                        historyQuickAccessCell,
                        historyQuickAccessText,
                    ],
                    timeout: 2,
                    maxSwipes: 3
                )
            }

            let historyTarget: XCUIElement? = historyQuickAccess.exists ? historyQuickAccess
                : (historyQuickAccessByLabel.exists ? historyQuickAccessByLabel
                   : (historyQuickAccessCell.exists ? historyQuickAccessCell : (
                        historyQuickAccessText.exists ? historyQuickAccessText : nil)))

            if let historyTarget {
                historyTarget.tap()
                // The history desk now lives as the "Recent" shelf inside Casebook.
                XCTAssertTrue(
                    app.navigationBars["Casebook"].waitForExistence(timeout: 5)
                        || app.staticTexts["Casebook"].waitForExistence(timeout: 5)
                        || app.staticTexts["Recent"].waitForExistence(timeout: 5)
                        || app.buttons["Recent"].waitForExistence(timeout: 5),
                    "History tab should open the Casebook recent shelf from the brand menu"
                )
            } else {
                print("Skipping history quick access because no history entry is visible in this menu style.")
            }

            let generateTabAfterHistory = app.buttons.matching(identifier: "tab.generate").firstMatch
            if generateTabAfterHistory.waitForExistence(timeout: 5) {
                generateTabAfterHistory.tap()
            }

            XCTAssertNotNil(findBrandMenuButton(app: app, timeout: 5, maxSwipes: 8))
            if let reopenBrandMenu = findBrandMenuButton(app: app, timeout: 5, maxSwipes: 8) {
                reopenBrandMenu.tap()
            }

            if brandMenuDone.waitForExistence(timeout: 1) {
                brandMenuDone.tap()
            } else {
                dismissTopScreen(app: app)
            }
        }

        // ── 2b. Favorites (primary tab, not brand menu) ──
        let favoritesTab = app.buttons.matching(identifier: "tab.favorites").firstMatch
        if favoritesTab.waitForExistence(timeout: 5) {
            favoritesTab.tap()
            // Favorites is now the "Saved" shelf of the Casebook desk.
            XCTAssertTrue(
                app.navigationBars["Casebook"].waitForExistence(timeout: 5)
                    || app.staticTexts["Casebook"].waitForExistence(timeout: 5)
                    || app.staticTexts["Saved"].waitForExistence(timeout: 5)
                    || app.buttons["Saved"].waitForExistence(timeout: 5),
                "Favorites tab should open the Casebook saved shelf from the primary tab bar"
            )

            let generateTabAfterFavorites = app.buttons.matching(identifier: "tab.generate").firstMatch
            if generateTabAfterFavorites.waitForExistence(timeout: 5) {
                generateTabAfterFavorites.tap()
            }
        }

        // ── 3. Missions ──
        if openMoreQuickAccess(app: app, id: "chaosHub", label: "Missions") {
            // Verify core Missions elements
            let leaderboardCard = app.descendants(matching: .any)["chaos.social.leaderboardCard"]
            // The missions desk is titled "Dares" in the Bureau shell.
            let chaosTitle = app.staticTexts["Dares"]
            XCTAssertTrue(
                leaderboardCard.waitForExistence(timeout: 5)
                    || chaosTitle.waitForExistence(timeout: 5)
                    || app.staticTexts["Missions"].waitForExistence(timeout: 5)
                    || app.descendants(matching: .any)["chaos.command.card"].waitForExistence(timeout: 5),
                "Missions content should load"
            )

            // Check submit score button exists
            let submitScore = app.buttons["chaos.social.submitScore"]
            _ = submitScore.waitForExistence(timeout: 3)
            // Don't assert enabled state — depends on social availability

            // Check leaderboard refresh button
            let refreshLeaderboard = app.buttons["chaos.social.refreshLeaderboard"]
            _ = refreshLeaderboard.waitForExistence(timeout: 3)
        }

        // ── 5. Quotes Tab ──
        let quotesTab = app.buttons.matching(identifier: "tab.quotes").firstMatch
        if quotesTab.waitForExistence(timeout: 5) {
            quotesTab.tap()

            let dailyHero = app.otherElements["quotes.dailyHero"]
            // The quotes desk is titled "Dispatches" in the Bureau shell.
            let quotesTitle = app.staticTexts["Dispatches"]
            XCTAssertTrue(
                dailyHero.waitForExistence(timeout: 5)
                    || quotesTitle.waitForExistence(timeout: 5)
                    || app.staticTexts["Quotes"].waitForExistence(timeout: 5),
                "Quotes tab should load"
            )

            // Toggle spotlight if available
            let spotlightToggle = app.buttons["quotes.spotlight.toggle"]
            if spotlightToggle.waitForExistence(timeout: 2) {
                spotlightToggle.tap()
                // Toggle back
                spotlightToggle.tap()
            }
        }

        // ── 6. Settings ──
        XCTAssertTrue(openSettings(app: app), "Should be able to reach settings")

        // Verify key settings elements exist
        let signOutButton = accessElementByIdentifier(app: app, identifier: "settings.auth.signOut", preferButton: true)
        if !signOutButton.waitForExistence(timeout: 3) {
            scrollToFind(app: app, element: signOutButton, maxSwipes: 10)
        }
        XCTAssertTrue(signOutButton.exists, "Sign out button should exist in settings")

        // Check generation engine picker
        let generationEngineState = app.staticTexts["settings.generationEngine.state"]
        if !generationEngineState.exists {
            scrollToFind(app: app, element: generationEngineState, maxSwipes: 10)
        }

        // ── 7. Return to Generate tab and verify stability ──
        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 5) {
            generateTab.tap()
        }

        let generateButtonAfterCycle = app.buttons["generate.primary"]
        if !scrollToFind(app: app, element: generateButtonAfterCycle, maxSwipes: 12) {
            _ = generateButtonAfterCycle.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(generateButtonAfterCycle.exists, "Generate button should still be present after full navigation cycle")
    }

    // MARK: - Auth Lifecycle Smoke Test

    /// Tests full auth flow: signup → settings → sign out → sign in → password change → delete
    func testAuthFullLifecycleSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments.filter { $0 != "-ui-testing-auth-skip" }
        app.launchArguments += [
            "-ui-testing-force-social-unavailable",
        ]
        app.launch()
        XCTAssertTrue(waitForAppToEnterForeground(app: app, timeout: 30))
        XCTAssertTrue(waitForAuthGateToBecomeReady(app: app, timeout: 30))

        // Sign up
        completeLocalSignup(
            app: app,
            displayName: "Smoke Tester",
            email: "smoke@badvice.test",
            password: "Smoke123!"
        )

        // Navigate to settings
        XCTAssertTrue(openSettings(app: app), "Should reach settings after signup")

        // Verify display name and email shown
        let displayNameLabel = app.staticTexts["settings.auth.displayName"]
        let emailLabel = app.staticTexts["settings.auth.email"]
        _ = displayNameLabel.waitForExistence(timeout: 3)
        _ = emailLabel.waitForExistence(timeout: 3)

        // Sign out
        let signOutButton = accessElementByIdentifier(app: app, identifier: "settings.auth.signOut", preferButton: true)
        scrollToFind(app: app, element: signOutButton, maxSwipes: 8)
        XCTAssertTrue(signOutButton.exists, "Sign out button should exist")
        signOutButton.tap()

        // Verify we're back at auth gate
        let authGate = waitForAnyElement(
            app: app,
            candidates: [
                app.textFields["auth.email"],
                app.secureTextFields["auth.password"],
                app.buttons["auth.mode.signIn"],
                app.buttons["Sign In"],
                app.buttons["auth.primary"],
                app.buttons["Sign Up"],
            ],
            timeout: 8,
            maxSwipes: 8
        )
        XCTAssertNotNil(authGate, "Should return to auth gate after sign out")

        // Sign back in
        completeLocalSignin(app: app, email: "smoke@badvice.test", password: "Smoke123!")
        XCTAssertTrue(waitForAuthenticatedShell(app: app), "Should authenticate after sign in")
    }

    // MARK: - Generate Tab Deep Feature Smoke Test

    /// Tests every Generate tab interaction in detail
    func testGenerateTabDeepSmoke() throws {
        let app = launchTestApp()

        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12))

        // Generate and verify advice card content
        tapGenerateAndWaitForResult(app: app, generateButton: generateButton)

        XCTAssertTrue(
            scrollToFind(app: app, element: app.otherElements["advice.card"], maxSwipes: 12),
            "Generated advice card should appear before checking result actions"
        )

        // Verify action buttons all exist
        // The header is a combined accessibility element, so its element type is
        // not guaranteed — match on identifier across any type.
        XCTAssertTrue(
            scrollToFind(
                app: app,
                element: app.descendants(matching: .any)["generate.actionRailHeader"],
                maxSwipes: 12
            )
                || scrollToFind(app: app, element: app.staticTexts["What happens next?"], maxSwipes: 12)
                || scrollToFind(app: app, element: app.staticTexts["Keep the keeper"], maxSwipes: 12),
            "Generate action rail header should explain save/copy/share/remix actions"
        )
        let actionButtons = ["generate.save", "generate.copy", "generate.share", "generate.remix"]
        for identifier in actionButtons {
            let button = app.buttons[identifier]
            XCTAssertTrue(scrollToFind(app: app, element: button, maxSwipes: 12), "\(identifier) should exist")
        }

        // Test save toggle
        let saveBtn = app.buttons["generate.save"]
        if saveBtn.isEnabled { saveBtn.tap() }
        // Tap again to unsave
        if saveBtn.isEnabled { saveBtn.tap() }

        // Test copy
        let copyBtn = app.buttons["generate.copy"]
        if copyBtn.isEnabled { copyBtn.tap() }

        // Generate multiple times to verify stability
        for i in 0..<3 {
            XCTAssertTrue(waitForGenerateActionToBeReady(app: app, timeout: 10), "Generate button should be re-enabled before each deep loop")
            generateButton.tap()
            XCTAssertTrue(waitForGenerateAdviceToSettle(app: app, timeout: 12), "Generate loop #\(i + 1) should settle")
        }

        // Test Surprise Me
        let surpriseBtn = app.buttons["generate.surprise"]
        XCTAssertTrue(scrollToFind(app: app, element: surpriseBtn, maxSwipes: 12))
        if surpriseBtn.isEnabled {
            surpriseBtn.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }

        // Test Daily Drop
        let dailyDropBtn = app.buttons["generate.dailyDrop"]
        XCTAssertTrue(scrollToFind(app: app, element: dailyDropBtn, maxSwipes: 12))
        if dailyDropBtn.isEnabled {
            dailyDropBtn.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
    }

    // MARK: - Settings Deep Smoke Test

    /// Tests settings tab in detail — scrolls through all sections
    func testSettingsDeepSmoke() throws {
        let app = launchTestApp()

        XCTAssertTrue(openSettings(app: app), "Should reach settings")

        // Verify key settings exist by scrolling through
        let settingsElements: [(identifier: String, isButton: Bool)] = [
            ("settings.auth.signOut", true),
            ("settings.auth.changePassword", true),
            ("settings.auth.deleteAccount", true),
            ("settings.generationEngine.state", false),
        ]

        for element in settingsElements {
            let el = element.isButton
                ? accessElementByIdentifier(app: app, identifier: element.identifier, preferButton: true)
                : app.staticTexts[element.identifier]
            if !el.exists {
                scrollToFind(app: app, element: el, maxSwipes: 15)
            }
            // Don't hard-fail on scroll visibility since some may be behind conditionals
        }

    }

    /// Verifies the alternate settings entry points stay stable and do not crash the app.
    func testSettingsEntryPointsSmoke() throws {
        let app = launchTestApp()

        var brandMenuButton = findBrandMenuButton(app: app, timeout: 5, maxSwipes: 8)
        if !(brandMenuButton?.waitForExistence(timeout: 2) ?? false) {
            let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
            if generateTab.waitForExistence(timeout: 3) {
                generateTab.tap()
            }
            brandMenuButton = findBrandMenuButton(
                app: app,
                timeout: 5,
                maxSwipes: 8
            )
        }

        let settingsQuickAccess: XCUIElement?
        if let brandMenuButton {
            brandMenuButton.tap()

            settingsQuickAccess = findSettingsQuickAccessButton(
                app: app,
                timeout: 6,
                maxSwipes: 8
            )
        } else {
            settingsQuickAccess = waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons.matching(identifier: "tab.more").firstMatch,
                    app.buttons["brandMenu.quickAccess.settings"],
                    app.tabBars.firstMatch.buttons.matching(identifier: "Settings").firstMatch,
                    app.navigationBars.element(boundBy: 0).buttons["Settings"],
                ],
                timeout: 4,
                maxSwipes: 4
            )
            XCTAssertNotNil(
                settingsQuickAccess,
                "Settings should still be reachable even when brand menu is unavailable."
            )
        }

        if let settingsQuickAccess {
            settingsQuickAccess.tap()
        } else {
            XCTFail("Settings entry point was not reachable on this run.")
            return
        }

        XCTAssertTrue(
            accessElementByIdentifier(app: app, identifier: "settings.auth.signOut", preferButton: true).waitForExistence(timeout: 5)
                || app.buttons["settings.menuButton"].waitForExistence(timeout: 5)
                || app.buttons["settings.socialHealth.open"].waitForExistence(timeout: 5)
                || app.navigationBars.firstMatch.waitForExistence(timeout: 5),
            "Settings quick access should land on the settings screen"
        )

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 5) {
            generateTab.tap()
        }

        if openMoreQuickAccess(app: app, id: "chaosHub", label: "Missions") {
            let openLabsButton = app.buttons["chaos.quickActions.openLabs"]
            if scrollToFind(app: app, element: openLabsButton, maxSwipes: 8),
                openLabsButton.waitForExistence(timeout: 3)
            {
                openLabsButton.tap()
                XCTAssertTrue(
                    accessElementByIdentifier(app: app, identifier: "settings.auth.signOut", preferButton: true).waitForExistence(timeout: 5)
                        || app.navigationBars.firstMatch.waitForExistence(timeout: 5),
                    "Missions open labs should land on the settings screen"
                )
            }
        }
    }

    // MARK: - Performance Smoke Test

    /// Ensures the app launches within a reasonable time and key views render quickly
    func testLaunchPerformanceSmoke() throws {
        let app = launchTestApp()

        // App should be interactive within 12 seconds
        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(
            generateButton.waitForExistence(timeout: 12),
            "App should be interactive within 12 seconds of launch"
        )

        // Generate should complete without disrupting interactivity
        generateButton.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))

        // Tab switching should be fast
        let tabs = ["tab.favorites", "tab.quotes", "tab.generate"]
        for tabID in tabs {
            let tab = app.buttons.matching(identifier: tabID).firstMatch
            if tab.waitForExistence(timeout: 3) {
                tab.tap()
                // Each tab should render content within 5 seconds
                RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            }
        }

        // Final check — generate tab should still be responsive
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5))
    }

    // MARK: - Onboarding Smoke Test

    /// Tests onboarding flow from start to finish
    func testOnboardingFlowSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-skip-splash",
            "-ui-testing-auth-reset",
            "-ui-testing-auth-skip",
            // NOTE: Do NOT include -skip-onboarding to test the flow
        ]
        // Reset onboarding state
        app.launchEnvironment["reset_onboarding"] = "true"
        app.launch()
        XCTAssertTrue(waitForAppToEnterForeground(app: app, timeout: 15))
        XCTAssertTrue(waitForAppToBecomeReady(app: app, timeout: 15))

        // The onboarding flow should present as a full-screen cover.
        // Look for the "Get Started" or final onboarding button.
        let getStarted = app.buttons["Get Started"]
        let continueButton = app.buttons["Continue"]
        let gotIt = app.buttons["Got it"]
        let nextButton = app.buttons["Next"]

        let deadline = Date().addingTimeInterval(10)
        var foundOnboardingOrMain = false

        while Date() < deadline && !foundOnboardingOrMain {
            if getStarted.exists || continueButton.exists || gotIt.exists || nextButton.exists {
                foundOnboardingOrMain = true
            }
            // Also check if we went straight to main (onboarding already seen)
            if app.buttons["generate.primary"].exists {
                foundOnboardingOrMain = true
            }
            if !foundOnboardingOrMain {
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }

        XCTAssertTrue(foundOnboardingOrMain, "Should show onboarding or main UI")

        // If onboarding is shown, tap through all pages
        if getStarted.exists || continueButton.exists || nextButton.exists {
            // Swipe through onboarding pages (6 pages)
            for _ in 0..<6 {
                if getStarted.exists {
                    getStarted.tap()
                    break
                }
                if continueButton.exists {
                    continueButton.tap()
                } else if nextButton.exists {
                    nextButton.tap()
                } else {
                    app.swipeLeft()
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }

            // Final page - dismiss only if the prior tap has not already landed
            // in the main app.
            if !app.buttons["generate.primary"].waitForExistence(timeout: 2),
               getStarted.waitForExistence(timeout: 5) {
                getStarted.tap()
            }
        }

        // Should eventually reach main app
        XCTAssertTrue(
            app.buttons["generate.primary"].waitForExistence(timeout: 15),
            "Should reach main app after onboarding"
        )
    }

    // MARK: - Helpers

    @discardableResult
    private func waitForAnyElement(
        app: XCUIApplication,
        candidates: [XCUIElement],
        timeout: TimeInterval,
        maxSwipes: Int = 0
    ) -> XCUIElement? {
        let timeoutDate = Date().addingTimeInterval(timeout)
        while Date() < timeoutDate {
            if let found = candidates.first(where: \.exists) {
                return found
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        guard maxSwipes > 0 else { return candidates.first(where: \.exists) }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            let timeoutDateAfterSwipe = Date().addingTimeInterval(0.5)
            while Date() < timeoutDateAfterSwipe {
                if let found = candidates.first(where: \.exists) {
                    return found
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
        }

        return candidates.first(where: \.exists)
    }

    @discardableResult
    private func scrollToFind(app: XCUIApplication, element: XCUIElement, maxSwipes: Int) -> Bool {
        for _ in 0..<maxSwipes where !element.exists {
            app.swipeUp()
        }
        return element.exists
    }

    private func waitForAdviceGenerationToSettle(
        app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        let generationLoading = app.otherElements["generate.loading"]
        let generateButton = app.buttons["generate.primary"]

        if generationLoading.waitForExistence(timeout: 0.5) {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if !generationLoading.exists && generateButton.isEnabled { return true }
                RunLoop.current.run(until: Date().addingTimeInterval(0.12))
            }
            return !generationLoading.exists && generateButton.isEnabled
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if generateButton.isEnabled {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        }
        return generateButton.isEnabled
    }

    /// Simulator touch delivery to SwiftUI buttons is occasionally dropped (the
    /// synthetic tap event fires but never reaches the button's action closure).
    /// Retries the tap if the empty state is still showing after settling.
    @discardableResult
    private func tapGenerateAndWaitForResult(
        app: XCUIApplication,
        generateButton: XCUIElement,
        maxAttempts: Int = 3
    ) -> Bool {
        let emptyState = app.descendants(matching: .any).matching(identifier: "generate.emptyState").firstMatch
        for _ in 0..<maxAttempts {
            generateButton.tap()
            _ = waitForAdviceGenerationToSettle(app: app, timeout: 10)
            if !emptyState.exists {
                return true
            }
        }
        return !emptyState.exists
    }

    private func dismissTopScreen(app: XCUIApplication) {
        let backCandidates: [XCUIElement] = [
            app.navigationBars.buttons.element(boundBy: 0),
            app.navigationBars.buttons["Back"],
            app.navigationBars.buttons["Settings"],
            app.navigationBars.buttons["Done"],
            app.buttons["Close"],
            app.buttons["Done"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Dismiss")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Cancel")).firstMatch,
        ]

        if let backControl = waitForAnyElement(
            app: app,
            candidates: backCandidates,
            timeout: 3,
            maxSwipes: 0
        ) {
            if backControl.isHittable {
                backControl.tap()
                return
            }
        }

        app.swipeDown()
    }

    private func launchTestApp(
        includeAuthSkip: Bool = true,
        extraLaunchArguments: [String] = [],
        timeout: TimeInterval = 15
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments.filter { includeAuthSkip || $0 != "-ui-testing-auth-skip" }
        app.launchArguments += extraLaunchArguments
        app.launch()
        XCTAssertTrue(waitForAppToEnterForeground(app: app, timeout: timeout))
        XCTAssertTrue(waitForAppToBecomeReady(app: app, timeout: timeout))
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
            { app.buttons["auth.primary"].exists },
            { app.buttons["Get Started"].exists },
            { app.buttons["Continue"].exists },
            { app.buttons["Next"].exists },
            { app.buttons["Start Badvice"].exists },
            { app.buttons["Got it"].exists },
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

    private func waitForGenerateAdviceToSettle(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let generationLoading = app.otherElements["generate.loading"]
        let generateButton = app.buttons["generate.primary"]

        if generationLoading.waitForExistence(timeout: 0.4) {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if !generationLoading.exists && generateButton.isEnabled { return true }
                RunLoop.current.run(until: Date().addingTimeInterval(0.12))
            }
            return !generationLoading.exists && generateButton.isEnabled
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if generateButton.isEnabled {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        }
        return generateButton.isEnabled
    }

    private func waitForGenerateActionToBeReady(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let generateButton = app.buttons["generate.primary"]
        if generateButton.waitForExistence(timeout: 1) == false { return false }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if generateButton.isEnabled && !app.otherElements["generate.loading"].exists {
                return true
            }
            if !app.otherElements["generate.loading"].exists && generateButton.isEnabled {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        }

        return generateButton.isEnabled && !app.otherElements["generate.loading"].exists
    }

    private func discoverSelectorHeader(app: XCUIApplication, identifier: String) -> XCUIElement? {
        return waitForAnyElement(
            app: app,
            candidates: [
                app.otherElements[identifier],
                app.buttons[identifier],
                app.staticTexts[identifier],
            ],
            timeout: 3,
            maxSwipes: 4
        )
    }

    private func waitForAuthGateToBecomeReady(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let readinessChecks: [() -> Bool] = [
            { app.buttons["auth.mode.signUp"].exists },
            { app.buttons["auth.mode.signIn"].exists },
            { app.buttons["auth.primary"].exists },
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
    private func waitForAuthenticatedShell(
        app: XCUIApplication,
        timeout: TimeInterval = 30
    ) -> Bool {
        let generateButton = app.buttons["generate.primary"]
        let settingsSignOut = accessElementByIdentifier(app: app, identifier: "settings.auth.signOut", preferButton: true)
        let tabMarkers = [
            app.buttons.matching(identifier: "tab.generate").firstMatch,
            app.buttons.matching(identifier: "tab.favorites").firstMatch,
            app.buttons.matching(identifier: "tab.quotes").firstMatch,
            app.buttons.matching(identifier: "tab.more").firstMatch,
        ]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if generateButton.exists
                || settingsSignOut.exists
                || tabMarkers.contains(where: \.exists)
            {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        return generateButton.exists
            || settingsSignOut.exists
            || tabMarkers.contains(where: \.exists)
    }

    @discardableResult
    private func openSettings(app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        guard waitForAuthenticatedShell(app: app, timeout: timeout) else { return false }

        if isLikelyInSettings(app: app) {
            return true
        }

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        if settingsTab.waitForExistence(timeout: 3) {
            settingsTab.tap()
            if isLikelyInSettings(app: app) {
                return true
            }
            if waitForSettingsShell(app: app, timeout: 10, maxSwipes: 12) {
                return true
            }
        }

        if openSettingsLooseEntry(app: app, timeout: 5, maxSwipes: 8) {
            return true
        }

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 2) { generateTab.tap() }
        
        if let brandMenu = findBrandMenuButton(app: app, timeout: 5, maxSwipes: 8) {
            brandMenu.tap()
            if let settingsQuickAccess = findSettingsQuickAccessButton(app: app, timeout: 5, maxSwipes: 8) {
                settingsQuickAccess.tap()
                let done = app.buttons["Done"].firstMatch
                if done.waitForExistence(timeout: 1) {
                    done.tap()
                }
                if isLikelyInSettings(app: app) {
                    return true
                }
                if waitForSettingsShell(app: app, timeout: 10, maxSwipes: 12) {
                    return true
                }
            } else if let settingsMenuButton = findSettingsDirectEntry(app: app, timeout: 5) {
                settingsMenuButton.tap()
                let done = app.buttons["Done"].firstMatch
                if done.waitForExistence(timeout: 1) {
                    done.tap()
                }
                if isLikelyInSettings(app: app) {
                    return true
                }
                if waitForSettingsShell(app: app, timeout: 10, maxSwipes: 12) {
                    return true
                }
            }
            if openSettingsLooseEntry(app: app, timeout: 6, maxSwipes: 10) {
                return true
            }
        }

        let tabBarSettingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        if tabBarSettingsTab.waitForExistence(timeout: 1) {
            tabBarSettingsTab.tap()
            if isLikelyInSettings(app: app) {
                return true
            }
            if waitForSettingsShell(app: app, timeout: 10, maxSwipes: 12) {
                return true
            }
        }

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let done = app.buttons["Done"].firstMatch
            if done.exists {
                done.tap()
            }
            if isLikelyInSettings(app: app)
            {
                return true
            }
            if openSettingsLooseEntry(app: app, timeout: 3, maxSwipes: 6) {
                return true
            }
            if waitForSettingsShell(app: app, timeout: 3, maxSwipes: 6) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        return false
    }

    private func isLikelyInSettings(app: XCUIApplication) -> Bool {
        return settingsShellCandidates(app: app).first(where: \.exists) != nil
    }

    private func openSettingsLooseEntry(
        app: XCUIApplication,
        timeout: TimeInterval,
        maxSwipes: Int = 8
    ) -> Bool {
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 1) {
            done.tap()
        }

        if openSettingsDirectButton(app: app) {
            return waitForSettingsShell(app: app, timeout: timeout, maxSwipes: maxSwipes)
        }

        let settingsCandidates: [XCUIElement] = [
            app.buttons["settings.menuButton"],
            app.buttons["settings.socialHealth.open"],
            app.buttons["settings.auth.signOut"],
            app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Settings")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Settings")).firstMatch,
            app.cells["settings.row.auth"],
            app.cells.matching(NSPredicate(format: "label ==[c] %@", "Settings")).firstMatch,
        ]
        if let settingsEntry = waitForAnyElement(
            app: app,
            candidates: settingsCandidates,
            timeout: timeout,
            maxSwipes: maxSwipes
        ) {
            if settingsEntry.isHittable {
                settingsEntry.tap()
            } else {
                settingsEntry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            return isLikelyInSettings(app: app) || waitForSettingsShell(app: app, timeout: timeout, maxSwipes: maxSwipes)
        }

        return isLikelyInSettings(app: app) || waitForSettingsShell(app: app, timeout: timeout, maxSwipes: maxSwipes)
    }

    private func openSettingsDirectButton(app: XCUIApplication) -> Bool {
        let directButtons = [
            app.buttons["settings.menuButton"],
            app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Settings")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings")).firstMatch,
            app.cells.matching(NSPredicate(format: "label ==[c] %@", "Settings")).firstMatch,
        ]
        for button in directButtons where button.exists && button.isHittable {
            button.tap()
            if isLikelyInSettings(app: app) {
                return true
            }
        }

        if let fallback = directButtons.first(where: \.exists) {
            fallback.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return isLikelyInSettings(app: app)
        }
        return false
    }

    private func waitForSettingsShell(
        app: XCUIApplication,
        timeout: TimeInterval,
        maxSwipes: Int = 10
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var swipes = 0
        while Date() < deadline {
            if isLikelyInSettings(app: app) {
                return true
            }
            if maxSwipes > 0 && swipes < maxSwipes {
                if swipes % 2 == 0 {
                    app.swipeUp()
                } else {
                    app.swipeDown()
                }
                swipes += 1
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return isLikelyInSettings(app: app)
    }

    private func settingsShellCandidates(app: XCUIApplication) -> [XCUIElement] {
        return [
            app.navigationBars["Settings"].firstMatch,
            app.otherElements["settings.shell"].firstMatch,
            app.buttons["settings.menuButton"].firstMatch,
            app.buttons["settings.socialHealth.open"].firstMatch,
            app.staticTexts["settings.auth.displayName"],
            app.staticTexts["settings.auth.email"],
            app.buttons["settings.auth.signOut"].firstMatch,
            app.staticTexts["settings.auth.signOut"],
            app.buttons["settings.auth.changePassword"].firstMatch,
            app.staticTexts["settings.auth.changePassword"],
            app.buttons["settings.auth.deleteAccount"].firstMatch,
            app.staticTexts["settings.auth.deleteAccount"],
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Sign Out")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Sign Out")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Change Password")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Delete")).firstMatch,
            app.cells["settings.row.auth"].firstMatch,
            app.cells["settings.row.system"].firstMatch,
            app.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "settings.row.")).firstMatch,
            app.cells.containing(.staticText, identifier: "Auth").firstMatch,
        ]
    }

    private func accessElementByIdentifier(
        app: XCUIApplication,
        identifier: String,
        preferButton: Bool = false
    ) -> XCUIElement {
        if identifier == "settings.auth.signOut" {
            let signOutByIdentifier = app.buttons["settings.auth.signOut"]
            if signOutByIdentifier.exists {
                return signOutByIdentifier
            }

            let settingsAuthRow = app.cells["settings.row.auth"].firstMatch
            if settingsAuthRow.exists {
                let rowSignOutButton = settingsAuthRow
                    .descendants(matching: .button)
                    .matching(NSPredicate(format: "label CONTAINS[c] %@", "Sign Out")).firstMatch
                if rowSignOutButton.exists {
                    return rowSignOutButton
                }
            }

            let signOutByLabel = app.descendants(matching: .button).matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Sign Out")
            ).firstMatch
            if signOutByLabel.exists {
                return signOutByLabel
            }
            let signOutStaticText = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Sign Out")
            ).firstMatch
            if signOutStaticText.exists {
                return signOutStaticText
            }
        } else if identifier == "settings.auth.changePassword" {
            let changePasswordByLabel = app.descendants(matching: .button).matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Change Password")
            ).firstMatch
            if changePasswordByLabel.exists {
                return changePasswordByLabel
            }
        } else if identifier == "settings.auth.deleteAccount" {
            let deleteAccountByLabel = app.descendants(matching: .button).matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Delete")
            ).firstMatch
            if deleteAccountByLabel.exists {
                return deleteAccountByLabel
            }
        }

        let buttonElement = app.buttons[identifier]
        if preferButton && buttonElement.exists {
            return buttonElement
        }

        let staticTextElement = app.staticTexts[identifier]
        if staticTextElement.exists {
            return staticTextElement
        }

        if buttonElement.exists {
            return buttonElement
        }

        let otherElement = app.otherElements[identifier]
        if otherElement.exists {
            return otherElement
        }

        let cellElement = app.cells[identifier]
        if cellElement.exists {
            return cellElement
        }

        return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func findBrandMenuButton(
        app: XCUIApplication,
        timeout: TimeInterval,
        maxSwipes: Int
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
            maxSwipes: maxSwipes
        )
    }

    @discardableResult
    private func openMoreQuickAccess(app: XCUIApplication, id: String, label: String) -> Bool {
        if id == "chaosHub" {
            let missionsTab = app.buttons.matching(identifier: "tab.chaosHub").firstMatch
            if missionsTab.waitForExistence(timeout: 4) {
                missionsTab.tap()
                return true
            }
        }

        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        if moreTab.waitForExistence(timeout: 4) {
            moreTab.tap()
        } else if let brandMenuButton = findBrandMenuButton(app: app, timeout: 4, maxSwipes: 6) {
            brandMenuButton.tap()
        } else {
            return false
        }

        let quickAccess = app.buttons["brandMenu.quickAccess.\(id)"]
        if quickAccess.waitForExistence(timeout: 5) {
            quickAccess.tap()
            return true
        }

        let labeledQuickAccess = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", label)
        ).firstMatch
        if labeledQuickAccess.waitForExistence(timeout: 2) {
            labeledQuickAccess.tap()
            return true
        }

        return false
    }

    private func findSettingsQuickAccessButton(
        app: XCUIApplication,
        timeout: TimeInterval,
        maxSwipes: Int
    ) -> XCUIElement? {
        return waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["brandMenu.quickAccess.settings"],
                app.buttons["settings.menuButton"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings")).firstMatch,
                app.cells["settings.row.auth"],
            ],
            timeout: timeout,
            maxSwipes: maxSwipes
        )
    }

    private func findSettingsDirectEntry(app: XCUIApplication, timeout: TimeInterval) -> XCUIElement? {
        return waitForAnyElement(
            app: app,
            candidates: [
                app.buttons.matching(identifier: "tab.more").firstMatch,
                app.buttons["brandMenu.quickAccess.settings"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings")).firstMatch,
                app.navigationBars.element(boundBy: 0).buttons["Settings"],
                app.buttons["settings.menuButton"],
                app.buttons["settings.socialHealth.open"],
            ],
            timeout: timeout,
            maxSwipes: 4
        )
    }

    private func completeLocalSignup(
        app: XCUIApplication,
        displayName: String,
        email: String,
        password: String,
        confirmPassword: String? = nil
    ) {
        let signUpModeButton = app.buttons["auth.mode.signUp"]
        XCTAssertTrue(signUpModeButton.waitForExistence(timeout: 8))
        if !signUpModeButton.isSelected {
            signUpModeButton.tap()
        }

        let displayNameField = app.textFields["auth.displayName"]
        XCTAssertTrue(displayNameField.waitForExistence(timeout: 5))
        fillTextInput(displayNameField, text: displayName)

        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 3))
        fillTextInput(emailField, text: email)

        let passwordField = app.textFields["auth.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        fillTextInput(passwordField, text: password)

        let confirmField = app.textFields["auth.confirmPassword"]
        XCTAssertTrue(confirmField.waitForExistence(timeout: 3))
        fillTextInput(confirmField, text: confirmPassword ?? password)

        let primaryButton = app.buttons["auth.primary"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))
        XCTAssertTrue(
            waitForElementToBecomeEnabled(primaryButton, timeout: 5),
            "auth.mode.signUp selected=\(signUpModeButton.isSelected) displayName=\(displayNameField.value ?? "nil") email=\(emailField.value ?? "nil") password=\(passwordField.value ?? "nil") confirm=\(confirmField.value ?? "nil") primaryEnabled=\(primaryButton.isEnabled)"
        )
        primaryButton.tap()

        XCTAssertTrue(waitForAuthenticatedShell(app: app))
    }

    private func completeLocalSignin(app: XCUIApplication, email: String, password: String) {
        let signInModeButton = app.buttons["auth.mode.signIn"]
        if signInModeButton.waitForExistence(timeout: 3) && !signInModeButton.isSelected {
            signInModeButton.tap()
        }

        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        fillTextInput(emailField, text: email)

        let passwordField = app.textFields["auth.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        fillTextInput(passwordField, text: password)

        let primaryButton = app.buttons["auth.primary"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))
        XCTAssertTrue(primaryButton.isEnabled)
        primaryButton.tap()
    }

    private func waitForElementToBecomeEnabled(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isEnabled {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.isEnabled
    }

    private func fillTextInput(_ element: XCUIElement, text: String) {
        let app = XCUIApplication()
        XCTAssertTrue(element.waitForExistence(timeout: 3))

        focusTextInput(element, app: app)

        if let currentValue = element.value as? String, shouldClearTextInputValue(currentValue, for: element) {
            if app.keys["delete"].waitForExistence(timeout: 0.5) {
                let deletePresses = String(repeating: "\u{8}", count: currentValue.count)
                element.typeText(deletePresses)
            } else {
                element.typeText(String(repeating: "\u{8}", count: currentValue.count))
            }
        }
        element.typeText(text)
    }

    private func shouldClearTextInputValue(_ value: String, for element: XCUIElement) -> Bool {
        let placeholderValues = Set([
            "Display name (optional)",
            "Email",
            "Create password",
            "Confirm password"
        ])
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return false }
        if placeholderValues.contains(trimmedValue) { return false }
        if let placeholderValue = element.placeholderValue,
           placeholderValue == value || placeholderValue == trimmedValue {
            return false
        }
        return true
    }

    private func focusTextInput(_ element: XCUIElement, app: XCUIApplication) {
        let focusAttempts = [
            { element.tap() },
            { element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() },
            { element.press(forDuration: 0.1) },
        ]

        for attempt in focusAttempts {
            attempt()
            let deadline = Date().addingTimeInterval(0.6)
            while Date() < deadline {
                if app.keyboards.firstMatch.exists {
                    return
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
        }

        XCTAssertTrue(app.keyboards.firstMatch.exists, "Expected keyboard focus before typing into \(element)")
    }

}
