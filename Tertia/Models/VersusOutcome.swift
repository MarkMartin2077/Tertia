//
//  VersusOutcome.swift
//  Tertia
//
//  Final result of a versus match from the local player's perspective. Maps
//  one-to-one to the four-column stats record described in VERSUS_PLAN.md:
//  Wins / Losses / Forfeits / Draws.
//

import Foundation

enum VersusOutcome: String, Codable, Equatable, Sendable {
    /// Local player won — either by score or because the opponent forfeited.
    case win

    /// Local player lost on score.
    case loss

    /// Local player forfeited (button press, app backgrounded, etc.). Tracked
    /// separately from losses because it represents a different player
    /// behavior — opponent forfeits land in `.win` for the local player.
    case forfeit

    /// Both players' scores AND trio counts tied at the end of the deck, OR
    /// both players disconnected simultaneously. Recorded as the same value
    /// either way — UI / stats can treat them identically.
    case draw

    /// Coop variant only. Both players completed the deck together.
    /// Recorded with the team's combined trio count rather than a winner.
    case coopCompleted

    /// Coop variant only. One player left mid-match, so the run can't be
    /// recorded as completed. Surfaced to both peers so neither's stats
    /// inflate.
    case coopAbandoned
}

extension VersusOutcome {
    /// Whether this outcome belongs to a coop run. Lets UI and stats split
    /// "competitive history" from "coop history" cleanly.
    var isCoop: Bool {
        switch self {
        case .coopCompleted, .coopAbandoned: return true
        case .win, .loss, .forfeit, .draw:   return false
        }
    }
}
