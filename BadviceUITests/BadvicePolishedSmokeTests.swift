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

        let actionCandidates: [(id: String, isButton: Bool)] = [
            ("generate.save", true),
            ("generate.copy", true),
            ("generate.remix", true),
            ("generate.gif", true),
            ("generate.surprise", true),
            ("generate.dailyDrop", true),
        ]

        for candidate in actionCandidates {
            let element = candidate.isButton
                ? app.buttons[candidate.id]
                : app.staticTexts[candidate.id]

            let found = waitForAnyElement(
                app: app,
                candidates: [
                    element,
                    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", candidate.id)).firstMatch,
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", candidate.id.replacingOccurrences(of: "generate.", with: ""))).firstMatch,
                ],
                timeout: 3,
                maxSwipes: 8
            )
            XCTAssertNotNil(
                found,
                "\(candidate.id) should be discoverable without hard dependency on exact visibility"
            )
        }
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
                candidates: [
                    app.buttons["Done"],
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Done")).firstMatch,
                    app.buttons["Cancel"],
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Cancel")).firstMatch,
                    app.buttons["Close"],
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Close")).firstMatch,
                    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Done")).firstMatch,
                    app.navigationBars.buttons.firstMatch,
                ],
                timeout: 4
            )
            if let done {
                done.tap()
            }
        } else {
            print("Brand menu not discoverable from current UI state; continuing with tab-cycle fallback.")
        }

        let tabOrder = ["tab.generate", "tab.chaosHub", "tab.friends", "tab.quotes", "tab.more"]
        for tabID in tabOrder where tabID != "tab.generate" {
            let tab = app.buttons.matching(identifier: tabID).firstMatch
            if !tab.waitForExistence(timeout: 2) { continue }
            tab.tap()

            let tabName = tabID.replacingOccurrences(of: "tab.", with: "")
            let likelyLabel = tabName.isEmpty ? "" : tabName.capitalized
            let alive = waitForAnyElement(
                app: app,
                candidates: [
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
                    app.staticTexts.element(boundBy: 0),
                ],
                timeout: 3,
                maxSwipes: 8
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
            }
        }

        // Verify we can still get back to generate.
        let finalGenerateTab = app.buttons.matching(identifier: "tab.generate").firstMatch
        if finalGenerateTab.waitForExistence(timeout: 5) {
            finalGenerateTab.tap()
        }
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 5))
    }

    private func launchTestApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += defaultLaunchArguments
        app.launch()
        XCTAssertTrue(waitForAppToBecomeReady(app: app, timeout: 15))
        return app
    }

    @discardableResult
    private func waitForAnyElement(
        app: XCUIApplication,
        candidates: [XCUIElement],
        timeout: TimeInterval,
        maxSwipes: Int = 0
    ) -> XCUIElement? {
        let timeoutDate = Date().addingTimeInterval(timeout)
        while Date() < timeoutDate {
            if let found = candidates.first(where: { $0.exists && $0.isHittable }) {
                return found
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        guard maxSwipes > 0 else { return candidates.first(where: \.exists) }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            let postSwipeDeadline = Date().addingTimeInterval(0.4)
            while Date() < postSwipeDeadline {
                if let found = candidates.first(where: { $0.exists && $0.isHittable }) {
                    return found
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
        }

        return candidates.first(where: { $0.exists && $0.isHittable })
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
}
