# Stats Charts — Plan

Swift Charts buildout for the **Stats** tab. Goal: turn the current "list of recent Time Attack scores" into the kind of screen that earns its own App Store screenshot.

---

## What we have today

`StatsView.swift` is a single `List` filtered to the 90s Time Attack runs in `HighScoreStore`. Empty state is a CTA to play Time Attack.

**Persisted data we can lean on:**

| Source                      | Fields                                               | History? |
| --------------------------- | ---------------------------------------------------- | :------: |
| `HighScoreStore.entries`    | `score`, `durationSeconds`, `date`                   |    ✅    |
| `DailyStore.todaysRecord`   | `day`, `score`                                       |    ❌ (today only) |
| `DailyStore.currentStreak`  | scalar                                               |    —     |
| `DailyStore.bestStreak`     | scalar                                               |    —     |

**Per-session-only (lost on game end):**
- `SetGame.fastestSetSeconds` — already shown on game-over sheet, never persisted.
- `SetGame.longestStreak` (combo multiplier) — same.

The biggest data gap: **we don't keep daily history.** A streak heatmap or daily score trend needs `DailyStore` to retain past records.

---

## Target screen

Three sections, scrollable. Each chart targets a different question the player asks themselves.

### 1. Daily Streak Heatmap — *"Have I been showing up?"*

GitHub-contributions style grid. Last 12 weeks (or 30 days on phone, 90 on iPad). Each cell is a calendar day, color-coded by score tier (none / 1–3 / 4–6 / 7+ trios). Today highlighted with a ring. Tap a cell → score popover.

- **Chart type:** `Chart` with `RectangleMark` on `(weekIndex, dayOfWeek)` axes.
- **Data shape:** `[DailyRecord]` covering the visible window.
- **Empty state:** Faded grid + "Play your first daily to start a streak."
- **Why this first:** Daily is the differentiator and what gets a player coming back. The heatmap tells that story at a glance.

### 2. Time Attack Score Trend — *"Am I getting better?"*

Line chart of Time Attack scores over time. Personal-best line on top as a `RuleMark`. X = date, Y = score. `interpolationMethod(.monotone)`.

- **Chart type:** `LineMark` + `PointMark` for the most recent N entries; `RuleMark` for current best.
- **Empty state:** Friendly nudge to play Time Attack (the existing CTA, but smaller).
- **Sub-chart:** small "best by week" bar strip below if we have ≥3 weeks of data.

### 3. Solve-Time Distribution — *"How fast am I solving trios?"*

Histogram of per-trio solve times across all sessions. Bucketed into `0–2s`, `2–5s`, `5–10s`, `10s+`. Median line annotation.

- **Requires schema work** (see Phase 2 below) — we don't currently persist per-trio times.

---

## Phasing

### Phase 1 — Ship with what we already persist

Goal: real charts, no schema migrations. Half a day of work.

1. **Extract a `StatsViewModel`** so `StatsView` doesn't reach into stores directly. Computed properties for `dailyHistory`, `recentTimeAttackEntries`, `personalBestScore`. `@Observable`, takes both stores in init.
2. **Extend `DailyStore` with a history array.** Append a copy of `todaysRecord` to a new `pastRecords: [DailyRecord]` whenever `recordCompletion` is called for the first time on a day. Cap at 365 entries. Use the same `decodeIfPresent` pattern we just shipped for `dismissedDay` so existing users' streaks survive.
3. **Build the Daily Streak Heatmap.**
   - New file: `Tertia/Views/Stats/DailyStreakChart.swift`.
   - Input: `[DailyRecord]`, today's date.
   - Pure view, accepts an array — easy to preview with mocked data.
4. **Build the Time Attack Trend chart.**
   - New file: `Tertia/Views/Stats/TimeAttackTrendChart.swift`.
   - Input: `[HighScoreEntry]` (already filtered to a duration).
   - Top-K (last 30) line + best-line `RuleMark`.
5. **Recompose `StatsView`** as a `ScrollView` with section headers ("This Month", "Time Attack"). Keep the existing list as a "Recent runs" section under the trend chart.
6. **Tests:** `StatsViewModelTests` covering empty state, single-entry state, and 30+-entry state. Snapshot one chart in light + dark mode if we wire the snapshot infra.

**Deliverable after Phase 1:** Stats tab with Heatmap + Trend, real data, no per-trio histogram yet.

### Phase 2 — Persist per-trio solve data

Adds the histogram. ~half a day.

1. **Persist `SetGame` session summaries.** New `SessionRecord { mode, date, score, solveTimes: [Double] }` written to a new `SessionStore` on game end. UserDefaults-backed for now (matches existing pattern); SwiftData migration is a separate ticket.
2. **Update `SetGame`** to emit the array of solve times on completion, not just the fastest.
3. **Solve-Time Distribution chart.** `BarMark` over fixed buckets. Median annotation as a `RuleMark`.
4. **Tests:** confirm `SessionStore` round-trips, and that `SetGame` reports correct solve times.

### Phase 3 — Polish (do last, optional)

- **Time-of-day chart** — when do you actually play? Ring/polar chart. Cute, low signal.
- **Attribute weakness analysis** — "you misread fill 2× more often than other attributes." Useful but needs us to capture *which* attribute caused an invalid trio. Cool stretch.
- **iCloud sync** via SwiftData — same data, multi-device. Belongs to a broader migration story.

---

## Charts API choices

- **Pure-view + data-in.** Each chart takes its data as an input parameter, no environment grabs. Easier to preview, easier to test.
- **`Chart` over `ChartContent` views unless we're nesting.** Keep it boring.
- **Color from `GameMode.accentColor`.** Daily = purple, Time Attack = orange. Threading the same accent through Stats reinforces the mode language.
- **Accessibility:** every chart needs `.accessibilityChartDescriptor` or at minimum a manual `.accessibilityLabel` summarizing the trend ("Score has improved over the last 7 days, current best 12 trios"). The existing app is good about labels; charts can't regress that.
- **Reduce Motion:** disable any chart entry/exit animations under `\.accessibilityReduceMotion`.

---

## Open questions

1. **Heatmap window on phone** — 12 weeks tall is fine on iPad but cramped on iPhone. Default to 5 weeks and let users scroll horizontally? Or always show 30 days as a 5×6 grid?
2. **Time Attack durations** — store currently filters to 90s only. If we ever introduce 60s or 120s variants, the trend chart needs a duration picker. Defer the picker until we have ≥2 durations.
3. **Per-trio solve times — capture or compute?** Phase 2 captures them. We could *retroactively* approximate using existing `fastestSetSeconds` per session if we persist it; cheaper than full per-trio capture but loses the histogram shape. Vote: capture per-trio.
4. **History cap** — 365 daily records (~6 KB) and 1000 sessions (~50 KB) feels safe in UserDefaults. Move to SwiftData when we cross a threshold or want sync.

---

## Definition of done (Phase 1)

- [ ] `StatsViewModel` exists and is the only thing `StatsView` reads.
- [ ] `DailyStore.pastRecords` persists and round-trips through schema bump cleanly.
- [ ] `DailyStreakChart` renders with mock data in Previews (empty / sparse / dense).
- [ ] `TimeAttackTrendChart` renders with mock data in Previews (empty / single entry / 30+ entries).
- [ ] Stats tab in light + dark mode, both portrait orientations, looks intentional.
- [ ] Unit tests cover the view model's bucketing + empty-state branches.
- [ ] No regressions in the existing recent-runs list.
