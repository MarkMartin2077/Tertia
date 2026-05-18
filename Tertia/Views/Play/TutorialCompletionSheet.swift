//
//  TutorialCompletionSheet.swift
//  Tertia
//
//  Created by Mark Martin on 5/17/26.
//

import SwiftUI

/// Shown after the player solves the capstone. The conversion moment from
/// "learner" to "player" — direct CTA to Normal, no corporate praise.
struct TutorialCompletionSheet: View {
    let onPlayNormal: () -> Void
    let onBackToMenu: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("You've got it.")
                    .font(.largeTitle.bold())
                Text("Ready for the real thing?")
                    .font(.headline.weight(.regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 12) {
                Button(action: onPlayNormal) {
                    Text("Play Normal")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(GameMode.normal.accentColor)

                Button(action: onBackToMenu) {
                    Text("Back to menu")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    Color.gray
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            TutorialCompletionSheet(
                onPlayNormal: {},
                onBackToMenu: {}
            )
            .presentationDetents([.medium])
        }
}
