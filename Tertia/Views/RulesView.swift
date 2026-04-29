//
//  RulesView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct RulesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section(
                    title: "The Cards",
                    body: "Each card has four attributes: shape, count, color, and fill. There are 81 unique cards in the deck — every combination of values appears exactly once."
                )

                section(
                    title: "What is a Set?",
                    body: "Three cards form a set if, for each of the four attributes, the values are either **all the same** or **all different** across the three cards."
                )

                VStack(alignment: .leading, spacing: 16) {
                    Text("These ARE Sets")
                        .font(.headline)
                    ExampleTrioView(
                        cards: ExampleData.allSameSet,
                        isSet: true,
                        explanation: "All four attributes are the same."
                    )
                    ExampleTrioView(
                        cards: ExampleData.allDifferentSet,
                        isSet: true,
                        explanation: "Every attribute is different."
                    )
                    ExampleTrioView(
                        cards: ExampleData.mixedSet,
                        isSet: true,
                        explanation: "Different shapes and counts; same color and fill."
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Not Sets")
                        .font(.headline)
                    ExampleTrioView(
                        cards: ExampleData.mixedFillNonSet,
                        isSet: false,
                        explanation: "Two filled, one empty — fill is mixed."
                    )
                    ExampleTrioView(
                        cards: ExampleData.mixedColorNonSet,
                        isSet: false,
                        explanation: "Two reds, one green — color is mixed."
                    )
                }

                section(
                    title: "Playing",
                    body: "Tap three cards to select them. If they form a set, you score a point and the cards are replaced. If not, the cards flash red — tap a fourth card to start over."
                )

                section(
                    title: "Tools",
                    body: "**Hint** pre-selects two cards from a valid set on the board.\n\n**Deal 3** adds three more cards when no set is visible. The board grows from 12 to 15, 18, then 21 — at 21 a set is mathematically guaranteed.\n\n**New Game** reshuffles the deck."
                )

                section(
                    title: "Game Over",
                    body: "The game ends when the deck is empty and no sets remain on the board. Your final score is the number of sets you found."
                )
            }
            .padding()
        }
        .navigationTitle("How to Play")
    }

    @ViewBuilder
    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(.init(body))
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        RulesView()
    }
}
