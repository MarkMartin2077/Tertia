//
//  GameDurationSection.swift
//  Tertia
//
//  Game-pace panel: a single chart card with the recent-sessions trend
//  and an average-overlay reference line.
//

import SwiftUI

struct GameDurationSection: View {
    let viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Game Pace", color: .blue, systemImage: "stopwatch")

            ChartCard {
                GameDurationTrendChart(
                    sessions: viewModel.recentGameDurationSessions(),
                    averageDurationSeconds: viewModel.averageGameDurationSeconds
                )
            }
        }
    }
}
