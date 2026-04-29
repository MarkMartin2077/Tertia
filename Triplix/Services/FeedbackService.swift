//
//  FeedbackService.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import AVFoundation
import Foundation
import Observation
import UIKit

/// Centralized haptics + sound for gameplay events. Reads the user's toggles
/// from `UserDefaults` on each call so Settings changes take effect immediately.
/// Sound files are looked up by name in the main bundle; missing files no-op
/// gracefully so haptics ship even before audio assets are added.
@Observable
final class FeedbackService {
    private enum Sound {
        static let tap = "mixkit-game-ball-tap-2073"
        static let dealDeck = "mixkit-thin-metal-card-deck-shuffle-3175"
        static let validSet = "mixkit-unlock-game-notification-253"
        static let personalBest = "mixkit-video-game-treasure-2066"
    }

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    private var players: [String: AVAudioPlayer] = [:]

    private var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    private var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
    }

    init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()

        // .ambient: respects silent switch, mixes with other audio.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func cardTap() {
        guard hapticsEnabled else { return }
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    func hintTap() {
        if hapticsEnabled {
            lightImpact.impactOccurred()
            lightImpact.prepare()
        }
        playSound(named: Sound.tap)
    }

    func dealDeck() {
        playSound(named: Sound.dealDeck)
    }

    func validSet() {
        if hapticsEnabled {
            notification.notificationOccurred(.success)
            notification.prepare()
        }
        playSound(named: Sound.validSet)
    }

    func invalidSet() {
        guard hapticsEnabled else { return }
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    func personalBest() {
        if hapticsEnabled {
            notification.notificationOccurred(.success)
            notification.prepare()
        }
        playSound(named: Sound.personalBest)
    }

    func timerWarning() {
        guard hapticsEnabled else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    func timerExpired() {
        guard hapticsEnabled else { return }
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    private func playSound(named name: String) {
        guard soundEnabled else { return }

        if let cached = players[name] {
            cached.currentTime = 0
            cached.play()
            return
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }
        player.prepareToPlay()
        players[name] = player
        player.play()
    }
}
