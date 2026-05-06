//
//  VersusGameView.swift
//  Tertia
//
//  Real-time 1-on-1 versus screen. Adapts the single-player GameView layout:
//  two score chips at the top, shared board grid in the middle, lockout
//  progress at the bottom while locked out, opponent-claim overlay above
//  the board for 1.5s after the opponent grabs a trio.
//
//  Forfeit button replaces the Modes / New Game toolbar items — quitting
//  the match has explicit semantics in versus.
//

import SwiftUI

struct VersusGameView: View {
    @Bindable var game: VersusGame
    let onExit: () -> Void
    let onFindNewMatch: () -> Void

    init(
        game: VersusGame,
        onExit: @escaping () -> Void,
        onFindNewMatch: @escaping () -> Void = {}
    ) {
        self.game = game
        self.onExit = onExit
        self.onFindNewMatch = onFindNewMatch
    }

    @Environment(FeedbackService.self) private var feedback
    @Environment(VersusStore.self) private var versusStore
    @Environment(VersusBestsStore.self) private var versusBestsStore
    @Environment(GameCenterService.self) private var gameCenter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showForfeitConfirm = false
    @State private var showGameOver = false
    /// Whether the captioned lockout bar has appeared yet this match. Used
    /// to switch to the compact dial after the first explanation.
    @State private var hasShownLockoutCaption = false
    /// Pending background-grace timer. Set when scenePhase goes to
    /// .background; cancelled if the user returns within the grace window
    /// or fires `game.forfeit()` if they don't. Phone calls, notification
    /// taps, and accidental swipes all benefit from this delay.
    @State private var backgroundForfeitTask: Task<Void, Never>?

    /// How long the user can be backgrounded before we record a forfeit.
    /// Mirrors `MatchSession.disconnectGrace` so the local-side grace and
    /// the peer-side watchdog land at roughly the same moment.
    private let backgroundForfeitGrace: Duration = .seconds(20)

    private let columnCount = 3
    private let cardSpacing: CGFloat = 6

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: cardSpacing), count: columnCount)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VersusHeaderRow(game: game)
                VersusGridArea(
                    game: game,
                    columns: columns,
                    cardSpacing: cardSpacing,
                    columnCount: columnCount
                )
                .overlay {
                    if game.phase == .awaitingConfirmation {
                        MatchConfirmationView(
                            opponentName: game.remoteDisplayName,
                            variant: game.variant,
                            localDecision: game.localConfirmation,
                            remoteDecision: game.remoteConfirmation,
                            onAccept: { Task { await game.acceptMatch() } },
                            onDecline: { Task { await game.declineMatch() } }
                        )
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else if shouldShowDealThreeOverlay {
                        VersusDealThreeOverlay(
                            onTap: { Task { await game.requestDealThree() } },
                            accent: game.variant.accent
                        )
                    } else if !game.hasReceivedDeck {
                        VersusConnectingOverlay(opponentName: game.remoteDisplayName)
                    }
                }
            }
            .boardBackground()
            .opacity(showGameOver ? 0.5 : 1.0)
            .blur(radius: showGameOver ? 2 : 0)
            // Subtle desaturation while locked out — pairs with the captioned
            // bar to make "you can't tap right now" unmistakable, without
            // hiding the board outright (you may want to plan your next claim).
            .saturation(game.isLockedOut ? 0.5 : 1.0)
            .opacity(game.isLockedOut ? 0.85 : 1.0)
            .animation(.default, value: showGameOver)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: game.phase)
            .animation(.easeInOut(duration: 0.25), value: game.isLockedOut)
            .tint(game.variant.accent)
            .toolbar { toolbarContent }
            .overlay(alignment: .bottom) {
                if let endsAt = game.lockoutEndsAt, game.isLockedOut {
                    LockoutProgressBar(
                        endsAt: endsAt,
                        totalDuration: 1.5,
                        showsCaption: !hasShownLockoutCaption
                    )
                    .padding(.bottom, 24)
                    .transition(.opacity)
                    .onAppear {
                        // Show the explanation card the first time per match;
                        // subsequent lockouts get the compact dial since the
                        // player already understands what's happening.
                        hasShownLockoutCaption = true
                    }
                }
            }
            .overlay {
                if let effect = game.opponentClaimEffect {
                    OpponentClaimEffect(
                        effect: effect,
                        opponentName: game.remoteDisplayName,
                        accentColor: game.variant.accent
                    )
                    .allowsHitTesting(false)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.isLockedOut)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.opponentClaimEffect)
            .confirmationDialog(
                "Forfeit this match?",
                isPresented: $showForfeitConfirm,
                titleVisibility: .visible
            ) {
                Button("Forfeit", role: .destructive) {
                    Task { await game.forfeit() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your opponent will be credited with the win.")
            }
            .onChange(of: game.outcome) { _, newValue in
                // Outcome non-nil means the match just ended → present sheet.
                // Outcome flips back to nil when both peers agree to rematch
                // and `applyRematchAgreement` resets state — dismiss so play
                // continues seamlessly.
                showGameOver = (newValue != nil)
                if let outcome = newValue {
                    recordCompletedMatch(outcome: outcome)
                }
            }
            .onChange(of: game.phase) { _, newPhase in
                // Match abandoned at the confirmation popup ends with phase
                // .ended but no outcome — nothing to record, just bail back
                // to mode select.
                guard newPhase == .ended, game.outcome == nil else { return }
                game.leave()
                onExit()
            }
            .onChange(of: scenePhase) { _, phase in
                handleScenePhaseChange(phase)
            }
            .sheet(isPresented: $showGameOver) {
                VersusGameOverSheet(
                    game: game,
                    onDone: {
                        showGameOver = false
                        game.leave()
                        onExit()
                    },
                    onFindNewMatch: {
                        showGameOver = false
                        game.leave()
                        onFindNewMatch()
                    }
                )
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled()
            }
            .task {
                await game.start()
            }
            .onAppear {
                // Keep the screen on for the duration of the match. iOS's
                // aggressive Wi-Fi power save during screen dim/sleep was
                // causing GameKit's UDP traffic to drop, manifesting as
                // mid-match disconnects when both players were on Wi-Fi.
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    /// Persists a `VersusMatchRecord` for the just-finished match. Called
    /// once per outcome transition (nil → non-nil); rematch resets outcome
    /// back to nil before the next match's transition fires, so we naturally
    /// only record terminal results.
    ///
    /// Also folds the match into all-time `VersusBests` and submits the
    /// relevant Game Center leaderboards. Both are fire-and-forget — a
    /// failure to update bests or submit a score must never disrupt the
    /// player's game-over flow.
    private func recordCompletedMatch(outcome: VersusOutcome) {
        let record = VersusMatchRecord(
            date: .now,
            opponentDisplayName: game.remoteDisplayName,
            yourScore: game.localScore,
            opponentScore: game.remoteScore,
            yourTrios: game.localTrios,
            opponentTrios: game.remoteTrios,
            outcome: outcome,
            variant: game.variant
        )
        versusStore.record(record)
        versusBestsStore.record(
            outcome: outcome,
            localFastestSetSeconds: game.localFastestSetSeconds,
            localLongestStreak: game.localLongestStreak
        )
        submitLeaderboards(for: outcome)
    }

    /// Handles all scenePhase transitions for an active versus match.
    /// Backgrounding during gameplay no longer records an immediate forfeit
    /// — phone calls, notification taps, and accidental swipes deserve a
    /// grace window. If the user returns within `backgroundForfeitGrace`
    /// the timer is cancelled. Pre-game confirmation backgrounding is still
    /// an immediate decline (no skin in the game yet).
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard game.outcome == nil else { return }

        switch phase {
        case .background:
            if game.phase == .awaitingConfirmation {
                // Pre-game has nothing to risk; declining immediately frees
                // the opponent without making them wait the full grace.
                Task { await game.declineMatch() }
                return
            }
            backgroundForfeitTask?.cancel()
            let grace = backgroundForfeitGrace
            backgroundForfeitTask = Task { @MainActor in
                try? await Task.sleep(for: grace)
                guard !Task.isCancelled else { return }
                guard game.outcome == nil else { return }
                await game.forfeit()
            }
        case .active:
            // User returned within the grace window — cancel the pending forfeit.
            backgroundForfeitTask?.cancel()
            backgroundForfeitTask = nil
        case .inactive:
            // Transient state (control center, notification banner). Don't
            // start the grace clock for these; .background is the real signal.
            break
        @unknown default:
            break
        }
    }

    /// Pushes Versus stats to Game Center. App Store Connect must declare
    /// the leaderboard IDs (see `LeaderboardID.versus*`) before submissions
    /// take effect; until they do, GameKit logs an error and we silently
    /// continue.
    private func submitLeaderboards(for outcome: VersusOutcome) {
        let bests = versusBestsStore.bests
        Task {
            // Wins ladder updates only when the local player actually won —
            // submitting on every match would still be best-score-correct
            // but spams GameKit unnecessarily.
            if outcome == .win {
                await gameCenter.submitVersusWins(versusStore.winCount)
            }
            if let fastest = bests.fastestSetSeconds {
                await gameCenter.submitVersusFastestSet(seconds: fastest)
            }
            if bests.longestCombo > 0 {
                await gameCenter.submitVersusLongestCombo(bests.longestCombo)
            }
        }
    }

    private var shouldShowDealThreeOverlay: Bool {
        guard game.outcome == nil else { return false }
        guard game.hasReceivedDeck else { return false }
        return !game.setGame.hasSetOnBoard
            && !game.setGame.deck.isEmpty
            && game.selectedCards.isEmpty
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            // Hide during pre-game confirmation — the popup's Decline button
            // owns the "back out" semantic in that state.
            if game.phase != .awaitingConfirmation {
                Button("Forfeit", systemImage: "flag.fill") {
                    showForfeitConfirm = true
                }
                .tint(.red)
                .disabled(game.outcome != nil)
            }
        }
    }
}
