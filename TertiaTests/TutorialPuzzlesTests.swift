//
//  TutorialPuzzlesTests.swift
//  TertiaTests
//
//  Created by Mark Martin on 5/17/26.
//

import Foundation
import Testing
@testable import Tertia

@Suite("TutorialPuzzles")
struct TutorialPuzzlesTests {

    @Test("There are exactly 12 puzzles, indexed 1 through 12")
    func puzzleCountAndIndices() {
        #expect(TutorialPuzzles.all.count == 12)
        #expect(TutorialPuzzles.all.map(\.index) == Array(1...12))
    }

    @Test("Board size schedule matches spec (4/4/4/4 → 6/6/6 → 8/8/8/8 → 12)")
    func boardSizeSchedule() {
        let expected = [4, 4, 4, 4, 6, 6, 6, 8, 8, 8, 8, 12]
        for (puzzle, size) in zip(TutorialPuzzles.all, expected) {
            #expect(
                puzzle.cards.count == size,
                "puzzle \(puzzle.index) has \(puzzle.cards.count) cards, expected \(size)"
            )
        }
    }

    @Test("Puzzles 1–11 have exactly one valid trio, matching solutionAttributes")
    func exactlyOneSetForSmallPuzzles() {
        for puzzle in TutorialPuzzles.all where puzzle.index < 12 {
            let allTrios = combinations(puzzle.cards, choose: 3)
            let validTrios = allTrios.filter { explain($0).isSet }
            #expect(
                validTrios.count == 1,
                """
                puzzle \(puzzle.index) has \(validTrios.count) valid trios, expected 1.
                Valid trio attribute sets:
                \(validTrios.map { trio in trio.map { SetCardAttributes($0) } }.map { String(describing: $0) }.joined(separator: "\n"))
                """
            )

            guard let trio = validTrios.first else { continue }
            let trioAttrs = Set(trio.map(SetCardAttributes.init))
            let expectedAttrs = Set(puzzle.solutionAttributes)
            #expect(
                trioAttrs == expectedAttrs,
                "puzzle \(puzzle.index) solution attributes don't match the only valid trio on the board"
            )
        }
    }

    /// Capstone (12 cards) relaxes the "exactly one" invariant to "at least
    /// one". Designing a 12-card max cap-set + 3 solution cards is
    /// mathematically constrained (cap sets in F_3^3 max out at 9), and the
    /// capstone is meant to feel like real play where multiple sets exist
    /// on the board and the player finds any of them — same UX as Normal.
    @Test("Capstone has at least one valid trio and the documented solution is valid")
    func capstoneHasAtLeastOneValidSet() {
        guard let capstone = TutorialPuzzles.all.first(where: { $0.index == 12 }) else {
            Issue.record("capstone puzzle missing")
            return
        }
        let allTrios = combinations(capstone.cards, choose: 3)
        let validTrios = allTrios.filter { explain($0).isSet }
        #expect(validTrios.count >= 1, "capstone has no valid trios")

        let solutionAttrs = Set(capstone.solutionAttributes)
        let solutionIsValid = validTrios.contains { trio in
            Set(trio.map(SetCardAttributes.init)) == solutionAttrs
        }
        #expect(
            solutionIsValid,
            "capstone solutionAttributes don't match any valid trio on the board"
        )
    }

    @Test("All cards on each board are attribute-distinct (no duplicate cards)")
    func noDuplicateCardsPerBoard() {
        for puzzle in TutorialPuzzles.all {
            let attrs = puzzle.cards.map(SetCardAttributes.init)
            #expect(
                Set(attrs).count == attrs.count,
                "puzzle \(puzzle.index) has duplicate cards (by attribute)"
            )
        }
    }

    @Test("Hints are non-empty for puzzles 1–11 and nil for puzzle 12")
    func hintCopySchedule() {
        for puzzle in TutorialPuzzles.all {
            if puzzle.index == 12 {
                #expect(puzzle.hint == nil, "capstone should have no hint")
            } else {
                #expect(
                    (puzzle.hint ?? "").isEmpty == false,
                    "puzzle \(puzzle.index) is missing a hint"
                )
            }
        }
    }

    @Test("Hints for puzzles 1–8 contain at least one Markdown-bolded attribute word")
    func hintMarkdownBolding() {
        // Puzzles 1–8 explicitly name attributes (color/shape/number/fill) and
        // those words must be Markdown-bolded so the hint banner renders them
        // emphasized. Puzzles 9–11 are intentionally generic rule reminders
        // that don't name attributes, so they're exempt. Puzzle 12 (capstone)
        // has no hint at all.
        for puzzle in TutorialPuzzles.all where puzzle.index <= 8 {
            guard let hint = puzzle.hint else {
                Issue.record("puzzle \(puzzle.index) unexpectedly has nil hint")
                continue
            }
            #expect(
                hint.range(of: #"\*\*[a-z]+\*\*"#, options: .regularExpression) != nil,
                "puzzle \(puzzle.index) hint is missing a **bolded** attribute word: \(hint)"
            )
        }
    }
}

/// Returns all unordered k-combinations of `items`. Used to enumerate every
/// 3-card trio in a tutorial board for the "exactly one valid set"
/// invariant.
nonisolated func combinations<T>(_ items: [T], choose k: Int) -> [[T]] {
    guard k > 0 else { return [[]] }
    guard k <= items.count else { return [] }
    if k == items.count { return [items] }

    var result: [[T]] = []
    var indices = Array(0..<k)
    while true {
        result.append(indices.map { items[$0] })

        var i = k - 1
        while i >= 0 && indices[i] == items.count - k + i { i -= 1 }
        if i < 0 { break }
        indices[i] += 1
        for j in (i + 1)..<k {
            indices[j] = indices[j - 1] + 1
        }
    }
    return result
}
