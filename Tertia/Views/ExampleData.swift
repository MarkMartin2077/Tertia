//
//  ExampleData.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation

enum ExampleData {
    /// Minimum-variation valid trio: only one attribute (count) is all-different;
    /// shape, color, and fill match across all three cards. Every card is a
    /// distinct combination, so this position can actually appear in play.
    static let oneAttributeDifferentSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .two, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .three, color: .red, fill: .filled)
    ]

    /// Maximum-variation valid trio: every attribute is all-different.
    static let allDifferentSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .square, count: .two, color: .green, fill: .empty),
        SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
    ]

    /// Mixed valid trio: two attributes all-different (shape, count), two
    /// all-same (color, fill). Demonstrates per-attribute independence. Uses
    /// green so it reads visually distinct from the all-red first example.
    static let mixedSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .green, fill: .filled),
        SetCard(shape: .square, count: .two, color: .green, fill: .filled),
        SetCard(shape: .triangle, count: .three, color: .green, fill: .filled)
    ]

    /// Non-trio: all three cards are distinct, counts are all-different, but
    /// fill is two-filled-one-empty — breaks the rule on a single attribute.
    /// Uses blue to differentiate from the red trio examples.
    static let mixedFillNonSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .blue, fill: .filled),
        SetCard(shape: .circle, count: .two, color: .blue, fill: .filled),
        SetCard(shape: .circle, count: .three, color: .blue, fill: .empty)
    ]

    /// Non-trio: all three cards are distinct, shapes are all-different, but
    /// color is two-red-one-green — breaks the rule on a single attribute.
    static let mixedColorNonSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .square, count: .one, color: .green, fill: .filled),
        SetCard(shape: .triangle, count: .one, color: .red, fill: .filled)
    ]
}
