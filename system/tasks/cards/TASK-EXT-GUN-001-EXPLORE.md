## TASK-EXT-GUN-001-EXPLORE: Explorer — taskgun limitations investigation

Goal:                 Read-only audit of taskgun source to answer the five limitations
                      questions in TASK-EXT-GUN-001 before any Builder is dispatched.

Read targets:         https://github.com/hamzamohdzubair/taskgun (clone or browse source)
                      Focus: src/main.rs or equivalent entry point
                      Look for: TASKRC/TASKDATA env var handling, free-text project name
                      handling, --skip flag accepted values, --dry-run support.

Questions to answer:  1. Does taskgun read TASKRC/TASKDATA env vars, or does it
                         hardcode ~/.task and ~/.taskrc?
                      2. Do project names with spaces work? (e.g. "Design Patterns")
                         Or must they be single tokens?
                      3. Does --skip accept arbitrary values or only weekend/bedtime?
                      4. Is there a --dry-run flag or equivalent preview mode?
                      5. What happens if TASKDATA points to a non-default location —
                         does it pass through to the task CLI or bypass it?

Write scope:          system/audits/gun-limitations.md  (new file, output only)

Tests required:       N/A — read-only

Fragility:            None — read-only

Status:               pending
Taskwarrior:          wwdev task 19 (78fb7b76-40fd-41dc-90ac-d52b643423ac) status:pending
