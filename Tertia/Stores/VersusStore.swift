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
    /// Which versus variant this match used. Pre-Phase 4 records (saved
    /// before this field existed) decode as `.normal` — see init(from:).
    let variant: VersusVariant

    init(
        date: Date = .now,
        opponentDisplayName: String?,
        yourScore: Int,
        opponentScore: Int,
        yourTrios: Int,
        opponentTrios: Int,
        outcome: VersusOutcome,
        variant: VersusVariant = .normal,
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
        self.variant = variant
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, opponentDisplayName, yourScore, opponentScore
        case yourTrios, opponentTrios, outcome, variant
    }

    /// Custom decode so persisted records from before Phase 4 (no
    /// `variant` field) load as `.normal` rather than failing the entire
    /// `[VersusMatchRecord]` decode and wiping history.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.opponentDisplayName = try container.decodeIfPresent(String.self, forKey: .opponentDisplayName)
        self.yourScore = try container.decode(Int.self, forKey: .yourScore)
        self.opponentScore = try container.decode(Int.self, forKey: .opponentScore)
        self.yourTrios = try container.decode(Int.self, forKey: .yourTrios)
        self.opponentTrios = try container.decode(Int.self, forKey: .opponentTrios)
        self.outcome = try container.decode(VersusOutcome.self, forKey: .outcome)
        self.variant = try container.decodeIfPresent(VersusVariant.self, forKey: .variant) ?? .normal
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

    // MARK: - Per-variant counts

    /// Records filtered by variant — caller can then slice further.
    /// Pre-Phase 4 records (no variant field) decode as `.normal`, so
    /// historic Versus matches surface in the Normal bucket as expected.
    func matches(in variant: VersusVariant) -> [VersusMatchRecord] {
        matches.filter { $0.variant == variant }
    }

    func winCount(in variant: VersusVariant) -> Int {
        matches.lazy.filter { $0.variant == variant && $0.outcome == .win }.count
    }

    func lossCount(in variant: VersusVariant) -> Int {
        matches.lazy.filter { $0.variant == variant && $0.outcome == .loss }.count
    }

    func forfeitCount(in variant: VersusVariant) -> Int {
        matches.lazy.filter { $0.variant == variant && $0.outcome == .forfeit }.count
    }

    func drawCount(in variant: VersusVariant) -> Int {
        matches.lazy.filter { $0.variant == variant && $0.outcome == .draw }.count
    }

    /// Coop runs that finished cleanly. Used by the picker's coop tile
    /// stat blurb and by the Stats screen's coop summary.
    var coopCompletedCount: Int {
        matches.lazy.filter { $0.outcome == .coopCompleted }.count
    }

    /// Coop runs that ended due to disconnect/forfeit. Surfaced separately
    /// from completed runs so the player can see "completed vs abandoned"
    /// without having to read between the lines on a single number.
    var coopAbandonedCount: Int {
        matches.lazy.filter { $0.outcome == .coopAbandoned }.count
    }

    /// Series record vs a specific opponent, matched by GameKit display name.
    /// Returns wins (you beat them or they forfeited) and losses (they beat
    /// you or you forfeited). Draws are excluded — head-to-head is meant to
    /// answer "who's ahead in this rivalry," not "how many games have we
    /// played." Caller is responsible for hiding the UI when both are zero.
    ///
    /// Display name is the only identifier we have today; if the opponent
    /// renames their Game Center account the streak resets. Acceptable
    /// tradeoff for a v1 — proper opponent IDs would require carrying
    /// `GKPlayer.gamePlayerID` through `VersusMatchRecord`.
    func headToHead(against opponentDisplayName: String) -> (wins: Int, losses: Int) {
        var wins = 0
        var losses = 0
        for match in matches where match.opponentDisplayName == opponentDisplayName {
            switch match.outcome {
            case .win: wins += 1
            case .loss, .forfeit: losses += 1
            case .draw: break
            case .coopCompleted, .coopAbandoned: break
            }
        }
        return (wins, losses)
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
