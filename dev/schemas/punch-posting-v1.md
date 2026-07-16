# Punch Posting — v1

**Contract for:** The mapping from a stream `B start/stop` interval to an hledger journal transaction.
**Status:** normative, v1.
**Producers:** `ww ledger sync-stream` (TASK-LED-015, not yet built).
**Consumers:** hledger queries, the attention queue (TASK-LED-017), reports.
**Related:** [`stream-event-v1.md`](./stream-event-v1.md) §4, [`actors-v1.md`](./actors-v1.md), [`units-v1.md`](./units-v1.md)

---

## 1. What is conserved

**An actor's hours.** A person has finite hours in a shift. An agent has a finite budget.
A machine has finite uptime. When they punch in, time flows FROM their capacity INTO
the work. This is the conservation law, and it is real.

---

## 2. The posting shape

A completed punch interval (a `B start` followed by a `B stop` on the same object)
produces exactly one journal transaction:

```hledger
<date> * punch  <actor_display> -> <object>
    ; stream:obj=<object_hash>
    ; stream:actor=<actor_id>
    ; stream:start=<start_ts>
    ; stream:end=<end_ts>
    time:<account_path>          <duration> h
    actors:<actor_id>           -<duration> h
```

### Example

Stream events:
```
1752300142 B start lathe-01 {"actor":"human:marta.k7x2","proj":"line-a","tags":["maintenance"]}
1752308342 B stop  lathe-01 {"actor":"human:marta.k7x2","proj":"line-a"}
```

Produces:
```hledger
2026-07-12 * punch  Marta Ruiz -> lathe-01
    ; stream:obj=a3f8c92b1e4d
    ; stream:actor=human:marta.k7x2
    ; stream:start=1752300142
    ; stream:end=1752308342
    time:project:line-a          2.28 h
    actors:human:marta.k7x2    -2.28 h
```

---

## 3. Field mapping (deterministic)

Every field in the posting is a pure function of the stream event fields. The same event
always yields the same transaction.

| Posting field | Source | Derivation |
|---|---|---|
| Date | `start_ts` | `date -d @<start_ts> +%Y-%m-%d` |
| Status | — | Always `*` (cleared — derived, not human-entered) |
| Description | `ctx.actor` display + `object` | `<actor_display> -> <object>` |
| Comment: `stream:obj` | object hash (field 4) | As-is from the event |
| Comment: `stream:actor` | `ctx.actor` | As-is |
| Comment: `stream:start` | start event `ts` (field 1) | Unix timestamp |
| Comment: `stream:end` | stop event `ts` (field 1) | Unix timestamp |
| Target account | `ctx.proj` or `object` | `time:project:<proj>` if proj exists, else `time:unclassified:<object>` |
| Target amount | end_ts - start_ts | Converted to hours, precision 2 (from units.yaml `h` entry) |
| Target commodity | — | Always `h` (the time unit) |
| Source account | `ctx.actor` | `actors:<actor_id>` (verbatim, including kind prefix) |
| Source amount | — | Negative of target amount (`-<duration> h`) |

### Account name derivation rules

**Target (where time goes TO):**
```
if ctx.proj exists and is non-empty:
    account = "time:project:" + ctx.proj
else:
    account = "time:unclassified:" + object
```

**Source (where time comes FROM):**
```
account = "actors:" + ctx.actor
```

If `ctx.actor` resolves via the v0 fallback (`profile:<prof>`), the source account is
`actors:profile:<prof>`. This is correct — we know the context but not the individual.

---

## 4. Actor accounts — semantics

Actor accounts live under `actors:` at the top level:
```
actors:human:<id>
actors:agent:<id>
actors:machine:<id>
actors:profile:<name>       (v0 fallback attribution)
```

**They run NEGATIVE.** Structurally like income accounts in traditional accounting:
- Income accounts receive credits (run negative in hledger's sign convention)
- Actor accounts "spend" capacity — each punch debits their capacity into the work

**Why negative:** `hledger balance actors:` shows how much capacity has been consumed.
A balance of `-47.5 h` means 47.5 hours have been invested by that actor. This is
analogous to an income account showing `-$10,000` meaning $10,000 received.

**The conservation law:** For every transaction:
```
time:project:X    +N h     (work gained)
actors:Y          -N h     (capacity spent)
                   ─────
                    0 h     (sigma = 0, always)
```

Double-entry enforces this mechanically. hledger rejects an unbalanced transaction.

---

## 5. Reconciled punches

A punch closed via reconciliation (STRM-005) carries `ctx.reconciled`. The journal
transaction MUST be distinguishable from a real one:

```hledger
2026-07-12 * punch  Marta Ruiz -> lathe-01  ; reconciled
    ; stream:obj=a3f8c92b1e4d
    ; stream:actor=human:marta.k7x2
    ; stream:start=1752300142
    ; stream:end=1752329600
    ; reconciled:by=human:morgen
    ; reconciled:at=1752333200
    ; reconciled:reason=shift boundary
    time:project:line-a          8.18 h
    actors:human:marta.k7x2    -8.18 h
```

The ` ; reconciled` tag on the description line marks it. The full reconciliation
metadata is preserved in comments. A query `tag:reconciled` returns only these.

**The account is the SAME.** A reconciled punch does not go to a different account — the
time was still spent. Only the provenance differs: a human asserted the end time, rather
than the actor punching out themselves.

---

## 6. Open punches (no stop yet)

An open punch (B start with no B stop) does NOT produce a journal transaction. The
journal records only **completed intervals**. An open punch is visible on the board
(STRM-004) but has no financial representation until it closes.

---

## 7. Duration computation

```python
duration_seconds = end_ts - start_ts
duration_hours = round(duration_seconds / 3600, 2)
```

Precision is 2 decimal places (from `config/units.yaml`, `h` entry, `precision: 2`).

---

## 8. Regeneration, not accumulation

`ww ledger sync-stream` (LED-015) will REGENERATE the derived journal from scratch on
every run. It does NOT append incrementally. This means:

- The derived journal is a **pure function** of the stream log
- Running sync-stream twice produces identical output
- Editing the derived journal is futile — it will be overwritten
- Manual entries go in `manual.journal`, never the derived file

This is the same principle as the stream itself: one source of truth (the log), with
everything else as a derived view.

---

## 9. Changelog

**v1 — 2026-07-15**
- Defined the punch posting shape: time → project, capacity from actor
- Actor accounts established: `actors:<kind>:<id>`, run negative
- Conservation law: sigma = 0 per transaction
- Deterministic account-name derivation documented
- Reconciled punches: same account, tagged + commented
- Open punches excluded from journal
- Regeneration model (not accumulation)
