//
//  GameDurationTrendChart.swift
//  Tertia
//

import SwiftUI
import Charts

/// Line + point chart of how long recent untimed games (Normal, Daily,
/// Practice) took to complete, with a horizontal rule at the running
/// average. Time Attack is excluded by the view model — it would be a flat
/// line at 5:00.
struct GameDurationTrendChart: View {
    let sessions: [GameSessionRecord]
    var averageDurationSeconds: Double?

    private var sorted: [GameSessionRecord] {
        sessions.sorted(by: { $0.date < $1.date })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if sorted.isEmpty {
                emptyState
            } else {
                chart
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Avg Game Duration")
                .font(.headline)
            Spacer()
            if let average = averageDurationSeconds {
                Text("Avg \(formatShort(average))")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }
        }
    }

    private var emptyState: some View {
        Text("Finish a Normal or Daily game to start tracking how long your games take.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
    }

    private var chart: some View {
        Chart {
            ForEach(sorted) { session in
                LineMark(
                    x: .value("Date", session.date),
                    y: .value("Duration", session.durationSeconds)
                )
                .foregroundStyle(Color.blue.gradient)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", session.date),
                    y: .value("Duration", session.durationSeconds)
                )
                .foregroundStyle(Color.blue)
                .symbolSize(32)
            }

            if let average = averageDurationSeconds {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(Color.blue.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Avg \(formatShort(average))")
                            .font(.caption2.bold())
                            .foregroundStyle(.blue)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(formatShort(seconds))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Game duration trend")
        .accessibilityValue(trendSummary)
    }

    private func formatShort(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return total.formatted() + "s" }
        return Duration.seconds(total).formatted(.time(pattern: .minuteSecond))
    }

    private var trendSummary: String {
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else {
            return sorted.first.map { "Single game: \(formatShort($0.durationSeconds))" } ?? "No games"
        }
        let direction: String
        if last.durationSeconds < first.durationSeconds {
            direction = "getting faster"
        } else if last.durationSeconds > first.durationSeconds {
            direction = "getting slower"
        } else {
            direction = "holding steady"
        }
        return "Across \(sorted.count) games, you're \(direction). Most recent: \(formatShort(last.durationSeconds))."
    }
}

#Preview("Empty") {
    GameDurationTrendChart(sessions: [], averageDurationSeconds: nil)
        .padding()
}

#Preview("Trend") {
    let cal = Calendar.current
    let sessions: [GameSessionRecord] = (0..<10).map { offset in
        let date = cal.date(byAdding: .day, value: -offset, to: .now) ?? .now
        return GameSessionRecord(
            mode: offset.isMultiple(of: 2) ? .normal : .daily,
            durationSeconds: Double.random(in: 90...420),
            trioCount: Int.random(in: 4...20),
            date: date
        )
    }
    let avg = sessions.reduce(0.0) { $0 + $1.durationSeconds } / Double(sessions.count)
    return GameDurationTrendChart(sessions: sessions, averageDurationSeconds: avg)
        .padding()
}
