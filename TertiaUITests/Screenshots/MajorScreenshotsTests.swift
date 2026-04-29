//
//  MajorScreenshotsTests.swift
//  TertiaUITests
//
//  Captures one screenshot per major screen. Output: /tmp/tertia-screenshots/major-*.png
//

import XCTest

final class MajorScreenshotsTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchPastOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
        return app
    }

    @MainActor
    private func launchAtOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "0"]
        app.launch()
        return app
    }

    /// Wait briefly for the deal animation to settle before capturing a game screen.
    private func waitForDealAnimation() {
        Thread.sleep(forTimeInterval: 1.0)
    }

    // MARK: - Mode Select & Tabs

    @MainActor
    func testModeSelect() throws {
        let app = launchPastOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        capture("major-mode-select")
    }

    @MainActor
    func testStatsTab() throws {
        let app = launchPastOnboarding()
        app.buttons["Stats"].tap()
        XCTAssertTrue(app.staticTexts["No runs yet"].waitForExistence(timeout: 3))
        capture("major-stats")
    }

    @MainActor
    func testSettingsTab() throws {
        let app = launchPastOnboarding()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Theme"].waitForExistence(timeout: 3))
        capture("major-settings")
    }

    @MainActor
    func testRulesView() throws {
        let app = launchPastOnboarding()
        app.buttons["Settings"].tap()
        app.buttons["How to Play"].tap()
        XCTAssertTrue(app.staticTexts["What is a Set?"].waitForExistence(timeout: 3))
        capture("major-rules")
    }

    // MARK: - Onboarding Slides

    @MainActor
    func testOnboardingWelcome() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        capture("major-onboarding-welcome")
    }

    @MainActor
    func testOnboardingRule() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["What Makes a Set"].waitForExistence(timeout: 3))
        capture("major-onboarding-rule")
    }

    @MainActor
    func testOnboardingValidSets() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        app.swipeLeft()
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["These ARE Sets"].waitForExistence(timeout: 3))
        capture("major-onboarding-valid-sets")
    }

    @MainActor
    func testOnboardingNonSets() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        app.swipeLeft()
        app.swipeLeft()
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Not Sets"].waitForExistence(timeout: 3))
        capture("major-onboarding-non-sets")
    }

    @MainActor
    func testOnboardingReady() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        app.swipeLeft()
        app.swipeLeft()
        app.swipeLeft()
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["You're Ready"].waitForExistence(timeout: 3))
        capture("major-onboarding-ready")
    }

    // MARK: - Game Modes

    @MainActor
    func testPracticeGame() throws {
        let app = launchPastOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        app.buttons["Practice"].tap()
        XCTAssertTrue(app.staticTexts["Score: 0"].waitForExistence(timeout: 3))
        waitForDealAnimation()
        capture("major-game-practice")
    }

    @MainActor
    func testNormalGame() throws {
        let app = launchPastOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        app.buttons["Normal"].tap()
        XCTAssertTrue(app.staticTexts["Score: 0"].waitForExistence(timeout: 3))
        waitForDealAnimation()
        capture("major-game-normal")
    }

    @MainActor
    func testTimeAttackGame() throws {
        let app = launchPastOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        app.buttons["Time Attack"].tap()
        XCTAssertTrue(app.staticTexts["Score: 0"].waitForExistence(timeout: 3))
        waitForDealAnimation()
        capture("major-game-time-attack")
    }

    @MainActor
    func testDailyGame() throws {
        let app = launchPastOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        app.buttons["Start Today"].tap()
        XCTAssertTrue(app.staticTexts["Score: 0"].waitForExistence(timeout: 3))
        waitForDealAnimation()
        capture("major-game-daily")
    }
}
