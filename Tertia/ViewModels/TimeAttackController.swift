//
//  TimeAttackController.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation
import Observation

/// Wall-clock timer for Time Attack mode. Composes with `SetGame`; the view
/// owns both. Pauses on app backgrounding, resumes on foreground.
@Observable
final class TimeAttackController {
    let totalDuration: TimeInterval

    /// Per-set time bonus awarded when a valid trio is found in a timed mode.
    let perSetBonus: TimeInterval = 3

    /// Hard ceiling on total bonus seconds awarded across one round.
    let maxBonus: TimeInterval = 30

    /// Running total of bonus seconds granted this round.
    private(set) var bonusGranted: TimeInterval = 0

    /// Wall-clock end of the round. Nil while paused (use `pausedRemaining`).
    private(set) var endDate: Date?
    private var pausedRemaining: TimeInterval?

    var remaining: TimeInterval {
        if let endDate {
            return max(0, endDate.timeIntervalSinceNow)
        }
        return pausedRemaining ?? totalDuration
    }

    var isFinished: Bool {
        remaining <= 0
    }

    var isPaused: Bool {
        endDate == nil
    }

    /// True once `start()` has been called. Stays true through pause/resume
    /// and after expiry. Used by the view to avoid restarting the round when
    /// `.task` re-fires (e.g., on tab switch).
    var hasStarted: Bool {
        endDate != nil || pausedRemaining != nil
    }

    init(totalDuration: TimeInterval = 300) {
        self.totalDuration = totalDuration
        // endDate stays nil — call start() to begin the round. Until then,
        // `remaining` reports the full duration and `isPaused` is true.
    }

    func pause() {
        guard let endDate else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        self.endDate = nil
    }

    func resume() {
        guard let paused = pausedRemaining, paused > 0 else { return }
        endDate = Date().addingTimeInterval(paused)
        pausedRemaining = nil
    }

    /// Begins (or restarts) the round with a fresh full duration.
    func start() {
        pausedRemaining = nil
        bonusGranted = 0
        endDate = Date().addingTimeInterval(totalDuration)
    }

    /// Adds time to the round, capped at `maxBonus` total per round. Returns
    /// the amount actually added (0 if the cap is hit, so callers can suppress
    /// the "+3s" toast). Safe to call while running or paused.
    @discardableResult
    func addTime(_ seconds: TimeInterval) -> TimeInterval {
        let allowed = min(seconds, maxBonus - bonusGranted)
        guard allowed > 0 else { return 0 }

        if let endDate {
            self.endDate = endDate.addingTimeInterval(allowed)
        } else if let paused = pausedRemaining {
            pausedRemaining = paused + allowed
        } else {
            // Round hasn't started yet — record the bonus so it applies on start.
            // Equivalent to extending the initial duration.
            pausedRemaining = (pausedRemaining ?? totalDuration) + allowed
        }

        bonusGranted += allowed
        return allowed
    }
}
