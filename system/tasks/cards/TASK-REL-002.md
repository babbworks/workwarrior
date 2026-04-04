## TASK-REL-002: Define production-ready CLI milestone criteria

Goal:                 Establish measurable criteria for declaring Workwarrior CLI production-ready.

Acceptance criteria:  1. Milestone rubric includes stability, test coverage, docs/help parity, and migration compatibility.
                      2. Each criterion has an evidence source and owner role.
                      3. Milestone status can be evaluated from current reports/checklists.

Write scope:          /Users/mp/ww/system/reports/production-readiness-rubric.md
                      /Users/mp/ww/system/gates/all-gates.md
                      /Users/mp/ww/docs/RELEASE-CHECKLIST.md
                      /Users/mp/ww/system/workflows/feature-delivery.md

Tests required:       rg -n "production-ready|rubric|evidence" /Users/mp/ww/system/reports/production-readiness-rubric.md /Users/mp/ww/system/gates/all-gates.md /Users/mp/ww/docs/RELEASE-CHECKLIST.md
                      Manual: milestone dry-run against current project status.

Rollback:             git checkout /Users/mp/ww/system/reports/production-readiness-rubric.md /Users/mp/ww/system/gates/all-gates.md /Users/mp/ww/docs/RELEASE-CHECKLIST.md /Users/mp/ww/system/workflows/feature-delivery.md

Fragility:            None

Risk notes:           Existing behavior affected: roadmap prioritization and release claims.
                      Tests currently covering write scope: document consistency and evidence mapping checks.
                      Rollback verification: rubric/gate docs revert.

Status:               pending

