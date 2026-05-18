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
    case tutorial

    /// Modes shown in the regular Free Play list. Daily and Versus are
    /// surfaced separately via dedicated hero cards. Tutorial sits at the
    /// top so new players land on it first.
    static var regularModes: [GameMode] { [.tutorial, .practice, .normal, .timeAttack] }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .practice: return "Practice"
        case .normal: return "Normal"
        case .timeAttack: return "Time Attack"
        case .daily: return "Daily Puzzle"
        case .versus: return "Versus"
        case .tutorial: return "Tutorial"
        }
    }

    var description: String {
        switch self {
        case .practice: return "Get feedback on every pick to learn the rules through play."
        case .normal: return "The classic experience. Hints available when you need them."
        case .timeAttack: return "5 minutes. No hints. Score as many sets as you can."
        case .daily: return "Same puzzle for everyone, refreshes daily."
        case .versus: return "Race a friend on the same deck. First to claim each trio wins the points."
        case .tutorial: return "Learn the rules in 10 hand-crafted puzzles."
        }
    }

    var systemImageName: String {
        switch self {
        case .practice: return "graduationcap.fill"
        case .normal: return "play.circle.fill"
        case .timeAttack: return "timer"
        case .daily: return "calendar"
        case .versus: return "person.2.fill"
        case .tutorial: return "book.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .practice: return .mint
        case .normal: return .yellow
        case .timeAttack: return .orange
        case .daily: return .purple
        case .versus: return .teal
        case .tutorial: return .indigo
        }
    }

    var allowsHint: Bool {
        switch self {
        case .practice, .normal, .daily: return true
        case .timeAttack, .versus, .tutorial: return false
        }
    }

    var allowsDealThree: Bool {
        switch self {
        case .practice, .normal, .daily, .versus: return true
        case .timeAttack, .tutorial: return false
        }
    }

    var usesTimer: Bool {
        switch self {
        case .practice, .normal, .daily, .versus, .tutorial: return false
        case .timeAttack: return true
        }
    }

    var tracksCombo: Bool {
        switch self {
        case .practice, .normal, .timeAttack, .daily, .versus: return true
        case .tutorial: return false
        }
    }

    var awardsTimeBonus: Bool {
        switch self {
        case .practice, .normal, .daily, .versus, .tutorial: return false
        case .timeAttack: return true
        }
    }
}
