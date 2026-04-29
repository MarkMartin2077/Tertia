//
//  DailyGameOverSheet.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI
import UIKit

struct DailyGameOverSheet: View {
    let date: Date
    let score: Int
    let streak: Int
    let onChangeMode: () -> Void

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var shareText: String {
        var lines = [
            "🟪 Triplix Daily — \(dateText)",
            "🎯 \(score) \(score == 1 ? "set" : "sets") in 90s"
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
                Text("You found \(score) \(score == 1 ? "set" : "sets")")
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
                argument: "Today's puzzle complete. You found \(score) \(score == 1 ? "set" : "sets")."
            )
        }
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
