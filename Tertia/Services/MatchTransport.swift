//
//  MatchTransport.swift
//  Tertia
//
//  Abstracts the wire so the rest of the versus stack doesn't have to know
//  about GameKit. Production uses GKMatchTransport (wraps GKMatch); unit
//  tests use StubMatchTransport (an in-memory loopback).
//

import Foundation
import GameKit
import OSLog

private let logger = Logger(subsystem: "Mark.Tertia", category: "MatchTransport")

/// Connection state changes the higher-level MatchSession needs to react to.
/// We don't model "reconnected" here — once a peer is gone we just emit a
/// disconnect and let the session decide whether to forfeit.
enum MatchConnectionEvent: Sendable, Equatable {
    case connected(VersusPlayerID)
    case disconnected(VersusPlayerID)
    /// Some terminal transport error (other than a clean disconnect). Surface
    /// to the user as "match ended unexpectedly."
    case failed(reason: String)
}

/// Anything that can shuttle bytes between the local player and exactly one
/// remote player. We're 1v1-only by design — extending this protocol to
/// >2 players is a deliberate future scope decision, not a casual change.
protocol MatchTransport: AnyObject, Sendable {
    var localPlayerID: VersusPlayerID { get }
    var remotePlayerID: VersusPlayerID? { get }

    /// Bytes received from the remote peer, oldest → newest.
    var incoming: AsyncStream<Data> { get }

    /// Connection lifecycle events (connect, disconnect, failure).
    var connectionEvents: AsyncStream<MatchConnectionEvent> { get }

    /// Reliable, ordered send to the remote peer. Throws if the underlying
    /// transport is gone (peer disconnected, match torn down).
    func send(_ data: Data) async throws

    /// Tears down the underlying connection. Idempotent — calling more than
    /// once is harmless.
    func disconnect()
}

// MARK: - Production: GKMatch

/// Wraps a `GKMatch` and bridges its NSObject delegate callbacks into
/// AsyncStreams. Owned by `MatchSession` for the lifetime of a versus
/// match; tear down via `disconnect()` when leaving.
final class GKMatchTransport: NSObject, MatchTransport, @unchecked Sendable, GKMatchDelegate {
    let localPlayerID: VersusPlayerID

    private let match: GKMatch
    private let dataContinuation: AsyncStream<Data>.Continuation
    private let eventContinuation: AsyncStream<MatchConnectionEvent>.Continuation
    let incoming: AsyncStream<Data>
    let connectionEvents: AsyncStream<MatchConnectionEvent>

    init(match: GKMatch) {
        self.match = match
        self.localPlayerID = GKLocalPlayer.local.gamePlayerID

        var dataCont: AsyncStream<Data>.Continuation!
        self.incoming = AsyncStream { dataCont = $0 }
        self.dataContinuation = dataCont

        var eventCont: AsyncStream<MatchConnectionEvent>.Continuation!
        self.connectionEvents = AsyncStream { eventCont = $0 }
        self.eventContinuation = eventCont

        super.init()
        match.delegate = self
    }

    var remotePlayerID: VersusPlayerID? {
        // 1v1-only: take the first non-local player. If GameKit ever hands us
        // a match with no remote players (shouldn't, but defensively), return nil.
        match.players.first?.gamePlayerID
    }

    func send(_ data: Data) async throws {
        // sendData(toAllPlayers:) is the simplest 1v1 path; we only have one
        // remote peer so "all" == "the opponent." Reliable mode preserves
        // ordering, which the claim-arbitration logic depends on.
        try match.sendData(toAllPlayers: data, with: .reliable)
    }

    func disconnect() {
        match.disconnect()
        dataContinuation.finish()
        eventContinuation.finish()
    }

    // MARK: GKMatchDelegate

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        dataContinuation.yield(data)
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        let id = player.gamePlayerID
        switch state {
        case .connected:
            eventContinuation.yield(.connected(id))
        case .disconnected:
            eventContinuation.yield(.disconnected(id))
        case .unknown:
            // GameKit emits .unknown on transient state we shouldn't react to.
            break
        @unknown default:
            break
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        let reason = error?.localizedDescription ?? "Unknown match failure"
        logger.error("GKMatch failed: \(reason)")
        eventContinuation.yield(.failed(reason: reason))
    }
}

// MARK: - Test stub

/// In-memory loopback transport. Tests inject incoming data and capture
/// outbound sends without touching GameKit. The "remote" side is just
/// whatever the test choreographs — typically two `StubMatchTransport`
/// instances paired so each one's `send` lands on the other's `incoming`.
final class StubMatchTransport: MatchTransport, @unchecked Sendable {
    let localPlayerID: VersusPlayerID
    private(set) var remotePlayerID: VersusPlayerID?

    let incoming: AsyncStream<Data>
    let connectionEvents: AsyncStream<MatchConnectionEvent>

    private let incomingContinuation: AsyncStream<Data>.Continuation
    private let eventsContinuation: AsyncStream<MatchConnectionEvent>.Continuation

    /// Captured outbound payloads, in send order. Tests assert against this.
    private(set) var sentPayloads: [Data] = []

    /// When set, `send` forwards every payload to `peer.deliverIncoming` —
    /// lets tests pair two transports together and exercise full round-trips
    /// without touching GameKit. `weak` so paired transports don't retain
    /// each other.
    weak var peer: StubMatchTransport?

    /// When set, `send` invokes this before recording. Lets tests fail-inject
    /// transport errors. Cleared after each call so it only fires once.
    var nextSendError: Error?

    init(localPlayerID: VersusPlayerID, remotePlayerID: VersusPlayerID? = nil) {
        self.localPlayerID = localPlayerID
        self.remotePlayerID = remotePlayerID

        var dataCont: AsyncStream<Data>.Continuation!
        self.incoming = AsyncStream { dataCont = $0 }
        self.incomingContinuation = dataCont

        var eventsCont: AsyncStream<MatchConnectionEvent>.Continuation!
        self.connectionEvents = AsyncStream { eventsCont = $0 }
        self.eventsContinuation = eventsCont
    }

    func send(_ data: Data) async throws {
        if let error = nextSendError {
            nextSendError = nil
            throw error
        }
        sentPayloads.append(data)
        peer?.deliverIncoming(data)
    }

    func disconnect() {
        incomingContinuation.finish()
        eventsContinuation.finish()
    }

    // MARK: Test choreography

    /// Simulates the remote peer sending `data`.
    func deliverIncoming(_ data: Data) {
        incomingContinuation.yield(data)
    }

    /// Simulates a connection event.
    func emitEvent(_ event: MatchConnectionEvent) {
        eventsContinuation.yield(event)
    }
}
