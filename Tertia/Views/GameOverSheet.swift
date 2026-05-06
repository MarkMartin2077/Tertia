//
//  GameOverSheet.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI
import UIKit

struct GameOverSheet: View {
    @AppStorage("hasFinishedAnyGame") private var hasFinishedAnyGame: Bool = false

    let mode: GameMode
    let score: Int
    let bestScore: Int?
    let isNewBest: Bool
    var fastestSetSeconds: Double? = nil
    var longestStreak: Int? = nil
    /// Number of cards left on the board when the deck ran out and no trio
    /// remained. Nil when the run ended for another reason (e.g. timer
    /// expiry), in which case the line is hidden.
    var strandedCardCount: Int? = nil
    var totalTriosFound: Int = 0
    var gameDurationSeconds: Double? = nil
    var averageTimeBetweenSetsSeconds: Double? = nil
    /// A valid trio that was on the board when the game ended. Surfaced
    /// for Time Attack runs that expired with zero trios found — the
    /// disclosure button shows the player what they missed so the
    /// game-over screen lands as a teaching moment rather than a wall.
    var missedTrio: [SetCard]? = nil
    let onPlayAgain: () -> Void
    let onChangeMode: () -> Void

    @State private var showsMissedTrio = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.largeTitle.bold())
                // Inflected on the trio count, not the multiplier-weighted
                // score, so the subtitle stays accurate when combos make
                // `score` larger than the number of trios claimed.
                Text("^[You found \(totalTriosFound) trio](inflect: true)")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if mode == .timeAttack {
                    bestScoreBadge
                        .padding(.top, 8)
                }

                statsBadges
                    .padding(.top, 8)

                GameSummaryStats(
                    totalTriosFound: totalTriosFound,
                    gameDurationSeconds: gameDurationSeconds,
                    averageTimeBetweenSetsSeconds: averageTimeBetweenSetsSeconds
                )
                .padding(.top, 12)

                DeckClearedLine(strandedCardCount: strandedCardCount)
                    .padding(.top, 4)

                if let missedTrio {
                    MissedTrioDisclosure(
                        trio: missedTrio,
                        isExpanded: $showsMissedTrio
                    )
                    .padding(.top, 12)
                }
            }

            VStack(spacing: 12) {
                Button(action: onPlayAgain) {
                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onChangeMode) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: onChangeMode) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(16)
            .accessibilityLabel("Close")
        }
        .overlay {
            if mode == .timeAttack && isNewBest && score > 0 {
                ConfettiView()
            }
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            UIAccessibility.post(
                notification: .announcement,
                argument: announcement
            )
            if !hasFinishedAnyGame {
                hasFinishedAnyGame = true
            }
        }
    }

    private var title: String {
        switch mode {
        case .timeAttack: return "Time's Up!"
        default: return "Game Complete"
        }
    }

    private var primaryButtonTitle: String {
        mode == .timeAttack ? "Play Again" : "New Game"
    }

    private var announcement: String {
        var base = "\(title) " + String(localized: "^[You found \(totalTriosFound) trio](inflect: true).")
        if mode == .timeAttack, isNewBest {
            base += " New personal best."
        }
        return base
    }

    @ViewBuilder
    private var statsBadges: some View {
        HStack(spacing: 8) {
            if let seconds = fastestSetSeconds {
                statBadge(
                    icon: "bolt.fill",
                    iconColor: .yellow,
                    text: String(format: "%.1fs fastest", seconds),
                    accessibility: "Fastest trio: \(String(format: "%.1f", seconds)) seconds"
                )
            }
            if let streak = longestStreak {
                statBadge(
                    icon: "flame.fill",
                    iconColor: .orange,
                    text: "×\(streak) best streak",
                    accessibility: "Longest streak: \(streak) trios in a row"
                )
            }
        }
    }

    private func statBadge(icon: String, iconColor: Color, text: String, accessibility: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            Text(text)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(iconColor.opacity(0.15), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibility)
    }

    @ViewBuilder
    private var bestScoreBadge: some View {
        if isNewBest {
            Label("New best!", systemImage: "star.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.15), in: .capsule)
        } else if let best = bestScore, best > 0 {
            Text("Best: \(best)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Time Attack — new best") {
    GameOverSheet(
        mode: .timeAttack,
        score: 8,
        bestScore: 5,
        isNewBest: true,
        onPlayAgain: {},
        onChangeMode: {}
    )
}

#Preview("Time Attack — not a record") {
    GameOverSheet(
        mode: .timeAttack,
        score: 3,
        bestScore: 8,
        isNewBest: false,
        onPlayAgain: {},
        onChangeMode: {}
    )
}

#Preview("Normal mode") {
    GameOverSheet(
        mode: .normal,
        score: 12,
        bestScore: nil,
        isNewBest: false,
        onPlayAgain: {},
        onChangeMode: {}
    )
}

/// Disclosure widget that reveals a valid trio the player missed when
/// time ran out. Collapsed: a teaching CTA. Expanded: three cards laid
/// out as they appeared on the board. Used only for Time Attack runs
/// that expired with zero trios — see `GameOverSheet.missedTrio`.
private struct MissedTrioDisclosure: View {
    let trio: [SetCard]
    @Binding var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "eye.slash.fill" : "eye.fill")
                    Text(isExpanded ? "Hide" : "See a trio you missed")
                        .font(.subheadline.weight(.semibold))
                    if !isExpanded {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .opacity(0.6)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.background.secondary, in: .capsule)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Hide the missed trio" : "See a trio you missed")

            if isExpanded {
                MissedTrioCards(trio: trio)
                    .transition(.opacity)
            }
        }
    }
}

private struct MissedTrioCards: View {
    let trio: [SetCard]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(trio) { card in
                    SetCardView(
                        card: card,
                        isSelected: false,
                        isInvalid: false,
                        action: {}
                    )
                    .frame(width: 76, height: 100)
                    .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)

            Text("These three formed a valid trio.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var accessibilityLabel: String {
        // Pull the per-attribute analysis so VoiceOver gets the same
        // "all same shape, different colors..." reading the player can
        // figure out by looking.
        let analysis = explain(trio)
        let parts = CardAttribute.allCases.compactMap { attribute -> String? in
            guard analysis.outcome(for: attribute) != nil else { return nil }
            return describe(trio, attribute: attribute)
        }
        return "Missed trio: " + parts.joined(separator: ", ") + "."
    }
}

/// Renders one of three states:
/// - nil: hidden (used for timer-driven endings)
/// - 0: "Perfect clear" celebration (green, with seal)
/// - >0: "N cards stranded" status pill (subtle tray icon, info coloring)
///
/// Both states use the same Label structure + capsule background so they
/// visually rhyme — only the tone (celebratory vs informational) differs.
struct DeckClearedLine: View {
    let strandedCardCount: Int?

    @ViewBuilder
    var body: some View {
        if let stranded = strandedCardCount {
            if stranded == 0 {
                Label("Perfect clear — every card found a trio.", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.12), in: .capsule)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                    }
            } else {
                let cardWord = stranded == 1 ? "card" : "cards"
                Label("\(stranded) \(cardWord) stranded with no valid trio.", systemImage: "tray.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.background.secondary, in: .capsule)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
                    }
            }
        }
    }
}
