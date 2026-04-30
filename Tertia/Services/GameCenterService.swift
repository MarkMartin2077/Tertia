//
//  GameCenterService.swift
//  Tertia
//
//  Wraps GameKit authentication and leaderboard submission. The service is
//  created once at app launch, stored in the SwiftUI environment, and queried
//  by GameView (to submit) and StatsView (to gate the leaderboard sheet).
//
//  Tertia treats Game Center as fully optional. If the player declines the
//  prompt, never authenticates, or has Game Center disabled in iOS Settings,
//  every method on this service is a no-op and the app continues to work.
//

import Foundation
import GameKit
import OSLog
import UIKit

private let logger = Logger(subsystem: "Mark.Tertia", category: "GameCenter")

enum LeaderboardID {
    static let timeAttackBest = "tertia.time_attack_best"

    /// Best-ever daily streak. Monotonically increasing per player; the
    /// "Best Score" submission type means lower scores never overwrite.
    static let dailyStreakBest = "tertia.daily_streak_best"

    /// Today's daily puzzle score. Configured in App Store Connect as a
    /// recurring (daily) leaderboard so it resets every midnight.
    static let dailyScoreToday = "tertia.daily_score_today"
}

/// Captures a Game Center activity launch request. Consumed by `ContentView`
/// to switch to the Play tab and start the matching mode.
struct GameActivityRequest: Equatable {
    let activityID: String

    /// Maps the activity context to a GameMode. Today every activity routes
    /// to Time Attack since that's the only leaderboard with `Play` exposed
    /// in Game Center; future activities can expand this switch.
    var suggestedMode: GameMode {
        switch activityID {
        case "tertia.activity.play": return .timeAttack
        default: return .timeAttack
        }
    }
}

@MainActor
@Observable
final class GameCenterService {
    /// iOS 26 Game Activities listener. Apple expects apps that ship
    /// activities (and we have one configured for the Time Attack
    /// leaderboard's "Play" button) to register a `GKGameActivityListener`
    /// so the system has somewhere to deliver "user wants to play" callbacks.
    /// Without this, GameKit logs `Code=17 / Invalid game activity definition`
    /// every time the player opens or returns from the leaderboard view.
    private let activityListener = ActivityListener()

    /// Pending activity launch request from Game Center. Set when the player
    /// taps "Play" inside the Game Center leaderboard view; ContentView
    /// observes this to switch tabs and start the appropriate mode, then
    /// calls `clearPendingActivityRequest` to consume it.
    private(set) var pendingActivityRequest: GameActivityRequest?

    init() {
        activityListener.onActivityRequest = { [weak self] activityID in
            Task { @MainActor [weak self] in
                self?.pendingActivityRequest = GameActivityRequest(activityID: activityID)
            }
        }
    }

    func clearPendingActivityRequest() {
        pendingActivityRequest = nil
    }
    /// Whether the local player has authenticated with Game Center this
    /// session. Drives whether we attempt submissions and whether the
    /// leaderboard button in Stats is enabled.
    private(set) var isAuthenticated = false

    /// Game Center display name of the local player when authenticated,
    /// surfaced in Settings so the player can verify which account is
    /// signed in (especially useful when juggling sandbox vs production).
    private(set) var localPlayerDisplayName: String?

    /// Most recent error from the auth handler. Surfaced in Settings so the
    /// player can see why Game Center didn't sign in (most often: sandbox
    /// credentials confused, app not yet associated, or Game Center disabled
    /// at the OS level).
    private(set) var lastErrorMessage: String?

    /// True once the auth handler has fired at least once, regardless of
    /// outcome. Lets the UI distinguish "auth hasn't started yet" from "auth
    /// finished with no success."
    private(set) var hasCompletedFirstAttempt = false

    /// Sign-in UIViewController iOS hands us when authentication needs to
    /// present a prompt (typically only on first auth). The app root binds
    /// this to a fullScreenCover; setting it back to nil dismisses.
    var pendingAuthenticationViewController: UIViewController?

    /// Begins authentication. Apple's API takes a closure that fires multiple
    /// times across the app's lifetime — every state transition (logged in,
    /// logged out, prompt shown). Safe to call once at app launch.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            self.hasCompletedFirstAttempt = true
            self.pendingAuthenticationViewController = viewController
            self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            self.localPlayerDisplayName = GKLocalPlayer.local.isAuthenticated
                ? GKLocalPlayer.local.displayName
                : nil
            self.lastErrorMessage = error?.localizedDescription

            // Register activity listener once authenticated so iOS knows where
            // to deliver "user tapped Play in Game Center" callbacks.
            if GKLocalPlayer.local.isAuthenticated {
                GKLocalPlayer.local.register(self.activityListener)
                logger.info("Registered GKGameActivityListener for local player")
            }
        }
    }

    /// Opens the Game Center dashboard. Use from a "Game Center" Settings row
    /// so players can manage / verify their account from inside the app.
    func openDashboard() {
        GKAccessPoint.shared.trigger(state: .dashboard) { }
    }

    /// Submits a Time Attack score to Game Center. Silent on failure — the
    /// leaderboard is non-critical and we should never disrupt the player's
    /// game-over flow if Apple's servers are unreachable.
    ///
    /// Note: Tertia's scoring is purely local, so a determined player could
    /// forge any score before submission. Game Center has light anti-cheat
    /// filtering but no real protection against this. Acceptable for a
    /// pattern-matching game; would not be acceptable for prize stakes.
    func submitTimeAttackScore(_ score: Int) async {
        await submit(score: score, to: LeaderboardID.timeAttackBest)
    }

    /// Submits the player's best-ever daily streak. Safe to call after every
    /// daily completion — Apple's "Best Score" submission discards anything
    /// below the player's existing high mark.
    func submitBestStreak(_ streak: Int) async {
        await submit(score: streak, to: LeaderboardID.dailyStreakBest)
    }

    /// Submits today's daily puzzle score. The leaderboard is configured as
    /// recurring/daily in App Store Connect, so Apple resets it at midnight UTC.
    func submitDailyScore(_ score: Int) async {
        await submit(score: score, to: LeaderboardID.dailyScoreToday)
    }

    private func submit(score: Int, to leaderboardID: String) async {
        guard isAuthenticated, score > 0 else {
            logger.info("Skipping submit \(score) to \(leaderboardID): not authenticated or score is zero")
            return
        }
        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID]
            )
            logger.info("Submitted \(score) to \(leaderboardID)")
        } catch {
            logger.error("Submit \(score) to \(leaderboardID) failed: \(error.localizedDescription)")
        }
    }
}

/// Bridges Apple's `GKGameActivityListener` callbacks. NSObject conformance is
/// required by GameKit; kept as a small private class so the @Observable
/// service doesn't have to inherit from NSObject.
///
/// Tertia doesn't deep-link to specific modes from activities yet — the
/// completion handler is called immediately to acknowledge the request,
/// which lets the system continue its launch flow without errors. If we
/// later want "Play" from Game Center to drop the user straight into Time
/// Attack, this is where that routing would live.
private final class ActivityListener: NSObject, GKLocalPlayerListener, GKGameActivityListener {
    /// Set by `GameCenterService` to receive the activity ID when iOS asks
    /// the listener to launch an activity. The closure is `@Sendable` so it
    /// can hop to the main actor safely.
    var onActivityRequest: (@Sendable (String) -> Void)?

    func player(
        _ player: GKPlayer,
        wantsToPlay activity: GKGameActivity,
        completionHandler: @escaping (Bool) -> Void
    ) {
        onActivityRequest?(activity.identifier)
        completionHandler(true)
    }
}
