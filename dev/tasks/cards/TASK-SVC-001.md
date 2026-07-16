## TASK-SVC-001: Implement journal command lifecycle

Goal:                 Deliver `ww journal|journals add/list/remove/rename` with preferred singular namespace and alias compatibility.

Acceptance criteria:  1. Preferred `ww journal ...` forms are fully supported.
                      2. `ww journals ...` remains supported as alias with preference hint.
                      3. JRNL config and files update safely per profile.

Write scope:          ~/ww/bin/ww
                      ~/ww/lib/profile-manager.sh
                      ~/ww/services/custom/configure-journals.sh
                      ~/ww/docs/usage-examples.md
                      ~/ww/dev/config/command-syntax.yaml

Tests required:       bats ~/ww/dev/tests/test-journal-initialization.bats
                      bats ~/ww/dev/tests/test-journal-addition.bats
                      ~/ww/bin/ww journal list
                      ~/ww/bin/ww journals list

Rollback:             git checkout ~/ww/bin/ww ~/ww/lib/profile-manager.sh ~/ww/services/custom/configure-journals.sh ~/ww/docs/usage-examples.md ~/ww/dev/config/command-syntax.yaml

Fragility:            None

Risk notes:           Existing behavior affected: journal management and command namespace behavior.
                      Tests currently covering write scope: journal init/add test files.
                      Rollback verification: command and config behavior return on file revert.
                      Implementation evidence (2026-04-04): added journal lifecycle library operations
                      in lib/profile-manager.sh (`remove_journal_from_profile`, `rename_journal_in_profile`);
                      wired `ww journal add/remove/rename` in bin/ww with profile-aware scope handling;
                      kept `ww journals ...` alias compatibility with preference nudges; updated
                      configure-journals guidance, docs usage examples, and CSSOT journal contract/status.
                      Verification (2026-04-04): bats ~/ww/dev/tests/test-journal-initialization.bats (pass),
                      bats ~/ww/dev/tests/test-journal-addition.bats (pass),
                      ~/ww/bin/ww journal list (pass),
                      ~/ww/bin/ww journals list (pass with compatibility warning),
                      manual lifecycle smoke (pass): add -> rename -> remove using `ww --profile <tmp> journal ...`.

Status:               complete
