//
//  ModeSelectView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct ModeSelectView: View {
    @Environment(DailyStore.self) private var dailyStore
    @AppStorage("hasFinishedAnyGame") private var hasFinishedAnyGame: Bool = false

    let lastPlayed: GameMode?
    let onSelect: (GameMode) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                dailyHero
                freePlaySection
            }
            .padding(.bottom, 32)
        }
        .boardBackground()
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Choose Mode")
                .font(.largeTitle.bold())
            if let last = lastPlayed {
                Text("Last played: \(last.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var dailyHero: some View {
        DailyHeroCard(
            dateText: dateText,
            status: dailyStatus,
            onPlay: { onSelect(.daily) }
        )
        .padding(.horizontal, 20)
    }

    private var freePlaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Free Play")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            VStack(spacing: 16) {
                ForEach(GameMode.regularModes) { mode in
                    ModeCard(
                        mode: mode,
                        isLastPlayed: lastPlayed == mode,
                        showsRecommendedBadge: mode == .practice && !hasFinishedAnyGame,
                        onTap: { onSelect(mode) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Derived

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: .now)
    }

    private var dailyStatus: DailyHeroCard.Status {
        guard let record = dailyStore.todaysRecord else {
            return .ready(streak: dailyStore.displayedStreak)
        }
        return .completed(
            score: record.score,
            streak: dailyStore.displayedStreak,
            shareText: shareText(for: record)
        )
    }

    private func shareText(for record: DailyRecord) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let date = formatter.string(from: record.day)
        var lines = [
            "🟪 Tertia Daily — \(date)",
            "🎯 \(record.score) \(record.score == 1 ? "trio" : "trios")"
        ]
        let streak = dailyStore.displayedStreak
        if streak > 1 {
            lines.append("🔥 \(streak)-day streak")
        }
        return lines.joined(separator: "\n")
    }
}

private struct ModeCard: View {
    let mode: GameMode
    let isLastPlayed: Bool
    var showsRecommendedBadge: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: mode.systemImageName)
                    .font(.system(size: 32))
                    .foregroundStyle(mode.accentColor)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(mode.title)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        if isLastPlayed {
                            Text("Last")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(mode.accentColor.opacity(0.18), in: .capsule)
                                .foregroundStyle(mode.accentColor)
                        }
                    }
                    if showsRecommendedBadge {
                        Text("Recommended for new players")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(mode.accentColor.opacity(0.16), in: .capsule)
                            .foregroundStyle(mode.accentColor)
                    }
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isLastPlayed ? mode.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: isLastPlayed ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityHint("Double tap to start \(mode.title) mode")
    }
}

#Preview {
    ModeSelectView(lastPlayed: .normal) { mode in
        print("Selected: \(mode.title)")
    }
    .environment(DailyStore())
}
