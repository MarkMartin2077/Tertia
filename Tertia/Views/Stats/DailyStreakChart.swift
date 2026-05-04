//
//  DailyStreakChart.swift
//  Tertia
//

import SwiftUI

/// Selectable range for the streak heatmap. Week is the default — it
/// focuses the eye on the player's last seven days; Month expands to a
/// dense 30-day grid for the broader view.
enum DailyStreakRange: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }
    var dayCount: Int { self == .week ? 7 : 30 }
    var label: String { self == .week ? "Week" : "Month" }
}

/// Streak heatmap. Renders the most recent N days (rolling, ending today)
/// in one of two layouts: a single-row "week strip" with day-of-week
/// letters above, or a denser multi-row grid for the month view. Each
/// cell tints by score tier; days with no record render as a faint
/// placeholder so gaps are visible.
struct DailyStreakChart: View {
    let records: [DailyRecord]
    let today: Date
    /// Initial range. The chart owns its own selection state internally,
    /// so this only sets the starting position.
    var initialRange: DailyStreakRange = .week

    @State private var range: DailyStreakRange

    init(records: [DailyRecord], today: Date, initialRange: DailyStreakRange = .week) {
        self.records = records
        self.today = today
        self.initialRange = initialRange
        self._range = State(initialValue: initialRange)
    }

    private let calendar = Calendar.current
    private let columnSpacing: CGFloat = 6
    private let rowSpacing: CGFloat = 6

    private var days: [Day] {
        let startOfToday = calendar.startOfDay(for: today)
        let recordsByDay = Dictionary(uniqueKeysWithValues: records.map { record in
            (calendar.startOfDay(for: record.day), record.score)
        })
        return (0..<range.dayCount).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) ?? startOfToday
            return Day(date: date, score: recordsByDay[date], isToday: offset == 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Group {
                switch range {
                case .week: weekStrip
                case .month: monthGrid
                }
            }
            .animation(.easeInOut(duration: 0.18), value: range)
            if records.isEmpty {
                Text("Complete today's puzzle to start your streak.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                legend
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily Streak")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(DailyStreakRange.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .accessibilityLabel("Streak range")
            }
            Text(dateRangeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityLabel("Showing \(dateRangeText)")
        }
    }

    /// "Apr 28 – May 4" style range covering the full window. Driven off
    /// the `days` array so it always matches what's actually rendered —
    /// flips correctly between week (7-day) and month (30-day) modes.
    private var dateRangeText: String {
        guard let start = days.first?.date else { return "" }
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(start.formatted(style)) – \(today.formatted(style))"
    }

    // MARK: - Week strip

    /// Single-row layout for the 7-day view. Each cell gets a day-of-week
    /// letter above it, drawn from `Calendar.veryShortWeekdaySymbols` so
    /// the labels stay locale-correct.
    private var weekStrip: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(weekdayLetter(for: day.date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    cell(for: day)
                        .aspectRatio(1, contentMode: .fit)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel(for: day))
            }
        }
    }

    private func weekdayLetter(for date: Date) -> String {
        // veryShortWeekdaySymbols is indexed 1...7 by Calendar.component(.weekday, from:)
        // → Sunday = 1.
        let weekday = calendar.component(.weekday, from: date)
        let index = weekday - 1
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        let columns = Int(ceil(Double(range.dayCount) / 7.0))
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

    // MARK: - Cell

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

#Preview("Sparse — Week") {
    let cal = Calendar.current
    return DailyStreakChart(
        records: [
            DailyRecord(day: cal.date(byAdding: .day, value: -3, to: .now) ?? .now, score: 7),
            DailyRecord(day: .now, score: 2)
        ],
        today: .now
    )
    .padding()
}

#Preview("Dense — Month default") {
    let cal = Calendar.current
    let records = (0..<30).compactMap { offset -> DailyRecord? in
        guard offset.isMultiple(of: 2) else { return nil }
        guard let date = cal.date(byAdding: .day, value: -offset, to: .now) else { return nil }
        return DailyRecord(day: date, score: Int.random(in: 1...10))
    }
    return DailyStreakChart(records: records, today: .now, initialRange: .month)
        .padding()
}

#Preview("Empty") {
    DailyStreakChart(records: [], today: .now)
        .padding()
}
