//
//  DailyStreakChart.swift
//  Tertia
//

import SwiftUI

/// Calendar heatmap of the most recent N days. Each cell is a calendar day,
/// tinted by score tier; days with no record render as a faint placeholder so
/// the user can see gaps in their streak.
struct DailyStreakChart: View {
    let records: [DailyRecord]
    let today: Date
    var dayCount: Int = 35

    private let calendar = Calendar.current
    private let columnSpacing: CGFloat = 6
    private let rowSpacing: CGFloat = 6

    private var days: [Day] {
        let startOfToday = calendar.startOfDay(for: today)
        let recordsByDay = Dictionary(uniqueKeysWithValues: records.map { record in
            (calendar.startOfDay(for: record.day), record.score)
        })
        return (0..<dayCount).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) ?? startOfToday
            return Day(date: date, score: recordsByDay[date], isToday: offset == 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            grid
            if records.isEmpty {
                Text("Complete today's puzzle to start your streak.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                legend
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Daily Streak")
                .font(.headline)
            Spacer()
            Text("Last \(dayCount) days")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var grid: some View {
        let columns = Int(ceil(Double(dayCount) / 7.0))
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: columns),
            spacing: rowSpacing
        ) {
            ForEach(days) { day in
                cell(for: day)
                    .aspectRatio(1, contentMode: .fit)
                    .accessibilityLabel(accessibilityLabel(for: day))
            }
        }
    }

    @ViewBuilder
    private func cell(for day: Day) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(fill(for: day))
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.purple, lineWidth: 1.5)
                }
            }
    }

    private func fill(for day: Day) -> Color {
        guard let score = day.score else {
            return Color.secondary.opacity(0.10)
        }
        switch score {
        case 0...3:  return Color.purple.opacity(0.30)
        case 4...6:  return Color.purple.opacity(0.55)
        default:     return Color.purple.opacity(0.85)
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach([0.10, 0.30, 0.55, 0.85], id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 3)
                    .fill(opacity == 0.10
                        ? Color.secondary.opacity(0.10)
                        : Color.purple.opacity(opacity))
                    .frame(width: 12, height: 12)
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func accessibilityLabel(for day: Day) -> Text {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateText = formatter.string(from: day.date)
        if let score = day.score {
            return Text("^[\(dateText): \(score) trio](inflect: true)")
        } else {
            return Text("\(dateText): no play")
        }
    }
}

private struct Day: Identifiable {
    let date: Date
    let score: Int?
    let isToday: Bool
    var id: Date { date }
}

#Preview("Sparse") {
    let cal = Calendar.current
    return DailyStreakChart(
        records: [
            DailyRecord(day: cal.date(byAdding: .day, value: -10, to: .now) ?? .now, score: 4),
            DailyRecord(day: cal.date(byAdding: .day, value: -3, to: .now) ?? .now, score: 7),
            DailyRecord(day: .now, score: 2)
        ],
        today: .now
    )
    .padding()
}

#Preview("Dense") {
    let cal = Calendar.current
    let records = (0..<35).compactMap { offset -> DailyRecord? in
        guard offset.isMultiple(of: 2) else { return nil }
        guard let date = cal.date(byAdding: .day, value: -offset, to: .now) else { return nil }
        return DailyRecord(day: date, score: Int.random(in: 1...10))
    }
    return DailyStreakChart(records: records, today: .now)
        .padding()
}

#Preview("Empty") {
    DailyStreakChart(records: [], today: .now)
        .padding()
}
