//
//  DailyGameOverSheet.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI
import UIKit

struct DailyGameOverSheet: View {
    let date: Date
    let score: Int
    let streak: Int
    var fastestSetSeconds: Double? = nil
    var longestStreak: Int? = nil
    let onChangeMode: () -> Void

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var shareText: String {
        var lines = [
            "🟪 Tertia Daily — \(dateText)",
            "🎯 \(score) \(score == 1 ? "trio" : "trios") in 90s"
        ]
        if streak > 1 {
            lines.append("🔥 \(streak)-day streak")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Today's Puzzle")
                    .font(.largeTitle.bold())
                Text("You found \(score) \(score == 1 ? "trio" : "trios")")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if streak > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(streak)-day streak")
                            .font(.subheadline.bold())
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15), in: .capsule)
                }

                statsBadges
                    .padding(.top, 8)
            }

            VStack(spacing: 12) {
                ShareLink(item: shareText) {
                    Label("Share Result", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.purple)

                Button(action: onChangeMode) {
                    Text("Change Mode")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Text("Come back tomorrow for a new puzzle.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            UIAccessibility.post(
                notification: .announcement,
                argument: "Today's puzzle complete. You found \(score) \(score == 1 ? "trio" : "trios")."
            )
        }
    }

    @ViewBuilder
    private var statsBadges: some View {
        HStack(spacing: 8) {
            if let seconds = fastestSetSeconds {
                statBadge(
                    icon: "bolt.fill",
                    iconColor: .yellow,
                    text: String(format: "%.1fs fastest", seconds),
                    accessibility: "Fastest trio: \(String(format: "%.1f", seconds)) seconds"
                )
            }
            if let streak = longestStreak {
                statBadge(
                    icon: "flame.fill",
                    iconColor: .red,
                    text: "×\(streak) best streak",
                    accessibility: "Longest streak: \(streak) trios in a row"
                )
            }
        }
    }

    private func statBadge(icon: String, iconColor: Color, text: String, accessibility: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            Text(text)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(iconColor.opacity(0.15), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibility)
    }
}

#Preview("First-time") {
    DailyGameOverSheet(
        date: .now,
        score: 5,
        streak: 1,
        onChangeMode: {}
    )
}

#Preview("Streak day") {
    DailyGameOverSheet(
        date: .now,
        score: 8,
        streak: 5,
        onChangeMode: {}
    )
}
