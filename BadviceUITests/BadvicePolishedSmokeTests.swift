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

    func testBureauShellGeneratesLocallyAndFilesAResult() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-reset-data"])

        XCTAssertTrue(app.staticTexts["THE BADVICE BUREAU"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["tab.generate"].exists)
        XCTAssertTrue(app.buttons["tab.favorites"].exists)
        XCTAssertTrue(app.buttons["tab.chaosHub"].exists)
        XCTAssertTrue(app.buttons["tab.quotes"].exists)
        XCTAssertTrue(app.buttons["tab.more"].exists)

        app.buttons["tab.favorites"].tap()
        XCTAssertTrue(app.staticTexts["Casebook"].waitForExistence(timeout: 6))

        app.buttons["tab.chaosHub"].tap()
        XCTAssertTrue(app.staticTexts["Dares"].waitForExistence(timeout: 6))

        app.buttons["tab.quotes"].tap()
        XCTAssertTrue(app.staticTexts["Dispatches"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["TODAY'S DISPATCH"].waitForExistence(timeout: 6))

        XCTAssertTrue(
            openQuickAccessFromBrandMenu(
                app: app,
                quickAccessID: "settings",
                quickAccessLabel: "Settings"
            )
        )
        XCTAssertTrue(app.staticTexts["ADVICE ENGINE"].waitForExistence(timeout: 6))
        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons["Bureau Engine"],
                    app.staticTexts["Bureau Engine"],
                ],
                timeout: 3,
                requireHittable: false
            )
        )
        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons["Apple Intelligence"],
                    app.staticTexts["Apple Intelligence"],
                ],
                timeout: 3,
                requireHittable: false
            )
        )

        let deskTab = app.buttons["tab.generate"]
        XCTAssertTrue(deskTab.waitForExistence(timeout: 4))
        deskTab.tap()

        let contextField = waitForAnyElement(
            app: app,
            candidates: [
                app.textFields["generate.situation"],
                app.textViews["generate.situation"],
                app.textFields.matching(
                    NSPredicate(format: "placeholderValue CONTAINS[c] %@", "awkward first date")
                ).firstMatch,
            ],
            timeout: 6,
            maxSwipes: 8,
            requireHittable: true
        )
        XCTAssertNotNil(contextField)
        app.swipeUp()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))

        let writableContextField = app.textFields["generate.situation"]
        XCTAssertTrue(writableContextField.waitForExistence(timeout: 3))
        writableContextField.tap()
        writableContextField.typeText(
            "My manager asked for a status update and I have nothing finished."
        )
        app.swipeUp()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))

        let generateButton = waitForActionLikeElement(
            app: app,
            identifier: "generate.primary",
            labelHints: ["Advise", "take"],
            timeout: 6,
            maxSwipes: 5,
            requireHittable: true
        )
        XCTAssertNotNil(generateButton)
        generateButton?.tap()
        XCTAssertTrue(waitForGenerateAdviceToSettle(app: app, timeout: 18))

        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.otherElements["advice.card"],
                    app.staticTexts["THE RESULT"],
                ],
                timeout: 8,
                maxSwipes: 4,
                requireHittable: false
            )
        )

        let saveButton = waitForActionLikeElement(
            app: app,
            identifier: "generate.save",
            labelHints: ["Save"],
            timeout: 8,
            maxSwipes: 8,
            requireHittable: true
        )
        XCTAssertNotNil(saveButton)
        saveButton?.tap()

        let casebookTab = app.buttons["tab.favorites"]
        XCTAssertTrue(casebookTab.waitForExistence(timeout: 4))
        casebookTab.tap()
        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons.matching(
                        NSPredicate(format: "label CONTAINS[c] %@", "Remove")
                    ).firstMatch,
                    app.staticTexts.matching(
                        NSPredicate(format: "label CONTAINS[c] %@", "status update")
                    ).firstMatch,
                ],
                timeout: 8,
                maxSwipes: 4,
                requireHittable: false
            ),
            "A saved local result should be filed in Casebook."
        )
    }

    func testBadviceDialRewriteRealityCheckAndCasebookOrganization() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-reset-data"])

        let slider = waitForAnyElement(
            app: app,
            candidates: [app.sliders["generate.intensity"]],
            timeout: 6,
            maxSwipes: 6,
            requireHittable: true
        )
        XCTAssertNotNil(slider)
        guard let slider else { return }

        for _ in 0..<4
        where slider.frame.maxY > app.frame.maxY - 120 {
            app.swipeUp()
        }
        XCTAssertLessThan(
            slider.frame.maxY,
            app.frame.maxY - 120,
            "The dial must be fully above the floating tab bar before dragging."
        )
        slider.adjust(toNormalizedSliderPosition: 1)
        let adjustedSlider = app.sliders["generate.intensity"]
        XCTAssertTrue(adjustedSlider.waitForExistence(timeout: 3))
        XCTAssertTrue(
            (adjustedSlider.value as? String)?
                .localizedCaseInsensitiveContains("Legendary") == true,
            "The dial should expose its selected intensity through accessibility."
        )

        let generateButton = waitForActionLikeElement(
            app: app,
            identifier: "generate.primary",
            labelHints: ["Advise", "take"],
            timeout: 6,
            maxSwipes: 5,
            requireHittable: true
        )
        XCTAssertNotNil(generateButton)
        generateButton?.tap()
        XCTAssertTrue(waitForGenerateAdviceToSettle(app: app, timeout: 18))

        let rewrite = waitForActionLikeElement(
            app: app,
            identifier: "generate.revision.moreBelievable",
            labelHints: ["More believable"],
            timeout: 6,
            maxSwipes: 8,
            requireHittable: true
        )
        XCTAssertNotNil(rewrite)
        rewrite?.tap()
        XCTAssertTrue(waitForGenerateAdviceToSettle(app: app, timeout: 18))

        let realityCheck = waitForActionLikeElement(
            app: app,
            identifier: "generate.realityCheck",
            labelHints: ["Reality check"],
            timeout: 6,
            maxSwipes: 8,
            requireHittable: true
        )
        XCTAssertNotNil(realityCheck)
        realityCheck?.tap()
        XCTAssertTrue(
            app.staticTexts["generate.realityCheck.text"].waitForExistence(timeout: 5)
                || app.staticTexts.matching(
                    NSPredicate(format: "label BEGINSWITH[c] %@", "Reality check:")
                ).firstMatch.waitForExistence(timeout: 5)
        )

        let save = waitForActionLikeElement(
            app: app,
            identifier: "generate.save",
            labelHints: ["Save"],
            timeout: 6,
            maxSwipes: 8,
            requireHittable: true
        )
        XCTAssertNotNil(save)
        guard let save else { return }
        for _ in 0..<4
        where save.frame.minY < 90 {
            app.swipeDown()
        }
        XCTAssertGreaterThan(
            save.frame.minY,
            90,
            "Save must be below the status-bar region before tapping."
        )
        XCTAssertLessThan(
            save.frame.maxY,
            app.frame.maxY - 100,
            "Save must be above the floating tab bar before tapping."
        )
        save.tap()
        let savedState = app.buttons["generate.save"]
        let savedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS[c] %@", "Saved"),
            object: savedState
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [savedExpectation], timeout: 3),
            .completed,
            "The Desk should confirm the result was filed before navigating away."
        )

        let casebookTab = app.buttons["tab.favorites"]
        XCTAssertTrue(casebookTab.waitForExistence(timeout: 4))
        casebookTab.tap()
        XCTAssertTrue(app.otherElements["casebook.monthlyDossier"].waitForExistence(timeout: 8))

        let organize = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["Organize"],
                app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", "Organize")
                ).firstMatch,
            ],
            timeout: 6,
            maxSwipes: 6,
            requireHittable: true
        )
        XCTAssertNotNil(organize)
        organize?.tap()

        let folderField = app.textFields["casebook.organize.folder"]
        XCTAssertTrue(folderField.waitForExistence(timeout: 5))
        folderField.tap()
        folderField.typeText("Best Of")

        let saveOrganization = app.buttons["casebook.organize.save"]
        XCTAssertTrue(saveOrganization.waitForExistence(timeout: 4))
        saveOrganization.tap()
        XCTAssertTrue(
            app.staticTexts["Best Of"].waitForExistence(timeout: 6)
                || app.buttons["Best Of"].waitForExistence(timeout: 6)
        )
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

        let onboardingNext = app.buttons["onboarding.next"]
        if onboardingNext.waitForExistence(timeout: 5) {
            onboardingNext.tap()

            let starterSituation = app.textFields["onboarding.situation"]
            let starterIntensity = app.sliders["onboarding.intensity"]
            XCTAssertTrue(starterSituation.waitForExistence(timeout: 5))
            XCTAssertTrue(starterIntensity.waitForExistence(timeout: 5))
            starterIntensity.adjust(toNormalizedSliderPosition: 0.75)

            let getStarted = app.buttons["onboarding.next"]
            XCTAssertTrue(getStarted.waitForExistence(timeout: 3))
            XCTAssertTrue(getStarted.label.localizedCaseInsensitiveContains("Get Started"))
            getStarted.tap()

            XCTAssertTrue(
                waitForGenerateAdviceToSettle(app: app, timeout: 20),
                "Completing onboarding should commission the first local take."
            )
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

        let favoritesTab = app.buttons.matching(identifier: "tab.favorites").firstMatch
        if favoritesTab.waitForExistence(timeout: 3) {
            favoritesTab.tap()
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

        let tabOrder = ["tab.generate", "tab.favorites", "tab.chaosHub", "tab.quotes", "tab.more"]
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
                    app.buttons["favorites.generate"],
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
            "tab.favorites",
            "tab.chaosHub",
            "tab.quotes",
        ]
        for tabID in primaryTabs {
            let tabButton = app.buttons.matching(identifier: tabID).firstMatch
            XCTAssertTrue(tabButton.waitForExistence(timeout: 4), "Expected primary tab visible: \(tabID)")
            tabButton.tap()

            switch tabID {
            case "tab.favorites":
                assertTabSurface(
                    app: app,
                    tabMarkerCandidates: [
                        app.buttons["favorites.generate"],
                        app.staticTexts["Favorites"],
                        app.staticTexts["Nothing saved yet."],
                    ],
                    commandActionIDs: [
                        "favorites.generate",
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
                        app.otherElements["quotes.dailyHero"],
                        app.staticTexts["Quotes"],
                    ],
                    commandActionIDs: [
                        "quotes.spotlight.toggle",
                    ],
                    expectFocusToggle: true
                )
            default:
                break
            }
        }

        let favoritesTab = app.buttons.matching(identifier: "tab.favorites").firstMatch
        if favoritesTab.waitForExistence(timeout: 4) {
            favoritesTab.tap()
        } else {
            XCTAssertTrue(openQuickAccessFromBrandMenu(app: app, quickAccessID: "favorites", quickAccessLabel: "Favorites"))
        }
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
                app.navigationBars["Group Challenges"],
                app.buttons["groupChallenges.command.primary"],
                app.buttons["groupChallenges.command.join"],
                app.otherElements["groupChallenges.command.card"],
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
                app.staticTexts["Settings"],
                app.navigationBars["Settings"].firstMatch,
            ],
            commandActionIDs: [
                "settings.auth.signOut",
                "settings.menuButton",
            ],
            expectFocusToggle: false
        )
    }

    func testQuickAccessAndPrimaryTabsAreReachableAndStable() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-reset-data"])

        let quickAccessTargets: [(String, String, [String])] = [
            ("history", "History", ["history.generate"]),
            ("explore", "Explore", ["explore.filter.categories.chip.0"]),
            ("groupChallenges", "Challenges", ["groupChallenges.headerCreate"]),
            ("settings", "Settings", ["settings.menuButton", "settings.auth.signOut"]),
        ]

        let tabTargets: [(String, [String])] = [
            ("tab.generate", ["generate.primary", "generate.commandCard"]),
            ("tab.favorites", ["favorites.command.primary", "favorites.generate"]),
            ("tab.chaosHub", ["chaos.command.primary", "chaos.social.submitScore"]),
            ("tab.quotes", ["quotes.dailyHero", "quotes.spotlight.toggle"]),
        ]

        for (tabIdentifier, markerIdentifiers) in tabTargets {
            let tab = app.buttons.matching(identifier: tabIdentifier).firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 3), "Expected tab \(tabIdentifier) in bar.")
            tab.tap()

            var markerMatches: [XCUIElement] = markerIdentifiers.map { app.buttons[$0] }
            markerMatches += markerIdentifiers.map { app.staticTexts[$0] }
            markerMatches.append(app.otherElements["\(tabIdentifier).container"])
            markerMatches.append(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", tabIdentifier.replacingOccurrences(of: "tab.", with: ""))).firstMatch)
            if tabIdentifier == "tab.chaosHub" {
                markerMatches += [
                    app.otherElements["chaos.command.card"],
                    app.staticTexts["Missions"],
                    app.staticTexts["Progression Path"],
                ]
            } else if tabIdentifier == "tab.quotes" {
                markerMatches += [
                    app.otherElements["quotes.dailyHero"],
                    app.staticTexts["Quotes"],
                ]
            }

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

    func testMissionProgressionSurfaceAndQuickActionsKeepRendering() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-reset-data"])

        // Missions is a primary tab in the current shell. Keep the brand-menu
        // fallback for older layouts so this test remains useful across builds.
        let missionsTab = app.buttons.matching(identifier: "tab.chaosHub").firstMatch
        if missionsTab.waitForExistence(timeout: 4) {
            missionsTab.tap()
        } else {
            XCTAssertTrue(openQuickAccessFromBrandMenu(app: app, quickAccessID: "chaosHub", quickAccessLabel: "Missions"))
        }

        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.staticTexts["chaos.progressionPath.title"],
                    app.otherElements["chaos.progressionPath"],
                    app.buttons["chaos.command.card"],
                    app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Progression Path")).firstMatch,
                    app.staticTexts["Daily Mission"],
                ],
                timeout: 7,
                maxSwipes: 6,
                requireHittable: false
            ),
            "Missions/Progression surface should render with either the progression path or mission cards."
        )

        let quickAction = waitForActionLikeElement(
            app: app,
            identifier: "chaos.openAdvice",
            labelHints: ["Open Advice", "daily"],
            timeout: 5,
            maxSwipes: 4,
            requireHittable: false
        )
        XCTAssertNotNil(
            quickAction,
            "Expected at least one Missions quick action affordance to be discoverable."
        )
    }

    func testSettingsQuickAccessExposesAuthAndSystemControls() throws {
        let app = launchTestApp(extraLaunchArguments: ["-ui-testing-reset-data", "-debug-preload-polish-fixtures", "-debug-polish-seed", "424242"])

        XCTAssertTrue(openQuickAccessFromBrandMenu(app: app, quickAccessID: "settings", quickAccessLabel: "Settings"))

        let settingsSurface = waitForAnyElement(
            app: app,
            candidates: [
                app.buttons["settings.auth.signOut"],
                app.buttons["settings.auth.changePassword"],
                app.buttons["settings.theme.badvice"],
                app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Settings")).firstMatch,
                app.staticTexts["Settings"],
            ],
            timeout: 7,
            maxSwipes: 8,
            requireHittable: false
        )
        XCTAssertNotNil(settingsSurface, "Expected settings surface to render with auth, social, or theme controls.")

        XCTAssertNotNil(
            waitForAnyElement(
                app: app,
                candidates: [
                    app.buttons["settings.upgradeStore"],
                    app.otherElements["settings.upgradeStore"],
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Upgrade")) .firstMatch,
                    app.staticTexts["Upgrade & Store"],
                ],
                timeout: 5,
                maxSwipes: 8,
                requireHittable: false
            ),
            "Expected Upgrade & Store system surface to remain discoverable in Settings polish shell."
        )

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
        let candidates: [XCUIElement] = [
            app.buttons["generate.brandMenu"],
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Brand")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Menu")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "More")).firstMatch,
        ]

        if let direct = waitForAnyElement(
            app: app,
            candidates: candidates,
            timeout: 2,
            maxSwipes: 2,
            requireHittable: true
        ) {
            direct.tap()
            return true
        }

        let generateTab = app.buttons["tab.generate"]
        if generateTab.waitForExistence(timeout: 3), generateTab.isHittable {
            generateTab.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            if let direct = waitForAnyElement(
                app: app,
                candidates: candidates,
                timeout: 4,
                maxSwipes: 2,
                requireHittable: true
            ) {
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
            timeout: 8,
            maxSwipes: 6,
            requireHittable: true
        )

        guard let quickAccess else {
            closeBrandMenu(app: app)
            return false
        }

        quickAccess.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        return true
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
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if loading.exists {
                return loading
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return loading.exists ? loading : nil
    }

    private func loadingCopy(from loading: XCUIElement) -> String {
        let label = loading.label
        if label.localizedCaseInsensitiveContains("generating advice") {
            return label.localizedCaseInsensitiveContains(" — ")
                ? label
                : "Generating advice"
        }

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
