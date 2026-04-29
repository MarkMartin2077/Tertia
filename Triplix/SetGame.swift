//
//  SetGame.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

@Observable
class SetGame {
    var boardSlots: [SetCard?] = Array(repeating: nil, count: 18)
    var deck = [SetCard]()
    var selectedCards = Set<SetCard>()
    var score = 0

    init() {
        createBoard()
    }
    
    func drawCards(count: Int) -> [SetCard] {
        let drawnCards = Array(deck.prefix(count))
        deck.removeFirst(drawnCards.count)
        return drawnCards
    }
    
    func createBoard() {
        var newDeck = [SetCard]()
        //TODO: Refactor with flatMap calls
        for shape in CardShape.allCases {
            for count in CardCount.allCases {
                for color in CardColor.allCases {
                    for fill in CardFill.allCases {
                        newDeck.append(
                            SetCard(
                                shape: shape,
                                count: count,
                                color: color,
                                fill: fill
                            )
                        )
                    }
                }
            }
        }
        
        deck = newDeck.shuffled()
        
        let openingCards = drawCards(count: boardSlots.count)

        for (index, card) in openingCards.enumerated() {
            boardSlots[index] = card
        }

    }
    
    func select(_ card: SetCard) {
        guard boardSlots.contains(card) else { return }

        if selectedCards.contains(card) {
            selectedCards.remove(card)
            return
        }

        if selectedCards.count == 3 {
            selectedCards.removeAll()
        }

        selectedCards.insert(card)
        
        guard isSet(Array(selectedCards)) else { return }

        score += 1
        resolveMatchedCards(matching: selectedCards)
    }
    
    func allSameOrAllDifferent<Value: Hashable>(_ values: [Value]) -> Bool {
        let uniqueValueCount = Set(values).count
        return uniqueValueCount == 1 || uniqueValueCount == 3
    }
    
    func isSet(_ cards: [SetCard]) -> Bool {
        guard cards.count == 3 else { return false }

        return allSameOrAllDifferent(cards.map(\.shape))
            && allSameOrAllDifferent(cards.map(\.count))
            && allSameOrAllDifferent(cards.map(\.color))
            && allSameOrAllDifferent(cards.map(\.fill))
    }
    
    func resolveMatchedCards(matching matchedCards: Set<SetCard?>) {
        let matchedIndices = boardSlots.indices.filter { index in
            matchedCards.contains(boardSlots[index])
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
    
    func showHint() {
        selectedCards = Set(findSetOnBoard().prefix(2))
    }
    
    func findSetOnBoard() -> [SetCard] {
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

        return []
    }
}
