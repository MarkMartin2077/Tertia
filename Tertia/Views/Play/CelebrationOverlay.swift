//
//  CelebrationOverlay.swift
//  Tertia
//
//  Created by Mark Martin on 5/17/26.
//

import SwiftUI

/// Brief non-blocking celebration shown above the board after a correct
/// pick in tutorial mode. Tier mirrors the hint-fade curve — early puzzles
/// get an encouraging text bubble, middle puzzles get only haptic+pulse,
/// and the capstone gets a centered checkmark with optional confetti.
struct CelebrationOverlay: View {
    let level: CelebrationLevel

    var body: some View {
        switch level {
        case .small(let copy):
            smallBubble(copy: copy)
        case .medium:
            // The green selection halo + success haptic carry this tier.
            // No text overlay so puzzles 4–9 don't feel chatty.
            Color.clear
        case .capstone:
            capstoneCelebration
        }
    }

    private func smallBubble(copy: String) -> some View {
        Text(copy)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(GameMode.tutorial.accentColor.opacity(0.5), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .accessibilityLabel(copy)
    }

    private var capstoneCelebration: some View {
        ZStack {
            ConfettiView()
            VStack(spacing: 2) {
                Text("TRIO")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(GameMode.tutorial.accentColor)
                    .tracking(4)
                    .shadow(color: GameMode.tutorial.accentColor.opacity(0.25), radius: 18, y: 4)
                Text("you got it")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
        }
        .accessibilityLabel("Trio found")
    }
}

#Preview("Small") {
    CelebrationOverlay(level: .small(copy: "Nice!"))
}

#Preview("Capstone") {
    CelebrationOverlay(level: .capstone)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.955, green: 0.940, blue: 0.910))
}
