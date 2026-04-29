//
//  SetGameTests.swift
//  TertiaTests
//
//  Created by Mark Martin on 4/28/26.
//

import Testing
import Foundation
@testable import Tertia

@Suite("SetGame")
struct SetGameTests {

    // MARK: - Helpers

    private static let validSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .square, count: .two, color: .green, fill: .empty),
        SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
    ]

    private static let invalidTrio: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .one, color: .red, fill: .empty)
    ]

    /// A second valid trio with different cards so we can chain matches in tests.
    /// All four attributes are all-different (different from `validSet`).
    private static let validSet2: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .green, fill: .empty),
        SetCard(shape: .square, count: .two, color: .blue, fill: .filled),
        SetCard(shape: .triangle, count: .three, color: .red, fill: .rightHalf)
    ]

    // MARK: - Fresh game state

    @Test("Fresh game deals 12 cards and leaves 69 in the deck")
    func freshGameDealtCorrectly() {
        let game = SetGame()
        #expect(game.boardSlots.count == 12)
        #expect(game.deck.count == 81 - 12)
        #expect(game.score == 0)
        #expect(game.selectedCards.isEmpty)
        #expect(!game.hasInvalidSelection)
    }

    @Test("Deck contains all 81 unique cards across board and remaining stack")
    func deckIsComplete() {
        let game = SetGame()
        let allCards = Set(game.boardSlots + game.deck)
        #expect(allCards.count == 81)
    }

    // MARK: - isSet truth table    

    @Test("isSet rejects fewer than 3 cards")
    func isSetRejectsWrongCount() {
        let game = SetGame()
        let one = SetCard(shape: .circle, count: .one, color: .red, fill: .filled)
        let two = SetCard(shape: .square, count: .two, color: .green, fill: .empty)
        #expect(!game.isSet([]))
        #expect(!game.isSet([one]))
        #expect(!game.isSet([one, two]))
    }

    @Test("All-same attributes form a set")
    func allSameIsSet() {
        let game = SetGame()
        let cards = (0..<3).map { _ in
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled)
        }
        #expect(game.isSet(cards))
    }

    @Test("All-different attributes form a set")
    func allDifferentIsSet() {
        let game = SetGame()
        #expect(game.isSet(Self.validSet))
    }

    @Test("Mixed attributes (two same, one different) is not a set")
    func mixedIsNotSet() {
        let game = SetGame()
        // shape, count, color all different; fill is filled/empty/filled (mixed)
        let cards = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .filled)
        ]
        #expect(!game.isSet(cards))
    }

    // MARK: - select flow

    @Test("Tapping a selected card deselects it")
    func tappingSelectedDeselects() {
        let game = SetGame()
        let card = game.boardSlots.first!
        game.select(card)
        #expect(game.selectedCards.contains(card))
        game.select(card)
        #expect(!game.selectedCards.contains(card))
    }

    @Test("Three non-set cards leave hasInvalidSelection true")
    func threeInvalidFlagsInvalid() {
        let game = SetGame()
        for (i, c) in Self.invalidTrio.enumerated() { game.boardSlots[i] = c }
        for c in Self.invalidTrio { game.select(c) }
        #expect(game.selectedCards.count == 3)
        #expect(game.hasInvalidSelection)
    }

    @Test("Tapping a 4th card after invalid trio resets selection")
    func fourthCardResetsAfterInvalid() {
        let game = SetGame()
        let fourth = SetCard(shape: .square, count: .two, color: .green, fill: .empty)
        for (i, c) in Self.invalidTrio.enumerated() { game.boardSlots[i] = c }
        game.boardSlots[3] = fourth

        for c in Self.invalidTrio { game.select(c) }
        game.select(fourth)

        #expect(game.selectedCards.count == 1)
        #expect(game.selectedCards.contains(fourth))
        #expect(!game.hasInvalidSelection)
    }

    @Test("Matching a valid set increments score, clears selection, and removes the cards")
    func validSetScoresAndClears() {
        let game = SetGame()
        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }

        for c in Self.validSet { game.select(c) }

        // validSet is all-different on all 4 attributes → 4 base points.
        #expect(game.score == 4)
        #expect(game.selectedCards.isEmpty)
        for c in Self.validSet {
            #expect(!game.boardSlots.contains(c))
        }
    }

    @Test("hasInvalidSelection is false for fewer than three selected")
    func invalidRequiresThree() {
        let game = SetGame()
        #expect(!game.hasInvalidSelection)
        let card = game.boardSlots.first!
        game.select(card)
        #expect(!game.hasInvalidSelection)
    }

    // MARK: - newGame

    @Test("newGame resets score, selection, and refills the board")
    func newGameResets() {
        let game = SetGame()
        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }
        for c in Self.validSet { game.select(c) }
        #expect(game.score == 4)

        game.newGame()

        #expect(game.score == 0)
        #expect(game.selectedCards.isEmpty)
        #expect(game.boardSlots.count == 12)
        #expect(game.deck.count == 81 - 12)
    }

    // MARK: - showHint

    @Test("showHint returns true when a set exists and selects two cards")
    func hintFindsSet() {
        let game = SetGame()
        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }

        #expect(game.showHint() == true)
        #expect(game.selectedCards.count == 2)
    }

    @Test("showHint returns false when no set exists on the board")
    func hintMissesEmptyBoard() {
        let game = SetGame()
        game.boardSlots = []
        #expect(game.showHint() == false)
        #expect(game.selectedCards.isEmpty)
    }

    // MARK: - dealThreeMore / canDealThree

    @Test("canDealThree is true when board has no set and deck has cards")
    func canDealWhenNoSet() {
        let game = SetGame()
        game.boardSlots = Self.invalidTrio
        #expect(game.canDealThree)
    }

    @Test("canDealThree is false when a set is visible")
    func cannotDealWithVisibleSet() {
        let game = SetGame()
        game.boardSlots = Self.validSet
        #expect(!game.canDealThree)
    }

    @Test("canDealThree is false when deck is empty")
    func cannotDealEmptyDeck() {
        let game = SetGame()
        game.deck = []
        game.boardSlots = Self.invalidTrio
        #expect(!game.canDealThree)
    }

    @Test("dealThreeMore appends 3 cards and reduces deck by 3")
    func dealThreeAddsCards() {
        let game = SetGame()
        game.boardSlots = Self.invalidTrio
        let deckBefore = game.deck.count

        game.dealThreeMore()

        #expect(game.boardSlots.count == 6)
        #expect(game.deck.count == deckBefore - 3)
    }

    @Test("dealThreeMore is a no-op when a set is visible")
    func dealThreeNoOpWithVisibleSet() {
        let game = SetGame()
        game.boardSlots = Self.validSet
        let deckBefore = game.deck.count
        let boardBefore = game.boardSlots.count

        game.dealThreeMore()

        #expect(game.boardSlots.count == boardBefore)
        #expect(game.deck.count == deckBefore)
    }

    @Test("Matching a set on an oversized board shrinks back to base size")
    func oversizedBoardShrinksOnMatch() {
        let game = SetGame()
        // Plant a known set in slots 0-2, grow board from 12 to 15 via deck
        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }
        let extras = Array(game.deck.prefix(3))
        game.deck.removeFirst(3)
        game.boardSlots.append(contentsOf: extras)
        #expect(game.boardSlots.count == 15)
        let deckBefore = game.deck.count

        for c in Self.validSet { game.select(c) }

        #expect(game.boardSlots.count == 12)
        #expect(game.deck.count == deckBefore)
    }

    // MARK: - Practice mode / acknowledgeSelection

    @Test("Practice mode retains selection after select() until acknowledged")
    func practiceModeRetainsSelectionUntilAcknowledged() {
        let game = SetGame(mode: .practice)
        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }

        // Select the first two cards manually, then call select() for the third.
        game.selectedCards = Set(Self.validSet.prefix(2))
        game.select(Self.validSet[2])

        // autoResolvesMatch is false for practice — the trio must still be selected.
        #expect(game.selectedCards.count == 3)
        #expect(game.score == 0)
        // The matched cards are still on the board.
        for c in Self.validSet {
            #expect(game.boardSlots.contains(c))
        }
    }

    @Test("acknowledgeSelection scores a valid trio and clears it from the board")
    func practiceAcknowledgeValidSetIncrementsScore() {
        let game = SetGame(mode: .practice)
        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }
        game.selectedCards = Set(Self.validSet)

        game.acknowledgeSelection()

        // validSet is all-different on all 4 attributes → 4 base points.
        #expect(game.score == 4)
        #expect(game.selectedCards.isEmpty)
        for c in Self.validSet {
            #expect(!game.boardSlots.contains(c))
        }
    }

    @Test("acknowledgeSelection clears an invalid trio without scoring or removing cards")
    func practiceAcknowledgeInvalidTrioClearsWithoutScoring() {
        let game = SetGame(mode: .practice)
        for (i, c) in Self.invalidTrio.enumerated() { game.boardSlots[i] = c }
        game.selectedCards = Set(Self.invalidTrio)

        game.acknowledgeSelection()

        #expect(game.score == 0)
        #expect(game.selectedCards.isEmpty)
        // The three cards must still be on the board — no removal on an invalid trio.
        for c in Self.invalidTrio {
            #expect(game.boardSlots.contains(c))
        }
    }

    // MARK: - isGameOver

    @Test("isGameOver is false on a fresh game")
    func gameNotOverFresh() {
        let game = SetGame()
        #expect(!game.isGameOver)
    }

    @Test("isGameOver is true when deck is empty and no set exists")
    func gameOverWhenDeckEmptyAndNoSet() {
        let game = SetGame()
        game.deck = []
        game.boardSlots = Self.invalidTrio
        #expect(game.isGameOver)
    }

    @Test("isGameOver is false when deck is empty but a set exists")
    func notGameOverIfSetVisible() {
        let game = SetGame()
        game.deck = []
        game.boardSlots = Self.validSet
        #expect(!game.isGameOver)
    }

    // MARK: - Combo + session stats

    @Test("Two valid trios within the combo window activate ×2")
    func comboActivatesWithinFiveSeconds() {
        let game = SetGame(mode: .normal)
        let t0 = Date()
        game.newGame(now: t0)

        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }
        for c in Self.validSet { game.select(c, now: t0) }
        // 4 base × ×1 = 4
        #expect(game.score == 4)
        #expect(game.multiplier == 1)

        for (i, c) in Self.validSet2.enumerated() { game.boardSlots[i] = c }
        let t1 = t0.addingTimeInterval(4)
        for c in Self.validSet2 { game.select(c, now: t1) }

        // 4 base × ×2 = 8 added → 12 total
        #expect(game.multiplier == 2)
        #expect(game.score == 4 + 8)
        #expect(game.longestStreak == 2)
    }

    @Test("A stall outside the combo window resets multiplier to ×1")
    func comboResetsAfterStall() {
        let game = SetGame(mode: .normal)
        let t0 = Date()
        game.newGame(now: t0)

        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }
        for c in Self.validSet { game.select(c, now: t0) }

        for (i, c) in Self.validSet2.enumerated() { game.boardSlots[i] = c }
        let stalled = t0.addingTimeInterval(6)
        for c in Self.validSet2 { game.select(c, now: stalled) }

        // Both are 4-base trios, both score at ×1 due to stall: 4 + 4 = 8
        #expect(game.multiplier == 1)
        #expect(game.score == 8)
    }

    // MARK: - Difficulty-weighted scoring

    @Test("One-attribute-different trio scores 1 base point")
    func difficultyOneScoresOne() {
        let game = SetGame(mode: .normal)
        let trio = ExampleData.oneAttributeDifferentSet
        for (i, c) in trio.enumerated() { game.boardSlots[i] = c }
        for c in trio { game.select(c) }
        #expect(game.score == 1)
    }

    @Test("Two-attributes-different trio scores 2 base points")
    func difficultyTwoScoresTwo() {
        let game = SetGame(mode: .normal)
        let trio = ExampleData.mixedSet // shape & count differ; color & fill same
        for (i, c) in trio.enumerated() { game.boardSlots[i] = c }
        for c in trio { game.select(c) }
        #expect(game.score == 2)
    }

    @Test("Four-attributes-different trio scores 4 base points")
    func difficultyFourScoresFour() {
        let game = SetGame(mode: .normal)
        let trio = ExampleData.allDifferentSet
        for (i, c) in trio.enumerated() { game.boardSlots[i] = c }
        for c in trio { game.select(c) }
        #expect(game.score == 4)
    }

    @Test("Multiplier caps at ×3 even with four consecutive sets in window")
    func comboCapsAtThree() {
        let game = SetGame(mode: .normal)
        let t0 = Date()
        game.newGame(now: t0)

        // Four consecutive matches within the window. We only need two distinct
        // valid trios — alternating works because each match clears the slots.
        let trios = [Self.validSet, Self.validSet2, Self.validSet, Self.validSet2]
        var t = t0
        for trio in trios {
            for (i, c) in trio.enumerated() { game.boardSlots[i] = c }
            for c in trio { game.select(c, now: t) }
            t = t.addingTimeInterval(2)
        }

        #expect(game.multiplier == 3)
        #expect(game.longestStreak == 3)
    }

    @Test("fastestSetSeconds tracks the shortest solve in the session")
    func fastestSetTracksMinimum() {
        let game = SetGame(mode: .normal)
        let t0 = Date()
        game.newGame(now: t0)

        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }
        let firstAt = t0.addingTimeInterval(8)
        for c in Self.validSet { game.select(c, now: firstAt) }
        #expect(game.fastestSetSeconds == 8)

        for (i, c) in Self.validSet2.enumerated() { game.boardSlots[i] = c }
        let secondAt = firstAt.addingTimeInterval(3)
        for c in Self.validSet2 { game.select(c, now: secondAt) }

        #expect(game.fastestSetSeconds == 3)
    }

    @Test("Invalid trio in normal mode resets the active combo")
    func invalidTrioResetsComboInNormalMode() {
        let game = SetGame(mode: .normal)
        let t0 = Date()
        game.newGame(now: t0)

        // Build combo to ×2.
        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }
        for c in Self.validSet { game.select(c, now: t0) }
        for (i, c) in Self.validSet2.enumerated() { game.boardSlots[i] = c }
        for c in Self.validSet2 { game.select(c, now: t0.addingTimeInterval(2)) }
        #expect(game.multiplier == 2)

        // Plant invalid trio and complete the third tap.
        for (i, c) in Self.invalidTrio.enumerated() { game.boardSlots[i] = c }
        for c in Self.invalidTrio { game.select(c, now: t0.addingTimeInterval(3)) }

        #expect(game.multiplier == 1)
    }

    @Test("Invalid trio in practice mode preserves the active combo")
    func practiceDoesNotResetComboOnInvalid() {
        let game = SetGame(mode: .practice)
        let t0 = Date()
        game.newGame(now: t0)

        // Build practice combo to ×2 via acknowledgeSelection.
        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }
        game.selectedCards = Set(Self.validSet)
        game.acknowledgeSelection(now: t0)

        for (i, c) in Self.validSet2.enumerated() { game.boardSlots[i] = c }
        game.selectedCards = Set(Self.validSet2)
        game.acknowledgeSelection(now: t0.addingTimeInterval(2))
        #expect(game.multiplier == 2)

        // Plant invalid trio in practice — combo should not reset.
        for (i, c) in Self.invalidTrio.enumerated() { game.boardSlots[i] = c }
        for c in Self.invalidTrio { game.select(c, now: t0.addingTimeInterval(3)) }

        #expect(game.multiplier == 2)
    }

    @Test("newGame clears all combo and stats state")
    func newGameClearsAllSessionState() {
        let game = SetGame(mode: .normal)
        let t0 = Date()
        game.newGame(now: t0)

        // Build some state.
        for (i, c) in Self.validSet.enumerated() { game.boardSlots[i] = c }
        for c in Self.validSet { game.select(c, now: t0) }
        for (i, c) in Self.validSet2.enumerated() { game.boardSlots[i] = c }
        for c in Self.validSet2 { game.select(c, now: t0.addingTimeInterval(2)) }
        #expect(game.multiplier == 2)
        #expect(game.longestStreak == 2)
        #expect(game.fastestSetSeconds != nil)

        game.newGame()

        #expect(game.multiplier == 1)
        #expect(game.longestStreak == 0)
        #expect(game.fastestSetSeconds == nil)
        #expect(game.score == 0)
    }
}
