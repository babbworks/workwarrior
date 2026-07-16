# ONBOARDING.md — Workwarrior Agent Entry Point

Read this first. It orients you to the project and gets you to your first task.
This file is tool-agnostic — Claude Code, Amazon Q, Codex, Gemini, or any other agent.

---

## What This Project Is

Workwarrior is a terminal-first, profile-based productivity system unifying TaskWarrior, TimeWarrior, JRNL, and Hledger under a single CLI (`ww`). Profiles are isolated workspaces — each has its own task data, time tracking, journals, and ledgers. Users activate profiles via shell aliases and all tool state follows automatically via env vars. The system supports multiple independent instances tracked in a registry at `~/.config/ww/registry/`.

**Repo:** `github/workwarrior/` (git)
**Dev instance:** `~/ww/` (synced from repo via `dev-sync.sh`, not git)
**Production instance:** `~/ww/` (23+ profiles, anchor command `ww`)

---

## Step 1: Session Init

```bash
eval "$(ww agent init --instance ~/ww --profile ww-development)"
wwctl status
```

Confirm the printed header shows the correct instance and profile. See `.claude/ww/ww-agent-guidance.md` for the full session-init protocol.

---

## Step 2: Read These Files (in order)

| File | What it gives you |
|---|---|
| `dev/CLAUDE.md` | Directory map, agent model, scripting standards, fragility markers, testing, hard gates |
| `dev/TASKS.md` | Current task board: what's done, pending, in-progress |
| `dev/roles/*.md` | Per-role constraints and multi-agent working norms (Orchestrator/Builder/Verifier/Docs) |
| `dev/dev-instance.md` | Three-directory model: repo / dev-instance / prod-instance, sync workflow |
| `dev/logs/decisions.md` | Every non-obvious architectural decision — read before touching `lib/` or sync files |

For service work: also read `dev/services-CLAUDE.md`.
For fragility detail: also read `dev/fragility-register.md`.
For task and time tracking conventions (UUID rule, lifecycle, annotations, UDAs, parallel sub-agents): read `.claude/ww/ww-agent-guidance.md`.

---

## Current State

- **THE PROGRAM IS COMPLETE.** All four phases (capture → record → interpret → payoff) landed 2026-07-15/16.
  Stream, ledger sync, attention queue, auto-rules — all operational with tests.
- **155 of 165 cards complete.** 7 pending (popup pipeline, community chain, deferred items). 0 in-review.
- **CI:** Enabled. `.github/workflows/ci.yml` runs smoke, 13 BATS suites, identity gate, and INDEX staleness check on every push.
- **Identity:** Purged. `bash dev/scripts/check-identity-leak.sh` verifies no machine/user paths are tracked.
- **The plan going forward:** feature work (list service → popup), and the items in `dev/TASKS.md` "Outside the program" section.

## Task Status — Where To Look

| Question | Source of truth |
|---|---|
| What is this card's status? | The card itself: `Status:` in `dev/tasks/cards/TASK-*.md`. **Nothing else.** |
| What is the whole backlog? | `dev/tasks/INDEX.md` — **GENERATED** by `wwctl index`. Never hand-edit it. |
| What should I work on, and why? | `dev/TASKS.md` — the curated plan (priority, sequence, rationale). |

Changed a card's `Status:`? Run `wwctl index`. `wwctl index --check` exits 1 if the index is stale.
A card whose `Status:` cannot be parsed is a **fatal error**, not a silent skip — that silent skip
once hid 15 cards from the board for months (see "Reconciliation 2026-07-13" in `dev/TASKS.md`).

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

Full workflow: `dev/workflows/feature-delivery.md`

---

## Hard Rules

1. **Never write to `profiles/*/`** — profile data is user data. Use lib functions.
2. **Never create files at the repo root** — root is for shipped code only.
3. **Read before editing** — another agent may have modified the file since your last session.
4. **`dev/` is the only memory store** — decisions go to `dev/logs/decisions.md`, task state to `dev/TASKS.md`. Nothing important lives in tool-native memory (`~/.claude/`, `~/.codex/`, etc.).
5. **SERIALIZED files** (`bin/ww`, `lib/shell-integration.sh`) — one writer at a time, never parallel.
6. **HIGH FRAGILITY files** (all `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh`) — require Orchestrator approval before any Builder touches them.
7. **`set -euo pipefail`** in executed scripts only — never in sourced `lib/` files.
