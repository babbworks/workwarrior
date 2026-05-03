## TASK-COMM-010: Warrior cross-profile annotation write — phase 2

Goal:                 Extend the Warrior service to support writing task annotations
                      to foreign profiles (profiles other than the currently active one).
                      This unlocks COMM-008 for cross-profile task entries in communities.

Acceptance criteria:  (pending Gate A sign-off before dispatch — phase 2, not phase 1)
                      1. ww warrior annotate task <profile> <uuid> "<text>" executes
                         task annotate using the named profile's TASKRC/TASKDATA
                         without shell profile-switching
                      2. Write is atomic: task annotate either fully succeeds or
                         the error is surfaced cleanly with no partial state
                      3. lib/warrior-profile-registry.sh (COMM-009) provides the
                         profile path; no new lib file required
                      4. COMM-008 copy-back flow uses this path for cross-profile tasks

Write scope:          (pending Gate A)
                      lib/warrior-profile-registry.sh (extend from COMM-009)
                      services/warrior/warrior.sh (extend from COMM-009)

Tests required:       (pending Gate A)
                      bats tests/test-warrior.bats (extend)
                      Manual: annotate task in foreign profile, verify annotation
                      appears in that profile's task data

Rollback:             git checkout lib/warrior-profile-registry.sh services/warrior/

Fragility:            Medium — writes to foreign profile task data; validate profile
                      exists and task UUID is valid before any write

Depends on:           TASK-COMM-009
Blocked by:           TASK-COMM-009 (must be complete and verified first)
Wait until:           COMM-009 complete and Verifier signed off

Status:               pending
Taskwarrior:          wwdev task 17 (5cd2dde2-10fc-4133-bfab-5c296504ee7b) status:pending
