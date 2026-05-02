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

    @Environment(FeedbackService.self) private var feedback
    @Environment(VersusStore.self) private var versusStore

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
                    .foregroundStyle(headlineTint)
                    .multilineTextAlignment(.center)
                Text(headlineSubtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let h2h = headToHeadSummary {
                    Text(h2h)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .accessibilityLabel("Series record: \(h2h)")
                }
            }

            HStack(spacing: 16) {
                PlayerStatColumn(
                    name: game.localDisplayName,
                    score: game.localScore,
                    trios: game.localTrios,
                    longestStreak: game.localLongestStreak,
                    fastestSetSeconds: game.localFastestSetSeconds,
                    tint: localColumnTint
                )
                PlayerStatColumn(
                    name: game.remoteDisplayName,
                    score: game.remoteScore,
                    trios: game.remoteTrios,
                    longestStreak: game.remoteLongestStreak,
                    fastestSetSeconds: game.remoteFastestSetSeconds,
                    tint: remoteColumnTint
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
        .overlay(alignment: .top) {
            // Confetti is purely celebratory — only render on a true win.
            // `.opponentForfeited` / `.opponentDisconnected` wins still get
            // confetti because the local player technically won.
            if game.outcome == .win {
                ConfettiView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            playOutcomeFeedback()
        }
    }

    private var headlineTitle: String {
        switch game.outcome {
        case .win: return "You won!"
        case .loss: return "You lost"
        case .draw: return "Draw"
        case .forfeit: return "Match ended"
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

    /// "3-2 vs Alex" — pulled from VersusStore by opponent display name.
    /// Returns nil when this is the first match against this opponent (don't
    /// show "0-0" — feels weird as a hero stat).
    private var headToHeadSummary: String? {
        let h2h = versusStore.headToHead(against: game.remoteDisplayName)
        guard h2h.wins + h2h.losses > 0 else { return nil }
        return "\(h2h.wins)-\(h2h.losses) vs \(game.remoteDisplayName)"
    }

    /// Title color shifts with outcome — we want the screen to *feel*
    /// different on win vs loss vs forfeit, not just the words to differ.
    private var headlineTint: Color {
        switch game.outcome {
        case .win: return GameMode.versus.accentColor
        case .loss: return .secondary
        case .draw: return .primary
        case .forfeit: return .secondary
        case .none: return .primary
        }
    }

    /// Local column wears the accent on win/draw; on loss/forfeit the accent
    /// shifts to the remote column so the visual energy points at whoever
    /// actually came out ahead.
    private var localColumnTint: Color {
        switch game.outcome {
        case .win, .draw: return GameMode.versus.accentColor
        case .loss, .forfeit, .none: return .secondary
        }
    }

    private var remoteColumnTint: Color {
        switch game.outcome {
        case .loss, .forfeit: return GameMode.versus.accentColor
        case .win, .draw, .none: return .secondary
        }
    }

    private func playOutcomeFeedback() {
        switch game.outcome {
        case .win: feedback.personalBest()
        case .loss, .forfeit: feedback.timerExpired()
        case .draw: feedback.timerWarning()
        case .none: break
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
                        // String literal so it coerces to LocalizedStringKey
                        // — passing a String variable to a LocalizedStringKey
                        // parameter doesn't compile.
                        label: "\(seconds.formatted(.number.precision(.fractionLength(1))))s fastest"
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
    /// `LocalizedStringKey` so `Text(label)` runs the value through the
    /// localization machinery — required for `^[…](inflect: true)` markdown
    /// to actually pluralize. A `String` parameter would resolve to the
    /// `Text(_ verbatim:)` overload and render the markdown literally.
    let label: LocalizedStringKey

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
            // Once the session is dead, no rematch handshake can succeed —
            // skip the in-flight states (idle/localRequested/opponentRequested)
            // and show the "find a new match" path immediately. `.agreed`
            // is a brief transition state we leave alone; if the session
            // dies mid-rematch the new game will fail through its own path.
            if !game.isSessionConnected, game.rematchState != .agreed {
                ConnectionLostActions(
                    opponentName: game.remoteDisplayName,
                    onFindNewMatch: onFindNewMatch,
                    onDone: onDone
                )
            } else {
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
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.rematchState)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.isSessionConnected)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

private struct ConnectionLostActions: View {
    let opponentName: String
    let onFindNewMatch: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "wifi.exclamationmark")
                Text("Connection to \(opponentName) lost.")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.orange)

            Button(action: onFindNewMatch) {
                Label("Find a new match", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(GameMode.versus.accentColor)

            Button(action: onDone) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
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
            .tint(GameMode.versus.accentColor)

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
            .foregroundStyle(GameMode.versus.accentColor)

            Button {
                Task { await game.requestRematch() }
            } label: {
                // Different verb than the idle "Rematch" so the relationship
                // between the message above and the action is unmistakable.
                Label("Accept Rematch", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(GameMode.versus.accentColor)

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
            .tint(GameMode.versus.accentColor)

            Button(action: onDone) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}
