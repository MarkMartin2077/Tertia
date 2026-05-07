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

    // MARK: - Versus
    //
    // App Store Connect must declare each of these before submissions
    // succeed. All three use "Best Score" submission type so a lower
    // attempt never overwrites a player's high mark.
    //
    // - `versusWins`: cumulative wins. Submitted as a running total each
    //   time the player wins; GameKit dedupes via best-score semantics so
    //   resubmitting the same total is a no-op.
    // - `versusFastestSet`: per-match fastest trio claim, in *milliseconds*
    //   (lower is better → this leaderboard must be configured as
    //   "Low to High" in App Store Connect).
    // - `versusLongestCombo`: longest scoring streak in a single match.
    static let versusWins = "tertia.versus_wins"
    static let versusFastestSet = "tertia.versus_fastest_set_ms"
    static let versusLongestCombo = "tertia.versus_longest_combo"
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

/// A GameKit invite that the local player has accepted (typically by
/// tapping the invite in Messages). Wraps `GKInvite` with a stable UUID so
/// SwiftUI's `Identifiable` / `.onChange(of:)` plumbing can detect it as a
/// new event even if the same `GKInvite` reference re-arrives.
struct PendingMatchInvite: Identifiable, Equatable {
    let id = UUID()
    let invite: GKInvite

    static func == (lhs: PendingMatchInvite, rhs: PendingMatchInvite) -> Bool {
        lhs.id == rhs.id
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

    /// Pending GameKit match invite the local player accepted (typically from
    /// Messages). ContentView observes this to switch to the Play tab and
    /// hand the invite to the matchmaker, then calls
    /// `clearPendingMatchInvite` to consume it. Without this listener the
    /// app launches into the default tab and the accepted invite goes
    /// nowhere — the friend lands on Play instead of the match.
    private(set) var pendingMatchInvite: PendingMatchInvite?

    /// Guard against double-registering the activity listener. GameKit's auth
    /// handler can fire repeatedly across a session (account switches, scene
    /// transitions); register once and stay registered.
    private var hasRegisteredActivityListener = false

    /// In-memory retry queue for score submissions that couldn't be delivered
    /// (offline, signed-out, transient failure). Drained when authentication
    /// succeeds and on every subsequent submit attempt.
    ///
    /// Exposed for testability: production callers shouldn't need to inspect
    /// this directly, but unit tests verify enqueue behavior here.
    private(set) var pendingScores = PendingScoreQueue()

    init() {
        activityListener.onActivityRequest = { [weak self] activityID in
            Task { @MainActor [weak self] in
                self?.pendingActivityRequest = GameActivityRequest(activityID: activityID)
            }
        }
        activityListener.onInviteAccepted = { [weak self] invite in
            Task { @MainActor [weak self] in
                self?.pendingMatchInvite = PendingMatchInvite(invite: invite)
                logger.info("Surfaced accepted GameKit invite to UI")
            }
        }
    }

    func clearPendingActivityRequest() {
        pendingActivityRequest = nil
    }

    func clearPendingMatchInvite() {
        pendingMatchInvite = nil
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
        // Screenshot mode: skip the live GameKit handshake and pretend
        // we're authenticated so flows that gate on Game Center (e.g.,
        // the Versus mode picker) can be screenshotted without a real
        // sandbox account.
        if CommandLine.arguments.contains("-mockGameCenterAuth") {
            self.isAuthenticated = true
            self.hasCompletedFirstAttempt = true
            self.localPlayerDisplayName = "Demo Player"
            return
        }
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            // GameKit calls this on the main thread today, but Apple doesn't
            // commit to that in the Swift concurrency contract. Hop to
            // @MainActor explicitly so all @Observable mutations are on a
            // documented isolation boundary.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.hasCompletedFirstAttempt = true
                self.pendingAuthenticationViewController = viewController
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.localPlayerDisplayName = GKLocalPlayer.local.isAuthenticated
                    ? GKLocalPlayer.local.displayName
                    : nil
                self.lastErrorMessage = error?.localizedDescription

                // Register activity listener once per session.
                if GKLocalPlayer.local.isAuthenticated, !self.hasRegisteredActivityListener {
                    GKLocalPlayer.local.register(self.activityListener)
                    self.hasRegisteredActivityListener = true
                    logger.info("Registered GKGameActivityListener for local player")
                }

                // Auth just succeeded (or re-fired while authenticated) — flush
                // anything queued while the player was offline / signed out.
                if self.isAuthenticated, !self.pendingScores.isEmpty {
                    Task { @MainActor [weak self] in
                        await self?.drainPendingScoreSubmissions()
                    }
                }
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

    /// Submits the player's running total of Versus wins. Best-score
    /// semantics on the leaderboard make resubmitting an unchanged total
    /// a no-op, so callers can fire-and-forget after every win.
    func submitVersusWins(_ totalWins: Int) async {
        await submit(score: totalWins, to: LeaderboardID.versusWins)
    }

    /// Submits the player's fastest trio claim from a single match, in
    /// milliseconds. The Versus fastest-set leaderboard must be configured
    /// "Low to High" in App Store Connect — submitting in milliseconds keeps
    /// the integer score precise to ~1ms.
    func submitVersusFastestSet(seconds: Double) async {
        guard seconds > 0 else { return }
        let ms = Int((seconds * 1000).rounded())
        await submit(score: ms, to: LeaderboardID.versusFastestSet)
    }

    /// Submits the longest scoring streak from a single Versus match.
    func submitVersusLongestCombo(_ streak: Int) async {
        await submit(score: streak, to: LeaderboardID.versusLongestCombo)
    }

    private func submit(score: Int, to leaderboardID: String) async {
        guard score > 0 else { return }

        // Always queue. drainPendingScoreSubmissions will deliver immediately
        // if we're authenticated, or hold until the next auth callback / retry
        // otherwise. Treating "fresh score" and "previously failed score" the
        // same way keeps the retry logic in one place.
        pendingScores.enqueue(score: score, for: leaderboardID)
        await drainPendingScoreSubmissions()
    }

    /// Attempts to flush every queued score submission. Failures are
    /// re-enqueued and retried on the next auth callback or submit attempt.
    /// No-op when not authenticated — the auth handler will trigger a drain
    /// once the player signs in.
    func drainPendingScoreSubmissions() async {
        guard isAuthenticated else { return }
        guard !pendingScores.isEmpty else { return }

        let snapshot = pendingScores.drain()
        var failed: [String: Int] = [:]
        for (leaderboardID, score) in snapshot {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboardID]
                )
                logger.info("Submitted \(score) to \(leaderboardID)")
            } catch {
                failed[leaderboardID] = score
                logger.error("Submit \(score) to \(leaderboardID) failed: \(error.localizedDescription)")
            }
        }
        if !failed.isEmpty {
            pendingScores.reenqueue(failed)
        }
    }
}

/// Bridges Apple's `GKGameActivityListener` and `GKInviteEventListener`
/// callbacks. NSObject conformance is required by GameKit; kept as a small
/// private class so the @Observable service doesn't have to inherit from
/// NSObject.
///
/// Tertia doesn't deep-link to specific modes from activities yet — the
/// activity completion handler is called immediately to acknowledge the
/// request. The invite callback (`player(_:didAccept:)`) fires when the
/// local player accepts a GameKit invite from Messages or notifications;
/// without this conformance the invite has nowhere to land and the app
/// just opens to the default tab.
private final class ActivityListener: NSObject, GKLocalPlayerListener, GKGameActivityListener, GKInviteEventListener {
    /// Set by `GameCenterService` to receive the activity ID when iOS asks
    /// the listener to launch an activity. The closure is `@Sendable` so it
    /// can hop to the main actor safely.
    var onActivityRequest: (@Sendable (String) -> Void)?

    /// Set by `GameCenterService` to receive an accepted invite. `GKInvite`
    /// isn't formally Sendable; we ferry it across the actor boundary via
    /// `SendableInviteBox` and consume on @MainActor only.
    var onInviteAccepted: (@Sendable (GKInvite) -> Void)?

    func player(
        _ player: GKPlayer,
        wantsToPlay activity: GKGameActivity,
        completionHandler: @escaping (Bool) -> Void
    ) {
        onActivityRequest?(activity.identifier)
        completionHandler(true)
    }

    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        // GameKit calls invite listeners on the main thread today; we still
        // route through the box-and-Sendable-closure pattern so concurrency
        // checking stays clean if Apple ever changes that contract.
        let box = SendableInviteBox(invite)
        onInviteAccepted?(box.value)
    }
}

/// Lets us pass a `GKInvite` reference through a `@Sendable` closure
/// boundary. `GKInvite` (an NSObject subclass) is not formally Sendable,
/// but we only ever read its properties on @MainActor inside the matchmaker
/// flow, so the unchecked conformance is sound for this single use site.
private struct SendableInviteBox: @unchecked Sendable {
    let value: GKInvite
    init(_ value: GKInvite) { self.value = value }
}
