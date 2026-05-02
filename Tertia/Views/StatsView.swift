//
//  StatsView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI
import GameKit

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

                VersusSection(viewModel: viewModel)

                GameDurationSection(viewModel: viewModel)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Versus section

private struct VersusSection: View {
    let viewModel: StatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeading(title: "Versus", color: .teal, systemImage: "person.2.fill")
                if let rate = viewModel.versusWinRate {
                    Text(rate.formatted(.percent.precision(.fractionLength(0))) + " win rate")
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.teal.opacity(0.18), in: .capsule)
                }
            }

            if viewModel.hasVersusHistory {
                HStack(spacing: 12) {
                    VersusOutcomeTile(
                        value: viewModel.versusWins,
                        label: "Wins",
                        tint: .green
                    )
                    VersusOutcomeTile(
                        value: viewModel.versusLosses,
                        label: "Losses",
                        tint: .red
                    )
                    VersusOutcomeTile(
                        value: viewModel.versusForfeits,
                        label: "Forfeits",
                        tint: .orange
                    )
                    VersusOutcomeTile(
                        value: viewModel.versusDraws,
                        label: "Draws",
                        tint: .secondary
                    )
                }

                RecentVersusMatchesList(matches: viewModel.recentVersusMatches(8))
            } else {
                VersusEmptyState()
            }
        }
    }
}

private struct VersusOutcomeTile: View {
    let value: Int
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title.bold())
                .monospacedDigit()
                .foregroundStyle(tint == .secondary ? .primary : tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

private struct VersusEmptyState: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(.teal)
                .imageScale(.large)
            Text("Play a versus match to see your record here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct RecentVersusMatchesList: View {
    let matches: [VersusMatchRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Matches")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(matches.enumerated(), id: \.element.id) { index, match in
                    VersusMatchRow(match: match)
                    if index < matches.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(.background, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            }
        }
    }
}

private struct VersusMatchRow: View {
    let match: VersusMatchRecord

    private var opponentName: String {
        match.opponentDisplayName ?? "Opponent"
    }

    private var relativeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: match.date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            VersusOutcomeBadge(outcome: match.outcome)
            VStack(alignment: .leading, spacing: 2) {
                Text(opponentName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(match.yourScore)–\(match.opponentScore)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Text(relativeText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(opponentName), \(outcomeText), score \(match.yourScore) to \(match.opponentScore), \(relativeText)")
    }

    private var outcomeText: String {
        switch match.outcome {
        case .win: return "win"
        case .loss: return "loss"
        case .forfeit: return "forfeit"
        case .draw: return "draw"
        }
    }
}

private struct VersusOutcomeBadge: View {
    let outcome: VersusOutcome

    var body: some View {
        Text(letter)
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(tint, in: .circle)
            .accessibilityHidden(true)
    }

    private var letter: String {
        switch outcome {
        case .win: return "W"
        case .loss: return "L"
        case .forfeit: return "F"
        case .draw: return "D"
        }
    }

    private var tint: Color {
        switch outcome {
        case .win: return .green
        case .loss: return .red
        case .forfeit: return .orange
        case .draw: return .gray
        }
    }
}

// MARK: - Game duration section

private struct GameDurationSection: View {
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .imageScale(.small)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
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

#Preview("Empty") {
    StatsView(onPlay: { _ in })
        .environment(HighScoreStore())
        .environment(DailyStore())
        .environment(GameSessionStore())
        .environment(VersusStore())
        .environment(GameCenterService())
}

#Preview("Populated") {
    let highScores = HighScoreStore()
    let calendar = Calendar.current
    for offset in 0..<10 {
        let date = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
        highScores.record(score: Int.random(in: 4...14), durationSeconds: 300, date: date)
    }
    let daily = DailyStore()
    let sessions = GameSessionStore()
    for offset in 0..<10 {
        let date = calendar.date(byAdding: .day, value: -offset, to: .now) ?? .now
        sessions.record(GameSessionRecord(
            mode: offset.isMultiple(of: 2) ? .normal : .daily,
            durationSeconds: Double.random(in: 90...360),
            trioCount: Int.random(in: 4...20),
            date: date
        ))
    }
    let versus = VersusStore()
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
