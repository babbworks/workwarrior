## TASK-LED-007: Add ledger manual verbs (set-default/check/report) + reconcile docs (F5, F6)

Goal:                 Close the manual-usage gaps: expose set-default, check, and report as
                      direct `ww ledger` subcommands (they exist only inside the interactive
                      wizard today), and reconcile the CLI help and command-syntax.yaml so the
                      documented surface matches the implementation (Gate C).

Acceptance criteria:  1. `ww ledger set-default <name>` repoints the reserved default key via
                         ledger_cfg_set_default; errors cleanly on an unknown name.
                      2. `ww ledger check` runs `hledger -f <default> check` on the resolved
                         default ledger (LEDGER_F, then ledger_cfg_default_path); clean error
                         if no default ledger file exists or hledger is missing.
                      3. `ww ledger report [balance|register|balancesheet|incomestatement]`
                         runs the corresponding hledger report on the default ledger; defaults
                         to balance; rejects unknown report names.
                      4. show_help_ledger lists set-default, check, and report with usage.
                      5. system/config/command-syntax.yaml ledger domain lists every real verb:
                         add, list, remove, rename, task, inventory, set-default, check, report
                         (adds the previously-missing task/inventory — F6 drift — and the new
                         verbs).
                      6. tests/test-ledger-cli.bats covers set-default, check, report, the
                         help listing, and the command-syntax.yaml reconciliation.
                      7. No new full-suite failures beyond the environment baseline.

Write scope:          bin/ww
                      system/config/command-syntax.yaml
                      tests/test-ledger-cli.bats

Tests required:       bats tests/test-ledger-cli.bats
                      bats tests/test-smoke.bats
                      bats tests/            (bin/ww change)
                      Manual: ww ledger set-default <n> ; ww ledger check ; ww ledger report

Rollback:             git checkout bin/ww system/config/command-syntax.yaml tests/test-ledger-cli.bats

Fragility:            SERIALIZED: bin/ww — this branch is the sole writer.

Risk notes:           (Orchestrator) The module already provides ledger_cfg_set_default and
                      ledger_cfg_default_path, so these verbs are thin dispatch arms over
                      existing, unit-tested functions plus hledger invocations. The interactive
                      wizard (services/custom/configure-ledgers.sh) keeps its own menu copies;
                      consolidating the wizard onto these verbs is a separate follow-on and is
                      out of scope here.
                      (Builder) fill in pre-flight before touching bin/ww.

Status:               pending
Taskwarrior:          wwdev task <id> (<uuid>) status:pending
