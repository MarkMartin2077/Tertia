//
//  RecentChangesTests.swift
//  TertiaUITests
//
//  Targeted screenshots for the screens currently being modified.
//  Output: /tmp/tertia-screenshots/recent-*.png
//
//  ▸ EDIT THIS FILE each iteration. Add/remove test methods to capture only the
//    screens you've just changed. Re-running overwrites the same filenames.
//
//  Current iteration: rules clarity + practice verdict + DEAL 3 overlay.
//
//  Note: PracticeVerdictBar and the DEAL 3 overlay need deterministic game
//  state (a known-set or no-set initial board) to capture reliably. That seam
//  is deferred — when needed, add a `--ui-test-deck=<token>` launch arg in
//  SetGame and wire fixed decks here.
//

import XCTest

final class RecentChangesTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureRuleSlide() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "0"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["What Makes a Set"].waitForExistence(timeout: 3))
        capture("recent-onboarding-rule")
    }

    @MainActor
    func testCaptureNonSetsSlide() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "0"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        app.swipeLeft()
        app.swipeLeft()
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Not Sets"].waitForExistence(timeout: 3))
        capture("recent-onboarding-non-sets")
    }

    @MainActor
    func testCaptureRulesViewTop() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
        app.buttons["Settings"].tap()
        app.buttons["How to Play"].tap()
        XCTAssertTrue(app.staticTexts["What is a Set?"].waitForExistence(timeout: 3))
        capture("recent-rules-top")
    }

    @MainActor
    func testCaptureRulesViewCommonMistake() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
        app.buttons["Settings"].tap()
        app.buttons["How to Play"].tap()
        XCTAssertTrue(app.staticTexts["What is a Set?"].waitForExistence(timeout: 3))
        // Scroll to surface the new "Common Mistake" section
        app.swipeUp()
        app.swipeUp()
        capture("recent-rules-common-mistake")
    }
}
