//
//  GameOverSheet.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI
import UIKit

struct GameOverSheet: View {
    let mode: GameMode
    let score: Int
    let bestScore: Int?
    let isNewBest: Bool
    let onPlayAgain: () -> Void
    let onChangeMode: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.largeTitle.bold())
                Text("You found \(score) \(score == 1 ? "set" : "sets")")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if mode == .timeAttack {
                    bestScoreBadge
                        .padding(.top, 8)
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
        var base = "\(title) You found \(score) \(score == 1 ? "set" : "sets")."
        if mode == .timeAttack, isNewBest {
            base += " New personal best."
        }
        return base
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
