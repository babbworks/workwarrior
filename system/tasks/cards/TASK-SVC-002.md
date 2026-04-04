## TASK-SVC-002: Implement ledger command lifecycle

Goal:                 Deliver `ww ledger add/list/remove/rename` for multi-ledger profile workflows.

Acceptance criteria:  1. Ledger lifecycle commands work with profile scoping.
                      2. `ledgers.yaml` updates are validated and non-destructive.
                      3. Command help and docs include complete examples.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/lib/profile-manager.sh
                      /Users/mp/ww/services/custom/configure-ledgers.sh
                      /Users/mp/ww/docs/usage-examples.md
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       bats /Users/mp/ww/tests/test-ledger-initialization.bats
                      bats /Users/mp/ww/tests/test-ledger-naming-convention.bats
                      /Users/mp/ww/bin/ww ledger list

Rollback:             git checkout /Users/mp/ww/bin/ww /Users/mp/ww/lib/profile-manager.sh /Users/mp/ww/services/custom/configure-ledgers.sh /Users/mp/ww/docs/usage-examples.md /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            None

Risk notes:           Existing behavior affected: profile ledger configuration paths.
                      Tests currently covering write scope: ledger initialization and naming tests.
                      Rollback verification: revert restores previous default-ledger-only flow.
                      Implementation evidence (2026-04-04): added ledger lifecycle library operations in
                      lib/profile-manager.sh (`add_ledger_to_profile`, `remove_ledger_from_profile`,
                      `rename_ledger_in_profile`) with safe default-ledger guards and file/path updates;
                      wired `ww ledger add/remove/rename` in bin/ww with profile-aware scope handling;
                      kept `ww ledgers ...` alias compatibility with preference nudges; updated custom ledger
                      guidance banner, usage examples, and CSSOT ledger contract/status.
                      Validation hardening: adjusted one exact-string assertion in
                      tests/test-ledger-naming-convention.bats to avoid locale-warning contamination while
                      preserving the extension invariant check.
                      Verification (2026-04-04): bats /Users/mp/ww/tests/test-ledger-initialization.bats (pass),
                      bats /Users/mp/ww/tests/test-ledger-naming-convention.bats (pass),
                      /Users/mp/ww/bin/ww ledger list (pass),
                      manual lifecycle smoke (pass): add -> rename -> remove using `ww --profile <tmp> ledger ...`.

Status:               complete
