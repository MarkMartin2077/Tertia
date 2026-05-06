//
//  VersusGridArea.swift
//  Tertia
//
//  Shared board grid used by `VersusGameView`. Same layout shape as the
//  single-player grid — fixed column count, dynamic row count keyed off
//  `boardSlots` so the grid grows/shrinks with Deal 3.
//

import SwiftUI

struct VersusGridArea: View {
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
