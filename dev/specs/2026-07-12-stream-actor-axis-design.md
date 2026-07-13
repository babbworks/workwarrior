# Design: Stream Actor Axis, the Board, and Reconciliation

**Date:** 2026-07-12
**Status:** design approved; cards TASK-STRM-001…005 derive from this.
**Schemas:** [`dev/schemas/stream-event-v1.md`](../schemas/stream-event-v1.md) ·
[`dev/schemas/actors-v1.md`](../schemas/actors-v1.md)
**Upstream analysis:** [`dev/docs/ledger-systems-accounting.md`](../docs/ledger-systems-accounting.md)

---

## 1. The problem

Workwarrior needs to record **dozens or hundreds of concurrent punch-ins** — humans and
agents and machines, all working at once — and to answer, at any moment, *who or what is
currently IN*.

TimeWarrior cannot do this. It tracks **one open interval**. That looked like a blocking
limitation.

**It is not a limitation. It is a category error on our side.**

A Bundy (1888) or Dey time recorder is **one clock and many cards**. The device is
shared; each worker carries their own card; the clock stamps whichever card is presented.
The recording device is singular and the identities are plural. We had inverted it — one
card (`timew`), and every actor trying to share it.

### The role assignment

| | Role | Why |
|---|---|---|
| **Stream** | **The clock.** | Append-only event log. An "open punch" is a `start` with no matching `stop` — there is no active slot to contend over, so a hundred concurrent punches cost the same as one. |
| **TimeWarrior** | **A card.** | One worker, one open punch, excellent personal ergonomics. Its single-interval constraint is *correct*: that is what a card is. Standalone `timew` use is a human's own card, with or without a task behind it. **Unchanged by this work.** |
| **`adapt_timew`** | **The card reader.** | Already transcribes card contents into the clock's log as `B start`/`B stop` events. |

### This is already true — verified

The existing `bundy` lens keeps `starts = {}`, a **dict keyed by object**, matching
`B start` to `B stop`. There is no single-slot restriction anywhere in it.

Driving 40 concurrent actors (12 human, 28 agent) and 80 overlapping punch events through
the **unmodified** lens: it handled all 40, accumulating 25h30m of agent time and 14h45m
of human time inside a ~2-hour wall-clock window. *More time logged than elapsed* is the
signature of genuine concurrency — a punch board with forty cards in it.

**The multi-punch clock already exists.** What's missing is identity and legibility.

---

## 2. The two gaps

**Gap 1 — there is no actor.** The data model is TAOO: Time, Action, Object, Occurrence.
The `object` field records *what was acted on*; nothing records *who acted*. In the
concurrency trial, identity had to be smuggled into object names (`agent:claude-07`) —
a convention, not a schema, and one that conflates the actor with the thing they acted on.
Real work needs the pair: operator 3 **on** lathe-01.

**Gap 2 — you cannot ask who is IN.** The `bundy` lens **discards** unclosed starts: a
`start` with no `stop` is dropped from the report. But the entire purpose of a punch board
is seeing which cards are currently in. The open set is already tracked in memory and then
thrown away.

---

## 3. The design

### 3.1 Actor lives in `ctx`, and the encoding does not move

The line format is **frozen at five fields**, and this is arithmetic, not taste. Every
consumer parses `line.split(None, 4)` — `maxsplit=4` makes `ctx` the remainder of the
line. A sixth positional field would be swallowed into `ctx` and corrupt the JSON parse; a
field inserted *before* `ctx` shifts every index, breaking all eight lenses **and silently
misreading every event already on disk.**

`ctx` is the extension point, and three independent facts prove it is safe:

1. **Every lens reads it defensively** — `json.loads` in `try/except`, then `.get(k, default)`.
   Unknown keys are ignored *by construction*.
2. **The adapters already extend it** — `src`, `prof`, `proj`, `tags` are all ctx keys.
3. **Dedup excludes it** — the identity key is `(ts, op, action, object)`. `ctx` is
   explicitly not part of event identity, so enriching it **cannot create duplicates on
   re-ingest.**

```
1752300142 B start lathe-01 {"actor":"human:op-03","proj":"line-a"}
```

**No migration. No log rewrite. v0 events resolve via a required fallback:**
`actor = ctx.actor or "profile:" + ctx.prof`.

### 3.2 Actors are registered; the rule is punch-vs-punched-onto

> **Actors punch. Objects get punched onto.**

A machine an operator works is an object; a machine running unattended is an actor. Both
are legitimate, in different events.

Three registry tiers — and the scoping is **forced**, not chosen: the stream log is
**one log per instance**, so profile-scoped IDs would make the shared log incoherent.
Identity is instance-scoped; *participation* is profile-scoped. Full contract in
`actors-v1.md`.

The profile tier carries a `weight` per actor — which is **the ledger's coefficient in a
different hat.** `ledger-systems-accounting.md` §6.5 verified that a *mode is a price
table*: one immutable record, valued under different coefficients, yields different
priority orders. An actor's attention weight is exactly such a coefficient.

### 3.3 The board — who is IN

A **new lens** (`lenses/board.sh`), which means a new file and **zero edits to any existing
lens**: `lens_list` globs the directory, so discovery is automatic.

```
ACTOR              OBJECT              PROJ      IN SINCE   DURATION
human:op-03        lathe-01            line-a    07:12      2h 14m
agent:claude-07    ledger-refactor     ledger    08:40      46m
agent:claude-11    struct-1b           dev       04:02      5h 32m  ⚠ stale
```

It is the Bundy lens's loop, *keeping* the open set instead of discarding it.

**And here is the payoff:** a stale punch is a **hung agent**. An agent that punched in and
never punched out is, definitionally, a loop that did not terminate. The loop-agent work
lists "detect no-progress" as a hard requirement — **the board is that detector, for
free.** The floor-manager view and the agent-supervision view are the same screen.

### 3.4 Reconciliation — corrections are entries, never erasures

The oldest problem in the punch-clock trade is the worker who forgets to clock out, and the
historical answer is the right one: **the foreman reconciles the board at shift end. He does
not rewrite the card.**

- **Individual:** `ww stream punch out --actor X --at <t> --reason <text>` — appends a
  `B stop` carrying `ctx.reconciled`.
- **Mass:** `ww stream reconcile --stale 12h --at shift-end --reason <text>` —
  **`--dry-run` mandatory first**, reason required, **one event per closure** so each is
  individually auditable.
- **Every closure is attributed to the actor who made it.** The log says *"morgen closed 47
  stale punches at shift end."* The reconciler is an actor; reconciliation is an act.
- **Nothing auto-closes silently, ever.** Flag always; close only by an act. Fabricating a
  punch-out destroys the one property that makes this record worth keeping.

### 3.5 The schema version is an event

The log has no header — a comment line would be garbage to the positional parser. The
version is stated as an ordinary `S` event, the mechanism `cmd_reset` already uses:

```
1752300000 S schema v1 {"schema":"v1","prev":"v0"}
```

Valid five-field event; every lens treats it as routine; greppable, dated, and part of the
log's own history. **In an append-only system, even the schema version is an append.**
Absence of the marker means v0 — so it must be written *before* any v1-only key is emitted.

---

## 4. Blast radius

**New files (zero risk to existing behaviour):**

| File | Purpose |
|---|---|
| `services/stream/lenses/board.sh` | The board. Auto-discovered; touches nothing. |
| `services/stream/lib/actor.sh` | Actor resolution + v0 fallback + ID normalisation. |
| `config/actors.yaml` | Instance roster (runtime data — `config/`, per the placement rule). |

**Modified (additive, surgical):**

| File | Change |
|---|---|
| `services/stream/stream.sh` | New `board`, `punch`, `reconcile` subcommands in the dispatch `case`; `--actor` flag on `cmd_emit`. **The `printf` encoding line is NOT touched.** |
| `services/stream/lib/adapters.sh` | One key added to the ctx dict the adapters already build. |
| `services/stream/lib/taoo.sh` | Extend `taoo_classify` with actor. |
| `server.py` + browser panel | New read-only endpoint fed by `board --format json`. Additive route. |

**Explicitly NOT touched:** the five-field encoding · all eight existing lenses ·
`stream.log` (no migration, no rewrite) · `codecs.sh` · TimeWarrior's role.

**Rollback:** `git revert` + delete the new files. Nothing on disk changes shape.

---

## 5. The interpretive layer

Both surfaces are currently absent, and they are what make the record legible.

**CLI:** `ww stream board [--actor X] [--proj P] [--stale <dur>] [--format json]`
**Browser:** a new panel reading `board --format json` through an added `server.py`
endpoint. Purely additive — no existing route changes.

This is also the natural first screen for the Warrior mobile app: *who is in, what is
stale, close it.*

---

## 6. Deliberately deferred

- **Shift concept** (punches spanning a shift boundary) — needs the board in use first.
- **Registry tier** (`~/.config/ww/registry/actors.yaml`) — IDs are forward-compatible
  (§`actors-v1.md` 5); add when a second instance exists.
- **Actor import adapters** (HRIS/CMMS → `actors.yaml`) — the `source` field reserves the
  shape; the importers come when there is a system to import from.
- **Punch → journal posting** — the `pacioli` lens already computes a running balance per
  object, and `ledger-systems-accounting.md` establishes punches-as-postings (an actor is
  an account, time is a commodity). **This is the join between the two threads**, and it
  waits until the actor axis is real.

---

## 7. Open

**The TimeWarrior ↔ ledger relationship (Q2 of the ledger synthesis) remains open.** This
design settles TimeWarrior's role *relative to Stream* (card vs. clock) but not its role
relative to the **journal**. Some redundancy between the stores is accepted as unavoidable;
which is the capture surface and which the analytical surface is still undecided, and
nothing that writes time into the ledger should be built until it is.
