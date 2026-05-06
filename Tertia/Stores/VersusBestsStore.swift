//
//  VersusBestsStore.swift
//  Tertia
//
//  Persistent all-time bests across every Versus match the local player has
//  finished. Per-match stats (`localFastestSetSeconds`, `localLongestStreak`)
//  are computed inside `VersusGame` and currently die when the game-over
//  sheet dismisses; this store keeps them around so the Stats screen can
//  surface "Fastest set ever: 1.4s" — the kind of personal-best line that
//  actually motivates a return visit.
//

import Foundation
import Observation

/// Snapshot of the player's all-time Versus highs. Encoded as a single
/// blob in UserDefaults so adding a new "best" later is a one-property
/// migration rather than a multi-key dance.
struct VersusBests: Codable, Equatable {
    /// Lowest single-trio claim time the player has ever recorded across
    /// Versus matches. `nil` until the player has finished one match where
    /// they actually scored.
    var fastestSetSeconds: Double?

    /// Longest in-match scoring streak the player has ever hit.
    var longestCombo: Int

    /// Longest consecutive run of `.win` outcomes (without a `.loss` /
    /// `.forfeit` between them). Draws don't reset the streak.
    var longestWinStreak: Int

    /// Current consecutive-wins streak. Resets on loss/forfeit. Persisted
    /// here rather than recomputed off `VersusStore` so we don't have to
    /// keep both stores in lockstep.
    var currentWinStreak: Int

    static let empty = VersusBests(
        fastestSetSeconds: nil,
        longestCombo: 0,
        longestWinStreak: 0,
        currentWinStreak: 0
    )
}

@MainActor
@Observable
final class VersusBestsStore {
    private let userDefaults: UserDefaults
    private let storageKey = "versusBests.v1"

    private(set) var bests: VersusBests = .empty

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    /// Folds a single completed Versus match into the all-time bests.
    /// Returns `true` if any field actually improved (caller can hook this
    /// to a "personal best!" celebration). The streak fields update
    /// regardless of whether they're an improvement.
    @discardableResult
    func record(
        outcome: VersusOutcome,
        localFastestSetSeconds: Double?,
        localLongestStreak: Int
    ) -> Bool {
        var improved = false
        var updated = bests

        if let fastest = localFastestSetSeconds, fastest > 0 {
            if updated.fastestSetSeconds == nil || fastest < (updated.fastestSetSeconds ?? .infinity) {
                updated.fastestSetSeconds = fastest
                improved = true
            }
        }

        if localLongestStreak > updated.longestCombo {
            updated.longestCombo = localLongestStreak
            improved = true
        }

        switch outcome {
        case .win:
            updated.currentWinStreak += 1
            if updated.currentWinStreak > updated.longestWinStreak {
                updated.longestWinStreak = updated.currentWinStreak
                improved = true
            }
        case .loss, .forfeit:
            updated.currentWinStreak = 0
        case .draw:
            // Draws preserve the streak (you didn't lose) but don't extend it.
            break
        case .coopCompleted, .coopAbandoned:
            // Coop runs sit outside the competitive win-streak ledger.
            break
        }

        bests = updated
        save()
        return improved
    }

    func clear() {
        bests = .empty
        userDefaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(VersusBests.self, from: data) else {
            return
        }
        bests = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bests) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
