//
//  TriplixUITests.swift
//  TriplixUITests
//
//  Created by Mark Martin on 4/28/26.
//

import XCTest

final class TriplixUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesWithStartingScore() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Score: 0"].waitForExistence(timeout: 2),
            "Expected initial nav title 'Score: 0'"
        )
    }

    func testToolbarButtonsArePresent() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Hint"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["New Game"].exists)
    }

    func testHintButtonTapDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launch()
        let hint = app.buttons["Hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 2))
        hint.tap()
        XCTAssertTrue(app.staticTexts["Score: 0"].exists)
    }

    func testNewGameAtZeroScoreSkipsConfirmation() throws {
        let app = XCUIApplication()
        app.launch()
        let newGame = app.buttons["New Game"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 2))
        newGame.tap()
        // No confirmation dialog should appear at score 0
        XCTAssertFalse(app.buttons["Cancel"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Score: 0"].exists)
    }

    func testDeckCounterIsVisible() throws {
        let app = XCUIApplication()
        app.launch()
        // 81 cards total, 18 dealt → 63 left after launch
        XCTAssertTrue(
            app.staticTexts["63"].waitForExistence(timeout: 2),
            "Expected deck counter to read 63 after initial deal"
        )
    }
}
