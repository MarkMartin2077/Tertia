 //
//  DailyGameOverSheet.swift
//  Tertia
//
//  End-of-game sheet for the Daily Puzzle. Designed around a single
//  hero number (today's score), a streak chip when active, and a live
//  "next puzzle in HH:MM" footer that gives the player a reason to come
//  back. Confetti fires on perfect-clear or notable-streak completions —
//  routine completions get a quieter accent flash.
//

import SwiftUI
import UIKit

struct DailyGameOverSheet: View {
    let date: Date
    let score: Int
    let streak: Int
    var fastestSetSeconds: Double? = nil
    var longestStreak: Int? = nil
    var strandedCardCount: Int? = nil
    var totalTriosFound: Int = 0
    var gameDurationSeconds: Double? = nil
    var averageTimeBetweenSetsSeconds: Double? = nil
    let onChangeMode: () -> Void

    @Environment(FeedbackService.self) private var feedback
    /// Hero score scales with Dynamic Type so the number remains the
    /// dominant visual element at every accessibility size.
    @ScaledMetric(relativeTo: .largeTitle) private var heroScoreSize: CGFloat = 64

    private var accent: Color { GameMode.daily.accentColor }

    /// Trigger confetti when the run feels celebratory — perfect clear, a
    /// streak that's compounding, or a strong score. Avoids confetti on
    /// every routine completion (would dilute the moment).
    private var deservesConfetti: Bool {
        if strandedCardCount == 0 { return true }
        if streak >= 2 { return true }
        return false
    }

    private var dateLabel: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var shareText: String {
        let trioWord = totalTriosFound == 1 ? "trio" : "trios"
        var lines = [
            "🟪 Tertia Daily — \(date.formatted(.dateTime.month(.abbreviated).day()))",
            "💯 \(score) points",
            "🎯 \(totalTriosFound) \(trioWord)"
        ]
        if streak > 1 {
            lines.append("🔥 \(streak)-day streak")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                DailyResultHeader(dateLabel: dateLabel)

                DailyHeroScore(
                    score: score,
                    accent: accent,
                    heroSize: heroScoreSize
                )

                if streak >= 2 {
                    DailyStreakBadge(streak: streak, accent: accent)
                        .transition(.scale.combined(with: .opacity))
                }

                DailyBestMomentsRow(
                    fastestSetSeconds: fastestSetSeconds,
                    longestStreak: longestStreak
                )

                DailyDetailStatsGrid(
                    totalTriosFound: totalTriosFound,
                    gameDurationSeconds: gameDurationSeconds,
                    averageTimeBetweenSetsSeconds: averageTimeBetweenSetsSeconds
                )

                DeckClearedLine(strandedCardCount: strandedCardCount)

                actionButtons

                DailyNextPuzzleTimer(accent: accent)
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .topTrailing) {
            Button(action: onChangeMode) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(16)
            .accessibilityLabel("Close")
        }
        .overlay {
            if deservesConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            playArrivalFeedback()
            let trioWord = totalTriosFound == 1 ? "trio" : "trios"
            UIAccessibility.post(
                notification: .announcement,
                argument: "Today's puzzle complete. You found \(totalTriosFound) \(trioWord)."
            )
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            ShareLink(item: shareText) {
                Label("Share Result", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(accent)

            Button(action: onChangeMode) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    /// Success haptic on every completion; "personal best" flourish on the
    /// celebratory paths so a perfect clear / streak day actually feels
    /// different from a routine completion.
    private func playArrivalFeedback() {
        if deservesConfetti {
            feedback.personalBest()
        } else {
            feedback.validSet()
        }
    }
}

// MARK: - Header

private struct DailyResultHeader: View {
    let dateLabel: String

    var body: some View {
        VStack(spacing: 4) {
            Text(dateLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.4)
            Text("Today's Puzzle")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's Puzzle, \(dateLabel)")
    }
}

// MARK: - Hero score

private struct DailyHeroScore: View {
    let score: Int
    let accent: Color
    let heroSize: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(.system(size: heroSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent.gradient)
                .contentTransition(.numericText())
                .accessibilityHidden(true)
            Text("Score")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.4)
        }
        .accessibilityElement()
        .accessibilityLabel("Score: \(score)")
    }
}

// MARK: - Streak chip

private struct DailyStreakBadge: View {
    let streak: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(streak)-day streak")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.15), in: .capsule)
        .overlay {
            Capsule()
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streak) day streak")
    }
}

// MARK: - Best moments

/// "Fastest" + "Longest combo" sit side-by-side as the second-tier rewards.
/// Self-hides if neither is available (early days, no completed trios).
private struct DailyBestMomentsRow: View {
    let fastestSetSeconds: Double?
    let longestStreak: Int?

    private var hasContent: Bool {
        fastestSetSeconds != nil || (longestStreak ?? 0) >= 2
    }

    var body: some View {
        if hasContent {
            HStack(spacing: 10) {
                if let seconds = fastestSetSeconds {
                    BestMomentTile(
                        icon: "bolt.fill",
                        iconColor: .yellow,
                        value: seconds.formatted(.number.precision(.fractionLength(1))) + "s",
                        caption: "Fastest"
                    )
                }
                if let streak = longestStreak, streak >= 2 {
                    BestMomentTile(
                        icon: "flame.fill",
                        iconColor: .red,
                        value: "×\(streak)",
                        caption: "Best Combo"
                    )
                }
            }
        }
    }
}

private struct BestMomentTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .imageScale(.small)
                Text(value)
                    .font(.title3.bold())
                    .monospacedDigit()
            }
            Text(caption)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(caption): \(value)")
    }
}

// MARK: - Detail stats line

/// Three-column scoreboard-style detail stats. Bold values + tracked
/// uppercase captions give the data real weight without a card / border —
/// keeps it distinct from the bordered `DailyBestMomentsRow` above while
/// still feeling structured (not footnote copy).
private struct DailyDetailStatsGrid: View {
    let totalTriosFound: Int
    let gameDurationSeconds: Double?
    let averageTimeBetweenSetsSeconds: Double?

    private struct Entry: Identifiable {
        let id = UUID()
        let value: String
        let label: String
    }

    private var entries: [Entry] {
        var result: [Entry] = []
        if totalTriosFound > 0 {
            result.append(Entry(value: "\(totalTriosFound)", label: "Trios"))
        }
        if let duration = gameDurationSeconds {
            result.append(Entry(
                value: GameSummaryStats.formatDuration(duration),
                label: "Total"
            ))
        }
        if let avg = averageTimeBetweenSetsSeconds {
            result.append(Entry(
                value: GameSummaryStats.formatAverage(avg),
                label: "Avg / Trio"
            ))
        }
        return result
    }

    var body: some View {
        if !entries.isEmpty {
            HStack(alignment: .top, spacing: 0) {
                ForEach(entries.indices, id: \.self) { index in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.18))
                            .frame(width: 1, height: 28)
                    }
                    DailyDetailStatCell(
                        value: entries[index].value,
                        label: entries[index].label
                    )
                }
            }
        }
    }
}

private struct DailyDetailStatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(verbatim: value)
                .font(.title3.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Next puzzle countdown

/// Replaces the old static "Come back tomorrow" copy with a live countdown
/// to local midnight. Drives engagement — the player can see exactly how
/// long until the next puzzle drops.
private struct DailyNextPuzzleTimer: View {
    let accent: Color

    var body: some View {
        TimelineView(.everyMinute) { context in
            let remaining = nextPuzzleRemaining(now: context.date)
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .imageScale(.small)
                Text("Next puzzle in \(remaining)")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            .accessibilityLabel("Next puzzle in \(remaining)")
        }
    }

    /// Compact "Hh Mm" format. Falls back to "M minutes" when under an hour.
    private func nextPuzzleRemaining(now: Date) -> String {
        let calendar = Calendar.current
        guard let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else {
            return "tomorrow"
        }
        let total = max(0, Int(nextMidnight.timeIntervalSince(now)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview("Routine — first day") {
    DailyGameOverSheet(
        date: .now,
        score: 36,
        streak: 1,
        fastestSetSeconds: 3.4,
        longestStreak: 2,
        strandedCardCount: 9,
        totalTriosFound: 18,
        gameDurationSeconds: 1245,
        averageTimeBetweenSetsSeconds: 69.2,
        onChangeMode: {}
    )
    .environment(FeedbackService())
}

#Preview("Streak day — confetti") {
    DailyGameOverSheet(
        date: .now,
        score: 58,
        streak: 5,
        fastestSetSeconds: 2.1,
        longestStreak: 3,
        strandedCardCount: 6,
        totalTriosFound: 24,
        gameDurationSeconds: 1910,
        averageTimeBetweenSetsSeconds: 79.6,
        onChangeMode: {}
    )
    .environment(FeedbackService())
}

#Preview("Perfect clear") {
    DailyGameOverSheet(
        date: .now,
        score: 84,
        streak: 12,
        fastestSetSeconds: 1.8,
        longestStreak: 4,
        strandedCardCount: 0,
        totalTriosFound: 27,
        gameDurationSeconds: 1620,
        averageTimeBetweenSetsSeconds: 60.0,
        onChangeMode: {}
    )
    .environment(FeedbackService())
}
