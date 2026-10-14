import XCTest

/// Shared, strict helpers for the current product. Missing controls fail the test.
class BadviceUITestCase: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @discardableResult
    func launch(authenticated: Bool = true, extra: [String] = [], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-skip-onboarding", "-skip-splash"]
        if reset { app.launchArguments += ["-ui-testing-auth-reset", "-ui-testing-reset-data"] }
        if authenticated { app.launchArguments += ["-ui-testing-auth-skip"] }
        app.launchArguments += extra
        app.launch()
        XCTAssertTrue(app.buttons[authenticated ? "generate.primary" : "auth.guest"].waitForExistence(timeout: 20), app.debugDescription)
        return app
    }

    func control(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func reveal(_ element: XCUIElement, in app: XCUIApplication, direction: String = "up", swipes: Int = 8) {
        if app.keyboards.firstMatch.exists {
            let done = app.buttons["keyboard.done"].firstMatch
            if done.exists && done.isHittable { done.tap() }
        }
        _ = element.waitForExistence(timeout: 1)
        for _ in 0..<swipes {
            if element.exists {
                let key = element.identifier.isEmpty ? element.label : element.identifier
                let navigationControl = key.hasPrefix("tab.") || key == "casebook.organize.save"
                    || ["BackButton", "Back", "Close", "Cancel", "Save", "Done", "keyboard.done"].contains(key)
                let visibleCenter = element.frame.midY > 24 && element.frame.midY < app.frame.height - 124
                if (element.isHittable || !element.isEnabled) && (navigationControl || visibleCenter) { break }
            }
            let key = element.exists ? (element.identifier.isEmpty ? element.label : element.identifier) : ""
            let containing = app.scrollViews.containing(.any, identifier: key)
            let isVerticallyVisible = element.exists && element.frame.midY > 74 && element.frame.midY < app.frame.height - 124
            if isVerticallyVisible && (element.frame.midX < 0 || element.frame.midX > app.frame.width) {
                let horizontal = containing.allElementsBoundByIndex.last(where: { $0.isHittable }) ?? app.scrollViews.firstMatch
                swipeContent(horizontal, in: app, direction: element.frame.midX < 0 ? "right" : "left")
            } else {
                let outer = containing.firstMatch
                let scroll = !key.isEmpty && outer.exists && outer.isHittable
                    ? outer : app.scrollViews.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? app.scrollViews.firstMatch
                let scrollDown = element.exists ? element.frame.midY < 74 : direction == "down"
                swipeContent(scroll, in: app, direction: scrollDown ? "down" : "up")
            }
        }
        if !element.exists || (element.isEnabled && !element.isHittable) {
            capture("Unreachable control", app: app)
            print(app.debugDescription)
        }
        XCTAssertTrue(element.exists, "Missing control: \(element)")
        if element.isEnabled { XCTAssertTrue(element.isHittable, "Control is not reachable: \(element)") }
    }

    /// Keep gestures above the floating navigation and below the native title bar.
    func swipeContent(_ scroll: XCUIElement, in app: XCUIApplication, direction: String) {
        let bounds = scroll.frame.intersection(CGRect(x: 0, y: 80, width: app.frame.width, height: app.frame.height - 204))
        XCTAssertFalse(bounds.isEmpty, "Scroll content must be visible before a gesture")
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let horizontal = direction == "left" || direction == "right"
        let start = horizontal
            ? CGPoint(x: direction == "left" ? bounds.maxX - 20 : bounds.minX + 20, y: bounds.midY)
            : CGPoint(x: bounds.midX, y: direction == "up" ? bounds.maxY - 25 : bounds.minY + 25)
        let end = horizontal
            ? CGPoint(x: direction == "left" ? bounds.minX + 20 : bounds.maxX - 20, y: bounds.midY)
            : CGPoint(x: bounds.midX, y: direction == "up" ? bounds.minY + 25 : bounds.maxY - 25)
        origin.withOffset(CGVector(dx: start.x, dy: start.y)).press(forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: end.x, dy: end.y)))
    }

    func tap(_ id: String, in app: XCUIApplication, direction: String = "up") {
        let element = control(id, in: app)
        reveal(element, in: app, direction: direction)
        element.tap()
    }

    func type(_ value: String, field id: String, in app: XCUIApplication) {
        let field = app.textFields[id].exists ? app.textFields[id] : app.secureTextFields[id].exists ? app.secureTextFields[id] : app.textViews[id]
        reveal(field, in: app)
        field.tap()
        field.typeText(value)
    }

    func openSettings(_ app: XCUIApplication, advanced: Bool = false) {
        tap("tab.more", in: app)
        tap("brandMenu.quickAccess.settings", in: app)
        XCTAssertTrue(app.staticTexts["ADVICE ENGINE"].waitForExistence(timeout: 8))
        if advanced { tap("settings.advanced", in: app) }
    }

    func openParty(_ app: XCUIApplication) {
        tap("tab.more", in: app)
        tap("brandMenu.quickAccess.groupChallenges", in: app)
        XCTAssertTrue(app.staticTexts["Party mode"].waitForExistence(timeout: 8))
    }

    func generate(_ app: XCUIApplication) {
        tap("generate.primary", in: app, direction: "down")
        reveal(app.staticTexts["advice.text"], in: app)
        reveal(app.buttons["generate.save"], in: app)
        XCTAssertTrue(app.buttons["generate.save"].isEnabled)
    }

    func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func openAdvancedLink(_ title: String, app: XCUIApplication) {
        let text = app.staticTexts[title].firstMatch
        reveal(text, in: app)
        text.tap()
    }
}

final class BadviceUITests: BadviceUITestCase {
    func testLaunchShowsBrandedSplashUntilInitialScreenIsReady() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-skip-onboarding",
            "-ui-testing-auth-reset",
            "-ui-testing-reset-data",
            "-ui-testing-auth-skip",
        ]
        app.launch()

        let splash = app.descendants(matching: .any)
            .matching(identifier: "splash.screen")
            .firstMatch
        XCTAssertTrue(splash.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(splash.label.contains("Badvice"), app.debugDescription)
        capture("Badvice launch splash", app: app)

        let splashDismissal = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: splash
        )
        XCTAssertEqual(XCTWaiter.wait(for: [splashDismissal], timeout: 8), .completed, app.debugDescription)
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 20), app.debugDescription)
    }

    func testSmokeNavigationAndCoreInteractions() {
        let app = launch()
        capture("Advice — first viewport", app: app)
        XCTAssertTrue(app.buttons["generate.primary"].isHittable)
        generate(app)
        tap("generate.save", in: app)
        XCTAssertTrue(app.buttons["generate.save"].label.contains("Saved"))
        tap("generate.copy", in: app)
        tap("tab.favorites", in: app)
        XCTAssertTrue(app.staticTexts["Saved & recent"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Organize"].waitForExistence(timeout: 5))
        capture("Saved advice", app: app)
        tap("tab.chaosHub", in: app)
        XCTAssertTrue(app.staticTexts["Play"].waitForExistence(timeout: 8))
        capture("Play", app: app)
        tap("tab.quotes", in: app)
        XCTAssertTrue(app.staticTexts["TODAY'S BAD IDEA"].waitForExistence(timeout: 8))
        capture("Daily quote", app: app)
        tap("tab.generate", in: app)
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 8))
    }

    func testFreshGuestEntryPersistsAndProtectedAccountsStayOptional() {
        let app = launch(authenticated: false)
        capture("Guest entry", app: app)
        tap("auth.guest", in: app)
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 12))
        generate(app)
        tap("generate.save", in: app)
        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-splash", "-skip-onboarding"]
        app.launch()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 15))
        tap("tab.favorites", in: app)
        XCTAssertTrue(app.buttons["Organize"].waitForExistence(timeout: 8))
        openSettings(app)
        let guestEmail = app.staticTexts["settings.auth.email"]
        reveal(guestEmail, in: app)
        XCTAssertEqual(guestEmail.label, "Guest • this device only")
        XCTAssertFalse(app.buttons["settings.auth.changePassword"].exists)
    }

    func testLocalAuthSignupSignoutAndSigninFlow() {
        let app = launch(authenticated: false)
        type("Comedian", field: "auth.displayName", in: app)
        type("comedian@badvice.test", field: "auth.email", in: app)
        type("Badvice123", field: "auth.password", in: app)
        type("Badvice123", field: "auth.confirmPassword", in: app)
        tap("auth.primary", in: app)
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 15))
        openSettings(app)
        tap("settings.auth.signOut", in: app)
        XCTAssertTrue(app.buttons["auth.guest"].waitForExistence(timeout: 8))
        tap("auth.mode.signIn", in: app)
        type("Badvice123", field: "auth.password", in: app)
        tap("auth.primary", in: app)
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 15))
    }

    func testSettingsSuggestionPipelineAndAppleLocalModelSurfaces() {
        let app = launch()
        openSettings(app, advanced: true)
        tap("settings.row.suggestion.pipeline", in: app)
        XCTAssertTrue(app.staticTexts["Suggestion Pipeline"].waitForExistence(timeout: 8))
        capture("Suggestion pipeline", app: app)
    }

    func testSuggestionLabValidationAndSubmissionFlow() {
        let app = launch()
        openSettings(app, advanced: true)
        tap("settings.row.advice.suggestion.lab", in: app)
        let submit = app.buttons["suggestionLab.submit"]
        reveal(submit, in: app)
        XCTAssertFalse(submit.isEnabled)
        type("Status meeting", field: "Topic", in: app)
        type("Spend the entire meeting explaining why meetings are inefficient.", field: "Advice line", in: app)
        tap("suggestionLab.submit", in: app)
        reveal(app.staticTexts["Career • Status meeting"], in: app)
    }

    func testSocialUnavailableHasAnActionableDiagnostic() {
        let app = launch(extra: ["-ui-testing-force-social-unavailable"])
        openSettings(app, advanced: true)
        tap("settings.socialHealth.open", in: app)
        XCTAssertTrue(control("settings.socialHealth.status", in: app).waitForExistence(timeout: 8))
        let schemaCheck = control("settings.socialHealth.schemaCheck", in: app)
        reveal(schemaCheck, in: app)
        XCTAssertTrue(schemaCheck.isEnabled, "Development CloudKit probe should be available in Debug diagnostics")
        tap("settings.socialHealth.copyReport", in: app)
        capture("CloudKit unavailable diagnosis", app: app)
    }

    func testSignedDeviceDevelopmentCloudKitProbe() throws {
#if targetEnvironment(simulator)
        throw XCTSkip("The CloudKit probe intentionally runs only on a signed physical device.")
#else
        let app = launch()
        openSettings(app, advanced: true)
        tap("settings.socialHealth.open", in: app)

        let probe = control("settings.socialHealth.schemaCheck", in: app)
        reveal(probe, in: app)
        probe.tap()

        let result = control("settings.socialHealth.schemaCheck.result", in: app)
        let completed = NSPredicate(format: "exists == true")
        let completedExpectation = expectation(for: completed, evaluatedWith: result)
        wait(for: [completedExpectation], timeout: 60)
        XCTAssertTrue(
            result.label.contains("Passed:"),
            "CloudKit Development probe failed: \(result.label)"
        )
        capture("Development CloudKit probe passed", app: app)
#endif
    }
}


extension BadviceUITests {
    func testICloudConnectionProfileRequestsAndFeedWithExplicitMock() {
        let app = launch(extra: ["-ui-testing-social-mock", "-ui-testing-social-seed-incoming", "2"])
        openSettings(app)
        tap("settings.social.connection", in: app)
        type("mischief_qa", field: "social.handle", in: app)
        type("Mischief QA", field: "social.displayName", in: app)
        tap("social.createProfile", in: app)
        XCTAssertTrue(app.staticTexts["social.profile"].waitForExistence(timeout: 10))
        tap("social.accept.mock_seed_request_1", in: app)
        XCTAssertTrue(app.staticTexts["Friends · 1"].waitForExistence(timeout: 10))
        tap("social.decline.mock_seed_request_2", in: app)
        capture("iCloud profile and friends — explicit test backend", app: app)
        tap("social.feed", in: app)
        XCTAssertTrue(app.staticTexts["Friends feed"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["No bad ideas here yet"].exists)
    }

    func testAppleModelSelectionReportsActualProvider() {
        let app = launch(extra: ["-ui-testing-apple-model"])
        tap("generate.primary", in: app)
        let source = app.staticTexts["generate.source"]
        XCTAssertTrue(source.waitForExistence(timeout: 35))
        XCTAssertTrue(source.label.contains("Apple Intelligence") || source.label.contains("Bureau Engine"))
        if source.label.contains("Bureau Engine") {
            XCTAssertTrue(control("generate.notice", in: app).exists || app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Apple'")).count > 0)
        }
        reveal(source, in: app)
        capture("Apple model actual source", app: app)
    }
}
