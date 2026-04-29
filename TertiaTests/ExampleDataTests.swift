//
//  ExampleDataTests.swift
//  TertiaTests
//

import Foundation
import Testing
@testable import Tertia

@Suite("ExampleData")
struct ExampleDataTests {

    @Test("All trio examples have three distinct cards")
    func examplesUseDistinctCards() {
        let allExamples: [(String, [SetCard])] = [
            ("oneAttributeDifferentSet", ExampleData.oneAttributeDifferentSet),
            ("allDifferentSet", ExampleData.allDifferentSet),
            ("mixedSet", ExampleData.mixedSet),
            ("mixedFillNonSet", ExampleData.mixedFillNonSet),
            ("mixedColorNonSet", ExampleData.mixedColorNonSet)
        ]
        for (name, cards) in allExamples {
            #expect(cards.count == 3, "\(name) should have exactly 3 cards")
            let signatures = cards.map { card in
                "\(card.shape)-\(card.count)-\(card.color)-\(card.fill)"
            }
            #expect(
                Set(signatures).count == 3,
                "\(name) has duplicate cards — impossible in an 81-card deck"
            )
        }
    }

    @Test("oneAttributeDifferentSet is a valid trio")
    func minimalVariationIsTrio() {
        #expect(explain(ExampleData.oneAttributeDifferentSet).isSet)
    }

    @Test("allDifferentSet is a valid trio")
    func maximalVariationIsTrio() {
        #expect(explain(ExampleData.allDifferentSet).isSet)
    }

    @Test("mixedSet is a valid trio")
    func mixedIsTrio() {
        #expect(explain(ExampleData.mixedSet).isSet)
    }

    @Test("mixedFillNonSet is not a trio (fill is the breaker)")
    func mixedFillBreaks() {
        let result = explain(ExampleData.mixedFillNonSet)
        #expect(!result.isSet)
        #expect(result.failingAttributes == [.fill])
    }

    @Test("mixedColorNonSet is not a trio (color is the breaker)")
    func mixedColorBreaks() {
        let result = explain(ExampleData.mixedColorNonSet)
        #expect(!result.isSet)
        #expect(result.failingAttributes == [.color])
    }
}
