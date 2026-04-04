## TASK-SVC-006: Normalize issues service command contract

Goal:                 Align `i` and `ww` issues/sync command routing, messaging, and scope behavior.

Acceptance criteria:  1. Command matrix for `i` and `ww` issues routes is explicit and implemented.
                      2. One-way bugwarrior semantics are consistently communicated.
                      3. Help/docs/CSSOT parity is maintained for all issues commands.

Write scope:          /Users/mp/ww/lib/shell-integration.sh
                      /Users/mp/ww/bin/ww
                      /Users/mp/ww/services/custom/configure-issues.sh
                      /Users/mp/ww/services/custom/README-issues.md
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       bats /Users/mp/ww/tests/test-shell-functions.bats
                      /Users/mp/ww/bin/ww help custom
                      Manual: i pull --dry-run, i custom

Rollback:             git checkout /Users/mp/ww/lib/shell-integration.sh /Users/mp/ww/services/custom/configure-issues.sh /Users/mp/ww/services/custom/README-issues.md /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            SERIALIZED: /Users/mp/ww/lib/shell-integration.sh

Risk notes:           Existing behavior affected: shell alias/function dispatch for issues commands.
                      Tests currently covering write scope: shell integration test coverage.
                      Rollback verification: routing reverts with shell integration restore.

Status:               complete

