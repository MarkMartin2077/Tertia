//
//  GameMode.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

nonisolated enum GameMode: String, CaseIterable, Identifiable, Codable {
    case practice
    case normal
    case timeAttack
    case daily

    /// Modes shown in the regular Free Play list. Daily is surfaced separately
    /// via the hero card.
    static var regularModes: [GameMode] { [.practice, .normal, .timeAttack] }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .practice: return "Practice"
        case .normal: return "Normal"
        case .timeAttack: return "Time Attack"
        case .daily: return "Daily Puzzle"
        }
    }

    var description: String {
        switch self {
        case .practice: return "Get feedback on every pick to learn the rules through play."
        case .normal: return "The classic experience. Hints available when you need them."
        case .timeAttack: return "5 minutes. No hints. Score as many sets as you can."
        case .daily: return "Same puzzle for everyone, refreshes daily."
        }
    }

    var systemImageName: String {
        switch self {
        case .practice: return "graduationcap.fill"
        case .normal: return "play.circle.fill"
        case .timeAttack: return "timer"
        case .daily: return "calendar"
        }
    }

    var accentColor: Color {
        switch self {
        case .practice: return .mint
        case .normal: return .yellow
        case .timeAttack: return .orange
        case .daily: return .purple
        }
    }

    var allowsHint: Bool {
        switch self {
        case .practice, .normal, .daily: return true
        case .timeAttack: return false
        }
    }

    var allowsDealThree: Bool {
        switch self {
        case .practice, .normal, .daily: return true
        case .timeAttack: return false
        }
    }

    var usesTimer: Bool {
        switch self {
        case .practice, .normal, .daily: return false
        case .timeAttack: return true
        }
    }

    var tracksCombo: Bool {
        switch self {
        case .practice, .normal, .timeAttack, .daily: return true
        }
    }

    var awardsTimeBonus: Bool {
        switch self {
        case .practice, .normal, .daily: return false
        case .timeAttack: return true
        }
    }
}
