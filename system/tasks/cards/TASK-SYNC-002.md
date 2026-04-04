## TASK-SYNC-002: Fix critical state integrity bugs in sync engine

Goal:                 Three specific bugs found by Explorer B can silently corrupt or permanently
                      destroy user data. Fix them before any sync hardening work proceeds.

Acceptance criteria:  1. github-sync-state.sh:182 — bare `mv` after jq transform gets error check
                         and a rollback path (restore from temp file on failure).
                      2. sync-detector.sh:43–46 — jq failure in change detection is caught;
                         function returns an error instead of silently using empty `changes`.
                      3. profile-manager.sh:1753–1762 — restore operation uses two-phase commit:
                         write to temp path, validate, then atomic rename; original not deleted
                         until replacement is confirmed in place.
                      4. Each fix has a BATS test that triggers the failure path and verifies
                         correct error handling / no data loss.

Write scope:          /Users/mp/ww/lib/github-sync-state.sh
                      /Users/mp/ww/lib/sync-detector.sh
                      /Users/mp/ww/lib/profile-manager.sh
                      /Users/mp/ww/tests/test-sync-state.bats  (new or extend from SYNC-001)

Tests required:       bats tests/test-sync-state.bats
                      bats tests/

Rollback:             git checkout /Users/mp/ww/lib/github-sync-state.sh /Users/mp/ww/lib/sync-detector.sh /Users/mp/ww/lib/profile-manager.sh

Fragility:            HIGH FRAGILITY: lib/github-sync-state.sh, lib/sync-detector.sh
                      HIGH RISK: lib/profile-manager.sh — profile data loss on failed restore

Risk notes:           Explorer B findings:
                        github-sync-state.sh:182 — mv with no error check; state.json silently lost on disk-full
                        sync-detector.sh:43-46 — jq failure leaves changes="" and continues silently
                        profile-manager.sh:1753-1762 — rm -rf original before mv succeeds; if mv fails, profile is gone
                      Rollback verification: file restore reverts all three fixes independently.

Status:               pending
