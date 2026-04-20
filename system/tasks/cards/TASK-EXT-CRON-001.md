## TASK-EXT-CRON-001: Integrate allgreed/cron as ww routines — stateful recurring task generator

Goal:                 Surface allgreed/cron as `ww routines` — a stateful recurring task
                      generator that creates TaskWarrior tasks from Python class definitions.
                      Smarter than native TW recurrence: handles interval rollover, auto-tags
                      with +cron, sets until: to the recurrence window.

Upstream:             https://github.com/allgreed/cron
                      Author: allgreed · Python · Active Feb 2026
                      Requires: nix (dev), Python 3 (runtime)

Profile isolation:    Writes tasks via active TASKRC/TASKDATA. Per-profile by default.
                      Routine definitions are profile-specific Python files.

Design decisions (operator-confirmed):
                      1. Routine files are profile-scoped in:
                           profiles/<name>/.config/routines/
                      2. Authoring UX uses template-first flow:
                           ww routines new <name> (opens editor)
                      3. Run trigger is manual:
                           ww routines run [name]
                      4. Scope is per-profile only.
                      5. Nix is not required for ww runtime usage; runtime is Python 3.

Command syntax:
                      ww routines list              List defined routines for active profile
                      ww routines run               Generate tasks from all due routines
                      ww routines run <name>        Run a specific routine
                      ww routines new               Create a new routine definition
                      ww routines edit <name>       Edit a routine definition
                      ww routines status            Show last-run times and next-due
                      ww routines install           Install allgreed/cron runtime
                      ww routines help              Usage + attribution

Attribution:
                      Powered by allgreed/cron · allgreed
                      https://github.com/allgreed/cron

Acceptance criteria:  1. `ww routines` command family exists with list/new/edit/run/status/install/help.
                      2. Routine files are stored in `profiles/<name>/.config/routines/`.
                      3. Routine execution runs with profile `TASKRC`/`TASKDATA` and records run metadata.
                      4. CSSOT updated with `routines` domain syntax and behavior.
                      5. Integration doc written at docs/taskwarrior-extensions/cron-integration.md.
                      6. BATS coverage added for routines list/new/run/status.

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/docs/taskwarrior-extensions/cron-integration.md
                      /Users/mp/ww/tests/test-routines.bats
                      /Users/mp/ww/docs/usage-examples.md
                      /Users/mp/ww/services/README.md

Status:               complete

Completion note:      Implemented `ww routines` as profile-scoped recurring task microservice.
                      Routine definitions and runtime state now live in `.config/routines`.
                      Runtime source installs to `$WW_BASE/tools/extensions/cron` via
                      `ww routines install`, and runs are isolated by active profile env.
