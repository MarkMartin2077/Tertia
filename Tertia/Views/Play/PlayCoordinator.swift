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
    @Environment(GameCenterService.self) private var gameCenter
    @State private var activeMode: GameMode?
    @State private var versusFlow: VersusFlow?
    @State private var matchmakingError: MatchmakingError?
    /// Set when the user taps Versus while signed out of Game Center.
    /// Drives the sign-in prompt; once GC auth succeeds, the mode-select
    /// sheet opens automatically. Holds the intent the user originally
    /// kicked off with so we resume the correct flow post-auth.
    @State private var pendingVersusIntent: VersusMatchIntent?
    @State private var showGameCenterPrompt = false
    /// Drives the bottom-sheet variant picker pushed off the hero card.
    /// User picks variant + intent inside the sheet; on confirm, the sheet
    /// dismisses and the matchmaker fullScreenCover takes over.
    @State private var showModeSelect = false

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
            onVersus: { openVersusModeSelect() }
        )
        .fullScreenCover(item: $activeMode) { mode in
            GameView(mode: mode, onExit: { activeMode = nil })
        }
        .fullScreenCover(item: $versusFlow) { flow in
            switch flow {
            case .matchmaker(let source, let variant):
                let isInviteRecipient = source.isAcceptedInvite
                VersusMatchmakerView(
                    source: source,
                    variant: variant,
                    onMatch: { match in handleMatchFound(match, variant: variant, isInviteRecipient: isInviteRecipient) },
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
                        // Reuse the just-finished match's variant so "Find
                        // New Match" stays in the same mode.
                        versusFlow = .matchmaker(.intent(.inviteFriend), game.variant)
                    }
                )
            }
        }
        .sheet(isPresented: $showModeSelect) {
            VersusModeSelectView(
                onStart: { variant, intent in
                    showModeSelect = false
                    startVersus(intent: intent, variant: variant)
                },
                onCancel: { showModeSelect = false }
            )
            // Large only. The selected card expands to show its full
            // description, so a fixed medium detent risks pushing the
            // action bar off-screen when the third (Co-op) row is the
            // selected one.
            .presentationDetents([.large])
        }
        .alert(
            "Couldn't start match",
            isPresented: Binding(
                get: { matchmakingError != nil },
                set: { if !$0 { matchmakingError = nil } }
            ),
            presenting: matchmakingError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
        .alert(
            "Sign in to Game Center",
            isPresented: $showGameCenterPrompt
        ) {
            Button("Sign in") { attemptSignInAndProceed() }
            Button("Cancel", role: .cancel) { pendingVersusIntent = nil }
        } message: {
            Text("Versus matches use Game Center to find opponents and track your wins. You only need to sign in once.")
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
    ///
    /// Inbound invites default to `.normal` because the invite payload
    /// itself doesn't carry the inviter's variant. If the inviter chose
    /// a non-Normal variant, the matchConfirmation handshake (Phase 1)
    /// will surface a mismatch and decline the match cleanly. Phase 2
    /// limitation; revisit when invite metadata grows a variant field.
    private func acceptInvite(_ pending: PendingMatchInvite) {
        versusFlow = .matchmaker(.acceptedInvite(pending.invite), .normal)
    }

    /// Surfaces the variant picker sheet. Gates on Game Center auth — if
    /// the user isn't signed in, surface the sign-in prompt first; once
    /// auth completes the sheet opens automatically.
    private func openVersusModeSelect() {
        if gameCenter.isAuthenticated {
            showModeSelect = true
        } else {
            // The picker is the only way into Versus, and it's invite-only,
            // so any post-auth resume just reopens the sheet.
            pendingVersusIntent = .inviteFriend
            showGameCenterPrompt = true
        }
    }

    /// Either opens the matchmaker immediately (if Game Center is already
    /// signed in) or stages an inline sign-in prompt and resumes once auth
    /// succeeds. Avoids forcing a sign-in wall at app launch — users only
    /// see the GC ask when they actually try to play Versus.
    private func startVersus(intent: VersusMatchIntent, variant: VersusVariant) {
        if gameCenter.isAuthenticated {
            versusFlow = .matchmaker(.intent(intent), variant)
        } else {
            pendingVersusIntent = intent
            showGameCenterPrompt = true
        }
    }

    /// Kicks off Game Center auth and watches for completion. On success
    /// within a reasonable window, opens the matchmaker for the intent the
    /// user originally tapped. On timeout / decline, drops the pending
    /// intent so a stale auth flip later doesn't pop the matchmaker out
    /// of nowhere.
    private func attemptSignInAndProceed() {
        gameCenter.authenticate()
        Task { @MainActor in
            // Poll briefly while GameKit's auth UI is in front of the user.
            // 30s gives plenty of headroom for the system sheet, the user
            // typing a password, or a slow network handshake.
            for _ in 0..<60 {
                try? await Task.sleep(for: .milliseconds(500))
                if gameCenter.isAuthenticated, pendingVersusIntent != nil {
                    pendingVersusIntent = nil
                    // Variant gets picked inside the sheet. Open the picker
                    // rather than going straight to matchmaker.
                    showModeSelect = true
                    return
                }
            }
            // Window elapsed without auth — drop the pending intent so
            // a future successful auth (e.g., user signs in via Settings
            // an hour later) doesn't surprise-launch the matchmaker.
            pendingVersusIntent = nil
        }
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
    private func handleMatchFound(_ match: GKMatch, variant: VersusVariant, isInviteRecipient: Bool) {
        let transport = GKMatchTransport(match: match)
        let session = MatchSession(transport: transport)
        session.start()

        let local = GKLocalPlayer.local
        let remote = match.players.first
        let game = VersusGame(
            session: session,
            variant: variant,
            // GKInvite doesn't carry the inviter's variant. Invite
            // recipients adopt it from the inviter's first
            // matchConfirmation message; until then the popup is held
            // back so we don't ask "Race Casey?" when they actually
            // chose Co-op.
            awaitingVariantFromPeer: isInviteRecipient,
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
        matchmakingError = MatchmakingError(message: error.localizedDescription)
    }
}

private struct MatchmakingError: Identifiable {
    let id = UUID()
    let message: String
}

/// Single-cover state machine for everything Versus. Modeling matchmaker
/// and active game as cases of the same enum lets SwiftUI swap content in
/// place — no dismiss/present race when transitioning from "match found"
/// to gameplay or from "find a new match" back to matchmaker.
///
/// `matchmaker` carries the chosen variant so it can be stamped onto
/// `GKMatchRequest.playerGroup` and onto the `VersusGame` once a match is
/// found.
private enum VersusFlow: Identifiable {
    case matchmaker(VersusMatchmakerSource, VersusVariant)
    case game(VersusGame)

    var id: String {
        switch self {
        case .matchmaker(let source, let variant):
            switch source {
            case .intent(let intent): return "matchmaker-intent-\(intent.rawValue)-\(variant.rawValue)"
            case .acceptedInvite(let invite): return "matchmaker-invite-\(ObjectIdentifier(invite))-\(variant.rawValue)"
            }
        case .game(let game):
            return "game-\(game.id.uuidString)"
        }
    }
}

#Preview {
    PlayCoordinator()
        .environment(GameCenterService())
}
