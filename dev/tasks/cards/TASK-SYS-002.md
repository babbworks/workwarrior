## TASK-SYS-002: Stabilize Phase-1 verification behavior

Goal:                 Ensure Phase-1 verification reports only real blockers and clearly distinguishes structural vs rollout failures.

Acceptance criteria:  1. `verify-phase1` output groups failures by category (structural, rollout, hygiene).
                      2. Expected rollout failures are clearly labeled with next action.
                      3. No false-negative checks from missing fallback directories (`audits`/`outputs`).

Write scope:          ~/ww/dev/scripts/verify-phase1.sh
                      ~/ww/dev/config/phase1-checklist.txt
                      ~/ww/dev/README.md

Tests required:       ~/ww/dev/bin/wwctl verify-phase1
                      ~/ww/dev/bin/wwctl status

Rollback:             git checkout ~/ww/dev/scripts/verify-phase1.sh ~/ww/dev/config/phase1-checklist.txt ~/ww/dev/README.md

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
