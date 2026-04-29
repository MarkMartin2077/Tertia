//
//  DailyStore.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation
import Observation

struct DailyRecord: Codable, Equatable {
    /// Start-of-day for the calendar day this record applies to.
    let day: Date
    let score: Int
}

@Observable
final class DailyStore {
    private let userDefaults: UserDefaults
    private let storageKey = "daily.v1"
    private let calendar: Calendar

    private(set) var lastPlayedDate: Date?
    private(set) var currentStreak: Int = 0
    private(set) var bestStreak: Int = 0
    private(set) var todaysRecord: DailyRecord?
    private(set) var dismissedDay: Date?

    /// All completed daily runs, ordered oldest → newest. Capped at
    /// `historyLimit` entries; older entries fall off the back. Today's record
    /// is mirrored here once `recordCompletion` runs, so charts can treat
    /// `pastRecords` as the full source of truth.
    private(set) var pastRecords: [DailyRecord] = []

    private let historyLimit = 365

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        load()
        rolloverIfNeeded()
    }

    var hasPlayedToday: Bool {
        todaysRecord != nil
    }

    var isHeroDismissedToday: Bool {
        guard let dismissedDay else { return false }
        return calendar.isDateInToday(dismissedDay)
    }

    func dismissHeroForToday(on date: Date = .now) {
        dismissedDay = calendar.startOfDay(for: date)
        save()
    }

    /// Streak shown to the user. Returns 0 if the user has skipped a day, even
    /// if `currentStreak` still holds the prior value.
    var displayedStreak: Int {
        guard let last = lastPlayedDate else { return 0 }
        let today = calendar.startOfDay(for: .now)
        let lastDay = calendar.startOfDay(for: last)
        let daysSince = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return daysSince <= 1 ? currentStreak : 0
    }

    /// Records a completed daily run. First completion of a given day wins —
    /// subsequent completions for the same day are ignored.
    func recordCompletion(score: Int, on date: Date = .now) {
        let dayStart = calendar.startOfDay(for: date)

        if let last = lastPlayedDate, calendar.isDate(last, inSameDayAs: dayStart) {
            return
        }

        if let last = lastPlayedDate {
            let lastDay = calendar.startOfDay(for: last)
            let daysSince = calendar.dateComponents([.day], from: lastDay, to: dayStart).day ?? 0
            if daysSince == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        bestStreak = max(bestStreak, currentStreak)
        lastPlayedDate = dayStart
        let record = DailyRecord(day: dayStart, score: score)
        todaysRecord = record
        appendToHistory(record)
        save()
    }

    private func appendToHistory(_ record: DailyRecord) {
        pastRecords.append(record)
        if pastRecords.count > historyLimit {
            pastRecords.removeFirst(pastRecords.count - historyLimit)
        }
    }

    func clear() {
        lastPlayedDate = nil
        currentStreak = 0
        bestStreak = 0
        todaysRecord = nil
        dismissedDay = nil
        pastRecords = []
        userDefaults.removeObject(forKey: storageKey)
    }

    /// Drops `todaysRecord` if a new calendar day has started since it was set.
    private func rolloverIfNeeded() {
        let today = calendar.startOfDay(for: .now)
        if let record = todaysRecord, !calendar.isDate(record.day, inSameDayAs: today) {
            todaysRecord = nil
        }
        if let day = dismissedDay, !calendar.isDate(day, inSameDayAs: today) {
            dismissedDay = nil
        }
    }

    // MARK: - Persistence

    private struct Persistable: Codable {
        let lastPlayedDate: Date?
        let currentStreak: Int
        let bestStreak: Int
        let todaysRecord: DailyRecord?
        let dismissedDay: Date?
        let pastRecords: [DailyRecord]

        init(
            lastPlayedDate: Date?,
            currentStreak: Int,
            bestStreak: Int,
            todaysRecord: DailyRecord?,
            dismissedDay: Date?,
            pastRecords: [DailyRecord]
        ) {
            self.lastPlayedDate = lastPlayedDate
            self.currentStreak = currentStreak
            self.bestStreak = bestStreak
            self.todaysRecord = todaysRecord
            self.dismissedDay = dismissedDay
            self.pastRecords = pastRecords
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.lastPlayedDate = try c.decodeIfPresent(Date.self, forKey: .lastPlayedDate)
            self.currentStreak = try c.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
            self.bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
            self.todaysRecord = try c.decodeIfPresent(DailyRecord.self, forKey: .todaysRecord)
            self.dismissedDay = try c.decodeIfPresent(Date.self, forKey: .dismissedDay)
            self.pastRecords = try c.decodeIfPresent([DailyRecord].self, forKey: .pastRecords) ?? []
        }
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Persistable.self, from: data) else {
            return
        }
        lastPlayedDate = decoded.lastPlayedDate
        currentStreak = decoded.currentStreak
        bestStreak = decoded.bestStreak
        todaysRecord = decoded.todaysRecord
        dismissedDay = decoded.dismissedDay
        pastRecords = decoded.pastRecords

        // Backfill: existing users have a todaysRecord but no pastRecords entry
        // for it. Promote it so charts have at least one data point on first
        // launch under this version.
        if pastRecords.isEmpty, let record = todaysRecord {
            pastRecords = [record]
        }
    }

    private func save() {
        let snapshot = Persistable(
            lastPlayedDate: lastPlayedDate,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            todaysRecord: todaysRecord,
            dismissedDay: dismissedDay,
            pastRecords: pastRecords
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
