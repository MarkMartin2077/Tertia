//
//  StatsViewModel.swift
//  Tertia
//

import Foundation
import Observation

/// Composes the two stats-relevant stores into a single shape the view layer
/// can render against. Pure derivation — no persistence of its own.
@MainActor
@Observable
final class StatsViewModel {
    private let highScoreStore: HighScoreStore
    private let dailyStore: DailyStore

    /// Time Attack duration (in seconds) the leaderboard filters on. Mirrors
    /// the same constant used by `GameView`'s default for `TimeAttackController`.
    let timeAttackDuration = 300

    init(highScoreStore: HighScoreStore, dailyStore: DailyStore) {
        self.highScoreStore = highScoreStore
        self.dailyStore = dailyStore
    }

    var dailyHistory: [DailyRecord] {
        dailyStore.pastRecords
    }

    var hasDailyHistory: Bool {
        !dailyHistory.isEmpty
    }

    var currentStreak: Int {
        dailyStore.displayedStreak
    }

    var bestStreak: Int {
        dailyStore.bestStreak
    }

    var timeAttackEntries: [HighScoreEntry] {
        highScoreStore.entries.filter { $0.durationSeconds == timeAttackDuration }
    }

    var hasTimeAttackHistory: Bool {
        !timeAttackEntries.isEmpty
    }

    var timeAttackBest: Int? {
        bestScore(in: timeAttackEntries)
    }

    var timeAttackBestToday: Int? {
        let calendar = Calendar.current
        return bestScore(in: timeAttackEntries.filter { calendar.isDateInToday($0.date) })
    }

    var timeAttackBestThisWeek: Int? {
        let calendar = Calendar.current
        return bestScore(in: timeAttackEntries.filter {
            calendar.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear)
        })
    }

    private func bestScore(in entries: [HighScoreEntry]) -> Int? {
        entries.map(\.score).max()
    }

    /// Top-N Time Attack runs, sorted descending by score, for the recent-runs list.
    func topTimeAttackEntries(_ n: Int = 5) -> [HighScoreEntry] {
        Array(timeAttackEntries.sorted(by: { $0.score > $1.score }).prefix(n))
    }
}
