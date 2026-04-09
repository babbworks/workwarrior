## TASK-EXT-CHECK-001: Integrate 00sapo/taskcheck as ww schedule — auto-scheduler with toggle system

Goal:                 Surface taskcheck as `ww schedule` — an automatic task scheduler
                      that fits tasks into working hours around calendar events, respecting
                      urgency and dependencies. Adds `estimated` and `time_map` UDAs.
                      Includes a toggle system so users can enable/disable auto-scheduling
                      per profile without removing the extension.

Upstream:             https://github.com/00sapo/taskcheck
                      Author: 00sapo · MIT License · Python · Stable (author moved on)
                      pipx install taskcheck

Profile isolation:    Reads TASKRC/TASKDATA. Writes scheduled: field to tasks.
                      Config file (TOML) must be per-profile, not global.

Toggle system design:
                      taskcheck is powerful but opinionated — it modifies task scheduled:
                      fields automatically. Users need a clear on/off switch per profile.

                      ww schedule enable          Write taskcheck config to profile, enable
                      ww schedule disable         Disable without removing config or UDAs
                      ww schedule status          Show enabled/disabled + last run time
                      ww schedule run             Run scheduler against active profile
                      ww schedule run --dry-run   Preview scheduling without writing
                      ww schedule config          Open/edit profile's taskcheck TOML config
                      ww schedule install         Install taskcheck via pipx
                      ww schedule help            Usage + attribution

                      Toggle implementation:
                        profiles/<name>/.config/taskcheck/enabled  (presence = enabled)
                        profiles/<name>/.config/taskcheck/taskcheck.toml  (config)
                      ww schedule run checks for enabled file before executing.

Command fit with current approaches:
                      - `estimated` UDA: fits ww's UDA system — add to service-uda-registry.yaml
                        under extensions: section (same pattern as TWDensity)
                      - `time_map` UDA: same
                      - scheduled: is a native TW field — no UDA needed
                      - taskcheck config TOML lives in profiles/<n>/.config/taskcheck/
                        (same pattern as bugwarrior config)
                      - ww schedule run can be called from ww routines run if cron is active

Attribution:
                      Powered by taskcheck · 00sapo
                      https://github.com/00sapo/taskcheck · MIT License

Acceptance criteria:  1. ww schedule enable/disable toggle works per profile
                      2. ww schedule run passes correct TASKRC/TASKDATA/config path
                      3. ww schedule run --dry-run passes --dry-run to taskcheck
                      4. estimated + time_map UDAs added to service-uda-registry.yaml
                      5. ww profile uda list shows [extension:taskcheck] on these UDAs
                      6. docs/taskwarrior-extensions/taskcheck-integration.md written

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/system/config/service-uda-registry.yaml
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/docs/taskwarrior-extensions/taskcheck-integration.md

Fragility:            SERIALIZED: bin/ww

Status:               pending
