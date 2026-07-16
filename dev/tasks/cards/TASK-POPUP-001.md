## TASK-POPUP-001: Unified rofi popup launcher — multi-tool quick-capture and browse

Goal:                 Build a single keyboard-activated popup (rofi/dmenu) that provides
                      fast access to all core ww tools via prefix-routed input. Bare text
                      adds to the current list; symbol prefixes route to other tools;
                      slash commands open browse views.

Depends on:           TASK-LIST-001 (multi-list management), TASK-LIST-002 (tags/notes/json)

Design context:       The popup is stateless — each invocation reads current state from ww
                      and exits after one action. Rofi renders in <100ms; all reads are
                      local. The context bar (rofi -mesg) orients the user without typing.

Acceptance criteria:  1. DISPATCHER
                         a. Single script at `scripts/ww-popup.sh`. Detects rofi or dmenu.
                         b. Context bar shows: `<profile> / <list> · ▶ <timer> (duration) · N tasks due`
                         c. Bare text input (no prefix) → add to current list, exit.
                         d. Prefix routing dispatches to the correct handler (see table).
                         e. After a write action, popup exits. After a browse action,
                            popup loops until Esc.

                      2. SYMBOL PREFIXES (write actions — fast capture)
                         a. `.` → TaskWarrior add (`.fix login +frontend due:tomorrow`)
                         b. `>` → timew start (`>coding ledger-refactor`)
                         c. `>>` → timew stop
                         d. `@` → jrnl entry (`@met with design team about rebrand`)
                         e. `$` → hledger transaction (`$50 expenses:coffee assets:cash`)
                         f. `?` → ww find / cross-tool search (`?ledger config`)
                         g. `!` → switch profile (`!work`); bare `!` shows picker
                         h. `#` → filter current list by tag (`#reading`)

                      3. SLASH COMMANDS (browse/status — interactive)
                         a. `/` → status dashboard (profile, timer, list, task count)
                         b. `/lists` → list picker (existing LIST-001 flow)
                         c. `/tasks` → active tasks, select to start/done/modify
                         d. `/j` → recent journal entries
                         e. `/l` → ledger account balances
                         f. `/timew` → today's tracked time
                         g. `/stream` → the board (who/what is punched in)

                      4. CONTEXT BAR
                         a. Reads WARRIOR_PROFILE, queries timew for active interval,
                            reads lists.yaml for current list name, counts urgent tasks.
                         b. Renders in rofi's -mesg area. Fast — must complete in <200ms.
                         c. Graceful when components are missing (no timer = omit, no
                            profile = show "no profile").

                      5. DESKTOP INTEGRATION
                         a. `.desktop` file at `~/.local/share/applications/ww-popup.desktop`
                            launchable from GNOME Activities / Super search.
                         b. Bindable to custom keyboard shortcut via gsettings or DE config.

Write scope:          scripts/ww-popup.sh                        (rewrite/extend existing)
                      ~/.local/share/applications/ww-popup.desktop (created externally)

Tests required:       Manual: invoke popup, test each prefix writes correctly
                      Manual: invoke popup, test each slash command shows correct data
                      Manual: verify context bar renders with/without active timer
                      Manual: verify non-rofi fallback (dmenu) works
                      Manual: verify Esc exits cleanly at every stage

Rollback:             Revert scripts/ww-popup.sh to the lists-only version.
                      The .desktop file is user-local, remove manually if needed.

Fragility:            None. Standalone script, no production code touched.

Risk notes:           (Orchestrator) This script calls into ww CLI and tools. It does
                      NOT modify lib/, bin/ww, or services/ — it is a consumer only.
                      The `$` prefix for ledger: ensure the shell doesn't expand it.
                      The script must be defensive — if timew/task/jrnl/hledger are not
                      installed, those prefixes should show a brief error, not crash.
                      The `>` prefix: rofi passes input as-is, no shell expansion concern.
                      Context bar data collection must be fast (<200ms total). Use
                      background subshells or cached state if needed.
                      Consider phased delivery: dispatcher + bare text + `!` + `/` status
                      as phase 1; remaining prefixes and browse views as follow-up.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
