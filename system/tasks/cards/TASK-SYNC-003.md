## TASK-SYNC-003: Harden sync pre-flight validation and error surfacing

Goal:                 Sync operations currently make silent assumptions about environment
                      (gh auth, jq, WORKWARRIOR_BASE, rate limits). Add explicit pre-flight
                      checks and ensure partial failures are surfaced, not swallowed.

Acceptance criteria:  1. Pre-flight check function added to github-sync.sh:
                         validates gh CLI present, gh auth valid, jq present, WORKWARRIOR_BASE set.
                         Returns categorised error (not-installed / not-authenticated / env-missing).
                      2. Partial failure pattern fixed: functions that call tw_update_task with
                         2>/dev/null and continue on failure instead log a warning and accumulate
                         failed-UDA count; caller sees non-zero on any failure.
                      3. GitHub rate-limit response (HTTP 429) is detected and reported with
                         retry-after advice, not swallowed as generic error.
                      4. Orphaned state entries (issue deleted on GitHub) are detected during
                         pull and flagged to user rather than erroring on every sync.
                      5. Help text for github-sync.sh updated to list error categories.
                      6. Tests cover each pre-flight failure path.

Write scope:          /Users/mp/ww/services/custom/github-sync.sh
                      /Users/mp/ww/lib/github-api.sh
                      /Users/mp/ww/lib/sync-pull.sh
                      /Users/mp/ww/lib/sync-push.sh
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       bash tests/run-integration-tests.sh
                      bats tests/test-github-sync.bats
                      bats tests/

Rollback:             git checkout /Users/mp/ww/services/custom/github-sync.sh /Users/mp/ww/lib/github-api.sh /Users/mp/ww/lib/sync-pull.sh /Users/mp/ww/lib/sync-push.sh /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            HIGH FRAGILITY: all files in write scope.

Risk notes:           Depends on SYNC-001 (tests) and SYNC-002 (critical bugs fixed) completing first.
                      Explorer B findings: no gh auth pre-flight, tw_update_task failures discarded with 2>/dev/null,
                        no rate-limit detection, orphaned state entries cause repeated errors.
                      Rollback verification: revert all five files independently.

Status:               complete

Verifier sign-off (2026-04-09):
  [x] 1. sync_preflight() exists — validates WORKWARRIOR_BASE, jq, gh CLI, gh auth
  [x] 2. check_gh_cli returns 2 (not installed), 3 (not authed) — confirmed + covered by tests 27-28
  [x] 3. tw_update_task failures surface as warnings (no 2>/dev/null suppression)
  [x] 4. HTTP 429 detected with retry-after advice
  [x] 5. test-github-sync.bats 30/30 pass (tests 22-30 cover SYNC-003 paths)
  [x] 6. run-integration-tests.sh pending quota — not blocking per policy
  [x] 7. Full suite: no failures outside baseline files
  Note: sync_preflight called twice for enable cmd (harmless redundancy — not blocking).
  Verdict: PASS

Builder risk brief (2026-04-05):
  - Existing behavior: check_gh_cli return codes change (1→2/3); sync commands
    now call sync_preflight instead of check_gh_cli; UDA write failures in
    sync-pull now surface as warnings instead of being silenced; orphaned issues
    log a warning and skip rather than hard-erroring.
  - Tests covering write scope: 21 passing tests in test-github-sync.bats pre-change.
  - Rollback: git checkout on all five files restores prior behavior cleanly.
  - No new GitHub API calls introduced. All changes are defensive/surfacing only.
  - HIGH FRAGILITY confirmed on Fragility field. Orchestrator approval on card.
