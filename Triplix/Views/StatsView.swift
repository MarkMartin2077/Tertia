//
//  StatsView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct StatsView: View {
    @Environment(HighScoreStore.self) private var store

    let onPlayTimeAttack: () -> Void

    private let timeAttackDuration = 90

    private var topScores: [HighScoreEntry] {
        Array(
            store.entries
                .filter { $0.durationSeconds == timeAttackDuration }
                .prefix(5)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if topScores.isEmpty {
                    emptyState
                } else {
                    scoreList
                }
            }
            .navigationTitle("Stats")
        }
    }

    private var scoreList: some View {
        List {
            Section {
                ForEach(Array(topScores.enumerated()), id: \.element.id) { index, entry in
                    StatsRow(rank: index + 1, entry: entry)
                }
            } header: {
                Text("Time Attack · 90s")
            } footer: {
                Text("Top \(topScores.count) of your runs.")
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
                Text("Play Time Attack to set a high score.")
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
                Text("\(entry.score) \(entry.score == 1 ? "set" : "sets")")
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(relativeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank). \(entry.score) sets. \(relativeText).")
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

#Preview("Empty") {
    StatsView(onPlayTimeAttack: {})
        .environment(HighScoreStore())
}

#Preview("Populated") {
    let store = HighScoreStore()
    store.record(score: 8, durationSeconds: 90, date: .now.addingTimeInterval(-3600))
    store.record(score: 5, durationSeconds: 90, date: .now.addingTimeInterval(-86400))
    store.record(score: 3, durationSeconds: 90, date: .now.addingTimeInterval(-86400 * 5))
    return StatsView(onPlayTimeAttack: {})
        .environment(store)
}
