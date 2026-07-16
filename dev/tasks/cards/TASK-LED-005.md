## TASK-LED-005: Repoint runtime ledger CLI consumers at lib/ledger-config.sh

Goal:                 Replace the hand-rolled awk/grep/python YAML parsing in the runtime
                      ledger CLI paths with calls to the lib/ledger-config.sh module built in
                      TASK-LED-004, closing the read-side schema fork (F2), the divergent
                      default-ledger resolvers (F4), and the `resource create ledger` path:
                      writer anomaly (F2 write-side). Creation-time consumers (profile-manager,
                      the SERIALIZED shell-integration alias generator) are OUT OF SCOPE — they
                      operate on not-yet-active profile paths and already emit valid string
                      form; they get their own card if needed.

Acceptance criteria:  1. bin/ww sources lib/ledger-config.sh at startup (alongside the other
                         lib sources near lines 27-44).
                      2. cmd_ledger list uses ledger_cfg_names (respecting hidden exclusion)
                         instead of the inline awk parse; --json and --compact output modes
                         preserved byte-compatibly for string-form configs.
                      3. (Deferred to TASK-LED-006) cmd_ledger task's default-file resolver
                         already reads the `default` key and handles the map form, so it is
                         the least-broken reader; its repoint is bundled with the F1 hledger
                         passthrough fix in LED-006.
                      4. `ww resource create ledger <name>` registers the new ledger via
                         ledger_cfg_add — the resulting ledgers.yaml entry uses journal:
                         (or inline string), never path:. (F2 write anomaly fixed.)
                      5. services/questions/handlers/ledger_handler.sh resolves the default
                         ledger via ledger_cfg_default_path (or `ww` equivalent) instead of
                         `list(ledgers.values())[0]`. (F4 fixed.)
                      6. New: `ww resource create ledger foo` on a fixture profile produces a
                         ledgers.yaml that `grep -q 'path:'` does NOT match and
                         `ledger_cfg_resolve foo` resolves correctly.
                      7. `ww ledger list` excludes a hidden:true ledger; `ww ledger list
                         --include-hidden`-equivalent behavior documented if not added here.
                      8. tests/test-ledger-cli.bats passes (e2e via bin/ww).
                      9. tests/test-ledger-config.bats still 24/24; smoke 12/12; full suite
                         adds no new failures beyond the environment baseline.

Write scope:          bin/ww
                      services/questions/handlers/ledger_handler.sh
                      tests/test-ledger-cli.bats

Tests required:       bats tests/test-ledger-cli.bats
                      bats tests/test-ledger-config.bats
                      bats tests/test-smoke.bats
                      bats tests/test-service-discovery.bats
                      bats tests/            (bin/ww + services change)
                      Manual: ww ledger list ; ww resource create ledger tmp ; grep the yaml

Rollback:             git checkout bin/ww services/questions/handlers/ledger_handler.sh
                      git rm tests/test-ledger-cli.bats

Fragility:            SERIALIZED: bin/ww — confirm no parallel active task touches it (this
                      branch is the sole writer). NOT touching lib/shell-integration.sh.
                      Deferred to follow-on cards: configure-ledgers.sh wizard consolidation,
                      shell-integration alias regen for map/hidden entries, build-ledger-
                      inventory F3 (reads jrnl.yaml), cmd_hledger_passthrough F1 (TASK-LED-006).

Risk notes:           (Orchestrator) All runtime consumers already key off
                      $WORKWARRIOR_BASE/ledgers.yaml — the exact file the module targets — so
                      no path-override is required. cmd_ledger list currently prints names via
                      an awk match that happens to also list map-form keys; the behavior change
                      is hidden-exclusion, which is the point. Preserve JSON/compact modes.
                      (Builder) fill in pre-flight before touching bin/ww.

Resolution:
  Implemented on agent/builder/ledger-schema; PORTED onto the dev/ layout and MERGED by
  TASK-LED-012 (2026-07-13). Code is live: lib/ledger-config.sh + lib/ledger-dispatch.sh.
  Ledger + alias suites 92/92; check-regression.sh clean.
  NOT self-approved: no Verifier sign-off exists for LED-004..011. One pass over the
  merged result is owed.

Status:               complete
Taskwarrior:          wwdev task <id> (<uuid>) status:pending
