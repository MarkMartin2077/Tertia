//
//  SetExplanationTests.swift
//  TertiaTests
//
//  Created by Mark Martin on 4/28/26.
//

import Testing
@testable import Tertia

@Suite("SetExplanation")
struct SetExplanationTests {

    @Test("All-different trio is a set with all four conforming attributes")
    func allDifferentSet() {
        let cards = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        let result = explain(cards)
        #expect(result.isSet)
        #expect(Set(result.conformingAttributes) == Set(CardAttribute.allCases))
        #expect(result.failingAttributes.isEmpty)
    }

    @Test("All-same trio is a set with all four conforming attributes")
    func allSameSet() {
        let card = SetCard(shape: .circle, count: .one, color: .red, fill: .filled)
        let result = explain([card, card, card])
        #expect(result.isSet)
        #expect(result.failingAttributes.isEmpty)
    }

    @Test("Mixed-fill trio fails on fill attribute only")
    func mixedFillNonSet() {
        let cards = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .empty)
        ]
        let result = explain(cards)
        #expect(!result.isSet)
        #expect(result.failingAttributes == [.fill])
        #expect(Set(result.conformingAttributes) == Set([.shape, .count, .color]))
    }

    @Test("Mixed-color trio fails on color attribute only")
    func mixedColorNonSet() {
        let cards = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .one, color: .green, fill: .filled),
            SetCard(shape: .triangle, count: .one, color: .red, fill: .filled)
        ]
        let result = explain(cards)
        #expect(!result.isSet)
        #expect(result.failingAttributes == [.color])
    }

    @Test("Trio with fewer than 3 cards is never a set")
    func wrongCardCount() {
        let card = SetCard(shape: .circle, count: .one, color: .red, fill: .filled)
        #expect(!explain([]).isSet)
        #expect(!explain([card]).isSet)
        #expect(!explain([card, card]).isSet)
    }

    // MARK: - describe(_:attribute:)

    @Test("describe returns 'all <plural>' for all-same attributes")
    func describeAllSame() {
        let cards = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled)
        ]
        #expect(describe(cards, attribute: .shape) == "all circles")
        #expect(describe(cards, attribute: .count) == "all ones")
        #expect(describe(cards, attribute: .color) == "all red")
        #expect(describe(cards, attribute: .fill) == "all filled")
    }

    @Test("describe returns 'all different' for all-different attributes")
    func describeAllDifferent() {
        let cards = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]
        #expect(describe(cards, attribute: .shape) == "all different")
        #expect(describe(cards, attribute: .count) == "all different")
        #expect(describe(cards, attribute: .color) == "all different")
        #expect(describe(cards, attribute: .fill) == "all different")
    }

    @Test("describe returns 'two <majority>, one <minority>' for mixed attributes")
    func describeMixed() {
        let mixedFill = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .empty)
        ]
        #expect(describe(mixedFill, attribute: .fill) == "two filled, one empty")

        let mixedColor = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .one, color: .green, fill: .filled),
            SetCard(shape: .triangle, count: .one, color: .red, fill: .filled)
        ]
        #expect(describe(mixedColor, attribute: .color) == "two red, one green")

        let mixedShape = [
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .one, color: .red, fill: .filled)
        ]
        #expect(describe(mixedShape, attribute: .shape) == "two squares, one circle")

        let mixedCount = [
            SetCard(shape: .circle, count: .three, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled)
        ]
        #expect(describe(mixedCount, attribute: .count) == "two ones, one three")
    }

    @Test("describe returns empty string for non-3-card inputs")
    func describeWrongSize() {
        let card = SetCard(shape: .circle, count: .one, color: .red, fill: .filled)
        #expect(describe([], attribute: .shape) == "")
        #expect(describe([card, card], attribute: .shape) == "")
    }
}
