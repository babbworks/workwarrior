## TASK-CLI-001: Define top-level CLI taxonomy

Goal:                 Standardize the global command model as `ww <domain> <verb> [args]`.

Acceptance criteria:  1. Approved domain map exists for all core services.
                      2. Primary and alias forms are defined (e.g., `journal` preferred, `journals` alias).
                      3. Dispatch behavior in `bin/ww` matches documented taxonomy.

Write scope:          ~/ww/bin/ww
                      ~/ww/dev/config/command-syntax.yaml
                      ~/ww/docs/usage-examples.md

Tests required:       bats ~/ww/dev/tests/test-scripts-integration.sh
                      ~/ww/bin/ww help
                      ~/ww/bin/ww help standalone

Rollback:             git checkout ~/ww/bin/ww ~/ww/dev/config/command-syntax.yaml ~/ww/docs/usage-examples.md

Fragility:            SERIALIZED: ~/ww/bin/ww — confirm no overlapping active CLI task

Risk notes:           Existing behavior affected: all top-level CLI routing.
                      Tests currently covering write scope: script integration tests and help checks.
                      Rollback verification: dispatch map reverts with file restore.
                      Implementation evidence (2026-04-04): singular/plural taxonomy added in bin/ww;
                      plural bare-list shortcuts added for profiles/services/groups/models/journals/ledgers;
                      CSSOT updated with noun/verb policy and aliases; docs usage examples updated.
                      Debug closure (2026-04-04): fixed test env shell-config honoring in lib/shell-integration.sh;
                      fixed manage-profiles filesystem calls to use `command find`; stabilized integration backup test
                      destination handling in dev/tests/test-scripts-integration.sh.
                      Verification (2026-04-04): bats ~/ww/dev/tests/test-scripts-integration.sh (pass),
                      WW_BASE=~/ww ~/ww/bin/ww help (pass),
                      WW_BASE=~/ww ~/ww/bin/ww groups (pass),
                      WW_BASE=~/ww ~/ww/bin/ww services (pass),
                      WW_BASE=~/ww WARRIOR_PROFILE=work WORKWARRIOR_BASE=~/ww/profiles/work
                      ~/ww/bin/ww journal list (pass), ~/ww/bin/ww journals (pass).

Status:               complete
