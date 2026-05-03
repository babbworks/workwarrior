## TASK-SYS-002: Stabilize Phase-1 verification behavior

Goal:                 Ensure Phase-1 verification reports only real blockers and clearly distinguishes structural vs rollout failures.

Acceptance criteria:  1. `verify-phase1` output groups failures by category (structural, rollout, hygiene).
                      2. Expected rollout failures are clearly labeled with next action.
                      3. No false-negative checks from missing fallback directories (`audits`/`outputs`).

Write scope:          /Users/mp/ww/system/scripts/verify-phase1.sh
                      /Users/mp/ww/system/config/phase1-checklist.txt
                      /Users/mp/ww/system/README.md

Tests required:       /Users/mp/ww/system/bin/wwctl verify-phase1
                      /Users/mp/ww/system/bin/wwctl status

Rollback:             git checkout /Users/mp/ww/system/scripts/verify-phase1.sh /Users/mp/ww/system/config/phase1-checklist.txt /Users/mp/ww/system/README.md

Fragility:            None

Risk notes:           Existing behavior affected: gate feedback clarity.
                      Tests currently covering write scope: manual wwctl verification runs.
                      Rollback verification: script-only revert.
                      Dispatch readiness: ready-now (preferred after TASK-SYS-001).
                      Dependencies: TASK-SYS-001 preferred for cleaner baseline.
                      Completion evidence (2026-04-04): verify-phase1 now reports categorized
                      results (structural/rollout/hygiene) and actionable next steps.
                      audits/outputs fallback checks confirmed active in explorer gate checks.

Status:               complete
