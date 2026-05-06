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

    /// VersusGame tests don't exercise watchdog behavior — that's covered in
    /// MatchSessionTests. Use a generous disconnect grace here so the
    /// watchdog can't fire mid-test under MainActor contention and trip
    /// `observeSessionState` into a phantom `.draw` finish.
    private static let timings = MatchSessionTimings(
        heartbeatInterval: .milliseconds(50),
        disconnectGrace: .seconds(30),
        watchdogPoll: .milliseconds(50)
    )

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

    @Test("Lockout auto-clears after its duration expires so view dimming releases")
    func lockoutClearsAfterDurationExpires() async throws {
        // Bug regression: `lockoutEndsAt` was set on a failed claim but never
        // cleared on natural expiry. Because `isLockedOut` is a time-based
        // computed property, SwiftUI's @Observable wouldn't re-evaluate it
        // when the deadline passed, leaving the view stuck dimmed/locked.
        // A scheduled clear task now nils `lockoutEndsAt` at expiry.
        //
        // Short lockoutDuration so the auto-clear lands within tick window —
        // same shape as `opponentClaimEffectLifecycle`.
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()
        let hostGame = VersusGame(session: hostSession, lockoutDuration: 0.1)
        let guestGame = VersusGame(session: guestSession, lockoutDuration: 0.1)
        await hostGame.start()
        await guestGame.start()
        try await tick()
        await hostGame.acceptMatch()
        await guestGame.acceptMatch()
        try await tick()

        // Plant an invalid trio (mixed-shape, all-same color/count/fill on
        // two of three) on both peers' boards.
        let invalid = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .empty),
            SetCard(shape: .square, count: .two, color: .red, fill: .filled)
        ]
        for (i, card) in invalid.enumerated() {
            hostGame.setGame.boardSlots[i] = card
            guestGame.setGame.boardSlots[i] = card
        }

        // Guest claims the invalid trio. Host arbitrates → rejects → guest
        // receives result and starts its lockout window.
        for card in invalid {
            await guestGame.toggleSelection(card)
        }
        try await Task.sleep(for: .milliseconds(60))

        #expect(guestGame.isLockedOut)
        #expect(guestGame.lockoutEndsAt != nil)

        // Wait past the 100ms lockout. Pre-fix this would still be locked out
        // because `lockoutEndsAt` was never cleared.
        try await Task.sleep(for: .milliseconds(200))

        #expect(!guestGame.isLockedOut)
        #expect(guestGame.lockoutEndsAt == nil)
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

    // MARK: - Variant (Phase 1)

    @Test("VersusGame defaults to .normal variant when none specified")
    func variantDefaultsToNormal() async {
        let pair = makePair()
        #expect(pair.hostGame.variant == .normal)
        #expect(pair.guestGame.variant == .normal)
    }

    @Test("Explicit variant is stored on both peers")
    func variantStoredWhenProvided() async {
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()

        let hostGame = VersusGame(session: hostSession, variant: .firstTo10)
        let guestGame = VersusGame(session: guestSession, variant: .firstTo10)
        #expect(hostGame.variant == .firstTo10)
        #expect(guestGame.variant == .firstTo10)
    }

    @Test("Matching variants on both peers transition to .playing")
    func matchingVariantsAcceptedNormally() async throws {
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()

        let hostGame = VersusGame(session: hostSession, variant: .coop)
        let guestGame = VersusGame(session: guestSession, variant: .coop)
        await hostGame.start()
        await guestGame.start()
        try await tick()
        await hostGame.acceptMatch()
        await guestGame.acceptMatch()
        try await tick()

        #expect(hostGame.phase == .playing)
        #expect(guestGame.phase == .playing)
    }

    // MARK: - First-to-10 (Phase 3)

    @Test("First-to-N ends the match when host crosses the threshold")
    func firstToNHostWinsAtThreshold() async throws {
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()

        // Use a 2-trio threshold so we can exercise the end condition with
        // two valid claims rather than ten — same code path, faster test.
        let hostGame = VersusGame(
            session: hostSession,
            variant: .firstTo10,
            lockoutDuration: 2.0,
            trioWinThresholdOverride: 2
        )
        let guestGame = VersusGame(
            session: guestSession,
            variant: .firstTo10,
            lockoutDuration: 2.0,
            trioWinThresholdOverride: 2
        )
        await hostGame.start()
        await guestGame.start()
        try await tick()
        await hostGame.acceptMatch()
        await guestGame.acceptMatch()
        try await tick()

        // Plant a known valid trio; host claims.
        let trio1 = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        for (i, card) in trio1.enumerated() {
            hostGame.setGame.boardSlots[i] = card
            guestGame.setGame.boardSlots[i] = card
        }
        for card in trio1 {
            await hostGame.toggleSelection(card)
        }
        try await tick()

        // After one claim, host has 1 trio — below threshold, match still on.
        #expect(hostGame.hostTrios == 1)
        #expect(hostGame.outcome == nil)

        // Plant a second valid trio; host claims it to cross the threshold.
        let trio2 = [
            SetCard(shape: .circle, count: .two, color: .red, fill: .empty),
            SetCard(shape: .square, count: .three, color: .green, fill: .rightHalf),
            SetCard(shape: .triangle, count: .one, color: .blue, fill: .filled)
        ]
        for (i, card) in trio2.enumerated() {
            hostGame.setGame.boardSlots[i] = card
            guestGame.setGame.boardSlots[i] = card
        }
        for card in trio2 {
            await hostGame.toggleSelection(card)
        }
        try await tick()

        #expect(hostGame.hostTrios == 2)
        #expect(hostGame.outcome == .win)
        #expect(guestGame.outcome == .loss)
    }

    @Test("First-to-N is variant-gated — Normal doesn't end mid-deck")
    func normalIgnoresThresholdEvenAtTenTrios() async throws {
        let pair = makePair()
        try await startAndAcceptMatch(pair)

        // Normal variant ignores the threshold override entirely. With one
        // claim and threshold=1 (which would end firstTo10), the match
        // must continue.
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
            await pair.hostGame.toggleSelection(card)
        }
        try await tick()

        #expect(pair.hostGame.hostTrios == 1)
        // Default makePair uses .normal variant — no threshold check fires.
        #expect(pair.hostGame.outcome == nil)
    }

    // MARK: - Coop (Phase 3)

    @Test("Coop forfeit by local maps both peers to .coopAbandoned")
    func coopForfeitMapsBothToAbandoned() async throws {
        let pair = coopPair()
        try await startAndAcceptCoop(pair)

        await pair.guestGame.forfeit()
        try await tick()

        #expect(pair.guestGame.outcome == .coopAbandoned)
        // Critical: opponent does NOT see .win — coop has no winner.
        #expect(pair.hostGame.outcome == .coopAbandoned)
    }

    @Test("Coop opponent disconnect maps to .coopAbandoned for the surviving peer")
    func coopOpponentDisconnectIsAbandonment() async throws {
        let pair = coopPair()
        try await startAndAcceptCoop(pair)

        // Guest's transport reports the host disconnected.
        pair.guestTransport.emitEvent(.disconnected("P-1"))
        try await tick()

        #expect(pair.guestGame.outcome == .coopAbandoned)
        // Surviving peer doesn't get a win — coop runs end as abandoned
        // either way so neither side's stats inflate.
        #expect(pair.guestGame.winSource == nil)
    }

    @Test("Coop successful claim attributes trios to claimer but counts toward team")
    func coopClaimContributesToTeam() async throws {
        let pair = coopPair()
        try await startAndAcceptCoop(pair)

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

        // Per-player attribution preserved (used for contribution badges).
        #expect(pair.hostGame.guestTrios == 1)
        #expect(pair.hostGame.hostTrios == 0)
        // Team aggregate sums both.
        #expect(pair.hostGame.teamTrios == 1)
        #expect(pair.hostGame.teamScore > 0)
        // No winner in coop — outcome stays nil mid-game.
        #expect(pair.hostGame.outcome == nil)
    }

    // MARK: - Coop helpers

    private func coopPair() -> Pair {
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()
        let hostGame = VersusGame(session: hostSession, variant: .coop, lockoutDuration: 2.0)
        let guestGame = VersusGame(session: guestSession, variant: .coop, lockoutDuration: 2.0)
        return Pair(
            hostGame: hostGame,
            guestGame: guestGame,
            hostTransport: hostTransport,
            guestTransport: guestTransport
        )
    }

    private func startAndAcceptCoop(_ pair: Pair) async throws {
        await pair.hostGame.start()
        await pair.guestGame.start()
        try await tick()
        await pair.hostGame.acceptMatch()
        await pair.guestGame.acceptMatch()
        try await tick()
    }

    @Test("Invite recipient adopts the inviter's variant on first matchConfirmation")
    func inviteRecipientAdoptsRemoteVariant() async throws {
        // Inviter (host) chose Co-op in their picker. Invitee (guest)
        // accepted from Messages — they don't know the variant yet, so
        // they construct VersusGame with the .normal placeholder and
        // `awaitingVariantFromPeer: true`. The first matchConfirmation
        // from the inviter should flip the guest's variant to Co-op
        // and clear the flag.
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()

        // Inviter committed to Co-op in the picker.
        let hostGame = VersusGame(session: hostSession, variant: .coop)
        // Invitee has the placeholder + the awaiting flag.
        let guestGame = VersusGame(
            session: guestSession,
            variant: .normal,
            awaitingVariantFromPeer: true
        )
        await hostGame.start()
        await guestGame.start()
        try await tick()

        // Sanity: pre-adoption, guest is still on .normal.
        #expect(guestGame.variant == .normal)
        #expect(guestGame.awaitingVariantFromPeer)

        // Inviter accepts → broadcasts matchConfirmation(.coop).
        await hostGame.acceptMatch()
        try await tick()

        // Guest should have adopted .coop and cleared the flag, but
        // hasn't sent its own confirmation yet (UI hasn't shown the
        // popup until adoption — Accept can't fire).
        #expect(guestGame.variant == .coop)
        #expect(!guestGame.awaitingVariantFromPeer)
        #expect(guestGame.remoteConfirmation == .accepted)
        #expect(guestGame.localConfirmation == .pending)

        // Now the invitee taps Accept (popup is now visible to them).
        await guestGame.acceptMatch()
        try await tick()

        // Both peers playing in the inviter's chosen variant.
        #expect(hostGame.phase == .playing)
        #expect(guestGame.phase == .playing)
        #expect(hostGame.variant == .coop)
        #expect(guestGame.variant == .coop)
    }

    @Test("acceptMatch is a no-op while awaitingVariantFromPeer")
    func acceptIsHeldUntilAdoption() async throws {
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()
        let hostGame = VersusGame(session: hostSession, variant: .firstTo10)
        let guestGame = VersusGame(
            session: guestSession,
            variant: .normal,
            awaitingVariantFromPeer: true
        )
        await hostGame.start()
        await guestGame.start()
        try await tick()

        // Trying to accept before the inviter's matchConfirmation lands
        // should not mark localConfirmation as accepted (otherwise we'd
        // send Normal and the inviter would mismatch-decline).
        await guestGame.acceptMatch()
        #expect(guestGame.localConfirmation == .pending)
    }

    @Test("Mismatched variants short-circuit to decline")
    func mismatchedVariantsCauseDecline() async throws {
        // GameKit's playerGroup gating should prevent this, but a
        // misconfigured client (or test bypass) shouldn't be able to
        // accidentally play a different variant from its peer.
        let hostTransport = StubMatchTransport(localPlayerID: "P-1", remotePlayerID: "P-2")
        let guestTransport = StubMatchTransport(localPlayerID: "P-2", remotePlayerID: "P-1")
        hostTransport.peer = guestTransport
        guestTransport.peer = hostTransport
        let hostSession = MatchSession(transport: hostTransport, timings: Self.timings)
        let guestSession = MatchSession(transport: guestTransport, timings: Self.timings)
        hostSession.start()
        guestSession.start()

        let hostGame = VersusGame(session: hostSession, variant: .normal)
        let guestGame = VersusGame(session: guestSession, variant: .coop)
        await hostGame.start()
        await guestGame.start()
        try await tick()

        // Both accept — but they disagree on variant.
        await hostGame.acceptMatch()
        await guestGame.acceptMatch()
        try await tick()

        // Mismatch surfaces as a remote decline on both sides; phase ends
        // with no outcome (nothing to record in stats).
        #expect(hostGame.phase == .ended)
        #expect(guestGame.phase == .ended)
        #expect(hostGame.outcome == nil)
        #expect(guestGame.outcome == nil)
        #expect(!hostGame.hasReceivedDeck)
        #expect(!guestGame.hasReceivedDeck)
    }
}
