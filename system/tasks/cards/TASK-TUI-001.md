## TASK-TUI-001: Integrate taskwarrior-tui as ww tui command

Goal:                 Wrap kdheepak/taskwarrior-tui as a first-class ww command with
                      profile isolation, install helper, and attribution.

Acceptance criteria:  1. ww tui launches taskwarrior-tui with --taskrc and --taskdata
                         flags set from active profile env vars.
                      2. ww tui install checks for binary, installs via brew (fallback: cargo).
                      3. ww tui help shows usage and full attribution (name, handle, URL, license).
                      4. Attribution line printed to scroll buffer before exec so it persists
                         above the restored prompt after TUI exits (alt-screen).
                      5. tui domain added to CSSOT (command-syntax.yaml).
                      6. show_usage() updated with tui in Commands list and TUI Commands section.
                      7. docs/taskwarrior-extensions/tui-integration.md written with assessment,
                         decision rationale, profile config patterns, future options.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/docs/taskwarrior-extensions/tui-integration.md  (new)

Tests required:       Manual: ww tui help; ww tui install; ww tui (with active profile)

Rollback:             git checkout /Users/mp/ww/bin/ww
                      git checkout /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            SERIALIZED: bin/ww

Risk notes:           Zero source modification to upstream binary. Profile isolation is
                      automatic via TASKRC/TASKDATA env vars already exported by ww.
                      Binary accepts --taskrc/--taskdata flags directly.
                      No new lib dependencies. exec replaces shell process cleanly.

Status:               complete

Completion note:      Implemented in uncommitted changes to bin/ww and command-syntax.yaml.
                      docs/taskwarrior-extensions/tui-integration.md written.
                      Pending commit — tui work is in git diff HEAD (not yet staged).
