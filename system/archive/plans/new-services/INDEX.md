# New Services — Concept Index

Pre-task-card conceptual write-ups for 12 proposed Workwarrior services.
Status: draft concepts — not yet in task pipeline.

Each file here must be reviewed and approved before a task card is created.
Once approved, the Orchestrator creates a task card in `system/tasks/cards/` and
adds the task to `system/TASKS.md`.

---

| Service | File | One-line purpose |
|---|---|---|
| Daily | [daily.md](daily.md) | Aggregate daily task, time, and journal data into structured standups and reviews |
| Reports | [reports.md](reports.md) | Generate structured output reports across all profile data sources |
| Decisions | [decisions.md](decisions.md) | Log, retrieve, and track decisions with context and rationale |
| Tests | [tests.md](tests.md) | Run and track test suites within a profile/project context |
| Dumps | [dumps.md](dumps.md) | Full and partial profile data snapshots for backup, migration, and inspection |
| Plans | [plans.md](plans.md) | Store and retrieve structured planning documents tied to a profile |
| Bases | [bases.md](bases.md) | Profile-scoped knowledge base — **parked, research required** |
| Sites | [sites.md](sites.md) | Site generator from profile content — **parked, research required** |
| Agents | [agents.md](agents.md) | AI agent dispatch and tracking — **parked, research required** |
| Systems | [systems.md](systems.md) | System/environment config management — **parked, research required** |
| Worlds | [worlds.md](worlds.md) | Meta-workspaces grouping profiles — **parked, research required** |
| Definitions | [definitions.md](definitions.md) | Profile-scoped glossary for terms, abbreviations, and concepts |
| Projects | [projects.md](projects.md) | External project management integration — UDA ↔ field sync, GitHub Projects V2, multi-backend lifecycle |

---

## Review Process

1. Each concept reviewed and refined with user
2. Approved concepts promoted to task cards (`system/tasks/cards/TASK-SVC-XXX.md`)
3. Task cards satisfy Gate A before any Builder is dispatched
4. Services land in `services/<category>/` following full handoff sequence

## Isolation Note

These files are write-safe during any active Phase 2 work — they touch no production
files, no lib/, no bin/ww, and no serialized files.
