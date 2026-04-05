# Workwarrior Dev System — v2 (Hybrid)

Synthesized from `claude/v1` (documentation depth, agent readability) and `codex/v1` (executable automation, machine-parseable config). Neither system alone was complete. This one is.

**claude/v1 contributed:** rich CLAUDE.md, services-CLAUDE.md, fragility-register, agent prompt prefixes, full workflow depth, high-fragility workflow, memory system integration, worked template examples.

**codex/v1 contributed:** `bin/wwctl` CLI, operational scripts, YAML config, individual task card files, separated audit/report/log directories, `verify-phase1` automation.

---

## Core Rules (Non-Negotiable)

- Hard gates A–E are mandatory merge/release blockers
- No self-approval — implementing role ≠ approving role
- Parallel work only on disjoint write sets
- `TASKS.md` is the summary index; `tasks/cards/<ID>.md` are the source of truth per task
- `pending/` is archive-only after Phase 1 reconciliation

---

## Structure

```
v2/
├── README.md                   ← you are here
├── CLAUDE.md                   ← deploy to project root /CLAUDE.md
├── services-CLAUDE.md          ← deploy to project /services/CLAUDE.md
├── TASKS.md                    ← summary index; links to tasks/cards/
├── fragility-register.md       ← file-by-file policy; contents referenced in CLAUDE.md
│
├── bin/
│   └── wwctl                   ← CLI entrypoint: status, verify, new-task, dispatch
│
├── config/
│   ├── gates.yaml              ← Gates A–E (machine-parseable)
│   ├── roles.yaml              ← Role definitions + phase profiles
│   ├── test-baseline.yaml      ← Required tests by change type
│   ├── serialization-paths.txt ← Files requiring serialized ownership
│   └── phase1-checklist.txt    ← Phase 1 exit criteria (used by verify-phase1.sh)
│
├── scripts/
│   ├── common.sh               ← Shared utilities (sourced by all scripts)
│   ├── dispatch-worktree.sh    ← Creates git worktree on agent/<role>/<topic> branch
│   ├── new-task.sh             ← Generates task card from template + updates TASKS.md
│   ├── system-status.sh        ← System health check: files, tasks, phase status
│   └── verify-phase1.sh        ← Automated Phase 1 gate verification (PASS/FAIL)
│
├── roles/
│   ├── orchestrator.md         ← Role definition + agent prompt prefix
│   ├── builder.md              ← Role definition + agent prompt prefix
│   ├── verifier.md             ← Role definition + agent prompt prefix
│   ├── explorer.md             ← Role definition + agent prompt prefix (A and B)
│   └── docs-agent.md           ← Role definition + agent prompt prefix
│
├── gates/
│   ├── all-gates.md            ← A–E with concrete checklists and scan commands
│   └── release-checklist.md    ← Gate D sign-off form
│
├── templates/
│   ├── task-card.md            ← 8-field template + sizing guide + worked example
│   ├── builder-risk-brief.md   ← Pre-flight 5-section form
│   ├── explorer-a-output.md    ← Contradiction matrix template
│   ├── explorer-b-output.md    ← Coverage map + baseline matrix template
│   └── verifier-signoff.md     ← Adversarial 7-section checklist
│
├── tasks/cards/                ← Individual task card files (TASK-XXX.md)
│
├── workflows/
│   ├── phase1.md               ← 8-step Phase 1 with commands + checkboxes
│   ├── feature-delivery.md     ← Standard 6-step delivery loop
│   └── high-fragility.md       ← Sync-specific additional gates and rollback
│
├── audits/                     ← Explorer A/B report outputs
├── reports/                    ← Verifier sign-off outputs
└── logs/                       ← Operational logs
```

---

## Deployment Guide

Before Phase 1 starts, deploy these files to the project:

| Source | Deploy to |
|---|---|
| `CLAUDE.md` | `/Users/mp/ww/CLAUDE.md` |
| `services-CLAUDE.md` | `/Users/mp/ww/services/CLAUDE.md` |
| `TASKS.md` (after Task 1.4) | `/Users/mp/ww/TASKS.md` |

`lib/CLAUDE.md` and `tests/CLAUDE.md` are Phase 2 prerequisites — authored by Docs agent from Explorer B output.

---

## Quick Start

```bash
cd /Users/mp/ww/devsystem/claude/v2
chmod +x bin/wwctl scripts/*.sh

# Check system readiness
bin/wwctl status

# Verify Phase 1 gate conditions
bin/wwctl verify-phase1

# Create a new task card
bin/wwctl new-task TASK-002 "Write root CLAUDE.md"

# Dispatch a builder in an isolated worktree
bin/wwctl dispatch builder write-claude-md tasks/cards/TASK-002.md

# See all active task cards
ls tasks/cards/*.md
```

---

## Session Quick-Reference

### Starting Phase 1
1. `bin/wwctl status` — confirm system is ready
2. Deploy `CLAUDE.md` and `services-CLAUDE.md` to project root
3. Open `workflows/phase1.md` — follow step by step
4. Dispatch Explorer A and B as parallel subagents (prompts in `roles/explorer.md`)
5. `bin/wwctl verify-phase1` — confirm all exit criteria when done

### Starting a Feature Task (Phase 2+)
1. Open `workflows/feature-delivery.md`
2. `bin/wwctl new-task TASK-XXX "Goal"` — generates card in `tasks/cards/`
3. `bin/wwctl dispatch builder <topic> tasks/cards/TASK-XXX.md`
4. Verifier uses `templates/verifier-signoff.md`, saves output to `reports/`
5. Explorer A/B outputs saved to `audits/`

### High-Fragility Changes
See `workflows/high-fragility.md`. Pre-condition: Orchestrator approval in task card before dispatch.
