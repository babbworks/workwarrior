## TASK-LED-006: Fix ww hledger passthrough to use LEDGER_F (F1)

Goal:                 cmd_hledger_passthrough hard-codes $WORKWARRIOR_BASE/ledgers/default.journal
                      — a file that never exists (the default ledger is named <profile>.journal).
                      So `ww hledger <cmd>` silently drops to bare hledger with no -f and never
                      operates on the profile's ledger. Fix it to use the exported LEDGER_F
                      (the canonical env var, which nothing currently consumes), falling back to
                      ledger_cfg_default_path.

Acceptance criteria:  1. `ww hledger <cmd>` (no -f) runs `hledger -f "$LEDGER_F" <cmd>` when
                         LEDGER_F is set and the file exists.
                      2. When LEDGER_F is unset, it falls back to ledger_cfg_default_path
                         (the schema-owner resolver), then to bare hledger if neither resolves.
                      3. An explicit -f/--file in the args still bypasses the default (unchanged).
                      4. The hard-coded "ledgers/default.journal" string is gone from bin/ww.
                      5. tests/test-ledger-cli.bats gains e2e coverage: `ww hledger files`
                         reports the LEDGER_F path (primary), and reports the
                         ledger_cfg_default_path when LEDGER_F is unset (fallback).
                      6. No new full-suite failures beyond the environment baseline.

Write scope:          bin/ww
                      tests/test-ledger-cli.bats

Tests required:       bats tests/test-ledger-cli.bats
                      bats tests/test-smoke.bats
                      bats tests/            (bin/ww change)
                      Manual: with a profile active, ww hledger files ; ww hledger bal

Rollback:             git checkout bin/ww tests/test-ledger-cli.bats

Fragility:            SERIALIZED: bin/ww — this branch is the sole writer.

Risk notes:           (Orchestrator) LEDGER_F is derived at session init as
                      $ledger_dir/$prof_name.journal (bin/ww ~line 1077) and exported, but is
                      referenced by nothing today. bin/ww already sources lib/ledger-config.sh
                      (LED-005), so ledger_cfg_default_path is available as the fallback.
                      DEFERRED (not this card): cmd_ledger task's default-file resolver already
                      reads the reserved 'default' key and handles the map form, so it is not
                      broken; consolidating it onto ledger_cfg_default_path is a pure cleanup
                      whose e2e test is gated by _ww_verify_instance (needs TASKRC + a live
                      task fixture). Tracked as a follow-on cleanup, not bundled here.

Status:               pending
Taskwarrior:          wwdev task <id> (<uuid>) status:pending
