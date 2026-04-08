# TASKS.md — Workwarrior Canonical Task Board

**Summary index only. Each task's source of truth is its card in `tasks/cards/TASK-XXX.md`.**
**Orchestrator is the only agent that updates status fields.**
`pending/` is archive-only. Nothing new is written there.

Last updated: 2026-04-08 (session 5)
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
| [TASK-SHELL-001](tasks/cards/TASK-SHELL-001.md) | complete | Add set -euo pipefail to all lib/ and services/ scripts |
| [TASK-SYNC-001](tasks/cards/TASK-SYNC-001.md) | complete | Add test coverage for GitHub sync engine |
| [TASK-SYNC-002](tasks/cards/TASK-SYNC-002.md) | complete | Fix critical state integrity bugs in sync engine |
| [TASK-SYNC-003](tasks/cards/TASK-SYNC-003.md) | complete | Harden sync pre-flight validation and error surfacing |
| [TASK-SYNC-004](tasks/cards/TASK-SYNC-004.md) | complete | Resolve tag sync TODO in sync-pull.sh (Gate E) |
| [TASK-SYNC-005](tasks/cards/TASK-SYNC-005.md) | complete | Implement GitHub label → TaskWarrior tag sync |
| [TASK-TEST-002](tasks/cards/TASK-TEST-002.md) | complete | Add CI gate for BATS + integration tests |
| [TASK-QUAL-001](tasks/cards/TASK-QUAL-001.md) | complete | Enforce artifact hygiene across repo |
| [TASK-QUAL-004](tasks/cards/TASK-QUAL-004.md) | complete | Fix filter_system_tags() jq iterator bug in field-mapper.sh |
| [TASK-SYNC-006](tasks/cards/TASK-SYNC-006.md) | complete | Extended label encoding for categorical UDA ↔ GitHub label sync |
| [TASK-SYNC-007](tasks/cards/TASK-SYNC-007.md) | complete | Issue body YAML block for rich UDA ↔ GitHub sync |
| [TASK-QUAL-002](tasks/cards/TASK-QUAL-002.md) | pending | Automate docs/help parity checks |
| [TASK-ISSUES-001](tasks/cards/TASK-ISSUES-001.md) | pending | Improve `ww issues uda` CLI and uda-manager service |
| [TASK-ISSUES-002](tasks/cards/TASK-ISSUES-002.md) | deferred | Configure bugwarrior for john and mark profiles |
| [TASK-QUAL-003](tasks/cards/TASK-QUAL-003.md) | complete | Audit and clean functions/ directory dead code |
| [TASK-INSTALL-001](tasks/cards/TASK-INSTALL-001.md) | complete | Per-tool interactive installer with version cards, platform detection, conflict neutralisation |
| [TASK-INSTALL-002](tasks/cards/TASK-INSTALL-002.md) | complete | Fix journals() function — grep matches all YAML keys, not just journal names under journals: section |
| [TASK-SHELL-UX-001](tasks/cards/TASK-SHELL-UX-001.md) | complete | Shell integration overhaul — re-source safety, dual-rc writes, bare commands, profile creation output cleanup |
| [TASK-UX-001](tasks/cards/TASK-UX-001.md) | pending | Standardize human/compact/json output behavior |
| [TASK-UX-002](tasks/cards/TASK-UX-002.md) | pending | Build command examples library per service |
| [TASK-REL-001](tasks/cards/TASK-REL-001.md) | pending | Operationalize release checklist gate |
| [TASK-REL-002](tasks/cards/TASK-REL-002.md) | pending | Define production-ready CLI milestone criteria |
| [TASK-UDA-001](tasks/cards/TASK-UDA-001.md) | pending | Build ww profile uda surface — list/add/remove/group/manage/perm |
| [TASK-UDA-002](tasks/cards/TASK-UDA-002.md) | pending | Unicode indicator system for UDA groups |
| [TASK-UDA-003](tasks/cards/TASK-UDA-003.md) | pending | UDA color schema — systematic color rules for TW reports |
| [TASK-URG-001](tasks/cards/TASK-URG-001.md) | pending | Interactive urgency coefficient tuning |
| [TASK-TC-001](tasks/cards/TASK-TC-001.md) | parked | TaskChampion multi-device profile sync — ww integration layer |

---

## Dispatch Queue (Phase 2 — active)

| Priority | ID | Goal | Depends On |
|---|---|---|---|
| 1 | [TASK-SYNC-003](tasks/cards/TASK-SYNC-003.md) | Harden sync pre-flight validation and error surfacing | SYNC-001, SYNC-002 done |
| 2 | [TASK-SYNC-005](tasks/cards/TASK-SYNC-005.md) | Implement label → tag sync | SYNC-001 done |
| 3 | [TASK-TEST-002](tasks/cards/TASK-TEST-002.md) | Add CI gate for BATS + integration tests | Wave B |
| 4 | [TASK-QUAL-001](tasks/cards/TASK-QUAL-001.md) | Enforce artifact hygiene across repo | none |
| 5 | [TASK-ISSUES-001](tasks/cards/TASK-ISSUES-001.md) | Improve `ww issues uda` CLI and uda-manager | none |
| 6 | [TASK-ISSUES-002](tasks/cards/TASK-ISSUES-002.md) | Configure bugwarrior for john and mark profiles | none |

---

## Dependency Waves (Phase 2)

| Wave | Tasks | Depends On |
|---|---|---|
| A (safety floor) | ~~`TASK-SHELL-001`~~ ~~`TASK-SHELL-UX-001`~~ ~~`TASK-INSTALL-002`~~ ~~`TASK-SYNC-002`~~ ~~`TASK-SYNC-004`~~ (all done) | — |
| B (test coverage) | ~~`TASK-SYNC-001`~~ (done), `TASK-TEST-002` | Wave A ✓ |
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
| TASK-SHELL-001 | set -euo pipefail sweep (sourced libs use defensive guards; flags in executed scripts only) |
| TASK-INSTALL-001 | Per-tool interactive installer with version cards, platform detection, conflict neutralisation, uninstall |
| TASK-INSTALL-002 | Fix journals() YAML grep bug — awk section-scoped reader |
| TASK-SHELL-UX-001 | Shell integration overhaul: re-source safety, dual-rc writes, bare commands, profile creation output cleanup |
| TASK-SYNC-001 | Add BATS test coverage for GitHub sync engine (42 tests: state, detection, API) |
| TASK-SYNC-002 | Fix 3 critical data-integrity bugs: mv error checks in state, JSON input validation in detector, two-phase commit in profile restore |
| TASK-SYNC-004 | Gate E: remove TODO from sync-pull.sh, create TASK-SYNC-005 for deferred tag sync |
| TASK-QUAL-003 | Dead code audit: removed 8 unreferenced scripts from functions/ |
| TASK-ISSUES-† | Session 4: bugwarrior installed (pipx + setuptools); babb profile configured; GitHub UDAs added to babb .taskrc; configure-issues.sh GitHub wizard overhauled (gh auth token, login/org split, project_template, UDA auto-generate); dependency-installer.sh + bin/ww install hints corrected; uda-manager.sh service-source display; test-shell-functions Property 12 assertion fixed |

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
