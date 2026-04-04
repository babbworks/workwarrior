## TASK-CLI-002: Standardize global flag model

Goal:                 Implement consistent handling of `--profile`, `--global`, `--json`, `--compact`, `--verbose`, and `--help`.

Acceptance criteria:  1. Scope resolution follows approved policy (active/last profile default with override).
                      2. Flag behavior is consistent across core domains.
                      3. Invalid flag combinations return clear errors.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/lib/core-utils.sh
                      /Users/mp/ww/lib/shell-integration.sh
                      /Users/mp/ww/system/config/command-syntax.yaml

Tests required:       bats /Users/mp/ww/tests/test-shell-functions.bats
                      bats /Users/mp/ww/tests/test-scripts-integration.sh
                      bats /Users/mp/ww/tests/test-service-discovery.bats

Rollback:             git checkout /Users/mp/ww/bin/ww /Users/mp/ww/lib/core-utils.sh /Users/mp/ww/lib/shell-integration.sh /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            SERIALIZED: /Users/mp/ww/bin/ww /Users/mp/ww/lib/shell-integration.sh

Risk notes:           Existing behavior affected: command parsing and profile targeting across services.
                      Tests currently covering write scope: shell function and integration test suites.
                      Rollback verification: parser logic fully restored by file revert.
                      Implementation evidence (2026-04-04): added global flag parser and invalid combination
                      guards in bin/ww; added scope fallback resolution (explicit override -> active env ->
                      last profile file); added WW output-mode propagation and list/read JSON/compact handling
                      for profile/service/journal/ledger list flows.
                      Added persistent last-profile state helpers in lib/core-utils.sh and activation writes in
                      lib/shell-integration.sh.
                      Verification (2026-04-04): bats /Users/mp/ww/tests/test-shell-functions.bats (pass),
                      bats /Users/mp/ww/tests/test-scripts-integration.sh (pass),
                      bats /Users/mp/ww/tests/test-service-discovery.bats (pass),
                      manual checks: ww --json service list, ww --compact profile list,
                      ww --profile work journal list, ww --profile work --json journal list,
                      ww --json --compact service list (expected error).

Status:               complete
