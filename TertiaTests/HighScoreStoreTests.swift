//
//  HighScoreStoreTests.swift
//  TertiaTests
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation
import Testing
@testable import Tertia

@Suite("HighScoreStore")
@MainActor
struct HighScoreStoreTests {

    private func makeStore() -> (HighScoreStore, UserDefaults, String) {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (HighScoreStore(userDefaults: defaults), defaults, suiteName)
    }

    @Test("Fresh store has no entries")
    func freshStoreIsEmpty() {
        let (store, _, _) = makeStore()
        #expect(store.entries.isEmpty)
    }

    @Test("Records are appended and sorted by score descending")
    func recordsSortDescending() {
        let (store, _, _) = makeStore()
        store.record(score: 5, durationSeconds: 90)
        store.record(score: 8, durationSeconds: 90)
        store.record(score: 3, durationSeconds: 90)
        #expect(store.entries.count == 3)
        #expect(store.entries.map(\.score) == [8, 5, 3])
    }

    @Test("top(n) returns the top n entries")
    func topNReturnsLeaderboard() {
        let (store, _, _) = makeStore()
        store.record(score: 1, durationSeconds: 90)
        store.record(score: 5, durationSeconds: 90)
        store.record(score: 3, durationSeconds: 90)
        let top = store.top(2)
        #expect(top.count == 2)
        #expect(top.map(\.score) == [5, 3])
    }

    @Test("bestScore filters by duration")
    func bestScoreFiltersByDuration() {
        let (store, _, _) = makeStore()
        store.record(score: 5, durationSeconds: 60)
        store.record(score: 8, durationSeconds: 90)
        store.record(score: 3, durationSeconds: 90)
        #expect(store.bestScore(forDuration: 90) == 8)
        #expect(store.bestScore(forDuration: 60) == 5)
        #expect(store.bestScore(forDuration: 30) == nil)
    }

    @Test("Entries persist across store instances backed by the same UserDefaults")
    func persistsAcrossInstances() {
        let suiteName = "test-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)

        let store1 = HighScoreStore(userDefaults: defaults)
        store1.record(score: 7, durationSeconds: 90)

        let store2 = HighScoreStore(userDefaults: defaults)
        #expect(store2.entries.count == 1)
        #expect(store2.entries.first?.score == 7)
    }

    @Test("clear() removes all entries")
    func clearWipesEntries() {
        let (store, _, _) = makeStore()
        store.record(score: 5, durationSeconds: 90)
        store.clear()
        #expect(store.entries.isEmpty)
    }
}
