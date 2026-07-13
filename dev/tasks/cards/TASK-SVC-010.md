## TASK-SVC-010: ww projects CLI — promote browser project discovery to CLI command

Goal:                 `ww projects [list|show|describe]` surfaces the same project data the browser Projects section displays: auto-discovered TW projects merged with `config/projects.yaml` descriptions.

Acceptance criteria:  - [ ] `ww projects` / `ww projects list` prints all projects for active profile with task counts
                      - [ ] `ww projects show <name>` prints project detail: description, task count, tags
                      - [ ] `ww projects describe <name> <text>` writes description to `config/projects.yaml`
                      - [ ] `ww projects help` shows usage
                      - [ ] `services/projects/projects.sh` promoted from stub
                      - [ ] bin/ww routes `projects` / `project` to the service

Write scope:          - `services/projects/projects.sh` (implement)
                      - `bin/ww` (add `projects)` / `project)` cases)

Notes:                priority: M · area: cli · created: 2026-04-27

Status:               complete — 2026-07-13 (verified by execution: `ww projects list|show|describe|help` all pass; gates on active profile)
