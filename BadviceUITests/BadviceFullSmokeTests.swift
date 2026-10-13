import XCTest

final class BadviceFullSmokeTests: BadviceUITestCase {
    func testOnboardingFlowCompletesAndPersistsAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-auth-reset", "-ui-testing-auth-skip", "-ui-testing-reset-data"]
        app.launchEnvironment["reset_onboarding"] = "true"
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 20))
        capture("Onboarding", app: app)
        app.buttons["onboarding.start"].tap()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 15))
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "reset_onboarding")
        app.launchArguments = ["-ui-testing", "-skip-splash"]
        app.launch()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["onboarding.start"].exists)
    }

    func testBackgroundAndRelaunchPreserveSavedAdvice() {
        let app = launch()
        generate(app)
        tap("generate.save", in: app)
        tap("tab.favorites", in: app)
        reveal(app.buttons["Organize"].firstMatch, in: app)
        capture("Saved before background", app: app)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["Saved & recent"].waitForExistence(timeout: 8), "Foregrounding must preserve the current screen")
        reveal(app.buttons["Organize"].firstMatch, in: app)
        capture("Saved after foreground", app: app)
    }

    func testQuoteSuggestionValidationAndSubmissionFlow() {
        let app = launch()
        openSettings(app, advanced: true)
        tap("settings.row.quote.suggestion.lab", in: app)
        let submit = app.buttons["quoteSuggestionLab.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 8))
        XCTAssertFalse(submit.isEnabled)
        type("Department of Overthinking", field: "Source (optional)", in: app)
        type("If the deadline moves, you were early all along.", field: "Quote text", in: app)
        tap("quoteSuggestionLab.submit", in: app)
        let saved = app.staticTexts["Career - Department of Overthinking"]
        reveal(saved, in: app)
        XCTAssertTrue(saved.exists)
    }

    func testLocalAuthPasswordChangeAndDeleteFlow() {
        let app = launch()
        openSettings(app)
        tap("settings.auth.changePassword", in: app)
        // The root shortcut opens Advanced; password management remains a deliberate sheet.
        tap("settings.auth.changePassword", in: app)
        type("Badvice123", field: "settings.auth.currentPassword", in: app)
        type("BetterChaos456", field: "settings.auth.newPassword", in: app)
        type("BetterChaos456", field: "settings.auth.confirmNewPassword", in: app)
        app.buttons["Save"].tap()
        XCTAssertFalse(app.navigationBars["Change Password"].waitForExistence(timeout: 2))
        tap("settings.auth.deleteAccount", in: app)
        type("BetterChaos456", field: "settings.auth.deletePassword", in: app)
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["auth.guest"].waitForExistence(timeout: 12))
    }
}
