//
//  VersusHeroCard.swift
//  Tertia
//
//  Entry point for the 1-on-1 Versus mode. Phase 1 surfaces the card and its
//  two CTAs (Quick Match / Invite Friend); the actual matchmaking and game
//  flow land in later phases. See VERSUS_PLAN.md.
//

import SwiftUI

struct VersusHeroCard: View {
    /// Aggregate wins / losses across all variants. The per-variant
    /// breakdown lives inside `VersusModeSelectView`, surfaced once the
    /// user opens the picker.
    let wins: Int
    let losses: Int
    let onChooseMode: () -> Void

    init(
        wins: Int = 0,
        losses: Int = 0,
        onChooseMode: @escaping () -> Void
    ) {
        self.wins = wins
        self.losses = losses
        self.onChooseMode = onChooseMode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                    Text("Versus")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.teal)

                Spacer()

                Text("LIVE")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.teal.opacity(0.22), in: .capsule)
                    .foregroundStyle(.teal)
            }

            Text("Race a friend")
                .font(.title2.bold())

            VersusSubtitle(wins: wins, losses: losses)

            Button(action: onChooseMode) {
                HStack {
                    Label("Choose a Mode", systemImage: "rectangle.stack.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.7)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.teal.opacity(0.28), .blue.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 20)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.teal.opacity(0.4), lineWidth: 1.5)
        }
    }
}

/// Reads "First to find each trio wins the points" when the player has no
/// versus history; otherwise surfaces W/L counts so the card has personality
/// without leaning on the (Phase 7) full stats integration.
private struct VersusSubtitle: View {
    let wins: Int
    let losses: Int

    var body: some View {
        if wins == 0 && losses == 0 {
            Text("First to spot each trio claims the points.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 20) {
                StatBlock(value: "\(wins)", label: wins == 1 ? "Win" : "Wins", iconColor: .teal)
                StatBlock(
                    value: "\(losses)",
                    label: losses == 1 ? "Loss" : "Losses",
                    iconColor: .secondary
                )
            }
        }
    }
}

private struct StatBlock: View {
    let value: String
    let label: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(iconColor == .secondary ? .secondary : iconColor)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("First time") {
    VersusHeroCard(onChooseMode: {})
        .padding()
}

#Preview("With record") {
    VersusHeroCard(wins: 7, losses: 4, onChooseMode: {})
        .padding()
}
