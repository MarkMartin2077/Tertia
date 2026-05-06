//
//  VersusDealThreeOverlay.swift
//  Tertia
//
//  Pulsing "Deal 3" call-to-action shown over the versus board when no
//  trio is visible and the deck still has cards. Tapping it forwards to
//  `VersusGame.requestDealThree()`.
//

import SwiftUI

struct VersusDealThreeOverlay: View {
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEAL 3")
                        .font(.title3.weight(.heavy))
                        .tracking(2)
                    Text("No trio on the board")
                        .font(.caption.weight(.medium))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(GameMode.versus.accentColor.gradient, in: .rect(cornerRadius: 18))
            .shadow(color: GameMode.versus.accentColor.opacity(0.35), radius: 14, y: 6)
            .scaleEffect(pulse ? 1.04 : 1.0)
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 1.1).repeatCount(3, autoreverses: true),
                value: pulse
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
        }
        .onDisappear { pulse = false }
        .accessibilityLabel("Deal three more cards")
    }
}
