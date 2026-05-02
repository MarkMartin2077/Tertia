//
//  GameSessionStoreTests.swift
//  TertiaTests
//

import Foundation
import Testing
@testable import Tertia

@Suite("GameSessionStore")
@MainActor
struct GameSessionStoreTests {

    private func makeStore() -> (GameSessionStore, UserDefaults, String) {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (GameSessionStore(userDefaults: defaults), defaults, suiteName)
    }

    private func makeSession(
        mode: GameMode = .normal,
        durationSeconds: Double = 120,
        trioCount: Int = 8,
        date: Date = .now
    ) -> GameSessionRecord {
        GameSessionRecord(
            mode: mode,
            durationSeconds: durationSeconds,
            trioCount: trioCount,
            date: date
        )
    }

    @Test("Fresh store has no sessions")
    func freshStoreIsEmpty() {
        let (store, _, _) = makeStore()
        #expect(store.sessions.isEmpty)
        #expect(!store.durationTrackedSessions.contains { _ in true })
        #expect(store.averageGameDurationSeconds == nil)
    }

    @Test("record appends sessions in insertion order")
    func recordAppends() {
        let (store, _, _) = makeStore()
        store.record(makeSession(durationSeconds: 100))
        store.record(makeSession(durationSeconds: 200))
        store.record(makeSession(durationSeconds: 300))
        #expect(store.sessions.count == 3)
        #expect(store.sessions.map(\.durationSeconds) == [100, 200, 300])
    }

    @Test("durationTrackedSessions excludes Time Attack")
    func durationTrackedExcludesTimeAttack() {
        let (store, _, _) = makeStore()
        store.record(makeSession(mode: .normal, durationSeconds: 100))
        store.record(makeSession(mode: .timeAttack, durationSeconds: 300))
        store.record(makeSession(mode: .daily, durationSeconds: 200))
        store.record(makeSession(mode: .practice, durationSeconds: 50))

        let tracked = store.durationTrackedSessions
        #expect(tracked.count == 3)
        #expect(!tracked.contains { $0.mode == .timeAttack })
    }

    @Test("averageGameDurationSeconds averages only tracked sessions")
    func averageExcludesTimeAttack() {
        let (store, _, _) = makeStore()
        store.record(makeSession(mode: .normal, durationSeconds: 100))
        store.record(makeSession(mode: .daily,  durationSeconds: 200))
        store.record(makeSession(mode: .timeAttack, durationSeconds: 300))

        // Tracked durations: 100 + 200 = 300, count = 2 → avg 150
        #expect(store.averageGameDurationSeconds == 150)
    }

    @Test("averageGameDurationSeconds is nil when only Time Attack sessions exist")
    func averageNilWhenOnlyTimeAttack() {
        let (store, _, _) = makeStore()
        store.record(makeSession(mode: .timeAttack, durationSeconds: 300))
        #expect(store.averageGameDurationSeconds == nil)
    }

    @Test("Sessions persist across store instances backed by the same UserDefaults")
    func sessionsPersist() {
        let suiteName = "test-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)

        let store1 = GameSessionStore(userDefaults: defaults)
        store1.record(makeSession(durationSeconds: 222, trioCount: 11))

        let store2 = GameSessionStore(userDefaults: defaults)
        #expect(store2.sessions.count == 1)
        #expect(store2.sessions.first?.durationSeconds == 222)
        #expect(store2.sessions.first?.trioCount == 11)
    }

    @Test("clear empties the store and persistence")
    func clearEmpties() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        store.record(makeSession())
        store.clear()
        #expect(store.sessions.isEmpty)

        // Reload from persistence to confirm the underlying blob is gone.
        let reloaded = GameSessionStore(userDefaults: defaults)
        #expect(reloaded.sessions.isEmpty)
    }

    @Test("Older entries fall off when the history limit is exceeded")
    func historyLimitTrimsOldest() {
        let (store, _, _) = makeStore()
        // historyLimit is 200 — record one extra and confirm the first is dropped.
        for i in 0..<201 {
            store.record(makeSession(durationSeconds: Double(i), trioCount: 1))
        }
        #expect(store.sessions.count == 200)
        // The oldest (durationSeconds == 0) should have been dropped; the first
        // surviving entry should be durationSeconds == 1.
        #expect(store.sessions.first?.durationSeconds == 1)
        #expect(store.sessions.last?.durationSeconds == 200)
    }
}
