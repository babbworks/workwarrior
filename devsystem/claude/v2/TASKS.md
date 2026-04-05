# TASKS.md — Workwarrior Canonical Task Board

**Summary index only. Each task's source of truth is its card in `tasks/cards/TASK-XXX.md`.**
**Orchestrator is the only agent that updates status fields.**
`pending/` is archive-only. Nothing new is written there.

Last updated: 2026-04-04
Current phase: Phase 1 — Foundation

---

## Active Tasks

| ID | Status | Goal |
|---|---|---|
| [TASK-1.1](tasks/cards/TASK-1.1.md) | pending | Deploy root CLAUDE.md to project |
| [TASK-1.2](tasks/cards/TASK-1.2.md) | pending | Deploy services/CLAUDE.md to project |
| [TASK-1.3a](tasks/cards/TASK-1.3a.md) | pending | Explorer A — docs/status drift audit |
| [TASK-1.3b](tasks/cards/TASK-1.3b.md) | pending | Explorer B — code/test reality audit |
| [TASK-1.4](tasks/cards/TASK-1.4.md) | pending | Build canonical TASKS.md at project root |
| [TASK-1.5](tasks/cards/TASK-1.5.md) | pending | Artifact cleanup (.gitignore + untrack) |

---

## Completed Tasks

*None yet. Evidence-backed completions recorded here after TASK-1.4 reconciliation.*

---

## Deferred Tasks

*Populated from Explorer A + B outputs during TASK-1.4.*

---

## Fragility Register (interim)

Full policy: `fragility-register.md`

| File(s) | Classification |
|---|---|
| `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh` | HIGH FRAGILITY |
| `bin/ww`, `lib/shell-integration.sh` | SERIALIZED |

---

## Phase Boundary Rules

**Phase 1 exit:** all items in `config/phase1-checklist.txt` must be true.
Run `bin/wwctl verify-phase1` for automated check.

**Phase 2 prerequisites:** `lib/CLAUDE.md` and `tests/CLAUDE.md` must exist before any lib/ Builder task is dispatched.
