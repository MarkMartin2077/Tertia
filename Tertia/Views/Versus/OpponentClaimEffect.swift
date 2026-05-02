//
//  OpponentClaimEffect.swift
//  Tertia
//
//  Renders a floating "ghost trio" overlay when the remote player
//  successfully claims a set. Pulses for the configured duration, fades,
//  and leaves the cleanup to VersusGame's timer.
//
//  Why an overlay instead of animating the actual cards: by the time this
//  view sees the claim, the cards have already been removed from
//  `setGame.boardSlots` (gameplay correctness comes first). Rendering ghost
//  copies in the center of the screen is cleaner than reserving on-board
//  slots for a pure visual effect.
//

import SwiftUI

struct OpponentClaimEffect: View {
    let effect: OpponentClaimEffectState
    let opponentName: String
    let accentColor: Color

    @State private var pulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(effect.cards) { card in
                    SetCardView(
                        card: card,
                        isSelected: false,
                        isInvalid: false,
                        pulsingAttributes: [],
                        pulseToken: 0,
                        isHaloed: true,
                        haloPulseToken: pulse ? 1 : 0,
                        action: {}
                    )
                    .frame(width: 70, height: 96)
                    .allowsHitTesting(false)
                }
            }
            .scaleEffect(pulse ? 1.05 : 1.0)

            Text("\(opponentName) claimed a trio")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accentColor.opacity(0.85), in: .capsule)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(accentColor.opacity(0.6), lineWidth: 2)
        }
        .shadow(color: accentColor.opacity(0.4), radius: 16, y: 4)
        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(opponentName) claimed a trio")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    let cards = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .square, count: .two, color: .green, fill: .empty),
        SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
    ]
    return OpponentClaimEffect(
        effect: OpponentClaimEffectState(cards: cards, claimedBy: "P-2", startedAt: .now),
        opponentName: "Alex",
        accentColor: .teal
    )
    .padding()
}
