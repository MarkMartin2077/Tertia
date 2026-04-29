//
//  TimeAttackTrendChart.swift
//  Tertia
//

import SwiftUI
import Charts

/// Line + point chart of recent Time Attack runs, with a personal-best line
/// drawn across the top. Pure view — give it the entries and it renders.
struct TimeAttackTrendChart: View {
    let entries: [HighScoreEntry]
    var maxEntries: Int = 30

    private var sorted: [HighScoreEntry] {
        Array(entries.sorted(by: { $0.date < $1.date }).suffix(maxEntries))
    }

    private var personalBest: Int? {
        entries.map(\.score).max()
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
            Text("Time Attack Trend")
                .font(.headline)
            Spacer()
            if let best = personalBest {
                Text("Best: \(best)")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
        }
    }

    private var emptyState: some View {
        Text("Play a Time Attack run to start the trend.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
    }

    private var chart: some View {
        Chart {
            ForEach(sorted) { entry in
                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(Color.orange.gradient)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(Color.orange)
                .symbolSize(32)
            }

            if let best = personalBest {
                RuleMark(y: .value("Best", best))
                    .foregroundStyle(Color.orange.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Best \(best)")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Time Attack score trend")
        .accessibilityValue(trendSummary)
    }

    private var trendSummary: String {
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else {
            return sorted.first.map { "Single run: \($0.score) trios" } ?? "No runs"
        }
        let direction = last.score > first.score ? "improved" : (last.score < first.score ? "declined" : "held steady")
        return "Over \(sorted.count) runs, score has \(direction). Most recent: \(last.score)."
    }
}

#Preview("Empty") {
    TimeAttackTrendChart(entries: [])
        .padding()
}

#Preview("Single") {
    TimeAttackTrendChart(entries: [
        HighScoreEntry(score: 7, durationSeconds: 300, date: .now)
    ])
    .padding()
}

#Preview("Trend") {
    let entries: [HighScoreEntry] = (0..<14).map { offset in
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now)!
        return HighScoreEntry(
            score: Int.random(in: 4...14),
            durationSeconds: 300,
            date: date
        )
    }
    return TimeAttackTrendChart(entries: entries)
        .padding()
}
