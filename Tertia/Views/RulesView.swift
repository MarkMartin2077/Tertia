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
                    title: "What is a Trio?",
                    body: "Three cards form a trio if, for each of the four attributes, the values are either **all the same** or **all different** across the three cards.\n\n**Each attribute is checked independently.** A trio can be all-same on color, all-different on shape, all-same on count, and all-different on fill — and still be valid."
                )

                VStack(alignment: .leading, spacing: 16) {
                    Text("These ARE Trios")
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
                        explanation: "All-same color and fill, all-different shape and count. Per-attribute independence in action."
                    )
                }

                commonMistakeCallout

                VStack(alignment: .leading, spacing: 16) {
                    Text("Not Trios")
                        .font(.headline)
                    ExampleTrioView(
                        cards: ExampleData.mixedFillNonSet,
                        isSet: false,
                        explanation: "Two filled, one empty. Fill is two-and-one."
                    )
                    ExampleTrioView(
                        cards: ExampleData.mixedColorNonSet,
                        isSet: false,
                        explanation: "Two red, one green. Color is two-and-one."
                    )
                }

                section(
                    title: "Playing",
                    body: "Tap three cards to select them. If they form a trio, you score a point and the cards are replaced. If not, the cards flash red — tap a fourth card to start over."
                )

                section(
                    title: "Tools",
                    body: "**Hint** pre-selects two cards from a valid trio on the board.\n\n**Deal 3** adds three more cards when no trio is visible. The board grows from 12 to 15, 18, then 21 — at 21 a trio is mathematically guaranteed.\n\n**New Game** reshuffles the deck."
                )

                section(
                    title: "Game Over",
                    body: "The game ends when the deck is empty and no trios remain on the board. Your final score is the number of trios you found."
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

    private var commonMistakeCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 8) {
                Text("Common Mistake")
                    .font(.headline.weight(.semibold))
                Text(.init("If you can sort the three cards into **\"two of one, one of another\"** on any attribute, it's not a trio.\n\nThis is the trap beginners fall into: two reds and a green, two filled and an empty, two circles and a square. The rule needs *all same* or *all different* — never two-and-one."))
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.yellow.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        RulesView()
    }
}
