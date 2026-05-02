//
//  VersusGameOverSheet.swift
//  Tertia
//
//  End-of-match sheet for versus mode. Renders the outcome banner, both
//  players' detailed stats, and a rematch state machine driven by
//  VersusGame.rematchState.
//

import SwiftUI

struct VersusGameOverSheet: View {
    let game: VersusGame
    let onDone: () -> Void
    let onFindNewMatch: () -> Void

    init(
        game: VersusGame,
        onDone: @escaping () -> Void,
        onFindNewMatch: @escaping () -> Void = {}
    ) {
        self.game = game
        self.onDone = onDone
        self.onFindNewMatch = onFindNewMatch
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(headlineTitle)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(headlineSubtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                PlayerStatColumn(
                    name: game.localDisplayName,
                    score: game.localScore,
                    trios: game.localTrios,
                    longestStreak: game.localLongestStreak,
                    fastestSetSeconds: game.localFastestSetSeconds,
                    tint: GameMode.versus.accentColor
                )
                PlayerStatColumn(
                    name: game.remoteDisplayName,
                    score: game.remoteScore,
                    trios: game.remoteTrios,
                    longestStreak: game.remoteLongestStreak,
                    fastestSetSeconds: game.remoteFastestSetSeconds,
                    tint: .secondary
                )
            }

            RematchActionArea(
                game: game,
                onDone: onDone,
                onFindNewMatch: onFindNewMatch
            )
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityAddTraits(.isModal)
    }

    private var headlineTitle: String {
        switch game.outcome {
        case .win: return "You won!"
        case .loss: return "You lost"
        case .draw: return "Draw"
        case .forfeit: return "You forfeited"
        case .none: return "Match complete"
        }
    }

    private var headlineSubtitle: String {
        switch game.outcome {
        case .win:
            switch game.winSource {
            case .opponentForfeited:
                return "\(game.remoteDisplayName) forfeited."
            case .opponentDisconnected:
                return "\(game.remoteDisplayName) disconnected."
            case .scoreFinal, .none:
                return "Great race vs \(game.remoteDisplayName)."
            }
        case .loss:
            return "\(game.remoteDisplayName) edged you out."
        case .draw:
            return "Tied with \(game.remoteDisplayName)."
        case .forfeit:
            return "\(game.remoteDisplayName) takes the win."
        case .none:
            return ""
        }
    }
}

// MARK: - Per-player stats

private struct PlayerStatColumn: View {
    let name: String
    let score: Int
    let trios: Int
    let longestStreak: Int
    let fastestSetSeconds: Double?
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(name)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text("\(score)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint == .secondary ? .primary : tint)

            VStack(alignment: .leading, spacing: 4) {
                StatLine(icon: "checkmark.seal.fill", color: .teal, label: "^[\(trios) trio](inflect: true)")
                if longestStreak >= 2 {
                    StatLine(
                        icon: "flame.fill",
                        color: .orange,
                        label: "×\(longestStreak) best streak"
                    )
                }
                if let seconds = fastestSetSeconds {
                    StatLine(
                        icon: "bolt.fill",
                        color: .yellow,
                        label: fastestSetText(seconds)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func fastestSetText(_ seconds: Double) -> String {
        seconds.formatted(.number.precision(.fractionLength(1))) + "s fastest"
    }

    private var accessibilitySummary: String {
        var parts = ["\(name): \(score) points"]
        parts.append(String(localized: "^[\(trios) trio](inflect: true)"))
        if longestStreak >= 2 {
            parts.append("Longest streak \(longestStreak)")
        }
        if let seconds = fastestSetSeconds {
            parts.append("Fastest set \(seconds.formatted(.number.precision(.fractionLength(1)))) seconds")
        }
        return parts.joined(separator: ", ")
    }
}

private struct StatLine: View {
    let icon: String
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .imageScale(.small)
                .frame(width: 14)
            Text(label)
                .font(.caption.weight(.medium))
        }
    }
}

// MARK: - Rematch state-driven action area

private struct RematchActionArea: View {
    let game: VersusGame
    let onDone: () -> Void
    let onFindNewMatch: () -> Void

    var body: some View {
        Group {
            switch game.rematchState {
            case .idle:
                IdleActions(game: game, onDone: onDone)
            case .localRequested:
                WaitingActions(game: game, onDone: onDone)
            case .opponentRequested:
                OpponentReadyActions(game: game, onDone: onDone)
            case .agreed:
                // Brief transition state — sheet will dismiss when outcome
                // flips back to nil. Show a placeholder so the buttons don't
                // flash an in-between layout.
                ProgressView("Starting…")
                    .controlSize(.large)
                    .padding()
            case .opponentDeclined:
                DeclinedActions(
                    opponentName: game.remoteDisplayName,
                    onFindNewMatch: onFindNewMatch,
                    onDone: onDone
                )
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.rematchState)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

private struct IdleActions: View {
    let game: VersusGame
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                Task { await game.requestRematch() }
            } label: {
                Label("Rematch", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)

            Button(action: {
                Task { await game.declineRematch() }
                onDone()
            }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

private struct WaitingActions: View {
    let game: VersusGame
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text("Waiting for \(game.remoteDisplayName)…")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.background.secondary, in: .rect(cornerRadius: 12))

            Button(action: {
                Task { await game.declineRematch() }
                onDone()
            }) {
                Text("Cancel and Leave")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

private struct OpponentReadyActions: View {
    let game: VersusGame
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("\(game.remoteDisplayName) is ready to go again.")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.teal)

            Button {
                Task { await game.requestRematch() }
            } label: {
                Label("Rematch", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)

            Button(action: {
                Task { await game.declineRematch() }
                onDone()
            }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

private struct DeclinedActions: View {
    let opponentName: String
    let onFindNewMatch: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("\(opponentName) left.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Button(action: onFindNewMatch) {
                Label("Find a new match", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)

            Button(action: onDone) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}
