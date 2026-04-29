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

    let onPlay: (GameMode) -> Void

    var body: some View {
        StatsBody(
            viewModel: StatsViewModel(
                highScoreStore: highScoreStore,
                dailyStore: dailyStore
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

// MARK: - Populated state

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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Welcome banner

private struct StatsWelcomeBanner: View {
    let onPlay: (GameMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title)
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your stats live here")
                        .font(.headline)
                    Text("Build a streak with the Daily Puzzle, or chase a high score in Time Attack. The charts below fill in as you go.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                Button {
                    onPlay(.daily)
                } label: {
                    Label("Today's Daily", systemImage: "calendar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.purple)

                Button {
                    onPlay(.timeAttack)
                } label: {
                    Label("Time Attack", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.orange)
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.purple.opacity(0.35), lineWidth: 1.5)
        }
    }
}

// MARK: - Daily section

private struct DailySection: View {
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

// MARK: - Time Attack section

private struct TimeAttackSection: View {
    let viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Time Attack", color: .orange, systemImage: "timer")

            HStack(spacing: 16) {
                StatTile(
                    icon: "infinity",
                    tint: .orange,
                    value: viewModel.timeAttackBest.map(String.init) ?? "—",
                    label: "All time"
                )
                StatTile(
                    icon: "calendar.badge.clock",
                    tint: .orange,
                    value: viewModel.timeAttackBestThisWeek.map(String.init) ?? "—",
                    label: "This week"
                )
                StatTile(
                    icon: "sun.max.fill",
                    tint: .orange,
                    value: viewModel.timeAttackBestToday.map(String.init) ?? "—",
                    label: "Today"
                )
            }

            ChartCard {
                TimeAttackTrendChart(entries: viewModel.timeAttackEntries)
            }

            if viewModel.hasTimeAttackHistory {
                TopRunsSection(entries: viewModel.topTimeAttackEntries(5))
            }
        }
    }
}

// MARK: - Reusable bits

private struct SectionHeading: View {
    let title: String
    let color: Color
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(title)
                .font(.title3.bold())
            Spacer()
        }
    }
}

private struct StatTile: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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
}

private struct TopRunsSection: View {
    let entries: [HighScoreEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Time Attack Runs")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(entries.enumerated(), id: \.element.id) { index, entry in
                    StatsRow(rank: index + 1, entry: entry)
                    if index < entries.count - 1 {
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
}

private struct ChartCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(.background, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            }
    }
}

// MARK: - Row

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
            RankBadge(rank: rank)
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
}

private struct RankBadge: View {
    let rank: Int

    var body: some View {
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

#Preview("Empty") {
    StatsView(onPlay: { _ in })
        .environment(HighScoreStore())
        .environment(DailyStore())
}

#Preview("Populated") {
    let highScores = HighScoreStore()
    let calendar = Calendar.current
    for offset in 0..<10 {
        let date = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
        highScores.record(score: Int.random(in: 4...14), durationSeconds: 300, date: date)
    }
    let daily = DailyStore()
    return StatsView(onPlay: { _ in })
        .environment(highScores)
        .environment(daily)
}
