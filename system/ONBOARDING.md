# ONBOARDING.md — Workwarrior Agent Entry Point

Read this first. It orients you to the project and gets you to your first task.
This file is tool-agnostic — Claude Code, Amazon Q, Codex, Gemini, or any other agent.

---

## What This Project Is

Workwarrior is a terminal-first, profile-based productivity system unifying TaskWarrior, TimeWarrior, JRNL, and Hledger under a single CLI (`ww`). Profiles are isolated workspaces — each has its own task data, time tracking, journals, and ledgers. Users activate profiles via shell aliases and all tool state follows automatically via env vars. The system supports multiple independent instances tracked in a registry at `~/.config/ww/registry/`.

**Repo:** `Documents/vaults/babb/repos/ww/` (git)
**Dev instance:** `~/ww-dev/` (synced from repo via `dev-sync.sh`, not git)
**Production instance:** `~/wwv02/` (23+ profiles, anchor command `ww`)

---

## Step 1: Session Init

```bash
eval "$(ww agent init --instance ~/wwv02 --profile ww-development)"
wwctl status
```

Confirm the printed header shows the correct instance and profile. See `system/context/session-init.md` for full protocol.

---

## Step 2: Read These Files (in order)

| File | What it gives you |
|---|---|
| `system/CLAUDE.md` | Directory map, agent model, scripting standards, fragility markers, testing, hard gates |
| `system/TASKS.md` | Current task board: what's done, pending, in-progress |
| `system/context/working-conventions.md` | Operator preferences, response style, multi-agent norms |
| `system/dev-instance.md` | Three-directory model: repo / ww-dev / wwv02, sync workflow |
| `system/logs/decisions.md` | Every non-obvious architectural decision — read before touching `lib/` or sync files |

For service work: also read `system/services-CLAUDE.md`.
For fragility detail: also read `system/fragility-register.md`.
For task and time tracking conventions: read `system/context/task-conventions.md`.

---

## Current State

- **Phase:** Phase 2 active
- **Active work:** Browser UI (15+ panels), AI integration (ollama), weapons (gun/sword), profile management, multi-instance registry
- **Known test baseline:** ~29 failures in `test-profile-management-properties.bats`, `test-profile-name-validation.bats`, `test-browser.bats`. Pre-existing — do not block on them.
- **CI:** Disabled. Tests run locally via `bats tests/`.

---

## How Work Gets Done

Handoff sequence: **Orchestrator** (authors task card + acceptance criteria) → **Builder** (implements in isolated worktree) → **Verifier** (adversarial review + signs off) → **Docs** (closes task, updates docs).

```bash
cd system
wwctl status                                   # confirm system state
wwctl new-task TASK-XXX "goal"                 # generate task card
wwctl dispatch builder <topic> tasks/cards/TASK-XXX.md
bash scripts/select-tests.sh <type> --run      # verify before merge
```

Change types: `lib` | `service` | `profile` | `shell_integration` | `bin_ww` | `github_sync`

Full workflow: `system/workflows/feature-delivery.md`

---

## Hard Rules

1. **Never write to `profiles/*/`** — profile data is user data. Use lib functions.
2. **Never create files at the repo root** — root is for shipped code only.
3. **Read before editing** — another agent may have modified the file since your last session.
4. **`system/` is the only memory store** — decisions go to `system/logs/decisions.md`, task state to `system/TASKS.md`. Nothing important lives in tool-native memory (`~/.claude/`, `~/.codex/`, etc.).
5. **SERIALIZED files** (`bin/ww`, `lib/shell-integration.sh`) — one writer at a time, never parallel.
6. **HIGH FRAGILITY files** (all `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh`) — require Orchestrator approval before any Builder touches them.
7. **`set -euo pipefail`** in executed scripts only — never in sourced `lib/` files.
