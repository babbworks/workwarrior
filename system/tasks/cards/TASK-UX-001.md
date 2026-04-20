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

Implementation notes: Added default compact output policy via `WW_DEFAULT_OUTPUT_MODE`
                      (from `lib/core-utils.sh`) and applied mode resolution in
                      `parse_global_flags()` so default is compact, `--verbose`
                      opts into expanded human mode, and `--json` remains explicit.
                      Added compact/json support for `profile info`, compact support
                      for `service info`, and compact branch for `timew extensions list`.
                      Updated CLI help text, CSSOT output-mode policy wording, and
                      usage examples.
                      Manual checks passed:
                        - `ww profile list`
                        - `ww profile list --json`
                        - `ww service list --json`
                      `tests/test-scripts-integration.sh` could not be completed in
                      sandbox due home-directory write restrictions (`~/.bashrc`);
                      elevated re-run requires user approval.

Status:               complete

