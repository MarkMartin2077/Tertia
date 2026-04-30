//
//  ContentView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

enum AppTab: Hashable {
    case play, stats, settings
}

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(GameCenterService.self) private var gameCenter
    @Environment(HighScoreStore.self) private var highScoreStore
    @Environment(DailyStore.self) private var dailyStore
    @State private var selectedTab: AppTab = .play
    @State private var requestedPlayMode: GameMode?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Play", systemImage: "gamecontroller.fill", value: AppTab.play) {
                PlayCoordinator(requestedMode: $requestedPlayMode)
            }
            Tab("Stats", systemImage: "chart.bar.fill", value: AppTab.stats) {
                StatsView(onPlay: { mode in
                    requestedPlayMode = mode
                    selectedTab = .play
                })
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .fullScreenCover(isPresented: showingOnboarding) {
            OnboardingView()
        }
        .onChange(of: gameCenter.isAuthenticated) { _, newValue in
            guard newValue else { return }
            // Auth completed — push the player's current local Time Attack
            // best to Game Center so existing players don't have to replay
            // to populate the leaderboard.
            Task {
                if let timeAttackBest = highScoreStore.bestScore(forDuration: 300) {
                    await gameCenter.submitTimeAttackScore(timeAttackBest)
                }
            }
        }
        .onChange(of: gameCenter.pendingActivityRequest) { _, request in
            guard let request else { return }
            // Game Center asked us to launch an activity — switch to Play
            // and start the matching mode. Consume the request so it doesn't
            // re-fire on the next view update.
            requestedPlayMode = request.suggestedMode
            selectedTab = .play
            gameCenter.clearPendingActivityRequest()
        }
    }

    private var showingOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { _ in }
        )
    }
}

#Preview {
    ContentView()
        .environment(HighScoreStore())
}
