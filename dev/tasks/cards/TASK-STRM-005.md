## TASK-STRM-005: Reconciliation — closing missed punch-outs, individually and en masse

Goal:                 Close the punches that never closed — the operator who forgot, the agent
                      that died mid-loop — WITHOUT ever editing history. Corrections are
                      appended entries, attributed to the actor who made them. This is the
                      shift-end foreman, encoded.

Depends on:           TASK-STRM-004 (the board identifies what needs reconciling)

Contract:             dev/schemas/stream-event-v1.md §5
Design:               dev/specs/2026-07-12-stream-actor-axis-design.md §3.4

Acceptance criteria:  1. `ww stream punch out --actor X --object O --at <time> --reason <text>`
                         appends a `B stop` carrying:
                         `"reconciled":{"by":"<reconciler>","at":<now>,"reason":"<text>"}`
                         NOTE the two timestamps are DIFFERENT and both required: field 1 is
                         the punch-out time being ASSERTED; `reconciled.at` is when the human
                         made the correction.
                      2. `--reason` is MANDATORY on any reconciled close. No default. Exit 1
                         if absent.
                      3. `reconciled.by` is the actor performing the reconciliation, resolved
                         from the session (NOT the actor being closed). The log must be able to
                         say "morgen closed op-03's punch".
                      4. Mass: `ww stream reconcile --stale <dur> --at <time> --reason <text>`
                         - `--dry-run` is REQUIRED on first invocation: without it, the command
                           prints what it WOULD close and exits 0 without writing. A `--confirm`
                           flag (or interactive y/N) is required to actually write.
                         - Emits ONE event per closure. Never a single summary event: each
                           closure must be independently auditable.
                         - Prints a summary: N closed, by whom, reason.
                      5. NOTHING AUTO-CLOSES. There is no timeout, no daemon, no implicit
                         closure anywhere in the codebase. Grep-assert in the test: no code
                         path emits a `B stop` without an explicit user action.
                      6. An unmarked `B stop` (no `reconciled` key) continues to mean "the
                         actor really did punch out". Reconciled stops are distinguishable
                         from real ones FOREVER — this distinction must survive every lens.
                      7. The board (STRM-004) excludes reconciled-closed punches from the open
                         set, exactly as it would a real stop.
                      8. Reconciling an already-closed punch is a no-op with a warning, not a
                         double-stop.

Write scope:          services/stream/stream.sh              (punch out --reason, reconcile verb)
                      services/stream/lib/actor.sh           (reconciler resolution)
                      dev/tests/test-stream-reconcile.bats   (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-stream-reconcile.bats
                      bats dev/tests/test-stream-board.bats   (regression: reconciled punches leave the board)
                      bats dev/tests/            (full suite — at/above baseline)
                      Manual: mass reconcile dry-run -> confirm -> N events appended, one per closure.

Rollback:             git revert. Reconciled events already in the log remain valid and
                      correctly marked — they are ordinary `B stop` events with an extra ctx
                      key. Nothing to unwind.

Fragility:            MEDIUM. This card WRITES to the append-only log on behalf of a human,
                      about events the human did not personally perform. That is exactly the
                      power that must not be abused.

Risk notes:           (Orchestrator) THE HARD RULE: never fabricate a punch-out silently.
                      Flag always; close only by an explicit act, attributed to an actor, with
                      a reason. A system that quietly invents punch-outs to make its board look
                      tidy has destroyed the only property that makes the record worth keeping.
                      This is the same discipline the ledger imposes (corrections are entries,
                      never erasures) and it is not negotiable.
                      Criterion 5 (grep-assert no auto-close path) is the gate.
                      (Builder) --dry-run first is mandatory for mass operations. A bad
                      --stale value could otherwise close hundreds of live punches in one
                      command.

Status:               complete
Taskwarrior:          (assign live TW id on dispatch)
