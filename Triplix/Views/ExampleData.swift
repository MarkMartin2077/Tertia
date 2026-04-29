//
//  ExampleData.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation

enum ExampleData {
    static let allSameSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled)
    ]

    static let allDifferentSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .square, count: .two, color: .green, fill: .empty),
        SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
    ]

    static let mixedSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .square, count: .two, color: .red, fill: .filled),
        SetCard(shape: .triangle, count: .three, color: .red, fill: .filled)
    ]

    static let mixedFillNonSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .one, color: .red, fill: .empty)
    ]

    static let mixedColorNonSet: [SetCard] = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .square, count: .one, color: .green, fill: .filled),
        SetCard(shape: .triangle, count: .one, color: .red, fill: .filled)
    ]
}
