//
//  CardColor.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

nonisolated enum CardColor: String, CaseIterable, Codable {
    case red, green, blue

    var displayName: String {
        switch self {
        case .red: "red"
        case .green: "green"
        case .blue: "blue"
        }
    }

    /// Colors don't pluralize in adjective form ("two red cards", not "two reds").
    var pluralForm: String { displayName }

    var color: Color {
        switch self {
        case .red: .red
        case .green: .green
        case .blue: .blue
        }
    }
}
