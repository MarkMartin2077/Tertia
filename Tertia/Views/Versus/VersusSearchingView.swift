//
//  VersusSearchingView.swift
//  Tertia
//
//  SCAFFOLD — replacement for Apple's bare GKMatchmakerViewController during
//  Quick Match, so the player sees a Tertia-branded "looking for an
//  opponent" screen with an estimated wait, an explicit Cancel, and an
//  optional "play a Practice round while you wait" affordance instead of
//  Apple's dated default sheet.
//
//  This file is intentionally a stub today. Wiring it up requires:
//    1. Driving GKMatchmaker.shared().findMatch(for:withCompletionHandler:)
//       directly from the model layer (no view controller).
//    2. Routing the resulting GKMatch into PlayCoordinator.handleMatchFound,
//       same as the existing post-matchmaker handoff.
//    3. Cancellation must call GKMatchmaker.shared().cancel() to release
//       the matchmaking slot — not just dismiss the view.
//    4. Optional "play Practice while waiting" needs scene state plumbing
//       so the matchmaker keeps running in the background while a single-
//       player game is on top.
//
//  Until that's in place, PlayCoordinator continues to use
//  VersusMatchmakerView (Apple's default UI). This view is not yet wired.
//

import SwiftUI

struct VersusSearchingView: View {
    let onCancel: () -> Void
    /// Optional escape hatch — if non-nil, surfaces a "Practice while you
    /// wait" affordance that opens a single-player Practice game.
    var onPlayPracticeWhileWaiting: (() -> Void)?

    @State private var elapsedSeconds: Int = 0
    @State private var clockTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 18) {
                SearchingPulse()
                Text("Finding an opponent…")
                    .font(.title2.bold())
                Text(elapsedCopy)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel(elapsedAccessibility)
            }

            Spacer()

            VStack(spacing: 12) {
                if let onPlayPracticeWhileWaiting {
                    Button(action: onPlayPracticeWhileWaiting) {
                        Label("Play Practice while you wait", systemImage: "questionmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(GameMode.versus.accentColor)
                }

                Button(role: .cancel, action: onCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            startClock()
        }
        .onDisappear {
            clockTask?.cancel()
            clockTask = nil
        }
    }

    private var elapsedCopy: String {
        if elapsedSeconds < 5 {
            return "Pinging Game Center…"
        }
        let secs = elapsedSeconds
        return "Searching for \(secs)s — most matches connect within 30s."
    }

    private var elapsedAccessibility: String {
        elapsedSeconds == 0
            ? "Searching for an opponent"
            : "Searching for \(elapsedSeconds) seconds"
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                elapsedSeconds += 1
            }
        }
    }
}

private struct SearchingPulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Image(systemName: "person.2.fill")
            .font(.system(size: 64, weight: .semibold))
            .foregroundStyle(GameMode.versus.accentColor)
            .scaleEffect(scale)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                ) {
                    scale = 1.08
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview("Searching") {
    VersusSearchingView(onCancel: {})
}

#Preview("With Practice escape") {
    VersusSearchingView(
        onCancel: {},
        onPlayPracticeWhileWaiting: {}
    )
}
