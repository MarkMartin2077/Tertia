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
}
