# Versus Mode — Plan

A 1-on-1 real-time mode where two players race against the same deck. Whoever finds and claims a valid trio first earns the points. Highest score when the deck clears wins.

This document is the source of truth for how versus mode is shaped. If a Claude session needs to pick this up, start here.

---

## Locked decisions

### Architecture
- **Transport:** Game Center Real-Time Multiplayer (`GKMatch`) over the internet.
- **Match scopes:** Quick Match (random opponent) and Invite Friend (direct from GC friends).
- **Bot fallback:** none — if matchmaking fails, show "Couldn't find a match" with Retry / Done.
- **Authority model:** host-authoritative. One peer is silently designated host (deterministic playerID hash so both peers agree without a round-trip). Host owns the `SetGame` model and arbitrates all claims; guest mirrors via messages.

### Game rules
- **Hints:** disabled in versus.
- **Deal 3:** appears when no trio is on the board. Either player can tap it. Host applies and broadcasts.
- **Timer:** none — game ends when the deck is cleared and no trio remains.
- **Combos / multipliers:** per-player. Each player's own streak stacks; opponent's streak is independent.
- **Selection privacy:** ongoing 1-card and 2-card picks are hidden from the opponent. Only after a successful third-tap claim does the opponent see anything.
- **Successful-claim feedback (rendered on opponent's device):**
  - Matched cards pulse for 1.5s in your accent color, then dissolve.
  - Brief haptic tick on opponent's device.
  - Opponent's score chip pulses with the new value.
  - "+N" toast surfaces above their score chip (mirrors existing `PointsToast`).
- **Invalid claim (your three cards are not a trio):**
  - Your selection clears.
  - You enter a 1.5s lockout — taps on the board are ignored.
  - A circular progress indicator at screen bottom counts down the lockout.
  - Opponent is unaffected and free to claim during your lockout window.

### End conditions and tiebreakers
- Game ends when the deck is empty and no trio remains on the board.
- Winner: highest score.
- Tiebreaker 1: most trios found.
- Tiebreaker 2 (extremely rare — same score and same trio count): draw.

### Disconnect / forfeit
- Reconnect grace: **20 seconds**. Past that, the absent player is treated as forfeited.
- Host disconnect → match ends as forfeit by host; guest wins.
- App backgrounded (home, phone call, etc.) → same as disconnect.
- Both players disconnect simultaneously → draw, recorded independently on each side when each comes back online (in-memory only, no peer to confirm — acceptable).
- Explicit forfeit button replaces the back-button warning logic in versus.

### End-of-game sheet
Layout: winner banner, both scores side-by-side. Per-player stats: trios claimed, longest streak, fastest set.

Buttons:
- **Rematch** — sends a rematch request to opponent. Shows "Waiting for [opponent]…" with a 15s timer. If opponent accepts within the window, both transition into a fresh versus game with the same `MatchSession`. If they decline or time out, sheet updates: "[Opponent] left — find a new match?" with a Quick Match button.
- **Done** — back to mode select.

Match auto-records to `VersusStore` before sheet appears.

### Stats (four-column record)
- **Wins / Losses / Forfeits / Draws** as separate columns. Forfeits are not folded into losses.
- New "Versus" section in `StatsView` mirrors the existing "Time Attack" pattern: tile row (W/L/F/D), recent matches list. Optional: win-rate-over-time chart.

---

## Phased plan

### Phase 1 — Mode plumbing (~½ day)
- `GameMode.versus` case with capability flags (`allowsHint = false`, `allowsDealThree = true`, `usesTimer = false`, `tracksCombo = true`, `awardsTimeBonus = false`, accent `.teal`).
- `regularModes` excludes `.versus`.
- `Views/Play/VersusHeroCard.swift` — mirrors `DailyHeroCard`. Two CTAs: Quick Match + Invite Friend.
- `ModeSelectView` integrates the hero card adjacent to `DailyHeroCard`.
- Phase 1 wires the CTAs to a "coming soon" alert in `PlayCoordinator` so the entry point ships honestly until Phase 2 is ready.

### Phase 2 — Networking layer (~2 days)
**New files:**
- `Services/VersusMessage.swift` — Codable enum:
  - `.deckSeed(UInt64)`
  - `.claim(cardIDs: [UUID], at: Date)`
  - `.claimResult(winner: PlayerID, cards: [UUID], success: Bool, hostScore: Int, guestScore: Int, hostTrios: Int, guestTrios: Int)`
  - `.dealThreeRequest(by: PlayerID)`
  - `.dealThreeAck`
  - `.forfeit(by: PlayerID)`
  - `.heartbeat(at: Date)`
- `Services/MatchTransport.swift` — protocol fronting `GKMatch`. Concrete `GKMatchTransport` for production; stub conformer for unit tests.
- `Services/MatchSession.swift` — `@MainActor @Observable`. Wraps `MatchTransport`. Exposes `send(_:)`, `incoming: AsyncStream<VersusMessage>`, `localPlayer`, `remotePlayer`, `isHost`, `connectionState`. Heartbeat sender on a 5s interval; receiver tracks `lastHeartbeatAt` and emits a disconnect event after 20s of silence.

**Why protocol-fronted:** GKMatch can't run in unit tests. The protocol lets the game model and arbitration logic above it be unit-tested with a stub.

### Phase 3 — Matchmaking UI (~1 day)
- `Views/Versus/VersusMatchmakerView.swift` — wraps `GKMatchmakerViewController` via `UIViewControllerRepresentable`.
- Two paths from `VersusHeroCard`: Find Opponent (random) and Invite Friend (`GKMatchRequest.recipients` populated from `GKLocalPlayer.local.loadFriends`).
- Loading state with cancel button.
- On match found: hand `MatchSession` to `VersusGameView`.
- Empty / failure: "Couldn't find a match" alert with Retry / Done.

### Phase 4 — Versus game model (~2 days)
- `ViewModels/VersusGame.swift` — `@MainActor @Observable`. Owns a `SetGame` for rules + per-player state:
  - `hostScore`, `guestScore`
  - `hostTrios`, `guestTrios`
  - `hostMultiplier`, `guestMultiplier`
  - `hostFastestSet`, `guestFastestSet`
  - `hostLongestStreak`, `guestLongestStreak`
  - `lockoutEndsAt: Date?` (local lockout window)
  - `winner: PlayerID?`
  - `outcome: VersusOutcome` — `.win`, `.loss`, `.forfeit(by:)`, `.draw`
- Host runs `SetGame`; guest mirrors via messages.
- Deck seeded by host's RNG, sent to guest at match start. Both clients call a deterministic-deck builder keyed on the seed.
- Claim arbitration pipeline (host-side): receives `.claim` → validates against current board → applies if valid → broadcasts `.claimResult` with new state. The race-loser receives `success: false` and starts their 1.5s lockout locally.
- Idempotent claim handling: duplicate `.claim` messages from a flaky network do not double-count.

### Phase 5 — Versus game view (~1.5 days)
- `Views/Versus/VersusGameView.swift` — adapts `GameView` layout. Two score chips at top (you on left, opponent on right with display name). Forfeit button replaces Modes button; tapping prompts confirm.
- `Views/Versus/LockoutProgressBar.swift` — circular progress at screen bottom, visible only during lockout window. Ticks down via `TimelineView`.
- `Views/Versus/OpponentClaimEffect.swift` — handles the 1.5s pulsing-highlight + dissolve on the matched cards when the opponent successfully claims.
- Reuse `PointsToast` for the "+N" toast on the opponent's chip.
- Optimistic UI on the guest: third-tap clears selection immediately; on `.claimResult(success: false)`, snap back with a quick rollback animation.

### Phase 6 — End-of-game + rematch (~1 day)
- `Views/Versus/VersusGameOverSheet.swift` — winner banner, both scores side-by-side, per-player trio count + longest streak + fastest set. Rematch + Done buttons.
- `VersusGame` exposes a rematch state machine: `idle → localRequested → waitingForOpponent (15s) → bothAccepted → freshGame` or `→ opponentDeclined → showQuickMatchSuggestion`.

### Phase 7 — Stats (~1 day)
- `Stores/VersusStore.swift` — `@MainActor @Observable`, UserDefaults `versus.v1`. `VersusMatchRecord`:
  - `id: UUID`, `date: Date`
  - `opponentDisplayName: String?`
  - `yourScore: Int`, `opponentScore: Int`
  - `yourTrios: Int`, `opponentTrios: Int`
  - `outcome: VersusOutcome` — `.win`, `.loss`, `.forfeit`, `.draw`
  - `wasYourForfeit: Bool` (only meaningful when `outcome == .forfeit`)
- `StatsViewModel` adds `versusWins`, `versusLosses`, `versusForfeits`, `versusDraws`, `versusWinRate`, `recentVersusMatches`.
- `Views/StatsView.swift` adds a "Versus" section: tile row (W / L / F / D + win-rate badge), recent matches list, optional win-rate-over-time chart.
- Tests: `VersusStoreTests`, extend `StatsViewModelTests`.

### Phase 8 — Edge-case hardening (~1.5 days)
- Disconnect detection wired through to forfeit-record + opponent-wins flow.
- Host-disconnect → guest sees "Opponent disconnected — you win" and the match records as host's forfeit, guest's win.
- Backgrounded-during-claim arbitration: host queues messages until guest reconnects; if window expires, forfeit.
- Both-disconnect-simultaneously → draw, recorded independently on each side when each comes back online (in-memory only since no peer to confirm; acceptable).
- Tests for the message protocol via the stub `MatchTransport`.

**Total: ~10.5 days** of focused work, with Phase 2 (~2d) the biggest unknown.

---

## Risks

1. **Real-device testing burden.** GKMatch can't run in unit tests; you'll need two devices (or simulator + device) with sandbox GC accounts to validate end-to-end. Mitigation: protocol-fronted transport so the game model and arbitration logic are unit-testable with a stub.
2. **GameKit sandbox quirks.** First-time setup of friend-invite flow often surfaces `GKErrorDomain` errors that look catastrophic but are sandbox-only. Plan a half-day for the first round-trip working.
3. **Apple's roadmap.** Real-time matchmaking still works but isn't being heavily evangelized. Probability of formal deprecation in iOS 27/28 is non-zero. Acceptable risk for this app's lifetime.
4. **Latency-sensitive UX.** Even at 100ms RTT, the host's claim feels instant while the guest sees a perceptible delay. Mitigation: optimistic UI on the guest (selection clears immediately on third tap), then snap to host's authoritative result.
