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

    private func makeViewModel() -> (StatsViewModel, HighScoreStore, DailyStore) {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let highScores = HighScoreStore(userDefaults: defaults)
        let daily = DailyStore(userDefaults: defaults)
        let vm = StatsViewModel(highScoreStore: highScores, dailyStore: daily)
        return (vm, highScores, daily)
    }

    @Test("Empty state reports no history")
    func empty() {
        let (vm, _, _) = makeViewModel()
        #expect(!vm.hasDailyHistory)
        #expect(!vm.hasTimeAttackHistory)
        #expect(vm.timeAttackBest == nil)
    }

    @Test("Daily history surfaces from store")
    func dailyHistory() {
        let (vm, _, daily) = makeViewModel()
        let earlier = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        daily.recordCompletion(score: 3, on: earlier)
        daily.recordCompletion(score: 5, on: .now)
        #expect(vm.hasDailyHistory)
        #expect(vm.dailyHistory.count == 2)
        #expect(vm.currentStreak == 2)
    }

    @Test("Time Attack filter ignores other durations")
    func timeAttackFilter() {
        let (vm, scores, _) = makeViewModel()
        scores.record(score: 4, durationSeconds: 90)   // legacy duration
        scores.record(score: 7, durationSeconds: 300)
        scores.record(score: 9, durationSeconds: 300)
        #expect(vm.hasTimeAttackHistory)
        #expect(vm.timeAttackEntries.count == 2)
        #expect(vm.timeAttackBest == 9)
    }

    @Test("Top entries are ordered by score descending and capped")
    func topEntriesOrdered() {
        let (vm, scores, _) = makeViewModel()
        for value in [4, 12, 7, 1, 9, 6] {
            scores.record(score: value, durationSeconds: 300)
        }
        let top = vm.topTimeAttackEntries(3)
        #expect(top.count == 3)
        #expect(top.map(\.score) == [12, 9, 7])
    }
}
