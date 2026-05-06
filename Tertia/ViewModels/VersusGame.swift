//
//  VersusGame.swift
//  Tertia
//
//  Host-authoritative coordinator for a 1-on-1 versus match. Wraps a
//  MatchSession (transport + heartbeat) and a SetGame (board + rules) and
//  layers per-player scoring + claim arbitration on top.
//
//  Both peers run an instance of this class. Host is the authority — it
//  validates and applies claims, then broadcasts `.claimResult`. Guest sends
//  claims and applies host's authoritative results to its mirror SetGame.
//  See VERSUS_PLAN.md for the full design.
//

import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "Mark.Tertia", category: "VersusGame")

@MainActor
@Observable
final class VersusGame: Identifiable {
    // MARK: - Configuration

    let id = UUID()
    /// The session's variant. Set at construction in the normal flow
    /// (inviter chose it in the picker). For invite recipients it's a
    /// placeholder until the inviter's first `matchConfirmation` arrives
    /// and the variant is adopted from that message — see
    /// `awaitingVariantFromPeer`.
    private(set) var variant: VersusVariant
    private let session: MatchSession
    private let lockoutDuration: TimeInterval
    private let comboWindow: TimeInterval = 5
    private let clock: @MainActor () -> Date
    private let opponentClaimEffectDuration: TimeInterval
    private let rematchTimeoutDuration: TimeInterval
    private let confirmationTimeoutDuration: TimeInterval
    /// Override for `variant.trioWinThreshold`. Production code passes
    /// nil and uses the variant's default; tests can lower the threshold
    /// (e.g., 2) to exercise the end-condition path without faking 10
    /// sequential claims. Ignored for variants without a threshold.
    private let trioWinThresholdOverride: Int?

    // MARK: - Identity

    let isHost: Bool
    let localPlayerID: VersusPlayerID
    let remotePlayerID: VersusPlayerID
    let localDisplayName: String
    let remoteDisplayName: String

    var hostID: VersusPlayerID { isHost ? localPlayerID : remotePlayerID }
    var guestID: VersusPlayerID { isHost ? remotePlayerID : localPlayerID }

    // MARK: - Game state (mirrored on both peers)

    private(set) var setGame: SetGame
    private(set) var hostScore: Int = 0
    private(set) var guestScore: Int = 0
    private(set) var hostTrios: Int = 0
    private(set) var guestTrios: Int = 0
    private(set) var hostMultiplier: Int = 1
    private(set) var guestMultiplier: Int = 1
    private(set) var hostLongestStreak: Int = 0
    private(set) var guestLongestStreak: Int = 0
    private(set) var hostFastestSetSeconds: Double?
    private(set) var guestFastestSetSeconds: Double?
    private(set) var outcome: VersusOutcome?

    /// Set when `outcome == .win`. Lets the game-over sheet differentiate
    /// "great race" from "opponent disconnected" / "opponent forfeited."
    private(set) var winSource: VersusWinSource?

    private(set) var hasReceivedDeck: Bool = false

    /// Lifecycle phase. `awaitingConfirmation` is the pre-game popup,
    /// `playing` is active gameplay, `ended` is terminal (either with an
    /// outcome from gameplay or with `outcome == nil` if the match was
    /// abandoned at confirmation).
    private(set) var phase: VersusGamePhase = .awaitingConfirmation
    private(set) var localConfirmation: MatchConfirmationDecision = .pending
    private(set) var remoteConfirmation: MatchConfirmationDecision = .pending

    /// True while the local peer is an invite recipient who hasn't yet
    /// received the inviter's first `matchConfirmation` (which carries
    /// the inviter's selected variant). Drives the view layer to show a
    /// "connecting" overlay rather than the confirmation popup until the
    /// variant is known. Cleared the moment the peer's first
    /// `matchConfirmation` lands.
    private(set) var awaitingVariantFromPeer: Bool

    // MARK: - Local-only state

    /// Cards the local player has tapped, pre-claim. Cleared on commit
    /// (third tap → claim sent) or invalid trio (third tap with mismatched
    /// attributes → still sent for arbitration but selection clears).
    private(set) var selectedCards: Set<SetCard> = []

    /// While `> .now`, the local player can't claim. Set by the local side
    /// when its claim comes back from the host with `success: false`.
    private(set) var lockoutEndsAt: Date?

    /// Set when the remote player successfully claims. View layer renders a
    /// floating ghost trio overlay for the duration before clearing.
    private(set) var opponentClaimEffect: OpponentClaimEffectState?

    /// Drives the post-game rematch UI in `VersusGameOverSheet`. Reset to
    /// `.idle` whenever a fresh match starts (initial deck or rematch).
    private(set) var rematchState: RematchState = .idle

    // MARK: - Internal

    private var hostSeed: UInt64?
    private var hostLastSetAt: Date?
    private var guestLastSetAt: Date?
    private var hostLastResolveAt: Date?
    private var guestLastResolveAt: Date?
    /// Claim IDs the host has already arbitrated. Used to ignore duplicates
    /// from a flaky network. Guest tracks its own outstanding claims so it
    /// can correlate results back.
    private var processedClaimIDs: Set<UUID> = []
    private var pumpTask: Task<Void, Never>?
    private var stateObserverTask: Task<Void, Never>?
    private var lockoutClearTask: Task<Void, Never>?

    // MARK: - Convenience

    var localScore: Int { isHost ? hostScore : guestScore }
    var remoteScore: Int { isHost ? guestScore : hostScore }
    var localTrios: Int { isHost ? hostTrios : guestTrios }
    var remoteTrios: Int { isHost ? guestTrios : hostTrios }
    var localMultiplier: Int { isHost ? hostMultiplier : guestMultiplier }
    var remoteMultiplier: Int { isHost ? guestMultiplier : hostMultiplier }
    var localLongestStreak: Int { isHost ? hostLongestStreak : guestLongestStreak }
    var remoteLongestStreak: Int { isHost ? guestLongestStreak : hostLongestStreak }
    var localFastestSetSeconds: Double? { isHost ? hostFastestSetSeconds : guestFastestSetSeconds }
    var remoteFastestSetSeconds: Double? { isHost ? guestFastestSetSeconds : hostFastestSetSeconds }

    /// Team aggregates for coop. Always defined (sum is well-formed for
    /// any variant) so views can reference them unconditionally and just
    /// switch on the variant for *which* number to surface.
    var teamScore: Int { hostScore + guestScore }
    var teamTrios: Int { hostTrios + guestTrios }
    /// Coop's shared combo number. Both peer multipliers are kept in
    /// lockstep when the variant is coop, so reading either is equivalent.
    var teamMultiplier: Int { max(hostMultiplier, guestMultiplier) }

    var isLockedOut: Bool {
        guard let end = lockoutEndsAt else { return false }
        return clock() < end
    }

    var isGameOver: Bool {
        outcome != nil
    }

    /// Whether the underlying transport is still alive. Used by the
    /// game-over sheet to disable Rematch when the session has already
    /// torn down — a tap on Rematch would just sit silently for 15s
    /// otherwise (timeout flips to opponentDeclined).
    var isSessionConnected: Bool {
        if case .disconnected = session.state { return false }
        return true
    }

    // MARK: - Init

    init(
        session: MatchSession,
        variant: VersusVariant = .normal,
        awaitingVariantFromPeer: Bool = false,
        localDisplayName: String = "You",
        remoteDisplayName: String = "Opponent",
        lockoutDuration: TimeInterval = 1.5,
        opponentClaimEffectDuration: TimeInterval = 1.5,
        rematchTimeoutDuration: TimeInterval = 15,
        confirmationTimeoutDuration: TimeInterval = 15,
        trioWinThresholdOverride: Int? = nil,
        clock: @escaping @MainActor () -> Date = { .now }
    ) {
        self.session = session
        self.variant = variant
        self.awaitingVariantFromPeer = awaitingVariantFromPeer
        self.localDisplayName = localDisplayName
        self.remoteDisplayName = remoteDisplayName
        self.lockoutDuration = lockoutDuration
        self.opponentClaimEffectDuration = opponentClaimEffectDuration
        self.rematchTimeoutDuration = rematchTimeoutDuration
        self.confirmationTimeoutDuration = confirmationTimeoutDuration
        self.trioWinThresholdOverride = trioWinThresholdOverride
        self.clock = clock
        self.isHost = session.isHost
        self.localPlayerID = session.localPlayerID
        self.remotePlayerID = session.remotePlayerID ?? ""
        // Empty deck until the host's seed lands. SetGame is built with
        // autoDeal=false so we control the deal animation from the view layer.
        self.setGame = SetGame(mode: .versus, autoDeal: false, deckBuilder: { [] })
    }

    // MARK: - Lifecycle

    /// Kicks off the message pump and the confirmation timeout. Does NOT
    /// broadcast the deck seed yet — that's deferred until both peers have
    /// accepted the match (see `evaluateConfirmationProgress`). Idempotent.
    func start() async {
        guard pumpTask == nil else { return }
        pumpTask = Task { @MainActor [weak self] in
            await self?.pumpMessages()
        }
        stateObserverTask = Task { @MainActor [weak self] in
            await self?.observeSessionState()
        }
        scheduleConfirmationTimeout()
    }

    /// Shuts down the message pump. Idempotent.
    func leave() {
        pumpTask?.cancel()
        stateObserverTask?.cancel()
        lockoutClearTask?.cancel()
        session.leave()
    }

    // MARK: - Local actions

    /// Toggles selection of a card. Once three are selected, fires the claim
    /// pipeline: host arbitrates locally, guest sends `.claim` to host.
    /// Lockout-aware — taps are dropped while `isLockedOut`.
    func toggleSelection(_ card: SetCard) async {
        guard outcome == nil else { return }
        guard !isLockedOut else { return }
        guard setGame.boardSlots.contains(card) else { return }

        if selectedCards.contains(card) {
            selectedCards.remove(card)
            return
        }

        // Reset stale third-tap state so a fourth tap starts fresh.
        if selectedCards.count >= SetGame.setSize {
            selectedCards.removeAll()
        }

        selectedCards.insert(card)

        if selectedCards.count == SetGame.setSize {
            await commitClaim(Array(selectedCards))
        }
    }

    /// Sends a "deal three more" request. Either peer can request; host
    /// validates and broadcasts the ack. Local board updates only after the
    /// ack lands so peers stay in sync.
    func requestDealThree() async {
        guard outcome == nil else { return }
        if isHost {
            await applyDealThree()
        } else {
            await session.send(.dealThreeRequest(by: localPlayerID))
        }
    }

    /// Local player forfeits. Broadcasts a `.forfeit` and immediately ends
    /// the local match — opponent will record a win (competitive) or a
    /// matching `.coopAbandoned` (coop) when the message arrives.
    func forfeit() async {
        guard outcome == nil else { return }
        await session.send(.forfeit(by: localPlayerID))
        finish(outcome: variant == .coop ? .coopAbandoned : .forfeit)
    }

    // MARK: - Pre-game confirmation

    /// Local player taps Accept on the pre-game confirmation popup. Broadcasts
    /// the decision; if both peers have accepted, transitions to `.playing`
    /// and (host only) seeds the deck.
    func acceptMatch() async {
        guard phase == .awaitingConfirmation else { return }
        guard localConfirmation == .pending else { return }
        // Invite recipients can't send confirmation until the inviter's
        // variant has been adopted — sending Normal here would tell the
        // inviter "I picked Normal" and trip their mismatch decline.
        // The view layer hides the Accept button until adoption finishes
        // (`awaitingVariantFromPeer`), so this guard is belt-and-suspenders.
        guard !awaitingVariantFromPeer else { return }
        localConfirmation = .accepted
        await session.send(.matchConfirmation(by: localPlayerID, accepted: true, variant: variant))
        evaluateConfirmationProgress()
    }

    /// Local player taps Deny. Broadcasts the decision and ends the session
    /// without recording an outcome — declined matches don't appear in stats.
    func declineMatch() async {
        guard phase == .awaitingConfirmation else { return }
        guard localConfirmation == .pending else { return }
        localConfirmation = .declined
        await session.send(.matchConfirmation(by: localPlayerID, accepted: false, variant: variant))
        abandonMatch()
    }

    /// Either both peers have accepted (→ start playing) or one declined /
    /// timed out (→ end the session). Idempotent on repeat calls.
    private func evaluateConfirmationProgress() {
        guard phase == .awaitingConfirmation else { return }
        if localConfirmation == .declined || remoteConfirmation == .declined {
            abandonMatch()
            return
        }
        guard localConfirmation == .accepted, remoteConfirmation == .accepted else {
            return
        }
        phase = .playing
        if isHost {
            let seed = generateSeed()
            hostSeed = seed
            buildDeck(from: seed)
            Task { [session] in await session.send(.deckSeed(seed)) }
        }
    }

    /// Tears down a match that was abandoned before any gameplay. Phase goes
    /// to `.ended` with `outcome == nil` — the view layer reads that as
    /// "dismiss without recording."
    private func abandonMatch() {
        guard phase != .ended else { return }
        phase = .ended
        // Don't immediately leave the session — the parent view inspects
        // the terminal state and calls leave() during dismissal.
    }

    private func scheduleConfirmationTimeout() {
        let duration = confirmationTimeoutDuration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self else { return }
            // Timeout only counts if the local user never decided. If they
            // already accepted and we're waiting on the remote, we still
            // call it a timeout — match is over.
            if self.phase == .awaitingConfirmation {
                if self.localConfirmation == .pending {
                    self.localConfirmation = .declined
                }
                self.abandonMatch()
            }
        }
    }

    // MARK: - Rematch

    /// Local player taps Rematch. Notifies the opponent and waits up to
    /// `rematchTimeoutDuration` for them to do the same. If they had
    /// already requested before us, the match transitions immediately.
    func requestRematch() async {
        guard outcome != nil else { return }
        switch rematchState {
        case .idle:
            rematchState = .localRequested
            logger.info("Rematch: requesting from \(self.localPlayerID); session state=\(String(describing: self.session.state))")
            await session.send(.rematchRequest(by: localPlayerID))
            scheduleRematchTimeout()
        case .opponentRequested:
            rematchState = .agreed
            logger.info("Rematch: agreeing (opponent already requested); session state=\(String(describing: self.session.state))")
            await session.send(.rematchRequest(by: localPlayerID))
            await applyRematchAgreement()
        case .localRequested, .agreed, .opponentDeclined:
            // Already requested or terminal — ignore double-taps.
            break
        }
    }

    /// Local player taps Done on the game-over sheet. Sends a decline so
    /// the opponent doesn't have to wait the full 15s for our silence.
    func declineRematch() async {
        guard outcome != nil else { return }
        if rematchState != .opponentDeclined {
            rematchState = .opponentDeclined
        }
        await session.send(.rematchDecline(by: localPlayerID))
    }

    private func scheduleRematchTimeout() {
        let duration = rematchTimeoutDuration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self else { return }
            // Only flip if we're still in localRequested — agreement or an
            // explicit decline beat us to the punch.
            if self.rematchState == .localRequested {
                self.rematchState = .opponentDeclined
            }
        }
    }

    /// Both peers have agreed. Wipes per-game state and rebuilds the deck.
    /// Host generates a fresh seed and broadcasts; guest waits for it.
    private func applyRematchAgreement() async {
        resetGameState()
        if isHost {
            let seed = generateSeed()
            buildDeck(from: seed)
            await session.send(.deckSeed(seed))
        }
        // Guest's deck arrives via the normal .deckSeed path in handle().
    }

    /// Wipes everything tied to the previous match while leaving identity,
    /// session, and configuration alone. Called on rematch agreement before
    /// the host broadcasts the new seed.
    private func resetGameState() {
        outcome = nil
        winSource = nil
        rematchState = .idle
        // Rematch already required both peers to agree, so we skip a fresh
        // confirmation handshake. Phase goes directly back to .playing and
        // confirmations are auto-set to accepted to keep state consistent.
        phase = .playing
        localConfirmation = .accepted
        remoteConfirmation = .accepted
        hostScore = 0
        guestScore = 0
        hostTrios = 0
        guestTrios = 0
        hostMultiplier = 1
        guestMultiplier = 1
        hostLongestStreak = 0
        guestLongestStreak = 0
        hostFastestSetSeconds = nil
        guestFastestSetSeconds = nil
        hostLastSetAt = nil
        guestLastSetAt = nil
        hostLastResolveAt = nil
        guestLastResolveAt = nil
        selectedCards.removeAll()
        lockoutClearTask?.cancel()
        lockoutClearTask = nil
        lockoutEndsAt = nil
        opponentClaimEffect = nil
        processedClaimIDs.removeAll()
        hasReceivedDeck = false
        setGame = SetGame(mode: .versus, autoDeal: false, deckBuilder: { [] })
    }

    // MARK: - Claim flow

    private func commitClaim(_ cards: [SetCard]) async {
        let claimID = UUID()
        let wireCards = cards.map(\.wire)
        // Optimistic UI: clear local selection so the next tap is fresh.
        selectedCards.removeAll()

        if isHost {
            arbitrate(cards: cards, by: localPlayerID, claimID: claimID, claimedAt: clock())
        } else {
            await session.send(.claim(cards: wireCards, at: clock(), claimID: claimID))
        }
    }

    /// Host-only. Validates a claim and broadcasts the result. Idempotent
    /// against duplicate claimIDs so a retransmitted claim doesn't double-count.
    private func arbitrate(
        cards: [SetCard],
        by claimer: VersusPlayerID,
        claimID: UUID,
        claimedAt: Date
    ) {
        guard isHost else { return }
        guard outcome == nil else { return }
        guard !processedClaimIDs.contains(claimID) else {
            logger.info("Ignoring duplicate claim \(claimID)")
            return
        }
        processedClaimIDs.insert(claimID)

        // Validate: cards must still be on the board AND form a valid trio.
        let stillPresent = cards.allSatisfy { setGame.boardSlots.contains($0) }
        let isValidTrio = stillPresent && setGame.isSet(cards)

        if isValidTrio {
            applyValidMatch(cards: cards, by: claimer, at: claimedAt)
            broadcastClaimResult(
                winner: claimer,
                cards: cards,
                success: true,
                claimID: claimID
            )
        } else {
            broadcastClaimResult(
                winner: claimer,
                cards: cards,
                success: false,
                claimID: claimID
            )
        }
    }

    /// Applies a validated match locally — both host and guest end up here
    /// (host after self-arbitrating; guest after receiving the result). Updates
    /// per-player score, multiplier, fastest-set, longest-streak, and the
    /// authoritative board state. If the claimer is the remote player,
    /// kicks off the 1.5s opponent-claim overlay before the cards dissolve.
    private func applyValidMatch(cards: [SetCard], by claimer: VersusPlayerID, at claimedAt: Date) {
        if claimer != localPlayerID {
            triggerOpponentClaimEffect(cards: cards, by: claimer, at: claimedAt)
        }
        let explanation = explain(cards)
        let basePoints = explanation.difficultyPoints
        let isClaimerHost = (claimer == hostID)

        // Combo model:
        //   - Competitive variants: per-player ladder — claimer's multiplier
        //     extends if their *own* last set was within the combo window.
        //   - Coop: team-shared ladder — either peer claiming within the
        //     window extends the combo for both. Rewards passing trios back
        //     and forth quickly.
        let lastSetAt: Date?
        let priorMultiplier: Int
        if variant == .coop {
            lastSetAt = mostRecent(hostLastSetAt, guestLastSetAt)
            priorMultiplier = teamMultiplier
        } else {
            lastSetAt = isClaimerHost ? hostLastSetAt : guestLastSetAt
            priorMultiplier = currentMultiplier(forHost: isClaimerHost)
        }
        var multiplier: Int
        if let last = lastSetAt, claimedAt.timeIntervalSince(last) <= comboWindow {
            multiplier = min(priorMultiplier + 1, 3)
        } else {
            multiplier = 1
        }

        let pointsAwarded = basePoints * multiplier
        if isClaimerHost {
            hostScore += pointsAwarded
            hostTrios += 1
            hostMultiplier = multiplier
            hostLongestStreak = max(hostLongestStreak, multiplier)
            updateFastestSet(forHost: true, claimedAt: claimedAt)
            hostLastSetAt = claimedAt
        } else {
            guestScore += pointsAwarded
            guestTrios += 1
            guestMultiplier = multiplier
            guestLongestStreak = max(guestLongestStreak, multiplier)
            updateFastestSet(forHost: false, claimedAt: claimedAt)
            guestLastSetAt = claimedAt
        }
        // Mirror the multiplier across both peers in coop so either side's
        // UI surfaces the same shared team combo number.
        if variant == .coop {
            hostMultiplier = multiplier
            guestMultiplier = multiplier
        }

        // Board mutation flows through SetGame so refill rules match the
        // single-player path. Score on SetGame stays at 0 — VersusGame owns
        // per-player scoring above.
        setGame.applyAuthoritativeMatch(cards: cards)
        if isClaimerHost {
            hostLastResolveAt = claimedAt
        } else {
            guestLastResolveAt = claimedAt
        }

        evaluateGameOver()
    }

    private func currentMultiplier(forHost: Bool) -> Int {
        forHost ? hostMultiplier : guestMultiplier
    }

    /// Returns the later of two optional dates. Nil-aware so the call
    /// site can pass un-set timestamps (no claim yet) without branching.
    private func mostRecent(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case (let a?, let b?): return max(a, b)
        case (let a?, nil):    return a
        case (nil, let b?):    return b
        case (nil, nil):       return nil
        }
    }

    private func triggerOpponentClaimEffect(cards: [SetCard], by claimer: VersusPlayerID, at claimedAt: Date) {
        opponentClaimEffect = OpponentClaimEffectState(
            cards: cards,
            claimedBy: claimer,
            startedAt: claimedAt
        )
        let id = opponentClaimEffect?.startedAt
        let duration = opponentClaimEffectDuration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            // Only clear if still the same effect — avoid clobbering a fresh
            // claim that landed during the sleep.
            if self?.opponentClaimEffect?.startedAt == id {
                self?.opponentClaimEffect = nil
            }
        }
    }

    /// Clears `lockoutEndsAt` once the window expires so the view layer's
    /// `isLockedOut`-driven dimming and progress bar fall away. Without this
    /// the @Observable view never re-evaluates the time-based computed
    /// property and stays stuck in the locked-out visual state.
    private func scheduleLockoutClear(expiry: Date) {
        lockoutClearTask?.cancel()
        lockoutClearTask = Task { @MainActor [weak self] in
            let interval = expiry.timeIntervalSinceNow
            if interval > 0 {
                try? await Task.sleep(for: .seconds(interval))
            }
            guard !Task.isCancelled else { return }
            // Only clear if this is still the same lockout — a new failed
            // claim landing during the sleep extends the window.
            guard self?.lockoutEndsAt == expiry else { return }
            self?.lockoutEndsAt = nil
        }
    }

    private func updateFastestSet(forHost: Bool, claimedAt: Date) {
        let lastResolve = forHost ? hostLastResolveAt : guestLastResolveAt
        guard let last = lastResolve else {
            // First trio of the session — no "previous resolve" to time from.
            return
        }
        let solveTime = claimedAt.timeIntervalSince(last)
        guard solveTime > 0 else { return }
        if forHost {
            hostFastestSetSeconds = min(hostFastestSetSeconds ?? solveTime, solveTime)
        } else {
            guestFastestSetSeconds = min(guestFastestSetSeconds ?? solveTime, solveTime)
        }
    }

    private func broadcastClaimResult(
        winner: VersusPlayerID,
        cards: [SetCard],
        success: Bool,
        claimID: UUID
    ) {
        let result = VersusMessage.claimResult(
            winner: winner,
            cards: cards.map(\.wire),
            success: success,
            hostScore: hostScore,
            guestScore: guestScore,
            hostTrios: hostTrios,
            guestTrios: guestTrios,
            claimID: claimID
        )
        Task { [session] in await session.send(result) }
        // Host also processes the result locally so its lockout / observer
        // logic mirrors the guest's path.
        handleClaimResult(
            winner: winner,
            cards: cards,
            success: success,
            hostScore: hostScore,
            guestScore: guestScore,
            hostTrios: hostTrios,
            guestTrios: guestTrios,
            claimID: claimID,
            wasJustAppliedLocally: success
        )
    }

    /// Both peers funnel through here when a claim result arrives. `wasJustAppliedLocally`
    /// is true when the host has already mutated state in `applyValidMatch` —
    /// the guest path needs to apply the mutation now from the wire payload.
    private func handleClaimResult(
        winner: VersusPlayerID,
        cards: [SetCard],
        success: Bool,
        hostScore: Int,
        guestScore: Int,
        hostTrios: Int,
        guestTrios: Int,
        claimID: UUID,
        wasJustAppliedLocally: Bool
    ) {
        if success {
            if !wasJustAppliedLocally {
                // Guest path: apply the authoritative mutation now.
                applyValidMatch(cards: cards, by: winner, at: clock())
                // Reconcile against host's authoritative scores in case our
                // local computation drifted (clock skew, missed message).
                self.hostScore = hostScore
                self.guestScore = guestScore
                self.hostTrios = hostTrios
                self.guestTrios = guestTrios
            }
        } else if winner == localPlayerID {
            // Local player's claim was rejected — start the lockout window.
            // Reset local combo since the chain broke. In coop, the team's
            // combo is shared, so resetting one peer's multiplier resets
            // the other's too.
            let expiry = clock().addingTimeInterval(lockoutDuration)
            lockoutEndsAt = expiry
            scheduleLockoutClear(expiry: expiry)
            if variant == .coop {
                hostMultiplier = 1
                guestMultiplier = 1
            } else if isHost {
                hostMultiplier = 1
            } else {
                guestMultiplier = 1
            }
        } else {
            // Opponent's claim was rejected — reset their combo to match
            // the single-player invalidation rule. In coop, the shared
            // team combo resets regardless of who claimed.
            if variant == .coop {
                hostMultiplier = 1
                guestMultiplier = 1
            } else if winner == hostID {
                hostMultiplier = 1
            } else {
                guestMultiplier = 1
            }
        }
    }

    // MARK: - Deal three

    private func applyDealThree() async {
        guard isHost else { return }
        guard !setGame.hasSetOnBoard, !setGame.deck.isEmpty else { return }
        let drawn = setGame.appendCardsFromDeck(count: SetGame.setSize)
        guard !drawn.isEmpty else { return }
        await session.send(.dealThreeAck(newCards: drawn.map(\.wire)))
        evaluateGameOver()
    }

    private func handleDealThreeAck(newCards: [WireCard]) {
        guard !isHost else { return }
        // Guest mirror: the host already validated. Take the next N cards
        // off the local seeded deck so card identities stay consistent with
        // SetGame's internal deck cursor (peers are seeded identically).
        _ = setGame.appendCardsFromDeck(count: newCards.count)
        evaluateGameOver()
    }

    // MARK: - Game over

    private func evaluateGameOver() {
        guard outcome == nil else { return }

        // First-to-N: end the moment either player crosses the threshold,
        // even with cards still in the deck. Tie is impossible because
        // claims are sequential (host arbitrates one at a time). Tests
        // can supply a lower override to skip simulating 10 claims.
        if let threshold = trioWinThresholdOverride ?? variant.trioWinThreshold {
            if localTrios >= threshold {
                finish(outcome: .win)
                return
            }
            if remoteTrios >= threshold {
                finish(outcome: .loss)
                return
            }

            // Mercy rule: if the trailing player can't reach the threshold
            // even by claiming every remaining card in play, the leader
            // has won mathematically — no point dragging the deck out.
            // Conservative cap: floor((board + undealt) / 3) is the
            // absolute max additional trios anyone could claim, ignoring
            // whether those cards actually form sets. That makes the
            // mercy strict (won't trigger early on a marginal lead).
            let maxRemainingTrios = (setGame.boardSlots.count + setGame.deck.count) / SetGame.setSize
            if localTrios > remoteTrios, remoteTrios + maxRemainingTrios < threshold {
                finish(outcome: .win)
                return
            }
            if remoteTrios > localTrios, localTrios + maxRemainingTrios < threshold {
                finish(outcome: .loss)
                return
            }
        }

        // Natural end-of-deck condition.
        guard setGame.isGameOver else { return }

        if variant.isCompetitive {
            finish(outcome: computeNaturalOutcome())
        } else {
            // Coop: both peers record the same completion outcome, no
            // winner/loser, no winSource.
            finish(outcome: .coopCompleted)
        }
    }

    /// Final outcome at the end of the deck for a competitive variant.
    /// Spec: higher score wins, tied score breaks on trio count, both
    /// ties → draw. Coop runs don't go through this — they end with
    /// `.coopCompleted` regardless of per-player numbers.
    private func computeNaturalOutcome() -> VersusOutcome {
        if localScore > remoteScore { return .win }
        if localScore < remoteScore { return .loss }
        if localTrios > remoteTrios { return .win }
        if localTrios < remoteTrios { return .loss }
        return .draw
    }

    private func finish(outcome: VersusOutcome, winSource: VersusWinSource? = nil) {
        guard self.outcome == nil else { return }
        self.outcome = outcome
        if outcome == .win {
            // Default to score-final when a win lands without a more specific
            // source — natural deck-clear endings flow through here.
            self.winSource = winSource ?? .scoreFinal
        }
        phase = .ended
        // Don't tear down the session immediately — the view layer wants to
        // present the game-over sheet first. Caller leaves explicitly.
    }

    // MARK: - Pumps

    private func pumpMessages() async {
        for await message in session.incoming {
            await handle(message)
        }
    }

    private func handle(_ message: VersusMessage) async {
        // Once the match has ended, only post-game coordination messages are
        // legal. A late-arriving claim or dealThree from a flaky network
        // shouldn't be processed — gameplay state is frozen.
        if outcome != nil {
            switch message {
            case .rematchRequest, .rematchDecline, .forfeit, .heartbeat:
                break // valid post-game; fall through
            default:
                logger.info("Dropping post-outcome message: \(String(describing: message))")
                return
            }
        }

        // Pre-game (awaitingConfirmation): only confirmation, forfeit, and
        // heartbeat are legal. Defensive guard against a peer that sends
        // gameplay messages before both have accepted.
        if phase == .awaitingConfirmation {
            switch message {
            case .matchConfirmation, .forfeit, .heartbeat:
                break // valid pre-game; fall through
            default:
                logger.info("Dropping pre-confirmation message: \(String(describing: message))")
                return
            }
        }

        switch message {
        case .deckSeed(let seed):
            guard !isHost, !hasReceivedDeck else { return }
            buildDeck(from: seed)

        case .claim(let cards, let at, let claimID):
            // Host-only path: arbitrate guest's claim. Resolve wire cards to
            // local SetCard instances by attribute matching.
            guard isHost else { return }
            let resolved = cards.compactMap { $0.resolve(in: setGame.boardSlots) }
            guard resolved.count == cards.count else {
                // One or more cards have already been removed — automatic
                // invalid claim (race lost).
                broadcastClaimResult(
                    winner: remotePlayerID,
                    cards: [],
                    success: false,
                    claimID: claimID
                )
                return
            }
            arbitrate(cards: resolved, by: remotePlayerID, claimID: claimID, claimedAt: at)

        case .claimResult(let winner, let cards, let success, let hScore, let gScore, let hTrios, let gTrios, let claimID):
            // Guest path: apply the host's authoritative result. Host already
            // applied it locally inside arbitrate().
            guard !isHost else { return }
            let resolved = cards.compactMap { $0.resolve(in: setGame.boardSlots) }
            handleClaimResult(
                winner: winner,
                cards: resolved,
                success: success,
                hostScore: hScore,
                guestScore: gScore,
                hostTrios: hTrios,
                guestTrios: gTrios,
                claimID: claimID,
                wasJustAppliedLocally: false
            )

        case .dealThreeRequest:
            await applyDealThree()

        case .dealThreeAck(let newCards):
            handleDealThreeAck(newCards: newCards)

        case .forfeit:
            // Opponent forfeited.
            //   - Competitive: local player records a win.
            //   - Coop: both peers record `.coopAbandoned` — no winner.
            // `finish` is internally guarded but make the intent explicit
            // in case our own forfeit raced theirs.
            if outcome == nil {
                if variant == .coop {
                    finish(outcome: .coopAbandoned)
                } else {
                    finish(outcome: .win, winSource: .opponentForfeited)
                }
            }

        case .rematchRequest:
            await handleRematchRequest()

        case .rematchDecline:
            handleRematchDecline()

        case .matchConfirmation(_, let accepted, let remoteVariant):
            guard phase == .awaitingConfirmation else { return }
            if awaitingVariantFromPeer {
                // First confirmation from the inviter — adopt their
                // variant so the popup we're about to show says the
                // right mode. After this, the normal mismatch-decline
                // logic resumes (catches a misbehaving peer that flips
                // variants mid-handshake).
                logger.info("Adopting variant from peer: \(remoteVariant.rawValue)")
                variant = remoteVariant
                awaitingVariantFromPeer = false
            } else if remoteVariant != variant {
                // Mismatch with no adoption pending — both sides chose
                // explicitly and disagree. Decline cleanly.
                logger.error("Variant mismatch in matchConfirmation: local=\(self.variant.rawValue) remote=\(remoteVariant.rawValue) — declining")
                remoteConfirmation = .declined
                evaluateConfirmationProgress()
                return
            }
            remoteConfirmation = accepted ? .accepted : .declined
            evaluateConfirmationProgress()

        case .heartbeat:
            // MatchSession filters these out; defensive no-op.
            break
        }
    }

    private func handleRematchRequest() async {
        logger.info("Rematch: received request from peer; outcome=\(String(describing: self.outcome)) state=\(String(describing: self.rematchState))")
        guard outcome != nil else { return }
        switch rematchState {
        case .idle:
            rematchState = .opponentRequested
        case .localRequested:
            rematchState = .agreed
            await applyRematchAgreement()
        case .opponentRequested, .agreed, .opponentDeclined:
            break
        }
    }

    private func handleRematchDecline() {
        guard outcome != nil else { return }
        // Either we were waiting for them and now know they bailed, or they
        // declined before we asked. Either way, terminal.
        if rematchState != .agreed {
            rematchState = .opponentDeclined
        }
    }

    private func observeSessionState() async {
        // MatchSession.state is @Observable; track changes via a small poll
        // loop. Polling here is fine — state transitions are rare and the
        // 200ms interval is cheap.
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                return
            }
            switch session.state {
            case .disconnected(let reason):
                if outcome == nil {
                    let result = outcomeForDisconnect(reason: reason)
                    finish(outcome: result.outcome, winSource: result.winSource)
                } else if rematchState != .opponentDeclined && rematchState != .agreed {
                    // Game already ended naturally; the session has now died
                    // (peer left, watchdog timeout, transport failure). A
                    // rematch can't reach the opponent over a dead transport,
                    // so surface that immediately rather than letting the UI
                    // sit at "Waiting…" for the full 15s.
                    rematchState = .opponentDeclined
                }
                return
            default:
                continue
            }
        }
    }

    private var isRematchPending: Bool {
        rematchState == .localRequested || rematchState == .opponentRequested
    }

    private func outcomeForDisconnect(reason: MatchSessionState.DisconnectReason) -> (outcome: VersusOutcome, winSource: VersusWinSource?) {
        // Coop has no winner concept — every disconnect/transport failure
        // resolves to `.coopAbandoned` so neither peer's stats inflate.
        if variant == .coop {
            return (.coopAbandoned, nil)
        }

        switch reason {
        case .localDisconnect:
            // Local user explicitly left (e.g. forfeit() already set outcome,
            // or app shutdown). Treat as forfeit if we got here without one.
            return (.forfeit, nil)
        case .peerLeft, .peerSilent:
            // Opponent disappeared — credit local with a win.
            return (.win, .opponentDisconnected)
        case .transportFailure:
            // Couldn't keep talking to anyone — call it a draw and let stats
            // reflect "neither side completed."
            return (.draw, nil)
        }
    }

    // MARK: - Helpers

    private func buildDeck(from seed: UInt64) {
        hostSeed = seed
        let deck = SetGame.seededStandardDeck(seed: seed)
        setGame.deck = deck
        // Both peers deal the initial board off the top of the seeded deck
        // synchronously; the view layer's deal animation can re-render
        // incrementally without the cards mismatching across peers.
        let initial = setGame.appendCardsFromDeck(count: SetGame.boardSize)
        _ = initial
        hasReceivedDeck = true
    }

    private func generateSeed() -> UInt64 {
        var rng = SystemRandomNumberGenerator()
        return rng.next()
    }
}
