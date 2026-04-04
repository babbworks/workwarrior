## TASK-UX-001: Standardize output modes across CLI commands

Goal:                 Default to compact human output while enabling explicit `--json` for review/automation use cases.

Acceptance criteria:  1. Output-mode policy is documented in CSSOT and help.
                      2. Read/list/status/check commands support `--json`.
                      3. Default output remains compact human for daily terminal use.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/lib/core-utils.sh
                      /Users/mp/ww/docs/usage-examples.md
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       /Users/mp/ww/bin/ww profile list
                      /Users/mp/ww/bin/ww profile list --json
                      /Users/mp/ww/bin/ww service list --json
                      bats /Users/mp/ww/tests/test-scripts-integration.sh

Rollback:             git checkout /Users/mp/ww/bin/ww /Users/mp/ww/lib/core-utils.sh /Users/mp/ww/docs/usage-examples.md /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            SERIALIZED: /Users/mp/ww/bin/ww

Risk notes:           Existing behavior affected: output rendering and scriptability of command results.
                      Tests currently covering write scope: integration tests plus manual output checks.
                      Rollback verification: formatter/flag behavior restore via revert.

Status:               pending

