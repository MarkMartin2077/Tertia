//
//  GameSummaryStats.swift
//  Tertia
//

import SwiftUI

/// Compact three-up summary shown on every game-over sheet. Hides itself if
/// no trios were found — there's nothing useful to show in that case.
struct GameSummaryStats: View {
    let totalTriosFound: Int
    let gameDurationSeconds: Double?
    let averageTimeBetweenSetsSeconds: Double?

    var body: some View {
        if totalTriosFound > 0 {
            HStack(spacing: 12) {
                SummaryTile(
                    label: totalTriosFound == 1 ? "Trio" : "Trios",
                    value: "\(totalTriosFound)",
                    accessibility: String(localized: "^[\(totalTriosFound) trio](inflect: true) found")
                )
                if let duration = gameDurationSeconds {
                    SummaryTile(
                        label: "Total Time",
                        value: Self.formatDuration(duration),
                        accessibility: "Total time \(Self.durationAccessibilityText(duration))"
                    )
                }
                if let avg = averageTimeBetweenSetsSeconds {
                    SummaryTile(
                        label: "Avg / Trio",
                        value: Self.formatAverage(avg),
                        accessibility: "Average \(Self.formatAverage(avg)) per trio"
                    )
                }
            }
        }
    }

    static func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return Duration.seconds(total).formatted(.time(pattern: .minuteSecond))
    }

    static func formatAverage(_ seconds: Double) -> String {
        if seconds < 60 {
            return seconds.formatted(.number.precision(.fractionLength(1))) + "s"
        }
        return formatDuration(seconds)
    }

    static func durationAccessibilityText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let secs = total % 60
        if minutes == 0 {
            return String(localized: "^[\(secs) second](inflect: true)")
        }
        if secs == 0 {
            return String(localized: "^[\(minutes) minute](inflect: true)")
        }
        return String(localized: "^[\(minutes) minute](inflect: true) ^[\(secs) second](inflect: true)")
    }
}

private struct SummaryTile: View {
    let label: String
    let value: String
    let accessibility: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibility)
    }
}

#Preview("Populated") {
    GameSummaryStats(
        totalTriosFound: 8,
        gameDurationSeconds: 154,
        averageTimeBetweenSetsSeconds: 19.25
    )
    .padding()
}

#Preview("Single trio") {
    GameSummaryStats(
        totalTriosFound: 1,
        gameDurationSeconds: 28,
        averageTimeBetweenSetsSeconds: 28
    )
    .padding()
}

#Preview("Hidden — no trios") {
    GameSummaryStats(
        totalTriosFound: 0,
        gameDurationSeconds: 12,
        averageTimeBetweenSetsSeconds: nil
    )
    .padding()
}
