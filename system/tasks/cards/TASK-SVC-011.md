---
id: TASK-SVC-011
title: ww warrior CLI — promote browser warrior stats to CLI command
status: pending
priority: M
area: cli
created: 2026-04-27
---

## Goal

`ww warrior [summary|hooks|report]` exposes the cross-profile task aggregation that the browser Warrior section displays: per-profile task counts, urgency leaders, total across all profiles.

## Acceptance Criteria

- [ ] `ww warrior` / `ww warrior summary` prints aggregate table: profile | pending | active | top task
- [ ] `ww warrior hooks` lists active on-modify/on-add hooks with paths for active profile
- [ ] `ww warrior report <name>` thin wrapper over `task report <name>` with ww env
- [ ] `ww warrior help` shows usage
- [ ] `services/warrior/warrior.sh` promoted from stub
- [ ] bin/ww routes `warrior` / `w` to the service

## Write Scope

- `services/warrior/warrior.sh` (implement)
- `bin/ww` (add `warrior)` case)
