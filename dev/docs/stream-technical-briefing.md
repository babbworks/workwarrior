# Stream Subsystem — Technical Briefing for Agent Handoff

**Created:** 2026-07-15
**Scope:** STRM-001 through STRM-006 (Phase 1 complete)
**Purpose:** Everything an agent needs to work on this subsystem without re-reading all the code.

---

## What was built

The Stream service is a unified, append-only event log that captures everything
happening in a workwarrior instance. It replaces the previous model where each tool
(TaskWarrior, TimeWarrior, jrnl, hledger) was an isolated silo harvested in batch.

**The metaphor:** A Bundy time clock from 1888. One clock, many cards. Stream is the
clock; TimeWarrior is a card reader.

---

## Architecture

```
services/stream/
  stream.sh              Main dispatcher (~800 lines, executed)
  lib/
    actor.sh             Actor ID validation + v0 fallback resolution
    adapters.sh          Batch ingestion: timew/task/jrnl/ledger → stream events
    replay.sh            Feeds events to lenses (excludes S and H events)
    lenses.sh            Lens discovery (globs lenses/*.sh)
    codecs.sh            Output formatters (JSON, text)
    taoo.sh              Event classification (Time, Action, Object, Occurrence)
  lenses/
    board.sh             Who's currently IN (open B start/stop set)
    bundy.sh             Interval accumulation + ASCII timeline
    burroughs.sh         Raw chronological log view
    frick.sh             State transition timeline
    felt.sh              Activity density heat map
    dey.sh               Behavioral signal (intensity/stability)
    hollerith.sh         Matrix grid (time × object)
    pacioli.sh           Running balance per object
    cooper.sh            Geometric polar projection of Dey signal
  hooks/
    timew-stream-hook.sh Sourced by timew() shell function for live emission

lib/
  actor-registry.sh      Single owner of config/actors.yaml

config/
  actors.yaml            Instance actor roster (ships empty, seeded on first use)

dev/schemas/
  stream-event-v1.md     The normative contract for the event format
  actors-v1.md           The normative contract for the actor registry
```

---

## The event format (FROZEN)

```
<unix_ts> <OP> <action> <object> <ctx_json>
```

Five space-separated fields. `ctx_json` is field 5 (the remainder of the line after
`split(None, 4)`). **Adding a 6th positional field is impossible** — it would corrupt
every consumer's JSON parse.

| OP | Domain |
|---|---|
| T | Task lifecycle |
| B | Punch (interval start/stop) |
| F | State transition |
| D | Behavioral signal |
| H | Legacy header (excluded from lenses) |
| S | System (schema, reset — excluded from lenses) |
| A | Annotation |

---

## Key invariants (non-negotiable)

1. **5-field encoding is frozen.** New dimensions go in ctx, never as positional fields.
2. **Dedup keys on (ts, op, action, object).** ctx is NOT in the identity key. Enriching ctx cannot create duplicates.
3. **The log is append-only.** Corrections are new entries (`reconciled` key), never edits.
4. **Lenses are read-only.** They never write to the log.
5. **Unknown ctx keys are ignored.** Readers use `.get(key, default)`.
6. **Unknown op codes are skipped.** New ops are additive.
7. **S and H events are excluded from lenses** at `replay_load()`.
8. **The timew hook fails soft.** Hook failure never breaks timew.

---

## What each STRM card delivered

| Card | What | Files |
|---|---|---|
| STRM-001 | Schema v1 event + actor_resolve with v0 fallback | actor.sh, stream.sh, replay.sh, stream-event-v1.md |
| STRM-002 | Actor registry (config/actors.yaml) + single owning module | lib/actor-registry.sh, config/actors.yaml, actors-v1.md |
| STRM-003 | Events carry ctx.actor; punch verbs; --actor flag on emit | stream.sh (cmd_punch, cmd_emit), adapters.sh |
| STRM-004 | The board lens — who's currently IN | lenses/board.sh, stream.sh (cmd_board) |
| STRM-005 | Reconciliation — close missed punches with attribution | stream.sh (cmd_reconcile), reconciled key in ctx |
| STRM-006 | timew → stream live bridge (shell wrapper hook) | hooks/timew-stream-hook.sh, lib/shell-integration.sh |

---

## How to invoke key operations

```bash
# Punch in/out
ww stream punch in  --actor human:morgen --object lathe-01 --proj line-a
ww stream punch out --actor human:morgen --object lathe-01

# Reconcile missed punches
ww stream board --stale 14400          # find stale (>4h)
ww stream reconcile --stale 14400 --reason "shift end" --confirm

# View the board
ww stream board                        # text table
ww stream board --format json          # JSON array

# Emit arbitrary events
ww stream emit T add task-uuid '{"proj":"alpha"}' --actor agent:claude.k7x2

# Ingest from tools (batch backfill)
ww stream ingest --source all

# View through lenses
ww stream view --lens bundy
ww stream view --lens board
ww stream view --lens dey --format json
```

---

## Tests

All stream tests live in `dev/tests/test-stream-*.bats`:

```bash
bats dev/tests/test-stream-actor.bats          # 14 tests (actor validation, resolution)
bats dev/tests/test-stream-schema.bats         # 10 tests (schema marker, lens exclusion)
bats dev/tests/test-stream-punch.bats          # 18 tests (punch verbs, --actor flag)
bats dev/tests/test-stream-ingest-dedup.bats   # 8 tests (dedup parity proof)
bats dev/tests/test-stream-board.bats          # 20 tests (board lens, scale, filters)
bats dev/tests/test-stream-reconcile.bats      # 22 tests (reconcile, mass close)
bats dev/tests/test-stream-timew-hook.bats     # 20 tests (hook, dedup parity, fail-soft)
bats dev/tests/test-actor-registry.bats        # 23 tests (registry CRUD, profile overlay)
```

Total: 135 stream-related tests, all passing.

---

## Known gaps (from post-analysis)

1. Hook only fires via shell function wrapper — raw `timew` calls bypass it
2. `ww stream hooks status` doesn't report timew hook state
3. Profile membership warning on punch not implemented (only instance-level check)
4. Popup board screen doesn't use `ww stream board --format json` yet
5. STRM-002 reopened for actor ID format (solo/team/enterprise tiers + nano suffix)
6. stream.sh growing large — may benefit from module splitting later

---

## What comes next (Phase 2+)

- Phase 2: The bridge (STRM-006 done, but the TaskWarrior on-modify hook could also emit)
- Phase 3: The journal — `ww ledger sync-stream` derives a hledger journal from stream
- Phase 4: The attention queue — value every account in a synthetic commodity

Key cards: TASK-LED-014 (actor accounts), TASK-LED-015 (derived journal),
TASK-LED-016 (accrual rule), TASK-LED-017 (attention queue).

---

## For agents working on this subsystem

1. Read `dev/schemas/stream-event-v1.md` — it's the law
2. Read `dev/schemas/actors-v1.md` — the registry contract
3. Run `bats dev/tests/test-stream-*.bats` before and after any change
4. Never modify the 5-field printf line
5. Never put data in a positional field that should be in ctx
6. Never write a B stop without explicit user action
7. Always use `actor_validate` before writing actor IDs
8. Always use `_dedup_events` for any ingest path
