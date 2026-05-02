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
//  Current iteration: Versus mode end-to-end (hero card on mode select,
//  versus stats section).
//

import XCTest

final class RecentChangesTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "1",
            "-screenshotMockData",
            "-colorSchemePreference", "light"
        ]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let notNow = springboard.buttons["Not Now"]
        if notNow.waitForExistence(timeout: 1) { notNow.tap() }
        return app
    }

    @MainActor
    func testCaptureModeSelectWithVersusHero() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        // VersusHeroCard renders the "Race a friend" headline.
        XCTAssertTrue(app.staticTexts["Race a friend"].waitForExistence(timeout: 3))
        capture("recent-mode-select-versus-hero")
    }

    @MainActor
    func testCaptureStatsVersusSection() throws {
        let app = launch()
        app.buttons["Stats"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Stats"].waitForExistence(timeout: 5))
        // Scroll down so the Versus section is fully on-screen — it lives
        // below Daily and Time Attack.
        app.swipeUp()
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.4)
        capture("recent-stats-versus")
    }

    @MainActor
    func testCaptureStatsTopWithVersus() throws {
        // Captures the Stats tab landing — daily streak, time attack, and
        // (depending on screen height) the top of the Versus section.
        let app = launch()
        app.buttons["Stats"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Stats"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
        capture("recent-stats-top")
    }
}
