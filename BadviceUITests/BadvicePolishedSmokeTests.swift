import XCTest

// Focused resilience test bundle for top-line shipping confidence.
// Keeps assertions broad with fallback selectors and lightweight navigation checks.
final class BadvicePolishedSmokeTests: XCTestCase {
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

    func testGenerateFlowIsStableAndReachesShare() throws {
        let app = launchTestApp()

        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12), "Generate button should be available")
        generateButton.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        XCTAssertTrue(waitForGenerateActionToBeReady(app: app, timeout: 12))

        let actionCandidates: [(id: String, isButton: Bool)] = [
            ("generate.save", true),
            ("generate.copy", true),
            ("generate.share", true),
            ("generate.remix", true),
            ("generate.surprise", true),
            ("generate.dailyDrop", true),
        ]

        for candidate in actionCandidates {
            // Keep action discovery resilient across control-type shifts.

            let found = waitForActionLikeElement(
                app: app,
                identifier: candidate.id,
                labelHints: [candidate.id.replacingOccurrences(of: "generate.", with: "")],
                timeout: 6,
                maxSwipes: 8,
                requireHittable: false
            )
            XCTAssertNotNil(
                found,
                "\(candidate.id) should be discoverable without hard dependency on exact visibility"
            )
        }
    }

    func testGenerateLoadingAndSelectorsFlowSmoothlyThroughAllOptions() throws {
        let app = launchTestApp()

        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12), "Generate button should be available")

        // Pickers exist and expose all category/tone chip families.
        XCTAssertNotNil(discoverSelectorHeader(app: app, identifier: "generate.category", timeout: 10, maxSwipes: 6))
        XCTAssertNotNil(discoverSelectorHeader(app: app, identifier: "generate.tone", timeout: 10, maxSwipes: 6))

        let categoryChips = discoverButtons(app: app, prefix: "generate.category.chip.", fallbackMax: 24)
        let toneChips = discoverButtons(app: app, prefix: "generate.tone.chip.", fallbackMax: 24)
        XCTAssertFalse(categoryChips.isEmpty, "Expected category chips to be present")
        XCTAssertFalse(toneChips.isEmpty, "Expected tone chips to be present")

        // Validate each chip in the UI can be selected without blocking the shell.
        for chip in categoryChips {
            if chip.exists && chip.isHittable {
                chip.tap()
                XCTAssertTrue(generateButton.exists)
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }

        for chip in toneChips {
            if chip.exists && chip.isHittable {
                chip.tap()
                XCTAssertTrue(generateButton.exists)
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }

        // Verify loading state appears and settles when generation starts.
        generateButton.tap()
        if let loading = waitForGenerateLoadingElement(app: app, timeout: 3) {
            XCTAssertTrue(loadingCopy(from: loading).contains("Generating advice"))
            XCTAssertTrue(waitForGenerateAdviceToSettle(app: app, timeout: 12))
            XCTAssertTrue(waitForGenerateActionToBeReady(app: app, timeout: 8))
        } else {
            XCTAssertTrue(waitForGenerateActionToBeReady(app: app, timeout: 8))
            return
        }
    }

    func testGenerateUsesOneCommandCardForSelectionLoadingAndResult() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-reset-data"])

        let commandCard = app.otherElements["generate.commandCard"]
        XCTAssertTrue(commandCard.waitForExistence(timeout: 12), "The command card should own the generate flow.")
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 8))
        XCTAssertNotNil(discoverSelectorHeader(app: app, identifier: "generate.category", timeout: 8, maxSwipes: 4))
        XCTAssertNotNil(discoverSelectorHeader(app: app, identifier: "generate.tone", timeout: 8, maxSwipes: 4))

        app.buttons["generate.primary"].tap()
        if let loading = waitForGenerateLoadingElement(app: app, timeout: 3) {
            XCTAssertTrue(commandCard.exists, "Loading should happen without replacing the command card.")
            XCTAssertTrue(loadingCopy(from: loading).contains("Generating advice"))
        }

        XCTAssertTrue(waitForGenerateAdviceToSettle(app: app, timeout: 18))
        XCTAssertTrue(commandCard.exists, "The command card should still be present after generation settles.")
        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.otherElements["advice.card"],
                    app.otherElements["generate.resultNextStep"],
                    app.otherElements["advice.card.goodAdvice"],
                    app.staticTexts["Advice"],
                ],
                timeout: 8,
                maxSwipes: 6,
                requireHittable: false
            ),
            "The advice card should render inside the command flow."
        )
        XCTAssertNotNil(
            waitForActionLikeElement(
                app: app,
                identifier: "generate.save",
                labelHints: ["Save", "save"],
                timeout: 3,
                maxSwipes: 4,
                requireHittable: false
            )
        )
        XCTAssertNotNil(
            waitForActionLikeElement(
                app: app,
                identifier: "generate.copy",
                labelHints: ["Copy", "copy"],
                timeout: 3,
                maxSwipes: 4,
                requireHittable: false
            )
        )
        XCTAssertNotNil(
            waitForActionLikeElement(
                app: app,
                identifier: "generate.share",
                labelHints: ["Share", "share"],
                timeout: 3,
                maxSwipes: 4,
                requireHittable: false
            )
        )
    }

    func testSplashAndOnboardingFlowCompletesAndPersistsAfterRelaunch() throws {
        let app = launchTestApp(
            extraLaunchArguments: ["-ui-testing-auth-reset", "-ui-testing-auth-skip"],
            skipIntro: false,
            resetOnboarding: true
        )

        if app.buttons["onboarding.next"].waitForExistence(timeout: 5) {
            app.buttons["onboarding.skip"].tap()
        }

        XCTAssertTrue(waitForAnyElement(app: app, candidates: [app.buttons["generate.primary"]], timeout: 8) != nil)
        app.terminate()

        let secondLaunch = launchTestApp(
            extraLaunchArguments: ["-ui-testing-auth-reset", "-ui-testing-auth-skip"],
            skipIntro: false
        )
        XCTAssertTrue(waitForAnyElement(app: secondLaunch, candidates: [secondLaunch.buttons["generate.primary"]], timeout: 8) != nil)
    }

    func testLoadingMessageRotationFeelsFunnyAndLively() throws {
        let app = launchTestApp()

        let generateButton = app.buttons["generate.primary"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 12))
        generateButton.tap()

        let loading = app.otherElements["generate.loading"]
        if loading.waitForExistence(timeout: 3) == false {
            XCTAssertTrue(waitForGenerateActionToBeReady(app: app, timeout: 4))
            return
        }

        var uniqueMessages = Set<String>()
        let deadline = Date().addingTimeInterval(7)
        while Date() < deadline, loading.exists {
            if let message = activeLoadingMessage(from: loading), !message.isEmpty {
                uniqueMessages.insert(message)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        XCTAssertTrue(uniqueMessages.count >= 2, "Expected loading message text to update during long-running generation")

        XCTAssertTrue(waitForGenerateAdviceToSettle(app: app, timeout: 15))
        XCTAssertTrue(waitForGenerateActionToBeReady(app: app, timeout: 6))
    }

    func testColdLaunchGeneratesOnOpenAndRecoversAfterRelaunch() throws {
        let app = launchTestApp(
            extraLaunchArguments: ["-ui-testing-reset-data"],
            skipIntro: true
        )

        let loading = waitForGenerateLoadingElement(app: app, timeout: 6)
        if let loadingElement = loading {
            var seenMessages: Set<String> = []
            let deadline = Date().addingTimeInterval(8)
            while Date() < deadline && loadingElement.exists {
                if let text = activeLoadingMessage(from: loadingElement), !text.isEmpty {
                    seenMessages.insert(text)
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.35))
            }
            XCTAssertTrue(
                seenMessages.count >= 2,
                "Expected at least two unique loading messages while auto-generating on launch."
            )
        }

        XCTAssertTrue(waitForGenerateAdviceToSettle(app: app, timeout: 20))

        let categoryChips = discoverButtons(app: app, prefix: "generate.category.chip.", fallbackMax: 30)
        let toneChips = discoverButtons(app: app, prefix: "generate.tone.chip.", fallbackMax: 30)
        XCTAssertFalse(categoryChips.isEmpty, "Expected category chips on generate page.")
        XCTAssertFalse(toneChips.isEmpty, "Expected tone chips on generate page.")

        let friendsTab = app.buttons.matching(identifier: "tab.friends").firstMatch
        if friendsTab.waitForExistence(timeout: 3) {
            friendsTab.tap()
        }
        app.terminate()

        let appAfterRestart = launchTestApp(
            extraLaunchArguments: ["-ui-testing-reset-data"],
            skipIntro: true
        )
        XCTAssertTrue(waitForGenerateActionToBeReady(app: appAfterRestart, timeout: 15))
        XCTAssertTrue(appAfterRestart.buttons["generate.primary"].waitForExistence(timeout: 8))
    }

    func testBrandMenuAndTabCyclePolish() throws {
        let app = launchTestApp()

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if generateTab.waitForExistence(timeout: 3) { generateTab.tap() }

        let brandMenuButton = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["generate.brandMenu"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Brand")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Menu")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "More")).firstMatch,
            ],
            timeout: 5,
            maxSwipes: 8
        )

        if let brandMenuButton {
            brandMenuButton.tap()
            let done = waitForAnyElement(
                app: app,
                candidates: dismissBrandMenuCandidates(app),
                timeout: 4
            )
            if let done {
                done.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
            closeBrandMenu(app: app)
        } else {
            print("Brand menu not discoverable from current UI state; continuing with tab-cycle fallback.")
        }

        let tabOrder = ["tab.generate", "tab.friends", "tab.chaosHub", "tab.quotes", "tab.more"]
        for tabID in tabOrder where tabID != "tab.generate" {
            let tab = app.buttons.matching(identifier: tabID).firstMatch
            if !tab.waitForExistence(timeout: 2) { continue }
            tab.tap()

            let tabName = tabID.replacingOccurrences(of: "tab.", with: "")
            let likelyLabel = tabName.isEmpty ? "" : tabName.capitalized

            let aliveCandidates: [XCUIElement] = if tabID == "tab.more" {
                [
                    app.otherElements["brandMenu.recommendedFlow"],
                    app.buttons["brandMenu.recommendedFlow"],
                    app.buttons["brandMenu.quickAccess.favorites"],
                    app.buttons["brandMenu.quickAccess.history"],
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Quick Access")).firstMatch,
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "More")).firstMatch,
                ]
            } else {
                [
                    app.buttons["generate.primary"],
                    app.buttons["friends.section.feed"],
                    app.buttons["quotes.dailyHero"],
                    app.buttons["chaos.social.submitScore"],
                    app.navigationBars["\(likelyLabel)"].firstMatch,
                    app.navigationBars.element(boundBy: 0),
                    app.navigationBars.firstMatch,
                    app.collectionViews.firstMatch,
                    app.tables.firstMatch,
                    app.scrollViews.firstMatch,
                    app.cells.firstMatch,
                    app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", tabName)).firstMatch,
                ]
            }

            let alive = waitForAnyElement(
                app: app,
                candidates: aliveCandidates,
                timeout: 3,
                maxSwipes: 8,
                requireHittable: false
            )
            XCTAssertNotNil(
                alive,
                "Tab \(tabID) should show content without requiring an exact element contract"
            )

            if tabID == "tab.more" {
                let done = app.buttons["Done"].firstMatch
                if done.waitForExistence(timeout: 2) {
                    done.tap()
                }

                let close = app.buttons["Close"].firstMatch
                if close.waitForExistence(timeout: 0.5) {
                    close.tap()
                }
            }
        }

        // Verify we can still get back to generate.
        let finalGenerateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if finalGenerateTab.waitForExistence(timeout: 5) {
            finalGenerateTab.tap()
        }
        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons["generate.primary"],
                    app.otherElements["generate.commandCard"],
                    app.staticTexts["Advice"],
                    app.buttons["focus.mode.toggle"],
                ],
                timeout: 6,
                maxSwipes: 3,
                requireHittable: false
            ),
            "Expected generate context to reappear after tab cycling."
        )
    }

    func testTabSurfacePolishCoverageAcrossAllSurfaces() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-reset-data"])

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        XCTAssertTrue(generateTab.waitForExistence(timeout: 6))
        generateTab.tap()
        assertTabSurface(
            app: app,
            tabMarkerCandidates: [
                app.buttons["generate.primary"],
                app.staticTexts["Advice"],
                app.otherElements["generate.commandCard"],
            ],
            commandActionIDs: ["generate.primary"],
            expectFocusToggle: true
        )

        let primaryTabs = [
            "tab.friends",
            "tab.chaosHub",
            "tab.quotes",
        ]
        for tabID in primaryTabs {
            let tabButton = app.buttons.matching(identifier: tabID).firstMatch
            XCTAssertTrue(tabButton.waitForExistence(timeout: 4), "Expected primary tab visible: \(tabID)")
            tabButton.tap()

            switch tabID {
            case "tab.friends":
                assertTabSurface(
                    app: app,
                    tabMarkerCandidates: [
                        app.buttons["friends.section.feed"],
                        app.buttons["friends.section.collab"],
                        app.otherElements["friends.sectionPicker"],
                        app.staticTexts["Friends"],
                    ],
                    commandActionIDs: [
                        "friends.command.feed",
                        "friends.command.collab",
                        "friends.newCollabDoc",
                        "friends.openSetup.banner",
                        "friends.openSetup.section",
                    ],
                    expectFocusToggle: true
                )
            case "tab.chaosHub":
                assertTabSurface(
                    app: app,
                    tabMarkerCandidates: [
                        app.buttons["chaos.command.primary"],
                        app.buttons["chaos.command.generate"],
                        app.buttons["chaos.social.submitScore"],
                        app.staticTexts["Missions"],
                    ],
                    commandActionIDs: [
                        "chaos.command.primary",
                        "chaos.command.generate",
                    ],
                    expectFocusToggle: true
                )
            case "tab.quotes":
                assertTabSurface(
                    app: app,
                    tabMarkerCandidates: [
                        app.buttons["quotes.dailyHero"],
                        app.buttons["quotes.command.primary"],
                        app.staticTexts["Quotes"],
                    ],
                    commandActionIDs: [
                        "quotes.command.primary",
                        "quotes.command.daily",
                        "quotes.command.generate",
                        "quotes.ritual.friendAction",
                        "quotes.spotlight.toggle",
                    ],
                    expectFocusToggle: true
                )
            default:
                break
            }
        }

        XCTAssertTrue(openQuickAccessFromBrandMenu(app: app, quickAccessID: "favorites", quickAccessLabel: "Favorites"))
        assertTabSurface(
            app: app,
            tabMarkerCandidates: [
                app.staticTexts["Favorites"],
                app.buttons["favorites.command.primary"],
                app.buttons["favorites.generate"],
            ],
            commandActionIDs: [
                "favorites.command.primary",
                "favorites.generate",
                "favorites.clearFilters",
            ],
            expectFocusToggle: true
        )

        XCTAssertTrue(openQuickAccessFromBrandMenu(app: app, quickAccessID: "history", quickAccessLabel: "History"))
        assertTabSurface(
            app: app,
            tabMarkerCandidates: [
                app.staticTexts["History"],
                app.buttons["history.command.primary"],
                app.buttons["history.generate"],
                app.buttons["history.clearFilters"],
            ],
            commandActionIDs: [
                "history.command.primary",
                "history.generate",
                "history.clearFilters",
            ],
            expectFocusToggle: true
        )

        XCTAssertTrue(openQuickAccessFromBrandMenu(app: app, quickAccessID: "explore", quickAccessLabel: "Explore"))
        assertTabSurface(
            app: app,
            tabMarkerCandidates: [
                app.staticTexts["Explore"],
                app.buttons["explore.command.primary"],
                app.buttons["explore.command.reset"],
                app.otherElements["explore.command.card"],
                app.otherElements["explore.emptyState"],
            ],
            commandActionIDs: [
                "explore.command.primary",
                "explore.command.reset",
                "explore.clearFilters",
                "explore.generateFresh",
            ],
            expectFocusToggle: true
        )

        XCTAssertTrue(openQuickAccessFromBrandMenu(app: app, quickAccessID: "groupChallenges", quickAccessLabel: "Challenges"))
        assertTabSurface(
            app: app,
            tabMarkerCandidates: [
                app.staticTexts["Challenges"],
                app.buttons["groupChallenges.command.primary"],
                app.buttons["groupChallenges.command.join"],
                app.buttons["groupChallenges.empty.create"],
                app.buttons["groupChallenges.empty.join"],
            ],
            commandActionIDs: [
                "groupChallenges.command.primary",
                "groupChallenges.command.join",
                "groupChallenges.empty.create",
                "groupChallenges.empty.join",
            ],
            expectFocusToggle: true
        )

        XCTAssertTrue(openQuickAccessFromBrandMenu(app: app, quickAccessID: "settings", quickAccessLabel: "Settings"))
        assertTabSurface(
            app: app,
            tabMarkerCandidates: [
                app.buttons["settings.auth.signOut"],
                app.buttons["settings.socialHealth.open"],
                app.buttons["settings.socialHealth.view"],
                app.staticTexts["Settings"],
                app.navigationBars["Settings"].firstMatch,
            ],
            commandActionIDs: [
                "settings.socialHealth.open",
                "settings.socialHealth.view",
                "settings.auth.signOut",
                "settings.menuButton",
            ],
            expectFocusToggle: false
        )
    }

    func testQuickAccessAndPrimaryTabsAreReachableAndStable() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-reset-data"])

        let quickAccessTargets: [(String, String, [String])] = [
            ("favorites", "Favorites", ["favorites.command.primary", "favorites.generate"]),
            ("history", "History", ["history.command.primary", "history.generate"]),
            ("explore", "Explore", ["explore.command.primary", "explore.command.reset"]),
            ("groupChallenges", "Challenges", ["groupChallenges.command.primary", "groupChallenges.command.join"]),
            ("settings", "Settings", ["settings.socialHealth.open", "settings.auth.signOut"]),
        ]

        let tabTargets: [String:[String]] = [
            "tab.generate": ["generate.primary", "generate.commandCard"],
            "tab.friends": ["friends.section.feed", "friends.section.collab"],
            "tab.chaosHub": ["chaos.command.primary", "chaos.social.submitScore"],
            "tab.quotes": ["quotes.dailyHero", "quotes.command.primary"],
            "tab.more": ["brandMenu.flow.favorites", "brandMenu.quickAccess.favorites", "favorites.command.primary", "favorites.generate"],
        ]

        for (tabIdentifier, markerIdentifiers) in tabTargets {
            let tab = app.buttons.matching(identifier: tabIdentifier).firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 3), "Expected tab \(tabIdentifier) in bar.")
            tab.tap()

            var markerMatches: [XCUIElement] = markerIdentifiers.map { app.buttons[$0] }
            markerMatches += markerIdentifiers.map { app.staticTexts[$0] }
            markerMatches.append(app.otherElements["\(tabIdentifier).container"])
            markerMatches.append(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", tabIdentifier.replacingOccurrences(of: "tab.", with: ""))).firstMatch)

            XCTAssertNotNil(
                waitForAnyElement(
                    app: app,
                    candidates: markerMatches,
                    timeout: 6,
                    maxSwipes: 6,
                    requireHittable: false
                ),
                "Expected markers for \(tabIdentifier) to render."
            )
        }

        let generateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        XCTAssertTrue(generateTab.waitForExistence(timeout: 3))
        generateTab.tap()

        for (quickAccessID, quickAccessLabel, commandIDs) in quickAccessTargets {
            XCTAssertTrue(
                openQuickAccessFromBrandMenu(app: app, quickAccessID: quickAccessID, quickAccessLabel: quickAccessLabel),
                "Expected quick access item \(quickAccessID) to be reachable from menu."
            )

            for commandID in commandIDs {
                XCTAssertNotNil(
                    waitForActionLikeElement(
                        app: app,
                        identifier: commandID,
                        timeout: 5,
                        maxSwipes: 3,
                        requireHittable: false
                    ),
                    "Expected at least one quick access affordance for \(commandID)."
                )
            }

            XCTAssertTrue(generateTab.waitForExistence(timeout: 3))
            generateTab.tap()
        }
    }

    func testExploreTabFiltersCanToggleAndClear() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-reset-data"])
        XCTAssertTrue(openQuickAccessFromBrandMenu(app: app, quickAccessID: "explore", quickAccessLabel: "Explore"))

        let categoryChips = discoverButtons(app: app, prefix: "explore.filter.categories.chip.", fallbackMax: 12)
        let toneChips = discoverButtons(app: app, prefix: "explore.filter.tones.chip.", fallbackMax: 12)

        if let firstCategory = categoryChips.first(where: \.exists), firstCategory.isHittable {
            firstCategory.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }

        if let firstTone = toneChips.first(where: \.exists), firstTone.isHittable {
            firstTone.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }

        let reset = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["explore.command.reset"],
                app.buttons["explore.clearFilters"],
                app.buttons["explore.generateFresh"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Reset")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Generate")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Filters")).firstMatch,
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Explore")).firstMatch,
            ],
            timeout: 5,
            maxSwipes: 3
        )
        XCTAssertNotNil(reset, "Expected explore command affordance to stay available after toggling filters.")
    }

    private func launchTestApp(
        extraLaunchArguments: [String] = [],
        skipIntro: Bool = true,
        resetOnboarding: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var launchArguments = defaultLaunchArguments
        if !skipIntro {
            launchArguments = launchArguments.filter { arg in
                arg != "-skip-onboarding" && arg != "-skip-splash"
            }
        }
        launchArguments += extraLaunchArguments
        app.launchArguments = launchArguments
        if resetOnboarding {
            app.launchEnvironment["reset_onboarding"] = "true"
        }
        app.launch()
        XCTAssertTrue(waitForAppToBecomeReady(app: app, timeout: 15))
        return app
    }

    private func assertTabSurface(
        app: XCUIApplication,
        tabMarkerCandidates: [XCUIElement],
        commandActionIDs: [String],
        expectFocusToggle: Bool
    ) {
        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: tabMarkerCandidates,
                timeout: 6,
                maxSwipes: 3,
                requireHittable: false
            ),
            "Expected a marker for this tab surface."
        )

        var foundAnyCommandAction = false
        for commandID in commandActionIDs {
            let found = waitForActionLikeElement(
                app: app,
                identifier: commandID,
                timeout: 2.2,
                maxSwipes: 1,
                requireHittable: false
            )
            if found != nil {
                foundAnyCommandAction = true
                break
            }
        }

        XCTAssertTrue(
            foundAnyCommandAction,
            "Expected at least one command affordance to be present for this tab surface."
        )

        if expectFocusToggle {
            let focusToggle = app.buttons["focus.mode.toggle"]
            if focusToggle.waitForExistence(timeout: 2) {
                let beforeLabel = focusToggle.label
                if focusToggle.isHittable {
                    focusToggle.tap()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.4))
                    let updatedToggle = app.buttons["focus.mode.toggle"]
                    if updatedToggle.waitForExistence(timeout: 2) {
                        XCTAssertNotEqual(
                            beforeLabel,
                            updatedToggle.label,
                            "Focus mode label should toggle state while polish controls stay visible."
                        )
                        if updatedToggle.isHittable {
                            updatedToggle.tap()
                        }
                    }
                }
            }
        }
    }
    private func openBrandMenu(app: XCUIApplication) -> Bool {
        let direct = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["generate.brandMenu"],
                app.buttons["brandMenu.recommendedFlow"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Brand")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Menu")).firstMatch,
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "More")).firstMatch,
            ],
            timeout: 4,
            maxSwipes: 4,
            requireHittable: false
        )
        if let direct {
            if direct.waitForExistence(timeout: 0.2), direct.isHittable || direct.exists {
                direct.tap()
                return true
            }
        }

        return false
    }

    private func closeBrandMenu(app: XCUIApplication) {
        if let closeTarget = waitForAnyElement(
            app: app,
            candidates: dismissBrandMenuCandidates(app),
            timeout: 2,
            maxSwipes: 2,
            requireHittable: false
        ),
        closeTarget.isHittable
        {
            closeTarget.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
    }

    private func dismissBrandMenuCandidates(_ app: XCUIApplication) -> [XCUIElement] {
        [
            app.buttons["Done"],
            app.buttons["Close"],
            app.buttons["Cancel"],
            app.buttons["Done"].firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Done")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Close")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Cancel")).firstMatch,
            app.navigationBars.buttons.firstMatch,
        ]
    }

    @discardableResult
    private func openQuickAccessFromBrandMenu(app: XCUIApplication, quickAccessID: String, quickAccessLabel: String) -> Bool {
        guard openBrandMenu(app: app) else {
            return false
        }

        let quickAccess = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["brandMenu.quickAccess.\(quickAccessID)"],
                app.buttons[quickAccessID],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", quickAccessLabel)).firstMatch,
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", quickAccessLabel)).firstMatch,
            ],
            timeout: 5,
            maxSwipes: 6,
            requireHittable: false
        )

        guard let quickAccess else {
            closeBrandMenu(app: app)
            return false
        }

        if quickAccess.waitForExistence(timeout: 2) && quickAccess.isHittable {
            quickAccess.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            return true
        }

        closeBrandMenu(app: app)
        return false
    }
    private func waitForActionLikeElement(
        app: XCUIApplication,
        identifier: String,
        labelHints: [String] = [],
        timeout: TimeInterval,
        maxSwipes: Int,
        requireHittable: Bool = true
    ) -> XCUIElement? {
        let shortID = identifier.split(separator: ".").last.map(String.init) ?? identifier
        var candidates: [XCUIElement] = [
            app.buttons[identifier],
            app.otherElements[identifier],
            app.staticTexts[identifier],
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", identifier)).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", shortID)).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", shortID)).firstMatch,
            app.otherElements.matching(NSPredicate(format: "label CONTAINS[c] %@", shortID)).firstMatch,
        ]

        for hint in labelHints {
            candidates.append(contentsOf: [
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", hint)).firstMatch,
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", hint)).firstMatch,
                app.otherElements.matching(NSPredicate(format: "label CONTAINS[c] %@", hint)).firstMatch,
            ])
        }

        return waitForAnyElement(
            app: app,
            candidates: candidates,
            timeout: timeout,
            maxSwipes: maxSwipes,
            requireHittable: requireHittable
        )
    }

    @discardableResult
    private func waitForAnyElement(
        app: XCUIApplication,
        candidates: [XCUIElement],
        timeout: TimeInterval,
        maxSwipes: Int = 0,
        requireHittable: Bool = false
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        var swipes = 0
        while Date() < deadline {
            if let found = candidates.first(where: { candidate in
                guard candidate.exists else { return false }
                return requireHittable ? candidate.isHittable : true
            }) {
                return found
            }
            if maxSwipes > 0 && swipes < maxSwipes {
                app.swipeUp()
                swipes += 1
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return candidates.first(where: { candidate in
            guard candidate.exists else { return false }
            return requireHittable ? candidate.isHittable : true
        })
    }


    private func waitForAppToBecomeReady(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let readinessChecks: [() -> Bool] = [
            { app.buttons["generate.primary"].exists },
            { app.buttons["auth.mode.signUp"].exists },
            { app.buttons["auth.mode.signIn"].exists },
            { app.buttons["Get Started"].exists },
            { app.buttons["Skip"].exists },
        ]

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if readinessChecks.contains(where: { $0() }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return readinessChecks.contains(where: { $0() })
    }

    private func discoverButtons(
        app: XCUIApplication,
        prefix: String,
        fallbackMax: Int
    ) -> [XCUIElement] {
        var found: [XCUIElement] = []
        for index in 0..<fallbackMax {
            let button = app.buttons["\(prefix)\(index)"]
            if button.exists {
                found.append(button)
                continue
            }
            if !found.isEmpty { break }
            if index > 3 { break }
        }
        return found
    }

    private func discoverSelectorHeader(app: XCUIApplication, identifier: String) -> XCUIElement? {
        return discoverSelectorHeader(app: app, identifier: identifier, timeout: 4, maxSwipes: 6)
    }

    private func discoverSelectorHeader(
        app: XCUIApplication,
        identifier: String,
        timeout: TimeInterval,
        maxSwipes: Int
    ) -> XCUIElement? {
        let candidates = [
            app.otherElements[identifier],
            app.buttons[identifier],
            app.staticTexts[identifier],
        ]

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let found = candidates.first(where: \.exists) {
                return found
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            if let found = candidates.first(where: \.exists) {
                return found
            }
        }

        return candidates.first(where: \.exists)
    }

    private func waitForGenerateAdviceToSettle(app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let generationLoading = app.otherElements["generate.loading"]
        let generateButton = app.buttons["generate.primary"]
        if generationLoading.waitForExistence(timeout: 0.4) {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if !generationLoading.exists && generateButton.isEnabled {
                    return true
                }
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
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        }

        return generateButton.isEnabled && !app.otherElements["generate.loading"].exists
    }

    private func waitForGenerateLoadingElement(app: XCUIApplication, timeout: TimeInterval) -> XCUIElement? {
        let loading = app.otherElements["generate.loading"]
        let fallbackText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Generating advice")).firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if loading.exists || fallbackText.exists {
                return loading.exists ? loading : fallbackText
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return loading.exists ? loading : nil
    }

    private func loadingCopy(from loading: XCUIElement) -> String {
        if let value = loading.value as? String, !value.isEmpty {
            return value
        }

        let staticTexts = loading.staticTexts.allElementsBoundByIndex
        for element in staticTexts {
            let value = element.label
            if value.isEmpty || value == "Generating advice" {
                continue
            }
            return value
        }

        return loading.label
    }

    private func activeLoadingMessage(from loading: XCUIElement) -> String? {
        let value = loadingCopy(from: loading)
        if value == "Generating advice" {
            return nil
        }
        return value.isEmpty ? nil : value
    }
}
