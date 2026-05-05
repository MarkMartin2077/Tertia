---
name: Tertia project context
description: Architecture, tech stack, and reviewer expectations for the Tertia Set card game app
type: project
---

Tertia is a SwiftUI iOS Set card game (iOS 26.2, Swift 5/6, @Observable — NOT VIPER, NOT ObservableObject). Single Xcode project, three targets: Tertia, TertiaTests (Swift Testing), TertiaUITests (XCUITest).

Key architectural facts:
- `SetGame` is the central @Observable model; `GameView` owns it via @State.
- `GameMode` enum drives all capability flags (allowsHint, allowsDealThree, usesTimer, autoResolvesMatch, accentColor).
- Practice mode: `autoResolvesMatch = false`. `select()` leaves trio on screen; `GameView` shows `PracticeVerdictBar`; only on dismiss does `acknowledgeSelection()` run scoring/refill.
- Daily mode: deterministic deck via `DailyPuzzle.deck(for:)` — seeded LCG keyed on YYYYMMDD.
- `TimeAttackController` is a separate @Observable owned by `GameView`; pauses on scenePhase background/inactive, resumes on active.
- Timer expiry watcher is an async task in `GameView` (`runTimerWatcher`) re-keyed by `taskTrigger` increment.
- Models/pure functions are `nonisolated` for Swift 6 concurrency.
- Unit tests use Swift Testing (@Suite, @Test, #expect), not XCTest.
- Build settings use `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`, making every type implicitly @MainActor unless marked `nonisolated`.
- `GameCenterService` added (April 2026): @MainActor @Observable wrapping GKLocalPlayer auth, leaderboard submission, and GKGameActivityListener bridging via private `ActivityListener: NSObject, GKLocalPlayerListener, GKGameActivityListener`.
- Backfill on first auth: ContentView submits the local 300s Time Attack best when `isAuthenticated` flips true.
- `GameCenterAuthenticationContainer` uses UIViewControllerRepresentable to host the GK auth VC in a fullScreenCover.
- Daily mode does NOT use `usesTimer` — daily timer (if any) is implied elsewhere; `GameMode.daily.usesTimer == false`.

**Why:** Reviewer needs this to avoid applying VIPER/ObservableObject rules incorrectly.
**How to apply:** Reviews should be framed around @Observable patterns, nonisolated model correctness, and GameMode-driven flow — not VIPER layering.
