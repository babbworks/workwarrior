## TASK-SVC-005: Harden questions service CLI UX

Goal:                 Normalize `q`/questions behavior, template lifecycle, and errors for reliable daily use.

Acceptance criteria:  1. Template create/list/edit/delete flows are deterministic and validated.
                      2. Errors are actionable with clear next-step guidance.
                      3. Help/usage examples match implemented behavior.

Write scope:          /Users/mp/ww/services/questions/q.sh
                      /Users/mp/ww/services/questions/README.md
                      /Users/mp/ww/tests/test-questions-service.sh
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       bash /Users/mp/ww/tests/test-questions-service.sh
                      bats /Users/mp/ww/tests/test-scripts-integration.sh
                      Manual: q, q list, q new journal

Rollback:             git checkout /Users/mp/ww/services/questions/q.sh /Users/mp/ww/services/questions/README.md /Users/mp/ww/tests/test-questions-service.sh /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            None

Risk notes:           Existing behavior affected: interactive prompt flow and template file writes.
                      Tests currently covering write scope: questions service test script.
                      Rollback verification: service behavior reverts with script restore.
                      Implementation evidence (2026-04-04): normalized `q` help/usage output via shared
                      `_q_usage`; added deterministic sorted template listing; added template/service name
                      validation; added actionable next-step error hints; added optional `--yes` for
                      non-interactive template delete; aligned service README and usage examples with
                      implemented command forms.
                      Verification (2026-04-04): WW_BASE=/Users/mp/ww bash /Users/mp/ww/tests/test-questions-service.sh (pass),
                      bats /Users/mp/ww/tests/test-scripts-integration.sh (pass),
                      manual checks (pass): q, q list, q new journal (piped input).

Status:               complete
