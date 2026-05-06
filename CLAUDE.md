# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Tertia is a SwiftUI iOS implementation of the Set card game. Single Xcode project, three targets: `Tertia` (app), `TertiaTests` (Swift Testing unit tests), `TertiaUITests` (XCUITest). Universal (iPhone/iPad), iOS 26.2 deployment target, Swift 5.

## Build / Test Commands

The project uses one shared scheme (`Tertia`) covering all three targets.

```bash
# Build for simulator
xcodebuild -project Tertia.xcodeproj -scheme Tertia \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests (unit + UI)
xcodebuild test -project Tertia.xcodeproj -scheme Tertia \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single Swift Testing case (note the @Suite name, then test function name)
xcodebuild test -project Tertia.xcodeproj -scheme Tertia \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:TertiaTests/SetGame/freshGameDealtCorrectly

# Run only unit tests (skip UI tests)
xcodebuild test -project Tertia.xcodeproj -scheme Tertia \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:TertiaTests
```

Unit tests use **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`), not XCTest. UI tests still use XCTest.

The Xcode project uses **PBXFileSystemSynchronizedRootGroup** — files added to `Tertia/`, `TertiaTests/`, or `TertiaUITests/` on disk are picked up automatically; no `project.pbxproj` edit is required to add a new source file.

## Architecture

### Layering

```
TertiaApp (entry, injects stores)
   └── ContentView (TabView: Play / Stats / Settings, gates onboarding)
        └── PlayCoordinator (ModeSelectView ↔ GameView)
             └── GameView (owns SetGame + optional TimeAttackController)
```

### Mode-driven gameplay

`GameMode` (`Models/GameMode.swift`) is the central pivot. The four modes — `practice`, `normal`, `timeAttack`, `daily` — each declare their own capabilities (`allowsHint`, `allowsDealThree`, `usesTimer`, `accentColor`, etc.). `SetGame` and `GameView` branch on these flags rather than checking the mode directly, so adding a mode means: add a case, set the capability flags, and the rest of the system follows.

Two cross-cutting wrinkles to know:

- **Practice does not auto-resolve a match.** When 3 cards are selected, `SetGame.autoResolvesMatch` is `false`, so `select(_:)` leaves the trio on screen. `GameView` shows a `PracticeVerdictBar` (built from the pure `explain(_:)` analysis), and only when the user dismisses it does `acknowledgeSelection()` run scoring/refill. Other modes resolve immediately inside `select(_:)`.
- **Daily mode uses a deterministic deck.** `GameView.init` swaps in `DailyPuzzle.deck(for:)` (seeded LCG keyed on `YYYYMMDD`) instead of `SetGame.standardDeck` — same calendar day, same deck, same puzzle for everyone. `SetGame` accepts a `deckBuilder` closure exactly so this is testable and pluggable.

### State / persistence

The project uses Swift's **Observation** framework (`@Observable`), not `ObservableObject`. Stores are injected via `.environment(...)` in `TertiaApp`:

- `HighScoreStore` — Time Attack scores, keyed by duration (UserDefaults `highScores.v1`).
- `DailyStore` — daily streak + today's record, with day-rollover logic (UserDefaults `daily.v1`). `displayedStreak` returns 0 if the user skipped a day; `currentStreak` is the persisted value.

Lightweight per-view prefs use `@AppStorage`: `hasCompletedOnboarding`, `lastGameMode`, `colorSchemePreference`.

### Pure set-explanation core

`explain(_ cards: [SetCard]) -> SetExplanation` (in `Models/SetExplanation.swift`) is the single source of truth for "is this a set?". `SetGame.isSet(_:)` is a thin wrapper. The richer return type — per-attribute `.allSame` / `.allDifferent` / `.mixed` outcomes — is what powers the practice-mode verdict bar. **When changing set rules, change `explain` only.**

### Board sizing

Constants live on `SetGame`: `boardSize = 12`, `setSize = 3`, `maxBoardSize = 21`. The board grows with **Deal 3** (allowed only when no set is visible and deck has cards) up to `maxBoardSize`; matching a set on an oversized board shrinks it back to `boardSize` rather than refilling. `GameView` computes its grid layout from `boardSlots.count`, so the view follows the model.

### Time Attack & Daily timing

`TimeAttackController` is a separate `@Observable` composed by `GameView` for any mode where `usesTimer` is true (timeAttack and daily). It pauses on `scenePhase` background/inactive and resumes on active. The expiry watcher is an `async` task in `GameView` (`runTimerWatcher`) re-keyed by `taskTrigger` whenever a new game starts — incrementing `taskTrigger` is how you cancel the old watcher and start a fresh one.

## Conventions

- Models and pure functions are marked `nonisolated` for Swift 6 concurrency; preserve this when adding new model types.
- `SetCard` synthesizes `Hashable` from a UUID, so two cards with identical attributes are distinct instances. Tests rely on this when planting known cards into `boardSlots`.
- New game modes require touching `GameMode` capability flags, the `ModeSelectView` list (`regularModes` excludes `.daily`, which is surfaced via `DailyHeroCard`), and possibly `GameView`'s game-over branching (`timeAttack` records to `HighScoreStore`, `daily` records to `DailyStore`).
