//
//  TutorialPuzzle.swift
//  Tertia
//
//  Created by Mark Martin on 5/17/26.
//

import Foundation

/// A hand-authored puzzle for tutorial mode. Each puzzle is a small board
/// containing exactly one valid trio; the solution is stored by attribute
/// tuple (not UUID) so card re-instantiation in previews or test fixtures
/// can't break the link.
nonisolated struct TutorialPuzzle: Identifiable {
    let index: Int
    let cards: [SetCard]
    let solutionAttributes: [SetCardAttributes]
    let hint: String?

    var id: Int { index }
}

/// Value-equal projection of a `SetCard` for matching puzzle solutions.
/// `SetCard.id` is a fresh UUID per instance, so solutions referenced by
/// UUID would silently break the moment a card is rebuilt.
nonisolated struct SetCardAttributes: Hashable {
    let shape: CardShape
    let count: CardCount
    let color: CardColor
    let fill: CardFill

    init(shape: CardShape, count: CardCount, color: CardColor, fill: CardFill) {
        self.shape = shape
        self.count = count
        self.color = color
        self.fill = fill
    }

    init(_ card: SetCard) {
        self.shape = card.shape
        self.count = card.count
        self.color = card.color
        self.fill = card.fill
    }
}
