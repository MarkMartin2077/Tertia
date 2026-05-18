//
//  TutorialControllerTests.swift
//  TertiaTests
//
//  Created by Mark Martin on 5/17/26.
//

import Foundation
import Testing
@testable import Tertia

@MainActor
@Suite("TutorialController")
struct TutorialControllerTests {

    @Test("Fresh controller starts on puzzle 1 with no selection or verdict")
    func freshState() {
        let controller = TutorialController()
        #expect(controller.currentIndex == 0)
        #expect(controller.selectedCards.isEmpty)
        #expect(controller.verdict == nil)
        #expect(controller.celebration == nil)
        #expect(controller.isComplete == false)
        #expect(controller.finishedNaturally == false)
        #expect(controller.progressText == "1 / 12")
    }

    @Test("Tapping the same card toggles it off")
    func toggleSelection() {
        let controller = TutorialController()
        let card = controller.currentPuzzle.cards[0]
        controller.select(card)
        #expect(controller.selectedCards.count == 1)
        controller.select(card)
        #expect(controller.selectedCards.isEmpty)
        #expect(controller.verdict == nil)
    }

    @Test("Selecting 3 cards produces a verdict")
    func verdictOnThirdSelection() {
        let controller = TutorialController()
        let cards = controller.currentPuzzle.cards
        controller.select(cards[0])
        controller.select(cards[1])
        #expect(controller.verdict == nil)
        controller.select(cards[2])
        #expect(controller.verdict != nil)
    }

    @Test("Wrong pick → verdict, no advance, unlimited retries")
    func wrongPickHasNoConsequence() {
        let controller = TutorialController()
        let puzzle = controller.currentPuzzle

        // Plant a wrong trio: any 3 cards that don't match the solution.
        let solutionSet = Set(puzzle.solutionAttributes)
        let wrongCards = puzzle.cards
            .filter { !solutionSet.contains(SetCardAttributes($0)) }
        // Puzzle 1 has 4 cards, 3 in solution + 1 distractor. Need 3 wrong;
        // pick the distractor + 2 solution cards so the trio is invalid.
        let invalid = [wrongCards[0], puzzle.cards[0], puzzle.cards[1]]
        let invalidExplanation = explain(invalid)
        #expect(invalidExplanation.isSet == false, "test setup expected an invalid trio")

        for card in invalid {
            controller.select(card)
        }
        #expect(controller.verdict?.isSet == false)
        #expect(controller.currentIndex == 0)

        controller.dismissVerdict()
        #expect(controller.verdict == nil)
        #expect(controller.selectedCards.isEmpty)
        #expect(controller.currentIndex == 0)
        #expect(controller.isComplete == false)

        // Repeat 10x to confirm no retry limit.
        for _ in 0..<10 {
            for card in invalid { controller.select(card) }
            controller.dismissVerdict()
        }
        #expect(controller.currentIndex == 0)
        #expect(controller.isComplete == false)
    }

    @Test("Correct pick → advances to next puzzle on verdict dismiss")
    func correctPickAdvances() {
        let controller = TutorialController()
        let puzzle = controller.currentPuzzle
        let solution = puzzle.cards
            .filter { puzzle.solutionAttributes.contains(SetCardAttributes($0)) }
        #expect(solution.count == 3)

        for card in solution { controller.select(card) }
        #expect(controller.verdict?.isSet == true)
        #expect(controller.celebration != nil)

        controller.dismissVerdict()
        #expect(controller.currentIndex == 1)
        #expect(controller.verdict == nil)
        #expect(controller.celebration == nil)
        #expect(controller.selectedCards.isEmpty)
    }

    @Test("Skip → isComplete true, finishedNaturally false, no completion sheet")
    func skipExitsCleanly() {
        let controller = TutorialController()
        controller.skip()
        #expect(controller.isComplete == true)
        #expect(controller.finishedNaturally == false)
    }

    @Test("Capstone correct pick → finishedNaturally true")
    func capstoneCompletesNaturally() {
        let controller = TutorialController()
        // Drive through all puzzles.
        for _ in 0..<TutorialPuzzles.count {
            let puzzle = controller.currentPuzzle
            let solution = puzzle.cards
                .filter { puzzle.solutionAttributes.contains(SetCardAttributes($0)) }
            for card in solution { controller.select(card) }
            controller.dismissVerdict()
        }
        #expect(controller.isComplete == true)
        #expect(controller.finishedNaturally == true)
    }

    @Test("Celebration tier matches puzzle index schedule")
    func celebrationTierSchedule() {
        // Walk the controller through each puzzle, planting the solution,
        // checking celebration tier before dismissing.
        let expected: [Int: CelebrationLevel] = [
            0: .small(copy: "Nice!"),
            1: .small(copy: "You got it!"),
            2: .small(copy: "That's a trio!"),
            3: .small(copy: "Four for four!"),
            4: .medium,
            5: .medium,
            6: .medium,
            7: .medium,
            8: .medium,
            9: .medium,
            10: .medium,
            11: .capstone
        ]

        let controller = TutorialController()
        for index in 0..<TutorialPuzzles.count {
            let puzzle = controller.currentPuzzle
            let solution = puzzle.cards
                .filter { puzzle.solutionAttributes.contains(SetCardAttributes($0)) }
            for card in solution { controller.select(card) }
            #expect(
                controller.celebration == expected[index],
                "puzzle index \(index) celebration mismatch: got \(String(describing: controller.celebration))"
            )
            controller.dismissVerdict()
        }
    }

    @Test("Furthest puzzle reached updates monotonically and persists to UserDefaults")
    func furthestPuzzleReachedTracking() {
        // Clear any persisted value from prior test runs
        UserDefaults.standard.removeObject(forKey: "tutorialFurthestPuzzleReached")

        let controller = TutorialController()
        #expect(UserDefaults.standard.integer(forKey: "tutorialFurthestPuzzleReached") == 0)

        // Solve puzzle 1 → should record reaching puzzle 2
        let puzzle1 = controller.currentPuzzle
        let solution = puzzle1.cards.filter { puzzle1.solutionAttributes.contains(SetCardAttributes($0)) }
        for card in solution { controller.select(card) }
        controller.dismissVerdict()
        #expect(UserDefaults.standard.integer(forKey: "tutorialFurthestPuzzleReached") == 2)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "tutorialFurthestPuzzleReached")
    }

    @Test("Cannot select while verdict is showing")
    func selectionLockedDuringVerdict() {
        let controller = TutorialController()
        let cards = controller.currentPuzzle.cards
        controller.select(cards[0])
        controller.select(cards[1])
        controller.select(cards[2])
        #expect(controller.verdict != nil)

        let countBefore = controller.selectedCards.count
        controller.select(cards[0])
        #expect(controller.selectedCards.count == countBefore)
    }
}
