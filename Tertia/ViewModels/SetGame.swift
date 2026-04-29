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

    // MARK: - Combo & session stats

    /// Window in which a follow-up valid trio extends the combo.
    let comboWindow: TimeInterval = 5

    /// Active combo multiplier. Resets to 1 on stall or invalid in non-practice.
    var multiplier: Int = 1

    /// Highest multiplier reached this session — surfaced on the game-over sheet.
    var longestStreak: Int = 0

    /// Smallest time-to-set this session in seconds. Nil until first set.
    var fastestSetSeconds: Double? = nil

    private var lastSetAt: Date? = nil
    private var lastBoardChangeAt: Date = .now

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

    var hasSetOnBoard: Bool {
        boardContainsSet()
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

    func newGame(now: Date = .now) {
        withAnimation {
            selectedCards.removeAll()
            score = 0
            resetSessionStats(now: now)
            createBoard()
        }
    }

    /// Resets state without dealing cards. Use with `dealOne()` to drive an
    /// animated deal from the view layer.
    func clearBoard(now: Date = .now) {
        selectedCards.removeAll()
        score = 0
        resetSessionStats(now: now)
        boardSlots = []
        deck = deckBuilder()
    }

    private func resetSessionStats(now: Date = .now) {
        multiplier = 1
        longestStreak = 0
        fastestSetSeconds = nil
        lastSetAt = nil
        lastBoardChangeAt = now
    }

    /// Draws one card from the deck and appends it to the board. No-op if the
    /// deck is empty.
    @discardableResult
    func dealOne() -> Bool {
        guard !deck.isEmpty else { return false }
        boardSlots.append(deck.removeFirst())
        return true
    }

    func dealThreeMore(now: Date = .now) {
        guard canDealThree else { return }
        withAnimation {
            boardSlots.append(contentsOf: drawCards(count: SetGame.setSize))
        }
        lastBoardChangeAt = now
    }

    func select(_ card: SetCard, now: Date = .now) {
        guard boardSlots.contains(card) else { return }

        if selectedCards.contains(card) {
            selectedCards.remove(card)
            return
        }

        if selectedCards.count == SetGame.setSize {
            selectedCards.removeAll()
        }

        selectedCards.insert(card)

        // Third tap completed an invalid trio — non-practice modes break the combo
        // immediately so the user feels the cost of a wrong pick.
        if selectedCards.count == SetGame.setSize,
           !isSet(Array(selectedCards)),
           mode != .practice {
            multiplier = 1
        }

        guard isSet(Array(selectedCards)) else { return }
        guard autoResolvesMatch else { return }

        registerValidSet(at: now)
        score += multiplier
        resolveMatchedCards(matching: selectedCards, now: now)
    }

    /// Practice-mode hook: called by the view layer after the verdict bar is
    /// dismissed. Scores the match (if valid) and refills the board, or just
    /// clears the selection if the trio was invalid.
    func acknowledgeSelection(now: Date = .now) {
        if isSet(Array(selectedCards)) {
            registerValidSet(at: now)
            score += multiplier
            resolveMatchedCards(matching: selectedCards, now: now)
        } else {
            withAnimation {
                selectedCards.removeAll()
            }
        }
    }

    /// Combo + stats bookkeeping. Must be called BEFORE incrementing `score`
    /// so the awarded points reflect the freshly-applied multiplier.
    private func registerValidSet(at now: Date) {
        if let last = lastSetAt, now.timeIntervalSince(last) <= comboWindow {
            multiplier = min(multiplier + 1, 3)
        } else {
            multiplier = 1
        }
        longestStreak = max(longestStreak, multiplier)

        let solveTime = now.timeIntervalSince(lastBoardChangeAt)
        if solveTime > 0 {
            fastestSetSeconds = min(fastestSetSeconds ?? solveTime, solveTime)
        }

        lastSetAt = now
    }

    func isSet(_ cards: [SetCard]) -> Bool {
        explain(cards).isSet
    }

    private func resolveMatchedCards(matching matchedCards: Set<SetCard>, now: Date = .now) {
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

        lastBoardChangeAt = now
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

    /// Returns any valid trio currently visible, or nil if the board has none.
    /// Pure — does not mutate state. Safe to call from the view layer for the
    /// passive practice halo.
    func findSetOnBoard() -> [SetCard]? {
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
