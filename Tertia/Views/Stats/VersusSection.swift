//
//  VersusSection.swift
//  Tertia
//
//  Versus stats panel: win-rate badge, W/L/F/D outcome tiles, and the
//  recent-matches list. Empty-state copy nudges the user to play their
//  first match if there's nothing to show yet.
//

import SwiftUI

struct VersusSection: View {
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
