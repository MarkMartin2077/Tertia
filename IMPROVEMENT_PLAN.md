# Triplix Improvement Plan

A prioritized list of fixes, features, and polish items for the Triplix Set card game.

---

## P0 — Bugs & Correctness

### 1. `resolveMatchedCards` parameter type
**File:** `Triplix/SetGame.swift:91`
**Issue:** Parameter typed as `Set<SetCard?>` but always called with `Set<SetCard>`.
**Fix:** Change signature to `func resolveMatchedCards(matching matchedCards: Set<SetCard>)` and update the `.contains` call accordingly.

### 2. `showHint()` silently clears selection when no set exists
**File:** `Triplix/SetGame.swift:111-113`
**Issue:** When `findSetOnBoard()` returns `[]`, `selectedCards = Set([].prefix(2))` clears the user's existing selection without any feedback.
**Fix:** Make `findSetOnBoard()` return `[SetCard]?` (or have `showHint` return `Bool`), and when nil/false, surface a UI message like "No sets on board — deal more cards."

### 3. `findSetOnBoard()` only randomizes outer loop
**File:** `Triplix/SetGame.swift:115-135`
**Issue:** Hints favor low-index second/third cards because only `firstIndex` is shuffled.
**Fix:** Generate all valid triples, shuffle the result, and return the first match. Or use a single shuffled list of index combinations.

### 4. ForEach identity defeats card transitions
**File:** `Triplix/ContentView.swift:24`
**Issue:** `ForEach(game.boardSlots.indices, id: \.self)` keys identity by slot index, so when a card is replaced, the transition (`.scale.combined(with: .opacity)`) doesn't trigger — SwiftUI sees the same identity.
**Fix:** Iterate over cards keyed by `card.id` for the transition to fire, or apply the transition to the inner `SetCardView` keyed on `card.id`.

---

## P1 — Missing Set Game Mechanics

### 5. No "New Game" action
**Issue:** `createBoard()` exists but is only called once from `init`.
**Fix:** Add a `newGame()` method on `SetGame` that resets `score`, `selectedCards`, `deck`, and `boardSlots`. Wire to a toolbar button in `ContentView`.

### 6. No "Deal 3 More Cards" action
**Issue:** Classic Set lets you deal extra cards when no set is visible on the board. With a fixed 18-slot board and no manual deal, players can be stuck if the visible cards contain no set.
**Fix:** Either:
- Switch from a fixed 18-slot board to a dynamic `[SetCard]` that grows in 3s, or
- Keep slots and add a "Deal 3" button that fills the next 3 nil slots from the deck (and grows the board if all slots are filled).

### 7. No deck-remaining indicator
**Fix:** Show `deck.count` somewhere in the toolbar or status line so players know how much game remains.

### 8. No game-over state
**Issue:** When the deck empties and no sets remain on the board, nothing happens.
**Fix:** Compute `isGameOver = deck.isEmpty && findSetOnBoard().isEmpty` and present an alert / overlay with final score and a "New Game" button.

### 9. No invalid-set feedback
**File:** `Triplix/SetGame.swift:65-75`
**Issue:** When the player selects 3 cards that don't form a set, there's no visible "wrong" state — they only learn it failed when they tap a 4th card and the selection clears.
**Fix:** Track an `invalidSelection: Bool` (or similar) and flash the 3 cards red briefly before clearing.

### 10. Score never decreases
**Issue:** No penalty for failed match attempts or hint usage.
**Fix (optional, design call):** Subtract 1 on invalid 3-card selection, subtract 1 per hint. Make this configurable if desired.

---

## P2 — Refactors

### 11. Resolve the `flatMap` TODO
**File:** `Triplix/SetGame.swift:27-55`
**Replace nested for-loops with:**
```swift
deck = CardShape.allCases.flatMap { shape in
    CardCount.allCases.flatMap { count in
        CardColor.allCases.flatMap { color in
            CardFill.allCases.map { fill in
                SetCard(shape: shape, count: count, color: color, fill: fill)
            }
        }
    }
}.shuffled()
```

### 12. Tighten `SetGame` API surface
**File:** `Triplix/SetGame.swift`
**Mark `private`:** `drawCards`, `createBoard`, `resolveMatchedCards`, `allSameOrAllDifferent`, `findSetOnBoard`. Keep public: `select`, `showHint`, and a future `newGame`/`dealThree`.

### 13. Name the magic numbers
**Issue:** `18` (slots), `3` (set size), `3` (columns), `6` (rows) are scattered between `SetGame` and `ContentView`, with `columnCount * rowCount` implicitly equal to slot count.
**Fix:** Add constants like `static let boardSize = 18`, `static let setSize = 3` on `SetGame`. In `ContentView`, derive `rowCount` from `boardSize / columnCount`.

### 14. Animate selection toggles
**File:** `Triplix/SetGame.swift:57-75`
**Issue:** Only `resolveMatchedCards` runs inside `withAnimation`. Selecting/deselecting cards is instant.
**Fix:** Wrap the body of `select(_:)` in `withAnimation` (or animate `isSelected` in `SetCardView`).

---

## P3 — Polish & Accessibility

### 15. Accessibility labels for cards
**File:** `Triplix/SetCardView.swift`
**Fix:** Add `.accessibilityLabel("\(card.count) \(card.color) \(card.fill) \(card.shape)")` (after making the enums describe themselves via `CustomStringConvertible` or similar).

### 16. Symbol size doesn't scale
**File:** `Triplix/SetSymbolView.swift:12`
**Issue:** Hardcoded `symbolSize = 32.0` will overflow on smaller devices and looks small on iPad.
**Fix:** Use `@ScaledMetric` for Dynamic Type support, or compute size from container with `GeometryReader` / `containerRelativeFrame`.

### 17. Hint UX
**File:** `Triplix/SetGame.swift:111-113`
**Issue:** Hint pre-selects 2 cards as if the user picked them — no visual distinction between hint state and normal selection.
**Fix:** Add a separate `hintedCards: Set<SetCard>` and render hinted cards with a different border (e.g. blue) so the user knows the system suggested them.

### 18. `SetCard` Hashable comment
**File:** `Triplix/SetCard.swift:10`
**Issue:** Auto-synthesized `Hashable` includes the `UUID id`, meaning two cards with identical attributes are distinct. This is intentional (every physical card in the deck is unique) but non-obvious.
**Fix:** One-line comment explaining the intent, or implement `Hashable` manually using only `id`.

---

## P4 — Testing & CI

### 19. No tests
**Issue:** No XCTest / Swift Testing target visible.
**Fix:** Add a `TriplixTests` target with at minimum:
- `isSet` truth table covering all-same, all-different, and mixed for each attribute
- `allSameOrAllDifferent` edge cases
- `select` flow: select 3 valid, select 3 invalid, deselect, 4th-card-after-3 reset
- `findSetOnBoard` with hand-crafted boards (known set / known no-set)

### 20. No CI
**Fix (optional):** Add a GitHub Actions workflow that runs `xcodebuild test` on push.

---

## Suggested Execution Order

1. **Quick wins:** #11 (flatMap), #12 (private), #13 (constants), #1 (type fix) — all small, mechanical.
2. **Core gameplay:** #5 (New Game), #6 (Deal 3), #7 (deck count), #8 (game over).
3. **Feedback loops:** #9 (invalid feedback), #2 (hint feedback), #17 (hint UX), #14 (selection animation), #4 (transition identity).
4. **Polish:** #15 (a11y), #16 (scaled metrics), #18 (Hashable comment).
5. **Confidence:** #19 (tests), #20 (CI).
