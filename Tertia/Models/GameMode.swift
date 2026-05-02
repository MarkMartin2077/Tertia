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
    case versus

    /// Modes shown in the regular Free Play list. Daily and Versus are
    /// surfaced separately via dedicated hero cards.
    static var regularModes: [GameMode] { [.practice, .normal, .timeAttack] }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .practice: return "Practice"
        case .normal: return "Normal"
        case .timeAttack: return "Time Attack"
        case .daily: return "Daily Puzzle"
        case .versus: return "Versus"
        }
    }

    var description: String {
        switch self {
        case .practice: return "Get feedback on every pick to learn the rules through play."
        case .normal: return "The classic experience. Hints available when you need them."
        case .timeAttack: return "5 minutes. No hints. Score as many sets as you can."
        case .daily: return "Same puzzle for everyone, refreshes daily."
        case .versus: return "Race a friend on the same deck. First to claim each trio wins the points."
        }
    }

    var systemImageName: String {
        switch self {
        case .practice: return "graduationcap.fill"
        case .normal: return "play.circle.fill"
        case .timeAttack: return "timer"
        case .daily: return "calendar"
        case .versus: return "person.2.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .practice: return .mint
        case .normal: return .yellow
        case .timeAttack: return .orange
        case .daily: return .purple
        case .versus: return .teal
        }
    }

    var allowsHint: Bool {
        switch self {
        case .practice, .normal, .daily: return true
        case .timeAttack, .versus: return false
        }
    }

    var allowsDealThree: Bool {
        switch self {
        case .practice, .normal, .daily, .versus: return true
        case .timeAttack: return false
        }
    }

    var usesTimer: Bool {
        switch self {
        case .practice, .normal, .daily, .versus: return false
        case .timeAttack: return true
        }
    }

    var tracksCombo: Bool {
        switch self {
        case .practice, .normal, .timeAttack, .daily, .versus: return true
        }
    }

    var awardsTimeBonus: Bool {
        switch self {
        case .practice, .normal, .daily, .versus: return false
        case .timeAttack: return true
        }
    }
}
