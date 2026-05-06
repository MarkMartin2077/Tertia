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
                VersusMatchmakerView(
                    source: source,
                    variant: variant,
                    onMatch: { match in handleMatchFound(match, variant: variant) },
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
                        // New Match" doesn't silently drop you back to Normal.
                        versusFlow = .matchmaker(.intent(.quickMatch), game.variant)
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
            .presentationDetents([.medium, .large])
        }
        .alert(
            "Couldn't find a match",
            isPresented: Binding(
                get: { matchmakingError != nil },
                set: { if !$0 { matchmakingError = nil } }
            ),
            presenting: matchmakingError
        ) { error in
            // Non-Normal variants can hang on a thin matchmaking pool;
            // surface the fallback so the user isn't dead-ended on a
            // mode no one else is currently playing.
            if error.variant != .normal {
                Button("Try Normal instead") {
                    let intent = error.intent
                    matchmakingError = nil
                    startVersus(intent: intent, variant: .normal)
                }
            }
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
            // No specific intent yet — quickMatch is the natural default
            // post-sign-in. The user can still pick a different variant or
            // tap Invite Friend once the sheet is open.
            pendingVersusIntent = .quickMatch
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
    private func handleMatchFound(_ match: GKMatch, variant: VersusVariant) {
        let transport = GKMatchTransport(match: match)
        let session = MatchSession(transport: transport)
        session.start()

        let local = GKLocalPlayer.local
        let remote = match.players.first
        let game = VersusGame(
            session: session,
            variant: variant,
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
        // Capture the in-flight variant + intent before tearing the flow
        // down so the alert can offer a "Try Normal instead" recovery.
        // Invite-driven flows can't fall back (the invite is to a
        // specific friend with a specific variant), so the fallback is
        // gated to intent-driven flows only.
        var fallbackVariant: VersusVariant = .normal
        var fallbackIntent: VersusMatchIntent = .quickMatch
        if case .matchmaker(let source, let variant) = versusFlow {
            fallbackVariant = variant
            if case .intent(let intent) = source {
                fallbackIntent = intent
            }
        }
        versusFlow = nil
        matchmakingError = MatchmakingError(
            message: error.localizedDescription,
            variant: fallbackVariant,
            intent: fallbackIntent
        )
    }
}

/// Pulled out of `String?` so the alert can offer a variant-aware
/// "Try Normal instead" recovery without losing the original intent
/// (Quick Match vs Invite Friend).
private struct MatchmakingError: Identifiable {
    let id = UUID()
    let message: String
    let variant: VersusVariant
    let intent: VersusMatchIntent
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
