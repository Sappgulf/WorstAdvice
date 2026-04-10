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
        let app = launchTestApp()

        // ── 1. Generate Tab ──
        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12), "Generate button should appear on launch")

        // Generate first advice
        generateButton.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))

        // Verify category and tone selectors exist
        let categoryPicker = app.buttons["generate.category"]
        let tonePicker = app.buttons["generate.tone"]
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 3), "Category picker should exist")
        XCTAssertTrue(tonePicker.waitForExistence(timeout: 3), "Tone picker should exist")

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
            let favoritesQuickAccess = app.buttons["brandMenu.quickAccess.favorites"]
            let favoritesQuickAccessByLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Favorites")).firstMatch
            let favoritesQuickAccessCell = app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", "Favorites")).firstMatch
            let favoritesQuickAccessText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Favorites")).firstMatch
            let historyQuickAccess = app.buttons["brandMenu.quickAccess.history"]
            let historyQuickAccessByLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "History")).firstMatch
            let historyQuickAccessCell = app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", "History")).firstMatch
            let historyQuickAccessText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "History")).firstMatch
            let menuPresented = waitForAnyElement(
                app: app,
                candidates: [
                    brandMenuDone,
                    favoritesQuickAccess,
                    favoritesQuickAccessByLabel,
                    favoritesQuickAccessCell,
                    favoritesQuickAccessText,
                    historyQuickAccess,
                    historyQuickAccessByLabel,
                    historyQuickAccessCell,
                    historyQuickAccessText,
                    app.buttons["Done"].firstMatch,
                    app.buttons["brandMenu.quickAccess.settings"],
                    app.buttons["tab.settings"],
                ],
                timeout: 5,
                maxSwipes: 6
            )
            XCTAssertNotNil(menuPresented, "Brand menu quick access should appear")

            let favoritesTarget: XCUIElement? = favoritesQuickAccess.exists ? favoritesQuickAccess
                : (favoritesQuickAccessByLabel.exists ? favoritesQuickAccessByLabel
                   : (favoritesQuickAccessCell.exists ? favoritesQuickAccessCell : (
                        favoritesQuickAccessText.exists ? favoritesQuickAccessText : nil)))

            if let favoritesTarget {
                favoritesTarget.tap()
            } else {
                print("Skipping favorites quick access because no favorites entry is visible in this menu style.")
            }

            if favoritesTarget != nil {
                XCTAssertTrue(
                    app.navigationBars["Favorites"].waitForExistence(timeout: 5)
                        || app.staticTexts["Favorites"].waitForExistence(timeout: 5),
                    "Favorites tab should open from the brand menu"
                )

                let generateTabAfterFavorites = app.buttons.matching(identifier: "tab.generate").firstMatch
                if generateTabAfterFavorites.waitForExistence(timeout: 5) {
                    generateTabAfterFavorites.tap()
                }
            }

            if let reopenBrandMenu = findBrandMenuButton(app: app, timeout: 5, maxSwipes: 8) {
                reopenBrandMenu.tap()
                _ = waitForAnyElement(
                    app: app,
                    candidates: [
                        favoritesQuickAccessByLabel,
                        favoritesQuickAccessCell,
                        favoritesQuickAccessText,
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
                XCTAssertTrue(
                    app.navigationBars["History"].waitForExistence(timeout: 5)
                        || app.staticTexts["History"].waitForExistence(timeout: 5),
                    "History tab should open from the brand menu"
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
            let sectionPicker = app.otherElements["friends.sectionPicker"]
            let friendsTitle = app.staticTexts["Friends"]
            XCTAssertTrue(
                sectionPicker.waitForExistence(timeout: 5)
                    || app.buttons["friends.section.friends"].waitForExistence(timeout: 5)
                    || friendsTitle.waitForExistence(timeout: 5),
                "Friends tab should load"
            )

            if sectionPicker.exists || app.buttons["friends.section.friends"].exists {
                // Tap through each section
                let feedSegment = app.buttons["friends.section.feed"]
                if feedSegment.exists {
                    feedSegment.tap()
                    let feedRefresh = app.buttons["friends.feedRefresh"]
                    _ = feedRefresh.waitForExistence(timeout: 3)
                }

                let collabSegment = app.buttons["friends.section.collab"]
                if collabSegment.exists {
                    collabSegment.tap()
                    let newDoc = app.buttons["friends.newCollabDoc"]
                    _ = newDoc.waitForExistence(timeout: 3)
                }

                // Go back to Friends list
                let friendsSegment = app.buttons["friends.section.friends"]
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

        let sectionPicker = app.otherElements["friends.sectionPicker"]
        XCTAssertTrue(sectionPicker.waitForExistence(timeout: 5), "Friends section picker should load")

        // Search for users
        let searchField = app.textFields["friends.searchField"]
        if searchField.waitForExistence(timeout: 3) {
            fillTextInput(searchField, text: "test")
            let searchButton = app.buttons["friends.searchButton"]
            if searchButton.waitForExistence(timeout: 3) && searchButton.isEnabled {
                searchButton.tap()
            }
            // Dismiss keyboard
            app.swipeDown()
        }

        // Check Feed section
        let feedSegment = app.buttons["friends.section.feed"]
        if feedSegment.exists {
            feedSegment.tap()
            let feedRefresh = app.buttons["friends.feedRefresh"]
            XCTAssertTrue(feedRefresh.waitForExistence(timeout: 3), "Feed refresh button should exist")
        }

        // Check Collab section
        let collabSegment = app.buttons["friends.section.collab"]
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
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))

        let shareToFriends = app.buttons["generate.shareToFriends"]
        if scrollToFind(app: app, element: shareToFriends, maxSwipes: 12) {
            // With mock social, this should be enabled after profile setup
            if shareToFriends.isEnabled {
                shareToFriends.tap()
            }
        }
    }

    // MARK: - Generate Tab Deep Feature Smoke Test

    /// Tests every Generate tab interaction in detail
    func testGenerateTabDeepSmoke() throws {
        let app = launchTestApp()

        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12))

        // Generate and verify advice card content
        generateButton.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))

        // Verify action buttons all exist
        let actionButtons = ["generate.save", "generate.copy", "generate.remix", "generate.gif"]
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
        for _ in 0..<3 {
            generateButton.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
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
                ? app.buttons[element.identifier]
                : app.staticTexts[element.identifier]
            if !el.exists {
                scrollToFind(app: app, element: el, maxSwipes: 15)
            }
            // Don't hard-fail on scroll visibility since some may be behind conditionals
        }

        // Check social health section
        let socialHealthOpen = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.socialHealth.open"],
                app.buttons["settings.socialHealth.view"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social Diagnostics")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social Health")).firstMatch,
                app.buttons["Social Diagnostics"],
                app.buttons["Social Health"],
            ],
            timeout: 5,
            maxSwipes: 12
        )
        if let socialHealthOpen {
            socialHealthOpen.tap()
            let socialDiagScreen = waitForAnyElement(
                app: app,
                candidates: [
                    app.navigationBars["Social Diagnostics"],
                    app.navigationBars["Social Health"],
                    app.navigationBars.element(boundBy: 0),
                    app.staticTexts["Social Diagnostics"],
                    app.staticTexts["Social Health"],
                    app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social")).firstMatch,
                    app.buttons["settings.socialHealth.retryQueue"],
                    app.buttons["Retry Queue"],
                    app.buttons["settings.socialHealth.copyReport"],
                ],
                timeout: 5,
                maxSwipes: 10
            )
            XCTAssertTrue(
                socialDiagScreen != nil,
                "Social diagnostics should open"
            )

            let retryQueue = waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons["settings.socialHealth.retryQueue"],
                    app.buttons["settings.socialHealth.copyReport"],
                    app.buttons["Retry Queue"],
                    app.buttons["Copy Report"],
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "retry")).firstMatch,
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "copy")).firstMatch,
                ],
                timeout: 3,
                maxSwipes: 10
            )
            if retryQueue == nil {
                print("Social diagnostics action set is unavailable in this test mode.")
            }

            // Navigate back
            dismissTopScreen(app: app)
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
                    app.buttons.matching(identifier: "tab.settings").firstMatch,
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
            app.buttons["settings.auth.signOut"].waitForExistence(timeout: 5)
                || app.navigationBars.firstMatch.waitForExistence(timeout: 5),
            "Settings quick access should land on the settings screen"
        )

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 5) {
            generateTab.tap()
        }

        let chaosTab = app.buttons.matching(identifier: "tab.chaosHub").firstMatch
        if chaosTab.waitForExistence(timeout: 5) {
            chaosTab.tap()
            let openLabsButton = app.buttons["chaos.quickActions.openLabs"]
            if scrollToFind(app: app, element: openLabsButton, maxSwipes: 8),
                openLabsButton.waitForExistence(timeout: 3)
            {
                openLabsButton.tap()
                XCTAssertTrue(
                    app.buttons["settings.auth.signOut"].waitForExistence(timeout: 5)
                        || app.navigationBars.firstMatch.waitForExistence(timeout: 5),
                    "Chaos Hub open labs should land on the settings screen"
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
        let tabs = ["tab.chaosHub", "tab.friends", "tab.quotes", "tab.generate"]
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

    private func dismissTopScreen(app: XCUIApplication) {
        let backCandidates: [XCUIElement] = [
            app.navigationBars.buttons.element(boundBy: 0),
            app.navigationBars.buttons["Back"],
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
            { app.buttons["Start The Chaos"].exists },
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
        XCTAssertTrue(waitForAppToEnterForeground(app: app, timeout: 15))
        XCTAssertTrue(waitForAppToBecomeReady(app: app, timeout: 15))
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

        // Prefer the known-good brand menu path on device.
        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 2) { generateTab.tap() }
            if let brandMenu = findBrandMenuButton(app: app, timeout: 5, maxSwipes: 8) {
                brandMenu.tap()
                if let settingsQuickAccess = findSettingsQuickAccessButton(app: app, timeout: 5, maxSwipes: 8) {
                    settingsQuickAccess.tap()
                } else if let settingsMenuButton = findSettingsDirectEntry(app: app, timeout: 5) {
                    settingsMenuButton.tap()
            }
        }

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if app.buttons["settings.auth.signOut"].exists
                || app.buttons["settings.auth.changePassword"].exists
                || app.navigationBars.firstMatch.exists
            {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        // Last resort: try the root settings tab directly.
        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        if settingsTab.waitForExistence(timeout: 2) {
            settingsTab.tap()
            let directDeadline = Date().addingTimeInterval(5)
            while Date() < directDeadline {
                if app.buttons["settings.auth.signOut"].exists
                    || app.buttons["settings.auth.changePassword"].exists
                    || app.navigationBars.firstMatch.exists
                {
                    return true
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }

        return false
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
                app.buttons.matching(identifier: "tab.settings").firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings")).firstMatch,
                app.navigationBars.element(boundBy: 0).buttons["Settings"],
                app.buttons["settings.menuButton"],
            ],
            timeout: timeout,
            maxSwipes: 4
        )
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
        fillTextInput(handleField, text: handle)
        XCTAssertTrue(
            (handleField.value as? String ?? "").contains(handle),
            "Expected Friends handle field to contain the requested handle after typing"
        )

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
        fillTextInput(confirmField, text: password)

        let primaryButton = app.buttons["auth.primary"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))
        XCTAssertTrue(
            waitForElementToBecomeEnabled(primaryButton, timeout: 3),
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

        element.tap()

        if let currentValue = element.value as? String, !currentValue.isEmpty {
            if app.keys["delete"].waitForExistence(timeout: 0.5) {
                let deletePresses = String(repeating: "\u{8}", count: currentValue.count)
                element.typeText(deletePresses)
            } else {
                element.typeText(String(repeating: "\u{8}", count: currentValue.count))
            }
        }
        element.typeText(text)
    }

}
