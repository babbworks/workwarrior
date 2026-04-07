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
