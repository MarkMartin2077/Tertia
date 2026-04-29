//
//  HighScoreStore.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation
import Observation

struct HighScoreEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let score: Int
    let durationSeconds: Int
    let date: Date

    init(score: Int, durationSeconds: Int, date: Date = .now, id: UUID = UUID()) {
        self.id = id
        self.score = score
        self.durationSeconds = durationSeconds
        self.date = date
    }
}

@Observable
final class HighScoreStore {
    private let userDefaults: UserDefaults
    private let storageKey = "highScores.v1"

    /// Sorted descending by score. First entry is the current best.
    private(set) var entries: [HighScoreEntry] = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func record(score: Int, durationSeconds: Int, date: Date = .now) {
        let entry = HighScoreEntry(score: score, durationSeconds: durationSeconds, date: date)
        entries.append(entry)
        entries.sort { $0.score > $1.score }
        save()
    }

    func top(_ n: Int) -> [HighScoreEntry] {
        Array(entries.prefix(n))
    }

    func bestScore(forDuration durationSeconds: Int) -> Int? {
        entries
            .filter { $0.durationSeconds == durationSeconds }
            .map(\.score)
            .max()
    }

    func clear() {
        entries = []
        userDefaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HighScoreEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
