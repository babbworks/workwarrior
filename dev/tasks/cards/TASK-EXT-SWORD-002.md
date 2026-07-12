## TASK-EXT-SWORD-002: Implement Sword weapon — task splitting

Goal:                 Sword splits a single task into N subtasks with sequential
                      dependencies. The original task description becomes the parent
                      context. Each subtask gets a due date offset.

CLI syntax:
  ww sword <task-id> -p <parts> [--interval <dur>] [--prefix <text>]
  ww sword 5 -p 3                    Split task 5 into 3 parts
  ww sword 5 -p 4 --interval 2d     Split with 2-day intervals
  ww sword install                   (no external binary needed — ww-native)
  ww sword help                      Show help

Implementation:       Pure bash in bin/ww cmd_sword(). No external binary.
                      Creates subtasks via `task add` with project matching parent,
                      due dates offset by interval, and depends: on previous subtask.

Browser UI:           Sword button in weapons bar opens section-sword with a form:
                      task ID, number of parts, interval. Shows created subtasks.

Acceptance criteria:  1. ww sword 5 -p 3 creates 3 subtasks with descriptions
                         "Part 1 of: <original>", "Part 2 of: <original>", etc.
                      2. Each subtask has project matching the original task
                      3. Due dates are offset by --interval (default: 1d)
                      4. Subtask N depends on subtask N-1
                      5. Browser sword panel works with form submission
                      6. ww sword help shows usage

Write scope:          bin/ww (cmd_sword)
                      services/browser/static/index.html (section-sword)
                      services/browser/static/app.js (sword form handler)

Fragility:            SERIALIZED: bin/ww (additive only)

Status:               complete

Completion note:      cmd_sword() implemented in bin/ww. Creates N subtasks with
                      sequential dependencies and due date offsets. Browser UI has
                      sword section with form. Tested: ww sword 3 -p 3 --interval 2d
                      creates 3 subtasks with correct deps and dues.
