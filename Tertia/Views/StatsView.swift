//
//  StatsView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//
//  Top-level Stats tab. Composes the per-mode section views (Daily,
//  Time Attack, Versus, Game Pace) into a single scroll view. Section
//  views and their helpers live alongside this file in `Stats/`.
//

import SwiftUI

struct StatsView: View {
    @Environment(HighScoreStore.self) private var highScoreStore
    @Environment(DailyStore.self) private var dailyStore
    @Environment(GameSessionStore.self) private var sessionStore
    @Environment(VersusStore.self) private var versusStore

    let onPlay: (GameMode) -> Void

    var body: some View {
        StatsBody(
            viewModel: StatsViewModel(
                highScoreStore: highScoreStore,
                dailyStore: dailyStore,
                sessionStore: sessionStore,
                versusStore: versusStore
            ),
            onPlay: onPlay
        )
    }
}

private struct StatsBody: View {
    let viewModel: StatsViewModel
    let onPlay: (GameMode) -> Void

    var body: some View {
        NavigationStack {
            StatsScroll(viewModel: viewModel, onPlay: onPlay)
                .boardBackground()
                .navigationTitle("Stats")
        }
    }
}

private struct StatsScroll: View {
    let viewModel: StatsViewModel
    let onPlay: (GameMode) -> Void

    private var isCompletelyEmpty: Bool {
        !viewModel.hasDailyHistory && !viewModel.hasTimeAttackHistory
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if isCompletelyEmpty {
                    StatsWelcomeBanner(onPlay: onPlay)
                }

                DailySection(viewModel: viewModel)

                TimeAttackSection(viewModel: viewModel)

                VersusSection(viewModel: viewModel)

                GameDurationSection(viewModel: viewModel)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }
}

/// Ephemeral, isolated UserDefaults for previews. The default
/// `UserDefaults.standard` is shared across every preview run AND with the
/// simulator app, so without isolation the "Empty" preview loads whatever
/// data was left behind by a prior "Populated" run, and "Populated" keeps
/// appending across reloads. A unique-suite transient defaults sidesteps
/// both problems.
private func ephemeralDefaults() -> UserDefaults {
    let suiteName = "preview.tertia.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

#Preview("Empty") {
    let defaults = ephemeralDefaults()
    return StatsView(onPlay: { _ in })
        .environment(HighScoreStore(userDefaults: defaults))
        .environment(DailyStore(userDefaults: defaults))
        .environment(GameSessionStore(userDefaults: defaults))
        .environment(VersusStore(userDefaults: defaults))
        .environment(GameCenterService())
}

#Preview("Populated") {
    let defaults = ephemeralDefaults()
    let highScores = HighScoreStore(userDefaults: defaults)
    let calendar = Calendar.current
    for offset in 0..<10 {
        let date = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
        highScores.record(score: Int.random(in: 4...14), durationSeconds: 300, date: date)
    }
    let daily = DailyStore(userDefaults: defaults)
    let sessions = GameSessionStore(userDefaults: defaults)
    for offset in 0..<10 {
        let date = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
        sessions.record(GameSessionRecord(
            mode: offset.isMultiple(of: 2) ? .normal : .daily,
            durationSeconds: Double.random(in: 90...360),
            trioCount: Int.random(in: 4...20),
            date: date
        ))
    }
    let versus = VersusStore(userDefaults: defaults)
    let outcomes: [VersusOutcome] = [.win, .win, .loss, .draw, .win, .forfeit, .win, .loss]
    for (offset, outcome) in outcomes.enumerated() {
        let date = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
        versus.record(VersusMatchRecord(
            date: date,
            opponentDisplayName: ["Casey", "Jordan", "Riley", "Sam"].randomElement(),
            yourScore: Int.random(in: 12...30),
            opponentScore: Int.random(in: 12...30),
            yourTrios: Int.random(in: 6...14),
            opponentTrios: Int.random(in: 6...14),
            outcome: outcome
        ))
    }
    return StatsView(onPlay: { _ in })
        .environment(highScores)
        .environment(daily)
        .environment(sessions)
        .environment(versus)
        .environment(GameCenterService())
}
