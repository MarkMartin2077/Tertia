# Cross-Device Progress Sync — Plan

Sync user progress (streaks, time-attack scores, daily history, game-pace, versus
record) across devices signed into the same Apple ID. Tabled for now;
this doc is the source of truth when it comes back to the top of the queue.

---

## Decision: NSUbiquitousKeyValueStore (iCloud KVS)

Picked over CloudKit because:
- Drop-in API match for `UserDefaults` — minimal changes to the four stores
- Free, no backend, no schema design, no entitlement work beyond enabling iCloud
- Total persisted data is ~50KB even for power users (well under the 1MB quota)
- All records are already Codable, UUID-keyed, and append-only-ish — merge logic is straightforward

CloudKit is the right answer if/when scope changes:
- Friend-leaderboards independent of Game Center
- Sharing decks/replays with other users
- Per-record queries from a server / web companion
- Quota >1MB

For Tertia today, KVS wins.

---

## Stores in scope

All four:

| Store | Storage key | Schema | Merge identity |
|---|---|---|---|
| `HighScoreStore` | `highScores.v1` | `[HighScoreEntry]` | `id: UUID` |
| `DailyStore` | `daily.v1` | `Persistable` (composite) | `day: Date` (start-of-day) |
| `GameSessionStore` | `gameSessions.v1` | `[GameSessionRecord]` | `id: UUID` |
| `VersusStore` | `versus.v1` | `[VersusMatchRecord]` | `id: UUID` |

Three are append-only logs — trivial merge by union-of-UUIDs. `DailyStore` is
the only one with derived state (`currentStreak`, `bestStreak`, `lastPlayedDate`)
that has to be recomputed after merging `pastRecords`.

---

## Architecture

### Storage abstraction

Introduce a small protocol so stores don't talk to `UserDefaults` or KVS directly:

```swift
protocol KeyValueBackend: AnyObject, Sendable {
    func data(forKey: String) -> Data?
    func set(_: Data?, forKey: String)
    func synchronize() -> Bool
}
```

Two conformers:
- `UserDefaultsBackend` — wraps `UserDefaults.standard`
- `ICloudKeyValueBackend` — wraps `NSUbiquitousKeyValueStore.default`

Each store takes a `backend: KeyValueBackend` instead of a `UserDefaults`.
Tests pass a `MemoryBackend` that's just a dict.

### App-level sync coordinator

New `Services/CloudSyncService.swift` (`@MainActor @Observable`):
- Owns a reference to all four stores
- Subscribes to `NSUbiquitousKeyValueStore.didChangeExternallyNotification`
- On change: pull new blobs, run each store's `merge(remote:)` method, save merged blob back
- Exposes `lastSyncDate: Date?` and `syncState: .idle / .merging / .failed(reason)` for an optional Settings UI

### Per-store changes

Each store gets:

```swift
extension HighScoreStore {
    /// Replaces local entries with the union of local + remote, deduped by id.
    /// Higher scores per duration win when timestamps tie (defensive — UUIDs
    /// should make this a non-issue in practice).
    func merge(remote: [HighScoreEntry]) { ... }
}

extension DailyStore {
    /// Merges past records by day-key (start-of-day Date). For a given day,
    /// the higher score wins. After merging records, recompute streak fields.
    func merge(remote: Persistable) { ... }
}

extension GameSessionStore {
    func merge(remote: [GameSessionRecord]) { ... }   // union by id
}

extension VersusStore {
    func merge(remote: [VersusMatchRecord]) { ... }   // union by id
}
```

`DailyStore.merge` is the trickiest because of streak recomputation. The clean
approach: merge `pastRecords` first, then recompute `currentStreak`, `bestStreak`,
`lastPlayedDate` from scratch off the merged history. Already deterministic
because records are keyed by `dayStart`.

---

## Migration (one-time, on first KVS-enabled launch)

Stamp progress in a single boolean: `@AppStorage("hasMigratedToICloudKVS.v1")`.

```
on first launch with new version:
    if hasMigratedToICloudKVS.v1: skip
    
    call NSUbiquitousKeyValueStore.default.synchronize()
    wait for didChangeExternallyNotification (or 3s timeout)
    
    for each store:
        local  = read from UserDefaults
        remote = read from NSUbiquitousKeyValueStore
        
        if remote.isEmpty && local.isEmpty: skip
        if remote.isEmpty && !local.isEmpty: upload local → remote
        if !remote.isEmpty && local.isEmpty: store.replace(with: remote)
        if !remote.isEmpty && !local.isEmpty: store.merge(remote)
    
    set hasMigratedToICloudKVS.v1 = true
```

After migration, all reads come from KVS, all writes go to KVS. UserDefaults
copies are left untouched as a fallback (cheap insurance against an iCloud
data loss event).

---

## Sync lifecycle (post-migration)

### On every change-externally notification:
1. Fetch the keys that changed (`NSUbiquitousKeyValueStoreChangedKeysKey`)
2. For each changed key, call the relevant store's `merge(remote:)`
3. Each store's merge persists its own merged blob — KVS picks it up

### On app foreground:
- Call `synchronize()` to nudge iCloud to push pending writes / pull updates
- iOS does this automatically too; explicit call covers the "just opened the app" case

### On every local write (record / clear):
- Write to KVS as today (the backend abstraction handles this)
- iOS coalesces and syncs in the background; nothing further to do

---

## Conflict resolution rules

KVS is last-write-wins **per key**. Our merge layer turns that into
last-write-wins **per record** by:

- Append-only logs (HighScore / GameSession / Versus): union by UUID — both
  sides' records survive
- Daily records: take the higher score per `dayStart`. Both devices completing
  the same day shouldn't happen in practice (game blocks duplicate completions
  on a given day) but defensive
- DailyStore derived fields (streaks): always recomputed from merged
  `pastRecords` — never trusted from either side directly

The "two devices play offline simultaneously" case is the only interesting
conflict, and it resolves correctly: union the records, recompute streaks.

---

## Risks

1. **iCloud KVS quota (1MB total / 1MB per key)**. Tertia's data is ~50KB; far
   from the cap. Add a quota-warning log and a circuit breaker that stops
   writing if a write fails, just so we hear about it during beta.

2. **Sync timing on first launch.** KVS may not have synced from iCloud when
   the app starts. Migration logic waits for the notification or times out at
   3s, then proceeds with local. If sync arrives later, the merge handler
   catches it. No data loss either way.

3. **iCloud disabled at OS level.** KVS degrades to local-cache-only.
   Everything still works; sync just doesn't happen until they re-enable.
   Optional: surface a "Sync paused — enable iCloud Drive" hint in Settings.

4. **Schema migrations.** `highScores.v1` etc are versioned in the key name.
   Adding a `v2` requires a coordinated migration across both UserDefaults
   and KVS. Plan for this when you change a record shape.

5. **Game Center duplicate writes.** Existing `submitTimeAttackScore` flow
   writes to `HighScoreStore` then submits to GC. If iCloud merge brings in a
   higher score from another device, we should re-submit to GC so the
   leaderboard reflects it. Add a "post-merge submit" step in the sync
   coordinator that drains any new bests through `GameCenterService`.

---

## Effort estimate

- **Day 1 (½ day):** Backend abstraction + `ICloudKeyValueBackend`, swap stores
  to use it. Per-store `merge(_:)` methods + unit tests against a memory backend.
- **Day 2 (½ day):** `CloudSyncService`, change-externally notification
  handling, migration logic, post-merge GC re-submit.
- Buffer (½ day): real-device testing across two devices in iCloud sandbox.

Total: **~1.5 days**, low risk, all behavior is testable except the actual
iCloud round-trip (which needs two real devices on the same Apple ID).

---

## Test plan

Unit tests against a `MemoryBackend`:

- `HighScoreStoreTests.mergeUnionsByID` — local + remote produces deduped union
- `DailyStoreTests.mergeRecomputesStreaks` — merging past-records from another device updates `currentStreak` / `bestStreak` correctly
- `GameSessionStoreTests.mergeUnionsByID`
- `VersusStoreTests.mergeUnionsByID`
- `CloudSyncServiceTests.migrationUploadsLocalToEmptyRemote`
- `CloudSyncServiceTests.migrationDownloadsRemoteToEmptyLocal`
- `CloudSyncServiceTests.migrationMergesBothPopulated`
- `CloudSyncServiceTests.runsExactlyOnce` — `hasMigratedToICloudKVS.v1` flag is respected

End-to-end (manual, real device):
- Two devices, same Apple ID, both with prior progress. Update both. Verify
  each shows the union of both histories within a minute.
- One device offline; play a few games; bring online; verify other device
  picks up the new entries.

---

## Out of scope (deliberately)

- **Friend-leaderboards** — Game Center already covers this for Time Attack;
  KVS is for personal progress only.
- **Cross-account migration** — moving data when a user changes Apple IDs.
  No good story; punt.
- **Sync timestamps / "last synced X minutes ago" UI** — could ship later as a
  Settings affordance but doesn't change the core implementation.
