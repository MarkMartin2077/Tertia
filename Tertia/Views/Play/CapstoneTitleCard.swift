//
//  CapstoneTitleCard.swift
//  Tertia
//
//  Created by Mark Martin on 5/17/26.
//

import SwiftUI

/// Brief intro card shown before the capstone (puzzle 10) board reveals.
/// Tone is "you're ready for this" — no intimidation cues, no red accents,
/// no "Final Challenge" framing. The capstone is graduation, not a boss
/// fight. The learner taps "I'm ready" to dismiss — auto-dismissal felt
/// rushed when the eye was still landing on the headline.
struct CapstoneTitleCard: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("You've learned the rules.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Text("The real deal.")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
            Text("A full board. Find one trio.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onContinue) {
                Text("I'm ready")
                    .font(.headline)
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(GameMode.tutorial.accentColor)
            .padding(.top, 8)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 28)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(GameMode.tutorial.accentColor.opacity(0.4), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.1), radius: 14, y: 4)
        .padding(.horizontal, 40)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    CapstoneTitleCard(onContinue: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.955, green: 0.940, blue: 0.910))
}
