//
//  PlayCoordinator.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI
import GameKit

struct PlayCoordinator: View {
    @AppStorage("lastGameMode") private var lastGameModeRaw: String = GameMode.normal.rawValue
    @Binding var requestedMode: GameMode?
    @State private var activeMode: GameMode?
    @State private var versusFlow: VersusFlow?
    @State private var matchmakingError: String?

    init(requestedMode: Binding<GameMode?> = .constant(nil)) {
        self._requestedMode = requestedMode
    }

    var body: some View {
        ModeSelectView(
            lastPlayed: GameMode(rawValue: lastGameModeRaw),
            onSelect: { mode in startMode(mode) },
            onVersus: { intent in versusFlow = .matchmaker(intent) }
        )
        .fullScreenCover(item: $activeMode) { mode in
            GameView(mode: mode, onExit: { activeMode = nil })
        }
        .fullScreenCover(item: $versusFlow) { flow in
            switch flow {
            case .matchmaker(let intent):
                VersusMatchmakerView(
                    intent: intent,
                    onMatch: { match in handleMatchFound(match) },
                    onCancel: { versusFlow = nil },
                    onError: { error in handleMatchmakingError(error) }
                )
                .ignoresSafeArea()
            case .game(let game):
                VersusGameView(
                    game: game,
                    onExit: { versusFlow = nil },
                    onFindNewMatch: {
                        // Replace the current game with a fresh matchmaker
                        // pass on the same cover — single fullScreenCover
                        // handles the handoff without dismiss/present races.
                        versusFlow = .matchmaker(.quickMatch)
                    }
                )
            }
        }
        .alert(
            "Couldn't find a match",
            isPresented: Binding(
                get: { matchmakingError != nil },
                set: { if !$0 { matchmakingError = nil } }
            ),
            presenting: matchmakingError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .onChange(of: requestedMode) { _, newValue in
            if let mode = newValue {
                startMode(mode)
                requestedMode = nil
            }
        }
        .onAppear {
            if let mode = requestedMode {
                startMode(mode)
                requestedMode = nil
            }
        }
    }

    private func startMode(_ mode: GameMode) {
        guard mode != .versus else { return }
        lastGameModeRaw = mode.rawValue
        activeMode = mode
    }

    /// Bridge a freshly-found GKMatch into the model layer. Builds the
    /// transport → session → game stack and replaces the matchmaker on the
    /// same cover with the active game.
    private func handleMatchFound(_ match: GKMatch) {
        let transport = GKMatchTransport(match: match)
        let session = MatchSession(transport: transport)
        session.start()

        let local = GKLocalPlayer.local
        let remote = match.players.first
        let game = VersusGame(
            session: session,
            localDisplayName: local.displayName,
            remoteDisplayName: remote?.displayName ?? "Opponent"
        )
        versusFlow = .game(game)
    }

    private func handleMatchmakingError(_ error: Error) {
        versusFlow = nil
        matchmakingError = error.localizedDescription
    }
}

/// Single-cover state machine for everything Versus. Modeling matchmaker
/// and active game as cases of the same enum lets SwiftUI swap content in
/// place — no dismiss/present race when transitioning from "match found"
/// to gameplay or from "find a new match" back to matchmaker.
private enum VersusFlow: Identifiable {
    case matchmaker(VersusMatchIntent)
    case game(VersusGame)

    var id: String {
        switch self {
        case .matchmaker(let intent): return "matchmaker-\(intent.rawValue)"
        case .game(let game): return "game-\(game.id.uuidString)"
        }
    }
}

#Preview {
    PlayCoordinator()
}
