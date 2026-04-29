//
//  ContentView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

enum AppTab: Hashable {
    case play, stats, settings
}

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: AppTab = .play
    @State private var requestedPlayMode: GameMode?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Play", systemImage: "gamecontroller.fill", value: AppTab.play) {
                PlayCoordinator(requestedMode: $requestedPlayMode)
            }
            Tab("Stats", systemImage: "chart.bar.fill", value: AppTab.stats) {
                StatsView(onPlayTimeAttack: {
                    requestedPlayMode = .timeAttack
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
