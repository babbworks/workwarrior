# Stream Event Format — v1

**Contract for:** `$WW_BASE/stream/stream.log`
**Status:** normative. v1 supersedes v0; **v1 is a strict superset of v0** — every v0 event
is a valid v1 event, and no migration of existing logs is required or permitted.
**Producers:** `ww stream emit`, `services/stream/lib/adapters.sh`, task hooks.
**Consumers:** every lens in `services/stream/lenses/`, `lib/codecs.sh`.

---

## 1. The line format — FROZEN at five fields

```
<unix_ts> <OP> <action> <object> <ctx_json>
```

```
1752300142 B start lathe-01 {"actor":"human:op-03","proj":"line-a"}
```

Fields are whitespace-separated. **`ctx_json` is the remainder of the line** and may
itself contain spaces.

### The five fields

| # | Field | Type | Notes |
|---|---|---|---|
| 1 | `unix_ts` | integer, seconds | Event time. Log is **sorted by this**, appended in order. |
| 2 | `OP` | single char | Op code — see §2. |
| 3 | `action` | token, no spaces | Verb: `start`, `stop`, `add`, `done`, `delete`, `modify`, `write`, `post`, `track`, `fail`, `reset`, `schema`. |
| 4 | `object` | token, no spaces | **What was acted upon.** Task UUID, ledger account, machine ID, file. |
| 5 | `ctx_json` | JSON object | Metadata. **The only extension point.** See §3. |

### Why five fields is frozen — this is arithmetic, not preference

Every consumer parses with:

```python
parts = line.split(None, 4)     # maxsplit=4
```

`maxsplit=4` means **`parts[4]` is the entire rest of the line**. Two consequences, both
hard:

1. **A sixth positional field is impossible.** It would be swallowed into `ctx_json` and
   corrupt the JSON parse.
2. **Inserting a positional field before `ctx` is a breaking change to every event ever
   written.** Indices shift; `parts[3]` stops being the object. Eight lenses misread, and
   every historical line is silently reinterpreted.

**Therefore: the positional encoding MUST NOT change. New dimensions go in `ctx`.**

### Event identity — and why `ctx` is free to grow

Deduplication on ingest (`_dedup_events`, `lib/adapters.sh`) keys on:

```awk
seen[$1" "$2" "$3" "$4]        # ts, op, action, object — ctx is NOT in the key
```

**The identity of an event is the `(ts, op, action, object)` tuple.** `ctx` is explicitly
*not* part of what makes an event unique. This is load-bearing: it means enriching `ctx`
(e.g. adding `actor` to the adapters' output) **cannot produce duplicate events on
re-ingest.** The extension point is safe by construction.

---

## 2. Op codes

| OP | Domain | Meaning |
|---|---|---|
| `T` | Task | TaskWarrior lifecycle |
| `B` | Bundy | **Punch — interval start/stop.** The clock. |
| `F` | Frick | State transition |
| `D` | Dey | Behavioural signal |
| `H` | Hollerith | Positional/encoded record |
| `S` | System | Stream's own lifecycle (`reset`, `schema`) |
| `A` | Annotation | Free-text attachment |

Op codes are named for the lineage the service is built on (Bundy's 1888 time recorder,
the Dey Time Register, Hollerith's punched cards). Lenses are named the same way and
project the log through the corresponding view.

**Unknown op codes MUST be skipped, not rejected.** A lens filtering for `B` ignores the
rest; that is the intended behaviour and is what makes new op codes additive.

---

## 3. `ctx` — the extension point

A JSON object. **Readers MUST tolerate unknown keys** (all current lenses do: `json.loads`
in `try/except`, then `.get(key, default)`). **Adding a key is a non-breaking change and
does NOT require a version increment.**

### Reserved keys

| Key | Since | Type | Meaning |
|---|---|---|---|
| `src` | v0 | string | Origin adapter: `tasks`, `timew`, `jrnl`, `ledger`, `stream`. |
| `prof` | v0 | string | Profile active when the event was recorded. |
| `proj` | v0 | string | Project. |
| `tags` | v0 | string[] | Tags. |
| `name` | v0 | string | Human-readable label for `object`. |
| **`actor`** | **v1** | string | **Who or what performed the action.** See §4. |
| **`reconciled`** | **v1** | object | Present only on correcting events. See §5. |
| `schema` | v1 | string | Only on `S schema` events. See §6. |

Keys not listed here are permitted but carry no guarantees.

---

## 4. `actor` — the identity axis (new in v1)

**v0 had no actor.** The `object` field records *what was acted upon*; nothing recorded
*who acted*. This made the log unable to answer "what did operator 3 do today" or "which
agent is currently running", and forced identity to be smuggled into `object` names by
convention — conflating the actor with the thing they acted on.

**v1 adds `ctx.actor`.** Identity and object become a **pair**: operator 3 *on* lathe-01;
agent claude-07 *on* the ledger refactor.

```
1752300142 B start lathe-01        {"actor":"human:op-03","proj":"line-a"}
1752300890 B start ledger-refactor {"actor":"agent:claude-07","proj":"ledger"}
```

### Actor ID format

```
<kind>:<local-id>
```

`kind` is one of `human`, `agent`, `machine`. IDs resolve against the actor registry —
see [`actors-v1.md`](./actors-v1.md).

### Actor vs. object — the rule

> **Actors punch. Objects get punched onto.**

A machine an operator is working is an **object** (`actor: human:op-03`, `object:
lathe-01`). A machine running unattended is an **actor** (`actor: machine:lathe-01`,
`object: workorder-8891`). The same machine may appear in either slot in different
events. This is intentional and correct.

### Resolving `actor` on v0 events — REQUIRED

v0 events have no `actor` key and **MUST NOT be rewritten**. Readers resolve it:

```
actor = ctx.actor  or  "profile:" + (ctx.prof or "default")
```

Every consumer that reads `actor` MUST apply this fallback. Historical events therefore
attribute to the profile that recorded them, which is the honest answer: we know the
context, not the individual.

---

## 5. `reconciled` — corrections are entries, never erasures (new in v1)

A punch-out that never happened (an operator who forgot, an agent that died mid-loop) is
closed by **appending a correcting event**. The log is append-only; history is never
edited.

```
1752345600 B stop lathe-01 {"actor":"human:op-03","proj":"line-a",
  "reconciled":{"by":"human:morgen","at":1752349000,"reason":"shift boundary"}}
```

| `reconciled` field | Type | Meaning |
|---|---|---|
| `by` | actor ID | **Who performed the reconciliation.** Required. |
| `at` | unix_ts | When the correction was made (distinct from field 1, the punch-out time being asserted). |
| `reason` | string | Required. Free text. |

**Rules:**

- A reconciled `B stop` MUST carry `reconciled`. An unmarked stop asserts that the actor
  really did punch out; a marked one asserts that a human decided they should have.
- **Nothing may auto-close a punch silently.** Closure is an *act*, attributable to an
  actor. Fabricating a punch-out destroys the only thing that makes this record worth
  keeping.
- Bulk reconciliation emits **one event per closure**, each individually auditable.

---

## 6. Schema version — the version is an event

**The log carries no header.** A comment line would be garbage to the positional parser.
Instead, the version is stated as an ordinary `S` (System) event — the same mechanism
`cmd_reset` already uses:

```
1752300000 S schema v1 {"schema":"v1","prev":"v0"}
```

It is a valid five-field event, it is greppable and dated, and it lives **in the log's own
history**. In an append-only system, even the schema version is an append.

**A log with no `S schema` event is v0.** Absence is the v0 marker; this is why the
marker must be written before any v1-only key is emitted.

### System events are excluded from lenses — at ONE point

**Correction (2026-07-13, TASK-STRM-001).** An earlier draft of this section claimed "every
existing lens handles it as a routine system event." **That was false, and the build proved it:**
six of the eight lenses differed once the marker was present.

Only `bundy` (op `B`) and `frick` (op `F`) filter by op code. `burroughs`, `hollerith`,
`pacioli`, `felt`, `dey` and `cooper` render or **count every event** — so a synthetic `S` event
would have appeared as **activity that never happened**, skewing the density signals that `felt`,
`dey` and `cooper` exist to measure.

The rule already existed and simply had to be extended: `replay_load()` (`lib/replay.sh`) already
excluded `H` — the legacy positional header — because **the log's own metadata is not an event the
lenses analyse.** `S` (System: `schema`, `reset`) is the same category, and is now excluded at the
same single point.

> **System events stay IN the log. They are simply not *work*.**
> The log is the record; a lens is a projection of it.

Any consumer that reads the raw log directly (rather than through `replay_load`) will see `S`
events, and should skip op codes it does not understand — as §7 already requires.

---

## 7. Compatibility rules

**For readers:**
- MUST tolerate unknown `ctx` keys.
- MUST skip unknown op codes rather than erroring.
- MUST apply the `actor` fallback (§4) — never assume the key is present.
- MUST NOT assume `ctx` is valid JSON. Malformed ctx is skipped, not fatal (all current
  lenses already do this).

**For writers:**
- MUST NOT add, remove, or reorder positional fields. Five, forever, in v1.
- MUST NOT emit spaces in fields 1–4.
- MUST NOT rewrite or delete existing lines. Append only.
- SHOULD populate `actor` on every event they originate.

---

## 8. Changelog

**v1 — 2026-07-12**
- Added `ctx.actor` (§4) — the identity axis. Additive; v0 events resolve via fallback.
- Added `ctx.reconciled` (§5) — correcting events for missed punch-outs.
- Added the `S schema` version event (§6).
- Documented the positional encoding as **frozen** (§1) and `ctx` as the sole extension
  point, with the dedup-key argument for why that is safe.
- **No change to the encoding. No migration. No rewrite of any existing log.**

**v0 — (undocumented, retroactively specified above)**
- Five-field positional encoding; `ctx` keys `src`/`prof`/`proj`/`tags`/`name`.
- Version was never written into the log — hence "absence means v0".
