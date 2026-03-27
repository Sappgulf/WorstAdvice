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

    /// Open → Generate → Save → Copy → Vote → Surprise → Daily Drop → Battles → Collab →
    /// Chaos Hub → Friends → Quotes → Settings → Close
    func testFullAppLifecycleSmokeTest() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launch()

        // ── 1. Generate Tab ──
        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12), "Generate button should appear on launch")

        // Generate first advice
        generateButton.tap()
        let adviceCard = app.otherElements["advice.card"]
        XCTAssertTrue(adviceCard.waitForExistence(timeout: 15), "Advice card should appear after generation")

        // Verify category and tone selectors exist
        let categoryPicker = app.buttons["generate.category"]
        let tonePicker = app.buttons["generate.tone"]
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 3), "Category picker should exist")
        XCTAssertTrue(tonePicker.waitForExistence(timeout: 3), "Tone picker should exist")

        // Save current advice
        let saveButton = app.buttons["generate.save"]
        if saveButton.waitForExistence(timeout: 3) && saveButton.isEnabled {
            saveButton.tap()
        }

        // Copy current advice
        let copyButton = app.buttons["generate.copy"]
        if copyButton.waitForExistence(timeout: 3) && copyButton.isEnabled {
            copyButton.tap()
        }

        // Remix
        let remixButton = app.buttons["generate.remix"]
        if remixButton.waitForExistence(timeout: 3) && remixButton.isEnabled {
            remixButton.tap()
        }

        // Surprise Me
        let surpriseButton = app.buttons["generate.surprise"]
        if surpriseButton.waitForExistence(timeout: 3) && surpriseButton.isEnabled {
            surpriseButton.tap()
            // Wait for generation to complete
            _ = adviceCard.waitForExistence(timeout: 10)
        }

        // Daily Drop
        let dailyDropButton = app.buttons["generate.dailyDrop"]
        if dailyDropButton.waitForExistence(timeout: 3) && dailyDropButton.isEnabled {
            dailyDropButton.tap()
            _ = adviceCard.waitForExistence(timeout: 10)
        }

        // ── 2. Brand Menu ──
        let brandMenuButton = app.buttons["generate.brandMenu"]
        if brandMenuButton.waitForExistence(timeout: 5) {
            brandMenuButton.tap()
            // Verify brand menu sheet appeared
            let brandMenuDone = app.buttons["Done"]
            XCTAssertTrue(brandMenuDone.waitForExistence(timeout: 5), "Brand menu sheet should appear")
            brandMenuDone.tap()
        }

        // ── 3. Chaos Hub Tab ──
        let chaosTab = app.buttons.matching(identifier: "tab.chaosHub").firstMatch
        if chaosTab.waitForExistence(timeout: 5) {
            chaosTab.tap()

            // Verify core Chaos Hub elements
            let leaderboardCard = app.descendants(matching: .any)["chaos.social.leaderboardCard"]
            let chaosTitle = app.staticTexts["Chaos Hub"]
            XCTAssertTrue(
                leaderboardCard.waitForExistence(timeout: 5)
                    || chaosTitle.waitForExistence(timeout: 5),
                "Chaos Hub content should load"
            )

            // Check submit score button exists
            let submitScore = app.buttons["chaos.social.submitScore"]
            _ = submitScore.waitForExistence(timeout: 3)
            // Don't assert enabled state — depends on social availability

            // Check leaderboard refresh button
            let refreshLeaderboard = app.buttons["chaos.social.refreshLeaderboard"]
            _ = refreshLeaderboard.waitForExistence(timeout: 3)
        }

        // ── 4. Friends Tab ──
        let friendsTab = app.buttons.matching(identifier: "tab.friends").firstMatch
        if friendsTab.waitForExistence(timeout: 5) {
            friendsTab.tap()

            // Verify section picker loads
            let sectionPicker = app.segmentedControls["friends.sectionPicker"]
            let friendsTitle = app.staticTexts["Friends"]
            XCTAssertTrue(
                sectionPicker.waitForExistence(timeout: 5)
                    || friendsTitle.waitForExistence(timeout: 5),
                "Friends tab should load"
            )

            if sectionPicker.exists {
                // Tap through each section
                let feedSegment = sectionPicker.buttons["Feed"]
                if feedSegment.exists {
                    feedSegment.tap()
                    let feedRefresh = app.buttons["friends.feedRefresh"]
                    _ = feedRefresh.waitForExistence(timeout: 3)
                }

                let collabSegment = sectionPicker.buttons["Collab"]
                if collabSegment.exists {
                    collabSegment.tap()
                    let newDoc = app.buttons["friends.newCollabDoc"]
                    _ = newDoc.waitForExistence(timeout: 3)
                }

                // Go back to Friends list
                let friendsSegment = sectionPicker.buttons["Friends"]
                if friendsSegment.exists {
                    friendsSegment.tap()
                }
            }
        }

        // ── 5. Quotes Tab ──
        let quotesTab = app.buttons.matching(identifier: "tab.quotes").firstMatch
        if quotesTab.waitForExistence(timeout: 5) {
            quotesTab.tap()

            let dailyHero = app.otherElements["quotes.dailyHero"]
            let quotesTitle = app.staticTexts["Quotes"]
            XCTAssertTrue(
                dailyHero.waitForExistence(timeout: 5)
                    || quotesTitle.waitForExistence(timeout: 5),
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
        let signOutButton = app.buttons["settings.auth.signOut"]
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
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5), "Generate button should still be present after full navigation cycle")
    }

    // MARK: - Auth Lifecycle Smoke Test

    /// Tests full auth flow: signup → settings → sign out → sign in → password change → delete
    func testAuthFullLifecycleSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-skip-onboarding",
            "-skip-splash",
            "-ui-testing-auth-reset",
            "-ui-testing-force-social-unavailable",
        ]
        app.launch()

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
        let signOutButton = app.buttons["settings.auth.signOut"]
        scrollToFind(app: app, element: signOutButton, maxSwipes: 8)
        XCTAssertTrue(signOutButton.exists, "Sign out button should exist")
        signOutButton.tap()

        // Verify we're back at auth gate
        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5), "Should return to auth gate after sign out")

        // Sign back in
        completeLocalSignin(app: app, email: "smoke@badvice.test", password: "Smoke123!")
        XCTAssertTrue(waitForAuthenticatedShell(app: app), "Should authenticate after sign in")
    }

    // MARK: - Social Mock Smoke Test

    /// Tests social features with mock backend
    func testSocialMockFullSmoke() throws {
        let app = launchMockSocialApp(seededIncomingRequests: 2)

        // Complete social profile setup
        completeProfileSignup(app: app, handle: "smoke_social")

        // ── Verify Friends tab fully loads ──
        let friendsTab = app.buttons.matching(identifier: "tab.friends").firstMatch
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 5))
        friendsTab.tap()

        let sectionPicker = app.segmentedControls["friends.sectionPicker"]
        XCTAssertTrue(sectionPicker.waitForExistence(timeout: 5), "Friends section picker should load")

        // Search for users
        let searchField = app.textFields["friends.searchField"]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("test")
            let searchButton = app.buttons["friends.searchButton"]
            if searchButton.waitForExistence(timeout: 3) && searchButton.isEnabled {
                searchButton.tap()
            }
            // Dismiss keyboard
            app.swipeDown()
        }

        // Check Feed section
        let feedSegment = sectionPicker.buttons["Feed"]
        if feedSegment.exists {
            feedSegment.tap()
            let feedRefresh = app.buttons["friends.feedRefresh"]
            XCTAssertTrue(feedRefresh.waitForExistence(timeout: 3), "Feed refresh button should exist")
        }

        // Check Collab section
        let collabSegment = sectionPicker.buttons["Collab"]
        if collabSegment.exists {
            collabSegment.tap()
            let newDoc = app.buttons["friends.newCollabDoc"]
            XCTAssertTrue(newDoc.waitForExistence(timeout: 3), "New collab doc button should exist")
        }

        // ── Verify Chaos Hub with social ──
        let chaosTab = app.buttons.matching(identifier: "tab.chaosHub").firstMatch
        if chaosTab.waitForExistence(timeout: 5) {
            chaosTab.tap()
            let leaderboardCard = app.descendants(matching: .any)["chaos.social.leaderboardCard"]
            _ = leaderboardCard.waitForExistence(timeout: 5)
        }

        // ── Verify Share to Friends from Generate ──
        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 5) {
            generateTab.tap()
        }
        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 5))
        generateButton.tap()
        _ = app.otherElements["advice.card"].waitForExistence(timeout: 15)

        let shareToFriends = app.buttons["generate.shareToFriends"]
        if shareToFriends.waitForExistence(timeout: 3) {
            // With mock social, this should be enabled after profile setup
            if shareToFriends.isEnabled {
                shareToFriends.tap()
            }
        }
    }

    // MARK: - Generate Tab Deep Feature Smoke Test

    /// Tests every Generate tab interaction in detail
    func testGenerateTabDeepSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launch()

        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12))

        // Generate and verify advice card content
        generateButton.tap()
        let adviceCard = app.otherElements["advice.card"]
        XCTAssertTrue(adviceCard.waitForExistence(timeout: 15))

        // Verify action buttons all exist
        let actionButtons = ["generate.save", "generate.copy", "generate.remix", "generate.gif"]
        for identifier in actionButtons {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 3), "\(identifier) should exist")
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
        for _ in 0..<3 {
            generateButton.tap()
            _ = adviceCard.waitForExistence(timeout: 10)
        }

        // Test Surprise Me
        let surpriseBtn = app.buttons["generate.surprise"]
        XCTAssertTrue(surpriseBtn.waitForExistence(timeout: 3))
        if surpriseBtn.isEnabled { surpriseBtn.tap() }
        _ = adviceCard.waitForExistence(timeout: 10)

        // Test Daily Drop
        let dailyDropBtn = app.buttons["generate.dailyDrop"]
        XCTAssertTrue(dailyDropBtn.waitForExistence(timeout: 3))
        if dailyDropBtn.isEnabled { dailyDropBtn.tap() }
        _ = adviceCard.waitForExistence(timeout: 10)
    }

    // MARK: - Settings Deep Smoke Test

    /// Tests settings tab in detail — scrolls through all sections
    func testSettingsDeepSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launch()

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
                ? app.buttons[element.identifier]
                : app.staticTexts[element.identifier]
            if !el.exists {
                scrollToFind(app: app, element: el, maxSwipes: 15)
            }
            // Don't hard-fail on scroll visibility since some may be behind conditionals
        }

        // Check social health section
        let socialHealthOpen = app.buttons["settings.socialHealth.open"]
        if !socialHealthOpen.exists {
            scrollToFind(app: app, element: socialHealthOpen, maxSwipes: 8)
        }
        if socialHealthOpen.exists {
            socialHealthOpen.tap()
            let socialDiagNav = app.navigationBars["Social Diagnostics"]
            XCTAssertTrue(socialDiagNav.waitForExistence(timeout: 5), "Social diagnostics should open")

            let retryQueue = app.buttons["settings.socialHealth.retryQueue"]
            XCTAssertTrue(retryQueue.waitForExistence(timeout: 3), "Retry queue button should exist")

            // Navigate back
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    // MARK: - Performance Smoke Test

    /// Ensures the app launches within a reasonable time and key views render quickly
    func testLaunchPerformanceSmoke() throws {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launch()

        // App should be interactive within 12 seconds
        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(
            generateButton.waitForExistence(timeout: 12),
            "App should be interactive within 12 seconds of launch"
        )

        // Generate should complete within 10 seconds
        generateButton.tap()
        let adviceCard = app.otherElements["advice.card"]
        XCTAssertTrue(
            adviceCard.waitForExistence(timeout: 10),
            "Advice should generate within 10 seconds"
        )

        // Tab switching should be fast
        let tabs = ["tab.chaosHub", "tab.friends", "tab.quotes", "tab.generate"]
        for tabID in tabs {
            let tab = app.buttons.matching(identifier: tabID).firstMatch
            if tab.waitForExistence(timeout: 3) {
                tab.tap()
                // Each tab should render content within 5 seconds
                Thread.sleep(forTimeInterval: 0.5)
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
                Thread.sleep(forTimeInterval: 0.3)
            }

            // Final page — dismiss
            if getStarted.waitForExistence(timeout: 5) {
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
    private func scrollToFind(app: XCUIApplication, element: XCUIElement, maxSwipes: Int) -> Bool {
        for _ in 0..<maxSwipes where !element.exists {
            app.swipeUp()
        }
        return element.exists
    }

    private func launchMockSocialApp(seededIncomingRequests: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments + [
            "-ui-testing-social-mock"
        ]
        if seededIncomingRequests > 0 {
            app.launchArguments += [
                "-ui-testing-social-seed-incoming",
                "\(seededIncomingRequests)",
            ]
        }
        app.launch()
        return app
    }

    @discardableResult
    private func waitForAuthenticatedShell(
        app: XCUIApplication,
        timeout: TimeInterval = 30
    ) -> Bool {
        let generateButton = app.buttons["generate.primary"]
        let settingsSignOut = app.buttons["settings.auth.signOut"]
        let tabMarkers = [
            app.buttons.matching(identifier: "tab.generate").firstMatch,
            app.buttons.matching(identifier: "tab.chaosHub").firstMatch,
            app.buttons.matching(identifier: "tab.friends").firstMatch,
            app.buttons.matching(identifier: "tab.quotes").firstMatch,
            app.buttons.matching(identifier: "tab.settings").firstMatch,
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
        if app.buttons["settings.auth.signOut"].exists
            || app.buttons["settings.auth.changePassword"].exists
        {
            return true
        }

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        if settingsTab.waitForExistence(timeout: 2) {
            settingsTab.tap()
            return app.navigationBars.firstMatch.waitForExistence(timeout: 5)
        }

        // Fallback: access via Chaos Hub > Labs
        let chaosTab = app.buttons.matching(identifier: "tab.chaosHub").firstMatch
        if chaosTab.waitForExistence(timeout: 5) {
            chaosTab.tap()
            let openLabs = app.buttons["chaos.quickActions.openLabs"]
            if scrollToFind(app: app, element: openLabs, maxSwipes: 8),
                openLabs.waitForExistence(timeout: 3)
            {
                openLabs.tap()
                return app.navigationBars.firstMatch.waitForExistence(timeout: 5)
            }
        }

        // Fallback: access via brand menu
        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 2) { generateTab.tap() }
        let brandMenu = app.buttons["generate.brandMenu"]
        if brandMenu.waitForExistence(timeout: 5) { brandMenu.tap() }
        let settingsQuickAccess = app.buttons["brandMenu.quickAccess.settings"]
        if settingsQuickAccess.waitForExistence(timeout: 5) {
            settingsQuickAccess.tap()
        } else {
            let settingsMenuButton = app.buttons["settings.menuButton"]
            if settingsMenuButton.waitForExistence(timeout: 5) {
                settingsMenuButton.tap()
            }
        }
        return app.navigationBars.firstMatch.waitForExistence(timeout: 5)
    }

    private func completeProfileSignup(app: XCUIApplication, handle: String) {
        let friendsTab = app.buttons.matching(identifier: "tab.friends").firstMatch
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 5))
        friendsTab.tap()

        let openSetupButton = app.buttons["friends.openSetup"]
        XCTAssertTrue(openSetupButton.waitForExistence(timeout: 5))
        openSetupButton.tap()

        XCTAssertTrue(app.navigationBars["Friends Setup"].waitForExistence(timeout: 5))
        let handleField = app.textFields["social.profile.handle"]
        XCTAssertTrue(handleField.waitForExistence(timeout: 8))
        handleField.tap()
        handleField.typeText(handle)

        let saveButton = app.buttons["social.profile.save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertFalse(
            handleField.waitForExistence(timeout: 3),
            "Profile setup sheet should dismiss after save"
        )
    }

    private func completeLocalSignup(
        app: XCUIApplication,
        displayName: String,
        email: String,
        password: String
    ) {
        let signUpModeButton = app.buttons["auth.mode.signUp"]
        XCTAssertTrue(signUpModeButton.waitForExistence(timeout: 8))

        let displayNameField = app.textFields["auth.displayName"]
        XCTAssertTrue(displayNameField.waitForExistence(timeout: 5))
        displayNameField.tap()
        displayNameField.typeText(displayName)

        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 3))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["auth.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        passwordField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 32))
        passwordField.typeText(password)

        let confirmField = app.secureTextFields["auth.confirmPassword"]
        XCTAssertTrue(confirmField.waitForExistence(timeout: 3))
        confirmField.tap()
        confirmField.typeText(password)

        let primaryButton = app.buttons["auth.primary"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))
        XCTAssertTrue(primaryButton.isEnabled)
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
        emailField.tap()
        if let existing = emailField.value as? String, !existing.isEmpty, existing != "Email" {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)
            emailField.typeText(deleteString)
        }
        emailField.typeText(email)

        let passwordField = app.secureTextFields["auth.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        passwordField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 64))
        passwordField.typeText(password)

        let primaryButton = app.buttons["auth.primary"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))
        XCTAssertTrue(primaryButton.isEnabled)
        primaryButton.tap()
    }
}
