//
//  VersusMatchmakerView.swift
//  Tertia
//
//  Bridges GKMatchmakerViewController into SwiftUI. The matchmaker UI itself
//  is owned by Apple — we configure a GKMatchRequest, present it, and route
//  delegate callbacks back through three closures.
//
//  Phase 3 stops at "match found" — the resulting GKMatch is handed to the
//  caller via `onMatch`, which currently surfaces a placeholder. Phase 4
//  swaps that placeholder for a real VersusGameView.
//

import SwiftUI
import GameKit
import OSLog

private let logger = Logger(subsystem: "Mark.Tertia", category: "Matchmaker")

/// Which matchmaking flow the user kicked off. Mapped to GameKit's
/// `matchmakingMode` so Apple shows the right UI:
/// - `.quickMatch` → automatchOnly (random opponent only)
/// - `.inviteFriend` → inviteOnly (friend picker; no random match-up)
enum VersusMatchIntent: String, Identifiable, Equatable {
    case quickMatch
    case inviteFriend

    var id: String { rawValue }

    fileprivate var matchmakingMode: GKMatchmakingMode {
        switch self {
        case .quickMatch: return .automatchOnly
        case .inviteFriend: return .inviteOnly
        }
    }
}

struct VersusMatchmakerView: UIViewControllerRepresentable {
    let intent: VersusMatchIntent
    let onMatch: (GKMatch) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        if intent == .inviteFriend {
            request.inviteMessage = "Race me on Tertia"
        }

        guard let viewController = GKMatchmakerViewController(matchRequest: request) else {
            // GameKit returns nil only when the request is malformed. Our
            // request is hardcoded; this is unreachable with current code.
            // Fail loudly in DEBUG so we hear about it if Apple changes the
            // contract; degrade gracefully in production.
            assertionFailure("GKMatchmakerViewController init returned nil for a 1v1 request")
            logger.error("GKMatchmakerViewController init returned nil — surfacing transient error")
            Task { @MainActor in
                onError(VersusMatchmakerError.initFailed)
            }
            return UIViewController()
        }

        viewController.matchmakingMode = intent.matchmakingMode
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
            onMatch(match)
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
