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

Status:               complete

Verifier sign-off (2026-04-09 — Orchestrator/Claude):
  [x] 1. ww help stderr = 0 bytes (confirmed live)
  [x] 2. Compatibility line clean — single-quotes, no system groups (confirmed live)
  [x] 3. ww deps help has install policy referencing docs/INSTALL.md (static review)
  [x] 4. ww tui install has Linux _tui_pm platform detection (static review)
  [x] 5. ww mcp install has Linux _mcp_pm platform detection (static review)
  [x] 6. BATS bin_ww: only known baseline failures (confirmed from prior run)
  [x] 7. production-readiness-rubric.md: 5 criteria with evidence + owner (static review)
  [x] 8. docs/INSTALL.md: canonical vs best-effort split present (static review)
  [x] 9. Gate D references rubric (static review)
  Verdict: PASS

