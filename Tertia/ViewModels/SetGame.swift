//
//  SetGame.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

@Observable
class SetGame {
    static let boardSize = 12
    static let setSize = 3
    static let maxBoardSize = 21

    let mode: GameMode
    private let deckBuilder: () -> [SetCard]

    var boardSlots: [SetCard] = []
    var deck = [SetCard]()
    var selectedCards = Set<SetCard>()
    var score = 0

    var hasInvalidSelection: Bool {
        selectedCards.count == SetGame.setSize && !isSet(Array(selectedCards))
    }

    var canDealThree: Bool {
        !deck.isEmpty
            && boardSlots.count < SetGame.maxBoardSize
            && !boardContainsSet()
    }

    var isGameOver: Bool {
        deck.isEmpty && !boardContainsSet()
    }

    var canShowHint: Bool {
        mode.allowsHint
    }

    /// Practice mode keeps the matched trio visible until the player acknowledges
    /// the verdict bar; other modes resolve and refill immediately.
    var autoResolvesMatch: Bool {
        mode != .practice
    }

    init(
        mode: GameMode = .normal,
        autoDeal: Bool = true,
        deckBuilder: @escaping () -> [SetCard] = SetGame.standardDeck
    ) {
        self.mode = mode
        self.deckBuilder = deckBuilder
        if autoDeal {
            createBoard()
        } else {
            deck = deckBuilder()
        }
    }

    /// Default deck: all 81 unique cards, shuffled.
    nonisolated static func standardDeck() -> [SetCard] {
        CardShape.allCases.flatMap { shape in
            CardCount.allCases.flatMap { count in
                CardColor.allCases.flatMap { color in
                    CardFill.allCases.map { fill in
                        SetCard(shape: shape, count: count, color: color, fill: fill)
                    }
                }
            }
        }.shuffled()
    }

    private func drawCards(count: Int) -> [SetCard] {
        let drawnCards = Array(deck.prefix(count))
        deck.removeFirst(drawnCards.count)
        return drawnCards
    }

    private func createBoard() {
        deck = deckBuilder()
        boardSlots = drawCards(count: SetGame.boardSize)
    }

    func newGame() {
        withAnimation {
            selectedCards.removeAll()
            score = 0
            createBoard()
        }
    }

    /// Resets state without dealing cards. Use with `dealOne()` to drive an
    /// animated deal from the view layer.
    func clearBoard() {
        selectedCards.removeAll()
        score = 0
        boardSlots = []
        deck = deckBuilder()
    }

    /// Draws one card from the deck and appends it to the board. No-op if the
    /// deck is empty.
    @discardableResult
    func dealOne() -> Bool {
        guard !deck.isEmpty else { return false }
        boardSlots.append(deck.removeFirst())
        return true
    }

    func dealThreeMore() {
        guard canDealThree else { return }
        withAnimation {
            boardSlots.append(contentsOf: drawCards(count: SetGame.setSize))
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
        guard autoResolvesMatch else { return }

        score += 1
        resolveMatchedCards(matching: selectedCards)
    }

    /// Practice-mode hook: called by the view layer after the verdict bar is
    /// dismissed. Scores the match (if valid) and refills the board, or just
    /// clears the selection if the trio was invalid.
    func acknowledgeSelection() {
        if isSet(Array(selectedCards)) {
            score += 1
            resolveMatchedCards(matching: selectedCards)
        } else {
            withAnimation {
                selectedCards.removeAll()
            }
        }
    }

    func isSet(_ cards: [SetCard]) -> Bool {
        explain(cards).isSet
    }

    private func resolveMatchedCards(matching matchedCards: Set<SetCard>) {
        let matchedIndices = boardSlots.indices.filter { matchedCards.contains(boardSlots[$0]) }

        withAnimation {
            selectedCards.removeAll()

            // Replace in place when we have replacements AND board is at base size.
            // Otherwise (over-sized board after Deal 3, or empty deck) shrink.
            if deck.count >= matchedIndices.count && boardSlots.count <= SetGame.boardSize {
                let replacements = drawCards(count: matchedIndices.count)
                for (i, boardIdx) in matchedIndices.enumerated() {
                    boardSlots[boardIdx] = replacements[i]
                }
            } else {
                boardSlots.removeAll { matchedCards.contains($0) }
            }
        }
    }

    @discardableResult
    func showHint() -> Bool {
        guard canShowHint else { return false }
        guard let foundSet = findSetOnBoard() else { return false }
        withAnimation {
            selectedCards = Set(foundSet.prefix(2))
        }
        return true
    }

    private func findSetOnBoard() -> [SetCard]? {
        for firstIndex in boardSlots.indices.shuffled() {
            for secondIndex in (firstIndex + 1)..<boardSlots.endIndex {
                for thirdIndex in (secondIndex + 1)..<boardSlots.endIndex {
                    let possibleSet = [
                        boardSlots[firstIndex],
                        boardSlots[secondIndex],
                        boardSlots[thirdIndex]
                    ]

                    if isSet(possibleSet) {
                        return possibleSet
                    }
                }
            }
        }

        return nil
    }

    private func boardContainsSet() -> Bool {
        guard boardSlots.count >= SetGame.setSize else { return false }
        for i in 0..<boardSlots.count {
            for j in (i + 1)..<boardSlots.count {
                for k in (j + 1)..<boardSlots.count {
                    if isSet([boardSlots[i], boardSlots[j], boardSlots[k]]) {
                        return true
                    }
                }
            }
        }
        return false
    }
}
