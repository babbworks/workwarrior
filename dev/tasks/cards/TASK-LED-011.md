## TASK-LED-011: Regenerate l-<profile>-<ledger> aliases through the module

Goal:                 The per-profile ledger aliases (`l-<profile>`, `l-<profile>-<ledger>`) are
                      generated in create_profile_aliases with an `IFS=:` parser that cannot
                      read the map form and bakes raw `hledger -f <path>` (bypassing the `l`
                      dispatch + Stream telemetry). Regenerate them through the schema owner so
                      map-form ledgers work and the alias set is correct.

Acceptance criteria:  1. create_profile_aliases enumerates ledgers via the module
                         (ledger_cfg_names --include-hidden + ledger_cfg_resolve) instead of the
                         IFS=: parse of ledgers.yaml.
                      2. `l-<profile>` maps to the default ledger; `l-<profile>-<name>` maps to
                         each named ledger, resolving map-form (journal:) entries correctly.
                      3. remove_profile_aliases still cleans up all `l-<profile>*` aliases.
                      4. A map-form named ledger produces a correct alias (regression test for
                         the old parser).
                      5. No new full-suite failures beyond the environment baseline.

Write scope:          lib/shell-integration.sh
                      tests/test-alias-creation.bats

Tests required:       bats tests/test-alias-creation.bats
                      bats tests/test-shell-functions.bats
                      bats tests/

Rollback:             git checkout lib/shell-integration.sh tests/test-alias-creation.bats

Fragility:            SERIALIZED: lib/shell-integration.sh — sole writer on this branch.

Risk notes:           (Orchestrator) create_profile_aliases runs at profile-creation on the
                      profile's own ledgers.yaml (PROFILES_DIR/<profile>), which is not the
                      active WORKWARRIOR_BASE. Resolve names with WORKWARRIOR_BASE set to the
                      profile dir per-call (as build-ledger-inventory does), not the active base.
                      (Builder) fill in pre-flight before touching shell-integration.sh.

Resolution:
  Implemented on agent/builder/ledger-schema; PORTED onto the dev/ layout and MERGED by
  TASK-LED-012 (2026-07-13). Code is live: lib/ledger-config.sh + lib/ledger-dispatch.sh.
  Ledger + alias suites 92/92; check-regression.sh clean.
  NOT self-approved: no Verifier sign-off exists for LED-004..011. One pass over the
  merged result is owed.

Status:               complete
Taskwarrior:          wwdev task <id> (<uuid>) status:pending
