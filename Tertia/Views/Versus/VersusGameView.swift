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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showForfeitConfirm = false
    @State private var showGameOver = false

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
                    if shouldShowDealThreeOverlay {
                        VersusDealThreeOverlay {
                            Task { await game.requestDealThree() }
                        }
                    } else if !game.hasReceivedDeck {
                        VersusConnectingOverlay(opponentName: game.remoteDisplayName)
                    }
                }
            }
            .boardBackground()
            .opacity(showGameOver ? 0.5 : 1.0)
            .blur(radius: showGameOver ? 2 : 0)
            .animation(.default, value: showGameOver)
            .tint(GameMode.versus.accentColor)
            .toolbar { toolbarContent }
            .overlay(alignment: .bottom) {
                if let endsAt = game.lockoutEndsAt, game.isLockedOut {
                    LockoutProgressBar(endsAt: endsAt, totalDuration: 1.5)
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
            .overlay {
                if let effect = game.opponentClaimEffect {
                    OpponentClaimEffect(
                        effect: effect,
                        opponentName: game.remoteDisplayName,
                        accentColor: GameMode.versus.accentColor
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
            .onChange(of: scenePhase) { _, phase in
                // Per VERSUS_PLAN.md: backgrounding is treated as a forfeit.
                // Only fire if the match is still live — outcome already set
                // means we're about to dismiss anyway.
                guard phase == .background, game.outcome == nil else { return }
                Task { await game.forfeit() }
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
        }
    }

    /// Persists a `VersusMatchRecord` for the just-finished match. Called
    /// once per outcome transition (nil → non-nil); rematch resets outcome
    /// back to nil before the next match's transition fires, so we naturally
    /// only record terminal results.
    private func recordCompletedMatch(outcome: VersusOutcome) {
        let record = VersusMatchRecord(
            date: .now,
            opponentDisplayName: game.remoteDisplayName,
            yourScore: game.localScore,
            opponentScore: game.remoteScore,
            yourTrios: game.localTrios,
            opponentTrios: game.remoteTrios,
            outcome: outcome
        )
        versusStore.record(record)
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
            Button("Forfeit", systemImage: "flag.fill") {
                showForfeitConfirm = true
            }
            .tint(.red)
            .disabled(game.outcome != nil)
        }
    }
}

// MARK: - Header

private struct VersusHeaderRow: View {
    let game: VersusGame

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VersusScoreChip(
                name: game.localDisplayName,
                score: game.localScore,
                trios: game.localTrios,
                multiplier: game.localMultiplier,
                scoreTint: GameMode.versus.accentColor,
                alignment: .leading
            )
            VersusScoreChip(
                name: game.remoteDisplayName,
                score: game.remoteScore,
                trios: game.remoteTrios,
                multiplier: game.remoteMultiplier,
                scoreTint: .primary,
                alignment: .trailing
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

private struct VersusScoreChip: View {
    let name: String
    let score: Int
    let trios: Int
    let multiplier: Int
    /// Color applied to the score number — accent for the local player so
    /// they can locate themselves at a glance, neutral for the opponent.
    let scoreTint: Color
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            HStack(spacing: 6) {
                Text("\(score)")
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(scoreTint)
                    .contentTransition(.numericText())
                if multiplier > 1 {
                    Text("×\(multiplier)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18), in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: multiplier)
            Text("^[\(trios) trio](inflect: true)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(score) points")
    }
}

// MARK: - Grid

private struct VersusGridArea: View {
    let game: VersusGame
    let columns: [GridItem]
    let cardSpacing: CGFloat
    let columnCount: Int

    @Environment(FeedbackService.self) private var feedback

    var body: some View {
        GeometryReader { geometry in
            let baseRows = SetGame.boardSize / columnCount
            let actualRows = Int(ceil(Double(game.setGame.boardSlots.count) / Double(columnCount)))
            let rows = max(baseRows, actualRows)
            let totalSpacing = CGFloat(rows - 1) * cardSpacing
            let cellHeight = max(0, (geometry.size.height - totalSpacing) / CGFloat(rows))

            LazyVGrid(columns: columns, spacing: cardSpacing) {
                ForEach(game.setGame.boardSlots) { card in
                    SetCardView(
                        card: card,
                        isSelected: game.selectedCards.contains(card),
                        isInvalid: false,
                        pulsingAttributes: [],
                        pulseToken: 0,
                        isHaloed: false,
                        haloPulseToken: 0
                    ) {
                        feedback.cardTap()
                        Task { await game.toggleSelection(card) }
                    }
                    .frame(height: cellHeight)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 24)
    }
}

// MARK: - Deal 3 overlay

private struct VersusDealThreeOverlay: View {
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEAL 3")
                        .font(.title3.weight(.heavy))
                        .tracking(2)
                    Text("No trio on the board")
                        .font(.caption.weight(.medium))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(GameMode.versus.accentColor.gradient, in: .rect(cornerRadius: 18))
            .shadow(color: GameMode.versus.accentColor.opacity(0.35), radius: 14, y: 6)
            .scaleEffect(pulse ? 1.04 : 1.0)
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 1.1).repeatCount(3, autoreverses: true),
                value: pulse
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
        }
        .onDisappear { pulse = false }
        .accessibilityLabel("Deal three more cards")
    }
}

// MARK: - Connecting overlay (guest waiting on host's deck seed)

private struct VersusConnectingOverlay: View {
    let opponentName: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting to \(opponentName)…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to \(opponentName)")
    }
}
