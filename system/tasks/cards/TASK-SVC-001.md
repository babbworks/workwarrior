## TASK-SVC-001: Implement journal command lifecycle

Goal:                 Deliver `ww journal|journals add/list/remove/rename` with preferred singular namespace and alias compatibility.

Acceptance criteria:  1. Preferred `ww journal ...` forms are fully supported.
                      2. `ww journals ...` remains supported as alias with preference hint.
                      3. JRNL config and files update safely per profile.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/lib/profile-manager.sh
                      /Users/mp/ww/services/custom/configure-journals.sh
                      /Users/mp/ww/docs/usage-examples.md
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       bats /Users/mp/ww/tests/test-journal-initialization.bats
                      bats /Users/mp/ww/tests/test-journal-addition.bats
                      /Users/mp/ww/bin/ww journal list
                      /Users/mp/ww/bin/ww journals list

Rollback:             git checkout /Users/mp/ww/bin/ww /Users/mp/ww/lib/profile-manager.sh /Users/mp/ww/services/custom/configure-journals.sh /Users/mp/ww/docs/usage-examples.md /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            None

Risk notes:           Existing behavior affected: journal management and command namespace behavior.
                      Tests currently covering write scope: journal init/add test files.
                      Rollback verification: command and config behavior return on file revert.
                      Implementation evidence (2026-04-04): added journal lifecycle library operations
                      in lib/profile-manager.sh (`remove_journal_from_profile`, `rename_journal_in_profile`);
                      wired `ww journal add/remove/rename` in bin/ww with profile-aware scope handling;
                      kept `ww journals ...` alias compatibility with preference nudges; updated
                      configure-journals guidance, docs usage examples, and CSSOT journal contract/status.
                      Verification (2026-04-04): bats /Users/mp/ww/tests/test-journal-initialization.bats (pass),
                      bats /Users/mp/ww/tests/test-journal-addition.bats (pass),
                      /Users/mp/ww/bin/ww journal list (pass),
                      /Users/mp/ww/bin/ww journals list (pass with compatibility warning),
                      manual lifecycle smoke (pass): add -> rename -> remove using `ww --profile <tmp> journal ...`.

Status:               complete
