//
//  VersusHeaderRow.swift
//  Tertia
//
//  Top-of-screen score chips for the versus board. Layout branches by
//  variant:
//   - .normal / .firstTo10: two side-by-side chips (local accent-tinted,
//     remote neutral). FirstTo10 also surfaces a "X / 10" goal indicator
//     under the chips.
//   - .coop: a single shared "Team" chip with the combined score, plus
//     two small contribution badges below for each peer's trio count.
//

import SwiftUI

struct VersusHeaderRow: View {
    let game: VersusGame

    var body: some View {
        VStack(spacing: 8) {
            switch game.variant {
            case .normal:
                competitiveChips
            case .firstTo10:
                competitiveChips
                FirstToTenGoalBar(
                    localTrios: game.localTrios,
                    remoteTrios: game.remoteTrios,
                    threshold: VersusVariant.firstTo10.trioWinThreshold ?? 10,
                    accent: game.variant.accent
                )
            case .coop:
                CoopTeamHeader(game: game)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var competitiveChips: some View {
        HStack(alignment: .top, spacing: 12) {
            VersusScoreChip(
                name: game.localDisplayName,
                score: game.localScore,
                trios: game.localTrios,
                multiplier: game.localMultiplier,
                isLocal: true,
                alignment: .leading,
                accent: game.variant.accent
            )
            VersusScoreChip(
                name: game.remoteDisplayName,
                score: game.remoteScore,
                trios: game.remoteTrios,
                multiplier: game.remoteMultiplier,
                isLocal: false,
                alignment: .trailing,
                accent: game.variant.accent
            )
        }
    }
}

// MARK: - Competitive: two-chip layout

private struct VersusScoreChip: View {
    let name: String
    let score: Int
    let trios: Int
    let multiplier: Int
    /// Drives the visual asymmetry that lets the player locate "me" in a
    /// fast race at a glance — accent-tinted background pill, leading dot
    /// indicator, accent score color. The remote chip is neutral material.
    let isLocal: Bool
    let alignment: HorizontalAlignment
    let accent: Color

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            HStack(spacing: 6) {
                if isLocal {
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(score)")
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(isLocal ? accent : .primary)
                    .contentTransition(.numericText())
                if multiplier > 1 {
                    Text("×\(multiplier)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18), in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: multiplier)
            Text("^[\(trios) trio](inflect: true)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
        .background {
            if isLocal {
                // Accent-tinted glass pill — gives the local chip extra
                // weight without competing with card art on the board.
                RoundedRectangle(cornerRadius: 18)
                    .fill(accent.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(accent.opacity(0.25), lineWidth: 1)
                    }
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = ["\(isLocal ? "You, " : "")\(name): \(score) points"]
        parts.append(String(localized: "^[\(trios) trio](inflect: true)"))
        if multiplier > 1 {
            parts.append("\(multiplier)× combo")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - First-to-N goal indicator

/// Slim bar under the chips for First-to-10. Two parallel progress segments
/// (local + remote) visualize the race to threshold without a numeric
/// readout cluttering the chip area.
private struct FirstToTenGoalBar: View {
    let localTrios: Int
    let remoteTrios: Int
    let threshold: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            progressSegment(progress: progress(for: localTrios), color: accent)
            Text("\(localTrios)–\(remoteTrios)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 44)
            progressSegment(progress: progress(for: remoteTrios), color: .secondary)
                .scaleEffect(x: -1, y: 1, anchor: .center) // mirror toward the right chip
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Race to \(threshold) trios. You \(localTrios), opponent \(remoteTrios).")
    }

    private func progress(for trios: Int) -> Double {
        guard threshold > 0 else { return 0 }
        return min(1.0, Double(trios) / Double(threshold))
    }

    private func progressSegment(progress: Double, color: Color) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.18))
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * progress)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 6)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Coop: shared team chip + contribution badges

private struct CoopTeamHeader: View {
    let game: VersusGame

    private var accent: Color { VersusVariant.coop.accent }

    var body: some View {
        VStack(spacing: 10) {
            teamChip
            contributionRow
        }
    }

    private var teamChip: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .imageScale(.small)
                    .foregroundStyle(accent)
                Text("Team")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(game.teamScore)")
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
                if game.teamMultiplier > 1 {
                    Text("×\(game.teamMultiplier)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18), in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: game.teamMultiplier)
            Text("^[\(game.teamTrios) trio](inflect: true)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(accent.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(accent.opacity(0.3), lineWidth: 1.5)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Team score \(game.teamScore), \(game.teamTrios) trios.")
    }

    private var contributionRow: some View {
        HStack(spacing: 10) {
            ContributionBadge(
                name: game.localDisplayName,
                trios: game.localTrios,
                isLocal: true,
                accent: accent
            )
            ContributionBadge(
                name: game.remoteDisplayName,
                trios: game.remoteTrios,
                isLocal: false,
                accent: accent
            )
        }
    }
}

/// Compact "name: N" badge that runs under the team chip in coop. Local
/// peer gets a small accent dot so a player can still distinguish their
/// own contribution at a glance.
private struct ContributionBadge: View {
    let name: String
    let trios: Int
    let isLocal: Bool
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            if isLocal {
                Circle()
                    .fill(accent)
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)
            }
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text("\(trios)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(isLocal ? accent : .primary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isLocal ? "You" : name): \(trios) trios.")
    }
}
