# Workwarrior Dev System — Claude Agent Operating Architecture

This directory is the production operating system for agentic development of Workwarrior. It defines roles, gates, templates, and workflows that all Claude agent sessions must follow. It is not shipped with the project — it lives in `devsystem/` and governs how the project is built.

---

## What This System Is

A two-layer architecture:

1. **Governance control plane** — Orchestrator authority, hard gates A–E, no self-approval, explicit contracts before any code is written.
2. **Execution substrate** — CLAUDE.md context files baked into the repo, memory accumulation across sessions, worktree isolation, canonical task tracking.

Together these give parallel speed without regression risk.

---

## Deployment Guide

Before starting Phase 1, deploy these files to the project:

| File here | Deploy to |
|---|---|
| `CLAUDE.md` | `/Users/mp/ww/CLAUDE.md` |
| `services-CLAUDE.md` | `/Users/mp/ww/services/CLAUDE.md` |
| `TASKS.md` | `/Users/mp/ww/TASKS.md` |

`lib/CLAUDE.md` and `tests/CLAUDE.md` are Phase 2 prerequisites — do not deploy until Explorer B output is complete and reviewed.

---

## Directory Map

```
devsystem/claude/
├── README.md                  ← you are here
├── CLAUDE.md                  ← deploy to project root
├── services-CLAUDE.md         ← deploy to services/
├── TASKS.md                   ← deploy to project root
├── fragility-register.md      ← reference; contents go into CLAUDE.md
│
├── roles/
│   ├── orchestrator.md        ← role definition + agent prompt
│   ├── builder.md             ← role definition + agent prompt
│   ├── verifier.md            ← role definition + agent prompt
│   ├── explorer.md            ← role definition + agent prompt
│   └── docs-agent.md          ← role definition + agent prompt
│
├── gates/
│   ├── all-gates.md           ← Gates A–E with concrete checklist items
│   └── release-checklist.md   ← Gate D release checklist
│
├── templates/
│   ├── task-card.md           ← 8-field task card template
│   ├── builder-risk-brief.md  ← pre-flight risk brief template
│   ├── explorer-a-output.md   ← Explorer A output format
│   ├── explorer-b-output.md   ← Explorer B output format
│   └── verifier-signoff.md    ← Verifier sign-off checklist
│
└── workflows/
    ├── phase1.md              ← Phase 1 step-by-step execution
    ├── feature-delivery.md    ← Standard Phase 2+ feature workflow
    └── high-fragility.md      ← Workflow for GitHub sync and fragile areas
```

---

## Quick-Start: How to Run a Session

### Starting Phase 1
1. Deploy `CLAUDE.md`, `services-CLAUDE.md`, `TASKS.md` to the project.
2. Open `workflows/phase1.md` and follow the sequence.
3. Dispatch Explorer A and Explorer B as parallel subagents (see `roles/explorer.md`).
4. Orchestrator synthesizes outputs and populates TASKS.md.

### Starting a Feature Task (Phase 2+)
1. Open `TASKS.md`, find the task card, confirm status is `pending`.
2. Set status to `in-progress`.
3. Open `workflows/feature-delivery.md` and follow the sequence.
4. Builder works in isolated worktree on `agent/builder/<topic>` branch.
5. Verifier runs against acceptance criteria using `templates/verifier-signoff.md`.
6. Docs agent closes the task.

### High-Fragility Changes
See `workflows/high-fragility.md`. Requires explicit Orchestrator approval before Builder starts.

---

## Non-Negotiable Rules

- **No self-approval.** The agent that writes code cannot approve it.
- **No implementation without acceptance criteria.** (Gate A)
- **No merge without passing tests and Verifier sign-off.** (Gate B)
- **No "complete" without docs and help aligned.** (Gate C)
- **No untracked TODO in production path.** (Gate E)
- **Parallel work only when write sets are explicitly disjoint.**
- **`pending/` is archive. Nothing new is written there.**

---

## Branch Naming

```
agent/<role>/<topic>
```

Examples:
- `agent/builder/profile-stats`
- `agent/verifier/github-sync-audit`
- `agent/explorer/test-coverage-map`
- `agent/docs/services-readme-update`
