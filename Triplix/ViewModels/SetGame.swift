//
//  SetGame.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

@Observable
class SetGame {
    static let boardSize = 18
    static let setSize = 3

    var boardSlots: [SetCard?] = Array(repeating: nil, count: SetGame.boardSize)
    var deck = [SetCard]()
    var selectedCards = Set<SetCard>()
    var score = 0

    var hasInvalidSelection: Bool {
        selectedCards.count == SetGame.setSize && !isSet(Array(selectedCards))
    }

    init() {
        createBoard()
    }

    private func drawCards(count: Int) -> [SetCard] {
        let drawnCards = Array(deck.prefix(count))
        deck.removeFirst(drawnCards.count)
        return drawnCards
    }

    private func createBoard() {
        deck = CardShape.allCases.flatMap { shape in
            CardCount.allCases.flatMap { count in
                CardColor.allCases.flatMap { color in
                    CardFill.allCases.map { fill in
                        SetCard(shape: shape, count: count, color: color, fill: fill)
                    }
                }
            }
        }.shuffled()

        let openingCards = drawCards(count: boardSlots.count)

        for (index, card) in openingCards.enumerated() {
            boardSlots[index] = card
        }
    }

    func newGame() {
        withAnimation {
            selectedCards.removeAll()
            score = 0
            boardSlots = Array(repeating: nil, count: SetGame.boardSize)
            createBoard()
        }
    }

    func select(_ card: SetCard) {
        guard boardSlots.contains(card) else { return }

        if selectedCards.contains(card) {
            selectedCards.remove(card)
            return
        }

        if selectedCards.count == SetGame.setSize {
            selectedCards.removeAll()
        }

        selectedCards.insert(card)

        guard isSet(Array(selectedCards)) else { return }

        score += 1
        resolveMatchedCards(matching: selectedCards)
    }

    private func allSameOrAllDifferent<Value: Hashable>(_ values: [Value]) -> Bool {
        let uniqueValueCount = Set(values).count
        return uniqueValueCount == 1 || uniqueValueCount == SetGame.setSize
    }

    func isSet(_ cards: [SetCard]) -> Bool {
        guard cards.count == SetGame.setSize else { return false }

        return allSameOrAllDifferent(cards.map(\.shape))
            && allSameOrAllDifferent(cards.map(\.count))
            && allSameOrAllDifferent(cards.map(\.color))
            && allSameOrAllDifferent(cards.map(\.fill))
    }

    private func resolveMatchedCards(matching matchedCards: Set<SetCard>) {
        let matchedIndices = boardSlots.indices.filter { index in
            guard let card = boardSlots[index] else { return false }
            return matchedCards.contains(card)
        }
        let replacementCards = drawCards(count: matchedIndices.count)
        withAnimation {
            selectedCards.removeAll()

            // Remove the matched cards
            for index in matchedIndices {
                boardSlots[index] = nil
            }

            // Fill in new ones where possible
            for (index, card) in zip(matchedIndices, replacementCards) {
                boardSlots[index] = card
            }
        }
    }

    @discardableResult
    func showHint() -> Bool {
        guard let foundSet = findSetOnBoard() else { return false }
        withAnimation {
            selectedCards = Set(foundSet.prefix(2))
        }
        return true
    }

    private func findSetOnBoard() -> [SetCard]? {
        let cards = boardSlots.compactMap(\.self)

        for firstIndex in cards.indices.shuffled() {
            for secondIndex in (firstIndex + 1)..<cards.endIndex {
                for thirdIndex in (secondIndex + 1)..<cards.endIndex {
                    let possibleSet = [
                        cards[firstIndex],
                        cards[secondIndex],
                        cards[thirdIndex]
                    ]

                    if isSet(possibleSet) {
                        return possibleSet
                    }
                }
            }
        }

        return nil
    }
}
