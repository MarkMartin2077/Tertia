//
//  TutorialPuzzles.swift
//  Tertia
//
//  Created by Mark Martin on 5/17/26.
//

import Foundation

/// Hand-authored tutorial boards. Each puzzle 1–11 has exactly one valid trio,
/// verified by `TutorialPuzzlesTests`. Puzzle 12 (capstone) may contain multiple
/// valid trios. Hints use Markdown bolding on the four attribute words;
/// rendered with `Text(LocalizedStringKey(hint))`.
nonisolated enum TutorialPuzzles {
    static let all: [TutorialPuzzle] = [
        // MARK: Tier 1 — Screens 1–4 (4 cards each, one attribute all-same)

        // Puzzle 1: All-same-color (red) — count, shape, fill all-different.
        TutorialPuzzle(
            index: 1,
            cards: [
                SetCard(shape: .circle,   count: .one,   color: .red,  fill: .empty),
                SetCard(shape: .square,   count: .two,   color: .red,  fill: .rightHalf),
                SetCard(shape: .triangle, count: .three, color: .red,  fill: .filled),
                SetCard(shape: .circle,   count: .one,   color: .blue, fill: .empty)
            ],
            solutionAttributes: [
                .init(shape: .circle,   count: .one,   color: .red, fill: .empty),
                .init(shape: .square,   count: .two,   color: .red, fill: .rightHalf),
                .init(shape: .triangle, count: .three, color: .red, fill: .filled)
            ],
            hint: "Find 3 cards that are all the same **color**."
        ),

        // Puzzle 2: All-same-shape (circle) — count, color, fill all-different.
        TutorialPuzzle(
            index: 2,
            cards: [
                SetCard(shape: .circle, count: .one,   color: .red,   fill: .empty),
                SetCard(shape: .circle, count: .two,   color: .green, fill: .rightHalf),
                SetCard(shape: .circle, count: .three, color: .blue,  fill: .filled),
                SetCard(shape: .square, count: .one,   color: .red,   fill: .empty)
            ],
            solutionAttributes: [
                .init(shape: .circle, count: .one,   color: .red,   fill: .empty),
                .init(shape: .circle, count: .two,   color: .green, fill: .rightHalf),
                .init(shape: .circle, count: .three, color: .blue,  fill: .filled)
            ],
            hint: "Same rule. This time, all 3 cards share the same **shape**."
        ),

        // Puzzle 3: All-same-fill (empty) — shape, count, color all-different.
        TutorialPuzzle(
            index: 3,
            cards: [
                SetCard(shape: .circle,   count: .one,   color: .red,   fill: .empty),
                SetCard(shape: .square,   count: .two,   color: .green, fill: .empty),
                SetCard(shape: .triangle, count: .three, color: .blue,  fill: .empty),
                SetCard(shape: .circle,   count: .one,   color: .red,   fill: .filled)
            ],
            solutionAttributes: [
                .init(shape: .circle,   count: .one,   color: .red,   fill: .empty),
                .init(shape: .square,   count: .two,   color: .green, fill: .empty),
                .init(shape: .triangle, count: .three, color: .blue,  fill: .empty)
            ],
            hint: "Find the 3 cards whose **fill** is all empty."
        ),

        // Puzzle 4: All-same-count (two) — shape, color, fill all-different.
        // Distractor has count=one, so it can never complete a solution pair
        // (each solution pair would need a 3rd card with count=two).
        TutorialPuzzle(
            index: 4,
            cards: [
                SetCard(shape: .circle,   count: .two, color: .red,   fill: .empty),
                SetCard(shape: .square,   count: .two, color: .green, fill: .rightHalf),
                SetCard(shape: .triangle, count: .two, color: .blue,  fill: .filled),
                SetCard(shape: .circle,   count: .one, color: .red,   fill: .empty)
            ],
            solutionAttributes: [
                .init(shape: .circle,   count: .two, color: .red,   fill: .empty),
                .init(shape: .square,   count: .two, color: .green, fill: .rightHalf),
                .init(shape: .triangle, count: .two, color: .blue,  fill: .filled)
            ],
            hint: "Find 3 cards that all show the same **number**."
        ),

        // MARK: Tier 2 — Screens 5–7 (6 cards each, two attributes constrained)

        // Puzzle 5: color all-same (red) + count all-different (1/2/3).
        // Same-color anchor, varied counts/shapes/fills.
        TutorialPuzzle(
            index: 5,
            cards: [
                SetCard(shape: .circle,   count: .one,   color: .red,   fill: .empty),
                SetCard(shape: .circle,   count: .two,   color: .red,   fill: .empty),
                SetCard(shape: .circle,   count: .three, color: .red,   fill: .empty),
                SetCard(shape: .square,   count: .one,   color: .green, fill: .rightHalf),
                SetCard(shape: .triangle, count: .two,   color: .blue,  fill: .rightHalf),
                SetCard(shape: .circle,   count: .one,   color: .green, fill: .rightHalf)
            ],
            solutionAttributes: [
                .init(shape: .circle, count: .one,   color: .red, fill: .empty),
                .init(shape: .circle, count: .two,   color: .red, fill: .empty),
                .init(shape: .circle, count: .three, color: .red, fill: .empty)
            ],
            hint: "Now try one where attributes are mostly different: find 3 cards where the **number** is all different but the **color** is all the same."
        ),

        // Puzzle 6: shape all-same (triangle) + count all-different (1/2/3).
        TutorialPuzzle(
            index: 6,
            cards: [
                SetCard(shape: .triangle, count: .one,   color: .red,   fill: .filled),
                SetCard(shape: .triangle, count: .two,   color: .green, fill: .rightHalf),
                SetCard(shape: .triangle, count: .three, color: .blue,  fill: .empty),
                SetCard(shape: .circle,   count: .one,   color: .green, fill: .empty),
                SetCard(shape: .square,   count: .two,   color: .red,   fill: .filled),
                SetCard(shape: .triangle, count: .one,   color: .blue,  fill: .rightHalf)
            ],
            solutionAttributes: [
                .init(shape: .triangle, count: .one,   color: .red,   fill: .filled),
                .init(shape: .triangle, count: .two,   color: .green, fill: .rightHalf),
                .init(shape: .triangle, count: .three, color: .blue,  fill: .empty)
            ],
            hint: "Look at **shape** and **number** — one should be all-same, the other all-different."
        ),

        // Puzzle 7: color all-same (red) + fill all-different.
        // Solution: three red circles, count two, fills empty/rightHalf/filled.
        // Distractors are all green so any 1-solution + 2-distractor trio has
        // mixed color. Distractors share count=2/color=green; shape mix and a
        // mixed-fill in their own trio (DEF) prevent any accidental valid set.
        TutorialPuzzle(
            index: 7,
            cards: [
                SetCard(shape: .circle,   count: .two, color: .red,   fill: .empty),
                SetCard(shape: .circle,   count: .two, color: .red,   fill: .rightHalf),
                SetCard(shape: .circle,   count: .two, color: .red,   fill: .filled),
                SetCard(shape: .square,   count: .one, color: .green, fill: .empty),
                SetCard(shape: .triangle, count: .two, color: .green, fill: .rightHalf),
                SetCard(shape: .circle,   count: .three, color: .green, fill: .rightHalf)
            ],
            solutionAttributes: [
                .init(shape: .circle, count: .two, color: .red, fill: .empty),
                .init(shape: .circle, count: .two, color: .red, fill: .rightHalf),
                .init(shape: .circle, count: .two, color: .red, fill: .filled)
            ],
            hint: "This time look at **color** and **fill** — color all-same, fill all-different."
        ),

        // MARK: Tier 3 — Screens 8–11 (8 cards each, full Set complexity)

        // Puzzle 8: All-different across every attribute (classic Set).
        TutorialPuzzle(
            index: 8,
            cards: [
                SetCard(shape: .circle,   count: .one,   color: .red,   fill: .empty),
                SetCard(shape: .square,   count: .two,   color: .green, fill: .rightHalf),
                SetCard(shape: .triangle, count: .three, color: .blue,  fill: .filled),
                SetCard(shape: .circle,   count: .two,   color: .red,   fill: .rightHalf),
                SetCard(shape: .square,   count: .three, color: .green, fill: .filled),
                SetCard(shape: .triangle, count: .one,   color: .blue,  fill: .rightHalf),
                SetCard(shape: .circle,   count: .three, color: .red,   fill: .empty),
                SetCard(shape: .square,   count: .one,   color: .green, fill: .rightHalf)
            ],
            solutionAttributes: [
                .init(shape: .circle,   count: .one,   color: .red,   fill: .empty),
                .init(shape: .square,   count: .two,   color: .green, fill: .rightHalf),
                .init(shape: .triangle, count: .three, color: .blue,  fill: .filled)
            ],
            hint: "A valid trio can mix all-same and all-different — but no **color**, **shape**, **number**, or **fill** can be partially shared."
        ),

        // Puzzle 9: All-different across every attribute (different cards from puzzle 8).
        // Solution: (circle, three, green, empty) / (square, one, blue, rightHalf) /
        // (triangle, two, red, filled). Distractors share color=green + low counts;
        // every distractor trio is forced mixed on shape or count.
        TutorialPuzzle(
            index: 9,
            cards: [
                SetCard(shape: .circle,   count: .three, color: .green, fill: .empty),
                SetCard(shape: .square,   count: .one,   color: .blue,  fill: .rightHalf),
                SetCard(shape: .triangle, count: .two,   color: .red,   fill: .filled),
                SetCard(shape: .circle,   count: .one,   color: .green, fill: .empty),
                SetCard(shape: .circle,   count: .one,   color: .green, fill: .rightHalf),
                SetCard(shape: .square,   count: .one,   color: .green, fill: .empty),
                SetCard(shape: .square,   count: .one,   color: .green, fill: .rightHalf),
                SetCard(shape: .square,   count: .two,   color: .green, fill: .filled)
            ],
            solutionAttributes: [
                .init(shape: .circle,   count: .three, color: .green, fill: .empty),
                .init(shape: .square,   count: .one,   color: .blue,  fill: .rightHalf),
                .init(shape: .triangle, count: .two,   color: .red,   fill: .filled)
            ],
            hint: "Three cards. Every attribute either matches across all three, or differs across all three."
        ),

        // Puzzle 10: All-red same-color solution + 5 blue distractors.
        TutorialPuzzle(
            index: 10,
            cards: [
                SetCard(shape: .circle,   count: .one,   color: .red,  fill: .empty),
                SetCard(shape: .square,   count: .two,   color: .red,  fill: .rightHalf),
                SetCard(shape: .triangle, count: .three, color: .red,  fill: .filled),
                SetCard(shape: .circle,   count: .two,   color: .blue, fill: .empty),
                SetCard(shape: .square,   count: .three, color: .blue, fill: .rightHalf),
                SetCard(shape: .triangle, count: .one,   color: .blue, fill: .rightHalf),
                SetCard(shape: .circle,   count: .one,   color: .blue, fill: .rightHalf),
                SetCard(shape: .square,   count: .two,   color: .blue, fill: .filled)
            ],
            solutionAttributes: [
                .init(shape: .circle,   count: .one,   color: .red, fill: .empty),
                .init(shape: .square,   count: .two,   color: .red, fill: .rightHalf),
                .init(shape: .triangle, count: .three, color: .red, fill: .filled)
            ],
            hint: "Pick any card as your anchor. For the other two, each attribute must be either all-same or all-different — no exceptions."
        ),

        // Puzzle 11: All-triangle same-shape solution + 5 non-triangle distractors.
        // Buffer before the capstone — full board, brief hint.
        TutorialPuzzle(
            index: 11,
            cards: [
                SetCard(shape: .triangle, count: .one,   color: .red,   fill: .empty),
                SetCard(shape: .triangle, count: .two,   color: .green, fill: .rightHalf),
                SetCard(shape: .triangle, count: .three, color: .blue,  fill: .filled),
                SetCard(shape: .circle,   count: .one,   color: .green, fill: .rightHalf),
                SetCard(shape: .square,   count: .two,   color: .blue,  fill: .empty),
                SetCard(shape: .circle,   count: .three, color: .red,   fill: .filled),
                SetCard(shape: .square,   count: .one,   color: .red,   fill: .rightHalf),
                SetCard(shape: .circle,   count: .two,   color: .blue,  fill: .rightHalf)
            ],
            solutionAttributes: [
                .init(shape: .triangle, count: .one,   color: .red,   fill: .empty),
                .init(shape: .triangle, count: .two,   color: .green, fill: .rightHalf),
                .init(shape: .triangle, count: .three, color: .blue,  fill: .filled)
            ],
            hint: "Find any valid trio."
        ),

        // MARK: Tier 4 — Screen 12 (capstone — 12 cards, no hint)

        // Puzzle 12: All-red same-color solution + 9 mixed-color distractors.
        // Capstone — full-board complexity, no hint. May contain other valid
        // trios; only requirement is `solutionAttributes` matches at least one.
        TutorialPuzzle(
            index: 12,
            cards: [
                SetCard(shape: .circle,   count: .one,   color: .red,   fill: .empty),
                SetCard(shape: .square,   count: .two,   color: .red,   fill: .rightHalf),
                SetCard(shape: .triangle, count: .three, color: .red,   fill: .filled),
                SetCard(shape: .circle,   count: .two,   color: .green, fill: .rightHalf),
                SetCard(shape: .square,   count: .three, color: .green, fill: .empty),
                SetCard(shape: .triangle, count: .one,   color: .green, fill: .rightHalf),
                SetCard(shape: .circle,   count: .three, color: .blue,  fill: .rightHalf),
                SetCard(shape: .square,   count: .one,   color: .blue,  fill: .filled),
                SetCard(shape: .triangle, count: .two,   color: .blue,  fill: .filled),
                SetCard(shape: .circle,   count: .one,   color: .green, fill: .filled),
                SetCard(shape: .square,   count: .three, color: .blue,  fill: .rightHalf),
                SetCard(shape: .circle,   count: .two,   color: .blue,  fill: .empty)
            ],
            solutionAttributes: [
                .init(shape: .circle,   count: .one,   color: .red, fill: .empty),
                .init(shape: .square,   count: .two,   color: .red, fill: .rightHalf),
                .init(shape: .triangle, count: .three, color: .red, fill: .filled)
            ],
            hint: nil
        )
    ]

    static var count: Int { all.count }

    static func puzzle(at index: Int) -> TutorialPuzzle? {
        all.first { $0.index == index }
    }
}
