//
//  ScreenshotMockData.swift
//  Tertia
//
//  Populates persistence stores with curated history for App Store screenshot
//  capture. Activated only when the app is launched with the
//  `-screenshotMockData` argument; no-op otherwise.
//

import Foundation

enum ScreenshotMockData {
    static let launchArgument = "-screenshotMockData"

    static func populateIfRequested(
        highScores: HighScoreStore,
        daily: DailyStore,
        sessions: GameSessionStore,
        versus: VersusStore
    ) {
        guard CommandLine.arguments.contains(launchArgument) else { return }
        populate(
            highScores: highScores,
            daily: daily,
            sessions: sessions,
            versus: versus
        )
    }

    /// Curated mock state — believable, varied, demonstrates the chart shapes.
    /// - Time Attack: 11 runs over the last 28 days, peaking at 16 trios.
    /// - Daily: 21 completions over the last 30 days. Best streak is 7;
    ///   today's a 5-day streak (5 consecutive completions ending today).
    /// - Game pace: 14 finished untimed games, durations trending downward as
    ///   the player gets faster.
    /// - Versus: 14 matches over the last 21 days, weighted ~60% wins to
    ///   show the W/L/F/D distribution clearly in screenshots.
    private static func populate(
        highScores: HighScoreStore,
        daily: DailyStore,
        sessions: GameSessionStore,
        versus: VersusStore
    ) {
        // Reset to a clean slate so repeat launches don't accumulate.
        highScores.clear()
        daily.clear()
        sessions.clear()
        versus.clear()

        let cal = Calendar.current
        let now = Date()

        // Time Attack runs (daysAgo, score)
        let runs: [(Int, Int)] = [
            (28, 6), (24, 8), (21, 7), (18, 11), (14, 9),
            (11, 13), (8, 12), (5, 14), (3, 12), (1, 15), (0, 16)
        ]
        for (daysAgo, score) in runs {
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            highScores.record(score: score, durationSeconds: 300, date: date)
        }

        // Daily completions, oldest → newest so streak math accumulates correctly.
        // Designed to yield: best streak 7 (days -16…-10), current streak 5 (days -4…0).
        let dailyOffsets: [(Int, Int)] = [
            (29, 4), (28, 6),                               // 2-day streak
            (24, 5), (23, 7),                               // 2-day streak
            (20, 6), (19, 8),                               // 2-day streak
            (16, 9), (15, 7), (14, 10), (13, 8),            // 7-day streak (best)
            (12, 11), (11, 9), (10, 12),
            (8, 7), (7, 9), (6, 10),                        // 3-day streak
            (4, 11), (3, 9), (2, 12), (1, 10), (0, 13)      // 5-day streak (current)
        ]
        for (daysAgo, score) in dailyOffsets {
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            daily.recordCompletion(score: score, on: date)
        }

        // Game-pace history — 14 untimed games, durations gently trending down.
        let pace: [(daysAgo: Int, mode: GameMode, durationSeconds: Double, trios: Int)] = [
            (27, .normal, 360, 14),
            (24, .daily,  330, 16),
            (21, .normal, 320, 15),
            (19, .daily,  295, 17),
            (16, .normal, 280, 18),
            (14, .daily,  270, 18),
            (12, .normal, 255, 19),
            (10, .daily,  245, 19),
            (8,  .normal, 240, 20),
            (6,  .daily,  230, 20),
            (4,  .normal, 220, 21),
            (3,  .daily,  215, 22),
            (1,  .normal, 205, 22),
            (0,  .daily,  200, 23)
        ]
        for entry in pace {
            guard let date = cal.date(byAdding: .day, value: -entry.daysAgo, to: now) else { continue }
            sessions.record(GameSessionRecord(
                mode: entry.mode,
                durationSeconds: entry.durationSeconds,
                trioCount: entry.trios,
                date: date
            ))
        }

        // Versus matches — believable mix of W/L/F/D so the stats tile row
        // has all four values populated. Opponent names are stable so the
        // recent-matches list reads naturally in screenshots.
        let versusMatches: [(daysAgo: Int, opponent: String, you: Int, them: Int, yourTrios: Int, theirTrios: Int, outcome: VersusOutcome)] = [
            (20, "Casey",  18, 22,  8, 11, .loss),
            (18, "Riley",  24, 16, 12,  8, .win),
            (15, "Casey",  20, 20, 10, 10, .draw),
            (13, "Jordan", 26, 14, 13,  7, .win),
            (11, "Riley",   8, 18,  4,  9, .forfeit),
            (9,  "Sam",    22, 19, 11, 10, .win),
            (7,  "Jordan", 17, 23,  9, 12, .loss),
            (6,  "Casey",  28, 20, 14, 10, .win),
            (5,  "Sam",    21, 21, 11, 11, .draw),
            (4,  "Riley",  19, 25, 10, 12, .loss),
            (3,  "Jordan", 30, 17, 15,  9, .win),
            (2,  "Sam",    25, 23, 13, 12, .win),
            (1,  "Casey",  24, 28, 12, 14, .loss),
            (0,  "Riley",  27, 22, 14, 11, .win)
        ]
        for entry in versusMatches {
            guard let date = cal.date(byAdding: .day, value: -entry.daysAgo, to: now) else { continue }
            versus.record(VersusMatchRecord(
                date: date,
                opponentDisplayName: entry.opponent,
                yourScore: entry.you,
                opponentScore: entry.them,
                yourTrios: entry.yourTrios,
                opponentTrios: entry.theirTrios,
                outcome: entry.outcome
            ))
        }
    }
}
