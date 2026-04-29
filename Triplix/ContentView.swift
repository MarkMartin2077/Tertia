//
//  ContentView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct ContentView: View {
    @State private var game = SetGame()
    let columnCount = 3
    let rowCount = 6
    let cardSpacing = 6.0
    var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: cardSpacing),
            count: columnCount
        )
    }
    var body: some View {
        NavigationStack {
            LazyVGrid(columns: columns, spacing: cardSpacing) {
                ForEach(game.boardSlots.indices, id: \.self) { index in
                    Group {
                        if let card = game.boardSlots[index] {
                            SetCardView(
                                card: card,
                                isSelected: game.selectedCards.contains(card)

                            ) {
                                game.select(card)
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .containerRelativeFrame(.horizontal, count: columnCount, spacing: 30)
                    .containerRelativeFrame(.vertical, count: rowCount, spacing: cardSpacing)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .navigationTitle("Score: \(game.score)")
            .toolbar {
                Button("Hint", systemImage: "lightbulb", action: game.showHint)
            }

        }
    }
}

#Preview {
    ContentView()
}
