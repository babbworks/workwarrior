## TASK-ISSUES-001: Improve `ww issues uda` CLI and uda-manager service

Goal:                 `ww issues uda` currently passes through directly to bugwarrior's own `uda`
                      subcommand with no ww-native UX. `uda-manager.sh` is a functional CRUD tool
                      but has no service-install flow, no pre-defined service groups, and a dated
                      numbered-menu UX. This task brings both up to the standard of other ww services.

Acceptance criteria:  1. `ww issues uda` becomes a first-class ww command with subcommands:
                         - `ww issues uda list`          — formatted UDA list grouped by source service
                         - `ww issues uda install`       — idempotent: runs `bugwarrior uda`, appends
                                                           only missing UDA lines to .taskrc
                         - `ww issues uda group <name>`  — creates a named UDA group in .uda-groups
                                                           covering all UDAs for that service
                         - `ww issues uda help`          — service-standard help block
                      2. `ww issues uda install` is idempotent (safe to run on every pull).
                      3. `uda-manager.sh` interactive flow:
                         - Warns before delete/rename of service-managed UDAs (github*, gitlab*, etc.)
                         - "Install service UDAs" option calls `bugwarrior uda` and appends missing ones
                         - Shows type + label inline in the UDA list, not just name
                      4. Pre-defined group shortcuts: `ww issues uda group github` creates the
                         standard 15-field github group without requiring manual field selection.
                      5. Tests: bats tests covering `ww issues uda install` idempotency and
                         service UDA classification.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/services/profile/subservices/uda-manager.sh
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/tests/test-service-discovery.bats (or new test file)

Tests required:       bats tests/
                      Manual: ww issues uda list / install / group github

Rollback:             git checkout /Users/mp/ww/bin/ww
                      git checkout /Users/mp/ww/services/profile/subservices/uda-manager.sh

Fragility:            SERIALIZED: bin/ww (one writer at a time)

Risk notes:           bin/ww is serialized — do not run in parallel with any other bin/ww work.
                      `ww issues uda install` must not duplicate existing UDA lines on repeat runs.
                      Service UDA classification (github*, gitlab*, etc.) must match the classify_uda()
                      function already added to uda-manager.sh in this session.

Status:               pending
