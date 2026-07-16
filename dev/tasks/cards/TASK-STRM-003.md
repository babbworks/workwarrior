## TASK-STRM-003: Emit the actor axis — punch verbs + adapter enrichment

Goal:                 Start WRITING `ctx.actor`. Add the punch surface (`ww stream punch
                      in|out`), an `--actor` flag on emit, and one ctx key in each adapter.
                      This is the card that turns identity from a convention into a schema.

Depends on:           TASK-STRM-002 (registry — actors must resolve before they are written)

Contract:             dev/schemas/stream-event-v1.md §3, §4
Design:               dev/specs/2026-07-12-stream-actor-axis-design.md §3.1

Acceptance criteria:  1. `ww stream punch in  --actor <id> --object <obj> [--proj P] [--tags..]`
                         appends `<ts> B start <obj> {"actor":"<id>",...}`.
                      2. `ww stream punch out --actor <id> --object <obj>`
                         appends `<ts> B stop  <obj> {"actor":"<id>",...}`.
                      3. BOTH validate the actor against the registry (STRM-002) and exit 1
                         with a clear message on an unknown or malformed ID. An actor absent
                         from the ACTIVE PROFILE's members is a warning, not an error (it is
                         a legitimate cross-profile actor).
                      4. `cmd_emit` gains an optional `--actor <id>` flag that injects the key
                         into ctx. Positional invocation `ww stream emit <op> <action> <obj>
                         [ctx]` continues to work UNCHANGED (back-compat).
                      5. `adapt_timew` and `adapt_tasks` add ONE key (`"actor"`) to the ctx
                         dict they already build, resolved from the active profile owner.
                      6. **Re-ingest produces ZERO duplicates** after the adapters start
                         emitting the new key. Prove it: ingest, re-ingest, assert line count
                         unchanged. (`_dedup_events` keys on (ts,op,action,object); ctx is not
                         in the key — schema §1. This criterion PROVES that claim rather than
                         trusting it.)
                      7. The 5-field `printf` encoding line is NOT modified. Field count
                         stays 5. Assert with a test that every emitted line has exactly 4
                         whitespace-delimited fields before the JSON.
                      8. All 8 existing lenses produce byte-identical output on a log
                         containing actor-bearing ctx. (They ignore unknown ctx keys by
                         construction — prove per-lens.)

Write scope:          services/stream/stream.sh          (punch verbs, --actor on emit)
                      services/stream/lib/adapters.sh    (one ctx key in adapt_timew/adapt_tasks)
                      services/stream/lib/taoo.sh        (taoo_classify gains actor)
                      dev/tests/test-stream-punch.bats   (new)
                      dev/tests/test-stream-ingest-dedup.bats (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-stream-punch.bats
                      bats dev/tests/test-stream-ingest-dedup.bats
                      bats dev/tests/test-service-discovery.bats
                      bats dev/tests/            (full suite — at/above baseline)
                      Manual: ingest -> re-ingest -> line count unchanged (criterion 6).
                      Manual: 8-lens byte-identical diff (criterion 8).

Rollback:             git revert. Events already written with ctx.actor remain VALID and
                      readable — the key is simply ignored again. No log surgery. This is the
                      whole point of putting actor in ctx.

Fragility:            MEDIUM. Modifies stream.sh (shared dispatcher) and adapters (ingest
                      path). Criteria 6 and 7 are the hard gates: a dedup regression would
                      duplicate history on every re-ingest, and a field-count regression would
                      corrupt every downstream parse.

Risk notes:           (Orchestrator) Criterion 6 is non-negotiable and must be proven, not
                      argued. If ctx WERE in the dedup key, enriching adapter output would
                      silently double the log on the next `ww stream ingest`.
                      (Builder) Do NOT re-implement the v0 fallback — call actor.sh (STRM-001).
                      Punch verbs write; they must not auto-close anything (see STRM-005).

Status:               complete
Taskwarrior:          (assign live TW id on dispatch)
