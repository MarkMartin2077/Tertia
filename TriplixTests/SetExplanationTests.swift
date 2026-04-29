//
//  SetExplanationTests.swift
//  TriplixTests
//
//  Created by Mark Martin on 4/28/26.
//

import Testing
@testable import Triplix

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
}
