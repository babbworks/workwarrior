## TASK-SHELL-001: Add set -euo pipefail to all lib/ and services/custom/ scripts

Goal:                 bin/ww has only `set -e`. All 24 lib/ files and all 6 services/custom/ scripts
                      are missing `-u` and `-o pipefail`, allowing unset variables and broken pipes
                      to fail silently. This underpins every fragility finding in the sync engine.

Acceptance criteria:  1. Every file in lib/ and services/custom/ has `set -euo pipefail` as second line.
                      2. bin/ww updated from `set -e` to `set -euo pipefail`.
                      3. Full BATS suite passes after the change (set -u may expose latent bugs).
                      4. Any latent bugs exposed by -u are fixed in the same task.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/lib/*.sh  (all 24 files)
                      /Users/mp/ww/services/custom/*.sh  (all 6 files)

Tests required:       bats tests/
                      Manual: ww help; ww profile list; i help

Rollback:             git checkout /Users/mp/ww/bin/ww $(git ls-files /Users/mp/ww/lib/*.sh) $(git ls-files /Users/mp/ww/services/custom/*.sh)

Fragility:            SERIALIZED: bin/ww
                      HIGH FRAGILITY context: lib/github-*.sh, lib/sync-*.sh — adding -u may expose
                        undefined variable references that currently succeed silently.

Risk notes:           Mechanical change but -u flag may expose previously hidden bugs that need fixing.
                      Run bats tests/ immediately after each file group and fix failures before proceeding.
                      Explorer B: all 24 lib/ files and 6 services/custom/ scripts missing -u and pipefail.

Status:               pending
