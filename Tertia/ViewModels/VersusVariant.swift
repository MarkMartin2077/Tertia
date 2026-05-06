//
//  VersusVariant.swift
//  Tertia
//
//  Which "flavor" of versus a session is running. Picked at the
//  mode-select screen, threaded through MatchSession into VersusGame,
//  and gated by GameKit's `playerGroup` so the matchmaker only pairs
//  players who selected the same variant.
//
//  - .normal:    race for the highest score, ends when the deck is done
//  - .firstTo10: first player to 10 trios wins
//  - .coop:      shared score, work the deck together, no winner
//

import Foundation
import SwiftUI

enum VersusVariant: String, Codable, Sendable, CaseIterable, Equatable {
    case normal
    case firstTo10
    case coop

    /// Stable integer used as `GKMatchRequest.playerGroup` so GameKit
    /// only auto-matches peers who chose the same variant. Hand-picked
    /// IDs (rather than a hash) so the values are easy to inspect in
    /// logs and unchanged across binary builds.
    var playerGroup: Int {
        switch self {
        case .normal:    return 1_000
        case .firstTo10: return 1_001
        case .coop:      return 1_002
        }
    }

    /// Win-target trio count for `.firstTo10`. Returns nil for variants
    /// without a trio threshold so the game-over check can early-out.
    var trioWinThreshold: Int? {
        switch self {
        case .firstTo10: return 10
        case .normal, .coop: return nil
        }
    }

    /// Whether this variant produces a competitive winner/loser. False
    /// for coop where both players share the outcome.
    var isCompetitive: Bool {
        switch self {
        case .normal, .firstTo10: return true
        case .coop: return false
        }
    }

    /// Short label for chips, badges, and analytics. Stable — used for
    /// cross-variant filtering in stats so don't change without a
    /// migration plan.
    var shortName: String {
        switch self {
        case .normal:    return "Normal"
        case .firstTo10: return "First to 10"
        case .coop:      return "Co-op"
        }
    }

    /// Variant-specific accent that carries from the picker into the
    /// in-game header, the game-over sheet, and the action bar. Reading
    /// the variant's accent rather than `GameMode.versus.accentColor`
    /// gives each mode its own visual identity.
    var accent: Color {
        switch self {
        case .normal:    return GameMode.versus.accentColor
        case .firstTo10: return .orange
        case .coop:      return .teal
        }
    }
}
