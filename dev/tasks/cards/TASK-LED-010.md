## TASK-LED-010: Wire `l` onto ledger-dispatch + `-L` named-ledger selector

Goal:                 Make the `l` shell function share the LED-009 dispatcher, and add the
                      `-L`/`--ledger` selector so any ledger (not just the default) is reachable
                      for passthrough — the ergonomic half of the command model
                      (decisions.md 2026-07-12).

Acceptance criteria:  1. ledger_dispatch accepts an optional leading `-L <name>` / `--ledger <name>`
                         (and `--ledger=<name>`) selector, passthrough-only: management verbs
                         ignore it. Selector resolves via ledger_cfg_resolve; unknown name or
                         no active profile → clean error.
                      2. `ww ledger -L <name> <hledger-args>` runs hledger against that ledger;
                         explicit -f still bypasses.
                      3. The `l` shell function routes through ledger_dispatch (reserved words +
                         passthrough + selector + bare→balance), preserving: scope resolution
                         (active/profile/global), `l custom`, and the Stream write-telemetry
                         emit. Global scope + `-L` → clean error.
                      4. shell-integration.sh sources lib/ledger-config.sh and
                         lib/ledger-dispatch.sh at load (alongside core-utils.sh).
                      5. Module single-python optimization: drop the separate PyYAML guard so a
                         named resolve fires one python3, not two (rely on _ledger_cfg_py's
                         internal ImportError path).
                      6. tests: `ww ledger -L <name>` e2e; a sourced-`l` test (passthrough +
                         `-L`); test-ledger-config still 24/24.
                      7. No new full-suite failures beyond the environment baseline.

Write scope:          lib/ledger-dispatch.sh
                      lib/ledger-config.sh
                      lib/shell-integration.sh
                      tests/test-ledger-cli.bats
                      tests/test-ledger-l-function.bats  (new)

Tests required:       bats tests/test-ledger-cli.bats
                      bats tests/test-ledger-l-function.bats
                      bats tests/test-ledger-config.bats
                      bats tests/test-shell-functions.bats
                      bats tests/

Rollback:             git checkout lib/ledger-dispatch.sh lib/ledger-config.sh lib/shell-integration.sh tests/
                      git rm tests/test-ledger-l-function.bats

Fragility:            SERIALIZED: lib/shell-integration.sh — confirm no parallel active task
                      touches it (this branch is the sole writer). Profile activation depends
                      on this file; keep the `l` rewire additive and scope-preserving.

Risk notes:           (Orchestrator) `l` runs in-process in the interactive shell; it must NOT
                      shell out to bin/ww. For active scope, reuse the exported $LEDGER_F
                      (0 extra processes); for --profile/global overrides, set WORKWARRIOR_BASE
                      to the scoped base and clear LEDGER_F so the module resolves against the
                      right profile. Write-telemetry must read the command after stripping a
                      leading -L/--ledger.
                      (Builder) fill in pre-flight before touching shell-integration.sh.

Status:               pending
Taskwarrior:          wwdev task <id> (<uuid>) status:pending
