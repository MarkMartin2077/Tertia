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
    private let sessionStore: GameSessionStore
    private let versusStore: VersusStore

    /// Time Attack duration (in seconds) the leaderboard filters on. Mirrors
    /// the same constant used by `GameView`'s default for `TimeAttackController`.
    let timeAttackDuration = 300

    init(
        highScoreStore: HighScoreStore,
        dailyStore: DailyStore,
        sessionStore: GameSessionStore,
        versusStore: VersusStore
    ) {
        self.highScoreStore = highScoreStore
        self.dailyStore = dailyStore
        self.sessionStore = sessionStore
        self.versusStore = versusStore
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

    var dailyBest: Int? {
        dailyHistory.map(\.score).max()
    }

    /// Daily history sorted oldest → newest, capped to the last N entries for
    /// the trend chart.
    func recentDailyHistory(_ n: Int = 30) -> [DailyRecord] {
        Array(dailyHistory.sorted(by: { $0.day < $1.day }).suffix(n))
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

    // MARK: - Game duration history

    /// All sessions whose duration is meaningful — excludes Time Attack since
    /// it always runs the full 5 minutes.
    var gameDurationSessions: [GameSessionRecord] {
        sessionStore.durationTrackedSessions
    }

    var hasGameDurationHistory: Bool {
        !gameDurationSessions.isEmpty
    }

    var averageGameDurationSeconds: Double? {
        sessionStore.averageGameDurationSeconds
    }

    /// Most recent N sessions sorted oldest → newest, for the trend chart.
    func recentGameDurationSessions(_ n: Int = 30) -> [GameSessionRecord] {
        Array(
            gameDurationSessions
                .sorted(by: { $0.date < $1.date })
                .suffix(n)
        )
    }

    // MARK: - Versus

    var hasVersusHistory: Bool {
        !versusStore.matches.isEmpty
    }

    var versusWins: Int { versusStore.winCount }
    var versusLosses: Int { versusStore.lossCount }
    var versusForfeits: Int { versusStore.forfeitCount }
    var versusDraws: Int { versusStore.drawCount }

    /// Win rate among completed games (W vs L). Excludes draws and forfeits
    /// because those don't represent a head-to-head outcome on score. Nil
    /// when there are no completed games — keeps the UI from showing 0%
    /// during a run of forfeits.
    var versusWinRate: Double? {
        versusStore.winRateAmongCompleted
    }

    /// Most recent N versus matches sorted newest → oldest for the recent
    /// matches list. Pass a variant to filter; nil returns all variants.
    func recentVersusMatches(_ n: Int = 10, variant: VersusVariant? = nil) -> [VersusMatchRecord] {
        let pool = variant.map { versusStore.matches(in: $0) } ?? versusStore.matches
        return Array(
            pool
                .sorted(by: { $0.date > $1.date })
                .prefix(n)
        )
    }

    /// Coop-specific aggregates surfaced in the Coop bucket of the Stats
    /// Versus section. Kept out of the competitive `versusWins/Losses` so
    /// the existing W-L tiles aren't double-counted.
    var coopRunsCompleted: Int { versusStore.coopCompletedCount }
    var coopRunsAbandoned: Int { versusStore.coopAbandonedCount }
    var hasCoopHistory: Bool { coopRunsCompleted + coopRunsAbandoned > 0 }
}
