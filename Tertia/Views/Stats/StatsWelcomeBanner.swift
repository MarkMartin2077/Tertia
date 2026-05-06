//
//  StatsWelcomeBanner.swift
//  Tertia
//
//  Onboarding banner shown only when the user has no Daily or Time
//  Attack history yet — gives them a single tap into either mode so the
//  empty Stats screen has a clear call to action.
//

import SwiftUI

struct StatsWelcomeBanner: View {
    let onPlay: (GameMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title)
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your stats live here")
                        .font(.headline)
                    Text("Build a streak with the Daily Puzzle, or chase a high score in Time Attack. The charts below fill in as you go.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                Button {
                    onPlay(.daily)
                } label: {
                    Label("Today's Daily", systemImage: "calendar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.purple)

                Button {
                    onPlay(.timeAttack)
                } label: {
                    Label("Time Attack", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.orange)
            }
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.purple.opacity(0.35), lineWidth: 1.5)
        }
    }
}
