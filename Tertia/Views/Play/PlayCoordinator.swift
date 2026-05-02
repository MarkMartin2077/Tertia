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
    @Binding var requestedInvite: PendingMatchInvite?
    @State private var activeMode: GameMode?
    @State private var versusFlow: VersusFlow?
    @State private var matchmakingError: String?

    init(
        requestedMode: Binding<GameMode?> = .constant(nil),
        requestedInvite: Binding<PendingMatchInvite?> = .constant(nil)
    ) {
        self._requestedMode = requestedMode
        self._requestedInvite = requestedInvite
    }

    var body: some View {
        ModeSelectView(
            lastPlayed: GameMode(rawValue: lastGameModeRaw),
            onSelect: { mode in startMode(mode) },
            onVersus: { intent in versusFlow = .matchmaker(.intent(intent)) }
        )
        .fullScreenCover(item: $activeMode) { mode in
            GameView(mode: mode, onExit: { activeMode = nil })
        }
        .fullScreenCover(item: $versusFlow) { flow in
            switch flow {
            case .matchmaker(let source):
                VersusMatchmakerView(
                    source: source,
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
                        versusFlow = .matchmaker(.intent(.quickMatch))
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
        .onChange(of: requestedInvite) { _, newValue in
            if let invite = newValue {
                acceptInvite(invite)
                requestedInvite = nil
            }
        }
        .onAppear {
            if let mode = requestedMode {
                startMode(mode)
                requestedMode = nil
            }
            if let invite = requestedInvite {
                acceptInvite(invite)
                requestedInvite = nil
            }
        }
    }

    /// Tears down whatever versus state is on screen and presents the
    /// invite-driven matchmaker. Called when the user accepts a GameKit
    /// invite from Messages — by that point any prior game/match cover is
    /// stale.
    private func acceptInvite(_ pending: PendingMatchInvite) {
        versusFlow = .matchmaker(.acceptedInvite(pending.invite))
    }

    private func startMode(_ mode: GameMode) {
        guard mode != .versus else { return }
        lastGameModeRaw = mode.rawValue
        activeMode = mode
    }

    /// Bridge a freshly-found GKMatch into the model layer. Builds the
    /// transport → session → game stack, then transitions the cover from
    /// matchmaker to game.
    ///
    /// Two-step transition (clear flow, brief sleep, set to .game) avoids a
    /// race where SwiftUI is still tearing down the matchmaker view
    /// controller while we ask it to show the game. Going directly from
    /// `.matchmaker` to `.game` worked for Quick Match but broke the
    /// post-accept flow for Invite Friend, presumably because GameKit's
    /// invite-only state machine takes longer to clean up.
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

        versusFlow = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            versusFlow = .game(game)
        }
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
    case matchmaker(VersusMatchmakerSource)
    case game(VersusGame)

    var id: String {
        switch self {
        case .matchmaker(let source):
            switch source {
            case .intent(let intent): return "matchmaker-intent-\(intent.rawValue)"
            case .acceptedInvite(let invite): return "matchmaker-invite-\(ObjectIdentifier(invite))"
            }
        case .game(let game):
            return "game-\(game.id.uuidString)"
        }
    }
}

#Preview {
    PlayCoordinator()
}
