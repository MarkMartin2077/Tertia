//
//  VersusGameTypes.swift
//  Tertia
//
//  Public-facing types associated with `VersusGame`: the opponent-claim
//  effect snapshot, the rematch state machine, win-source attribution,
//  the lifecycle phase enum, and the per-peer confirmation decision.
//  Kept in their own file so `VersusGame.swift` is just the coordinator.
//

import Foundation

/// Snapshot of an opponent's just-completed successful claim. Drives the
/// 1.5s pulsing-highlight overlay so the local player can see what the
/// opponent grabbed before the cards dissolve.
struct OpponentClaimEffectState: Equatable {
    let cards: [SetCard]
    let claimedBy: VersusPlayerID
    let startedAt: Date
}

/// Local-side state machine for the post-game rematch flow: tap Rematch
/// → wait up to 15s → if opponent agrees, both transition to a fresh
/// game; if they decline or time out, surface a "find a new match?"
/// suggestion.
enum RematchState: Equatable, Sendable {
    case idle
    case localRequested
    case opponentRequested
    case agreed
    case opponentDeclined
}

/// Why the local player won (when `outcome == .win`). Drives the headline
/// and subtitle text on the game-over sheet so a "you won by score" reads
/// differently from "the opponent disconnected mid-match."
enum VersusWinSource: Equatable, Sendable {
    case scoreFinal
    case opponentForfeited
    case opponentDisconnected
}

/// Lifecycle phases for a versus session. The pre-game `awaitingConfirmation`
/// stage gives both peers a chance to back out after GameKit hands them an
/// opponent — the deck isn't seeded until both confirm. `ended` covers both
/// gameplay completion (with `outcome` set) and pre-game abandonment
/// (`outcome == nil`).
enum VersusGamePhase: Equatable, Sendable {
    case awaitingConfirmation
    case playing
    case ended
}

/// Per-peer confirmation state during the pre-game handshake.
enum MatchConfirmationDecision: Equatable, Sendable {
    case pending
    case accepted
    case declined
}
