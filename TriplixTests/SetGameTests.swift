//
//  SetGameTests.swift
//  TriplixTests
//
//  Created by Mark Martin on 4/28/26.
//

import Testing
@testable import Triplix

@Suite("SetGame")
struct SetGameTests {

    // MARK: - Fresh game state

    @Test("Fresh game deals 18 cards and leaves 63 in the deck")
    func freshGameDealtCorrectly() {
        let game = SetGame()
        let dealt = game.boardSlots.compactMap(\.self)
        #expect(dealt.count == 18)
        #expect(game.deck.count == 81 - 18)
        #expect(game.score == 0)
        #expect(game.selectedCards.isEmpty)
        #expect(!game.hasInvalidSelection)
    }

    @Test("Deck contains all 81 unique cards across board and remaining stack")
    func deckIsComplete() {
        let game = SetGame()
        let allCards = Set(game.boardSlots.compactMap(\.self) + game.deck)
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
        let cards = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        #expect(game.isSet(cards))
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
        let card = game.boardSlots.compactMap(\.self).first!
        game.select(card)
        #expect(game.selectedCards.contains(card))
        game.select(card)
        #expect(!game.selectedCards.contains(card))
    }

    @Test("Three non-set cards leave hasInvalidSelection true")
    func threeInvalidFlagsInvalid() {
        let game = SetGame()
        let invalidTrio = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .empty)
        ]
        for (i, c) in invalidTrio.enumerated() { game.boardSlots[i] = c }
        for c in invalidTrio { game.select(c) }
        #expect(game.selectedCards.count == 3)
        #expect(game.hasInvalidSelection)
    }

    @Test("Tapping a 4th card after invalid trio resets selection")
    func fourthCardResetsAfterInvalid() {
        let game = SetGame()
        let invalidTrio = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .empty)
        ]
        let fourth = SetCard(shape: .square, count: .two, color: .green, fill: .empty)
        for (i, c) in invalidTrio.enumerated() { game.boardSlots[i] = c }
        game.boardSlots[3] = fourth

        for c in invalidTrio { game.select(c) }
        game.select(fourth)

        #expect(game.selectedCards.count == 1)
        #expect(game.selectedCards.contains(fourth))
        #expect(!game.hasInvalidSelection)
    }

    @Test("Matching a valid set increments score, clears selection, and removes the cards")
    func validSetScoresAndClears() {
        let game = SetGame()
        let trio = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        for (i, c) in trio.enumerated() { game.boardSlots[i] = c }

        for c in trio { game.select(c) }

        #expect(game.score == 1)
        #expect(game.selectedCards.isEmpty)
        for c in trio {
            #expect(!game.boardSlots.compactMap(\.self).contains(c))
        }
    }

    @Test("hasInvalidSelection is false for fewer than three selected")
    func invalidRequiresThree() {
        let game = SetGame()
        #expect(!game.hasInvalidSelection)
        let card = game.boardSlots.compactMap(\.self).first!
        game.select(card)
        #expect(!game.hasInvalidSelection)
    }

    // MARK: - newGame

    @Test("newGame resets score, selection, and refills the board")
    func newGameResets() {
        let game = SetGame()
        let trio = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        for (i, c) in trio.enumerated() { game.boardSlots[i] = c }
        for c in trio { game.select(c) }
        #expect(game.score == 1)

        game.newGame()

        #expect(game.score == 0)
        #expect(game.selectedCards.isEmpty)
        #expect(game.boardSlots.compactMap(\.self).count == 18)
        #expect(game.deck.count == 81 - 18)
    }

    // MARK: - showHint

    @Test("showHint returns true when a set exists and selects two cards")
    func hintFindsSet() {
        let game = SetGame()
        let trio = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        for (i, c) in trio.enumerated() { game.boardSlots[i] = c }

        #expect(game.showHint() == true)
        #expect(game.selectedCards.count == 2)
    }

    @Test("showHint returns false when no set exists on the board")
    func hintMissesEmptyBoard() {
        let game = SetGame()
        for i in game.boardSlots.indices { game.boardSlots[i] = nil }
        #expect(game.showHint() == false)
        #expect(game.selectedCards.isEmpty)
    }
}
