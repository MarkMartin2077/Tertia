//
//  TimeAttackSection.swift
//  Tertia
//
//  Time Attack stats panel: best-of tiles, score trend chart, and the
//  top-runs leaderboard. Game Center button surfaces only when
//  authentication has succeeded.
//

import SwiftUI
import GameKit

struct TimeAttackSection: View {
    let viewModel: StatsViewModel
    @Environment(GameCenterService.self) private var gameCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeading(title: "Time Attack", color: .orange, systemImage: "timer")
                if gameCenter.isAuthenticated {
                    Button {
                        GKAccessPoint.shared.trigger(state: .leaderboards) { }
                    } label: {
                        Label("Leaderboard", systemImage: "trophy.fill")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                    .accessibilityLabel("Open Game Center leaderboard")
                }
            }

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
                Text("^[\(entry.score) trio](inflect: true)")
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
        .accessibilityLabel("Rank \(rank). " + String(localized: "^[\(entry.score) trio](inflect: true).") + " \(relativeText).")
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
