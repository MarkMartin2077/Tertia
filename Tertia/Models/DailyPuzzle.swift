//
//  DailyPuzzle.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import Foundation

/// Deterministic daily-puzzle deck generation. Same calendar day → same seed →
/// same shuffled deck across all players.
nonisolated enum DailyPuzzle {
    /// Encodes the calendar day as a stable UInt64 seed (YYYYMMDD).
    static func seed(for date: Date, calendar: Calendar = .current) -> UInt64 {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = UInt64(components.year ?? 2026)
        let month = UInt64(components.month ?? 1)
        let day = UInt64(components.day ?? 1)
        return year &* 10000 &+ month &* 100 &+ day
    }

    /// Returns the deterministically shuffled 81-card deck for the given date.
    static func deck(for date: Date, calendar: Calendar = .current) -> [SetCard] {
        var generator = SeededGenerator(seed: seed(for: date, calendar: calendar))
        let allCards: [SetCard] = CardShape.allCases.flatMap { shape in
            CardCount.allCases.flatMap { count in
                CardColor.allCases.flatMap { color in
                    CardFill.allCases.map { fill in
                        SetCard(shape: shape, count: count, color: color, fill: fill)
                    }
                }
            }
        }
        return allCards.shuffled(using: &generator)
    }
}

/// Linear congruential generator. Deterministic, fast, and good enough for
/// shuffling — not for cryptographic use.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xdeadbeef : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
