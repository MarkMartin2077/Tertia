//
//  TutorialController.swift
//  Tertia
//
//  Created by Mark Martin on 5/17/26.
//

import Foundation
import Observation
import SwiftUI

/// Drives a 12-puzzle tutorial run. Wraps `TutorialPuzzles` + `explain(_:)`;
/// deliberately omits scoring, deck/refill, and timers — those belong to
/// `SetGame` and aren't tutorial concerns. Wrong picks have no consequence
/// beyond the verdict bar; the tutorial is intentionally the safest place
/// for the player to be wrong.
@MainActor
@Observable
final class TutorialController {
    private(set) var currentIndex: Int = 0
    private(set) var selectedCards: [SetCard] = []
    private(set) var verdict: SetExplanation? = nil
    private(set) var celebration: CelebrationLevel? = nil
    private(set) var isComplete: Bool = false
    private(set) var finishedNaturally: Bool = false

    /// The cards as the player currently sees them, shuffled. Hand-authored
    /// puzzles put the solution in positions 0/1/2 — without shuffling, an
    /// observant player would learn "the answer is always the first 3
    /// cards" by puzzle 3. Reshuffled on advance AND on wrong-pick dismissal
    /// so the player can't memorize positions across retries.
    private(set) var displayedCards: [SetCard] = TutorialPuzzles.all[0].cards.shuffled()

    /// Lifetime furthest tutorial puzzle reached, 1-based. `0` means no
    /// tutorial started. Persists across sessions and never auto-resets
    /// (Settings "replay tutorial" deliberately preserves this stat).
    /// `@ObservationIgnored` because `@AppStorage` provides its own
    /// observation via `UserDefaults`; double-tracking emits a warning.
    @ObservationIgnored
    @AppStorage("tutorialFurthestPuzzleReached")
    private var furthestPuzzleReached: Int = 0

    var currentPuzzle: TutorialPuzzle {
        precondition(
            TutorialPuzzles.all.indices.contains(currentIndex),
            "TutorialController.currentIndex (\(currentIndex)) out of bounds for TutorialPuzzles.all (count: \(TutorialPuzzles.all.count))"
        )
        return TutorialPuzzles.all[currentIndex]
    }
    var progressText: String { "\(currentIndex + 1) / \(TutorialPuzzles.count)" }
    var hint: String? { currentPuzzle.hint }
    var isCapstone: Bool { currentIndex == TutorialPuzzles.count - 1 }

    /// Selection sets used by the view for highlighting. Computed from
    /// `selectedCards` for cheap identity lookup.
    var selectedIds: Set<UUID> { Set(selectedCards.map(\.id)) }

    /// While the verdict bar is showing the player can't toggle cards
    /// further — `select(_:)` is a no-op in that state.
    var isVerdictShowing: Bool { verdict != nil }

    func select(_ card: SetCard) {
        guard !isVerdictShowing else { return }
        if let existing = selectedCards.firstIndex(where: { $0.id == card.id }) {
            selectedCards.remove(at: existing)
            return
        }
        guard selectedCards.count < 3 else { return }
        selectedCards.append(card)
        if selectedCards.count == 3 {
            evaluate()
        }
    }

    /// Called when the player dismisses the verdict bar. Wrong picks reset
    /// the selection and stay on the same puzzle; correct picks advance
    /// after the celebration has held.
    func dismissVerdict() {
        guard let verdict else { return }
        if verdict.isSet {
            advance()
        } else {
            self.verdict = nil
            selectedCards = []
            celebration = nil
            // Reshuffle so a retry isn't visually identical — prevents the
            // player from rote-eliminating positions and forces a fresh look.
            displayedCards = currentPuzzle.cards.shuffled()
        }
    }

    func skip() {
        finishedNaturally = false
        isComplete = true
    }

    private func evaluate() {
        let explanation = explain(selectedCards)
        verdict = explanation
        guard explanation.isSet else { return }
        celebration = celebrationLevel(for: currentIndex)
    }

    private func advance() {
        verdict = nil
        celebration = nil
        selectedCards = []
        let next = currentIndex + 1
        // Update furthest-reached AFTER advancing, so finishing puzzle 1 records "2"
        // (player reached puzzle 2). Capstone completion records "12" (passed the
        // capstone) — there is no puzzle 13.
        if next >= TutorialPuzzles.count {
            finishedNaturally = true
            isComplete = true
            furthestPuzzleReached = max(furthestPuzzleReached, TutorialPuzzles.count)
        } else {
            currentIndex = next
            displayedCards = currentPuzzle.cards.shuffled()
            furthestPuzzleReached = max(furthestPuzzleReached, next + 1)
        }
    }

    private func celebrationLevel(for index: Int) -> CelebrationLevel {
        let oneBased = index + 1
        switch oneBased {
        case 1: return .small(copy: "Nice!")
        case 2: return .small(copy: "You got it!")
        case 3: return .small(copy: "That's a trio!")
        case 4: return .small(copy: "Four for four!")
        case 12: return .capstone
        default: return .medium
        }
    }
}

/// Celebration tier applied on a correct pick. Drives both haptic and view
/// overlay so the intensity curve matches the hint-fade curve.
nonisolated enum CelebrationLevel: Equatable {
    case small(copy: String)
    case medium
    case capstone
}
