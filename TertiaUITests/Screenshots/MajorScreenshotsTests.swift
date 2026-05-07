//
//  MajorScreenshotsTests.swift
//  TertiaUITests
//
//  Captures one screenshot per major screen with realistic mock data primed
//  via the `-screenshotMockData` launch argument. Output lands in
//  /tmp/tertia-screenshots/major-*.png.
//

import XCTest
import UIKit

final class MajorScreenshotsTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchPostOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "1",
            "-screenshotMockData",
            // Bypass the GameKit handshake so the Versus picker doesn't
            // get blocked by the sign-in prompt in the simulator.
            "-mockGameCenterAuth",
            "-colorSchemePreference", "light"
        ]
        app.launch()
        dismissAppleAccountAlert()
        return app
    }

    @MainActor
    private func launchAtOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "0",
            "-colorSchemePreference", "light"
        ]
        app.launch()
        dismissAppleAccountAlert()
        return app
    }

    /// Wait briefly for the deal animation to settle before capturing a game screen.
    private func waitForDealAnimation() {
        Thread.sleep(forTimeInterval: 1.0)
    }

    @MainActor
    private func deviceSuffix() -> String {
        UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
    }

    @MainActor
    private func captureForDevice(_ name: String) {
        capture("\(name)-\(deviceSuffix())")
    }

    /// Dismisses the springboard "Apple Account Verification" system alert
    /// that occasionally appears on fresh simulator boots and would otherwise
    /// occlude every screenshot. No-op if the alert isn't present.
    @MainActor
    private func dismissAppleAccountAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let notNow = springboard.buttons["Not Now"]
        if notNow.waitForExistence(timeout: 1) {
            notNow.tap()
        }
    }

    // MARK: - Mode Select & Tabs

    @MainActor
    func testModeSelect() throws {
        let app = launchPostOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        captureForDevice("major-mode-select")
    }

    @MainActor
    func testStatsTab() throws {
        let app = launchPostOnboarding()
        tapTab("Stats", in: app)
        // Mock data populates Daily Puzzle section with a streak
        XCTAssertTrue(app.staticTexts["Daily Puzzle"].waitForExistence(timeout: 3))
        // Give charts a beat to render
        Thread.sleep(forTimeInterval: 0.5)
        captureForDevice("major-stats")
    }

    @MainActor
    func testSettingsTab() throws {
        let app = launchPostOnboarding()
        tapTab("Settings", in: app)
        XCTAssertTrue(app.staticTexts["Theme"].waitForExistence(timeout: 3))
        captureForDevice("major-settings")
    }

    @MainActor
    func testRulesView() throws {
        let app = launchPostOnboarding()
        tapTab("Settings", in: app)
        app.buttons["How to Play"].tap()
        XCTAssertTrue(app.staticTexts["What is a Trio?"].waitForExistence(timeout: 3))
        captureForDevice("major-rules")
    }

    // MARK: - Onboarding Slides

    @MainActor
    func testOnboardingWelcome() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        captureForDevice("major-onboarding-welcome")
    }

    @MainActor
    func testOnboardingRule() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["What Makes a Trio"].waitForExistence(timeout: 3))
        captureForDevice("major-onboarding-rule")
    }

    @MainActor
    func testOnboardingValidSets() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        app.swipeLeft()
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["These ARE Trios"].waitForExistence(timeout: 3))
        captureForDevice("major-onboarding-valid-sets")
    }

    @MainActor
    func testOnboardingNonSets() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        app.swipeLeft()
        app.swipeLeft()
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Not Trios"].waitForExistence(timeout: 3))
        captureForDevice("major-onboarding-non-sets")
    }

    @MainActor
    func testOnboardingScoring() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        for _ in 0..<4 { app.swipeLeft() }
        XCTAssertTrue(app.staticTexts["Harder Trios = More Points"].waitForExistence(timeout: 3))
        captureForDevice("major-onboarding-scoring")
    }

    @MainActor
    func testOnboardingReady() throws {
        let app = launchAtOnboarding()
        XCTAssertTrue(app.staticTexts["Welcome to Tertia"].waitForExistence(timeout: 3))
        for _ in 0..<5 { app.swipeLeft() }
        XCTAssertTrue(app.staticTexts["You're Ready"].waitForExistence(timeout: 3))
        captureForDevice("major-onboarding-ready")
    }

    // MARK: - Game Modes

    /// iPad's floating tab bar exposes the same Button twice (cell + view), so
    /// `app.buttons["Stats"]` is ambiguous there. `firstMatch` picks one.
    @MainActor
    private func tapTab(_ name: String, in app: XCUIApplication) {
        app.buttons[name].firstMatch.tap()
    }

    @MainActor
    private func tapMode(_ name: String, in app: XCUIApplication) {
        let button = app.buttons[name]
        if !button.isHittable {
            // Mode list is below the daily hero card; scroll to bring it on-screen.
            app.swipeUp()
        }
        button.tap()
    }

    @MainActor
    func testPracticeGame() throws {
        let app = launchPostOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        tapMode("Practice", in: app)
        XCTAssertTrue(app.staticTexts["Score 0"].waitForExistence(timeout: 3))
        waitForDealAnimation()
        captureForDevice("major-game-practice")
    }

    @MainActor
    func testNormalGame() throws {
        let app = launchPostOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        tapMode("Normal", in: app)
        XCTAssertTrue(app.staticTexts["Score 0"].waitForExistence(timeout: 3))
        waitForDealAnimation()
        captureForDevice("major-game-normal")
    }

    @MainActor
    func testTimeAttackGame() throws {
        let app = launchPostOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        tapMode("Time Attack", in: app)
        XCTAssertTrue(app.staticTexts["Score 0"].waitForExistence(timeout: 3))
        waitForDealAnimation()
        captureForDevice("major-game-time-attack")
    }

    @MainActor
    func testDailyHeroDoneState() throws {
        // Mock data marks today's daily as completed → DailyHeroCard renders
        // its "DONE" + streak state with the share button. Captures the
        // Mode Select screen showcasing daily engagement.
        let app = launchPostOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["DONE"].waitForExistence(timeout: 3))
        captureForDevice("major-daily-done")
    }

    @MainActor
    func testVersusModePicker() throws {
        // Versus hero card → "Choose a Mode" sheet pushes up. Captures the
        // three-variant picker with stat blurbs populated from the mock
        // data (which now includes mixed .normal / .firstTo10 / .coop
        // matches).
        let app = launchPostOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        app.buttons["versusChooseModeButton"].tap()
        // Variant cards combine their text into a single accessibility
        // label, so the title texts ("NORMAL" etc.) aren't reachable as
        // separate elements. Wait on the picker's primary CTA instead.
        XCTAssertTrue(app.buttons["Invite a Friend"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.4)
        captureForDevice("major-versus-picker")
    }

    @MainActor
    func testVersusModePickerFirstTo10Selected() throws {
        // Same picker, with First to 10 highlighted — shows the
        // description panel expanded and the accent-tinted action bar.
        let app = launchPostOnboarding()
        XCTAssertTrue(app.staticTexts["Choose Mode"].waitForExistence(timeout: 3))
        app.buttons["versusChooseModeButton"].tap()
        XCTAssertTrue(app.buttons["Invite a Friend"].waitForExistence(timeout: 3))
        // Each variant card is one button. Find the First-to-10 row by
        // its accessibility label prefix and tap it.
        let firstTo10 = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "FIRST TO 10")
        ).firstMatch
        XCTAssertTrue(firstTo10.waitForExistence(timeout: 3))
        firstTo10.tap()
        Thread.sleep(forTimeInterval: 0.5)
        captureForDevice("major-versus-picker-firstto10")
    }
}
