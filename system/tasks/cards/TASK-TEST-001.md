## TASK-TEST-001: Enforce baseline tests by change type

Goal:                 Make required test suites enforceable from task metadata and change classification.

Acceptance criteria:  1. A script maps change type to required tests from config.
                      2. Verifier flow uses this mapping before sign-off.
                      3. Missing required tests block completion.

Write scope:          /Users/mp/ww/system/config/test-baseline.yaml
                      /Users/mp/ww/system/scripts/select-tests.sh
                      /Users/mp/ww/system/scripts/verify-phase1.sh
                      /Users/mp/ww/system/workflows/feature-delivery.md

Tests required:       bash /Users/mp/ww/system/scripts/select-tests.sh lib
                      bash /Users/mp/ww/system/scripts/select-tests.sh service
                      bash /Users/mp/ww/system/scripts/select-tests.sh github_sync

Rollback:             git checkout /Users/mp/ww/system/config/test-baseline.yaml /Users/mp/ww/system/scripts/select-tests.sh /Users/mp/ww/system/scripts/verify-phase1.sh /Users/mp/ww/system/workflows/feature-delivery.md

Fragility:            None

Risk notes:           Existing behavior affected: verifier gating and task completion criteria.
                      Tests currently covering write scope: script-level manual execution.
                      Rollback verification: policy/script revert.

Status:               complete

