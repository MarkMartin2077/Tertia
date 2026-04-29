//
//  StatsView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct StatsView: View {
    @Environment(HighScoreStore.self) private var highScoreStore
    @Environment(DailyStore.self) private var dailyStore

    let onPlayTimeAttack: () -> Void

    @State private var viewModel: StatsViewModel?

    var body: some View {
        NavigationStack {
            content
                .boardBackground()
                .navigationTitle("Stats")
                .onAppear {
                    if viewModel == nil {
                        viewModel = StatsViewModel(
                            highScoreStore: highScoreStore,
                            dailyStore: dailyStore
                        )
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            if !viewModel.hasDailyHistory && !viewModel.hasTimeAttackHistory {
                emptyState
            } else {
                populatedScroll(viewModel: viewModel)
            }
        }
    }

    private func populatedScroll(viewModel: StatsViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                streakSummary(viewModel: viewModel)

                DailyStreakChart(
                    records: viewModel.dailyHistory,
                    today: .now
                )
                .card()

                TimeAttackTrendChart(entries: viewModel.timeAttackEntries)
                    .card()

                if viewModel.hasTimeAttackHistory {
                    recentRunsSection(viewModel: viewModel)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    private func streakSummary(viewModel: StatsViewModel) -> some View {
        HStack(spacing: 16) {
            statTile(
                icon: "flame.fill",
                tint: .orange,
                value: "\(viewModel.currentStreak)",
                label: viewModel.currentStreak == 1 ? "Day streak" : "Day streak"
            )
            statTile(
                icon: "trophy.fill",
                tint: .yellow,
                value: "\(viewModel.bestStreak)",
                label: "Best streak"
            )
            if let best = viewModel.timeAttackBest {
                statTile(
                    icon: "timer",
                    tint: .orange,
                    value: "\(best)",
                    label: "TA best"
                )
            }
        }
    }

    private func statTile(icon: String, tint: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }

    private func recentRunsSection(viewModel: StatsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Time Attack Runs")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(viewModel.topTimeAttackEntries(5).enumerated()), id: \.element.id) { index, entry in
                    StatsRow(rank: index + 1, entry: entry)
                    if index < viewModel.topTimeAttackEntries(5).count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.background, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            VStack(spacing: 6) {
                Text("No runs yet")
                    .font(.title2.bold())
                Text("Play Time Attack or the Daily Puzzle to start your stats.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: onPlayTimeAttack) {
                Label("Start Time Attack", systemImage: "timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct StatsRow: View {
    let rank: Int
    let entry: HighScoreEntry

    private var relativeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: entry.date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 16) {
            rankBadge
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.score) \(entry.score == 1 ? "trio" : "trios")")
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(relativeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank). \(entry.score) trios. \(relativeText).")
    }

    @ViewBuilder
    private var rankBadge: some View {
        if rank == 1 {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 32)
        } else {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32)
        }
    }
}

private extension View {
    func card() -> some View {
        self
            .padding(16)
            .background(.background, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            }
    }
}

#Preview("Empty") {
    StatsView(onPlayTimeAttack: {})
        .environment(HighScoreStore())
        .environment(DailyStore())
}

#Preview("Populated") {
    let highScores = HighScoreStore()
    for offset in 0..<10 {
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now)!
        highScores.record(score: Int.random(in: 4...14), durationSeconds: 300, date: date)
    }
    let daily = DailyStore()
    return StatsView(onPlayTimeAttack: {})
        .environment(highScores)
        .environment(daily)
}
