//
//  TimerLabel.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct TimerLabel: View {
    let controller: TimeAttackController

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let urgentThreshold: TimeInterval = 10

    var body: some View {
        // TimelineView redraws only this subtree, not the whole board.
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let remaining = controller.remaining
            let isUrgent = remaining <= Self.urgentThreshold && remaining > 0
            let scale = (isUrgent && !reduceMotion) ? pulseScale(at: context.date) : 1.0

            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text(formatTime(remaining))
                    .monospacedDigit()
            }
            .font(.title3.bold())
            .foregroundStyle(isUrgent ? .red : .primary)
            .scaleEffect(scale)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Time remaining")
            .accessibilityValue(accessibilityTimeText(remaining))
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func accessibilityTimeText(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        if total == 0 { return "Time's up" }
        if total < 60 { return "\(total) seconds remaining" }
        return "\(total / 60) minutes \(total % 60) seconds remaining"
    }

    private func pulseScale(at date: Date) -> CGFloat {
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.0)
        let normalized = (sin(phase * 2 * .pi) + 1) / 2  // 0..1
        return 1.0 + 0.06 * CGFloat(normalized)
    }
}

#Preview {
    TimerLabel(controller: TimeAttackController(totalDuration: 12))
        .padding()
}
