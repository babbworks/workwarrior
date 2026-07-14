## TASK-STRM-001: Stream schema v1 marker + actor resolution lib

Goal:                 Land the v1 foundation WITHOUT changing any producer or consumer
                      behaviour: write the `S schema v1` version event, and add the actor
                      resolution library (with the v0 fallback) that every later card
                      depends on. Nothing reads `ctx.actor` yet — this card only makes it
                      possible to.

Depends on:           — (foundation; STRM-002..005 all depend on this)

Contract:             dev/schemas/stream-event-v1.md §4 (actor + fallback), §6 (version event)
Design:               dev/specs/2026-07-12-stream-actor-axis-design.md §3.1, §3.5

Acceptance criteria:  1. NEW `services/stream/lib/actor.sh` (sourced lib — NO `set -euo
                         pipefail`, return codes only, per dev/CLAUDE.md scripting standards):
                         - `actor_resolve <ctx_json>` -> actor ID, applying the REQUIRED v0
                           fallback: `ctx.actor` or `"profile:" + (ctx.prof or "default")`.
                           MUST never return empty for well-formed ctx.
                         - `actor_validate <id>` -> 0/1. Enforces `<kind>:<local-id>`,
                           kind ∈ human|agent|machine, local-id `[a-z0-9][a-z0-9_-]*`.
                         - `actor_kind <id>` -> human|agent|machine.
                      2. `ww stream` writes `<ts> S schema v1 {"schema":"v1","prev":"v0"}`
                         to stream.log exactly once, on first v1-aware invocation, IFF no
                         `S schema` event is already present. Idempotent: never double-writes.
                      3. The marker is written BEFORE any v1-only ctx key can be emitted
                         (absence of the marker means v0 — schema §6).
                      4. `ww stream status` reports the schema version read FROM THE LOG
                         (grep the last `S schema` event), not from the STREAM_SCHEMA_VERSION
                         constant. Absence -> "v0".
                      5. All 8 existing lenses produce BYTE-IDENTICAL output on a log that
                         now contains the `S schema` event. (It is an `S` op; every lens
                         already skips or passes through system events.) Prove per-lens.
                      6. The 5-field `printf` encoding line in cmd_emit is NOT modified.

Write scope:          services/stream/lib/actor.sh          (new)
                      services/stream/stream.sh             (schema-marker write + status read)
                      dev/tests/test-stream-actor.bats      (new)
                      dev/tests/test-stream-schema.bats     (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-stream-actor.bats
                      bats dev/tests/test-stream-schema.bats
                      bats dev/tests/            (full suite — must be at/above baseline)
                      Manual: run all 8 lenses over a fixture log before/after the marker,
                              diff outputs — MUST be byte-identical (criterion 5).

Rollback:             git revert. The only on-disk artifact is one appended `S schema` event,
                      which is inert to every existing lens. No migration to undo.

Fragility:            LOW-MEDIUM. Touches stream.sh (shared dispatcher) but adds only; the
                      encoding line is untouched. Criterion 5 is the real gate — an existing
                      lens choking on the S event would be a silent regression.

Risk notes:           (Orchestrator) The v0 fallback is REQUIRED, not optional — every
                      consumer that reads actor must apply it, or historical events silently
                      lose attribution. Do not let a later card re-implement it locally;
                      actor.sh is the single owner.
                      (Builder) Verify `_dedup_events` is unaffected: it keys on
                      (ts,op,action,object) and the S event is a normal 4-tuple. Confirm the
                      marker is not re-emitted on every invocation.

Resolution:
  Implemented 2026-07-13 on agent/builder/strm-001.
  services/stream/lib/actor.sh — the single owner of identity resolution, with the REQUIRED v0
  fallback (actor -> ctx.actor, else "profile:" + ctx.prof). Never returns empty; never dies on a
  malformed ctx (a lens must not be killed by one bad line).
  The schema version is an EVENT (`<ts> S schema v1 {...}`), written idempotently before any
  write, and `ww stream status` now reads the version FROM THE LOG — a constant cannot know the
  version of a file written by another build.

  CRITERION 5 FAILED ON FIRST ATTEMPT, AND THE CONTRACT WAS WRONG. stream-event-v1.md §6 claimed
  "every existing lens handles it as a routine system event". FALSE: 6 of 8 lenses differed. Only
  bundy (op B) and frick (op F) filter by op; burroughs/hollerith/pacioli/felt/dey/cooper render
  or COUNT every event, so a synthetic S event read as ACTIVITY THAT NEVER HAPPENED — skewing the
  very density signals felt/dey/cooper exist to measure.
  FIXED AT ONE POINT, NOT SIX: replay_load() already excluded `H` (the legacy header) because the
  log's own metadata is not an event the lenses analyse. `S` is the same category. One line; zero
  lenses touched. All 8 now byte-identical. Contract corrected in place.

  Tests 24/24 (test-stream-actor 14, test-stream-schema 10). Regression gate clean (60/60).
  The 5-field encoding is untouched; system events remain IN the log — they are simply not work.

Status:               in-review
Taskwarrior:          (assign live TW id on dispatch)
