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
        date: Date = .now,
        variant: VersusVariant = .normal
    ) -> VersusMatchRecord {
        VersusMatchRecord(
            date: date,
            opponentDisplayName: opponent,
            yourScore: you,
            opponentScore: them,
            yourTrios: you / 2,
            opponentTrios: them / 2,
            outcome: outcome,
            variant: variant
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

    // MARK: - Phase 4: variant filtering & persistence

    @Test("Per-variant counts filter by variant")
    func perVariantCounts() {
        let (store, _, _) = makeStore()
        store.record(match(.win, variant: .normal))
        store.record(match(.win, variant: .normal))
        store.record(match(.loss, variant: .normal))
        store.record(match(.win, variant: .firstTo10))
        store.record(match(.loss, variant: .firstTo10))
        store.record(match(.coopCompleted, variant: .coop))
        store.record(match(.coopAbandoned, variant: .coop))

        #expect(store.winCount(in: .normal) == 2)
        #expect(store.lossCount(in: .normal) == 1)
        #expect(store.winCount(in: .firstTo10) == 1)
        #expect(store.lossCount(in: .firstTo10) == 1)
        #expect(store.coopCompletedCount == 1)
        #expect(store.coopAbandonedCount == 1)
    }

    @Test("Aggregate counts ignore coop outcomes")
    func aggregateCountsExcludeCoop() {
        let (store, _, _) = makeStore()
        store.record(match(.win, variant: .normal))
        store.record(match(.coopCompleted, variant: .coop))
        store.record(match(.coopAbandoned, variant: .coop))
        // Coop runs aren't competitive — winCount only sees the .win record.
        #expect(store.winCount == 1)
        #expect(store.lossCount == 0)
        #expect(store.forfeitCount == 0)
    }

    @Test("Records persist their variant across store reload")
    func variantPersistsAcrossReload() {
        let suiteName = "test-variant-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)

        let store1 = VersusStore(userDefaults: defaults)
        store1.record(match(.win, variant: .firstTo10))
        store1.record(match(.coopCompleted, variant: .coop))

        let store2 = VersusStore(userDefaults: defaults)
        #expect(store2.matches.count == 2)
        #expect(store2.matches.first?.variant == .firstTo10)
        #expect(store2.matches.last?.variant == .coop)
    }

    @Test("Pre-Phase 4 records (no variant field) decode as .normal")
    func preExistingRecordsMigrateToNormal() throws {
        // Hand-crafted JSON matching the pre-Phase 4 schema — no variant
        // key. Decoding shouldn't throw, and the missing field should
        // resolve to `.normal` so historic versus matches still surface
        // in the Normal bucket of the picker and stats.
        let legacyJSON = """
        [
          {
            "id": "00000000-0000-0000-0000-000000000001",
            "date": 745977600,
            "opponentDisplayName": "Legacy",
            "yourScore": 21,
            "opponentScore": 18,
            "yourTrios": 7,
            "opponentTrios": 6,
            "outcome": "win"
          }
        ]
        """.data(using: .utf8)!

        let suiteName = "test-legacy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(legacyJSON, forKey: "versus.v1")

        let store = VersusStore(userDefaults: defaults)
        #expect(store.matches.count == 1)
        #expect(store.matches.first?.variant == .normal)
        #expect(store.matches.first?.opponentDisplayName == "Legacy")
        // And the pre-existing record still counts toward Normal-variant
        // win count, so the picker's "12-8 W-L" stat doesn't go missing
        // when a returning user updates the app.
        #expect(store.winCount(in: .normal) == 1)
    }
}
