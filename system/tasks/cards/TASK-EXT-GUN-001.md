## TASK-EXT-GUN-001: Integrate hamzamohdzubair/taskgun as ww gun — bulk task series generator

Goal:                 Surface taskgun as `ww gun` for generating deadline-spaced task
                      series. Taskgun creates sequential tasks with automatic due dates
                      from a single command — book chapters, lecture series, practice
                      sets. Pairs directly with ww's urgency surface.

Upstream:             https://github.com/hamzamohdzubair/taskgun
                      Author: hamzamohdzubair · Rust · Active Apr 2026
                      cargo install taskgun (or brew if available)

Profile isolation:    Writes tasks via active TASKRC/TASKDATA. Per-profile by default.

Proposed command syntax:
                      ww gun create <project> -p <parts> -u <unit> --offset <start> --interval <step>
                      ww gun create "ML Course" -p 10 -u Lecture --offset 2d --interval 1d
                      ww gun create CLRS -p 12 -u Chapter --offset 7d --interval 7d --skip weekend
                      ww gun install            Install taskgun binary
                      ww gun help               Usage + attribution

                      Note: ww gun is a thin passthrough to taskgun — all taskgun flags
                      pass through unchanged. ww adds profile env and attribution only.

Limitations confirmed (system/audits/gun-limitations.md):
                      - TASKRC/TASKDATA: fully supported via env inheritance
                      - Project names with spaces: SPLIT by TaskWarrior — use underscores
                        e.g. Design_Patterns not "Design Patterns"
                      - --skip: built-ins (weekend/bedtime) + time ranges + day lists
                      - --dry-run: NOT IMPLEMENTED upstream — not in proposed syntax
                      - Non-default TASKDATA: works correctly

Acceptance criteria:  1. ww gun passes TASKRC/TASKDATA env to taskgun correctly
                      2. ww gun install handles cargo/brew detection
                      3. ww gun help shows usage, space limitation warning, attribution
                      4. docs/taskwarrior-extensions/taskgun-integration.md written

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/docs/taskwarrior-extensions/taskgun-integration.md

Fragility:            SERIALIZED: bin/ww

Status:               complete

Completion note:      Implemented in commit 27d019d. cmd_gun() in bin/ww,
                      gun domain in CSSOT, taskgun-integration.md with space
                      limitation docs. Zero source modification. 19 pre-existing
                      failures, zero regressions.
