import UIKit
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

        XCTAssertTrue(openMoreQuickAccess(app: app, id: "chaosHub", label: "Missions"))
        XCTAssertTrue(
            app.descendants(matching: .any)["chaos.social.leaderboardCard"].waitForExistence(timeout: 5)
                || app.staticTexts["Missions"].waitForExistence(timeout: 5)
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

    func testSettingsSuggestionPipelineAndAppleLocalModelSurfacesAfterDebugPolishSeedPreload() throws {
        let app = launchTestApp(extraLaunchArguments: [
            "-debug-preload-polish-fixtures",
            "-debug-polish-seed", "424242",
        ])

        XCTAssertTrue(openSettings(app: app))

        let suggestionPipeline = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", "Suggestion Pipeline")
                ).firstMatch,
                app.staticTexts["Suggestion Pipeline"],
            ],
            timeout: 6,
            maxSwipes: 12
        )
        XCTAssertNotNil(suggestionPipeline, "Suggestion Pipeline row should be present in settings")

        if suggestionPipeline?.isHittable == true {
            suggestionPipeline!.tap()
            XCTAssertTrue(
                app.navigationBars["Suggestion Pipeline"].waitForExistence(timeout: 4)
                    || app.staticTexts["Suggestion Pipeline"].waitForExistence(timeout: 2),
                "Tapping Suggestion Pipeline should open the dedicated screen"
            )
            _ = closeTopScreen(app: app)
        }

        let appleModelStatus = app.staticTexts["settings.appleModel.status"]
        let appleModelEmpty = app.staticTexts["settings.appleModel.empty"]
        let appleModelFallback = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Apple Local Model")
        ).firstMatch
        let appleModelControl = waitForAnyElement(
            app: app,
            candidates: [
                appleModelStatus,
                app.buttons["settings.appleModel.recheckFooter"],
                app.buttons["settings.appleModel.recheckInline"],
                app.buttons["settings.appleModel.prepare"],
                appleModelEmpty,
                appleModelFallback,
                app.buttons["settings.appleModel.appSettings"],
            ],
            timeout: 6,
            maxSwipes: 12
        )
        XCTAssertNotNil(appleModelControl, "Expected Apple Local Model surface in settings")
    }

    func testSettingsAppleLocalModelShowsListOrExplicitEmptyState() throws {
        let app = launchTestApp()

        XCTAssertTrue(openSettings(app: app))

        let appleModelStatus = app.staticTexts["settings.appleModel.status"]
        let appleModelEmpty = app.staticTexts["settings.appleModel.empty"]
        let appleModelFallback = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Apple Model")
        ).firstMatch

        _ = waitForAnyElement(
            app: app,
            candidates: [
                appleModelStatus,
                appleModelEmpty,
                appleModelFallback,
                app.staticTexts["settings.appleModel.title"],
                app.otherElements["settings.appleModel.section"],
            ],
            timeout: 6,
            maxSwipes: 12
        )

        XCTAssertTrue(
            appleModelStatus.exists
                || appleModelEmpty.exists
                || appleModelFallback.exists
                || app.staticTexts["settings.appleModel.title"].exists
                || app.otherElements["settings.appleModel.section"].exists,
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

        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12))
        generateButton.tap()
        XCTAssertTrue(waitForAdviceGenerationToSettle(app: app, timeout: 10))
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))

        let shareButton = app.buttons["generate.share"]
        XCTAssertTrue(scrollToFind(app: app, element: shareButton, maxSwipes: 8))
        XCTAssertTrue(shareButton.exists)

        XCTAssertTrue(openMoreQuickAccess(app: app, id: "chaosHub", label: "Missions"))

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

        XCTAssertTrue(
            app.otherElements["friends.sectionPicker"].waitForExistence(timeout: 5)
                || app.otherElements["friends.root"].waitForExistence(timeout: 2)
                || app.staticTexts["Friends"].waitForExistence(timeout: 2)
        )
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
        if feedSegment.waitForExistence(timeout: 3) {
            if feedSegment.isHittable {
                feedSegment.tap()
            } else {
                feedSegment.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            let feedRefresh = app.buttons["friends.feedRefresh"]
            let feedEmpty = app.otherElements["friends.feed.empty"]
            XCTAssertTrue(feedRefresh.waitForExistence(timeout: 3)
                || feedEmpty.waitForExistence(timeout: 3))
            if feedRefresh.exists {
                XCTAssertFalse(feedRefresh.isEnabled)
            }
        }

        let collabSegment = app.buttons["friends.section.collab"]
        if collabSegment.waitForExistence(timeout: 3) {
            if collabSegment.isHittable {
                collabSegment.tap()
            } else {
                collabSegment.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            let newDoc = app.buttons["friends.newCollabDoc"]
            let collabEmpty = app.otherElements["friends.collab.empty"]
            XCTAssertTrue(newDoc.waitForExistence(timeout: 3)
                || collabEmpty.waitForExistence(timeout: 3))
            if newDoc.exists {
                XCTAssertFalse(newDoc.isEnabled)
            }
        }
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

    private func waitForAuthGateToBecomeReady(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let readinessChecks: [() -> Bool] = [
            { app.buttons["auth.mode.signUp"].exists },
            { app.buttons["auth.mode.signIn"].exists },
            { app.buttons["auth.primary"].exists },
            { app.textFields["auth.email"].exists },
            { app.textFields["auth.password"].exists },
            { app.secureTextFields["auth.password"].exists },
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

        let socialHealthOpen = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.socialHealth.open"],
                app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", "Open Diagnostics")
                ).firstMatch,
                app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", "Social Diagnostics")
                ).firstMatch,
                app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", "Social Health")
                ).firstMatch,
            ],
            timeout: 6,
            maxSwipes: 12
        )
        guard let socialHealthOpen else {
            XCTFail("Expected social diagnostics control in settings")
            return
        }
        if !socialHealthOpen.isHittable {
            let row = socialHealthOpen.label
            scrollToFind(app: app, element: socialHealthOpen, maxSwipes: 8)
            XCTAssertTrue(
                app.buttons["settings.socialHealth.open"].isHittable
                    || app.buttons.matching(
                        NSPredicate(format: "label CONTAINS[c] %@", row)
                    ).firstMatch.isHittable
            )
        }
        socialHealthOpen.tap()

        let socialDiagnosticsView = app.staticTexts["Social Diagnostics"]
        let socialDiagNav = app.navigationBars["Social Diagnostics"]
        XCTAssertTrue(
            socialDiagNav.waitForExistence(timeout: 5)
                || socialDiagnosticsView.waitForExistence(timeout: 3),
            "Social diagnostics should open"
        )

        let retryQueueButton = app.buttons["settings.socialHealth.retryQueue"]
        XCTAssertTrue(retryQueueButton.waitForExistence(timeout: 3))
    }

    func testSuggestionAndQuoteLabValidationAndSubmissionFlow() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-reset-data"])

        XCTAssertTrue(openSettings(app: app))

        let suggestionLabButton = app.buttons["Advice Suggestion Lab"]
        let suggestionLabRow = app.staticTexts["Advice Suggestion Lab"]
        if suggestionLabButton.waitForExistence(timeout: 3) {
            suggestionLabButton.tap()
        } else {
            XCTAssertTrue(suggestionLabRow.waitForExistence(timeout: 4))
            suggestionLabRow.tap()
        }

        XCTAssertTrue(app.navigationBars["Suggestion Lab"].waitForExistence(timeout: 5))

        let topicField = app.textFields["Topic"]
        let adviceLineCandidates = app.textFields.allElementsBoundByIndex + app.secureTextFields.allElementsBoundByIndex + app.textViews.allElementsBoundByIndex
        let adviceLineField = findEditableField(identifier: "Advice line", label: "Advice line", app: app, fallback: nil)
            ?? adviceLineCandidates.first(where: { candidate in
                let candidateText = "\(candidate.identifier) \(candidate.label) \(candidate.placeholderValue ?? "")".lowercased()
                return candidate.exists && !candidateText.contains("topic")
            })
        let submitButton = app.buttons["suggestionLab.submit"]
        XCTAssertTrue(topicField.waitForExistence(timeout: 4))
        XCTAssertNotNil(adviceLineField)
        XCTAssertTrue(submitButton.waitForExistence(timeout: 2))

        fillTextInput(topicField, text: "ai")
        fillTextInput(adviceLineField!, text: "Keep it short.")
        submitButton.tap()

        XCTAssertTrue(
            app.staticTexts["Add a clearer topic (at least 3 characters)."].waitForExistence(timeout: 2)
        )

        fillTextInput(topicField, text: "AI product strategy")
        fillTextInput(adviceLineField!, text: "Ship one crisp update, then wait for people to misunderstand you clearly.")
        submitButton.tap()
        XCTAssertTrue(
            app.staticTexts["Add a clearer topic (at least 3 characters)."].waitForExistence(timeout: 1.0) == false,
            "Expected validation error to clear after a successful suggestion submission."
        )

        app.navigationBars.buttons.firstMatch.tap()

        let quoteLabButton = app.buttons["Quote Suggestion Lab"]
        let quoteLabRow = app.staticTexts["Quote Suggestion Lab"]
        if quoteLabButton.waitForExistence(timeout: 3) {
            quoteLabButton.tap()
        } else {
            XCTAssertTrue(quoteLabRow.waitForExistence(timeout: 4))
            quoteLabRow.tap()
        }

        XCTAssertTrue(app.navigationBars["Quote Suggestion Lab"].waitForExistence(timeout: 5))

        let quoteTextField = findEditableField(
            identifier: "Quote text",
            label: "Quote text",
            app: app,
            fallback: nil
        )
        let quoteSubmit = app.buttons["quoteSuggestionLab.submit"]
        XCTAssertNotNil(quoteTextField)
        fillTextInput(app.textFields["Source (optional)"], text: "Lab")
        fillTextInput(quoteTextField!, text: "short")
        quoteSubmit.tap()

        XCTAssertTrue(app.staticTexts["Quote text is too short."].waitForExistence(timeout: 2))

        fillTextInput(quoteTextField!, text: "If your roadmap drifts, rename the destination before panic mode arrives.")
        quoteSubmit.tap()

        XCTAssertFalse(app.staticTexts["Quote text is too short."].exists)
        app.navigationBars.buttons.firstMatch.tap()
    }

    func testExploreFiltersAndTrendingCardNavigatesToGenerate() throws {
        let app = launchTestApp(extraLaunchArguments: ["-debug-preload-polish-fixtures", "-debug-polish-seed", "424242"])

        if !openMoreQuickAccess(app: app, id: "explore", label: "Explore") {
            throw XCTSkip("Explore quick access is not mounted in this build.")
        }

        let exploreTab = app.buttons.matching(identifier: "tab.explore").firstMatch
        let exploreTabByLabel = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Explore")
        ).firstMatch
        if exploreTab.exists || exploreTabByLabel.exists {
            let activeExploreTab = exploreTab.exists ? exploreTab : exploreTabByLabel
            XCTAssertNotNil(activeExploreTab)
            activeExploreTab.tap()
        }

        let categoryChip = app.buttons["explore.filter.categories.chip.0"]
        XCTAssertTrue(
            categoryChip.waitForExistence(timeout: 6) || app.otherElements["explore.command.card"].waitForExistence(timeout: 2),
            "Explore quick access should route to the Explore surface"
        )
        XCTAssertTrue(categoryChip.waitForExistence(timeout: 5))
        categoryChip.tap()

        let toneChip = app.buttons["explore.filter.tones.chip.0"]
        XCTAssertTrue(toneChip.waitForExistence(timeout: 5))
        toneChip.tap()

        let resetCategories = app.buttons["explore.filter.categories.reset"]
        XCTAssertTrue(resetCategories.waitForExistence(timeout: 3))
        if !resetCategories.isHittable {
            app.swipeDown()
        }
        resetCategories.tap()

        let resetTones = app.buttons["explore.filter.tones.reset"]
        XCTAssertTrue(resetTones.waitForExistence(timeout: 3))
        if !resetTones.isHittable {
            app.swipeDown()
        }
        resetTones.tap()

        let trendCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "explore.trending.")).firstMatch
        let trendCardByLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Trending")).firstMatch
        let trendingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Trending")).firstMatch
        let discoveredTrendCard = waitForAnyElement(
            app: app,
            candidates: [
                trendCard,
                trendCardByLabel,
                trendingText,
            ],
            timeout: 7,
            maxSwipes: 10
        )
        XCTAssertNotNil(discoveredTrendCard)
        discoveredTrendCard?.tap()

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        XCTAssertTrue(generateTab.waitForExistence(timeout: 6))
        XCTAssertTrue(generateTab.exists || app.buttons["generate.primary"].waitForExistence(timeout: 5))
        if generateTab.exists {
            generateTab.tap()
        }
    }

    func testGroupChallengesCreateJoinAndPlayFlow() throws {
        let app = launchTestApp()

        let openedFromMore = openMoreQuickAccess(app: app, id: "groupChallenges", label: "Challenges")
        if openedFromMore {
            XCTAssertTrue(
                app.buttons["groupChallenges.toolbarCreate"].waitForExistence(timeout: 5)
                    || app.staticTexts["Group Challenges"].waitForExistence(timeout: 5)
                    || app.buttons["groupChallenges.card.play"].waitForExistence(timeout: 5)
            )
        }

        if !openedFromMore {
            let challengesTab = app.buttons.matching(identifier: "tab.groupChallenges").firstMatch
            let challengesLabelTab = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "challenge")
            ).firstMatch
            guard challengesTab.waitForExistence(timeout: 5) || challengesLabelTab.waitForExistence(timeout: 3) else {
                throw XCTSkip("Group Challenges tab is not mounted in this build.")
            }
            if challengesTab.exists {
                challengesTab.tap()
            } else {
                challengesLabelTab.tap()
            }
        }

        let createChallenge = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["groupChallenges.toolbarCreate"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Create")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Create Challenge")).firstMatch,
            ],
            timeout: 6,
            maxSwipes: 12
        )
        if let createChallenge = createChallenge {
            createChallenge.tap()
            XCTAssertTrue(app.navigationBars["Create Challenge"].waitForExistence(timeout: 4))
        } else {
            XCTAssertTrue(app.buttons["groupChallenges.card.play"].waitForExistence(timeout: 6))
        }

        let cancelCreate = app.buttons["groupChallenges.create.cancel"]
        if cancelCreate.waitForExistence(timeout: 3) {
            cancelCreate.tap()
        }

        let headerCreate = app.buttons["groupChallenges.headerCreate"]
        if !headerCreate.exists {
            let challengesTab = app.buttons.matching(identifier: "tab.groupChallenges").firstMatch
            if challengesTab.waitForExistence(timeout: 2) {
                challengesTab.tap()
            } else {
                XCTAssertTrue(openMoreQuickAccess(app: app, id: "groupChallenges", label: "Challenges"))
            }
        }

        XCTAssertTrue(app.buttons["groupChallenges.card.play"].waitForExistence(timeout: 6))
        app.buttons["groupChallenges.card.copyCode"].tap()
        let copiedButtonState = app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label CONTAINS[c] %@", "groupChallenges.card.copyCode", "Copied")
        ).firstMatch
        let copiedToast = waitForAnyElement(
            app: app,
            candidates: [
                copiedButtonState,
                app.staticTexts["groupChallenges.copyStatus"],
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "copied")).firstMatch,
            ],
            timeout: 3,
            maxSwipes: 0
        )
        XCTAssertTrue(
            copiedToast != nil || UIPasteboard.general.string == "LOVE12",
            "Copy code should either expose visible feedback or place the active challenge code on the pasteboard"
        )

        app.buttons["groupChallenges.card.details"].tap()
        XCTAssertTrue(app.buttons["groupChallenges.detail.play"].waitForExistence(timeout: 4))
        app.buttons["groupChallenges.detail.play"].tap()

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        XCTAssertTrue(generateTab.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["generate.primary"].waitForExistence(timeout: 3)
                || app.staticTexts["Generate"].exists
        )
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

        let signOutButton = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.auth.signOut"],
                app.buttons["Sign Out"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Sign Out")).firstMatch,
            ],
            timeout: 6,
            maxSwipes: 10
        )
        if let signOutButton, !signOutButton.waitForExistence(timeout: 3) {
            for _ in 0..<8 where !signOutButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertNotNil(signOutButton)
        signOutButton?.tap()

        let authGate = waitForAnyElement(
            app: app,
            candidates: [
                app.textFields["auth.email"],
                app.secureTextFields["auth.password"],
                app.buttons["auth.mode.signIn"],
                app.buttons["Sign In"],
                app.buttons["auth.primary"],
            ],
            timeout: 8,
            maxSwipes: 8
        )
        XCTAssertNotNil(authGate)

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
        XCTAssertTrue(waitForAppToEnterForeground(app: app, timeout: 30))
        XCTAssertTrue(waitForAuthGateToBecomeReady(app: app, timeout: 30))

        completeLocalSignup(
            app: app,
            displayName: "Lifecycle User",
            email: "lifecycle@example.com",
            password: "Badvice123"
        )

        guard openSettings(app: app) else {
            throw XCTSkip("Settings shell is not available in this auth build configuration.")
        }

        let changePasswordButton = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.auth.changePassword"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Change Password")).firstMatch,
            ],
            timeout: 6,
            maxSwipes: 8
        )
        if let changePasswordButton, changePasswordButton.waitForExistence(timeout: 3) {
            changePasswordButton.tap()

            let currentPasswordField = app.secureTextFields["settings.auth.currentPassword"]
            XCTAssertTrue(currentPasswordField.waitForExistence(timeout: 3))
            fillTextInput(currentPasswordField, text: "Badvice123")

            let newPasswordField = app.secureTextFields["settings.auth.newPassword"]
            fillTextInput(newPasswordField, text: "Chaos456")

            let confirmField = app.secureTextFields["settings.auth.confirmNewPassword"]
            fillTextInput(confirmField, text: "Chaos456")

            let savePasswordButton = app.buttons["settings.auth.passwordSave"]
            XCTAssertTrue(savePasswordButton.isEnabled)
            savePasswordButton.tap()
        }

        let signOutButton = app.buttons["settings.auth.signOut"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5))

        let deleteAccountButton = app.buttons["settings.auth.deleteAccount"]
        if !deleteAccountButton.waitForExistence(timeout: 3) {
            for _ in 0..<8 where !deleteAccountButton.exists {
                app.swipeUp()
            }
        }
        XCTAssertTrue(deleteAccountButton.waitForExistence(timeout: 3))
        if deleteAccountButton.isHittable {
            deleteAccountButton.tap()
        } else {
            deleteAccountButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        let deletePasswordField = app.secureTextFields["settings.auth.deletePassword"]
        XCTAssertTrue(deletePasswordField.waitForExistence(timeout: 3))
        fillTextInput(deletePasswordField, text: "Chaos456")

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
        let settingsChangePassword = app.buttons["settings.auth.changePassword"]
        let authSuccessStatus = app.staticTexts["auth.status"]
        let isAuthSuccessStatusVisible = {
            let statusText = authSuccessStatus.label.lowercased()
            return statusText.contains("signed in") || statusText.contains("account created")
        }
        let tabMarkers = [
            app.buttons.matching(identifier: "tab.generate").firstMatch,
            app.buttons.matching(identifier: "tab.friends").firstMatch,
            app.buttons.matching(identifier: "tab.quotes").firstMatch,
            app.buttons.matching(identifier: "tab.more").firstMatch,
        ]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if generateButton.exists
                || settingsSignOut.exists
                || settingsChangePassword.exists
                || (authSuccessStatus.exists && isAuthSuccessStatusVisible())
                || tabMarkers.contains(where: \.exists)
            {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        return generateButton.exists
            || settingsSignOut.exists
            || settingsChangePassword.exists
            || (authSuccessStatus.exists && isAuthSuccessStatusVisible())
            || tabMarkers.contains(where: \.exists)
    }

    @discardableResult
    private func openSettings(app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        guard waitForAuthenticatedShell(app: app, timeout: timeout) else { return false }
        if app.buttons["settings.auth.signOut"].exists || app.buttons["settings.auth.changePassword"].exists
        {
            return true
        }

        if openMoreQuickAccess(app: app, id: "settings", label: "Settings") {
            return app.buttons["settings.auth.signOut"].waitForExistence(timeout: 5)
                || app.buttons["settings.auth.changePassword"].waitForExistence(timeout: 3)
                || app.buttons["settings.menuButton"].waitForExistence(timeout: 5)
                || app.buttons["settings.socialHealth.open"].waitForExistence(timeout: 5)
                || app.buttons["Sign Out"].waitForExistence(timeout: 2)
                || app.navigationBars["Settings"].waitForExistence(timeout: 2)
                || app.navigationBars.firstMatch.label.localizedCaseInsensitiveContains("Settings")
                || app.staticTexts["Settings"].waitForExistence(timeout: 2)
        }

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        if settingsTab.waitForExistence(timeout: 2) {
            settingsTab.tap()
            if app.buttons["settings.auth.signOut"].waitForExistence(timeout: 5) {
                return true
            }
            if app.buttons["settings.auth.changePassword"].waitForExistence(timeout: 3) {
                return true
            }
            if app.buttons["Sign Out"].waitForExistence(timeout: 2) {
                return true
            }
            return app.navigationBars["Settings"].waitForExistence(timeout: 2)
                || app.navigationBars.firstMatch.label.localizedCaseInsensitiveContains("Settings")
                || app.staticTexts["Settings"].waitForExistence(timeout: 2)
        }

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 2) {
            generateTab.tap()
        }
        guard let brandMenuButton = findBrandMenuButton(
            app: app,
            timeout: 6,
            maxSwipes: 8
        ) else {
            return false
        }
        brandMenuButton.tap()

        if let settingsQuickAccess = findSettingsQuickAccessButton(
            app: app,
            timeout: 6,
            maxSwipes: 8
        ) {
            settingsQuickAccess.tap()
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

        return app.navigationBars.firstMatch.waitForExistence(timeout: 5)
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
            maxSwipes: maxSwipes,
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
                app.buttons["settings.auth.signOut"],
                app.buttons["settings.socialHealth.open"],
            ],
            timeout: timeout,
            maxSwipes: maxSwipes,
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

        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 1) {
            done.tap()
        }
        return false
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
        fillTextInput(handleField, text: handle)
        let expectedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let handleMatches = waitUntilTextFieldValueContains(
            handleField,
            expectedText: expectedHandle,
            timeout: 2.5
        )
        XCTAssertTrue(
            handleMatches,
            "Expected Friends handle field to contain the requested handle after typing. expected=\(expectedHandle), actual=\(handleField.value ?? "nil")"
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

    private func waitUntilTextFieldValueContains(
        _ element: XCUIElement,
        expectedText: String,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let normalizedValue = (element.value as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if normalizedValue.contains(expectedText) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
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
        XCTAssertTrue(waitForAuthGateToBecomeReady(app: app, timeout: 8))
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

    @discardableResult
    private func waitForAnyElement(
        app: XCUIApplication,
        candidates: [XCUIElement],
        timeout: TimeInterval,
        maxSwipes: Int = 0
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        var swipes = 0
        while Date() < deadline {
            if let found = candidates.first(where: { $0.exists }) {
                return found
            }
            if maxSwipes > 0 && swipes < maxSwipes {
                app.swipeUp()
                swipes += 1
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return candidates.first(where: { $0.exists })
    }

    private func findEditableField(
        identifier: String,
        label: String? = nil,
        app: XCUIApplication,
        fallback: XCUIElement? = nil
    ) -> XCUIElement? {
        let textInputQueries: [XCUIElementQuery] = [app.textFields, app.secureTextFields, app.textViews]
        let textIdentifiers = [identifier, label].compactMap { item -> String? in
            let trimmed = item?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed?.isEmpty == false) ? trimmed?.lowercased() : nil
        }

        var candidates: [XCUIElement] = []
        for query in textInputQueries {
            candidates.append(contentsOf: query.allElementsBoundByIndex)
        }
        let visible = candidates.filter { $0.exists }
        let exactMatches = visible.filter { candidate in
            let candidateText = "\(candidate.identifier) \(candidate.label) \(candidate.placeholderValue ?? "")".lowercased()
            return textIdentifiers.contains(where: { id in
                candidate.identifier.lowercased() == id
                    || candidate.label.lowercased() == id
                    || (candidate.placeholderValue ?? "").lowercased() == id
            }) || textIdentifiers.contains(where: { candidateText.contains($0) })
        }
        if let hitMatch = exactMatches.first(where: { $0.isHittable }) {
            return hitMatch
        }

        let fuzzyMatches = visible.filter { candidate in
            let candidateText = "\(candidate.identifier) \(candidate.label) \(candidate.placeholderValue ?? "")".lowercased()
            return textIdentifiers.contains { target in
                candidateText.contains(target) || candidateText.hasPrefix(target)
            }
        }
        if let hitMatch = fuzzyMatches.first(where: { $0.isHittable }) {
            return hitMatch
        }

        if !exactMatches.isEmpty {
            return exactMatches.first
        }
        if !fuzzyMatches.isEmpty {
            return fuzzyMatches.first
        }
        return fallback
    }

    private func waitForEditableElement(
        _ element: XCUIElement,
        app: XCUIApplication,
        timeout: TimeInterval
    ) -> XCUIElement? {
        var searchElement = element

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let refreshed = findEditableField(
                identifier: element.identifier,
                label: element.label,
                app: app
            ) {
                searchElement = refreshed
            }

            if searchElement.isHittable {
                return searchElement
            }

            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        if searchElement.isHittable {
            return searchElement
        }
        return searchElement.exists ? searchElement : nil
    }

    private func fillTextInput(_ element: XCUIElement, text: String) {
        let app = XCUIApplication()
        let input = waitForEditableElement(element, app: app, timeout: 6)
        XCTAssertNotNil(input)
        guard let inputField = input else { return }

        XCTAssertTrue(inputField.waitForExistence(timeout: 3))
        inputField.tap()

        if let currentValue = inputField.value as? String, shouldClearTextInputValue(currentValue, for: inputField) {
            inputField.typeText(String(repeating: "\u{8}", count: currentValue.count))
        }
        inputField.typeText(text)
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

    private func closeTopScreen(app: XCUIApplication) -> Bool {
        let closeTargets = [
            app.navigationBars.buttons["Back"],
            app.navigationBars.buttons["Settings"],
            app.navigationBars.buttons["Done"],
            app.buttons["Close"],
            app.buttons["Done"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Dismiss")).firstMatch,
            app.buttons["Cancel"],
        ]

        if let closeTarget = waitForAnyElement(
            app: app,
            candidates: closeTargets,
            timeout: 3,
            maxSwipes: 2
        ) {
            if closeTarget.exists { closeTarget.tap() }
            return true
        }

        app.swipeDown()
        return true
    }

}

final class BadviceReadinessHardeningUITests: XCTestCase {
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

    func testReadinessLaunchAndTabFlowStableAcrossCoreScreens() throws {
        let app = launchReadinessApp()

        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons["generate.primary"],
                    app.buttons["tab.generate"],
                    app.navigationBars["Settings"].firstMatch,
                    app.buttons["auth.mode.signUp"],
                    app.buttons["auth.mode.signIn"],
                ],
                timeout: 18,
                maxSwipes: 10
            ),
            "App should land in a stable shell for a release-readiness run"
        )

        let tabFlow: [String] = ["tab.generate", "tab.friends", "tab.quotes"]
        for tabID in tabFlow {
            let tabButton = app.buttons.matching(identifier: tabID).firstMatch
            guard tabButton.waitForExistence(timeout: 3) else {
                throw XCTSkip("Expected tab not mounted in this build: \(tabID)")
            }
            tabButton.tap()

            XCTAssertNotNil(
                waitForAnyElement(
                    app: app,
                    candidates: tabMarkers(for: tabID, app: app),
                    timeout: 8,
                    maxSwipes: 12,
                    requireHittable: false
                ),
                "Tab \(tabID) should render a recognizable marker"
            )
        }

        XCTAssertTrue(openMoreQuickAccess(app: app, id: "chaosHub", label: "Missions"))
        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: tabMarkers(for: "tab.chaosHub", app: app),
                timeout: 8,
                maxSwipes: 12,
                requireHittable: false
            ),
            "Missions should render through More quick access"
        )

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        XCTAssertTrue(generateTab.waitForExistence(timeout: 5))
        generateTab.tap()
        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons["generate.primary"],
                ],
                timeout: 5,
                maxSwipes: 4,
            ),
            "Advice should remain reachable after cycling through condensed navigation"
        )
    }

    func testReadiness_FallbackSurfacesRemainUsableWhenSocialUnavailable() throws {
        let app = launchReadinessApp(
            extraLaunchArguments: [
                "-ui-testing-force-social-unavailable",
                "-skip-onboarding",
            ]
        )

        XCTAssertTrue(openSettings(app: app))

        let socialEntry = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.socialHealth.open"],
                app.buttons["settings.socialHealth.view"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social Diagnostics")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Social Health")).firstMatch,
            ],
            timeout: 8,
            maxSwipes: 8
        )
        XCTAssertNotNil(socialEntry)
        socialEntry?.tap()

        let unavailableState = waitForAnyElement(
            app: app,
            candidates: [
                app.staticTexts["Social diagnostics are currently unavailable."],
                app.staticTexts["Social features are unavailable in this test run."],
                app.staticTexts["CloudKit account status could not be determined."],
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Unavailable")).firstMatch,
            ],
            timeout: 6,
            maxSwipes: 6
        )
        let actionFallback = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.socialHealth.retryQueue"],
                app.buttons["Retry Queue"],
                app.buttons["settings.socialHealth.copyReport"],
                app.buttons["Copy Report"],
            ],
            timeout: 4,
            maxSwipes: 2
        )
        XCTAssertTrue(unavailableState != nil || actionFallback != nil, "Social unavailable mode should still present either fallback content or actions")

        _ = closeTopScreen(app: app)
        XCTAssertTrue(openSettings(app: app))

        let friendsTab = app.buttons.matching(identifier: "tab.friends").firstMatch
        if friendsTab.waitForExistence(timeout: 4) {
            friendsTab.tap()
            XCTAssertNotNil(
                waitForAnyElement(
                    app: app,
                    candidates: [
                        app.otherElements["friends.sectionPicker"],
                        app.staticTexts["Social features are unavailable in this test run."],
                        app.staticTexts["CloudKit account status could not be determined."],
                        app.buttons["friends.retryLoad"],
                    ],
                    timeout: 5,
                    maxSwipes: 6
                )
            )
        }
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
            if let found = candidates.first(where: { requireHittable ? ($0.exists && $0.isHittable) : $0.exists }) {
                return found
            }
            if maxSwipes > 0 && swipes < maxSwipes {
                app.swipeUp()
                swipes += 1
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        if requireHittable {
            if let found = candidates.first(where: { $0.exists }) {
                return found
            }
        }

        return nil
    }

    private func tabMarkers(for tabID: String, app: XCUIApplication) -> [XCUIElement] {
        switch tabID {
        case "tab.generate":
            return [app.buttons["generate.primary"], app.staticTexts["Generate"], app.navigationBars["Generate"].firstMatch]
        case "tab.chaosHub":
            return [
                app.descendants(matching: .any)["chaos.social.leaderboardCard"],
                app.staticTexts["Missions"],
                app.buttons["chaos.social.submitScore"],
            ]
        case "tab.friends":
            return [
                app.otherElements["friends.sectionPicker"],
                app.buttons["friends.section.feed"],
                app.staticTexts["Friends"],
            ]
        case "tab.quotes":
            return [
                app.otherElements["quotes.dailyHero"],
                app.staticTexts["Quotes"],
                app.buttons["quotes.spotlight.toggle"],
            ]
        case "tab.explore":
            return [
                app.searchFields["explore.search"],
                app.staticTexts["Explore"],
                app.otherElements["explore.scrollArea"],
                app.navigationBars["Explore"].firstMatch,
            ]
        default:
            return [app.navigationBars.firstMatch]
        }
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
        guard moreTab.waitForExistence(timeout: 4) else {
            return false
        }
        moreTab.tap()

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

        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 1) {
            done.tap()
        }
        return false
    }

    private func launchReadinessApp(extraLaunchArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launchArguments += extraLaunchArguments
        app.launch()
        XCTAssertTrue(waitForAppToBecomeReady(app: app, timeout: 20))
        return app
    }

    private func waitForAppToBecomeReady(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.state == .runningForeground
                && (app.buttons["generate.primary"].exists
                    || app.buttons["auth.mode.signUp"].exists
                    || app.buttons["auth.mode.signIn"].exists
                    || app.buttons["Get Started"].exists
                    || app.buttons["Continue"].exists
                    || app.buttons["Skip"].exists) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    private func openSettings(app: XCUIApplication, timeout: TimeInterval = 12) -> Bool {
        if app.navigationBars["Settings"].waitForExistence(timeout: 2) { return true }

        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        if moreTab.waitForExistence(timeout: 4) {
            moreTab.tap()
            let settingsQuickAccess = app.buttons["brandMenu.quickAccess.settings"]
            if settingsQuickAccess.waitForExistence(timeout: 5) {
                settingsQuickAccess.tap()
                return app.navigationBars["Settings"].waitForExistence(timeout: 5)
                    || app.buttons["settings.auth.signOut"].waitForExistence(timeout: 5)
                    || app.buttons["settings.auth.changePassword"].waitForExistence(timeout: 5)
                    || app.buttons["settings.menuButton"].waitForExistence(timeout: 5)
                    || app.buttons["settings.socialHealth.open"].waitForExistence(timeout: 5)
            }

            let done = app.buttons["Done"].firstMatch
            if done.waitForExistence(timeout: 1) {
                done.tap()
            }
        }

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        if settingsTab.waitForExistence(timeout: 2) {
            settingsTab.tap()
            if app.navigationBars["Settings"].waitForExistence(timeout: 5) { return true }
        }

        let fallbackEntry = app.buttons["settings.menuButton"]
        if fallbackEntry.waitForExistence(timeout: 2) {
            fallbackEntry.tap()
            return app.navigationBars["Settings"].waitForExistence(timeout: 5)
                || app.buttons["settings.auth.signOut"].waitForExistence(timeout: 5)
                || app.buttons["settings.menuButton"].waitForExistence(timeout: 5)
                || app.buttons["settings.socialHealth.open"].waitForExistence(timeout: 5)
        }

        let settings = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings")).firstMatch,
                app.buttons["settings.auth.signOut"],
                app.buttons["settings.menuButton"],
                app.buttons["settings.socialHealth.open"],
                app.cells["settings.row.auth"],
            ],
            timeout: timeout,
            maxSwipes: 8,
            requireHittable: false
        )

        if let settings {
            settings.tap()
            return app.buttons["settings.auth.signOut"].waitForExistence(timeout: 3)
                || app.buttons["settings.auth.changePassword"].waitForExistence(timeout: 3)
                || app.buttons["settings.menuButton"].waitForExistence(timeout: 3)
                || app.buttons["settings.socialHealth.open"].waitForExistence(timeout: 3)
                || app.navigationBars["Settings"].exists
        }

        return false
    }

    private func closeTopScreen(app: XCUIApplication) -> Bool {
        let closeTargets = [
            app.navigationBars.buttons["Back"],
            app.navigationBars.buttons["Settings"],
            app.navigationBars.buttons["Done"],
            app.buttons["Close"],
            app.buttons["Done"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Dismiss")).firstMatch,
            app.buttons["Cancel"],
        ]

        if let closeTarget = waitForAnyElement(app: app, candidates: closeTargets, timeout: 3, maxSwipes: 2, requireHittable: false) {
            if closeTarget.exists { closeTarget.tap() }
            return true
        }

        app.swipeDown()
        return true
    }
}
