//
//  StatsViewModelTests.swift
//  TertiaTests
//

import Foundation
import Testing
@testable import Tertia

@Suite("StatsViewModel")
@MainActor
struct StatsViewModelTests {

    private func makeViewModel() -> (StatsViewModel, HighScoreStore, DailyStore, GameSessionStore, VersusStore) {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let highScores = HighScoreStore(userDefaults: defaults)
        let daily = DailyStore(userDefaults: defaults)
        let sessions = GameSessionStore(userDefaults: defaults)
        let versus = VersusStore(userDefaults: defaults)
        let vm = StatsViewModel(
            highScoreStore: highScores,
            dailyStore: daily,
            sessionStore: sessions,
            versusStore: versus
        )
        return (vm, highScores, daily, sessions, versus)
    }

    @Test("Empty state reports no history")
    func empty() {
        let (vm, _, _, _, _) = makeViewModel()
        #expect(!vm.hasDailyHistory)
        #expect(!vm.hasTimeAttackHistory)
        #expect(vm.timeAttackBest == nil)
    }

    @Test("Daily history surfaces from store")
    func dailyHistory() {
        let (vm, _, daily, _, _) = makeViewModel()
        let earlier = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        daily.recordCompletion(score: 3, on: earlier)
        daily.recordCompletion(score: 5, on: .now)
        #expect(vm.hasDailyHistory)
        #expect(vm.dailyHistory.count == 2)
        #expect(vm.currentStreak == 2)
    }

    @Test("Time Attack filter ignores other durations")
    func timeAttackFilter() {
        let (vm, scores, _, _, _) = makeViewModel()
        scores.record(score: 4, durationSeconds: 90)   // legacy duration
        scores.record(score: 7, durationSeconds: 300)
        scores.record(score: 9, durationSeconds: 300)
        #expect(vm.hasTimeAttackHistory)
        #expect(vm.timeAttackEntries.count == 2)
        #expect(vm.timeAttackBest == 9)
    }

    @Test("Top entries are ordered by score descending and capped")
    func topEntriesOrdered() {
        let (vm, scores, _, _, _) = makeViewModel()
        for value in [4, 12, 7, 1, 9, 6] {
            scores.record(score: value, durationSeconds: 300)
        }
        let top = vm.topTimeAttackEntries(3)
        #expect(top.count == 3)
        #expect(top.map(\.score) == [12, 9, 7])
    }

    @Test("Time-windowed bests filter by today and week")
    func windowedBests() {
        let (vm, scores, _, _, _) = makeViewModel()
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let lastMonth = cal.date(byAdding: .day, value: -40, to: today)!

        scores.record(score: 6, durationSeconds: 300, date: today)
        scores.record(score: 9, durationSeconds: 300, date: yesterday)
        scores.record(score: 14, durationSeconds: 300, date: lastMonth)

        #expect(vm.timeAttackBest == 14)
        #expect(vm.timeAttackBestThisWeek == 9)
        #expect(vm.timeAttackBestToday == 6)
    }

    @Test("Time-windowed bests are nil when window is empty")
    func windowedBestsEmpty() {
        let (vm, scores, _, _, _) = makeViewModel()
        let cal = Calendar.current
        let lastMonth = cal.date(byAdding: .day, value: -40, to: .now)!
        scores.record(score: 7, durationSeconds: 300, date: lastMonth)

        #expect(vm.timeAttackBest == 7)
        #expect(vm.timeAttackBestThisWeek == nil)
        #expect(vm.timeAttackBestToday == nil)
    }

    @Test("Game-duration history surfaces only untimed sessions")
    func gameDurationHistoryFiltersTimedModes() {
        let (vm, _, _, sessions, _) = makeViewModel()
        sessions.record(GameSessionRecord(mode: .normal, durationSeconds: 100, trioCount: 5))
        sessions.record(GameSessionRecord(mode: .timeAttack, durationSeconds: 300, trioCount: 9))
        sessions.record(GameSessionRecord(mode: .daily, durationSeconds: 200, trioCount: 7))

        #expect(vm.hasGameDurationHistory)
        #expect(vm.gameDurationSessions.count == 2)
        #expect(vm.averageGameDurationSeconds == 150)
    }

    @Test("recentGameDurationSessions returns the newest N, oldest first")
    func recentDurationSessionsCappedAndOrdered() {
        let (vm, _, _, sessions, _) = makeViewModel()
        let cal = Calendar.current
        for offset in 0..<5 {
            let date = cal.date(byAdding: .day, value: -offset, to: .now)!
            sessions.record(GameSessionRecord(
                mode: .normal,
                durationSeconds: Double(offset * 10),
                trioCount: 5,
                date: date
            ))
        }
        let recent = vm.recentGameDurationSessions(3)
        #expect(recent.count == 3)
        // Oldest → newest. With offsets 4..0 in the store, the most recent 3
        // are offsets 2, 1, 0; sorted ascending by date that's offset 2 first.
        if let first = recent.first?.date, let last = recent.last?.date {
            #expect(first < last)
        } else {
            Issue.record("recentGameDurationSessions returned without bounds")
        }
    }

    @Test("Versus surfaces forward to the underlying store")
    func versusSurfaces() {
        let (vm, _, _, _, versus) = makeViewModel()
        versus.record(VersusMatchRecord(
            opponentDisplayName: "A",
            yourScore: 20, opponentScore: 18,
            yourTrios: 10, opponentTrios: 9,
            outcome: .win
        ))
        versus.record(VersusMatchRecord(
            opponentDisplayName: "B",
            yourScore: 14, opponentScore: 22,
            yourTrios: 7, opponentTrios: 11,
            outcome: .loss
        ))
        versus.record(VersusMatchRecord(
            opponentDisplayName: "C",
            yourScore: 18, opponentScore: 18,
            yourTrios: 9, opponentTrios: 9,
            outcome: .draw
        ))

        #expect(vm.hasVersusHistory)
        #expect(vm.versusWins == 1)
        #expect(vm.versusLosses == 1)
        #expect(vm.versusDraws == 1)
        #expect(vm.versusForfeits == 0)
        #expect(vm.versusWinRate == 0.5)
    }

    @Test("recentVersusMatches returns newest first, capped to N")
    func recentVersusMatchesOrdered() {
        let (vm, _, _, _, versus) = makeViewModel()
        let cal = Calendar.current
        for offset in 0..<5 {
            let date = cal.date(byAdding: .day, value: -offset, to: .now)!
            versus.record(VersusMatchRecord(
                date: date,
                opponentDisplayName: "Opp\(offset)",
                yourScore: 10, opponentScore: 10,
                yourTrios: 5, opponentTrios: 5,
                outcome: .draw
            ))
        }
        let recent = vm.recentVersusMatches(3)
        #expect(recent.count == 3)
        // Newest → oldest. offset 0 is today; should be first.
        #expect(recent.first?.opponentDisplayName == "Opp0")
        #expect(recent.last?.opponentDisplayName == "Opp2")
    }
}
