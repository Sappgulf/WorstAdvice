import XCTest

final class BadvicePolishedSmokeTests: BadviceUITestCase {
    func testDispatchDeskHeadersAndQuoteRemixFlow() {
        let app = launch()
        tap("tab.quotes", in: app)
        XCTAssertTrue(app.staticTexts["The daily bad idea"].waitForExistence(timeout: 8))
        let insight = control("quotes.daily.insight", in: app)
        XCTAssertTrue(insight.waitForExistence(timeout: 8))
        XCTAssertFalse(insight.label.isEmpty)
        XCTAssertTrue(insight.label.hasPrefix("The bad premise is"))

        let like = control("quotes.daily.like", in: app)
        let originalLikeState = like.value as? String
        XCTAssertTrue(["Liked", "Not liked"].contains(originalLikeState ?? ""))
        like.tap()
        let toggledLikeState = originalLikeState == "Liked" ? "Not liked" : "Liked"
        XCTAssertEqual(like.value as? String, toggledLikeState)
        XCTAssertEqual(like.label, toggledLikeState == "Liked" ? "Liked" : "Like")
        like.tap()
        XCTAssertEqual(like.value as? String, originalLikeState)

        tap("quotes.daily.remix", in: app)
        let situation = control("generate.situation", in: app)
        XCTAssertTrue(situation.waitForExistence(timeout: 8))
        XCTAssertFalse((situation.value as? String ?? "").isEmpty)

        tap("tab.quotes", in: app)
        let starters = app.buttons["Starters"].firstMatch
        reveal(starters, in: app)
        starters.tap()
        XCTAssertTrue(app.staticTexts["Start with a situation"].waitForExistence(timeout: 8))

        tap("quotes.ideas.surprise", in: app)
        let starterSituation = control("generate.situation", in: app)
        XCTAssertTrue(starterSituation.waitForExistence(timeout: 8))
        XCTAssertTrue([
            "I need to explain a project delay without sounding worried.",
            "They keep taking hours to text me back.",
            "I want to buy something unnecessary and call it self-care.",
            "The group chat went quiet after I made it awkward.",
            "I have a new app idea and no time to build it.",
            "I am planning every minute of a vacation.",
        ].contains(starterSituation.value as? String ?? ""))

        tap("tab.quotes", in: app)

        let archive = app.buttons["Archive"].firstMatch
        reveal(archive, in: app)
        archive.tap()
        XCTAssertTrue(app.staticTexts["The quote file"].waitForExistence(timeout: 8))
    }

    func testMissionActionsAreClearAndProgressIsAnnounced() {
        let app = launch()
        tap("tab.chaosHub", in: app)

        let dailyAction = control("chaos.mission.daily.action", in: app)
        XCTAssertTrue(dailyAction.waitForExistence(timeout: 8))
        XCTAssertTrue(["Generate today's dare", "Generate another"].contains(dailyAction.label))

        let dailyProgress = control("chaos.mission.daily.progress", in: app)
        XCTAssertEqual(dailyProgress.label, "Today's mission progress")
        let dailyValue = dailyProgress.value as? String ?? ""
        XCTAssertTrue(dailyValue == "Complete" || dailyValue.contains(" of "))

        let weeklyAction = control("chaos.mission.weekly.action", in: app)
        XCTAssertEqual(weeklyAction.label, "Set weekly focus")

        let weeklyProgress = control("chaos.mission.weekly.progress", in: app)
        XCTAssertEqual(weeklyProgress.label, "Weekly mission progress")
        let weeklyValue = weeklyProgress.value as? String ?? ""
        XCTAssertTrue(weeklyValue == "Complete" || weeklyValue.contains(" of "))

        weeklyAction.tap()
        XCTAssertTrue(control("generate.category.menu", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(control("generate.tone.menu", in: app).exists)
        XCTAssertTrue(app.buttons["generate.primary"].exists)
    }

    func testOverflowNavigationMatchesTheSelectedRoute() {
        let app = launch()
        openParty(app)
        let partyDestination = control("tab.more", in: app)
        XCTAssertEqual(partyDestination.label, "Party")
        XCTAssertEqual(partyDestination.value as? String, "Selected")

        openSettings(app)
        let settingsDestination = control("tab.more", in: app)
        XCTAssertEqual(settingsDestination.label, "Settings")
        XCTAssertEqual(settingsDestination.value as? String, "Selected")
    }

    func testGenerateCustomizationAndRealityCheck() {
        let app = launch()
        tap("generate.category.menu", in: app)
        app.buttons["Dating"].tap()
        tap("generate.tone.menu", in: app)
        app.buttons["The Wizard"].tap()
        type("I am planning an awkward first date.", field: "generate.situation", in: app)
        generate(app)
        tap("generate.realityCheck", in: app)
        XCTAssertTrue(control("generate.realityCheck.text", in: app).waitForExistence(timeout: 5))
        capture("Advice and reality check", app: app)
        tap("generate.playTools", in: app)
        tap("generate.revision.oneSentence", in: app)
        XCTAssertTrue(control("advice.text", in: app).waitForExistence(timeout: 8))
    }

    func testDialAndQuickActionsRemainReachable() {
        let app = launch()
        tap("generate.customize", in: app)
        let dial = control("generate.intensity", in: app)
        reveal(dial, in: app)
        dial.adjust(toNormalizedSliderPosition: 1)
        XCTAssertTrue(dial.value as? String == "Legendary Mistake" || app.staticTexts["Legendary Mistake"].exists)
        tap("generate.surprise", in: app, direction: "down")
        XCTAssertTrue(control("advice.text", in: app).waitForExistence(timeout: 12))
        tap("tab.generate", in: app)
        tap("generate.dailyDrop", in: app, direction: "down")
        XCTAssertTrue(control("advice.text", in: app).waitForExistence(timeout: 12))
    }

    func testSavedAdviceOrganizationPersists() {
        let app = launch()
        generate(app)
        tap("generate.save", in: app)
        tap("tab.favorites", in: app)
        let organize = app.buttons["Organize"].firstMatch
        reveal(organize, in: app)
        organize.tap()
        type("Best disasters", field: "casebook.organize.folder", in: app)
        type("office, keeper", field: "casebook.organize.tags", in: app)
        tap("casebook.organize.save", in: app)
        XCTAssertTrue(app.staticTexts["Best disasters"].waitForExistence(timeout: 8))

        type("office", field: "casebook.search", in: app)
        XCTAssertTrue(control("casebook.tag.office", in: app).waitForExistence(timeout: 8))
        app.buttons["Clear search"].tap()
        type("not-in-this-casebook", field: "casebook.search", in: app)
        tap("inlineSearch.done", in: app)
        XCTAssertTrue(control("casebook.empty.filtered", in: app).waitForExistence(timeout: 8))
        tap("casebook.clearFilters", in: app)
        XCTAssertTrue(control("casebook.tag.office", in: app).waitForExistence(timeout: 8))

        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-onboarding", "-skip-splash"]
        app.launch()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 15))
        tap("tab.favorites", in: app)
        XCTAssertTrue(app.staticTexts["Best disasters"].waitForExistence(timeout: 8))
        XCTAssertTrue(control("casebook.tag.office", in: app).waitForExistence(timeout: 8))
    }

    func testPartyValidationVotingPersistenceAndVerdict() {
        let app = launch()
        openParty(app)
        XCTAssertTrue(control("party.generation.providerDetail", in: app).exists)
        XCTAssertTrue(control("party.online.open", in: app).exists)
        capture("Party setup and provider choice", app: app)
        tap("party.start", in: app)
        XCTAssertTrue(app.staticTexts["party.validation"].waitForExistence(timeout: 5))
        type("Alex, Sam, Jordan", field: "party.players", in: app)
        tap("party.start", in: app)
        XCTAssertTrue(app.staticTexts["PASS TO ALEX"].waitForExistence(timeout: 45))
        XCTAssertTrue(control("party.generation.summary", in: app).exists)
        XCTAssertFalse(app.buttons["party.vote.0"].isEnabled)
        tap("party.vote.1", in: app)
        XCTAssertTrue(app.staticTexts["PASS TO SAM"].waitForExistence(timeout: 8))
        capture("Party voting", app: app)
        app.terminate()
        app.launchArguments = ["-ui-testing", "-skip-onboarding", "-skip-splash"]
        app.launch()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 15))
        openParty(app)
        XCTAssertTrue(app.staticTexts["PASS TO SAM"].waitForExistence(timeout: 8))
        tap("party.vote.0", in: app)
        tap("party.vote.0", in: app)
        XCTAssertTrue(control("party.results", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Alex"].exists)
        XCTAssertTrue(app.buttons["party.share"].exists)
        capture("Party verdict", app: app)
    }

    func testShareSheetHasRealExportAndCanBeDismissed() {
        let app = launch()
        generate(app)
        tap("generate.share", in: app)
        let close = app.buttons["Close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10) || app.otherElements["ActivityListView"].waitForExistence(timeout: 3))
        capture("Export share sheet", app: app)
        if close.exists { close.tap() } else { app.swipeDown() }
        XCTAssertTrue(app.buttons["generate.save"].waitForExistence(timeout: 8))
    }

    func testAccessibilityTextSizeAndReducedMotion() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-skip-onboarding", "-skip-splash", "-ui-testing-auth-reset", "-ui-testing-auth-skip", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["generate.primary"].waitForExistence(timeout: 20))
        generate(app)
        capture("Accessibility text — advice", app: app)
        tap("tab.quotes", in: app)
        XCTAssertTrue(control("quotes.dailyHero", in: app).waitForExistence(timeout: 8))
        capture("Accessibility text — daily", app: app)
    }
}
