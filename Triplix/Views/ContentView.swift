//
//  ContentView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct ContentView: View {
    @State private var game = SetGame()
    @State private var showNewGameConfirm = false
    @State private var showNoHintAlert = false

    let columnCount = 3
    var rowCount: Int { SetGame.boardSize / columnCount }
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
                                isSelected: game.selectedCards.contains(card),
                                isInvalid: game.hasInvalidSelection && game.selectedCards.contains(card)
                            ) {
                                game.select(card)
                            }
                            .id(card.id)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            Color.clear
                        }
                    }
                    .containerRelativeFrame(.horizontal, count: columnCount, spacing: 30)
                    .containerRelativeFrame(.vertical, count: rowCount, spacing: cardSpacing)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .navigationTitle("Score: \(game.score)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.stack")
                        Text("\(game.deck.count)")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Deck")
                    .accessibilityValue("\(game.deck.count) cards remaining")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Hint", systemImage: "lightbulb") {
                        if !game.showHint() {
                            showNoHintAlert = true
                        }
                    }
                    Button("New Game", systemImage: "arrow.clockwise") {
                        if game.score > 0 {
                            showNewGameConfirm = true
                        } else {
                            game.newGame()
                        }
                    }
                }
            }
            .alert("No sets on the board", isPresented: $showNoHintAlert) {
                Button("OK", role: .cancel) {}
            }
            .confirmationDialog(
                "Start a new game?",
                isPresented: $showNewGameConfirm,
                titleVisibility: .visible
            ) {
                Button("New Game", role: .destructive) {
                    game.newGame()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    ContentView()
}
