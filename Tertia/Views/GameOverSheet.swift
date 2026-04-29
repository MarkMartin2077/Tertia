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
    let onPlayAgain: () -> Void
    let onChangeMode: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.largeTitle.bold())
                Text("You found \(score) \(score == 1 ? "trio" : "trios")")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if mode == .timeAttack {
                    bestScoreBadge
                        .padding(.top, 8)
                }

                statsBadges
                    .padding(.top, 8)

                DeckClearedLine(strandedCardCount: strandedCardCount)
                    .padding(.top, 4)
            }

            VStack(spacing: 12) {
                Button(action: onPlayAgain) {
                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onChangeMode) {
                    Text("Change Mode")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        var base = "\(title) You found \(score) \(score == 1 ? "trio" : "trios")."
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

/// Renders one of three states:
/// - nil: hidden (used for timer-driven endings)
/// - 0: "Perfect clear" celebration
/// - >0: "N cards stranded with no valid trio"
struct DeckClearedLine: View {
    let strandedCardCount: Int?

    @ViewBuilder
    var body: some View {
        if let stranded = strandedCardCount {
            if stranded == 0 {
                Label("Perfect clear — every card found a trio.", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
            } else {
                Text("Cleared the deck — \(stranded) \(stranded == 1 ? "card" : "cards") stranded with no valid trio.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }
}
