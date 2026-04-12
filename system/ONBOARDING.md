# ONBOARDING.md — Workwarrior Agent Entry Point

**Read this file first. It tells you everything you need to orient to this project and start work.**
This file is tool-agnostic — it applies equally to Claude Code, Amazon Q, Codex, Gemini, or any other agent.

---

## What This Project Is

Workwarrior is a terminal-first, profile-based productivity system unifying TaskWarrior, TimeWarrior, JRNL, and Hledger under a single CLI (`ww`). Profiles are isolated workspaces — each has its own task data, time tracking, journals, ledgers, and config. Users activate profiles via shell aliases (`p-work`, `p-personal`) and all tool state follows automatically via env vars.

**Install path:** `/Users/mp/ww`
**Product name:** Workwarrior (never used in paths — path is always `ww`)

---

## Read These Files Next (in order)

| File | What it gives you |
|---|---|
| `system/CLAUDE.md` | Full project context: directory map, agent model, scripting standards, fragility markers, testing requirements, hard gates |
| `system/TASKS.md` | Current task board: what's done, what's pending, dispatch queue, dependency waves |
| `system/context/working-conventions.md` | Operator preferences, response style, path conventions, multi-agent norms |
| `system/logs/decisions.md` | Every non-obvious architectural decision made — read before touching any lib/ or sync file |

For service work, also read `system/services-CLAUDE.md`.
For fragility policy detail, also read `system/fragility-register.md`.

---

## Current State (update this section when phase changes)

- **Phase:** Phase 2 active
- **Next task:** TASK-SITE-005 — Wave 4 of `ww browser` (Time/Journal/Ledger polish)
- **Active initiative:** wwsite — locally-served browser UI (`ww browser`). Waves 1–3 complete. All four sections (Tasks, Time, Journal, Ledger) show live data. A demo profile can be seeded with tasks, time, journal, and ledger data for testing.
- **Known test baseline:** ~10 pre-existing failures (not regressions) in test-profile-management-properties.bats and test-profile-name-validation.bats. See tests/CLAUDE.md for the full list.

---

## The Control Plane

Everything that governs how work is done lives in `system/`. It is not shipped with the product.

```
system/
  ONBOARDING.md          ← you are here
  CLAUDE.md              ← full project + agent rules
  TASKS.md               ← canonical task board
  fragility-register.md  ← file-by-file access policy
  services-CLAUDE.md     ← service development contract
  logs/decisions.md      ← architectural decision log
  context/
    working-conventions.md        ← operator preferences + multi-agent norms
    reference/
      bugwarrior-github-udas.md   ← UDA schema + design notes
  roles/                 ← Orchestrator, Builder, Verifier, Explorer, Docs
  workflows/             ← feature-delivery, phase1, high-fragility
  gates/                 ← Gates A–E with checklists
  templates/             ← task-card, verifier-signoff, builder-risk-brief
  tasks/cards/           ← individual task cards (TASK-XXX.md)
  config/
    command-syntax.yaml  ← canonical CLI contract (CSSOT)
    gates.yaml
    roles.yaml
    test-baseline.yaml
  scripts/               ← wwctl CLI, select-tests.sh, verify-phase1.sh
  bin/wwctl              ← dev system CLI entrypoint
```

---

## Hard Rules (non-negotiable)

1. **Never write to `profiles/*/`** — profile data is user data. Use lib functions.
2. **Never create files at the project root** — `/Users/mp/ww` is a hybrid user-data/software directory.
3. **Read before editing** — another agent may have modified the file since your last session.
4. **`system/` is the only memory store** — decisions go to `system/logs/decisions.md`, task state to `system/TASKS.md`. Nothing important lives in tool-native memory locations (`~/.claude/`, `~/.codex/`, etc.).
5. **SERIALIZED files** (`bin/ww`, `lib/shell-integration.sh`) — one writer at a time, never parallel.
6. **HIGH FRAGILITY files** (all `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh`) — require Orchestrator approval before any Builder touches them.
7. **set -euo pipefail** belongs only in executed scripts (`bin/`, `services/`). Never in sourced `lib/` files — use `${var:-}` defensive guards instead.

---

## How Work Gets Done

Handoff sequence: **Orchestrator** (authors task card) → **Builder** (implements within write scope) → **Verifier** (adversarial review) → **Docs** (closes task).

To start a task:
```bash
cd /Users/mp/ww/system
bin/wwctl status          # confirm system state
bin/wwctl new-task TASK-XXX "goal"
bin/wwctl dispatch builder <topic> tasks/cards/TASK-XXX.md
```

To verify before merge:
```bash
bash scripts/select-tests.sh <change-type> --run
```

Change types: `lib` | `service` | `profile` | `shell_integration` | `bin_ww` | `github_sync`
