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
    @State private var sessionStore: GameSessionStore
    @State private var versusStore: VersusStore
    @State private var feedback = FeedbackService()
    @State private var gameCenter = GameCenterService()

    init() {
        let high = HighScoreStore()
        let daily = DailyStore()
        let sessions = GameSessionStore()
        let versus = VersusStore()
        ScreenshotMockData.populateIfRequested(
            highScores: high,
            daily: daily,
            sessions: sessions,
            versus: versus
        )
        _highScoreStore = State(initialValue: high)
        _dailyStore = State(initialValue: daily)
        _sessionStore = State(initialValue: sessions)
        _versusStore = State(initialValue: versus)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorSchemePreference.colorScheme)
                .environment(highScoreStore)
                .environment(dailyStore)
                .environment(sessionStore)
                .environment(versusStore)
                .environment(feedback)
                .environment(gameCenter)
                .gameCenterAuthenticationCover(service: gameCenter)
                .task {
                    gameCenter.authenticate()
                }
        }
    }
}

private extension View {
    func gameCenterAuthenticationCover(service: GameCenterService) -> some View {
        fullScreenCover(
            isPresented: Binding(
                get: { service.pendingAuthenticationViewController != nil },
                set: { if !$0 { service.pendingAuthenticationViewController = nil } }
            )
        ) {
            if let viewController = service.pendingAuthenticationViewController {
                GameCenterAuthenticationContainer(viewController: viewController)
                    .ignoresSafeArea()
            }
        }
    }
}

private struct GameCenterAuthenticationContainer: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController { viewController }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
