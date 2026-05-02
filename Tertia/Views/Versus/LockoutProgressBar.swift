//
//  LockoutProgressBar.swift
//  Tertia
//
//  Circular progress dial that ticks down the post-invalid-claim lockout in
//  versus mode. Driven by a TimelineView so it animates smoothly without
//  the model layer having to publish a per-frame value.
//
//  Pairs the dial with a one-line caption ("Invalid trio — wait a moment")
//  so a player who triggers lockout for the first time understands what
//  happened. The visual alone is silent punishment.
//

import SwiftUI

struct LockoutProgressBar: View {
    let endsAt: Date
    let totalDuration: TimeInterval
    var color: Color = .red
    /// When `true`, render a labeled card rather than the bare dial. Caller
    /// uses this for the first lockout in a match (when the player most
    /// needs the context); subsequent lockouts can render compactly.
    var showsCaption: Bool = true

    var body: some View {
        TimelineView(.animation) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))
            let progress = max(0, min(1, remaining / totalDuration))
            content(progress: progress, remaining: remaining)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(remaining: remaining))
        }
    }

    @ViewBuilder
    private func content(progress: Double, remaining: TimeInterval) -> some View {
        if showsCaption {
            HStack(spacing: 12) {
                dial(progress: progress)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invalid trio")
                        .font(.subheadline.weight(.semibold))
                    Text("Wait a moment before trying again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1)
            }
        } else {
            dial(progress: progress)
                .padding(.bottom, 4)
        }
    }

    private func dial(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: "lock.fill")
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(width: 36, height: 36)
    }

    private func accessibilityLabel(remaining: TimeInterval) -> String {
        let secs = max(0, Int(remaining.rounded(.up)))
        if secs <= 0 {
            return "Lockout ending"
        }
        return "Invalid trio. \(secs) second\(secs == 1 ? "" : "s") remaining."
    }
}

#Preview("With caption") {
    LockoutProgressBar(
        endsAt: Date().addingTimeInterval(1.5),
        totalDuration: 1.5
    )
    .padding()
}

#Preview("Compact") {
    LockoutProgressBar(
        endsAt: Date().addingTimeInterval(1.5),
        totalDuration: 1.5,
        showsCaption: false
    )
    .padding()
}
