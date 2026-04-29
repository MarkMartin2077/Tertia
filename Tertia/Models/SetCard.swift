//
//  SetCard.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation

nonisolated struct SetCard: Identifiable, Hashable {
    let id = UUID()
    var shape: CardShape
    var count: CardCount
    var color: CardColor
    var fill: CardFill
    
    static let example = SetCard(shape: .circle, count: .two, color: .red, fill: .filled)
}
