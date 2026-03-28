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
        let app = launchTestApp(extraLaunchArguments: [
            "-ui-testing-reset-data",
            "-debug-preload-polish-fixtures",
            "-debug-polish-seed", "424242",
        ])

        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12))

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
        let app = launchTestApp()

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        XCTAssertTrue(generateTab.waitForExistence(timeout: 5))
        generateTab.tap()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 5))

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
        let friendsTabValue = friendsTab.value as? String ?? ""
        XCTAssertTrue(
            friendsTabValue.localizedCaseInsensitiveContains("selected"),
            "Friends tab should become selected after tap. value=\(friendsTabValue)"
        )
        let friendsRoot = app.otherElements["friends.root"]
        let friendsPicker = app.otherElements["friends.sectionPicker"]
        let friendsButton = app.buttons["friends.section.friends"]
        let friendsTitle = app.staticTexts["Friends"]
        let friendsVisible = friendsRoot.waitForExistence(timeout: 5)
            || friendsPicker.waitForExistence(timeout: 5)
            || friendsButton.waitForExistence(timeout: 5)
            || friendsTitle.waitForExistence(timeout: 5)
        if !friendsVisible {
            print(app.debugDescription)
        }
        XCTAssertTrue(friendsVisible)

        let quotesTab = app.buttons.matching(identifier: "tab.quotes").firstMatch
        XCTAssertTrue(quotesTab.waitForExistence(timeout: 5))
        quotesTab.tap()
        XCTAssertTrue(
            app.otherElements["quotes.dailyHero"].waitForExistence(timeout: 5)
                || app.staticTexts["Quotes"].waitForExistence(timeout: 5)
        )

        XCTAssertTrue(openSettings(app: app))
    }

    func testSettingsGenerationEnginePickerStateAfterDebugPolishSeedPreload() throws {
        let app = launchTestApp(extraLaunchArguments: [
            "-debug-preload-polish-fixtures",
            "-debug-polish-seed", "424242",
        ])

        XCTAssertTrue(openSettings(app: app))

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
        let app = launchTestApp()

        XCTAssertTrue(openSettings(app: app))

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

    func testSettingsThemeMetadataAndDiagnosticsCopyReport() throws {
        let app = launchTestApp()

        XCTAssertTrue(openSettings(app: app))

        let badviceTheme = app.buttons["settings.theme.badvice"]
        if !badviceTheme.exists {
            scrollToFind(app: app, element: badviceTheme, maxSwipes: 10)
        }
        XCTAssertTrue(badviceTheme.waitForExistence(timeout: 3))

        let themeValue = badviceTheme.value as? String ?? ""
        XCTAssertTrue(
            themeValue.localizedCaseInsensitiveContains("selected")
                && themeValue.localizedCaseInsensitiveContains("best for"),
            "Theme tile should expose selection state and guidance. value=\(themeValue)"
        )

        let themeScope = app.staticTexts["settings.theme.accountScope"]
        if !themeScope.exists {
            scrollToFind(app: app, element: themeScope, maxSwipes: 8)
        }
        XCTAssertTrue(themeScope.exists)

        let copyReport = app.buttons["settings.socialHealth.copyReport"]
        if !copyReport.exists {
            scrollToFind(app: app, element: copyReport, maxSwipes: 10)
        }
        XCTAssertTrue(copyReport.waitForExistence(timeout: 3))
        copyReport.tap()
    }

    func testSmokeSocialSurfacesWhenUnavailable() throws {
        let app = launchTestApp(extraLaunchArguments: [
            "-ui-testing-force-social-unavailable"
        ])

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
        let unavailableText = app.staticTexts["Social features are unavailable in this test run."]
        let cloudKitStatusText = app.staticTexts["CloudKit account status could not be determined."]
        let retryLoadButton = app.buttons["friends.retryLoad"]
        XCTAssertTrue(
            unavailableText.waitForExistence(timeout: 2)
                || cloudKitStatusText.waitForExistence(timeout: 2)
                || retryLoadButton.waitForExistence(timeout: 2)
        )

        let sectionPicker = app.otherElements["friends.sectionPicker"]
        XCTAssertTrue(sectionPicker.waitForExistence(timeout: 3))

        let feedSegment = app.buttons["friends.section.feed"]
        if feedSegment.exists { feedSegment.tap() }
        let feedRefresh = app.buttons["friends.feedRefresh"]
        XCTAssertTrue(feedRefresh.waitForExistence(timeout: 3))
        XCTAssertFalse(feedRefresh.isEnabled)

        let collabSegment = app.buttons["friends.section.collab"]
        if collabSegment.exists { collabSegment.tap() }
        let newDoc = app.buttons["friends.newCollabDoc"]
        XCTAssertTrue(newDoc.waitForExistence(timeout: 3))
        XCTAssertFalse(newDoc.isEnabled)
    }

    @discardableResult
    private func scrollToFind(app: XCUIApplication, element: XCUIElement, maxSwipes: Int) -> Bool {
        for _ in 0..<maxSwipes where !element.exists {
            app.swipeUp()
        }
        return element.exists
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
        app.activate()
        XCTAssertTrue(waitForAppToBecomeReady(app: app, timeout: timeout))
        return app
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

    func testSocialMockSignupCompletesAndFriendsSurfaceLoads() throws {
        let app = launchMockSocialApp()

        completeProfileSignup(app: app, handle: "mock_signup_user")

        let friendsTab = app.buttons.matching(identifier: "tab.friends").firstMatch
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 5))
        friendsTab.tap()

        let sectionPicker = app.otherElements["friends.sectionPicker"]
        XCTAssertTrue(sectionPicker.waitForExistence(timeout: 5))

        let searchField = app.textFields["friends.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        app.buttons["friends.section.feed"].tap()
        XCTAssertTrue(app.buttons["friends.feedRefresh"].waitForExistence(timeout: 3))

        app.buttons["friends.section.collab"].tap()
        XCTAssertTrue(app.buttons["friends.newCollabDoc"].waitForExistence(timeout: 3))
    }

    func testSocialMockIncomingBadgeAppearsOnTabBar() throws {
        let app = launchMockSocialApp(seededIncomingRequests: 3)
        completeProfileSignup(app: app, handle: "badge_user")

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        XCTAssertTrue(generateTab.waitForExistence(timeout: 5))
        generateTab.tap()

        let friendsTab = app.buttons.matching(identifier: "tab.friends").firstMatch
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 5))
        let badge = app.staticTexts["tab.friends.badge"]
        if badge.waitForExistence(timeout: 8) {
            let badgeLabel = badge.label
            XCTAssertTrue(
                badgeLabel.contains("3") || badgeLabel.contains("99+"),
                "Expected friends badge to show pending request count. label=\(badgeLabel)"
            )
        } else {
            let tabValue = friendsTab.value as? String ?? ""
            XCTAssertTrue(
                tabValue.localizedCaseInsensitiveContains("pending requests"),
                "Expected friends tab accessibility value to include pending request count. value=\(tabValue)"
            )
        }
    }

    func testSettingsSocialDiagnosticsOpensInMockMode() throws {
        let app = launchMockSocialApp(seededIncomingRequests: 1)
        completeProfileSignup(app: app, handle: "diagnostics_user")

        XCTAssertTrue(openSettings(app: app))

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
        let app = launchTestApp(includeAuthSkip: false, extraLaunchArguments: [
            "-ui-testing-force-social-unavailable",
        ])

        completeLocalSignup(
            app: app,
            displayName: "Local Tester",
            email: "local@example.com",
            password: "Badvice123"
        )

        XCTAssertTrue(openSettings(app: app))

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
        app.launchArguments += defaultLaunchArguments.filter { $0 != "-ui-testing-auth-skip" }
        app.launchArguments += [
            "-ui-testing-force-social-unavailable",
        ]
        app.launch()
        app.activate()
        XCTAssertTrue(waitForAuthGateToBecomeReady(app: app, timeout: 30))

        completeLocalSignup(
            app: app,
            displayName: "Lifecycle User",
            email: "lifecycle@example.com",
            password: "Badvice123"
        )

        XCTAssertTrue(openSettings(app: app))

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
        app.activate()
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
        let settingsChangePassword = app.buttons["settings.auth.changePassword"]
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
                || settingsChangePassword.exists
                || tabMarkers.contains(where: \.exists)
            {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        return generateButton.exists
            || settingsSignOut.exists
            || settingsChangePassword.exists
            || tabMarkers.contains(where: \.exists)
    }

    @discardableResult
    private func openSettings(app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        guard waitForAuthenticatedShell(app: app, timeout: timeout) else { return false }
        if app.buttons["settings.auth.signOut"].exists || app.buttons["settings.auth.changePassword"].exists
        {
            return true
        }

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        if settingsTab.waitForExistence(timeout: 2) {
            settingsTab.tap()
            return app.navigationBars.firstMatch.waitForExistence(timeout: 5)
        }

        let chaosTab = app.buttons.matching(identifier: "tab.chaosHub").firstMatch
        if chaosTab.waitForExistence(timeout: 5) {
            chaosTab.tap()
            let openLabsButton = app.buttons["chaos.quickActions.openLabs"]
            if !openLabsButton.waitForExistence(timeout: 2) {
                for _ in 0..<8 where !openLabsButton.exists {
                    app.swipeUp()
                }
            }
            if openLabsButton.waitForExistence(timeout: 3) {
                openLabsButton.tap()
                return app.navigationBars.firstMatch.waitForExistence(timeout: 5)
            }
        }

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 2) {
            generateTab.tap()
        }
        let brandMenuButton = app.buttons["generate.brandMenu"]
        if brandMenuButton.waitForExistence(timeout: 5) {
            brandMenuButton.tap()
        } else {
            let fallbackBrandMenu = app.buttons["Badvice"].firstMatch
            guard fallbackBrandMenu.waitForExistence(timeout: 5) else { return false }
            fallbackBrandMenu.tap()
        }

        let settingsQuickAccess = app.buttons["brandMenu.quickAccess.settings"]
        if settingsQuickAccess.waitForExistence(timeout: 5) {
            settingsQuickAccess.tap()
        } else {
            let settingsMenuButton = app.buttons["settings.menuButton"]
            if settingsMenuButton.waitForExistence(timeout: 5) {
                settingsMenuButton.tap()
            } else {
                let settingsCell = app.cells.containing(.staticText, identifier: "Settings").firstMatch
                if settingsCell.waitForExistence(timeout: 2) {
                    settingsCell.tap()
                } else {
                    let settingsText = app.staticTexts["Settings"].firstMatch
                    if settingsText.waitForExistence(timeout: 2) {
                        settingsText.tap()
                    } else {
                        let fallbackSettings = app.buttons["Settings"].firstMatch
                        guard fallbackSettings.waitForExistence(timeout: 5) else { return false }
                        fallbackSettings.tap()
                    }
                }
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
        let intro = app.otherElements["social.profile.intro"]
        let handleField = app.textFields["social.profile.handle"]
        if !intro.waitForExistence(timeout: 2) && !handleField.exists {
            _ = handleField.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(intro.exists || handleField.exists)

        XCTAssertTrue(handleField.waitForExistence(timeout: 8))
        handleField.tap()
        app.typeText(handle)
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
            "Expected profile setup sheet to dismiss after successful profile creation."
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
        displayNameField.tap()
        if let existing = displayNameField.value as? String, !existing.isEmpty, existing != "Display name (optional)" {
            displayNameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        displayNameField.typeText(displayName)

        let emailField = app.textFields["auth.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 3))
        emailField.tap()
        if let existing = emailField.value as? String, !existing.isEmpty, existing != "Email" {
            emailField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        emailField.typeText(email)

        let passwordField = app.textFields["auth.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        passwordField.typeText(password)

        let confirmField = app.textFields["auth.confirmPassword"]
        XCTAssertTrue(confirmField.waitForExistence(timeout: 3))
        confirmField.tap()
        confirmField.typeText(password)

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
        emailField.tap()
        if let existing = emailField.value as? String, !existing.isEmpty, existing != "Email" {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count)
            emailField.typeText(deleteString)
        }
        emailField.typeText(email)

        let passwordField = app.textFields["auth.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        passwordField.typeText(password)

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

}
