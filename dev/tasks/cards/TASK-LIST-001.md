## TASK-LIST-001: List service CLI — multi-list management + orientation

Goal:                 Add multi-list management subcommands and orientation headers to the
                      List CLI so users can create, switch between, and identify multiple
                      lists per profile without leaving the terminal.

Depends on:           — (independent; no blockers)

Acceptance criteria:  1. MULTI-LIST MANAGEMENT
                         a. `lists` (bare) prints all lists for the active profile, numbered,
                            with the current/default list indicated (e.g. `*`), then awaits
                            numeric or name input. Enter with no input returns to prompt.
                            In non-TTY (pipe/agent) context: prints the list and exits 0
                            without blocking on read.
                         b. `list new <name>` creates a new named list (touches file in
                            profile's list/ dir + adds entry to lists.yaml). Rejects
                            duplicates with exit 1.
                         c. `list which` prints `<profile-name> / <list-name>` and exits.
                         d. `list switch <name>` changes the default list (updates
                            lists.yaml `default:` value). Errors if name doesn't exist.
                         e. `list switch` (bare, no arg) shows the same numbered picker
                            as `lists` and switches on selection.

                      2. ORIENTATION
                         a. `list` (bare, show items) prints a header line:
                            `<profile-name> / <list-name>` before the item listing.
                         b. Header is suppressed in `--quiet` mode.

                      3. ROUTING
                         a. `ww list <subcommand>` and `ww lists` passthrough routes work
                            for all new subcommands via cmd_list_passthrough.
                         b. Shell function `list` and `lists` both work when profile active.
                         c. `--global` and `--profile <name>` scope selectors work for
                            all new subcommands.

Write scope:          tools/list/list.py                         (extend with subcommands)
                      lib/shell-integration.sh                   (list + lists functions)
                      bin/ww                                     (cmd_list_passthrough)
                      dev/tests/test-list-service.bats           (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-list-service.bats
                      bats dev/tests/
                      Manual: create list, switch, verify lists.yaml updated
                      Manual: non-TTY `lists` piped to cat — must not hang

Rollback:             git checkout tools/list/list.py lib/shell-integration.sh bin/ww
                      git rm dev/tests/test-list-service.bats

Fragility:            SERIALIZED: bin/ww — confirm no parallel task touches dispatcher
                      SERIALIZED: lib/shell-integration.sh — confirm no parallel task

Risk notes:           (Orchestrator) The `lists` interactive picker MUST detect non-TTY
                      and degrade gracefully (print + exit, no blocking read).
                      lists.yaml format is simple (`lists:\n  default: <name>`). Extending
                      it to track all list names is acceptable but must remain valid YAML.
                      The existing `-l <name>` flag in list.py already supports named lists;
                      the new subcommands build on this, they do not replace it.
                      Existing list behavior (add/finish/edit/remove/grep/done) must be
                      UNCHANGED — this card only ADDS, never modifies item-level ops.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
