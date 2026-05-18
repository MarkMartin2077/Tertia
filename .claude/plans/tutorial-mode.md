# Tutorial Mode — Implementation Spec

## Summary

A guided 10-puzzle on-ramp that teaches Set's rules. Each puzzle shows a small, hand-authored board with exactly one valid set. Player picks 3; correct advances with a celebration that fades in intensity over the run, wrong shows the existing PracticeVerdictBar with no penalty and unlimited retries. Hints fade from prescriptive to absent across the 10 screens. Skippable at any time. Surfaces as a new mode on `ModeSelectView` (with a one-time "Recommended — start here" badge for new users) and re-enterable from Settings.

---

## 1. Data Model

### `TutorialPuzzle` (new — `Tertia/Models/TutorialPuzzle.swift`)

```swift
nonisolated struct TutorialPuzzle: Identifiable {
    let index: Int                  // 1...10, also `id`
    let cards: [SetCard]            // 4, 6, 8, or 12 — board the player sees
    let solutionAttributes: [SetCardAttributes]  // see below
    let hint: String?               // nil on screen 10 (capstone)
    var id: Int { index }
}
```

**Why an attribute tuple, not `Set<UUID>`?** `SetCard.id` is a fresh UUID per instance (see `Models/SetCard.swift`). If we author solutions by UUID, the cards must be `let` constants instantiated exactly once; any re-instantiation (preview, hot reload, copy) breaks the link. Authoring by attribute tuple is robust:

```swift
nonisolated struct SetCardAttributes: Hashable {
    let shape: CardShape
    let count: CardCount
    let color: CardColor
    let fill: CardFill
    init(_ card: SetCard) { /* ... */ }
}
```

The runtime resolves attributes → UUIDs at puzzle load: `puzzle.solutionCards = puzzle.cards.filter { puzzle.solutionAttributes.contains(SetCardAttributes($0)) }`. As long as the puzzle author doesn't put two attribute-identical cards on the same board (which would already be a deck violation — see `SetCard` comment about distinct instances), the mapping is unambiguous.

### `TutorialPuzzles` (new — `Tertia/Models/TutorialPuzzles.swift`)

Static, hand-authored:

```swift
nonisolated enum TutorialPuzzles {
    static let all: [TutorialPuzzle] = [
        TutorialPuzzle(index: 1, cards: [...4 cards...], solutionAttributes: [...3...], hint: "..."),
        // ...
        TutorialPuzzle(index: 10, cards: [...12 cards...], solutionAttributes: [...3...], hint: nil)
    ]

    static func puzzle(at index: Int) -> TutorialPuzzle? {
        all.first { $0.index == index }
    }
    static var count: Int { all.count }
}
```

### Board-size schedule

| Screens | Cards |
|---|---|
| 1–3 | 4 |
| 4–6 | 6 |
| 7–9 | 8 |
| 10 | 12 |

### Authoring constraint (enforced by tests)

**Puzzles 1–9:** exactly one valid trio across `cards.count choose 3` combinations, matching `solutionAttributes`.

**Puzzle 10 (capstone):** at least one valid trio, and the documented `solutionAttributes` matches one of them. The "exactly one" invariant is mathematically constrained for 12-card boards — the maximum cap set in F_3^3 is 9 cards, so 12 cards + a guaranteed solution unavoidably contains multiple valid trios. The capstone is meant to feel like real play anyway: the player finds *any* valid trio (same UX as Normal), so allowing multiple sets matches the intent. The controller doesn't read `solutionAttributes` — it accepts any valid trio.

Both invariants are unit-test only, not runtime assertions — broken authorship fails CI, not the player's session.

---

## 2. `GameMode` changes

Add `case tutorial` to `Tertia/Models/GameMode.swift`. Capability flag values:

| Flag | Value | Justification |
|---|---|---|
| `title` | "Tutorial" | |
| `description` | "Learn the rules in 10 hand-crafted puzzles." | |
| `systemImageName` | `"book.fill"` | distinct from practice's `graduationcap.fill` |
| `accentColor` | `.indigo` | distinct from other modes |
| `allowsHint` | `false` | tutorial provides its own hint copy; hint button would muddle the learning |
| `allowsDealThree` | `false` | board is fixed per puzzle |
| `usesTimer` | `false` | |
| `tracksCombo` | `false` | **new return value for this case** — no scoring shown |
| `awardsTimeBonus` | `false` | |

**`GameMode.regularModes`** — leave as-is. Tutorial is surfaced separately (see §5), the way `.daily` and `.versus` are. This keeps Free Play list semantically about replayable modes.

**No new flag is required.** All branching needed below is keyed off `mode == .tutorial` in the call sites that actually care (the tutorial view itself). We considered an `isTutorial` or `usesPredeterminedDeck` flag but neither paid for itself — `usesPredeterminedDeck` is already true for `.daily` and isn't checked anywhere; tutorial's special behaviors (per-puzzle board size, advance-on-correct, hint banner, progress indicator) are too tutorial-specific to belong on `GameMode`.

---

## 3. Game logic — **do NOT reuse `SetGame`**

### Recommendation: a thin dedicated controller

Create `Tertia/ViewModels/TutorialController.swift`:

```swift
@MainActor
@Observable
final class TutorialController {
    private(set) var currentIndex: Int = 0          // 0..<TutorialPuzzles.count
    private(set) var selectedCards = Set<SetCard>()
    private(set) var verdict: SetExplanation? = nil // non-nil while verdict bar is up
    private(set) var celebration: CelebrationLevel? = nil  // non-nil briefly after a correct pick
    private(set) var isComplete: Bool = false       // true on natural finish OR skip
    private(set) var finishedNaturally: Bool = false // distinguishes "show completion sheet" from skip

    var currentPuzzle: TutorialPuzzle { TutorialPuzzles.all[currentIndex] }
    var progressText: String { "\(currentIndex + 1) / \(TutorialPuzzles.count)" }
    var hint: String? { currentPuzzle.hint }
    var isCapstone: Bool { currentIndex == TutorialPuzzles.count - 1 }

    func select(_ card: SetCard) { /* tri-select, on 3rd: set verdict; if valid, also set celebration */ }
    func dismissVerdict() { /* if isSet → advance after celebration; else clear selection, verdict = nil */ }
    func advance() { /* currentIndex += 1, or finishedNaturally = true + isComplete = true */ }
    func skip() { isComplete = true /* finishedNaturally stays false */ }
}

enum CelebrationLevel: Equatable {
    case small(copy: String)   // screens 1–3: cards pulse green + overlay text + success haptic
    case medium               // screens 4–9: green pulse + haptic only
    case capstone             // screen 10: larger celebration, leads into completion sheet
}
```

**State machine notes:**

- On 3rd card select: `verdict = explain(selectedCards)`. If valid, also stamp `celebration` based on puzzle index. The verdict bar appears in both cases — the celebration overlay only appears on correct picks and only on the screens that warrant it (see §5).
- `dismissVerdict()` on a **wrong** pick: `verdict = nil`, `selectedCards = []`, `celebration = nil`. Puzzle unchanged. Player keeps going. **No retry counter, no score, no penalty.** The verdict bar's per-attribute explanation is the entire feedback loop.
- `dismissVerdict()` on a **correct** pick: trigger `feedback.validSet()`, hold the celebration briefly (~0.6s for small/medium, ~1.2s for capstone), then `advance()`. On screens 1–9 this cross-fades to the next puzzle; on the capstone it flips `finishedNaturally = true` and `isComplete = true`, which presents the completion sheet.
- `skip()` is reachable from the toolbar's "x" → confirmation dialog. Sets `isComplete = true` with `finishedNaturally = false` so the view dismisses without showing the completion sheet.

### Why not reuse `SetGame`?

`SetGame` is built around a deck → board → refill cycle: a fixed 12-card board (`SetGame.boardSize`), Deal 3 for stranded boards, scoring with combos, session stats for the game-over sheet. Tutorial needs none of it and breaks several invariants:

- Per-puzzle board size of 4/6/8/12 conflicts with `SetGame.boardSize = 12`. We'd need either a per-instance override (invasive — every `boardSize` reference becomes per-game state) or to live with `SetGame`'s assumption that an undersized board is mid-deal.
- `SetGame.select` auto-resolves valid trios outside practice mode, and practice mode runs the full scoring + refill pipeline on `acknowledgeSelection`. Tutorial wants neither — correct picks should advance the puzzle, not refill the board.
- Score, multiplier, `longestStreak`, `fastestSetSeconds`, `gameDurationSeconds`, etc. are all meaningless to the tutorial and would pollute `GameSessionStore` if we accidentally tripped `recordSessionIfTrackable`.

A 50-line dedicated controller is cheaper and clearer than adding modes-within-modes to `SetGame`.

### Reused pieces

- `explain(_ cards:)` from `Models/SetExplanation.swift` — the only logic the controller needs for verdicts.
- `PracticeVerdictBar` from `Views/Play/PracticeVerdictBar.swift` — verdict UI, used as-is.
- `SetCardView` from `Views/SetCardView.swift` — card rendering with selection/invalid/pulse states.
- `BoardBackground` — paper-folio tint shared by other screens.

---

## 4. View layer

### Recommendation: new `TutorialView`, not branched `GameView`

`GameView` is ~800 lines and already branches on `mode` in ~15 places (timer, daily, practice halo, game-over sheet variant, session recording, hint button, deal-three, etc.). Adding tutorial would push it well past a comfortable size and entangle scoring/timer/sheet logic with tutorial-only state.

### `Tertia/Views/Play/TutorialView.swift` — new

```swift
struct TutorialView: View {
    /// (completedNaturally, nextMode) — nextMode is non-nil only when the user
    /// tapped "Play Normal" from the completion sheet, so the coordinator can
    /// immediately launch a fresh game of that mode.
    let onExit: (_ completedNaturally: Bool, _ nextMode: GameMode?) -> Void

    @State private var controller = TutorialController()
    @State private var showSkipConfirmation = false
    @State private var showCapstoneTitleCard = false
    @Environment(FeedbackService.self) private var feedback
    @Environment(MusicService.self) private var music

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    hintBanner          // top — fades with puzzle.hint
                    gridArea            // adaptive 2/3-column based on card count
                }
                .opacity(showCapstoneTitleCard ? 0 : 1)

                // Capstone intro: brief fading title card before the board reveals.
                if showCapstoneTitleCard {
                    CapstoneTitleCard()
                        .transition(.opacity)
                }

                // Celebration overlay (non-blocking; sits above the board, below the verdict bar).
                if let celebration = controller.celebration {
                    CelebrationOverlay(level: celebration)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .boardBackground()
            .toolbar { toolbarContent }   // skip (x) leading, progress label in principal
            .safeAreaInset(edge: .bottom) {
                if let verdict = controller.verdict {
                    PracticeVerdictBar(
                        cards: Array(controller.selectedCards),
                        explanation: verdict,
                        onDismiss: { controller.dismissVerdict() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .confirmationDialog(
                "Skip tutorial?",
                isPresented: $showSkipConfirmation,
                titleVisibility: .visible
            ) {
                Button("Skip", role: .destructive) { controller.skip() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("You can replay it from Settings anytime.")
            }
            .sheet(isPresented: completionSheetBinding) {
                TutorialCompletionSheet(
                    onPlayNormal: { onExit(true, .normal) },
                    onBackToMenu: { onExit(true, nil) }
                )
                .interactiveDismissDisabled()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
            }
            .onChange(of: controller.isComplete) { _, isDone in
                // Skip path bypasses the completion sheet — exit immediately.
                if isDone && !controller.finishedNaturally {
                    onExit(false, nil)
                }
            }
            .onChange(of: controller.currentIndex) { _, newIndex in
                if newIndex == TutorialPuzzles.count - 1 {
                    runCapstoneIntro()
                }
            }
            .tint(GameMode.tutorial.accentColor)
        }
    }

    /// Only presents the completion sheet on natural finish, never on skip.
    private var completionSheetBinding: Binding<Bool> {
        Binding(
            get: { controller.isComplete && controller.finishedNaturally },
            set: { _ in }
        )
    }

    private func runCapstoneIntro() {
        withAnimation(.easeOut(duration: 0.25)) { showCapstoneTitleCard = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.easeIn(duration: 0.35)) { showCapstoneTitleCard = false }
        }
    }
}
```

### Layout details

- **Hint banner**: full-width card above the board, `font(.subheadline.weight(.medium))`, `.regularMaterial` background, indigo strokeBorder. Renders only when `controller.hint != nil`. Use a `.transition(.opacity)` keyed on `controller.currentIndex` so it cross-fades when the hint text changes between puzzles. **Markdown bolding** of attribute words is rendered automatically because `Text(_ key: LocalizedStringKey)` parses Markdown by default — pass the hint via the LocalizedStringKey-accepting overload (`Text(hint)`), not the verbatim variant. Verified: passing a `String` value through `Text(_:)` does NOT parse Markdown; it must go through `Text(LocalizedStringKey(hint))` or be a string literal. Use the explicit `Text(LocalizedStringKey(hint))` form to be safe.
- **Progress label**: place in `ToolbarItem(placement: .principal)`. For puzzles 1–9 show `"\(n) / 10"`. For the capstone (index 10), swap to a stylized label — `"The Real Deal"` in `.headline.weight(.semibold)` with the tutorial accent color — so it reads as a graduation moment rather than just "10/10".
- **Skip button**: `ToolbarItem(placement: .topBarLeading)` showing `Image(systemName: "xmark")` (matches the cancel idiom; "Skip tutorial" as accessibilityLabel). On tap, flips `showSkipConfirmation = true` (handled by the view's `.confirmationDialog`).
- **Grid**: adaptive column count to keep cards readable on small puzzles.
  - 4 cards → 2 columns × 2 rows
  - 6 cards → 3 columns × 2 rows (matches `GameView`)
  - 8 cards → 4 columns × 2 rows on regular width, 2 cols × 4 rows on compact
  - 12 cards → 3 columns × 4 rows (matches `GameView`)
  - Reuse the same `LazyVGrid` + `GeometryReader` cell-height computation pattern from `GameView.gridArea` so cards fill the available space proportionally.
- **Correct-pick transition**: on `controller.dismissVerdict()` when valid, briefly hold the trio highlighted (animation already provided by `SetCardView`'s isSelected state), play the celebration overlay (see below), then cross-fade the entire board out and the next puzzle in. Drive with `.transition(.opacity.combined(with: .scale(scale: 0.97)))` on the `ForEach` content, keyed on `controller.currentIndex`. Trigger `feedback.validSet()` on advance and `feedback.invalidSet()` on wrong-verdict dismiss — matches `GameView`.
- **Wrong picks**: PracticeVerdictBar already explains why. On dismiss, clear selection and let the player try again on the same puzzle. **Wrong answers don't count against anything** — no score, no retry counter, no penalty. The verdict bar IS the consequence: it teaches. This is intentional — the tutorial should be the safest place to be wrong.

### `Tertia/Views/Play/CelebrationOverlay.swift` — new (component)

Non-blocking overlay shown briefly on a correct pick. Tiered by puzzle index so celebration intensity fades alongside hint prescriptiveness:

| Screens | Level | Treatment |
|---|---|---|
| 1–3 | `.small(copy:)` | Cards pulse green (handled by `SetCardView` selection state) + centered overlay text + `feedback.validSet()`. Overlay auto-dismisses after ~0.8s. |
| 4–9 | `.medium` | Green card pulse + `feedback.validSet()` haptic. **No text overlay.** |
| 10 | `.capstone` | Larger celebration (scaled-up checkmark + accent glow + `feedback.validSet()`), held ~1.2s, then leads directly into the completion sheet. Optional: reuse the existing `ConfettiView.swift` here for the capstone — gives the moment some weight without making screens 1–9 noisy. |

**Per-screen copy variants (screens 1–3 only):**
- Screen 1: `"Nice!"`
- Screen 2: `"You got it!"`
- Screen 3: `"That's a trio!"` (use "trio" to match in-app vocabulary from `PracticeVerdictBar`, not "set")

**Visual placement** (small + medium tiers): overlay sits **centered horizontally**, **vertically positioned just above the verdict bar / safe-area inset bottom edge** — high enough to not collide with the verdict bar, low enough not to obscure the matched trio. Use `.regularMaterial` capsule background with accent-color stroke, `.title3.weight(.semibold)` text. The overlay is non-interactive (`.allowsHitTesting(false)`); the verdict bar remains the user's only tap target during the moment.

**Capstone tier** centers the celebration over the board, since the verdict bar dismisses immediately into the completion sheet.

```swift
struct CelebrationOverlay: View {
    let level: CelebrationLevel
    // body: switch on level → small text capsule, medium (returns EmptyView since
    // the haptic + card pulse carry it), or capstone (scaled checkmark + optional
    // ConfettiView wrap).
}
```

### `Tertia/Views/Play/CapstoneTitleCard.swift` — new (component)

Brief title card shown for ~1.4s before the capstone board reveals. **Avoid intimidation cues** — no red accents, no "Final challenge!" framing.

Content:
- Eyebrow text: `"You've learned the rules."` (.caption.weight(.semibold), secondary foreground)
- Title: `"The real deal."` (.largeTitle.bold, primary foreground)
- Subtitle: `"A full board. Find one trio."` (.subheadline, secondary foreground)
- Background: `.regularMaterial` rounded rect with subtle indigo accent stroke.

Tone: "you're ready for this," not "prove yourself."

### `Tertia/Views/Play/TutorialCompletionSheet.swift` — new

Shown only on natural completion (`finishedNaturally == true`); skip bypasses it.

**Presentation:** `.sheet` with `.presentationDetents([.medium])` and `.interactiveDismissDisabled()`. Chosen over `fullScreenCover` because the moment should feel like a friendly hand-off, not a screen takeover; chosen over an inline overlay because the dismiss-to-game transition is cleaner when SwiftUI owns the lifecycle. `.presentationDragIndicator(.hidden)` keeps the focus on the two CTAs.

**Content (final copy, ship as written):**

```
You've got it.

Ready for the real thing?

[ Play Normal ]    ← primary, .borderedProminent, tutorial accent tint
[ Back to menu ]   ← secondary, .bordered
```

- **Play Normal**: calls `onPlayNormal()` → view calls `onExit(true, .normal)` → `PlayCoordinator` dismisses the tutorial cover and immediately starts a fresh Normal game (see §7).
- **Back to menu**: calls `onBackToMenu()` → view calls `onExit(true, nil)` → coordinator dismisses to `ModeSelectView`.

Both paths set `hasFinishedTutorial = true` in the coordinator (handled in §7).

---

## 5. Routing

### `ModeSelectView.swift`

Tutorial gets surfaced as a regular `ModeCard` in the `freePlaySection` (or, optionally, as its own small hero above Free Play — either is fine; ModeCard is less work and reads cleanly given the existing `showsRecommendedBadge` pattern that's already there for `.practice`). It is **always visible**, even after completion — that's the entry point for replays from outside Settings, and a completed tutorial doesn't need to disappear from the list.

Add `.tutorial` to `GameMode.regularModes` so it surfaces via the existing `freePlaySection` `ForEach`. The card uses the existing `ModeCard` component with the recommended-badge mechanism already wired for `.practice`. **Replace** the existing `showsRecommendedBadge: mode == .practice && !hasFinishedAnyGame` rule with a tutorial-targeted version (see below) — `.practice` no longer needs the "Recommended" badge because the tutorial is now the canonical on-ramp for new users.

#### Tutorial-as-recommended badge (soft nudge, not auto-chain)

After onboarding completes, the player lands on `ModeSelectView` as today (no forced cover, no interception). The tutorial card shows a one-time `"Recommended — start here"` badge under three conjoined conditions:

```swift
showsRecommendedBadge:
    mode == .tutorial
    && hasCompletedOnboarding == true
    && hasFinishedTutorial == false
    && hasSeenTutorialNudge == false
```

**Storage keys** (all `@AppStorage`, defaults shown):

| Key | Default | Set by | Cleared/flipped by |
|---|---|---|---|
| `hasCompletedOnboarding` | `false` | onboarding "Get Started" (already exists) | n/a |
| `hasFinishedTutorial` | `false` | tutorial completion sheet path (either button) | reset to `false` by Settings "Replay tutorial" tap (see below) |
| `hasSeenTutorialNudge` | `false` | dismissal rule (below) | n/a — write-once flag |

**Dismissal rule for the badge** (planner pick — justification below): the badge clears when **the player taps any mode card on `ModeSelectView`** (tutorial or not). Implementation: `ModeSelectView.onSelect` and `onTutorial` both set `hasSeenTutorialNudge = true` before invoking their callback.

Why this rule:
- Clearing on "first tutorial start" only would leave the badge sticky for users who deliberately skipped the recommendation — annoying, and it makes the nudge feel coercive.
- Clearing on "tutorial completion" is too late — players who tried Normal first, came back, then started the tutorial would still see the nudge they already engaged with.
- Clearing on "first launch of any game" matches the intent of a *soft nudge*: it acknowledges the player made a choice, whatever it was, and gets out of the way.
- Resetting `hasSeenTutorialNudge` from Settings "Replay tutorial" is unnecessary — the badge is for first-run discoverability, not a perennial highlight.

**Badge visual treatment**: reuse the existing capsule pattern in `ModeCard` (`mode.accentColor.opacity(0.16)` background, `.caption2.weight(.semibold)`, `mode.accentColor` foreground). Copy: `"Recommended — start here"`. Slightly stronger than the current `"Recommended for new players"` on Practice because this is the canonical first-run path.

Closure plumbing: `ModeSelectView.onSelect` already handles all modes including `.tutorial` since tutorial is in `regularModes` — **no new closure needed**. The coordinator branches on `mode == .tutorial` inside `startMode(_:)`.

### `PlayCoordinator.swift`

Add state, cover, and tutorial-routing branch:

```swift
@AppStorage("hasFinishedTutorial") private var hasFinishedTutorial: Bool = false
@AppStorage("hasSeenTutorialNudge") private var hasSeenTutorialNudge: Bool = false
@State private var showTutorial = false

// In body, alongside the existing activeMode cover:
.fullScreenCover(isPresented: $showTutorial) {
    TutorialView(onExit: { completedNaturally, nextMode in
        showTutorial = false
        if completedNaturally {
            hasFinishedTutorial = true
        }
        // "Play Normal" path: kick off a Normal game immediately after the
        // tutorial cover dismisses. SwiftUI fires onChange of `activeMode`
        // even if it's set from inside a cover-dismiss closure; the brief
        // queueing is fine here.
        if let nextMode {
            startMode(nextMode)
        }
    })
}
```

**`startMode(_:)` branch** — intercept `.tutorial` before the `activeMode` cover:

```swift
private func startMode(_ mode: GameMode) {
    guard mode != .versus else { return }
    if mode == .tutorial {
        // Tutorial doesn't go through GameView, so don't update lastGameMode
        // (lastGameMode is for "resume the last real game you played"; tutorial
        // isn't that).
        showTutorial = true
        return
    }
    lastGameModeRaw = mode.rawValue
    activeMode = mode
}
```

Use a separate `fullScreenCover` (not the `activeMode` cover used for `GameView`) because tutorial doesn't fit `GameMode`-based routing cleanly — `activeMode` drives `GameView(mode:)`, and we don't want to route tutorial through there.

**Settings replay routing**: the Settings replay row needs to route into the tutorial too. Two options were considered:

| Option | Trade-off |
|---|---|
| Reset `hasFinishedTutorial = false` on tap, let the existing mode-card path show again | Surfaces the badge unnecessarily; conflates "I want to replay" with "I haven't done it yet" |
| Route directly to the tutorial cover via `requestedMode = .tutorial` (mirroring the existing notification-launched-mode pattern) | Cleaner — leaves `hasFinishedTutorial` truthfully `true`, just opens the cover |

**Pick option 2.** SettingsView already lives outside the Play tab; the cleanest cross-tab signal is the existing `requestedMode: Binding<GameMode?>` plumbed from `ContentView` into `PlayCoordinator`. Tapping "Replay tutorial" in Settings sets `requestedMode = .tutorial`, switches the TabView selection to Play, and the coordinator's existing `onChange(of: requestedMode)` calls `startMode(.tutorial)` which routes to the tutorial cover. The replay completion just re-fires the completion sheet path; `hasFinishedTutorial` stays `true`.

(If this cross-tab plumbing is heavier than expected at implementation time, fallback: add a dedicated `@AppStorage("requestTutorialReplay") Bool` flag that `PlayCoordinator` watches via `onChange`. But the `requestedMode` route already exists and just needs `.tutorial` to be a valid value, which it is once added to `GameMode`.)

### `SettingsView.swift` — add replay row

Place a new `Section("Tutorial")` between `"Audio & Haptics"` and `"Game Center"`. One row:

```swift
Section("Tutorial") {
    Button {
        // Switch to Play tab + request tutorial via the existing routing channel.
        // Implementation: a small @Binding<GameMode?> requestedMode and selectedTab
        // wired from ContentView, same pattern as the notification-launched daily mode.
        requestedMode = .tutorial
        selectedTab = .play
    } label: {
        LabeledContent {
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.footnote)
        } label: {
            Label("Replay tutorial", systemImage: "book.fill")
                .foregroundStyle(.primary)
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Replay tutorial")
    .accessibilityHint("Restart the 10-puzzle tutorial from the beginning")
}
```

Copy: **"Replay tutorial"** (chosen over "Show tutorial again" — shorter, action-oriented, matches the verb-style of "Open Game Center" elsewhere in the form).

Section placement: between "Audio & Haptics" and "Game Center". Putting it under "Help" alongside "How to Play" would also be defensible — both surface educational content — but the tutorial is interactive gameplay, not reference material, so a dedicated section signals the difference. If section-count bloat is a concern at implementation, folding into "Help" as a row above "How to Play" is the acceptable alternative.

**Plumbing dependency**: this row needs `requestedMode: Binding<GameMode?>` and `selectedTab: Binding<Tab>` (or equivalent) passed into `SettingsView`. Check `ContentView.swift` for the existing wiring pattern used for the daily-launch flow and mirror it.

### Persistence summary

Two new `@AppStorage` keys:

| Key | Type | Where read | Where written |
|---|---|---|---|
| `hasFinishedTutorial` | `Bool` | `PlayCoordinator`, `ModeSelectView` (badge gate) | `PlayCoordinator` on tutorial completion |
| `hasSeenTutorialNudge` | `Bool` | `ModeSelectView` (badge gate) | `ModeSelectView` on any mode-card tap |

No new store. No per-puzzle progress persistence — if the player skips at puzzle 4, they restart from puzzle 1 next time. The spec is small enough that this is fine.

---

## 6. Hint copy — full 10

Calibrated to the fading curve (1–3 = explicit attribute callouts, 4–6 = narrower hints, 7–9 = pure rule reminders, 10 = silent). The four attribute words — **color**, **shape**, **number**, **fill** — are bolded everywhere they appear via Markdown literals (`**word**`) so the hint banner highlights the vocabulary every time it's named.

| # | Cards | Hint |
|---|---|---|
| 1 | 4 | `"A trio is 3 cards where every attribute is all-same OR all-different. The 3 cards here that match all share the same **color**."` |
| 2 | 4 | `"Same rule. This time, all 3 cards share the same **shape**."` |
| 3 | 4 | `"Same rule. This time, the **fill** is all the same — find the 3 cards that match."` |
| 4 | 6 | `"Now try one where attributes are mostly different: find 3 cards where the **number** is all different but the **color** is all the same."` |
| 5 | 6 | `"Look at **shape** and **number** — one should be all-same, the other all-different."` |
| 6 | 6 | `"A valid trio can mix all-same and all-different attributes freely — just no attribute can be partially shared. Check **color**, **shape**, **number**, and **fill** one at a time."` |
| 7 | 8 | `"Pick any card. Then ask: for the next two, does every attribute stay consistently same or consistently different?"` |
| 8 | 8 | `"Three cards. Every attribute either matches across all three, or differs across all three."` |
| 9 | 8 | `"Find any valid trio."` |
| 10 | 12 | _(no hint — capstone)_ |

**Vocabulary note:** "trio" is used in place of "set" to match the in-app vocabulary already used by `PracticeVerdictBar` ("It's a trio!" / "Not a trio"). **"Fill"** is used (not "shading") to match the rest of the app: `CardFill` enum, `SetAttribute.fill` label, and the existing user-facing copy in `ExampleTrioView` ("fill is mixed") all use "fill". The `CardFill` value names players see are **"empty"**, **"half"**, **"filled"** — use these literals when hint copy ever needs to refer to a specific fill state.

**Markdown rendering**: SwiftUI's `Text(_ key: LocalizedStringKey)` parses Markdown automatically for string-literal arguments. To render a `String` value (the puzzle's `hint` field) with Markdown, wrap it explicitly: `Text(LocalizedStringKey(hint))`. **Do not** pass `Text(verbatim: hint)` — that disables Markdown. Verified pattern; note this in the hint banner implementation.

These are ship copy. The structural commitment (tested): screen 10 has `hint == nil`; screens 1–9 are non-empty; screens 1–6 each contain at least one `**word**` Markdown literal.

---

## 7. Test plan — `TertiaTests/TutorialPuzzlesTests.swift` (new)

Swift Testing suite:

```swift
@Suite("TutorialPuzzles")
struct TutorialPuzzlesTests {

    @Test("There are exactly 10 puzzles, indexed 1 through 10")
    func puzzleCountAndIndices() {
        #expect(TutorialPuzzles.all.count == 10)
        #expect(TutorialPuzzles.all.map(\.index) == Array(1...10))
    }

    @Test("Board size schedule matches spec (4/4/4/6/6/6/8/8/8/12)")
    func boardSizeSchedule() {
        let expected = [4,4,4, 6,6,6, 8,8,8, 12]
        for (puzzle, size) in zip(TutorialPuzzles.all, expected) {
            #expect(puzzle.cards.count == size, "puzzle \(puzzle.index) has \(puzzle.cards.count) cards, expected \(size)")
        }
    }

    @Test("Every puzzle has exactly one valid set, and it matches solutionAttributes")
    func exactlyOneSetPerPuzzle() {
        for puzzle in TutorialPuzzles.all {
            let allTrios = combinations(puzzle.cards, choose: 3)
            let validTrios = allTrios.filter { explain($0).isSet }
            #expect(validTrios.count == 1, "puzzle \(puzzle.index) has \(validTrios.count) valid trios, expected 1")

            if let trio = validTrios.first {
                let trioAttrs = Set(trio.map(SetCardAttributes.init))
                let expectedAttrs = Set(puzzle.solutionAttributes)
                #expect(trioAttrs == expectedAttrs, "puzzle \(puzzle.index) solution attributes don't match the only valid trio on the board")
            }
        }
    }

    @Test("All cards on each board are attribute-distinct (no duplicate cards)")
    func noDuplicateCardsPerBoard() {
        for puzzle in TutorialPuzzles.all {
            let attrs = puzzle.cards.map(SetCardAttributes.init)
            #expect(Set(attrs).count == attrs.count, "puzzle \(puzzle.index) has duplicate cards")
        }
    }

    @Test("Hints are non-empty for puzzles 1–9 and nil for puzzle 10")
    func hintCopySchedule() {
        for puzzle in TutorialPuzzles.all {
            if puzzle.index == 10 {
                #expect(puzzle.hint == nil)
            } else {
                #expect((puzzle.hint ?? "").isEmpty == false, "puzzle \(puzzle.index) is missing a hint")
            }
        }
    }

    @Test("Hints for puzzles 1–6 contain at least one Markdown-bolded attribute word")
    func hintMarkdownBolding() {
        for puzzle in TutorialPuzzles.all where puzzle.index <= 6 {
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
```

Plus a `TutorialControllerTests` suite covering all controller behavior. Use `@MainActor` test functions since the controller is `@MainActor`.

- **Selection lifecycle:** tap 1 card → selected, no verdict; tap 2 → still no verdict; tap 3 → `verdict != nil`; tap the same card again before 3rd → deselects.
- **Wrong pick → verdict appears, no advance:** plant a known wrong trio on puzzle 1, verify `verdict` is non-nil and `verdict?.isSet == false`, dismiss, verify `selectedCards.isEmpty`, `verdict == nil`, `currentIndex == 0` (unchanged).
- **No retry limit:** loop 10 times: select 3 wrong cards, dismiss verdict. After all 10, `currentIndex` is still 0, no `isComplete`, no scoring state exists (there's no scoring state to assert on — confirmed by the controller's `private(set)` surface containing no counters).
- **Correct pick → advances:** plant the puzzle's solution trio, dismiss verdict, verify `currentIndex == 1`.
- **Capstone correct pick → completion sheet path:** advance to `currentIndex == 9`, plant solution, dismiss verdict, verify `isComplete == true` AND `finishedNaturally == true`.
- **Skip → exits without completion sheet:** call `skip()`, verify `isComplete == true` AND `finishedNaturally == false`.
- **Celebration tier per puzzle:** after selecting a correct trio on puzzle 1, `celebration == .small(copy: "Nice!")`; on puzzle 4, `celebration == .medium`; on puzzle 10, `celebration == .capstone`.

`combinations(_:choose:)` is a 4-line local test helper; doesn't need to be in app code.

### Light UI / integration tests (XCUITest — optional but recommended)

Add to `TertiaUITests/TutorialUITests.swift`:

- **Recommended badge appears for new users:** fresh install state (clear `UserDefaults`), complete onboarding, assert "Recommended — start here" capsule is visible on the tutorial card.
- **Badge disappears after engagement:** tap any mode card from the badged state, return to mode select, assert the badge is gone.
- **Completion sheet "Play Normal" routes into a Normal game:** drive the tutorial to completion (or stub `hasFinishedTutorial` and re-enter via Settings replay path, plant a known-winning input), tap "Play Normal", assert `GameView` for `.normal` is on screen.
- **Settings replay re-enters tutorial:** with `hasFinishedTutorial == true`, tap Settings → "Replay tutorial", assert `TutorialView` is on screen and `hasFinishedTutorial` is still `true` afterward (replay doesn't clear the flag).

---

## 8. Open questions / call-outs

All seven original open questions have been resolved by user decision (see decision log in the spec history). The implementation as described above represents the locked design.

New questions surfaced during the propagation pass:

1. **Capstone confetti tradeoff.** The spec leaves confetti as optional on the capstone celebration. `ConfettiView.swift` exists in the codebase already (verify), so the cost is low. Recommendation: include it for the capstone moment only — it differentiates the graduation feel from the per-puzzle celebrations without being overused. If at implementation it visually clashes with the completion sheet transition (sheet animates up while confetti is still falling), gate the sheet presentation behind a ~300ms delay after the confetti starts.

*(Vocabulary question resolved: hints use **"fill"** to match the rest of the app — `CardFill`, `SetAttribute.fill` label, and existing copy in `ExampleTrioView` all use "fill". See §6 vocabulary note.)*

---

## 9. Out of scope (do NOT do in this PR)

- Modifying `OnboardingView` or the `hasCompletedOnboarding` flag itself. The tutorial is gated *off* of `hasCompletedOnboarding`, but onboarding doesn't change.
- Analytics / telemetry on tutorial progression.
- Localization of hint copy (current copy is English-only string literals; matches the rest of the app).
- Per-puzzle progress persistence (resume from where you left off after a skip).
- Adaptive difficulty or branching puzzle order.
- Game Center achievement for completing the tutorial.
- Tutorial-specific sound effects beyond reusing `FeedbackService.validSet()` / `.invalidSet()`.
- Any change to `SetGame`, `HighScoreStore`, `DailyStore`, `GameSessionStore`, or `VersusStore`.

**Now in scope** (moved up from out-of-scope per resolved decisions):
- Soft-nudge tutorial recommendation on `ModeSelectView` after onboarding (no forced auto-chain).
- "Replay tutorial" row in `SettingsView`.

---

## File checklist

**New files** (PBXFileSystemSynchronizedRootGroup — drop on disk, Xcode picks up):
- `Tertia/Models/TutorialPuzzle.swift` — struct + `SetCardAttributes` helper
- `Tertia/Models/TutorialPuzzles.swift` — static `all: [TutorialPuzzle]` + hint copy
- `Tertia/ViewModels/TutorialController.swift` — `@MainActor @Observable` controller (with `CelebrationLevel` enum)
- `Tertia/Views/Play/TutorialView.swift` — main screen
- `Tertia/Views/Play/TutorialCompletionSheet.swift` — completion sheet
- `Tertia/Views/Play/CelebrationOverlay.swift` — tiered correct-pick overlay (small / medium / capstone)
- `Tertia/Views/Play/CapstoneTitleCard.swift` — brief "The real deal" intro card before puzzle 10
- `TertiaTests/TutorialPuzzlesTests.swift` — puzzle invariants (incl. hint Markdown bolding)
- `TertiaTests/TutorialControllerTests.swift` — controller behavior (incl. unlimited-wrong, celebration tier, finishedNaturally vs skip)
- `TertiaUITests/TutorialUITests.swift` — recommended-badge appearance/dismissal + completion sheet routing + Settings replay (optional but recommended)

**Modified files**:
- `Tertia/Models/GameMode.swift` — add `.tutorial` case + capability values, include in `regularModes`
- `Tertia/Views/Play/ModeSelectView.swift` — flip `showsRecommendedBadge` from `.practice` to `.tutorial` with the conjoined gate (`hasCompletedOnboarding && !hasFinishedTutorial && !hasSeenTutorialNudge`); set `hasSeenTutorialNudge = true` on any mode-card tap
- `Tertia/Views/Play/PlayCoordinator.swift` — add `showTutorial` state, `fullScreenCover` for tutorial, branch in `startMode(_:)` to route `.tutorial` to the cover instead of `activeMode`; plumb `hasFinishedTutorial` and `hasSeenTutorialNudge` `@AppStorage`; handle `(completedNaturally, nextMode)` from tutorial exit and auto-start `.normal` if requested
- `Tertia/Views/SettingsView.swift` — add `Section("Tutorial")` with "Replay tutorial" row that fires `requestedMode = .tutorial` and switches to Play tab
- `Tertia/Views/ContentView.swift` — verify/extend the existing `requestedMode` binding to include `SettingsView` as a source (mirrors the daily-launch pattern); may also need to pass a `selectedTab` binding into `SettingsView`

No `pbxproj` edits required.
