## TASK-LED-008: Point ww ledger inventory at ledgers.yaml, not jrnl.yaml (F3)

Goal:                 build-ledger-inventory.sh discovers each profile's ledger files by
                      guessing hard-coded candidate paths and grepping the profile's jrnl.yaml
                      (the JOURNAL config), so ledgers registered only in ledgers.yaml — under
                      non-guessable filenames — are invisible to the inventory. Repoint
                      discovery at the profile's ledgers.yaml via lib/ledger-config.sh.

Acceptance criteria:  1. For each profile with a ledgers.yaml, the script resolves ledger files
                         via ledger_cfg_default_path + ledger_cfg_names --include-hidden +
                         ledger_cfg_resolve (per-profile, by setting WORKWARRIOR_BASE to the
                         profile dir), instead of the hard-coded candidate list and the
                         jrnl.yaml grep.
                      2. A ledger registered only in ledgers.yaml under a filename that does
                         NOT match <profile>.journal is included in the inventory.
                      3. The script no longer reads jrnl.yaml for ledger discovery.
                      4. hledger account/commodity aggregation and the --print / file-write
                         output are unchanged.
                      5. The module is sourced relative to the script's own dir (not WW_BASE),
                         so discovery works regardless of the WW_BASE value.
                      6. tests/test-ledger-cli.bats gains an F3 e2e test; no new full-suite
                         failures beyond the environment baseline.

Write scope:          scripts/build-ledger-inventory.sh
                      tests/test-ledger-cli.bats

Tests required:       bats tests/test-ledger-cli.bats
                      bats tests/test-smoke.bats
                      bats tests/
                      Manual: ww ledger inventory --print

Rollback:             git checkout scripts/build-ledger-inventory.sh tests/test-ledger-cli.bats

Fragility:            None. Standalone script; sourced module is read-only for discovery.

Risk notes:           (Orchestrator) The script runs with set -euo pipefail (executed script,
                      correct). The sourced lib uses return codes, not set -e, so it composes
                      safely; wrap module calls in `|| true` and guard empty results. PyYAML is
                      already a dependency. Preserve the grep fallback for ACCOUNT extraction
                      (separate from ledger discovery).
                      (Builder) fill in pre-flight before touching the script.

Status:               pending
Taskwarrior:          wwdev task <id> (<uuid>) status:pending
