//
//  SetExplanation.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation

nonisolated enum CardAttribute: String, CaseIterable, Identifiable, Hashable {
    case shape, count, color, fill

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shape: return "shape"
        case .count: return "count"
        case .color: return "color"
        case .fill: return "fill"
        }
    }
}

nonisolated enum AttributeOutcome: String, Codable, Equatable {
    case allSame
    case allDifferent
    case mixed
}

nonisolated struct AttributeAnalysis: Equatable {
    let attribute: CardAttribute
    let outcome: AttributeOutcome
}

nonisolated struct SetExplanation: Equatable {
    let isSet: Bool
    let analyses: [AttributeAnalysis]

    var conformingAttributes: [CardAttribute] {
        analyses.filter { $0.outcome != .mixed }.map(\.attribute)
    }

    var failingAttributes: [CardAttribute] {
        analyses.filter { $0.outcome == .mixed }.map(\.attribute)
    }

    func outcome(for attribute: CardAttribute) -> AttributeOutcome? {
        analyses.first { $0.attribute == attribute }?.outcome
    }
}

/// User-facing concrete description of a single attribute across a 3-card trio,
/// e.g. "all circles", "two filled, one empty", "all different". Used by the
/// practice verdict bar to teach why a trio is or isn't a set.
nonisolated func describe(_ cards: [SetCard], attribute: CardAttribute) -> String {
    guard cards.count == 3 else { return "" }

    func format<V: Hashable>(
        _ values: [V],
        name: (V) -> String,
        plural: (V) -> String
    ) -> String {
        let counts = values.reduce(into: [V: Int]()) { $0[$1, default: 0] += 1 }
        switch counts.count {
        case 1:
            return "all \(plural(values[0]))"
        case 3:
            return "all different"
        default:
            let majority = counts.first(where: { $0.value == 2 })!.key
            let minority = counts.first(where: { $0.value == 1 })!.key
            return "two \(plural(majority)), one \(name(minority))"
        }
    }

    switch attribute {
    case .shape:
        return format(cards.map(\.shape), name: { $0.displayName }, plural: { $0.pluralForm })
    case .count:
        return format(cards.map(\.count), name: { $0.displayName }, plural: { $0.pluralForm })
    case .color:
        return format(cards.map(\.color), name: { $0.displayName }, plural: { $0.pluralForm })
    case .fill:
        return format(cards.map(\.fill), name: { $0.displayName }, plural: { $0.pluralForm })
    }
}

/// Pure analysis of a 3-card trio against the Set rules. Reports each attribute
/// as `.allSame`, `.allDifferent`, or `.mixed`. The trio is a valid set iff no
/// attribute is `.mixed`.
nonisolated func explain(_ cards: [SetCard]) -> SetExplanation {
    guard cards.count == 3 else {
        return SetExplanation(isSet: false, analyses: [])
    }

    func outcome<Value: Hashable>(_ values: [Value]) -> AttributeOutcome {
        switch Set(values).count {
        case 1: return .allSame
        case 3: return .allDifferent
        default: return .mixed
        }
    }

    let analyses: [AttributeAnalysis] = [
        .init(attribute: .shape, outcome: outcome(cards.map(\.shape))),
        .init(attribute: .count, outcome: outcome(cards.map(\.count))),
        .init(attribute: .color, outcome: outcome(cards.map(\.color))),
        .init(attribute: .fill, outcome: outcome(cards.map(\.fill)))
    ]

    return SetExplanation(
        isSet: analyses.allSatisfy { $0.outcome != .mixed },
        analyses: analyses
    )
}
