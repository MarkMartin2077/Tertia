//
//  GameView.swift
//  Tertia
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(HighScoreStore.self) private var highScoreStore
    @Environment(DailyStore.self) private var dailyStore
    @Environment(FeedbackService.self) private var feedback

    @State private var showNewGameConfirm = false
    @State private var showNoHintAlert = false
    @State private var showGameOver = false
    @State private var showExitConfirm = false
    @State private var wasNewBest = false
    @State private var taskTrigger = 0
    @State private var pulseToken = 0
    @State private var hasDealtInitialBoard = false
    @State private var dealOverlayPulse = false
    @State private var didFireTimerWarning = false
    @State private var hasHandledExpiry = false

    // Practice slow-glow hint
    @State private var lastInteractionTime: Date = .now
    @State private var hintedCards: Set<SetCard> = []
    @State private var haloPulseToken: Int = 0

    // Time bonus toast
    @State private var bonusToastSeconds: Int? = nil
    @State private var bonusToastID: Int = 0

    // Points toast — fires on every scoring trio, anchored right of the score chip.
    @State private var pointsToastValue: Int? = nil
    @State private var pointsToastID: Int = 0

    /// Seconds of inactivity before the practice halo offers a hint.
    private let practiceHintDelay: TimeInterval = 25

    /// Calendar day the active daily puzzle was generated for. Used to guard
    /// against day-rollover crediting (user opens before midnight, completes
    /// after — the puzzle is still yesterday's, so the completion shouldn't
    /// be recorded as today's).
    private let puzzleDate: Date

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

        let puzzleDate = Date.now
        self.puzzleDate = puzzleDate

        let deckBuilder: () -> [SetCard]
        if mode == .daily {
            deckBuilder = { DailyPuzzle.deck(for: puzzleDate) }
        } else {
            deckBuilder = SetGame.standardDeck
        }

        self._game = State(initialValue: SetGame(mode: mode, autoDeal: false, deckBuilder: deckBuilder))
        self._controller = State(initialValue: mode.usesTimer ? TimeAttackController() : nil)
    }

    private var shouldShowPracticeVerdict: Bool {
        mode == .practice && game.selectedCards.count == SetGame.setSize
    }

    private var shouldShowDealThreeOverlay: Bool {
        hasDealtInitialBoard
            && !game.hasSetOnBoard
            && !game.isGameOver
            && game.selectedCards.isEmpty
            && game.canDealThree
    }

    private var currentFailingAttributes: Set<CardAttribute> {
        guard mode == .practice, game.hasInvalidSelection else { return [] }
        return Set(explain(Array(game.selectedCards)).failingAttributes)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerRow
                gridArea
                    .overlay {
                        if shouldShowDealThreeOverlay {
                            dealThreeOverlay
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.78), value: shouldShowDealThreeOverlay)
            }
            .boardBackground()
            .opacity(showGameOver ? 0.5 : 1.0)
            .blur(radius: showGameOver ? 2 : 0)
            .animation(.default, value: showGameOver)
            .tint(mode.accentColor)
            .safeAreaInset(edge: .bottom) {
                if shouldShowPracticeVerdict {
                    let selected = Array(game.selectedCards)
                    PracticeVerdictBar(
                        cards: selected,
                        explanation: explain(selected),
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
            .alert("No trios on the board", isPresented: $showNoHintAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Tap Deal 3 to add more cards.")
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
                guard isOver, !mode.usesTimer else { return }
                if mode == .daily,
                   Calendar.current.isDateInToday(puzzleDate) {
                    dailyStore.recordCompletion(score: game.score)
                }
                showGameOver = true
            }
            .onChange(of: game.score) { oldValue, newValue in
                guard newValue > oldValue else { return }
                feedback.validSet()
                pointsToastValue = newValue - oldValue
                pointsToastID += 1
                if mode.awardsTimeBonus, let controller {
                    let added = controller.addTime(controller.perSetBonus)
                    if added > 0 {
                        bonusToastSeconds = Int(added)
                        bonusToastID += 1
                    }
                }
            }
            .onChange(of: game.boardSlots) { _, _ in
                // The board changed (Deal 3, refill, etc.) — clear any stale halo.
                if !hintedCards.isEmpty { hintedCards = [] }
            }
            .onChange(of: game.hasInvalidSelection) { _, isInvalid in
                if isInvalid {
                    feedback.invalidSet()
                    if mode == .practice { pulseToken += 1 }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                handleScenePhase(phase)
            }
            .task(id: taskTrigger) {
                if !hasDealtInitialBoard {
                    await runDealAnimation()
                    if game.boardSlots.count >= SetGame.boardSize {
                        hasDealtInitialBoard = true
                        // Only start the timer if the scene is active. If the
                        // user backgrounded mid-deal, handleScenePhase(.active)
                        // will start it on resume — avoids a one-tick leak.
                        if mode.usesTimer,
                           let controller,
                           !controller.hasStarted,
                           scenePhase == .active {
                            controller.start()
                        }
                    }
                }
                async let timer: Void = runTimerWatcher()
                async let hint: Void = runHintWatcher()
                _ = await (timer, hint)
            }
            .sheet(isPresented: $showGameOver) { gameOverSheet }
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            scoreChip
                .overlay(alignment: .trailing) {
                    PointsToast(value: $pointsToastValue, id: pointsToastID)
                        .alignmentGuide(.trailing) { d in d[.leading] - 8 }
                }
            Spacer()

            if mode.usesTimer, let controller {
                TimerLabel(controller: controller)
                    .overlay(alignment: .leading) {
                        // Anchor toast just to the left of the timer — its
                        // trailing edge sits 8pt before the timer's leading.
                        bonusToast
                            .alignmentGuide(.leading) { d in d[.trailing] + 8 }
                    }
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

    private var scoreChip: some View {
        let comboActive = game.multiplier > 1
        return HStack(spacing: 6) {
            Text("Score: \(game.score)")
                .font(.largeTitle.bold())
                .contentTransition(.numericText())
            if comboActive {
                Text("×\(game.multiplier)")
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.18), in: .capsule)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: game.multiplier)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score \(game.score)")
        .accessibilityValue(comboActive ? "Combo multiplier ×\(game.multiplier)" : "")
    }

    @ViewBuilder
    private var bonusToast: some View {
        if let seconds = bonusToastSeconds {
            Text("+\(seconds)s")
                .font(.headline.bold())
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.18), in: .capsule)
                .id(bonusToastID)
                .transition(reduceMotion
                    ? .opacity
                    : .move(edge: .trailing).combined(with: .opacity))
                .accessibilityLabel("Plus \(seconds) seconds bonus")
                .task(id: bonusToastID) {
                    try? await Task.sleep(for: .milliseconds(900))
                    withAnimation(.easeOut(duration: 0.3)) {
                        bonusToastSeconds = nil
                    }
                }
        }
    }

    private var dealThreeOverlay: some View {
        Button {
            Task { await runDealThreeAnimation() }
        } label: {
            HStack(spacing: 16) {
                fannedCardsIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEAL 3")
                        .font(.title2.weight(.heavy))
                        .tracking(2)
                    Text("No trio on this board")
                        .font(.caption.weight(.medium))
                        .opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(mode.accentColor.gradient)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: mode.accentColor.opacity(0.35), radius: 14, y: 6)
            .scaleEffect(dealOverlayPulse ? 1.04 : 1.0)
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 1.1).repeatCount(3, autoreverses: true),
                value: dealOverlayPulse
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            guard !reduceMotion else { return }
            dealOverlayPulse = true
        }
        .onDisappear { dealOverlayPulse = false }
        .accessibilityLabel("Deal three more cards")
        .accessibilityHint("No trio is on the board. Tap to add three more cards.")
    }

    private var fannedCardsIcon: some View {
        ZStack {
            miniCard(symbol: "circle.fill", tint: .red)
                .rotationEffect(.degrees(-14))
                .offset(x: -16, y: 4)
            miniCard(symbol: "square.fill", tint: .green)
                .offset(x: 0, y: -2)
            miniCard(symbol: "triangle.fill", tint: .blue)
                .rotationEffect(.degrees(14))
                .offset(x: 16, y: 4)
        }
        .frame(width: 72, height: 56)
    }

    private func miniCard(symbol: String, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(.white)
            .frame(width: 30, height: 42)
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
            }
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
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
                    let inInvalidTrio = game.hasInvalidSelection && game.selectedCards.contains(card)
                    SetCardView(
                        card: card,
                        isSelected: game.selectedCards.contains(card),
                        isInvalid: inInvalidTrio,
                        pulsingAttributes: inInvalidTrio ? currentFailingAttributes : [],
                        pulseToken: pulseToken,
                        isHaloed: hintedCards.contains(card),
                        haloPulseToken: haloPulseToken
                    ) {
                        feedback.cardTap()
                        lastInteractionTime = .now
                        if !hintedCards.isEmpty { hintedCards = [] }
                        game.select(card)
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
        .overlay { boardEdgeGlow.allowsHitTesting(false) }
    }

    private var boardEdgeGlow: some View {
        let active = game.multiplier >= 2
        return RoundedRectangle(cornerRadius: 24)
            .strokeBorder(Color.orange.opacity(active ? 0.35 : 0), lineWidth: 3)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .blur(radius: 4)
            .animation(.easeInOut(duration: 0.4), value: game.multiplier)
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

    /// Stranded count is meaningful only for natural game-over (deck empty,
    /// no trio remaining). Timer-driven endings leave plenty of cards on the
    /// board but they aren't "stranded" in the cap-set sense, so suppress.
    private var strandedCardCount: Int? {
        mode.usesTimer ? nil : game.boardSlots.count
    }

    @ViewBuilder
    private var gameOverSheet: some View {
        if mode == .daily {
            DailyGameOverSheet(
                date: .now,
                score: game.score,
                streak: dailyStore.displayedStreak,
                fastestSetSeconds: game.fastestSetSeconds,
                longestStreak: game.longestStreak >= 2 ? game.longestStreak : nil,
                strandedCardCount: strandedCardCount,
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
                fastestSetSeconds: game.fastestSetSeconds,
                longestStreak: game.longestStreak >= 2 ? game.longestStreak : nil,
                strandedCardCount: strandedCardCount,
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
        hasDealtInitialBoard = false
        didFireTimerWarning = false
        hasHandledExpiry = false
        taskTrigger += 1
    }

    private func runDealThreeAnimation() async {
        guard game.canDealThree else { return }
        feedback.dealDeck()
        let dealInterval: Duration = .milliseconds(110)
        for i in 0..<SetGame.setSize {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                _ = game.dealOne()
            }
            if i < SetGame.setSize - 1 {
                do {
                    try await Task.sleep(for: dealInterval)
                } catch {
                    return
                }
            }
        }
    }

    private func runDealAnimation() async {
        let needed = min(
            SetGame.boardSize - game.boardSlots.count,
            game.deck.count
        )
        guard needed > 0 else { return }

        feedback.dealDeck()
        let dealInterval: Duration = .milliseconds(40)
        for _ in 0..<needed {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
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
            // If the user backgrounded mid-deal, the .task block skipped the
            // initial start() — kick it off now that we're foregrounded.
            if hasDealtInitialBoard, !controller.hasStarted {
                controller.start()
            } else {
                controller.resume()
            }
        case .background, .inactive:
            controller.pause()
        @unknown default:
            break
        }
    }

    private func handleTimerExpiry() {
        guard let controller else { return }
        guard !hasHandledExpiry else { return }
        hasHandledExpiry = true
        let finalScore = game.score
        let duration = Int(controller.totalDuration)

        switch mode {
        case .daily:
            // Only credit the streak if the puzzle's day still matches today.
            // Guards against opening before midnight and finishing after.
            if Calendar.current.isDateInToday(puzzleDate) {
                dailyStore.recordCompletion(score: finalScore)
            }
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
        // Contract: callers must ensure the controller has started. The .task
        // in `body` does this after the deal animation completes; if the scene
        // was inactive at that moment, handleScenePhase(.active) starts it on
        // resume. If we get here without a started controller, the watcher is
        // a no-op and a foreground transition will trigger a new task.
        assert(
            controller.hasStarted || scenePhase != .active,
            "runTimerWatcher reached while active but controller never started"
        )
        guard controller.hasStarted else { return }
        while !controller.isFinished {
            if !didFireTimerWarning && controller.remaining <= 10 && !controller.isPaused {
                didFireTimerWarning = true
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

    /// Practice-only: after the configured idle delay, surface two cards from
    /// any valid trio as a passive halo. Re-checks every second and dismisses
    /// itself when the user taps anything (handled in the card-tap closure)
    /// or the board changes (`onChange(of: game.boardSlots)`).
    private func runHintWatcher() async {
        guard mode == .practice else { return }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            guard hintedCards.isEmpty else { continue }
            guard !game.hasInvalidSelection else { continue }
            guard game.selectedCards.isEmpty else { continue }
            guard game.isGameOver == false else { continue }
            let elapsed = Date.now.timeIntervalSince(lastInteractionTime)
            guard elapsed >= practiceHintDelay else { continue }
            if let trio = game.findSetOnBoard() {
                hintedCards = Set(trio.prefix(2))
                haloPulseToken += 1
            }
        }
    }
}

#Preview {
    GameView(mode: .daily, onExit: {})
        .environment(HighScoreStore())
        .environment(DailyStore())
        .environment(FeedbackService())
}

private struct PointsToast: View {
    @Binding var value: Int?
    let id: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        if let value {
            Text("+\(value)")
                .font(.title3.bold())
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.18), in: .capsule)
                .id(id)
                .transition(reduceMotion
                    ? .opacity
                    : .move(edge: .leading).combined(with: .opacity))
                .accessibilityLabel("Plus \(value) points")
                .task(id: id) {
                    try? await Task.sleep(for: .milliseconds(900))
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.value = nil
                    }
                }
        }
    }
}
