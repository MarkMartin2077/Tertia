//
//  DailySection.swift
//  Tertia
//
//  Daily Puzzle stats panel: streak / best-streak / best-score tiles
//  plus the streak heatmap and score-trend charts.
//

import SwiftUI

struct DailySection: View {
    let viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Daily Puzzle", color: .purple, systemImage: "calendar")

            HStack(spacing: 16) {
                StatTile(
                    icon: "flame.fill",
                    tint: .orange,
                    value: "\(viewModel.currentStreak)",
                    label: "Day streak"
                )
                StatTile(
                    icon: "trophy.fill",
                    tint: .yellow,
                    value: "\(viewModel.bestStreak)",
                    label: "Best streak"
                )
                StatTile(
                    icon: "star.fill",
                    tint: .purple,
                    value: viewModel.dailyBest.map(String.init) ?? "—",
                    label: "Best score"
                )
            }

            ChartCard {
                DailyStreakChart(records: viewModel.dailyHistory, today: .now)
            }

            ChartCard {
                DailyScoreTrendChart(records: viewModel.dailyHistory)
            }
        }
    }
}
