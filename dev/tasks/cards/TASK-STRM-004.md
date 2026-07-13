## TASK-STRM-004: The board — who/what is currently IN (lens + CLI + JSON)

Goal:                 The interpretive layer. Answer the question the punch clock exists to
                      answer: WHO IS IN RIGHT NOW. A new lens, auto-discovered, touching no
                      existing lens. This is also, for free, the hung-agent detector.

Depends on:           TASK-STRM-003 (events must carry actor before a board can group by it)

Contract:             dev/schemas/stream-event-v1.md §4
Design:               dev/specs/2026-07-12-stream-actor-axis-design.md §3.3, §5

Acceptance criteria:  1. NEW `services/stream/lenses/board.sh` exposing `lens_describe` +
                         `lens_run` (the lens contract). Auto-discovered by `lens_list` —
                         NO existing lens file is edited, and no dispatch table is hand-updated.
                      2. It computes the OPEN SET: `B start <obj>` with no matching
                         `B stop <obj>`. (The bundy lens already tracks this set in `starts`
                         and discards it — board KEEPS it. Do not fork bundy; write the lens.)
                      3. Rows keyed by (actor, object) — the PAIR. Columns:
                         ACTOR | OBJECT | PROJ | IN SINCE | DURATION.
                      4. Actor resolved via actor.sh (STRM-001) — v0 events with no actor key
                         MUST still appear, attributed via the `profile:<prof>` fallback.
                         An actor ID absent from the registry displays AS-IS and is never
                         dropped (schema/actors-v1 §7: the log is truth, the registry is a
                         lookup).
                      5. `ww stream board [--actor X] [--proj P] [--stale <dur>] [--format json]`.
                         `--stale` FLAGS rows open longer than <dur>. It MUST NOT close them.
                      6. Sorted longest-open first (the stale ones surface without a flag).
                      7. `--format json` emits a stable array — this is the contract the
                         browser panel and the Warrior app consume.
                      8. Empty log / no open punches -> a clean "nobody is in" message, exit 0.
                         Not an error.
                      9. Verified at scale: 40+ concurrent actors with overlapping punches
                         render correctly (this is already proven possible against the
                         unmodified bundy lens — the board must not regress it).

Write scope:          services/stream/lenses/board.sh    (new)
                      services/stream/stream.sh          (board subcommand in dispatch case)
                      dev/tests/test-stream-board.bats   (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-stream-board.bats
                      bats dev/tests/            (full suite — at/above baseline)
                      Manual: 40-concurrent-actor fixture (criterion 9).
                      Manual: v0 event with no actor key still appears (criterion 4).

Rollback:             git revert + rm the lens file. Read-only feature; nothing is written to
                      the log by this card at all.

Fragility:            LOW. The lens is a new file and reads only. The single dispatch-case
                      line in stream.sh is the only edit to existing code.

Risk notes:           (Orchestrator) A STALE PUNCH IS A HUNG AGENT. An agent that punched in
                      and never punched out is definitionally a loop that did not terminate.
                      The loop-agent work lists "detect no-progress" as a hard requirement —
                      this card delivers that detector as a side effect. The floor-manager
                      view and the agent-supervision view are the same screen. Do not let
                      --stale acquire a "fix it" behaviour: flagging and closing are
                      different acts, and closing belongs to STRM-005.
                      (Builder) Read-only. This card MUST NOT append any event.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
