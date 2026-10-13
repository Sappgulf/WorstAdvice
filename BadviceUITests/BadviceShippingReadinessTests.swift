import XCTest

final class BadviceShippingReadinessTests: BadviceUITestCase {
    func testShippingReadiness_BootAndCoreTabs() {
        let app = launch()
        for (id, title) in [("generate", "badvice."), ("favorites", "Saved & recent"), ("chaosHub", "Play"), ("quotes", "The daily bad idea")] {
            tap("tab.\(id)", in: app)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 8))
            capture("Core tab — \(id)", app: app)
        }
        tap("tab.more", in: app)
        tap("brandMenu.quickAccess.explore", in: app)
        XCTAssertTrue(app.staticTexts["The status meeting"].waitForExistence(timeout: 8))
        app.staticTexts["The status meeting"].tap()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["generate.situation"].value as? String == "I need to explain a project delay without sounding worried.")
    }

    func testShippingReadiness_SettingsAndSocialHealthPath() {
        let app = launch(extra: ["-ui-testing-force-social-unavailable"])
        openSettings(app, advanced: true)
        tap("settings.socialHealth.open", in: app)
        XCTAssertTrue(control("settings.socialHealth.report", in: app).waitForExistence(timeout: 8))
        capture("Social health", app: app)
    }
}
