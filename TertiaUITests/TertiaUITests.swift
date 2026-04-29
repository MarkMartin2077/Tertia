//
//  TertiaUITests.swift
//  TertiaUITests
//
//  Created by Mark Martin on 4/28/26.
//

import XCTest

final class TertiaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Boots the app with onboarding pre-completed. Use for tests that target post-onboarding UI.
    @MainActor
    private func launchPastOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "1"]
        app.launch()
        return app
    }

    /// Boots the app with onboarding reset, so the cover is visible.
    @MainActor
    private func launchAtOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "0"]
        app.launch()
        return app
    }

    // MARK: - Play tab

    @MainActor
    func testAppLaunchesWithStartingScore() throws {
        let app = launchPastOnboarding()
        XCTAssertTrue(
            app.staticTexts["Score: 0"].waitForExistence(timeout: 2),
            "Expected 'Score: 0' header on launch"
        )
    }

    @MainActor
    func testToolbarButtonsArePresent() throws {
        let app = launchPastOnboarding()
        XCTAssertTrue(app.buttons["Hint"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["New Game"].exists)
        XCTAssertTrue(app.buttons["Deal 3"].exists)
    }

    @MainActor
    func testHintButtonTapDoesNotCrash() throws {
        let app = launchPastOnboarding()
        let hint = app.buttons["Hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 2))
        hint.tap()
        XCTAssertTrue(app.staticTexts["Score: 0"].exists)
    }

    @MainActor
    func testNewGameAtZeroScoreSkipsConfirmation() throws {
        let app = launchPastOnboarding()
        let newGame = app.buttons["New Game"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 2))
        newGame.tap()
        XCTAssertFalse(app.buttons["Cancel"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Score: 0"].exists)
    }

    @MainActor
    func testDeckCounterIsVisible() throws {
        let app = launchPastOnboarding()
        let deck = app.staticTexts["Deck"]
        XCTAssertTrue(
            deck.waitForExistence(timeout: 2),
            "Expected deck counter accessibility element"
        )
        XCTAssertEqual(deck.value as? String, "69 cards remaining")
    }

    // MARK: - Tab switching

    @MainActor
    func testSettingsTabIsAccessible() throws {
        let app = launchPastOnboarding()
        let settingsTab = app.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 2))
        settingsTab.tap()
        XCTAssertTrue(
            app.staticTexts["Theme"].waitForExistence(timeout: 2),
            "Expected Theme picker on Settings tab"
        )
    }

    @MainActor
    func testCanReturnToPlayTab() throws {
        let app = launchPastOnboarding()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Theme"].waitForExistence(timeout: 2))
        app.buttons["Play"].tap()
        XCTAssertTrue(
            app.staticTexts["Score: 0"].waitForExistence(timeout: 2),
            "Expected game state to be visible after switching back to Play"
        )
    }

    // MARK: - Settings tab content

    @MainActor
    func testThemePickerHasSystemDefault() throws {
        let app = launchPastOnboarding()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Theme"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts["System"].exists,
            "Expected default theme to be 'System'"
        )
    }

    @MainActor
    func testRulesScreenAccessibleFromSettings() throws {
        let app = launchPastOnboarding()
        app.buttons["Settings"].tap()
        let howToPlay = app.buttons["How to Play"]
        XCTAssertTrue(howToPlay.waitForExistence(timeout: 2))
        howToPlay.tap()
        XCTAssertTrue(
            app.staticTexts["What is a Set?"].waitForExistence(timeout: 2),
            "Expected 'What is a Set?' heading on rules screen"
        )
    }

    // MARK: - Onboarding

    @MainActor
    func testOnboardingShownOnFirstLaunch() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(
            app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 2),
            "Expected welcome slide on first launch"
        )
    }

    @MainActor
    func testOnboardingSkipDismissesToGame() throws {
        let app = launchAtOnboarding()
        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 2))
        skip.tap()
        XCTAssertTrue(
            app.staticTexts["Score: 0"].waitForExistence(timeout: 3),
            "Expected to land on Play tab after skipping onboarding"
        )
    }
}
