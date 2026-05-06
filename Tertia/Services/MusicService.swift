//
//  MusicService.swift
//  Tertia
//
//  Background music for active gameplay. One looped track shared across
//  every game mode — kept deliberately simple; per-mode tracks are a
//  later concern. Reads `musicEnabled` from UserDefaults so the Settings
//  toggle takes effect immediately.
//
//  Usage:
//  - `gameStarted()` from a game view's `.onAppear`
//  - `gameStopped()` from `.onDisappear`
//  - `setEnabled(_:)` from the Settings toggle's `.onChange`
//
//  The session category is `.ambient` (already configured by
//  FeedbackService) so the silent switch silences gameplay audio and
//  the music doesn't fight other apps' playback.
//

import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class MusicService {
    /// Bundled looping track. File lives at the target root and is
    /// auto-included via PBXFileSystemSynchronizedRootGroup.
    private static let trackName = "denis-pavlov-music-marimba-game-music-playful-tropical-jungle-puzzle-399759"
    private static let trackExt = "mp3"

    private var player: AVAudioPlayer?
    /// True while a game view is on screen. Lets the Settings toggle
    /// kick playback off immediately when flipped on mid-game, and lets
    /// scene-phase resumes know whether to play.
    private(set) var isInGame = false

    init() {
        loadPlayer()
    }

    private var enabled: Bool {
        UserDefaults.standard.object(forKey: "musicEnabled") as? Bool ?? true
    }

    private func loadPlayer() {
        guard let url = Bundle.main.url(forResource: Self.trackName, withExtension: Self.trackExt) else {
            // Track missing from the bundle — degrade silently. Music
            // is non-critical and gameplay must still ship.
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1   // loop indefinitely
            player.volume = 0.6         // sit under sound effects, not over
            player.prepareToPlay()
            self.player = player
        } catch {
            // Decoder error — also non-critical.
        }
    }

    // MARK: - Gameplay lifecycle

    /// A game view became visible. Begin playback if the user has music
    /// enabled. Idempotent — re-entering with no toggle change just
    /// keeps the loop running.
    func gameStarted() {
        isInGame = true
        guard enabled else { return }
        guard let player else { return }
        if !player.isPlaying {
            player.play()
        }
    }

    /// A game view disappeared. Stop and rewind so the next game starts
    /// from the top of the loop rather than mid-phrase.
    func gameStopped() {
        isInGame = false
        player?.pause()
        player?.currentTime = 0
    }

    // MARK: - Scene phase

    /// Pause playback for backgrounding without losing the play position
    /// — the user returning mid-game shouldn't reset the loop.
    func suspend() {
        player?.pause()
    }

    /// Resume playback if a game is still in flight and music is on.
    func resume() {
        guard isInGame, enabled, let player else { return }
        if !player.isPlaying {
            player.play()
        }
    }

    // MARK: - Settings toggle

    /// Called from the Settings toggle's `.onChange`. Reacts immediately
    /// rather than waiting for the next `gameStarted()`.
    func setEnabled(_ newValue: Bool) {
        if newValue {
            if isInGame, let player, !player.isPlaying {
                player.play()
            }
        } else {
            player?.pause()
        }
    }
}
