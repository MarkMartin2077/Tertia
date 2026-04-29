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

    static func populateIfRequested(highScores: HighScoreStore, daily: DailyStore) {
        guard CommandLine.arguments.contains(launchArgument) else { return }
        populate(highScores: highScores, daily: daily)
    }

    /// Curated mock state — believable, varied, demonstrates the chart shapes.
    /// - Time Attack: 11 runs over the last 28 days, peaking at 16 trios.
    /// - Daily: 21 completions over the last 30 days. Best streak is 7;
    ///   today's a 5-day streak (5 consecutive completions ending today).
    private static func populate(highScores: HighScoreStore, daily: DailyStore) {
        // Reset to a clean slate so repeat launches don't accumulate.
        highScores.clear()
        daily.clear()

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
    }
}
