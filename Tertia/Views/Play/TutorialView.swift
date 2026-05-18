//
//  TutorialView.swift
//  Tertia
//
//  Created by Mark Martin on 5/17/26.
//

import SwiftUI

struct TutorialView: View {
    /// `nextMode` is non-nil only when the user tapped "Play Normal" from
    /// the completion sheet, so the coordinator can immediately launch a
    /// fresh game of that mode.
    let onExit: (_ completedNaturally: Bool, _ nextMode: GameMode?) -> Void

    @State private var controller = TutorialController()
    @State private var showSkipConfirmation = false
    @State private var showCapstoneTitleCard = false
    @State private var pulseToken = 0
    @Environment(FeedbackService.self) private var feedback

    private let cardSpacing: CGFloat = 8

    var body: some View {
        NavigationStack {
            ZStack {
                boardLayer
                    .opacity(showCapstoneTitleCard ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: showCapstoneTitleCard)

                if showCapstoneTitleCard {
                    CapstoneTitleCard(onContinue: {
                        withAnimation(.easeIn(duration: 0.35)) {
                            showCapstoneTitleCard = false
                        }
                    })
                    .transition(.opacity)
                }

                if let celebration = controller.celebration {
                    celebrationLayer(celebration)
                        .transition(.opacity)
                }

                // Verdict card overlays the bottom of the board via an
                // explicit bottom-aligned VStack so the rest of the ZStack
                // children (capstone intro, celebrations) still center by
                // default. The board behind never resizes — eliminates the
                // animation snap when the panel appears and lets the
                // capstone use GameView-style sizing.
                if let verdict = controller.verdict {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        TutorialVerdictCard(
                            cards: controller.selectedCards,
                            explanation: verdict,
                            onDismiss: { handleVerdictDismiss(verdict: verdict) }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .boardBackground()
            .toolbar { toolbarContent }
            .toolbarTitleDisplayMode(.inline)
            .navigationTitle("")
            // iOS 26's floating toolbar buttons don't reserve content space.
            // Make the bar visible so the hint banner below it doesn't
            // overlap the leading skip button or the principal progress label.
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .confirmationDialog(
                "Skip tutorial?",
                isPresented: $showSkipConfirmation,
                titleVisibility: .visible
            ) {
                Button("Skip") { controller.skip() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("You can replay it from Settings anytime.")
            }
            .sheet(isPresented: completionSheetBinding) {
                TutorialCompletionSheet(
                    onPlayNormal: { onExit(true, .normal) },
                    onBackToMenu: { onExit(true, nil) }
                )
                .interactiveDismissDisabled()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                // Opaque background so the still-falling capstone confetti
                // doesn't bleed through and wash out the secondary button.
                .presentationBackground(Color(.systemBackground))
            }
            .onChange(of: controller.isComplete) { _, isDone in
                // Skip path bypasses the completion sheet — exit immediately.
                if isDone && !controller.finishedNaturally {
                    onExit(false, nil)
                }
            }
            .onChange(of: controller.currentIndex) { _, newIndex in
                if newIndex == TutorialPuzzles.count - 1 {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showCapstoneTitleCard = true
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: controller.verdict != nil)
            .animation(.easeInOut(duration: 0.25), value: controller.celebration)
            .tint(GameMode.tutorial.accentColor)
        }
    }

    // MARK: - Board

    private var boardLayer: some View {
        VStack(spacing: 16) {
            hintBanner
            gridArea
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var hintBanner: some View {
        if let hint = controller.hint {
            Text(LocalizedStringKey(hint))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(GameMode.tutorial.accentColor.opacity(0.35), lineWidth: 1.5)
                }
                .frame(maxWidth: maxGridWidth)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .id(controller.currentIndex)
                .transition(.opacity)
        }
    }

    /// Two layout modes:
    /// - Capstone (12 cards): dynamic GameView-style sizing — cards fill
    ///   the available space, like Normal/Practice mode. Feels like the
    ///   real game.
    /// - Small puzzles (4/6/8): fixed 3:4 aspect with per-puzzle max width
    ///   capped so cards don't stretch and look elongated.
    @ViewBuilder
    private var gridArea: some View {
        if controller.isCapstone {
            dynamicGrid
        } else {
            fixedSizeGrid
        }
    }

    /// Capstone-style grid: cards fill available space. Same approach as
    /// `GameView.gridArea` so the capstone visually matches Normal mode.
    private var dynamicGrid: some View {
        GeometryReader { geometry in
            let cards = controller.displayedCards
            let columns = columnCount(for: cards.count)
            let rows = Int(ceil(Double(cards.count) / Double(columns)))
            let totalRowSpacing = CGFloat(rows - 1) * cardSpacing
            let cellHeight = max(0, (geometry.size.height - totalRowSpacing) / CGFloat(rows))
            let gridColumns = Array(
                repeating: GridItem(.flexible(), spacing: cardSpacing),
                count: columns
            )

            LazyVGrid(columns: gridColumns, spacing: cardSpacing) {
                ForEach(cards) { card in
                    let isSelected = controller.selectedIds.contains(card.id)
                    let isInvalid = isInvalidSelection(card: card)
                    SetCardView(
                        card: card,
                        isSelected: isSelected,
                        isInvalid: isInvalid,
                        pulsingAttributes: pulsingAttributes(for: card),
                        pulseToken: pulseToken
                    ) {
                        handleTap(card)
                    }
                    .frame(height: cellHeight)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 24)
    }

    /// Small-puzzle grid: fixed card aspect ratio + per-puzzle max width
    /// keeps 4/6/8 card layouts from stretching cards into long rectangles
    /// when they only need a fraction of the available vertical space.
    private var fixedSizeGrid: some View {
        let cards = controller.displayedCards
        let columns = columnCount(for: cards.count)
        let gridColumns = Array(
            repeating: GridItem(.flexible(maximum: maxCardWidth(for: cards.count)),
                                spacing: cardSpacing),
            count: columns
        )

        return LazyVGrid(columns: gridColumns, spacing: cardSpacing) {
            ForEach(cards) { card in
                let isSelected = controller.selectedIds.contains(card.id)
                let isInvalid = isInvalidSelection(card: card)
                SetCardView(
                    card: card,
                    isSelected: isSelected,
                    isInvalid: isInvalid,
                    pulsingAttributes: pulsingAttributes(for: card),
                    pulseToken: pulseToken
                ) {
                    handleTap(card)
                }
                .aspectRatio(cardAspectRatio, contentMode: .fit)
            }
        }
        .frame(maxWidth: maxGridWidth)
        .padding(.horizontal, 20)
    }

    // MARK: - Sizing constants

    private let maxGridWidth: CGFloat = 380
    private let cardAspectRatio: CGFloat = 3.0 / 4.0

    /// Per-card-count max card width for small puzzles (4/6/8).
    /// Tuned to keep cards looking like cards, not stretched rectangles.
    /// Capstone uses dynamic sizing instead — see `dynamicGrid`.
    private func maxCardWidth(for cardCount: Int) -> CGFloat {
        switch cardCount {
        case 4: return 140    // 2 cols × 2 rows
        case 6: return 110    // 3 cols × 2 rows
        case 8: return 85     // 4 cols × 2 rows
        default: return 100
        }
    }

    // MARK: - Celebration

    @ViewBuilder
    private func celebrationLayer(_ level: CelebrationLevel) -> some View {
        switch level {
        case .small:
            VStack {
                Spacer()
                CelebrationOverlay(level: level)
                    .padding(.bottom, 140)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        case .medium:
            // No overlay — pulse + haptic carry it.
            EmptyView()
        case .capstone:
            CelebrationOverlay(level: level)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showSkipConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel("Skip tutorial")
        }
        ToolbarItem(placement: .principal) {
            if controller.isCapstone {
                Text("The Real Deal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(GameMode.tutorial.accentColor)
            } else {
                Text(controller.progressText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Helpers

    private var completionSheetBinding: Binding<Bool> {
        Binding(
            get: { controller.isComplete && controller.finishedNaturally },
            set: { _ in }
        )
    }

    private func columnCount(for cardCount: Int) -> Int {
        switch cardCount {
        case 4: return 2
        case 6: return 3
        case 8: return 4
        case 12: return 3
        default: return 3
        }
    }

    private func handleTap(_ card: SetCard) {
        guard !controller.isVerdictShowing else { return }
        feedback.cardTap()
        controller.select(card)
    }

    private func handleVerdictDismiss(verdict: SetExplanation) {
        if verdict.isSet {
            feedback.validSet()
        } else {
            feedback.invalidSet()
        }

        let isCapstoneWin = verdict.isSet && controller.isCapstone

        if isCapstoneWin {
            // Hold so the confetti has a moment to land before the completion
            // sheet slides up and visually swallows it.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    controller.dismissVerdict()
                }
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                controller.dismissVerdict()
            }
        }
    }

    /// Tutorial deliberately suppresses red invalid-card borders. The
    /// PracticeVerdictBar already explains what's wrong attribute-by-attribute
    /// — we don't need the cards to also yell at the learner. Cards stay
    /// neutral-selected (yellow) so the verdict bar carries the entire
    /// teaching moment.
    private func isInvalidSelection(card: SetCard) -> Bool {
        false
    }

    private func pulsingAttributes(for card: SetCard) -> Set<CardAttribute> {
        guard let verdict = controller.verdict,
              !verdict.isSet,
              controller.selectedIds.contains(card.id) else {
            return []
        }
        return Set(verdict.failingAttributes)
    }

}

#Preview {
    TutorialView(onExit: { _, _ in })
        .environment(FeedbackService())
}
