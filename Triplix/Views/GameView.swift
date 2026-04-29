//
//  GameView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct GameView: View {
    let mode: GameMode
    let onExit: () -> Void

    @State private var game: SetGame
    @State private var controller: TimeAttackController?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(HighScoreStore.self) private var highScoreStore
    @Environment(DailyStore.self) private var dailyStore
    @Environment(FeedbackService.self) private var feedback

    @State private var showNewGameConfirm = false
    @State private var showNoHintAlert = false
    @State private var showGameOver = false
    @State private var showExitConfirm = false
    @State private var wasNewBest = false
    @State private var taskTrigger = 0

    let columnCount = 3
    let cardSpacing = 6.0
    var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: cardSpacing),
            count: columnCount
        )
    }

    init(mode: GameMode = .normal, onExit: @escaping () -> Void = {}) {
        self.mode = mode
        self.onExit = onExit

        let deckBuilder: () -> [SetCard]
        if mode == .daily {
            deckBuilder = { DailyPuzzle.deck(for: .now) }
        } else {
            deckBuilder = SetGame.standardDeck
        }

        self._game = State(initialValue: SetGame(mode: mode, autoDeal: false, deckBuilder: deckBuilder))
        self._controller = State(initialValue: mode.usesTimer ? TimeAttackController() : nil)
    }

    private var shouldShowPracticeVerdict: Bool {
        mode == .practice && game.selectedCards.count == SetGame.setSize
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerRow
                gridArea
            }
            .opacity(showGameOver ? 0.5 : 1.0)
            .blur(radius: showGameOver ? 2 : 0)
            .animation(.default, value: showGameOver)
            .tint(mode.accentColor)
            .safeAreaInset(edge: .bottom) {
                if shouldShowPracticeVerdict {
                    PracticeVerdictBar(
                        explanation: explain(Array(game.selectedCards)),
                        onDismiss: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                game.acknowledgeSelection()
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: shouldShowPracticeVerdict)
            .toolbar { toolbarContent }
            .alert("No sets on the board", isPresented: $showNoHintAlert) {
                Button("OK", role: .cancel) {}
            }
            .confirmationDialog(
                "Start a new game?",
                isPresented: $showNewGameConfirm,
                titleVisibility: .visible
            ) {
                Button("New Game", role: .destructive) {
                    startNewGame()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Leave this game?",
                isPresented: $showExitConfirm,
                titleVisibility: .visible
            ) {
                Button("Leave", role: .destructive) {
                    onExit()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current score will be lost.")
            }
            .onChange(of: game.isGameOver) { _, isOver in
                if isOver && !mode.usesTimer { showGameOver = true }
            }
            .onChange(of: game.score) { oldValue, newValue in
                if newValue > oldValue { feedback.validSet() }
            }
            .onChange(of: game.hasInvalidSelection) { _, isInvalid in
                if isInvalid { feedback.invalidSet() }
            }
            .onChange(of: scenePhase) { _, phase in
                handleScenePhase(phase)
            }
            .task(id: taskTrigger) {
                await runDealAnimation()
                if mode.usesTimer, let controller {
                    controller.start()
                    if scenePhase != .active {
                        controller.pause()
                    }
                }
                await runTimerWatcher()
            }
            .sheet(isPresented: $showGameOver) { gameOverSheet }
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Score: \(game.score)")
                .font(.largeTitle.bold())
            Spacer()

            if mode.usesTimer, let controller {
                TimerLabel(controller: controller)
            } else {
                Label("\(game.deck.count)", systemImage: "rectangle.stack")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Deck")
                    .accessibilityValue("\(game.deck.count) cards remaining")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var gridArea: some View {
        GeometryReader { geometry in
            // Floor at boardSize/columnCount so cells don't resize during the
            // deal animation (when boardSlots.count < boardSize).
            let baseRows = SetGame.boardSize / columnCount
            let actualRows = Int(ceil(Double(game.boardSlots.count) / Double(columnCount)))
            let rows = max(baseRows, actualRows)
            let totalSpacing = CGFloat(rows - 1) * cardSpacing
            let cellHeight = max(0, (geometry.size.height - totalSpacing) / CGFloat(rows))

            LazyVGrid(columns: columns, spacing: cardSpacing) {
                ForEach(game.boardSlots) { card in
                    SetCardView(
                        card: card,
                        isSelected: game.selectedCards.contains(card),
                        isInvalid: game.hasInvalidSelection && game.selectedCards.contains(card)
                    ) {
                        feedback.cardTap()
                        game.select(card)
                    }
                    .frame(height: cellHeight)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 24)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Modes", systemImage: "chevron.backward") {
                if game.score > 0 {
                    showExitConfirm = true
                } else {
                    onExit()
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if mode != .daily {
                Button("New Game", systemImage: "arrow.clockwise") {
                    if game.score > 0 {
                        showNewGameConfirm = true
                    } else {
                        startNewGame()
                    }
                }
            }
            if mode.allowsDealThree {
                Button("Deal 3", systemImage: "plus.rectangle.on.rectangle") {
                    game.dealThreeMore()
                }
                .disabled(!game.canDealThree)
                .accessibilityHint(game.canDealThree ? "" : "Find the visible set first")
            }
            if mode.allowsHint {
                Button("Hint", systemImage: "lightbulb") {
                    feedback.hintTap()
                    if !game.showHint() {
                        showNoHintAlert = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var gameOverSheet: some View {
        if mode == .daily {
            DailyGameOverSheet(
                date: .now,
                score: game.score,
                streak: dailyStore.displayedStreak,
                onChangeMode: {
                    showGameOver = false
                    onExit()
                }
            )
            .presentationDetents([.medium])
        } else {
            GameOverSheet(
                mode: mode,
                score: game.score,
                bestScore: highScoreStore.bestScore(forDuration: Int(controller?.totalDuration ?? 0)),
                isNewBest: wasNewBest,
                onPlayAgain: {
                    showGameOver = false
                    startNewGame()
                },
                onChangeMode: {
                    showGameOver = false
                    onExit()
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Actions

    private func startNewGame() {
        game.clearBoard()
        if mode.usesTimer {
            controller = TimeAttackController()
        }
        wasNewBest = false
        taskTrigger += 1
    }

    private func runDealAnimation() async {
        feedback.dealDeck()
        let dealInterval: Duration = .milliseconds(70)
        for _ in 0..<SetGame.boardSize {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                _ = game.dealOne()
            }
            do {
                try await Task.sleep(for: dealInterval)
            } catch {
                return
            }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        guard mode.usesTimer, let controller else { return }
        switch phase {
        case .active:
            controller.resume()
        case .background, .inactive:
            controller.pause()
        @unknown default:
            break
        }
    }

    private func handleTimerExpiry() {
        guard let controller else { return }
        let finalScore = game.score
        let duration = Int(controller.totalDuration)

        switch mode {
        case .daily:
            dailyStore.recordCompletion(score: finalScore)
        case .timeAttack:
            let priorBest = highScoreStore.bestScore(forDuration: duration) ?? 0
            wasNewBest = finalScore > priorBest && finalScore > 0
            highScoreStore.record(score: finalScore, durationSeconds: duration)
        default:
            break
        }

        if mode == .timeAttack && wasNewBest {
            feedback.personalBest()
        } else {
            feedback.timerExpired()
        }
        showGameOver = true
    }

    private func runTimerWatcher() async {
        guard mode.usesTimer, let controller else { return }
        var firedTenSecondWarning = false
        while !controller.isFinished {
            if !firedTenSecondWarning && controller.remaining <= 10 && !controller.isPaused {
                firedTenSecondWarning = true
                feedback.timerWarning()
            }
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                return
            }
        }
        if !Task.isCancelled {
            handleTimerExpiry()
        }
    }
}

#Preview {
    GameView(mode: .daily, onExit: {})
        .environment(HighScoreStore())
        .environment(DailyStore())
        .environment(FeedbackService())
}
