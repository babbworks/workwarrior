# Service overview: `diagnostic`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

User- and agent-oriented health checks: quick answers to “is my profile sane?” without running the full test matrix—Timew hook presence, TaskWarrior config warnings, path drift, and optional network probes (GitHub, Ollama) behind explicit flags.

## Target user

Builders during integration; users after migrations or sync incidents.

## Command surface (sketch)

- `ww diagnostic run` — fixed checklist with exit codes mapped to severity (info/warn/blocker).
- `ww diagnostic json` — machine-readable report for CI or `wwctl health`.
- `ww diagnostic topic <name>` — scoped checks (e.g. `sync`, `timew`, `shell`).

## Data / integrations

- Reads: active profile env (`TASKRC`, `TASKDATA`, `TIMEWARRIORDB`), `bin/ww` version, optional `gh` / `timew` / `task`.
- Writes: none; may suggest commands, never mutates profile data by default.

## Open questions

- Merge vs differentiate from `system/scripts/health.sh` and `wwctl health`.
- Policy for network checks (opt-in only vs profile metadata flag).
- Whether diagnostics should emit remediation task IDs referencing `system/TASKS.md`.
