//
//  GameSessionStore.swift
//  Tertia
//

import Foundation
import Observation

/// One completed game's high-level stats. Kept lightweight so persistence
/// stays cheap; per-trio detail lives only in `SetGame` while the session
/// is active.
struct GameSessionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let mode: GameMode
    let durationSeconds: Double
    let trioCount: Int
    let date: Date

    init(
        mode: GameMode,
        durationSeconds: Double,
        trioCount: Int,
        date: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.mode = mode
        self.durationSeconds = durationSeconds
        self.trioCount = trioCount
        self.date = date
    }
}

/// Persists completed-game summaries across modes. Time Attack is excluded
/// from the duration history (it's always 5 minutes by design), but the
/// store doesn't enforce that — callers decide what to record.
@MainActor
@Observable
final class GameSessionStore {
    private let userDefaults: UserDefaults
    private let storageKey = "gameSessions.v1"
    private let historyLimit = 200

    /// All recorded sessions, oldest → newest.
    private(set) var sessions: [GameSessionRecord] = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func record(_ session: GameSessionRecord) {
        sessions.append(session)
        if sessions.count > historyLimit {
            sessions.removeFirst(sessions.count - historyLimit)
        }
        save()
    }

    func clear() {
        sessions = []
        userDefaults.removeObject(forKey: storageKey)
    }

    /// Sessions filtered to only modes whose duration is informative for the
    /// "average game time" chart (timer modes always run for the same length).
    var durationTrackedSessions: [GameSessionRecord] {
        sessions.filter { !$0.mode.usesTimer }
    }

    /// Average duration across `durationTrackedSessions`. Nil when none exist.
    var averageGameDurationSeconds: Double? {
        let tracked = durationTrackedSessions
        guard !tracked.isEmpty else { return nil }
        let total = tracked.reduce(0.0) { $0 + $1.durationSeconds }
        return total / Double(tracked.count)
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([GameSessionRecord].self, from: data) else {
            return
        }
        sessions = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
