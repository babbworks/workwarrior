# CLAUDE.md — Workwarrior

This file is the primary context document for all agent sessions working on this project. Read it fully before touching any file.

---

## Project

Workwarrior is a terminal-first, profile-based productivity system that unifies TaskWarrior, TimeWarrior, JRNL, and Hledger under a single CLI (`ww`). Profiles are isolated workspaces — each has its own task data, time tracking, journals, ledgers, and config. The system supports multiple independent instances, each registered in `~/.config/ww/registry/`. Users activate profiles via shell aliases (`p-work`, `p-personal`) and all tool state follows automatically.

---

## Directory Map

| Directory/File | Purpose | Touch? |
|---|---|---|
| `bin/ww` | Main CLI dispatcher. Routes commands to services. | Serialized — one writer at a time |
| `lib/` | Core bash libraries. Read `lib/CLAUDE.md` before any change. | High-risk — see fragility section |
| `services/` | Service registry (25+ categories). Read `services/CLAUDE.md`. | Safe to add; risky to change existing |
| `profiles/` | User workspaces with task/time/journal data. Gitignored. | Never modify profile data directly |
| `functions/` | Shell helper functions sourced at shell init. | Low risk |
| `global/` | Global shared state and cross-instance config. | Low risk |
| `config/` | Global YAML config (ai, models, groups, shortcuts, ctrl, heuristics). | Low risk |
| `resources/` | Default templates and config files for new profiles. | Low risk |
| `docs/` | User-facing documentation. Docs agent owns updates here. | Write after merge only |
| `tests/` | BATS unit suites and integration test runners. | Always update when changing behavior |
| `weapons/` | Weapon extensions (gun, sword). | Low risk |
| `stream/` | Stream service and adapters. | Low risk |
| `system/` | Dev control plane. Not shipped. | Orchestrator only |
| `system/TASKS.md` | **Canonical task board.** Single source of truth for all open work. | Orchestrator only |

**Never create files in:** `profiles/*/`, `bin/`, or repo root unless explicitly required by a task card.

---

## Session Init

**Every agent session starts with:**

```bash
eval "$(ww agent init --instance ~/wwv02 --profile ww-development)"
wwctl status
```

See `system/context/session-init.md` for full protocol including sync-check and alternate flags.

---

## Agent Model

Four always-active roles. Two conditional roles deployed by the Orchestrator as needed.

| Role | When Active | Core Constraint |
|---|---|---|
| **Orchestrator** | Always | Owns backlog, contracts, merge decisions. Never writes production code. Never self-approves. |
| **Builder** | Implementation tasks | Works within explicit write scope. Produces risk brief before touching any file. |
| **Verifier** | After every implementation | Adversarial test execution. Produces signed checklist. Never implements. |
| **Docs** | Task closure | Updates CLAUDE.md files, docs/, help strings. Runs after merge. |
| **Explorer** | Cross-cutting audits and HIGH FRAGILITY pre-flight only | Read-only. For routine tasks, absorbed into Builder pre-flight paragraph — do not spawn as standalone. |
| **Simplifier** | Large diffs or high-risk edits | Embedded in Verifier's checklist. Escalates to standalone for diffs >200 lines. |

**No agent self-approves. Orchestrator never writes production code. Verifier never writes production code.**

Handoff sequence: Orchestrator (contract) → Builder (implement) → Verifier (validate) → Docs (close).

---

## Shell Scripting Standards

Every script must follow these rules. Violations are Gate B failures.

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- **Bash, not sh.** `#!/usr/bin/env bash` on every executed script.
- **`set -euo pipefail`** in executed scripts (`bin/`, `services/`). **Never** in sourced `lib/` files — use `${var:-}` defensive guards instead.
- **Error propagation via return codes**, not exit traps or `exit 1` in lib functions.
- **Logging via `lib/logging.sh`** — never raw `echo` for user-facing messages in `lib/` or `services/`.
- **Absolute paths always.** Use `$WORKWARRIOR_BASE/...`, never relative paths.
- **Quote all variable expansions:** `"$var"` not `$var`.
- **Functions in snake_case.** All local variables declared with `local`.
- **No `cd` in lib functions.** Use full paths.
- **Exit codes:** 0 = success, 1 = user error, 2 = system/internal error.

---

## Environment Variables

Set when a profile is active. All exported by `ww agent init`. Safe to reference in any service or lib file.

| Variable | Value |
|---|---|
| `WARRIOR_PROFILE` | Active profile name (e.g., `ww-development`) |
| `WORKWARRIOR_BASE` | Instance install path (e.g., `~/wwv02`) |
| `TASKRC` | Profile `.taskrc` path |
| `TASKDATA` | Profile `.task/` directory path |
| `TIMEWARRIORDB` | Profile `.timewarrior/` path |
| `JRNL_CFG` | Profile `jrnl.yaml` path |
| `LEDGER_F` | Profile ledger file path |
| `WW_AGENT_SESSION_ID` | Session ID registered at session init |

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
services/bookbuilder/
```

---

## Testing Requirements

### Sequence: smoke → targeted → full

```bash
bats tests/test-smoke.bats          # always first (~5 seconds)
bash system/scripts/select-tests.sh <type> --run   # targeted by change type
bats tests/                         # full suite before any merge
```

### By change type

| Change type | Required test suite |
|---|---|
| Any `lib/` change | smoke + `bats tests/` |
| Any `services/` change | `bats tests/test-service-discovery.bats` + `bash tests/test-service-discovery.sh` + `bats tests/` |
| Profile behavior change | `bats tests/test-directory-structure.bats` + `bash tests/test-scripts-integration.sh` + `bats tests/` |
| `bin/ww` change | smoke + `bats tests/` + manual: `ww help`, `ww profile list` |
| GitHub sync change | `bash tests/run-integration-tests.sh` + `bats tests/test-github-sync.bats` + `bats tests/` |

See `tests/CLAUDE.md` for full matrix, known baseline failures (~29), and known pitfalls.

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
| **D** | No release claim without a fully signed release checklist saved to `system/reports/releases/` |
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

**`system/TASKS.md` is the only source of truth for open work.** `system/tasks/INDEX.md` is the scannable manifest of all task cards (`tasks/cards/`).

- Orchestrator is the only agent that updates status fields
- Every deferred TODO in production code must have a corresponding TASKS.md card (Gate E)
- New tasks are only added by the Orchestrator after Gate A is satisfied
