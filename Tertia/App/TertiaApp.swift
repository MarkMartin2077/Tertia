//
//  TertiaApp.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

@main
struct TertiaApp: App {
    @AppStorage("colorSchemePreference") private var colorSchemePreference: ColorSchemePreference = .system
    @State private var highScoreStore: HighScoreStore
    @State private var dailyStore: DailyStore
    @State private var feedback = FeedbackService()

    init() {
        let high = HighScoreStore()
        let daily = DailyStore()
        ScreenshotMockData.populateIfRequested(highScores: high, daily: daily)
        _highScoreStore = State(initialValue: high)
        _dailyStore = State(initialValue: daily)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorSchemePreference.colorScheme)
                .environment(highScoreStore)
                .environment(dailyStore)
                .environment(feedback)
        }
    }
}
