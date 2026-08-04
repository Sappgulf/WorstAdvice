import XCTest

/// Coverage for The Wire — the swipe-paged advice feed.
///
/// The behaviour that matters here is not that a card renders, but that a swipe
/// yields a *different* ruling without a visible stall. That is the whole premise
/// of the direction, and it depends on the look-ahead buffer staying topped up.
final class BadviceWireTests: XCTestCase {
    private let defaultLaunchArguments = [
        "-ui-testing",
        "-skip-onboarding",
        "-skip-splash",
        "-ui-testing-auth-reset",
        "-ui-testing-auth-skip",
        "-ui-testing-reset-data",
        // The Wire only self-fills under test when asked, so it never perturbs
        // the state other suites assert on. These tests are about the feed itself.
        "-ui-testing-wire-autofill",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchWire() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = defaultLaunchArguments
        app.launch()

        let wireTab = app.buttons["tab.wire"]
        XCTAssertTrue(wireTab.waitForExistence(timeout: 12), "The Wire tab should be in the shell")
        // The Wire is the launch tab, but tapping is harmless and makes the test
        // independent of a persisted tab order from a previous install.
        wireTab.tap()
        return app
    }

    func testWireShowsACardAndSwipeAdvancesToADifferentRuling() throws {
        let app = launchWire()

        XCTAssertTrue(
            app.buttons["wire.aim"].waitForExistence(timeout: 10),
            "The Wire chrome should appear"
        )

        let firstAdvice = app.staticTexts["wire.card.advice"]
        XCTAssertTrue(
            firstAdvice.waitForExistence(timeout: 20),
            "The Wire should generate a first ruling on its own"
        )
        let firstText = firstAdvice.label
        XCTAssertFalse(firstText.isEmpty, "A ruling should carry text")

        // Give the look-ahead buffer a moment to fill before paging.
        let secondCardReady = expectation(description: "look-ahead buffer filled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { secondCardReady.fulfill() }
        wait(for: [secondCardReady], timeout: 6)

        app.swipeUp(velocity: .fast)

        let changed = NSPredicate(format: "label != %@", firstText)
        expectation(for: changed, evaluatedWith: app.staticTexts["wire.card.advice"])
        waitForExpectations(timeout: 20) { error in
            XCTAssertNil(error, "Swiping should advance The Wire to a different ruling")
        }
    }

    func testWireSaveActionTogglesToSaved() throws {
        let app = launchWire()

        XCTAssertTrue(
            app.staticTexts["wire.card.advice"].waitForExistence(timeout: 20),
            "The Wire should have a ruling to save"
        )

        let save = app.buttons["wire.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 6))
        XCTAssertEqual(save.label, "Save")
        save.tap()

        let saved = NSPredicate(format: "label == %@", "Saved")
        expectation(for: saved, evaluatedWith: app.buttons["wire.save"])
        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error, "Saving from The Wire should mark the ruling as saved")
        }
    }

    func testAimSheetOpensAndApplies() throws {
        let app = launchWire()

        let aim = app.buttons["wire.aim"]
        XCTAssertTrue(aim.waitForExistence(timeout: 10))
        aim.tap()

        let apply = app.buttons["wire.aim.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 6), "The aim sheet should present")
        apply.tap()

        XCTAssertTrue(
            app.staticTexts["wire.card.advice"].waitForExistence(timeout: 20),
            "Applying a new aim should refill The Wire"
        )
    }
}
