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

Limitations to investigate before implementation:
                      - Does taskgun accept free-text project names with spaces?
                        (e.g. "Design Patterns" vs design-patterns)
                      - Does --skip accept arbitrary day names or only weekend/bedtime?
                      - Does it write to TASKRC-specified data or hardcoded ~/.task?
                      - What happens if TASKDATA points to a non-default location?
                      - Does it support --dry-run before writing tasks?
                      These must be confirmed by reading taskgun source before implementation.

Acceptance criteria:  1. ww gun passes TASKRC/TASKDATA env to taskgun correctly
                      2. ww gun install handles cargo/brew detection
                      3. ww gun help shows usage and attribution
                      4. Limitations above documented in integration doc
                      5. docs/taskwarrior-extensions/taskgun-integration.md written

Write scope:          /Users/mp/ww/bin/ww
                      /Users/mp/ww/system/config/command-syntax.yaml
                      /Users/mp/ww/docs/taskwarrior-extensions/taskgun-integration.md

Fragility:            SERIALIZED: bin/ww

Status:               pending — requires limitations investigation first (see above)
