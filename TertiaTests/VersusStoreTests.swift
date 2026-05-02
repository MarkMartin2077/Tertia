//
//  VersusStoreTests.swift
//  TertiaTests
//

import Foundation
import Testing
@testable import Tertia

@Suite("VersusStore")
@MainActor
struct VersusStoreTests {

    private func makeStore() -> (VersusStore, UserDefaults, String) {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (VersusStore(userDefaults: defaults), defaults, suiteName)
    }

    private func match(
        _ outcome: VersusOutcome,
        opponent: String = "Casey",
        you: Int = 20,
        them: Int = 18,
        date: Date = .now
    ) -> VersusMatchRecord {
        VersusMatchRecord(
            date: date,
            opponentDisplayName: opponent,
            yourScore: you,
            opponentScore: them,
            yourTrios: you / 2,
            opponentTrios: them / 2,
            outcome: outcome
        )
    }

    @Test("Fresh store has no matches and zero counts")
    func freshStoreIsEmpty() {
        let (store, _, _) = makeStore()
        #expect(store.matches.isEmpty)
        #expect(store.winCount == 0)
        #expect(store.lossCount == 0)
        #expect(store.forfeitCount == 0)
        #expect(store.drawCount == 0)
        #expect(store.winRateAmongCompleted == nil)
    }

    @Test("record appends in insertion order")
    func recordAppends() {
        let (store, _, _) = makeStore()
        store.record(match(.win, opponent: "A"))
        store.record(match(.loss, opponent: "B"))
        store.record(match(.draw, opponent: "C"))
        #expect(store.matches.count == 3)
        #expect(store.matches.map(\.opponentDisplayName) == ["A", "B", "C"])
    }

    @Test("Per-outcome counts reflect recorded matches")
    func perOutcomeCounts() {
        let (store, _, _) = makeStore()
        store.record(match(.win))
        store.record(match(.win))
        store.record(match(.loss))
        store.record(match(.forfeit))
        store.record(match(.draw))
        #expect(store.winCount == 2)
        #expect(store.lossCount == 1)
        #expect(store.forfeitCount == 1)
        #expect(store.drawCount == 1)
    }

    @Test("winRateAmongCompleted divides W by W+L, ignoring draws and forfeits")
    func winRateMath() {
        let (store, _, _) = makeStore()
        store.record(match(.win))
        store.record(match(.win))
        store.record(match(.win))
        store.record(match(.loss))
        store.record(match(.draw))
        store.record(match(.forfeit))
        // 3 wins, 1 loss → 75%
        #expect(store.winRateAmongCompleted == 0.75)
    }

    @Test("winRateAmongCompleted is nil when no completed games exist")
    func winRateNilWhenOnlyDrawsAndForfeits() {
        let (store, _, _) = makeStore()
        store.record(match(.draw))
        store.record(match(.forfeit))
        #expect(store.winRateAmongCompleted == nil)
    }

    @Test("Matches persist across store instances backed by the same UserDefaults")
    func matchesPersist() {
        let suiteName = "test-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)

        let store1 = VersusStore(userDefaults: defaults)
        store1.record(match(.win, opponent: "Sam", you: 24, them: 17))

        let store2 = VersusStore(userDefaults: defaults)
        #expect(store2.matches.count == 1)
        #expect(store2.matches.first?.opponentDisplayName == "Sam")
        #expect(store2.matches.first?.yourScore == 24)
        #expect(store2.winCount == 1)
    }

    @Test("clear empties the store and persistence")
    func clearEmpties() {
        let (store, defaults, suiteName) = makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        store.record(match(.win))
        store.clear()
        #expect(store.matches.isEmpty)

        let reloaded = VersusStore(userDefaults: defaults)
        #expect(reloaded.matches.isEmpty)
    }

    @Test("Older entries fall off when the history limit is exceeded")
    func historyLimitTrimsOldest() {
        let (store, _, _) = makeStore()
        for i in 0..<201 {
            store.record(match(.win, opponent: "Opp\(i)"))
        }
        #expect(store.matches.count == 200)
        // Oldest (Opp0) dropped; first survivor is Opp1.
        #expect(store.matches.first?.opponentDisplayName == "Opp1")
        #expect(store.matches.last?.opponentDisplayName == "Opp200")
    }
}
