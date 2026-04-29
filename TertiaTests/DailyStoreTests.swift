//
//  DailyStoreTests.swift
//  TertiaTests
//

import Foundation
import Testing
@testable import Tertia

@Suite("DailyStore")
@MainActor
struct DailyStoreTests {

    private func makeStore(today: Date = .now) -> (DailyStore, UserDefaults, String) {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (DailyStore(userDefaults: defaults), defaults, suiteName)
    }

    @Test("Fresh store has no past records")
    func freshStoreEmptyHistory() {
        let (store, _, _) = makeStore()
        #expect(store.pastRecords.isEmpty)
    }

    @Test("Recording a completion appends to past records")
    func recordAppendsHistory() {
        let (store, _, _) = makeStore()
        store.recordCompletion(score: 5)
        #expect(store.pastRecords.count == 1)
        #expect(store.pastRecords.first?.score == 5)
    }

    @Test("Same-day re-record is ignored in history")
    func sameDayRecordIgnored() {
        let (store, _, _) = makeStore()
        let date = Date()
        store.recordCompletion(score: 5, on: date)
        store.recordCompletion(score: 9, on: date)
        #expect(store.pastRecords.count == 1)
        #expect(store.pastRecords.first?.score == 5)
    }

    @Test("Multiple days append in order")
    func multipleDaysAppend() {
        let (store, _, _) = makeStore()
        let cal = Calendar.current
        let day1 = cal.date(byAdding: .day, value: -2, to: .now)!
        let day2 = cal.date(byAdding: .day, value: -1, to: .now)!
        let day3 = Date()
        store.recordCompletion(score: 3, on: day1)
        store.recordCompletion(score: 5, on: day2)
        store.recordCompletion(score: 7, on: day3)
        #expect(store.pastRecords.map(\.score) == [3, 5, 7])
    }

    @Test("History persists across store instances")
    func historyPersists() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store1 = DailyStore(userDefaults: defaults)
        store1.recordCompletion(score: 6)

        let store2 = DailyStore(userDefaults: defaults)
        #expect(store2.pastRecords.count == 1)
        #expect(store2.pastRecords.first?.score == 6)
    }

    @Test("Clear empties past records")
    func clearWipesHistory() {
        let (store, _, _) = makeStore()
        store.recordCompletion(score: 4)
        store.clear()
        #expect(store.pastRecords.isEmpty)
    }

    @Test("Legacy persisted blob without pastRecords still loads")
    func legacyBlobBackfillsTodayIntoHistory() throws {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        // Simulate a v1 blob from before pastRecords existed.
        let today = Calendar.current.startOfDay(for: .now)
        let legacy: [String: Any?] = [
            "lastPlayedDate": today.timeIntervalSinceReferenceDate,
            "currentStreak": 1,
            "bestStreak": 1,
            "todaysRecord": ["day": today.timeIntervalSinceReferenceDate, "score": 8],
            "dismissedDay": nil
        ]
        // Encode via JSONEncoder by going through Codable directly.
        struct LegacyRecord: Codable { let day: Date; let score: Int }
        struct LegacyPersistable: Codable {
            let lastPlayedDate: Date?
            let currentStreak: Int
            let bestStreak: Int
            let todaysRecord: LegacyRecord?
            let dismissedDay: Date?
        }
        let blob = LegacyPersistable(
            lastPlayedDate: today,
            currentStreak: 1,
            bestStreak: 1,
            todaysRecord: LegacyRecord(day: today, score: 8),
            dismissedDay: nil
        )
        let data = try JSONEncoder().encode(blob)
        defaults.set(data, forKey: "daily.v1")

        let store = DailyStore(userDefaults: defaults)
        #expect(store.todaysRecord?.score == 8)
        #expect(store.pastRecords.count == 1)
        #expect(store.pastRecords.first?.score == 8)
    }
}
