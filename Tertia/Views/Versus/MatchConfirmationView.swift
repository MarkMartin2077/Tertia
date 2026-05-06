//
//  MatchConfirmationView.swift
//  Tertia
//
//  Pre-game popup shown after GameKit hands the players an opponent.
//  Both peers must accept before the deck is seeded — declining (or
//  letting the timer run out) abandons the match without recording it.
//

import SwiftUI

struct MatchConfirmationView: View {
    let opponentName: String
    let variant: VersusVariant
    let localDecision: MatchConfirmationDecision
    let remoteDecision: MatchConfirmationDecision
    let onAccept: () -> Void
    let onDecline: () -> Void

    /// Convenience initializer that defaults to `.normal` so older preview
    /// blocks and any not-yet-updated call sites keep working.
    init(
        opponentName: String,
        variant: VersusVariant = .normal,
        localDecision: MatchConfirmationDecision,
        remoteDecision: MatchConfirmationDecision,
        onAccept: @escaping () -> Void,
        onDecline: @escaping () -> Void
    ) {
        self.opponentName = opponentName
        self.variant = variant
        self.localDecision = localDecision
        self.remoteDecision = remoteDecision
        self.onAccept = onAccept
        self.onDecline = onDecline
    }

    var body: some View {
        VStack(spacing: 20) {
            MatchConfirmationHeader(opponentName: opponentName, variant: variant)
            MatchConfirmationStatusRow(
                opponentName: opponentName,
                localDecision: localDecision,
                remoteDecision: remoteDecision
            )
            MatchConfirmationActions(
                accent: variant.accent,
                localDecision: localDecision,
                onAccept: onAccept,
                onDecline: onDecline
            )
        }
        .padding(28)
        .frame(maxWidth: 380)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
    }
}

private struct MatchConfirmationHeader: View {
    let opponentName: String
    let variant: VersusVariant

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(variant.accent)
                .accessibilityHidden(true)
            // Variant chip above the title makes the mode unmistakable —
            // the player's last sanity check before accepting.
            Text(variant.shortName.uppercased())
                .font(.caption2.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(variant.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(variant.accent.opacity(0.15), in: .capsule)
            Text("Match found")
                .font(.title2.bold())
            Text(prompt(for: variant))
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func prompt(for variant: VersusVariant) -> String {
        switch variant {
        case .normal:    return "Race \(opponentName)?"
        case .firstTo10: return "First to 10 with \(opponentName)?"
        case .coop:      return "Team up with \(opponentName)?"
        }
    }
}

private struct MatchConfirmationStatusRow: View {
    let opponentName: String
    let localDecision: MatchConfirmationDecision
    let remoteDecision: MatchConfirmationDecision

    var body: some View {
        HStack(spacing: 16) {
            MatchConfirmationStatusBadge(
                label: "You",
                decision: localDecision
            )
            MatchConfirmationStatusBadge(
                label: opponentName,
                decision: remoteDecision
            )
        }
    }
}

private struct MatchConfirmationStatusBadge: View {
    let label: String
    let decision: MatchConfirmationDecision

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconColor)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(statusText)")
    }

    private var iconName: String {
        switch decision {
        case .pending: return "ellipsis.circle"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch decision {
        case .pending: return .secondary
        case .accepted: return .green
        case .declined: return .red
        }
    }

    private var statusText: String {
        switch decision {
        case .pending: return "Deciding…"
        case .accepted: return "Ready"
        case .declined: return "Left"
        }
    }
}

private struct MatchConfirmationActions: View {
    let accent: Color
    let localDecision: MatchConfirmationDecision
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if localDecision == .pending {
                Button(action: onAccept) {
                    Label("Accept", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(accent)

                Button(role: .cancel, action: onDecline) {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                MatchConfirmationWaitingFooter(localDecision: localDecision)
            }
        }
    }
}

private struct MatchConfirmationWaitingFooter: View {
    let localDecision: MatchConfirmationDecision

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.regular)
            Text(localDecision == .accepted ? "Waiting for opponent…" : "Match ending…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
    }
}

#Preview("Both pending") {
    MatchConfirmationView(
        opponentName: "Alex",
        localDecision: .pending,
        remoteDecision: .pending,
        onAccept: {},
        onDecline: {}
    )
    .padding()
}

#Preview("Local accepted, remote pending") {
    MatchConfirmationView(
        opponentName: "Alex",
        localDecision: .accepted,
        remoteDecision: .pending,
        onAccept: {},
        onDecline: {}
    )
    .padding()
}
