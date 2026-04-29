//
//  DailyScoreTrendChart.swift
//  Tertia
//

import SwiftUI
import Charts

/// Line chart of recent Daily Puzzle scores over time, with an area gradient
/// under the line and a personal-best rule annotation. Pure view — give it
/// the records and it renders.
struct DailyScoreTrendChart: View {
    let records: [DailyRecord]
    var maxRecords: Int = 30

    private var sorted: [DailyRecord] {
        Array(records.sorted(by: { $0.day < $1.day }).suffix(maxRecords))
    }

    private var personalBest: Int? {
        records.map(\.score).max()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DailyScoreTrendHeader(personalBest: personalBest)

            if sorted.isEmpty {
                DailyScoreTrendEmpty()
            } else {
                DailyScoreTrendBody(sorted: sorted, personalBest: personalBest)
            }
        }
    }
}

private struct DailyScoreTrendHeader: View {
    let personalBest: Int?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Daily Score Trend")
                .font(.headline)
            Spacer()
            if let best = personalBest {
                Text("Best: \(best)")
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
            }
        }
    }
}

private struct DailyScoreTrendEmpty: View {
    var body: some View {
        Text("Complete a few daily puzzles to see your scores trend over time.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
    }
}

private struct DailyScoreTrendBody: View {
    let sorted: [DailyRecord]
    let personalBest: Int?

    var body: some View {
        Chart {
            ForEach(sorted, id: \.day) { record in
                AreaMark(
                    x: .value("Date", record.day),
                    y: .value("Score", record.score)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.35), Color.purple.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Date", record.day),
                    y: .value("Score", record.score)
                )
                .foregroundStyle(Color.purple.gradient)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Date", record.day),
                    y: .value("Score", record.score)
                )
                .foregroundStyle(Color.purple)
                .symbolSize(28)
            }

            if let best = personalBest {
                RuleMark(y: .value("Best", best))
                    .foregroundStyle(Color.purple.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Best \(best)")
                            .font(.caption2.bold())
                            .foregroundStyle(.purple)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Daily score trend")
        .accessibilityValue(summary)
    }

    private var summary: String {
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else {
            return sorted.first.map { "Single daily: \($0.score) trios" } ?? "No daily runs"
        }
        let direction = last.score > first.score ? "improved" : (last.score < first.score ? "declined" : "held steady")
        return "Over \(sorted.count) days, daily score has \(direction). Most recent: \(last.score)."
    }
}

#Preview("Empty") {
    DailyScoreTrendChart(records: [])
        .padding()
}

#Preview("Trend") {
    let cal = Calendar.current
    let records: [DailyRecord] = (0..<14).compactMap { offset in
        guard let date = cal.date(byAdding: .day, value: -offset, to: .now) else { return nil }
        return DailyRecord(day: date, score: Int.random(in: 3...12))
    }
    return DailyScoreTrendChart(records: records)
        .padding()
}
