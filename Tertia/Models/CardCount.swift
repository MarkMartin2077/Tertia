//
//  CardCount.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation

nonisolated enum CardCount: String, CaseIterable, Codable {
    case one, two, three

    var displayName: String {
        switch self {
        case .one: "one"
        case .two: "two"
        case .three: "three"
        }
    }

    var pluralForm: String {
        switch self {
        case .one: "ones"
        case .two: "twos"
        case .three: "threes"
        }
    }
}
