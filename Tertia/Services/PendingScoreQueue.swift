//
//  PendingScoreQueue.swift
//  Tertia
//
//  In-memory retry queue for Game Center score submissions that couldn't be
//  delivered (offline, signed-out, transient network failure).
//
//  Design notes:
//  - Coalesces by leaderboard ID, keeping only the highest pending score.
//    Game Center's "Best Score" submission semantics discard anything below
//    the current high mark, so submitting older/lower pending scores would
//    just be wasted round-trips.
//  - In-memory only by design — a stale 4-trio score from yesterday's session
//    is not worth surviving an app restart. The user's local persisted bests
//    are still intact in HighScoreStore / DailyStore; only the leaderboard
//    update is dropped.
//

import Foundation

struct PendingScoreQueue: Equatable {
    /// Leaderboard ID → highest pending score for that leaderboard.
    private(set) var entries: [String: Int] = [:]

    var isEmpty: Bool { entries.isEmpty }

    /// Adds (or upgrades) a pending submission. Lower scores for the same
    /// leaderboard are dropped on the floor — Game Center wouldn't accept
    /// them anyway.
    mutating func enqueue(score: Int, for leaderboardID: String) {
        guard score > 0 else { return }
        let current = entries[leaderboardID, default: 0]
        if score > current {
            entries[leaderboardID] = score
        }
    }

    /// Atomically removes everything currently queued and returns it. Caller
    /// is expected to attempt submissions on the snapshot and re-enqueue any
    /// that fail.
    mutating func drain() -> [String: Int] {
        let snapshot = entries
        entries.removeAll()
        return snapshot
    }

    /// Re-adds previously-drained items that failed to submit. Goes through
    /// `enqueue` so the max-wins coalescing rule still applies if a newer
    /// higher score landed in the queue while submissions were in flight.
    mutating func reenqueue(_ failed: [String: Int]) {
        for (leaderboardID, score) in failed {
            enqueue(score: score, for: leaderboardID)
        }
    }
}
