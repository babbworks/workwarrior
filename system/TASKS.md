# TASKS.md — Workwarrior Canonical Task Board

**Summary index only. Each task's source of truth is its card in `tasks/cards/TASK-XXX.md`.**
**Orchestrator is the only agent that updates status fields.**
`pending/` is archive-only. Nothing new is written there.

Last updated: 2026-04-04
Current phase: Phase 1 — Foundation (exit criteria met — see Phase Boundary Rules)

---

## Active Tasks

*None. Phase 1 tasks resolved — see notes below.*

---

## Queued Backlog (Phase 2+)

| ID | Status | Goal |
|---|---|---|
| [TASK-SYS-001](tasks/cards/TASK-SYS-001.md) | complete | Fully activate `/system` as control plane |
| [TASK-SYS-002](tasks/cards/TASK-SYS-002.md) | complete | Pass Phase-1 checks except expected rollout gates |
| [TASK-SYS-003](tasks/cards/TASK-SYS-003.md) | complete | Create command syntax source of truth |
| [TASK-CLI-001](tasks/cards/TASK-CLI-001.md) | complete | Define top-level CLI taxonomy |
| [TASK-CLI-002](tasks/cards/TASK-CLI-002.md) | complete | Standardize global flag model |
| [TASK-CLI-003](tasks/cards/TASK-CLI-003.md) | complete | Standardize help output contract |
| [TASK-CLI-004](tasks/cards/TASK-CLI-004.md) | complete | Add deprecation/compatibility command layer |
| [TASK-SVC-001](tasks/cards/TASK-SVC-001.md) | complete | Implement journal command lifecycle |
| [TASK-SVC-002](tasks/cards/TASK-SVC-002.md) | complete | Implement ledger command lifecycle |
| [TASK-SVC-003](tasks/cards/TASK-SVC-003.md) | complete | Add service discovery/info/help commands |
| [TASK-SVC-004](tasks/cards/TASK-SVC-004.md) | complete | Add profile import/restore workflow |
| [TASK-SVC-005](tasks/cards/TASK-SVC-005.md) | complete | Harden questions service CLI UX |
| [TASK-SVC-006](tasks/cards/TASK-SVC-006.md) | complete | Normalize issues service command contract |
| [TASK-TEST-001](tasks/cards/TASK-TEST-001.md) | complete | Enforce test baseline by change type |
| [TASK-SHELL-001](tasks/cards/TASK-SHELL-001.md) | pending | Add set -euo pipefail to all lib/ and services/ scripts |
| [TASK-SYNC-001](tasks/cards/TASK-SYNC-001.md) | pending | Add test coverage for GitHub sync engine |
| [TASK-SYNC-002](tasks/cards/TASK-SYNC-002.md) | pending | Fix critical state integrity bugs in sync engine |
| [TASK-SYNC-003](tasks/cards/TASK-SYNC-003.md) | pending | Harden sync pre-flight validation and error surfacing |
| [TASK-SYNC-004](tasks/cards/TASK-SYNC-004.md) | pending | Resolve tag sync TODO in sync-pull.sh (Gate E) |
| [TASK-TEST-002](tasks/cards/TASK-TEST-002.md) | pending | Add CI gate for BATS + integration tests |
| [TASK-QUAL-001](tasks/cards/TASK-QUAL-001.md) | pending | Enforce artifact hygiene across repo |
| [TASK-QUAL-002](tasks/cards/TASK-QUAL-002.md) | pending | Automate docs/help parity checks |
| [TASK-QUAL-003](tasks/cards/TASK-QUAL-003.md) | pending | Audit and clean functions/ directory dead code |
| [TASK-UX-001](tasks/cards/TASK-UX-001.md) | pending | Standardize human/compact/json output behavior |
| [TASK-UX-002](tasks/cards/TASK-UX-002.md) | pending | Build command examples library per service |
| [TASK-REL-001](tasks/cards/TASK-REL-001.md) | pending | Operationalize release checklist gate |
| [TASK-REL-002](tasks/cards/TASK-REL-002.md) | pending | Define production-ready CLI milestone criteria |

---

## Dispatch Queue (Phase 2 — active)

| Priority | ID | Goal | Depends On |
|---|---|---|---|
| 1 | [TASK-SHELL-001](tasks/cards/TASK-SHELL-001.md) | set -euo pipefail sweep | none |
| 2 | [TASK-SYNC-002](tasks/cards/TASK-SYNC-002.md) | Fix critical state integrity bugs | none (independent of tests) |
| 3 | [TASK-SYNC-001](tasks/cards/TASK-SYNC-001.md) | Add sync test coverage | SYNC-002 preferred first |
| 4 | [TASK-SYNC-004](tasks/cards/TASK-SYNC-004.md) | Resolve tag sync Gate E violation | none |
| 5 | [TASK-QUAL-003](tasks/cards/TASK-QUAL-003.md) | Dead code cleanup in functions/ | none |

---

## Dependency Waves (Phase 2)

| Wave | Tasks | Depends On |
|---|---|---|
| A (safety floor) | `TASK-SHELL-001`, `TASK-SYNC-002`, `TASK-SYNC-004` | none — run now |
| B (test coverage) | `TASK-SYNC-001`, `TASK-TEST-002` | Wave A |
| C (sync hardening) | `TASK-SYNC-003` | Waves A + B |
| D (quality/CI) | `TASK-QUAL-001..003`, `TASK-UX-001` | Wave A |
| E (release) | `TASK-REL-001..002`, `TASK-UX-002`, `TASK-QUAL-002` | Waves A-D |

---

## Completed Tasks

| ID | Goal |
|---|---|
| TASK-SYS-001..003 | Control plane, phase-1 checks, CSSOT |
| TASK-CLI-001..004 | Full CLI taxonomy, flags, help, deprecation layer |
| TASK-SVC-001..006 | All service command lifecycles |
| TASK-TEST-001 | Test baseline by change type (select-tests.sh) |
| TASK-1.3a | Explorer A — docs/status drift audit |
| TASK-1.3b | Explorer B — code/test reality audit |
| TASK-1.5 | Artifact cleanup (.gitignore + untrack 24 files) |

---

## Phase 1 Resolution Notes

**TASK-1.1** (Deploy root CLAUDE.md): Closed as design correction.
  `system/CLAUDE.md` is authoritative and already loaded by agent sessions.
  Deploying a copy to the project root would create a maintenance split in a user-data directory.

**TASK-1.2** (Deploy services/CLAUDE.md): Same resolution as TASK-1.1.
  `system/services-CLAUDE.md` is authoritative.

**TASK-1.4** (TASKS.md at project root): Closed as design correction.
  `system/TASKS.md` is authoritative. Project root is user data space.

---

## Fragility Register (interim)

Full policy: `fragility-register.md`

| File(s) | Classification |
|---|---|
| `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh` | HIGH FRAGILITY |
| `bin/ww`, `lib/shell-integration.sh` | SERIALIZED |

---

## Phase Boundary Rules

**Phase 1:** Closed. Explorer A + B complete, artifact cleanup done, CSSOT corrected.

**Phase 2 prerequisites before any lib/ Builder task:**
- `lib/CLAUDE.md` must exist
- `tests/CLAUDE.md` must exist
- TASK-SHELL-001 strongly recommended before touching HIGH FRAGILITY files
