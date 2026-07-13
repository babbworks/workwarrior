## TASK-LED-009: lib/ledger-dispatch.sh + adopt in cmd_ledger (reserved words + passthrough)

Goal:                 Introduce the shared ledger dispatch layer and adopt it in cmd_ledger so
                      `ww ledger` becomes "reserved management words + hledger passthrough for
                      everything else" (see decisions.md 2026-07-12). Rename management add->new,
                      drop the redundant check/report verbs, make unknown verbs pass through to
                      hledger, and make bare `ww ledger` show a balance. The `l` shell function
                      is wired onto the same dispatch in TASK-LED-010 (SERIALIZED file, separate).

Acceptance criteria:  1. New lib/ledger-dispatch.sh sources cleanly (sourced-lib rules: no
                         set -euo pipefail, return codes) and exposes ledger_dispatch().
                      2. ledger_dispatch routes reserved words to the schema-owner module /
                         scripts and passes everything else to `hledger -f "$LEDGER_F"`:
                         - new <name>        create+register a ledger (old `add` behavior)
                         - remove|rm <name>  ledger_cfg_remove
                         - rename <o> <n>    ledger_cfg_rename
                         - list              ledger_cfg_names
                         - set-default <n>   ledger_cfg_set_default
                         - inventory         build-ledger-inventory.sh
                         - custom            configure-ledgers.sh
                         - help|-h|--help    ledger help
                         - (no args)         hledger -f "$LEDGER_F" balance
                         - anything else     hledger -f "$LEDGER_F" <args>   (passthrough)
                      3. cmd_ledger keeps `task` as its own arm, delegates all other actions to
                         ledger_dispatch. `ww ledger add …` now passes through to `hledger add`;
                         `ww ledger new <name>` creates a ledger file.
                      4. check and report are no longer ww verbs (pass through to hledger).
                      5. Default-ledger resolution prefers $LEDGER_F, falls back to
                         ledger_cfg_default_path; explicit -f in args bypasses injection.
                      6. show_help_ledger and system/config/command-syntax.yaml updated: new
                         (not add), no check/report, note passthrough for hledger commands.
                      7. tests/test-ledger-cli.bats updated: `ww ledger new` creates+registers;
                         `ww ledger list` unchanged; bare `ww ledger` runs balance; an arbitrary
                         hledger command (e.g. `ww ledger accounts`) passes through; help +
                         command-syntax reconcile still pass.
                      8. No new full-suite failures beyond the environment baseline.

Write scope:          lib/ledger-dispatch.sh
                      bin/ww
                      system/config/command-syntax.yaml
                      tests/test-ledger-cli.bats

Tests required:       bats tests/test-ledger-cli.bats
                      bats tests/test-ledger-config.bats
                      bats tests/test-smoke.bats
                      bats tests/
                      Manual: ww ledger new tmp ; ww ledger accounts ; ww ledger (bare)

Rollback:             git checkout bin/ww system/config/command-syntax.yaml tests/test-ledger-cli.bats
                      git rm lib/ledger-dispatch.sh

Fragility:            SERIALIZED: bin/ww — this branch is the sole writer.
                      NOT touching lib/shell-integration.sh (the `l` function rewire is LED-010).

Risk notes:           (Orchestrator) BEHAVIOR CHANGE: `ww ledger add` no longer creates a ledger
                      (it now passes through to hledger's interactive `add`). Tests must not call
                      bare `ww ledger add` expecting creation — use `new`. Passthrough resolves
                      the default via $LEDGER_F first (0 extra processes). bin/ww already sources
                      lib/ledger-config.sh (LED-005); add lib/ledger-dispatch.sh alongside it.
                      (Builder) fill in pre-flight before touching bin/ww.

Status:               pending
Taskwarrior:          wwdev task <id> (<uuid>) status:pending
