//
//  TimeAttackController.swift
//  Triplix
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

    init(totalDuration: TimeInterval = 90) {
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
        endDate = Date().addingTimeInterval(totalDuration)
    }
}
