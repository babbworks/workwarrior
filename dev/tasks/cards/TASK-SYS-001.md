## TASK-SYS-001: Fully activate /system control plane

Goal:                 Make `~/ww/system` the single active operating system for project development.

Acceptance criteria:  1. All operator docs/scripts reference `dev/` paths only.
                      2. `bin/wwctl status` and `bin/wwctl verify-phase1` run without path-resolution errors.
                      3. No stale references to `devdev/*` or `dev/main/*` remain in active files.

Write scope:          ~/ww/dev/README.md
                      ~/ww/dev/scripts/common.sh
                      ~/ww/dev/scripts/system-status.sh
                      ~/ww/dev/scripts/verify-phase1.sh
                      ~/ww/dev/workflows/phase1.md

Tests required:       ~/ww/dev/bin/wwctl status
                      ~/ww/dev/bin/wwctl verify-phase1
                      rg -n "devdev/|dev/main" ~/ww/system

Rollback:             git checkout ~/ww/dev/README.md ~/ww/dev/scripts/common.sh ~/ww/dev/scripts/system-status.sh ~/ww/dev/scripts/verify-phase1.sh ~/ww/dev/workflows/phase1.md

Fragility:            None

Risk notes:           Existing behavior affected: operator workflow pathing.
                      Tests currently covering write scope: wwctl status/verify smoke checks.
                      Rollback verification: direct file revert restores previous behavior.
                      Dispatch readiness: ready-now (current phase approved by Orchestrator).
                      Dependencies: none.
                      Completion evidence (2026-04-04): wwctl status/verify run cleanly for path resolution;
                      stale-path scan returns no matches outside this task card.

Status:               complete
