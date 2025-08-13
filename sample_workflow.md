# 1) Basic single-action tick

**Goal:** one combatant issues one action; the tick resolves it, a log is produced, battlefield updates.

**Components:** `BattleManager`, `CombatLogic`, `CombatantLogic`, `BattleField` (as `LogsReceiver`)

**Steps**

1. Game creates `bm := NewBattleManager(ctx, combatants)` and `bf := NewBattleField(combatants, bm)`. Battlefield is registered as a logs receiver.
2. Player creates `act := Action{ID:..., Type:"attack", Source:attackerID, Target:defenderID, Params:{"damage": 10}}`.
3. Player calls an assumed API `bm.SubmitAction(act)` (actionQueue appended).
4. Ticker fires; `processTicker()` is invoked.
5. `processTicker()` drains the action queue and calls `logs, err := bm.combatLogic.ProcessActions(actions)`.
6. `bm.logs = append(bm.logs, logs...)`.
7. `bm.emitNewLogs(ctx, logs)` invoked; `bf.ReceiveLogs(ctx, logs)` runs.
8. `bf.updateCombatants(logs)` applies damage to the defender (or forwards to `CombatantLogic.ProcessCombatants`).
9. UI re-renders showing updated health and a combat log entry.

**Pseudocode**

```go
bm.SubmitAction(act)
...tick...
actions := bm.drainActionQueue()
logs, _ := bm.combatLogic.ProcessActions(actions)
bm.logs = append(bm.logs, logs...)
bm.emitNewLogs(bm.ctx, logs) // bf.ReceiveLogs -> bf.updateCombatants(logs)
```

**Notes:** Validate `Source`/`Target` at `SubmitAction` or inside `ProcessActions`. Return a client-visible error if invalid.

---

# 2) Multiple simultaneous actions with deterministic ordering

**Goal:** two combatants act in the same tick; actions sorted by priority/speed; deterministic tie-breakers.

**Components:** same as #1 plus a sort comparator in `CombatLogic.ProcessActions`.

**Steps**

1. Two actions submitted in same tick: `actA` (speed 10) and `actB` (speed 12).
2. `processTicker()` collects both and calls `ProcessActions([]Action{actA, actB})`.
3. `ProcessActions` validates both, sorts by `(Priority, Speed, Source.ID)` (explicit comparator), and generates logs in that order.
4. Logs appended and emitted to battlefield; `updateCombatants` applies logs sequentially in the returned order.
5. Results are deterministic across runs because comparator is stable and deterministic.

**Pseudocode (inside CombatLogic.ProcessActions)**

```go
sort.SliceStable(actions, func(i,j int) bool {
    if actions[i].Priority != actions[j].Priority { return ... }
    if actions[i].Speed != actions[j].Speed { return ... }
    return actions[i].Source.String() < actions[j].Source.String()
})
for _, a := range actions { logs = append(logs, generateLogFor(a)) }
return logs, nil
```

**Notes:** Include a `SequenceNumber` if you accept concurrent submissions from multiple clients to retain submission order as a tiebreaker.

---

# 3) Status effects & multi-tick effects (DOT/HoT)

**Goal:** apply a status (e.g., poison) which generates logs every tick while active.

**Components:** `BattleManager`, `CombatLogic`, `CombatantLogic`, `BattleField`; persistent status storage in `Combatant.Stats`.

**Steps**

1. An action `apply_poison` is processed on tick N; `ProcessActions` creates a `Log{Action:apply_poison}`.
2. `emitNewLogs` sends that log; `updateCombatants` or `CombatantLogic.ProcessCombatants` sets `c.Stats["poison"] = Poison{damage:2, remaining:3}` for the target.
3. On subsequent ticks, `processTicker()` invokes a small internal step that checks each combatant for active statuses and auto-enqueues generated actions/logs (or `CombatLogic` has a `ProcessStatusEffects` stage).
4. Generated DOT logs are produced (e.g., `Log{Action:damage_tick, Details:{"amount":2}}`) and emitted each tick until `remaining` reaches zero and then the status is removed.

**Pseudocode**

```go
// Tick N:
logs := combatLogic.ProcessActions(queue) // includes apply_poison log
bm.emitNewLogs(ctx, logs) // battlefield updates and sets poison in Stats

// Tick N+1..N+3:
statusLogs := combatLogic.ProcessStatusEffects() // generates damage_tick logs
bm.emitNewLogs(ctx, statusLogs)
```

**Notes:** Decide whether status ticks are produced by `CombatLogic` (recommended) or by `processTicker` polling `Combatant.Stats`. Ensure status decrements are deterministic.

---

# 4) Pause / resume and graceful shutdown

**Goal:** pause the ticker without losing state, resume later; support graceful shutdown.

**Components:** `BattleManager` internal `ctx/cancel`, ticker, `Pause()`.

**Steps**

1. UI calls `bm.Pause()`. Implementation stops the ticker and cancels the context used by the ticker goroutine; `bm.paused = true`.
2. While paused, `SubmitAction` still queues actions (or returns an error if you prefer to reject submissions while paused).
3. On resume (`bm.Resume()` — implement as needed), recreate `turnTicker` and a new `ctx` and start the ticker goroutine again; previously queued actions are processed on the next tick.
4. For shutdown, call `bm.Pause()` and then any `Close()` that flushes logs to persistent store if needed.

**Pseudocode**

```go
// Pause:
bm.Pause() // stops ticker, cancels ctx

// Later:
bm.Resume() // new ctx, new ticker, restart goroutine
```

**Notes:** If you cancel `ctx` used by receivers, be careful—receivers should use their own contexts or not rely on the manager's cancel for unrelated operations.

---

# 5) UI batching and receiver timeouts

**Goal:** battlefield receiver is slow; manager must avoid blocking the game loop.

**Components:** `BattleManager` (emitter), `BattleField` (slow receiver)

**Approach A (async dispatch):**

* `emitNewLogs` dispatches to receivers in goroutines and uses a bounded channel / worker pool, or uses `context.WithTimeout` for each `ReceiveLogs` call and continues on timeout.

**Steps**

1. Manager gets `logs`.
2. For each receiver `r`, create `ctx2, cancel := context.WithTimeout(bm.ctx, 50*time.Millisecond)` and call `r.ReceiveLogs(ctx2, logs)`. If it times out, log the receiver as slow and continue.
3. Continue game loop without waiting for slow UIs.

**Pseudocode**

```go
for _, r := range bm.logsReceivers {
    go func(r LogsReceiver) {
        ctx2, cancel := context.WithTimeout(bm.ctx, 50*time.Millisecond)
        defer cancel()
        _ = r.ReceiveLogs(ctx2, logs) // ignore errors/timeouts beyond logging
    }(r)
}
```

**Notes:** This avoids the game stalling due to UI. If UI needs guaranteed delivery, use a durable queue/persisted logs instead.

---

# 6) Replay / deterministic simulation

**Goal:** record all logs and replay them later to inspect or verify deterministic outcomes.

**Components:** `BattleManager.logs` (append-only), `BattleField` in replay mode (reads `bm.ListLogs()`).

**Steps**

1. During live play, all generated logs are appended to `bm.logs` (append-only).
2. To replay, create a fresh `combatants` snapshot (initial state), then iterate over `bm.ListLogs()` in order. For each log, call `bf.updateCombatants([]Log{log})` (or run the same `CombatantLogic` on the log) to reproduce state changes step-by-step.
3. Because `CombatLogic` uses deterministic sorting and no wall-clock timestamps for ordering, replay yields identical results.

**Pseudocode**

```go
logs := bm.ListLogs()
snap := deepcopy(initialCombatants)
bfReplay, _ := NewBattleField(snap, nil) // no live bm
for _, l := range logs {
    _ = bfReplay.updateCombatants([]Log{l})
    renderFrame(bfReplay)
}
```

**Notes:** Ensure actions’ ordering is deterministic (no reliance on map iteration or wall-clock). Store any comparator tiebreak values (sequence numbers) with actions/logs.

---

# 7) Error/validation flow

**Goal:** malformed or invalid actions should be rejected early and return useful errors.

**Components:** `SubmitAction` (or `ProcessActions`), `CombatLogic`.

**Steps**

1. Client submits `Action` referencing a non-existent `Target` ID.
2. `SubmitAction` runs a quick validation: check that `Source`/`Target` exist in `bm` or that `CombatLogic` will validate them at `ProcessActions`.
3. If invalid, return an explicit error to the client and do not enqueue the action.
4. If `ProcessActions` finds an invalid action (race condition where a combatant died between submit and tick), it should generate an error log (or a rejection log) appended to `bm.logs` and emitted so UIs can reflect the rejection.

**Pseudocode**

```go
func (bm *BattleManager) SubmitAction(a Action) error {
    if !bm.hasCombatant(a.Source) || !bm.hasCombatant(a.Target) {
        return fmt.Errorf("invalid action: unknown source/target")
    }
    bm.actionQueue = append(bm.actionQueue, a)
    return nil
}
```

**Notes:** Decide uniform policy: reject at submit time, or accept and mark invalid at resolution time (useful for network latency tolerance).

---

## Quick checklist of API helpers you may want to add (if not present)

* `SubmitAction(a Action) error`
* `Resume() error`
* `Close() error` (flush and stop)
* `HasCombatant(id EntityID) bool`
* `GetCombatantSnapshot() []*Combatant` (for UI or replay)
* `SetReceiverTimeout(d time.Duration)` (config for emit behavior)

---
