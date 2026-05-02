//
//  VersusStore.swift
//  Tertia
//
//  Persists completed versus matches and exposes the per-outcome counts
//  the Stats screen renders. Mirrors the four-column model from
//  VERSUS_PLAN.md: Wins / Losses / Forfeits / Draws.
//

import Foundation
import Observation

/// One completed versus match from the local player's perspective. The
/// `outcome` field already carries the "who won / who forfeited" semantics —
/// `outcome == .forfeit` means the local player forfeited; opponent forfeits
/// land as `.win` for the local side.
struct VersusMatchRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let opponentDisplayName: String?
    let yourScore: Int
    let opponentScore: Int
    let yourTrios: Int
    let opponentTrios: Int
    let outcome: VersusOutcome

    init(
        date: Date = .now,
        opponentDisplayName: String?,
        yourScore: Int,
        opponentScore: Int,
        yourTrios: Int,
        opponentTrios: Int,
        outcome: VersusOutcome,
        id: UUID = UUID()
    ) {
        self.id = id
        self.date = date
        self.opponentDisplayName = opponentDisplayName
        self.yourScore = yourScore
        self.opponentScore = opponentScore
        self.yourTrios = yourTrios
        self.opponentTrios = opponentTrios
        self.outcome = outcome
    }
}

@MainActor
@Observable
final class VersusStore {
    private let userDefaults: UserDefaults
    private let storageKey = "versus.v1"
    private let historyLimit = 200

    /// All recorded matches, oldest → newest.
    private(set) var matches: [VersusMatchRecord] = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func record(_ match: VersusMatchRecord) {
        matches.append(match)
        if matches.count > historyLimit {
            matches.removeFirst(matches.count - historyLimit)
        }
        save()
    }

    func clear() {
        matches = []
        userDefaults.removeObject(forKey: storageKey)
    }

    // MARK: - Counts

    var winCount: Int { matches.lazy.filter { $0.outcome == .win }.count }
    var lossCount: Int { matches.lazy.filter { $0.outcome == .loss }.count }
    var forfeitCount: Int { matches.lazy.filter { $0.outcome == .forfeit }.count }
    var drawCount: Int { matches.lazy.filter { $0.outcome == .draw }.count }

    /// Percentage of completed (non-draw, non-forfeit) games the local player
    /// won. Returns nil when no completed games exist — keeps the UI from
    /// showing a misleading "0%" before anyone has finished a match.
    var winRateAmongCompleted: Double? {
        let completed = winCount + lossCount
        guard completed > 0 else { return nil }
        return Double(winCount) / Double(completed)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([VersusMatchRecord].self, from: data) else {
            return
        }
        matches = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(matches) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
