//
//  ModeSelectView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct ModeSelectView: View {
    @Environment(DailyStore.self) private var dailyStore
    @Environment(VersusStore.self) private var versusStore
    @AppStorage("hasFinishedAnyGame") private var hasFinishedAnyGame: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("hasFinishedTutorial") private var hasFinishedTutorial: Bool = false
    @AppStorage("hasSeenTutorialNudge") private var hasSeenTutorialNudge: Bool = false

    let lastPlayed: GameMode?
    let onSelect: (GameMode) -> Void
    /// Fired when the user taps the Versus hero. The coordinator opens
    /// the variant picker — intent (Quick Match vs Invite Friend) is
    /// chosen inside that sheet rather than here.
    let onVersus: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if !dailyStore.isHeroDismissedToday {
                    dailyHero
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
                versusHero
                freePlaySection
            }
            .padding(.bottom, 32)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: dailyStore.isHeroDismissedToday)
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
            onPlay: { onSelect(.daily) },
            onDismiss: dailyStore.hasPlayedToday ? { dailyStore.dismissHeroForToday() } : nil
        )
        .padding(.horizontal, 20)
    }

    /// Versus entry point. CTAs produce a typed `VersusMatchIntent` so the
    /// coordinator can route to the right matchmaking mode (auto-match vs
    /// friend invite). Win/loss counts come from VersusStore so the card
    /// surfaces real history once the player has played a match.
    private var versusHero: some View {
        VersusHeroCard(
            wins: versusStore.winCount,
            losses: versusStore.lossCount,
            onChooseMode: onVersus
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
                        showsRecommendedBadge: shouldShowRecommendedBadge(for: mode),
                        onTap: {
                            // Any mode-card tap clears the one-time tutorial nudge —
                            // the player made a choice, get out of their way.
                            if !hasSeenTutorialNudge { hasSeenTutorialNudge = true }
                            onSelect(mode)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Derived

    /// One-time "Recommended — start here" badge on the tutorial card after
    /// onboarding completes. Disappears the moment the player taps any
    /// mode card (their choice is acknowledged either way).
    private func shouldShowRecommendedBadge(for mode: GameMode) -> Bool {
        guard mode == .tutorial else { return false }
        return hasCompletedOnboarding
            && !hasFinishedTutorial
            && !hasSeenTutorialNudge
    }

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
        let trioWord = record.score == 1 ? "trio" : "trios"
        var lines = [
            "🟪 Tertia Daily — \(date)",
            "🎯 \(record.score) \(trioWord)"
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
                        Text("Recommended — start here")
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
    ModeSelectView(
        lastPlayed: .normal,
        onSelect: { mode in print("Selected: \(mode.title)") },
        onVersus: { print("Versus: open mode picker") }
    )
    .environment(DailyStore())
    .environment(VersusStore())
}
