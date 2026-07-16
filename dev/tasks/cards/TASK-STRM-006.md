## TASK-STRM-006: timew on-modify hook — make TimeWarrior a live card reader, not a store

Goal:                 Kill the two-truths problem. Today `adapt_timew` SCRAPES TimeWarrior in
                      batch, which is exactly what lets two stores drift apart. Replace it with
                      a live hook: `timew start` -> `B start` in Stream, `timew stop` -> `B stop`,
                      immediately. TimeWarrior stops being a store to be harvested and becomes
                      what the design calls it — the CARD READER, operating in real time.

                      Success test: **delete ~/.timewarrior and lose nothing**, because Stream
                      already holds it. Redundancy becomes a CACHE, not a FORK.

Depends on:           TASK-STRM-003 (events must carry ctx.actor before the hook can stamp one)

Design:               dev/specs/2026-07-12-stream-actor-axis-design.md §1 (clock vs card)
                      decisions.md 2026-07-13 (capture -> record -> interpret)

Acceptance criteria:  1. A timew on-modify hook (`~/.timewarrior/hooks/on-modify.*`) emitting
                         `B start` / `B stop` into stream.log via the stream service.
                      2. Installed/removed by EXTENDING the existing verb — `ww stream hooks
                         install|remove|status` already does exactly this for TASK hooks.
                         Do NOT invent a second mechanism.
                      3. The hook resolves the actor from the active profile owner and stamps
                         `ctx.actor` (via actor.sh — do NOT re-implement resolution).
                      4. `ctx.src` is `timew` so events are attributable to the capture device.
                      5. IDEMPOTENT WITH BATCH INGEST: running `ww stream ingest --source timew`
                         after the hook has already recorded the same intervals produces ZERO
                         new events. (_dedup_events keys on (ts,op,action,object) — the hook and
                         the adapter MUST produce identical tuples for the same interval. Prove
                         it: hook-record an interval, then ingest, then assert line count
                         unchanged.) This criterion is the whole card.
                      6. Hook failure MUST NOT break `timew`. A user's clock-in cannot fail
                         because Stream is unavailable — fail soft, log, exit 0.
                      7. `adapt_timew` REMAINS for backfill of pre-hook history. It is not
                         deleted; it stops being the primary path.

Write scope:          services/stream/hooks/            (new — timew on-modify hook script)
                      services/stream/stream.sh         (hooks install/remove/status extended to timew)
                      dev/tests/test-stream-timew-hook.bats   (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-stream-timew-hook.bats
                      bats dev/tests/            (full suite — at/above baseline)
                      Manual: `timew start x` -> `ww stream board` shows the punch LIVE.
                      Manual: hook-record, then `ww stream ingest --source timew` -> 0 new events (criterion 5).
                      Manual: break the hook deliberately -> `timew start` still succeeds (criterion 6).

Rollback:             `ww stream hooks remove`. The hook is an external file; removing it
                      restores batch-ingest behaviour exactly.

Fragility:            MEDIUM. The hook runs inside the user's `timew` invocation. Criterion 6 is
                      non-negotiable: a hook that can break clock-in is worse than no hook.

Risk notes:           (Orchestrator) Criterion 5 (hook/adapter tuple parity) is the hard gate. If
                      the hook and the adapter disagree on the (ts,op,action,object) tuple for the
                      same interval, dedup fails and every ingest DOUBLES the punch history.
                      (Builder) Timestamps: the hook fires at wall-clock; the adapter derives ts
                      from timew's interval record. These MUST agree to the second, or use the
                      interval's own start/end rather than `date +%s`.

Status:               complete
Taskwarrior:          (assign live TW id on dispatch)
