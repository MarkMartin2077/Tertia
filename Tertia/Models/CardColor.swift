//
//  CardColor.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

nonisolated enum CardColor: CaseIterable {
    case red, green, blue
    
    var color: Color {
        switch self {
        case .red: .red
        case .green: .green
        case .blue: .blue
        }
    }
}
