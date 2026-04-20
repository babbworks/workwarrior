# CLAUDE.md — Workwarrior

This file is the primary context document for all Claude agent sessions working on this project. Read it fully before touching any file. It tells you what this project is, what you can and cannot do, how to run tests, and where your task is.

---

## Project

Workwarrior is a terminal-first, profile-based productivity system that unifies TaskWarrior, TimeWarrior, JRNL, and Hledger under a single CLI (`ww`). Profiles are isolated workspaces — each has its own task data, time tracking, journals, ledgers, and config. The service architecture is extensible and self-documenting. Users activate profiles via shell aliases (`p-work`, `p-personal`) and all tool state follows automatically.

---

## Directory Map

| Directory/File | Purpose | Touch? |
|---|---|---|
| `bin/ww` | Main CLI dispatcher (709 lines). Routes commands to services. | Serialized — one writer at a time |
| `lib/` | Core bash libraries (24 files). Read `lib/CLAUDE.md` before any change. | High-risk — see fragility section |
| `services/` | Service registry (25+ categories). Read `services/CLAUDE.md`. | Safe to add; risky to change existing |
| `profiles/` | User workspaces with task/time/journal data. Gitignored. | Never modify profile data directly |
| `functions/` | Shell helper functions sourced at shell init. | Low risk |
| `config/` | Global YAML config (ai, models, groups, shortcuts, ctrl, heuristics). | Low risk |
| `resources/` | Default templates and config files for new profiles. | Low risk |
| `docs/` | User-facing documentation. Docs agent owns updates here. | Write after merge only |
| `tests/` | BATS unit suites and integration test runners. | Always update when changing behavior |
| `system/` | Dev system documentation and planning. Not shipped. | Orchestrator only |
| `TASKS.md` | **Canonical task board.** Single source of truth for all open work. | Orchestrator only |
| `pending/` | Archive. Nothing new is written here. | Read-only |
| `scripts/` | Build scripts: compile-heuristics.py, scan-taskwarrior-extensions.py | Low risk |
| `weapons/` | Weapon extensions (gun, sword). | Low risk |

**Never create files in:** `profiles/*/`, `bin/`, or root unless explicitly required by a task card.

---

## Agent Model

Four always-active roles. Two conditional roles deployed by the Orchestrator as needed.

| Role | When Active | Core Constraint |
|---|---|---|
| **Orchestrator** | Always | Owns backlog, contracts, merge decisions. Never writes production code. Never self-approves. |
| **Builder** | Always (for implementation tasks) | Works within explicit write scope. Produces risk brief before touching any file. |
| **Verifier** | Always (after every implementation) | Adversarial test execution. Produces signed checklist. Never implements. |
| **Docs** | Always (task closure) | Updates CLAUDE.md files, docs/, help strings. Runs after merge. |
| **Explorer** | Audit phases and high-risk cross-cutting analysis | Read-only. Produces risk briefs or audit outputs. For routine tasks, absorbed into Builder pre-flight paragraph. |
| **Simplifier** | Large diffs or high-risk edits | Embedded in Verifier's checklist. Escalates to standalone agent for large/complex diffs. |

**No agent self-approves. Orchestrator never writes production code. Verifier never writes production code.**

Handoff sequence: Orchestrator (contract) → Builder (implement) → Verifier (validate) → Docs (close).

---

## Shell Scripting Standards

Every script in this project must follow these rules. Violations are Gate B failures.

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- **Bash, not sh.** `#!/usr/bin/env bash` on every script.
- **`set -euo pipefail`** is the second line. No exceptions.
- **Error propagation via return codes**, not exit traps or `exit 1` in lib functions.
- **Logging via `lib/logging.sh`** functions. Never use raw `echo` for user-facing messages in `lib/` or `services/`.
- **Absolute paths always.** Use `$WORKWARRIOR_BASE/...`, never relative paths.
- **Quote all variable expansions:** `"$var"` not `$var`. `"${array[@]}"` not `${array[@]}`.
- **Functions in snake_case.** All local variables declared with `local`.
- **No `cd` in lib functions.** Use full paths.
- **Exit codes:** 0 = success, 1 = user error, 2 = system/internal error.

---

## Environment Variables

These are always set when a profile is active. Safe to reference in any service or lib file.

| Variable | Value |
|---|---|
| `WARRIOR_PROFILE` | Active profile name (e.g., `work`) |
| `WORKWARRIOR_BASE` | Profile base directory (e.g., `~/ww/profiles/work`) |
| `TASKRC` | TaskWarrior config path |
| `TASKDATA` | TaskWarrior data directory path |
| `TIMEWARRIORDB` | TimeWarrior database path |

---

## Service Contract

Services are executable scripts in `services/<category>/`. `ww` discovers them by scanning for executables. Profile-level services at `profiles/<name>/services/<category>/` shadow global ones with the same name.

**Required elements every service must have:**
- Responds to `--help` / `-h` with a one-line description and usage example
- Uses exit codes: 0 success, 1 user error, 2 system error
- Logs via `lib/logging.sh`, not `echo`
- Does not write to profile directories directly — calls lib functions instead

**See `services/CLAUDE.md` for full contract, template tiers, and naming conventions.**

---

## Fragility Markers

### HIGH FRAGILITY — Require Orchestrator approval + extended risk brief + integration tests

| File(s) | Reason |
|---|---|
| `lib/github-api.sh`, `lib/github-sync-state.sh` | GitHub API integration; side effects on remote |
| `lib/sync-pull.sh`, `lib/sync-push.sh`, `lib/sync-bidirectional.sh` | Two-way sync logic; data loss risk |
| `lib/field-mapper.sh`, `lib/sync-detector.sh`, `lib/conflict-resolver.sh`, `lib/annotation-sync.sh` | Sync correctness layer |
| `services/custom/github-sync.sh` | Sync CLI; user-facing entry point |

Full policy in `system/fragility-register.md`.

### SERIALIZED OWNERSHIP — One writer at a time, never parallel

| File | Reason |
|---|---|
| `bin/ww` | All service routing passes through here; conflicts are catastrophic |
| `lib/shell-integration.sh` | Alias and shell function injection; profile activation depends on this |

### NEVER COMMIT

```
.DS_Store
profiles/*/
.state/
.task/
__pycache__/
*.sqlite3
config/cmd-heuristics.yaml
config/cmd-heuristics-corpus.yaml
devsystem/
services/bookbuilder/
```

---

## Testing Requirements

### Run before any merge

```bash
bats tests/
```

### By change type

| Change type | Required test suite |
|---|---|
| Any `lib/` change | `bats tests/` — full suite |
| Any `services/` change | `bats tests/test-service-discovery.sh` + `bats tests/` |
| Profile behavior change | `bats tests/test-foundation.sh` + `bats tests/` |
| `bin/ww` change | `bats tests/` + manual smoke: `ww help` |
| GitHub sync change | `./tests/run-integration-tests.sh` (requires GitHub CLI + test profile auth) |

**Note:** Test baseline will be updated after Explorer B output (Task 1.3b). Check TASKS.md for current status.

### New behavior rule
Every change that adds or modifies behavior requires a new or updated BATS test. No exceptions. This is Gate B.

---

## Hard Quality Gates

These are merge blockers. Not advisory. Not optional.

| Gate | Condition |
|---|---|
| **A** | No implementation starts without Orchestrator-authored acceptance criteria on the task card |
| **B** | No merge with failing required tests or unresolved high-severity Verifier findings |
| **C** | No task marked "complete" unless docs and CLI help strings match the implementation |
| **D** | No release claim without a fully signed release checklist |
| **E** | No untracked TODO or placeholder in any production code path — every deferred item has a TASKS.md card |

---

## Parallelization Rules

- Parallel execution only when write sets are explicitly disjoint
- Orchestrator verifies disjointness before dispatching parallel agents
- If write sets overlap even partially, work is serialized
- One worktree per active Builder stream
- Branch naming: `agent/<role>/<topic>`

---

## Canonical Task Source

**`system/TASKS.md` is the only source of truth for open work.** `system/tasks/INDEX.md` is the scannable manifest of task cards (see `tasks/cards/`; ~99 cards).

- Orchestrator is the only agent that updates status fields
- `pending/` is archive — nothing new is written there
- Every deferred TODO in production code must have a corresponding TASKS.md card (Gate E)
- New tasks are only added by the Orchestrator after Gate A is satisfied
