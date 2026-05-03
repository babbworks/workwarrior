---
id: TASK-SVC-010
title: ww projects CLI — promote browser project discovery to CLI command
status: pending
priority: M
area: cli
created: 2026-04-27
---

## Goal

`ww projects [list|show|describe]` surfaces the same project data the browser Projects section displays: auto-discovered TW projects merged with `config/projects.yaml` descriptions.

## Acceptance Criteria

- [ ] `ww projects` / `ww projects list` prints all projects for active profile with task counts
- [ ] `ww projects show <name>` prints project detail: description, task count, tags
- [ ] `ww projects describe <name> <text>` writes description to `config/projects.yaml`
- [ ] `ww projects help` shows usage
- [ ] `services/projects/projects.sh` promoted from stub
- [ ] bin/ww routes `projects` / `project` to the service

## Write Scope

- `services/projects/projects.sh` (implement)
- `bin/ww` (add `projects)` / `project)` cases)
