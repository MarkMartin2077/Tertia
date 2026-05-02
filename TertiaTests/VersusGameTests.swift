//
//  VersusGameTests.swift
//  TertiaTests
//
//  Integration tests for the host-authoritative versus model. Two paired
//  StubMatchTransports let host and guest VersusGames exchange real
//  messages without touching GameKit. Suite runs serialized — async pumps
//  on shared MainActor would otherwise starve each other.
//

import Foundation
import Testing
@testable import Tertia

@Suite("VersusGame", .serialized)
@MainActor
struct VersusGameTests {

    private static let timings = MatchSessionTimings.unitTest

    private struct Pair {
        let hostGame: VersusGame
        let guestGame: VersusGame
        let hostTransport: StubMatchTransport
        let guestTransport: StubMatchTransport
    }

    private func makePair() -> Pair {
        // Lex order: "P-1" < "P-2" → P-1 is host.
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport

        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()

        // Lockout long enough that the post-tick assertion still observes it
        // as active. The lockout-expiry path is tested separately if needed.
        let hostGame = VersusGame(session: hostSession, lockoutDuration: 2.0)
        let guestGame = VersusGame(session: guestSession, lockoutDuration: 2.0)

        return Pair(
            hostGame: hostGame,
            guestGame: guestGame,
            hostTransport: hostTransport,
            guestTransport: guestTransport
        )
    }

    /// Run both peers' message pumps long enough for queued messages to
    /// flow through. Generous default — when MatchSessionTests is running
    /// concurrently in another @MainActor suite, MainActor time is shared
    /// and short windows weren't enough for the deck-sync handshake to
    /// settle. 500ms gives the message pump plenty of headroom even under
    /// MainActor contention.
    private func tick(_ ms: UInt64 = 500) async throws {
        try await Task.sleep(for: .milliseconds(Int(ms)))
    }

    /// Standard "both peers are ready to play" setup used by every gameplay
    /// test. Starts both VersusGames, has both accept the pre-game match
    /// confirmation popup, and ticks long enough for the deck seed to
    /// propagate.
    private func startAndAcceptMatch(_ pair: Pair) async throws {
        await pair.hostGame.start()
        await pair.guestGame.start()
        try await tick()
        await pair.hostGame.acceptMatch()
        await pair.guestGame.acceptMatch()
        try await tick()
    }

    @Test("Host election matches transport-level decision")
    func hostElection() async {
        let pair = makePair()
        #expect(pair.hostGame.isHost)
        #expect(!pair.guestGame.isHost)
    }

    // MARK: - Pre-game confirmation

    @Test("Fresh game starts in awaitingConfirmation with both decisions pending")
    func freshGameStartsAwaitingConfirmation() async throws {
        let pair = makePair()
        await pair.hostGame.start()
        await pair.guestGame.start()
        try await tick()

        #expect(pair.hostGame.phase == .awaitingConfirmation)
        #expect(pair.guestGame.phase == .awaitingConfirmation)
        #expect(pair.hostGame.localConfirmation == .pending)
        #expect(pair.guestGame.localConfirmation == .pending)
        // Critical: the host must NOT have seeded the deck yet — that's the
        // whole point of deferring until both peers accept.
        #expect(!pair.hostGame.hasReceivedDeck)
        #expect(!pair.guestGame.hasReceivedDeck)
    }

    @Test("Both peers accepting moves phase to playing and seeds the deck")
    func bothAcceptingStartsPlaying() async throws {
        let pair = makePair()
        await pair.hostGame.start()
        await pair.guestGame.start()
        try await tick()

        await pair.hostGame.acceptMatch()
        await pair.guestGame.acceptMatch()
        try await tick()

        #expect(pair.hostGame.phase == .playing)
        #expect(pair.guestGame.phase == .playing)
        #expect(pair.hostGame.localConfirmation == .accepted)
        #expect(pair.hostGame.remoteConfirmation == .accepted)
        #expect(pair.hostGame.hasReceivedDeck)
        #expect(pair.guestGame.hasReceivedDeck)
    }

    @Test("Local declining ends the match with no outcome and no recorded deck")
    func localDeclineAbandonsMatch() async throws {
        let pair = makePair()
        await pair.hostGame.start()
        await pair.guestGame.start()
        try await tick()

        await pair.hostGame.declineMatch()
        try await tick()

        #expect(pair.hostGame.phase == .ended)
        #expect(pair.hostGame.outcome == nil)
        #expect(pair.hostGame.localConfirmation == .declined)
        // Guest should mirror via the broadcast confirmation message.
        #expect(pair.guestGame.phase == .ended)
        #expect(pair.guestGame.outcome == nil)
        #expect(pair.guestGame.remoteConfirmation == .declined)
        // No deck should have been seeded on either side.
        #expect(!pair.hostGame.hasReceivedDeck)
        #expect(!pair.guestGame.hasReceivedDeck)
    }

    @Test("Remote declining flips local phase to ended without an outcome")
    func remoteDeclineAbandonsMatch() async throws {
        let pair = makePair()
        await pair.hostGame.start()
        await pair.guestGame.start()
        try await tick()

        // Host accepts, guest declines.
        await pair.hostGame.acceptMatch()
        await pair.guestGame.declineMatch()
        try await tick()

        #expect(pair.hostGame.phase == .ended)
        #expect(pair.hostGame.outcome == nil)
        #expect(pair.hostGame.remoteConfirmation == .declined)
        #expect(!pair.hostGame.hasReceivedDeck)
    }

    @Test("Host's deck seed propagates and both peers build the same board")
    func deckSyncOnStart() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        #expect(pair.hostGame.hasReceivedDeck)
        #expect(pair.guestGame.hasReceivedDeck)
        // Both peers should have an initial board of `boardSize` cards with
        // matching attribute tuples (UUIDs differ across processes/peers).
        let hostWire = pair.hostGame.setGame.boardSlots.map(\.wire)
        let guestWire = pair.guestGame.setGame.boardSlots.map(\.wire)
        #expect(hostWire == guestWire)
        #expect(hostWire.count == SetGame.boardSize)
    }

    @Test("Host claiming a valid trio updates host's score on both peers")
    func hostClaimUpdatesBothScores() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        // Plant a known valid trio at the start of the host's board, then
        // mirror the same wire-card identities on the guest. Direct mutation
        // is fine here — we control both peers in the test.
        let trio = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        for (i, card) in trio.enumerated() {
            pair.hostGame.setGame.boardSlots[i] = card
            pair.guestGame.setGame.boardSlots[i] = card
        }

        // Host taps all three.
        for card in trio {
            await pair.hostGame.toggleSelection(card)
        }
        try await tick()

        #expect(pair.hostGame.hostScore > 0)
        #expect(pair.hostGame.hostTrios == 1)
        #expect(pair.guestGame.hostScore == pair.hostGame.hostScore)
        #expect(pair.guestGame.hostTrios == 1)
        // The matched cards should be gone from both boards.
        for card in trio {
            #expect(!pair.hostGame.setGame.boardSlots.contains(card))
            #expect(!pair.guestGame.setGame.boardSlots.contains(card))
        }
    }

    @Test("Guest claim is arbitrated by host and credited to guest on both peers")
    func guestClaimRoundTrip() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        let trio = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        for (i, card) in trio.enumerated() {
            pair.hostGame.setGame.boardSlots[i] = card
            pair.guestGame.setGame.boardSlots[i] = card
        }

        for card in trio {
            await pair.guestGame.toggleSelection(card)
        }
        try await tick()

        #expect(pair.guestGame.guestScore > 0)
        #expect(pair.guestGame.guestTrios == 1)
        #expect(pair.hostGame.guestScore == pair.guestGame.guestScore)
        #expect(pair.hostGame.guestTrios == 1)
    }

    @Test("Invalid claim from guest triggers a lockout on the guest only")
    func invalidGuestClaimLocksOutGuest() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        // Plant three identical cards (not a valid trio — fill differs only
        // would be valid, but identical cards are NOT a set under explain).
        // Actually three identical cards ARE a set (all-same). Use a known
        // invalid trio: two same color, one different on otherwise mixed.
        let invalid = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .empty),
            SetCard(shape: .square, count: .two, color: .red, fill: .filled)
        ]
        for (i, card) in invalid.enumerated() {
            pair.hostGame.setGame.boardSlots[i] = card
            pair.guestGame.setGame.boardSlots[i] = card
        }

        for card in invalid {
            await pair.guestGame.toggleSelection(card)
        }
        try await tick()

        #expect(pair.guestGame.isLockedOut)
        #expect(!pair.hostGame.isLockedOut)
        // Cards should still be on the board — invalid claim doesn't remove.
        for card in invalid {
            #expect(pair.hostGame.setGame.boardSlots.contains(card))
        }
    }

    @Test("Forfeit from local ends the match locally and signals opponent's win")
    func forfeitEndsMatch() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        await pair.guestGame.forfeit()
        try await tick()

        #expect(pair.guestGame.outcome == .forfeit)
        #expect(pair.hostGame.outcome == .win)
    }

    // MARK: - Rematch flow

    @Test("Both peers tapping Rematch resets state for a fresh game")
    func bothRematchTriggersFreshGame() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        // End the match by guest forfeiting → host has outcome=.win, guest=.forfeit.
        await pair.guestGame.forfeit()
        try await tick()
        #expect(pair.hostGame.outcome != nil)
        #expect(pair.guestGame.outcome != nil)

        // Host requests; guest then requests; both should land in agreed and
        // reset back to a fresh game state.
        await pair.hostGame.requestRematch()
        try await tick()
        #expect(pair.guestGame.rematchState == .opponentRequested)
        #expect(pair.hostGame.rematchState == .localRequested)

        await pair.guestGame.requestRematch()
        try await tick()

        #expect(pair.hostGame.outcome == nil)
        #expect(pair.guestGame.outcome == nil)
        #expect(pair.hostGame.rematchState == .idle)
        #expect(pair.guestGame.rematchState == .idle)
        // New deck dealt, scores zeroed.
        #expect(pair.hostGame.hostScore == 0)
        #expect(pair.hostGame.guestScore == 0)
        #expect(pair.hostGame.setGame.boardSlots.count == SetGame.boardSize)
        #expect(pair.guestGame.setGame.boardSlots.count == SetGame.boardSize)
    }

    @Test("Decline from opponent flips local rematch state to opponentDeclined")
    func declineSurfacesImmediately() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        await pair.guestGame.forfeit()
        try await tick()

        // Host taps Rematch and waits.
        await pair.hostGame.requestRematch()
        try await tick()
        #expect(pair.hostGame.rematchState == .localRequested)

        // Guest declines explicitly — host should see opponentDeclined.
        await pair.guestGame.declineRematch()
        try await tick()
        #expect(pair.hostGame.rematchState == .opponentDeclined)
        #expect(pair.guestGame.rematchState == .opponentDeclined)
    }

    @Test("Rematch timeout flips localRequested → opponentDeclined after the configured delay")
    func rematchTimesOut() async throws {
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()
        let hostGame = VersusGame(
            session: hostSession,
            lockoutDuration: 2.0,
            rematchTimeoutDuration: 0.1
        )
        let guestGame = VersusGame(
            session: guestSession,
            lockoutDuration: 2.0,
            rematchTimeoutDuration: 0.1
        )
        await hostGame.start()
        await guestGame.start()
        try await tick()

        await guestGame.forfeit()
        try await tick()

        await hostGame.requestRematch()
        try await Task.sleep(for: .milliseconds(60))
        #expect(hostGame.rematchState == .localRequested)

        // Wait past the 100ms timeout.
        try await Task.sleep(for: .milliseconds(200))
        #expect(hostGame.rematchState == .opponentDeclined)
    }

    @Test("Successful opponent claim sets the opponentClaimEffect, then auto-clears")
    func opponentClaimEffectLifecycle() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        let trio = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        for (i, card) in trio.enumerated() {
            pair.hostGame.setGame.boardSlots[i] = card
            pair.guestGame.setGame.boardSlots[i] = card
        }

        // Use a short effect duration so the auto-clear happens within tick window.
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()
        let hostGame = VersusGame(
            session: hostSession,
            lockoutDuration: 2.0,
            opponentClaimEffectDuration: 0.1
        )
        let guestGame = VersusGame(
            session: guestSession,
            lockoutDuration: 2.0,
            opponentClaimEffectDuration: 0.1
        )
        await hostGame.start()
        await guestGame.start()
        try await tick()
        // Both peers must accept the match before the deck is seeded.
        await hostGame.acceptMatch()
        await guestGame.acceptMatch()
        try await tick()

        for (i, card) in trio.enumerated() {
            hostGame.setGame.boardSlots[i] = card
            guestGame.setGame.boardSlots[i] = card
        }

        // Guest claims; host should see the opponent-claim effect appear.
        for card in trio { await guestGame.toggleSelection(card) }
        try await Task.sleep(for: .milliseconds(60))

        #expect(hostGame.opponentClaimEffect != nil)
        #expect(hostGame.opponentClaimEffect?.cards.count == 3)

        // Wait past the effect duration; host should auto-clear.
        try await Task.sleep(for: .milliseconds(200))
        #expect(hostGame.opponentClaimEffect == nil)
    }

    // MARK: - Phase 8 — disconnect / late message hardening

    @Test("Opponent transport disconnect surfaces as a win with .opponentDisconnected source")
    func opponentDisconnectFlagsWinSource() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        // Guest's transport reports the host disconnected. Host is "remote"
        // from guest's perspective.
        pair.guestTransport.emitEvent(.disconnected("P-1"))
        try await tick()

        #expect(pair.guestGame.outcome == .win)
        #expect(pair.guestGame.winSource == .opponentDisconnected)
    }

    @Test("Opponent forfeit surfaces as a win with .opponentForfeited source")
    func opponentForfeitFlagsWinSource() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        await pair.guestGame.forfeit()
        try await tick()

        #expect(pair.hostGame.outcome == .win)
        #expect(pair.hostGame.winSource == .opponentForfeited)
        #expect(pair.guestGame.outcome == .forfeit)
        #expect(pair.guestGame.winSource == nil)
    }

    @Test("Transport failure resolves to a draw")
    func transportFailureIsDraw() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        pair.guestTransport.emitEvent(.failed(reason: "test induced"))
        try await tick()

        #expect(pair.guestGame.outcome == .draw)
    }

    @Test("Late claim message after game-over is dropped, not processed")
    func lateClaimAfterOutcomeIsDropped() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        // Force a game-over via forfeit.
        await pair.guestGame.forfeit()
        try await tick()
        #expect(pair.hostGame.outcome != nil)

        // Inject a stale claim payload directly into the host's transport.
        // Should be dropped because the match is over.
        let trio = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        let payload = try JSONEncoder().encode(
            VersusMessage.claim(cards: trio.map(\.wire), at: .now, claimID: UUID())
        )
        pair.hostTransport.deliverIncoming(payload)
        try await tick()

        // Host's per-player counters must not have moved.
        #expect(pair.hostGame.guestTrios == 0)
        #expect(pair.hostGame.guestScore == 0)
    }

    @Test("Duplicate claims with the same claimID are arbitrated only once")
    func duplicateClaimIdempotent() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        let trio = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        for (i, card) in trio.enumerated() {
            pair.hostGame.setGame.boardSlots[i] = card
            pair.guestGame.setGame.boardSlots[i] = card
        }

        // Manually craft and inject a duplicate claim payload directly.
        let claimID = UUID()
        let payload = try JSONEncoder().encode(
            VersusMessage.claim(cards: trio.map(\.wire), at: .now, claimID: claimID)
        )
        pair.hostTransport.deliverIncoming(payload)
        pair.hostTransport.deliverIncoming(payload)
        pair.hostTransport.deliverIncoming(payload)
        try await tick()

        // Score should reflect exactly one claim, not three.
        #expect(pair.hostGame.guestTrios == 1)
        #expect(pair.guestGame.guestTrios == 1)
    }
}
