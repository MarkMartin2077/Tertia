//
//  VersusHeaderRow.swift
//  Tertia
//
//  Two score chips at the top of `VersusGameView` — one for each peer.
//  The local chip gets accent-tinted asymmetry (dot, accent score color,
//  accent pill background) so the player can locate "me" at a glance in
//  a fast race; the remote chip stays neutral material.
//

import SwiftUI

struct VersusHeaderRow: View {
    let game: VersusGame

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VersusScoreChip(
                name: game.localDisplayName,
                score: game.localScore,
                trios: game.localTrios,
                multiplier: game.localMultiplier,
                isLocal: true,
                alignment: .leading
            )
            VersusScoreChip(
                name: game.remoteDisplayName,
                score: game.remoteScore,
                trios: game.remoteTrios,
                multiplier: game.remoteMultiplier,
                isLocal: false,
                alignment: .trailing
            )
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

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

    private var accent: Color { GameMode.versus.accentColor }

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
