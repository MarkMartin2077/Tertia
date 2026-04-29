//
//  CardFill.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation

nonisolated enum CardFill: CaseIterable {
    case empty, rightHalf, filled

    var displayName: String {
        switch self {
        case .empty: "empty"
        case .rightHalf: "half"
        case .filled: "filled"
        }
    }

    /// Fill descriptions are adjectives ("two filled cards", not "two filleds").
    var pluralForm: String { displayName }
}
