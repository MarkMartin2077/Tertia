//
//  CardShape.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation

nonisolated enum CardShape: CaseIterable {
    case circle, square, triangle
    
    func systemName(for fill: CardFill) -> String {
        let base = switch self {
        case .circle: "circle"
        case .square: "square"
        case .triangle: "triangle"
        }

        let suffix = switch fill {
        case .empty: ""
        case .rightHalf: ".righthalf.filled"
        case .filled: ".fill"
        }

        return base + suffix
    }
}
