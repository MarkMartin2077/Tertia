//
//  PlayCoordinator.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct PlayCoordinator: View {
    @AppStorage("lastGameMode") private var lastGameModeRaw: String = GameMode.normal.rawValue
    @Binding var requestedMode: GameMode?
    @State private var activeMode: GameMode?

    private let transitionAnimation = Animation.spring(response: 0.45, dampingFraction: 0.82)

    init(requestedMode: Binding<GameMode?> = .constant(nil)) {
        self._requestedMode = requestedMode
    }

    var body: some View {
        ZStack {
            if let mode = activeMode {
                GameView(mode: mode, onExit: {
                    withAnimation(transitionAnimation) {
                        activeMode = nil
                    }
                })
                .id(mode)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.04)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    )
                )
            } else {
                ModeSelectView(
                    lastPlayed: GameMode(rawValue: lastGameModeRaw),
                    onSelect: { mode in
                        startMode(mode)
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 1.04))
                    )
                )
            }
        }
        .onChange(of: requestedMode) { _, newValue in
            if let mode = newValue {
                startMode(mode)
                requestedMode = nil
            }
        }
        .onAppear {
            if let mode = requestedMode {
                startMode(mode)
                requestedMode = nil
            }
        }
    }

    private func startMode(_ mode: GameMode) {
        lastGameModeRaw = mode.rawValue
        withAnimation(transitionAnimation) {
            activeMode = mode
        }
    }
}

#Preview {
    PlayCoordinator()
}
