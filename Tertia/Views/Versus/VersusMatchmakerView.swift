//
//  VersusMatchmakerView.swift
//  Tertia
//
//  Bridges GKMatchmakerViewController into SwiftUI. The matchmaker UI itself
//  is owned by Apple — we either configure a fresh GKMatchRequest (Quick
//  Match / Invite Friend, kicked off from inside the app) or hand off an
//  inbound `GKInvite` the local player just accepted from Messages.
//  Either way, the resulting `GKMatch` is delivered through the same
//  `onMatch` callback so PlayCoordinator's plumbing stays uniform.
//

import SwiftUI
import GameKit
import OSLog

private let logger = Logger(subsystem: "Mark.Tertia", category: "Matchmaker")

/// Which matchmaking flow the user kicked off. Versus is invite-only —
/// `.inviteFriend` maps to GameKit's `.inviteOnly` matchmaking mode so
/// Apple's picker shows friends rather than auto-matching strangers.
/// The enum stays an enum for future extensibility (e.g., a per-variant
/// "spectate" mode) but currently has a single case.
enum VersusMatchIntent: String, Identifiable, Equatable {
    case inviteFriend

    var id: String { rawValue }

    fileprivate var matchmakingMode: GKMatchmakingMode {
        switch self {
        case .inviteFriend: return .inviteOnly
        }
    }
}

/// What seeds the matchmaker. Either a fresh request (we initiated) or an
/// invite the local player accepted (they were invited by someone else).
enum VersusMatchmakerSource {
    case intent(VersusMatchIntent)
    case acceptedInvite(GKInvite)

    /// True when this source comes from a friend invite — the local
    /// player didn't pick a variant; the inviter did. Used to flag the
    /// resulting `VersusGame` so it adopts the variant from the
    /// inviter's first `matchConfirmation`.
    var isAcceptedInvite: Bool {
        if case .acceptedInvite = self { return true }
        return false
    }
}

struct VersusMatchmakerView: UIViewControllerRepresentable {
    let source: VersusMatchmakerSource
    /// The variant the local player picked. Maps to `GKMatchRequest.playerGroup`
    /// so GameKit auto-matches only peers in the same variant pool. Ignored
    /// for `acceptedInvite` (the invite already negotiated who's playing).
    let variant: VersusVariant
    let onMatch: (GKMatch) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    /// Convenience initializer for the intent-driven flow (Quick Match /
    /// Invite Friend) so existing call sites don't have to spell out the
    /// `.intent(...)` wrapping.
    init(
        intent: VersusMatchIntent,
        variant: VersusVariant = .normal,
        onMatch: @escaping (GKMatch) -> Void,
        onCancel: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.source = .intent(intent)
        self.variant = variant
        self.onMatch = onMatch
        self.onCancel = onCancel
        self.onError = onError
    }

    init(
        source: VersusMatchmakerSource,
        variant: VersusVariant = .normal,
        onMatch: @escaping (GKMatch) -> Void,
        onCancel: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.source = source
        self.variant = variant
        self.onMatch = onMatch
        self.onCancel = onCancel
        self.onError = onError
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController: GKMatchmakerViewController?
        switch source {
        case .intent(let intent):
            let request = GKMatchRequest()
            request.minPlayers = 2
            request.maxPlayers = 2
            // Variant pool gating — only peers who selected the same variant
            // share a playerGroup, so auto-match never crosses modes.
            request.playerGroup = variant.playerGroup
            if intent == .inviteFriend {
                request.inviteMessage = "Race me on Tertia"
            }
            viewController = GKMatchmakerViewController(matchRequest: request)
            viewController?.matchmakingMode = intent.matchmakingMode

        case .acceptedInvite(let invite):
            // Invite-driven path: GameKit already negotiated the players;
            // the matchmaker UI just shows the connecting state until the
            // GKMatch is ready. Variant is whatever the inviter selected;
            // the matchConfirmation handshake (Phase 1) verifies it.
            viewController = GKMatchmakerViewController(invite: invite)
        }

        guard let viewController else {
            // GameKit returns nil only when the request is malformed. Our
            // requests are hardcoded; this is unreachable with current code.
            // Fail loudly in DEBUG so we hear about it if Apple changes the
            // contract; degrade gracefully in production.
            assertionFailure("GKMatchmakerViewController init returned nil")
            logger.error("GKMatchmakerViewController init returned nil — surfacing transient error")
            Task { @MainActor in
                onError(VersusMatchmakerError.initFailed)
            }
            return UIViewController()
        }

        viewController.matchmakerDelegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Matchmaker owns its own state once presented; nothing to push.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onMatch: onMatch, onCancel: onCancel, onError: onError)
    }

    final class Coordinator: NSObject, GKMatchmakerViewControllerDelegate {
        let onMatch: (GKMatch) -> Void
        let onCancel: () -> Void
        let onError: (Error) -> Void

        init(
            onMatch: @escaping (GKMatch) -> Void,
            onCancel: @escaping () -> Void,
            onError: @escaping (Error) -> Void
        ) {
            self.onMatch = onMatch
            self.onCancel = onCancel
            self.onError = onError
        }

        func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            onCancel()
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
            logger.error("Matchmaker failed: \(error.localizedDescription)")
            onError(error)
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
            // Apple's expected pattern: dismiss the matchmaker view controller
            // and *then* operate on the GKMatch. Skipping the explicit dismiss
            // — relying on SwiftUI to tear down the cover when we change the
            // binding — was leaving GKMatchmakerViewController in a half-torn-
            // down state for invite-only flows, which presented as a broken
            // post-accept transition.
            logger.info("Matchmaker found match; dismissing then handing off")
            viewController.dismiss(animated: true) { [weak self] in
                self?.onMatch(match)
            }
        }
    }
}

enum VersusMatchmakerError: LocalizedError {
    case initFailed

    var errorDescription: String? {
        switch self {
        case .initFailed:
            return "Couldn't open the Game Center matchmaker."
        }
    }
}
