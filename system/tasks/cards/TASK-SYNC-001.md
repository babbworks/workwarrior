## TASK-SYNC-001: Add test coverage for GitHub sync engine

Goal:                 The entire sync engine (6 files, 17 functions) has zero BATS tests.
                      Build a baseline test suite covering the critical paths identified by Explorer B.

Acceptance criteria:  1. github-api.sh: tests for check_gh_cli (not installed, not authed), github_get_issue (invalid repo, 404, rate limit).
                      2. github-sync-state.sh: tests for save_sync_state with corrupted state.json, mv failure simulation, empty state.
                      3. sync-detector.sh: tests for detect_task_changes with malformed jq input (silent failure path).
                      4. sync-pull.sh / sync-push.sh: at least one happy-path and one error-path test each using mocked gh CLI.
                      5. All new tests pass in bats tests/.

Write scope:          /Users/mp/ww/tests/test-github-sync.bats  (new file)
                      /Users/mp/ww/tests/test-sync-state.bats   (new file)

Tests required:       bats tests/test-github-sync.bats
                      bats tests/test-sync-state.bats
                      bats tests/

Rollback:             git checkout tests/test-github-sync.bats tests/test-sync-state.bats

Fragility:            HIGH FRAGILITY context — tests must mock gh CLI and jq, not call real APIs.

Risk notes:           Existing behavior affected: none (tests only).
                      Tests currently covering write scope: zero.
                      Rollback verification: delete new test files.
                      Explorer B source: all sync libs have 0 BATS tests.

Status:               pending
