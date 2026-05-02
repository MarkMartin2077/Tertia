//
//  LockoutProgressBar.swift
//  Tertia
//
//  Circular progress dial that ticks down the post-invalid-claim lockout in
//  versus mode. Driven by a TimelineView so it animates smoothly without
//  the model layer having to publish a per-frame value.
//

import SwiftUI

struct LockoutProgressBar: View {
    let endsAt: Date
    let totalDuration: TimeInterval
    var color: Color = .red

    var body: some View {
        TimelineView(.animation) { context in
            let remaining = max(0, endsAt.timeIntervalSince(context.date))
            let progress = max(0, min(1, remaining / totalDuration))
            content(progress: progress, remaining: remaining)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Locked out, please wait")
    }

    private func content(progress: Double, remaining: TimeInterval) -> some View {
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
        .frame(width: 44, height: 44)
        .padding(.bottom, 4)
    }
}

#Preview {
    LockoutProgressBar(
        endsAt: Date().addingTimeInterval(1.5),
        totalDuration: 1.5
    )
}
