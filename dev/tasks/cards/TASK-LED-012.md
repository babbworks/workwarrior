## TASK-LED-012: Land ledger-schema — rebase TASK-LED-004..011 onto the dev/ layout

Goal:                 ~1,900 lines of built, tested ledger code (lib/ledger-config.sh,
                      lib/ledger-dispatch.sh, 4 test suites, TASK-LED-004..011) are STRANDED
                      on branch agent/builder/ledger-schema, which was cut from master BEFORE
                      the system/ -> dev/ rename. Nothing ledger-side can build until it lands.

Depends on:           TASK-STRUCT-1B (merged — the rename this must rebase across)

Acceptance criteria:  1. Rebase `agent/builder/ledger-schema` (8 commits, 7de3679) onto the
                         post-STRUCT-1B tree. Conflicts are ENTIRELY path-level:
                         system/TASKS.md -> dev/TASKS.md, system/tasks/cards/ -> dev/tasks/cards/,
                         system/logs/decisions.md -> dev/logs/decisions.md,
                         system/config/command-syntax.yaml -> config/command-syntax.yaml (moved by 1A),
                         tests/ -> dev/tests/.
                      2. The 2026-07-11 ledgers.yaml decision entry merges into dev/logs/decisions.md
                         WITHOUT duplicating the copy now in dev/schemas/ledgers-yaml-v1.md.
                         decisions.md keeps the WHY; the schema doc keeps the WHAT.
                      3. Cards TASK-LED-004..011 land in dev/tasks/cards/.
                      4. Test files' relative-root derivation is corrected for the extra depth
                         (dev/tests/ is one level deeper — see decisions.md 2026-07-10 depth gotcha).
                         The 4 ledger suites MUST be checked for this specifically.
                      5. Full `bats dev/tests/` at/above baseline, INCLUDING the 4 new ledger
                         suites (test-ledger-config, test-ledger-cli, test-ledger-l-function,
                         test-ledger-naming-convention).
                      6. `ww ledger` + the `l` shell function work end-to-end in a scratch install.

Write scope:          (rebase) branch agent/builder/ledger-schema onto agent/builder/struct-1b
                      dev/tests/test-ledger-*.bats  (depth fix)

Tests required:       bats dev/tests/            (full suite — at/above baseline, with 4 new suites)
                      Manual: ww ledger add/list/set-default/check/report; `l` function; `l -L <name>`

Rollback:             The branch is untouched until the rebase is force-pushed. Abort = discard.

Fragility:            MEDIUM. Large rebase across a 285-file rename. The depth gotcha
                      (decisions.md 2026-07-10) WILL bite the 4 ledger test suites if not
                      handled — a green exit code lies; only a failing-test-NAME-set diff
                      against baseline exposes it.

Risk notes:           (Orchestrator) Do NOT re-derive the ledger work. It is built and it is
                      correct — this card is purely a relocation. Run SOLO: no other task may
                      touch lib/, dev/tests/, or bin/ww concurrently.

Resolution:
  Ported and MERGED 2026-07-13 (acd0171). A 12-commit rebase conflicted on every path, so
  the work was ported by explicit 3-way merge — the card called it: the conflicts are
  ENTIRELY path-level.
  Two real merges, not blind copies: bin/ww (both sides added a source block — both belong),
  and lib/shell-integration.sh (ledger-schema REWROTE `l` to call ledger_dispatch, so the
  direct `hledger -f` call LED-013's floor guard sat in front of no longer existed; the guard
  moved to _ledger_passthrough in lib/ledger-dispatch.sh — exactly what LED-013's card required).
  THE DEPTH GOTCHA BIT, as decisions.md 2026-07-10 predicted: the 3 new suites derived the repo
  root by counting ../ and resolved to dev/lib. Added one traversal level. Also fixed a stale
  $WW_BASE/system/config/command-syntax.yaml path.
  THE REGRESSION GATE CAUGHT A REAL BREAK: test-hledger-floor asserted the guard lived in `l`,
  which is no longer where the passthrough is. The test was asserting a dead architecture.
  Verified: ledger + alias suites 92/92; check-regression.sh 60/60, no new failures.

Status:               complete
Taskwarrior:          (assign live TW id on dispatch)
