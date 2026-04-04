## TASK-SYS-001: Fully activate /system control plane

Goal:                 Make `/Users/mp/ww/system` the single active operating system for project development.

Acceptance criteria:  1. All operator docs/scripts reference `system/` paths only.
                      2. `bin/wwctl status` and `bin/wwctl verify-phase1` run without path-resolution errors.
                      3. No stale references to `devsystem/*` or `system/main/*` remain in active files.

Write scope:          /Users/mp/ww/system/README.md
                      /Users/mp/ww/system/scripts/common.sh
                      /Users/mp/ww/system/scripts/system-status.sh
                      /Users/mp/ww/system/scripts/verify-phase1.sh
                      /Users/mp/ww/system/workflows/phase1.md

Tests required:       /Users/mp/ww/system/bin/wwctl status
                      /Users/mp/ww/system/bin/wwctl verify-phase1
                      rg -n "devsystem/|system/main" /Users/mp/ww/system

Rollback:             git checkout /Users/mp/ww/system/README.md /Users/mp/ww/system/scripts/common.sh /Users/mp/ww/system/scripts/system-status.sh /Users/mp/ww/system/scripts/verify-phase1.sh /Users/mp/ww/system/workflows/phase1.md

Fragility:            None

Risk notes:           Existing behavior affected: operator workflow pathing.
                      Tests currently covering write scope: wwctl status/verify smoke checks.
                      Rollback verification: direct file revert restores previous behavior.
                      Dispatch readiness: ready-now (current phase approved by Orchestrator).
                      Dependencies: none.
                      Completion evidence (2026-04-04): wwctl status/verify run cleanly for path resolution;
                      stale-path scan returns no matches outside this task card.

Status:               complete
