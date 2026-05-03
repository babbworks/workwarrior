# Service overview: `warrior`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

Expose TaskWarrior-centric workflows that are not quite `ww profile` and not `task` passthrough—aggregated urgency views, warrior-specific reports, or curated hooks—aligned with browser “Warrior” panels.

## Target user

Task-heavy users; browser UI calling structured JSON endpoints (future).

## Command surface (sketch)

- `ww warrior summary` — urgency breakdown by project/tag (read-only).
- `ww warrior hooks status` — list active on-modify / on-add hooks with paths.
- `ww warrior report <name>` — thin wrapper over curated `task` reports with ww defaults.

## Data / integrations

- Reads: `TASKRC`, `TASKDATA`, optional UDAs from `ww profile uda`.
- Writes: none by default; optional hook install behind explicit subcommand.

## Open questions

- Overlap with `ww next`, `ww gun`, and browser `/data/tasks`—clear boundaries.
- Whether `warrior` becomes the home for TaskChampion-related flows (`TASK-TC-001`).
- JSON schema stability for UI consumers.
