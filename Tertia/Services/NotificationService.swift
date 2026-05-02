//
//  NotificationService.swift
//  Tertia
//
//  Scaffolding for in-app + push notifications around Versus events
//  (incoming invite, opponent requested rematch, opponent went silent).
//
//  This file is *intentionally* a stub today. Wiring full push delivery
//  requires:
//    1. APNS entitlement in Tertia.entitlements ("aps-environment").
//    2. APNS device-token registration in TertiaApp + AppDelegate adapter.
//    3. Server-side Apple Push payload assembly (likely a small
//       CloudKit / App Server function keyed off Game Center player IDs).
//    4. Optional Live Activity surface for an in-progress invite.
//
//  Keeping the surface small + isolated lets the rest of the app start
//  calling into it (`notify(...)`) without a dependency on any of the
//  delivery infrastructure being built yet.
//

import Foundation
import OSLog
import UserNotifications

private let logger = Logger(subsystem: "Mark.Tertia", category: "Notifications")

/// Reasons we'd ping the player. Mapping → APNS `category` IDs eventually,
/// so each case carries the localized title/body it would surface.
enum VersusNotificationKind {
    case inviteReceived(fromDisplayName: String)
    case rematchRequested(byDisplayName: String)
    case opponentTimedOut(displayName: String)

    var title: String {
        switch self {
        case .inviteReceived: return "Tertia invite"
        case .rematchRequested: return "Rematch?"
        case .opponentTimedOut: return "Match ended"
        }
    }

    var body: String {
        switch self {
        case .inviteReceived(let name):
            return "\(name) wants to race you."
        case .rematchRequested(let name):
            return "\(name) is ready for another round."
        case .opponentTimedOut(let name):
            return "\(name) didn't return in time."
        }
    }
}

@MainActor
@Observable
final class NotificationService {
    /// Whether the user has authorized local notifications. Updated after
    /// `requestAuthorizationIfNeeded()`. Distinct from APNS — this is just
    /// the OS-level permission gate. `nil` means we haven't asked yet.
    private(set) var localAuthorization: UNAuthorizationStatus?

    /// Asks the OS for notification permission if we don't have an answer
    /// yet. Idempotent. TODO: call from `TertiaApp` after the user finishes
    /// onboarding so the prompt lands at a moment they understand the value.
    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        localAuthorization = current.authorizationStatus
        guard current.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            let updated = await center.notificationSettings()
            localAuthorization = updated.authorizationStatus
        } catch {
            logger.error("Notification authorization request failed: \(error.localizedDescription)")
        }
    }

    /// Posts a *local* notification immediately. Useful for foreground
    /// fallbacks while we don't yet have push: e.g., if the app is in the
    /// foreground when a rematch arrives, we can surface a banner anyway.
    /// TODO: gate on whether the relevant screen is already visible — no
    /// point banner-notifying about a rematch the user is already looking at.
    func notify(_ kind: VersusNotificationKind) async {
        guard localAuthorization == .authorized else {
            logger.debug("Skipping notify(\(String(describing: kind))) — not authorized")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Notification post failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Push (TODO)

    /// Placeholder for APNS device-token registration. Real implementation
    /// lives in an `UIApplicationDelegateAdaptor` because SwiftUI's `App`
    /// scene doesn't expose `didRegisterForRemoteNotificationsWithDeviceToken`.
    /// Hook it up when push infrastructure is in place.
    func registerForRemotePush(deviceToken: Data) {
        // TODO: ship Data.base64EncodedString() up to the backend, keyed by
        // GKLocalPlayer.local.gamePlayerID.
        logger.info("Received APNS device token (len=\(deviceToken.count)); upload not implemented yet")
    }
}
