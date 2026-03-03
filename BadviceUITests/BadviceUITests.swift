import XCTest

final class BadviceUITests: XCTestCase {
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
        XCTAssertTrue(waitForAuthenticatedShell(app: app))
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
        XCTAssertTrue(waitForAuthenticatedShell(app: app))
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

    func testSocialMockSignupCompletesAndFriendsSurfaceLoads() throws {
        let app = launchMockSocialApp()

        XCTAssertTrue(app.navigationBars["Friends Setup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["social.profile.intro"].waitForExistence(timeout: 3))

        completeProfileSignup(app: app, handle: "mock_signup_user")

        let friendsTab = app.buttons.matching(identifier: "tab.friends").firstMatch
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 5))
        friendsTab.tap()

        let sectionPicker = app.segmentedControls["friends.sectionPicker"]
        XCTAssertTrue(sectionPicker.waitForExistence(timeout: 5))

        let searchField = app.textFields["friends.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["friends.overviewCard"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["friends.outgoingCard"].waitForExistence(timeout: 3))

        sectionPicker.buttons["Feed"].tap()
        XCTAssertTrue(app.otherElements["friends.feed.empty"].waitForExistence(timeout: 3))

        sectionPicker.buttons["Collab"].tap()
        XCTAssertTrue(app.otherElements["friends.collab.empty"].waitForExistence(timeout: 3))
    }

    func testSocialMockIncomingBadgeAppearsOnTabBar() throws {
        let app = launchMockSocialApp(seededIncomingRequests: 3)
        completeProfileSignup(app: app, handle: "badge_user")

        let badge = app.staticTexts["tab.friends.badge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        let badgeLabel = badge.label
        XCTAssertTrue(
            badgeLabel.contains("3") || badgeLabel.contains("99+"),
            "Expected friends badge to show pending request count. label=\(badgeLabel)"
        )
    }

    func testSettingsSocialDiagnosticsOpensInMockMode() throws {
        let app = launchMockSocialApp(seededIncomingRequests: 1)
        completeProfileSignup(app: app, handle: "diagnostics_user")

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let socialHealthOpen = app.buttons["settings.socialHealth.open"]
        if !socialHealthOpen.waitForExistence(timeout: 3) {
            for _ in 0..<8 where !socialHealthOpen.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(socialHealthOpen.waitForExistence(timeout: 3))
        socialHealthOpen.tap()

        XCTAssertTrue(app.navigationBars["Social Diagnostics"].waitForExistence(timeout: 5))

        let retryQueueButton = app.buttons["settings.socialHealth.retryQueue"]
        XCTAssertTrue(retryQueueButton.waitForExistence(timeout: 3))
    }

    func testLocalAuthSignupSignoutAndSigninFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-skip-onboarding",
            "-skip-splash",
            "-ui-testing-auth-reset",
            "-ui-testing-force-social-unavailable",
        ]
        app.launch()

        completeLocalSignup(
            app: app,
            displayName: "Local Tester",
            email: "local@example.com",
            password: "Badvice123"
        )

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let signOutButton = app.buttons["settings.auth.signOut"]
        if !signOutButton.waitForExistence(timeout: 3) {
            for _ in 0..<8 where !signOutButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 3))
        signOutButton.tap()

        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))

        completeLocalSignin(
            app: app,
            email: "local@example.com",
            password: "Badvice123"
        )

        XCTAssertTrue(waitForAuthenticatedShell(app: app))
    }

    func testLocalAuthPasswordChangeAndDeleteFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-skip-onboarding",
            "-skip-splash",
            "-ui-testing-auth-reset",
            "-ui-testing-force-social-unavailable",
        ]
        app.launch()

        completeLocalSignup(
            app: app,
            displayName: "Lifecycle User",
            email: "lifecycle@example.com",
            password: "Badvice123"
        )

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(waitForAuthenticatedShell(app: app))
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let changePasswordButton = app.buttons["settings.auth.changePassword"]
        if !changePasswordButton.waitForExistence(timeout: 3) {
            for _ in 0..<8 where !changePasswordButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(changePasswordButton.waitForExistence(timeout: 3))
        changePasswordButton.tap()

        let currentPasswordField = app.secureTextFields["settings.auth.currentPassword"]
        XCTAssertTrue(currentPasswordField.waitForExistence(timeout: 3))
        currentPasswordField.tap()
        currentPasswordField.typeText("Badvice123")

        let newPasswordField = app.secureTextFields["settings.auth.newPassword"]
        newPasswordField.tap()
        newPasswordField.typeText("Chaos456")

        let confirmField = app.secureTextFields["settings.auth.confirmNewPassword"]
        confirmField.tap()
        confirmField.typeText("Chaos456")

        let savePasswordButton = app.buttons["settings.auth.passwordSave"]
        XCTAssertTrue(savePasswordButton.isEnabled)
        savePasswordButton.tap()

        let signOutButton = app.buttons["settings.auth.signOut"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5))
        signOutButton.tap()

        completeLocalSignin(
            app: app,
            email: "lifecycle@example.com",
            password: "Chaos456"
        )
        XCTAssertTrue(waitForAuthenticatedShell(app: app))

        settingsTab.tap()
        let deleteAccountButton = app.buttons["settings.auth.deleteAccount"]
        if !deleteAccountButton.waitForExistence(timeout: 3) {
            for _ in 0..<8 where !deleteAccountButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(deleteAccountButton.waitForExistence(timeout: 3))
        deleteAccountButton.tap()

        let deletePasswordField = app.secureTextFields["settings.auth.deletePassword"]
        XCTAssertTrue(deletePasswordField.waitForExistence(timeout: 3))
        deletePasswordField.tap()
        deletePasswordField.typeText("Chaos456")

        let confirmDeleteButton = app.buttons["settings.auth.deleteConfirm"]
        XCTAssertTrue(confirmDeleteButton.isEnabled)
        confirmDeleteButton.tap()

        XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 5))
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
        timeout: TimeInterval = 15
    ) -> Bool {
        let generateButton = app.buttons["generate.primary"]
        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if generateButton.exists || settingsTab.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        return generateButton.exists || settingsTab.exists
    }

    private func completeProfileSignup(app: XCUIApplication, handle: String) {
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
            "Expected profile setup sheet to dismiss after successful profile creation."
        )
    }

    private func completeLocalSignup(
        app: XCUIApplication,
        displayName: String,
        email: String,
        password: String
    ) {
        let modePicker = app.segmentedControls["auth.mode"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 8))

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
        let signInSegment = app.buttons["Sign In"]
        if signInSegment.exists {
            signInSegment.tap()
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
        passwordField.typeText(password)

        let primaryButton = app.buttons["auth.primary"]
        XCTAssertTrue(primaryButton.waitForExistence(timeout: 3))
        XCTAssertTrue(primaryButton.isEnabled)
        primaryButton.tap()
    }
}
