//
//  DailyHeroCard.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct DailyHeroCard: View {
    enum Status {
        case ready(streak: Int)
        case completed(score: Int, streak: Int, shareText: String)
    }

    let dateText: String
    let status: Status
    let onPlay: () -> Void
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(dateText)
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.purple)

                Spacer()

                statusBadge
            }

            Text("Daily Puzzle")
                .font(.title2.bold())

            subtitleArea

            actionButton
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.purple.opacity(0.28), .pink.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 20)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.purple.opacity(0.4), lineWidth: 1.5)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .ready:
            Text("READY")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.22), in: .capsule)
                .foregroundStyle(.green)
        case .completed:
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("DONE")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.22), in: .capsule)
                .foregroundStyle(.green)

                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.purple.opacity(0.55))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide today's puzzle")
                    .accessibilityHint("Hides the daily puzzle card until tomorrow")
                }
            }
        }
    }

    @ViewBuilder
    private var subtitleArea: some View {
        switch status {
        case .ready(let streak):
            if streak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("Keep your \(streak)-day streak alive")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            } else {
                Text("Same puzzle for everyone today. Find every set.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .completed(let score, let streak, _):
            HStack(spacing: 20) {
                statBlock(value: "\(score)", label: score == 1 ? "Trio" : "Trios")
                if streak > 0 {
                    statBlock(value: "\(streak)", label: streak == 1 ? "Day" : "Days", icon: "flame.fill", iconColor: .orange)
                }
            }
        }
    }

    @ViewBuilder
    private func statBlock(value: String, label: String, icon: String? = nil, iconColor: Color = .purple) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: -2) {
                Text(value)
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .ready:
            Button(action: onPlay) {
                Label("Start Today", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.purple)
        case .completed(_, _, let shareText):
            ShareLink(item: shareText) {
                Label("Share Result", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(.purple)
        }
    }
}

#Preview("Ready — no streak") {
    DailyHeroCard(
        dateText: "Apr 29",
        status: .ready(streak: 0),
        onPlay: {}
    )
    .padding()
}

#Preview("Ready — with streak") {
    DailyHeroCard(
        dateText: "Apr 29",
        status: .ready(streak: 3),
        onPlay: {}
    )
    .padding()
}

#Preview("Completed") {
    DailyHeroCard(
        dateText: "Apr 29",
        status: .completed(score: 8, streak: 5, shareText: "Tertia Daily — 8 trios"),
        onPlay: {}
    )
    .padding()
}
