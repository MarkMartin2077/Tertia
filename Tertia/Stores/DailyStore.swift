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

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        load()
        rolloverIfNeeded()
    }

    var hasPlayedToday: Bool {
        todaysRecord != nil
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
        todaysRecord = DailyRecord(day: dayStart, score: score)
        save()
    }

    func clear() {
        lastPlayedDate = nil
        currentStreak = 0
        bestStreak = 0
        todaysRecord = nil
        userDefaults.removeObject(forKey: storageKey)
    }

    /// Drops `todaysRecord` if a new calendar day has started since it was set.
    private func rolloverIfNeeded() {
        let today = calendar.startOfDay(for: .now)
        if let record = todaysRecord, !calendar.isDate(record.day, inSameDayAs: today) {
            todaysRecord = nil
        }
    }

    // MARK: - Persistence

    private struct Persistable: Codable {
        let lastPlayedDate: Date?
        let currentStreak: Int
        let bestStreak: Int
        let todaysRecord: DailyRecord?
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
    }

    private func save() {
        let snapshot = Persistable(
            lastPlayedDate: lastPlayedDate,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            todaysRecord: todaysRecord
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
