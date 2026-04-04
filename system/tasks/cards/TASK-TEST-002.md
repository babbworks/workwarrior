## TASK-TEST-002: Add CI gate for required BATS and integration suites

Goal:                 Run required tests automatically on PRs based on change type and block merges on failure.

Acceptance criteria:  1. CI workflow runs baseline suites for touched areas.
                      2. Failures block merge until resolved.
                      3. CI output clearly maps failures to gate criteria.

Write scope:          /Users/mp/ww/.github/workflows/workwarrior-tests.yml
                      /Users/mp/ww/tests/TESTING-QUICK-START.md
                      /Users/mp/ww/system/workflows/feature-delivery.md

Tests required:       gh workflow run dry-run (or local lint of workflow)
                      bats /Users/mp/ww/tests/*.bats
                      bash /Users/mp/ww/tests/run-integration-tests.sh

Rollback:             git checkout /Users/mp/ww/.github/workflows/workwarrior-tests.yml /Users/mp/ww/tests/TESTING-QUICK-START.md /Users/mp/ww/system/workflows/feature-delivery.md

Fragility:            None

Risk notes:           Existing behavior affected: merge workflow and development velocity.
                      Tests currently covering write scope: CI pipeline itself validated via workflow checks.
                      Rollback verification: remove workflow changes.

Status:               pending

