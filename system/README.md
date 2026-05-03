# Workwarrior Dev System

Synthesized from `claude/v2` (documentation depth, agent readability, seeded task cards, serialization safety) and `codex/v2` (executable automation, machine-parseable config, dual audit/outputs directories). Canonical system deployed to `system/`.

**claude/v2 contributed:** rich CLAUDE.md, services-CLAUDE.md, fragility-register, agent prompt prefixes, full workflow depth, high-fragility workflow, memory system integration, worked template examples, role validation in dispatch, serialization conflict detection.

**codex/v2 contributed:** `bin/wwctl` CLI, operational scripts, YAML config, individual task card files, separated `audits/` + `outputs/` + `reports/` + `logs/` directories, `verify-phase1` automation.

---

## Core Rules (Non-Negotiable)

- Hard gates A–E are mandatory merge/release blockers
- No self-approval — implementing role ≠ approving role
- Parallel work only on disjoint write sets
- `TASKS.md` is the summary index; `tasks/cards/<ID>.md` are the source of truth per task
- `pending/` is archive-only after Phase 1 reconciliation
- `config/command-syntax.yaml` is the canonical command syntax source of truth (CSSOT)

---

## Structure

```
system/
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
│   ├── command-syntax.yaml     ← Canonical command/subcommand/flag contract
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
├── audits/                     ← Explorer A/B report outputs (primary)
├── outputs/                    ← Alternative Explorer output dir (codex convention)
│                               NOTE: verify-phase1 accepts files from EITHER directory
├── reports/                    ← Verifier sign-off outputs + comparison reports
├── plans/                      ← Planning documents (8 planning artifacts)
└── logs/                       ← Operational logs
```

---

## audits/ vs outputs/ — How the Dual-Directory Pattern Works

This system accepts Explorer agent outputs in **either** `audits/` or `outputs/`. Both resolve identically in `verify-phase1.sh`. This is not redundancy — it's a deliberate convention bridge.

**`audits/`** — the claude/v2 naming convention. Communicates that Explorer agents produce *audit artifacts*: contradiction matrices, coverage maps, risk classifications. The name signals intent: these are diagnostic outputs that inform decision-making.

**`outputs/`** — the codex/v2 naming convention. More generic; fits any agent output that doesn't fit neatly into `reports/` or `logs/`. Retained for compatibility so codex-convention agents don't need retraining.

**Rule of thumb:**
- Explorer A and B reports → `audits/` (preferred)
- Any output where "audit" feels wrong → `outputs/`
- Verifier sign-off forms → `reports/`
- Operational logs (sync runs, deploy traces) → `logs/`

**`verify-phase1.sh` check (lines 31–32):**
```bash
check "Explorer A exists" "[[ -n $(ls audits/*explorer-a* 2>/dev/null) || -n $(ls outputs/*explorer-a* 2>/dev/null) ]]"
check "Explorer B exists" "[[ -n $(ls audits/*explorer-b* 2>/dev/null) || -n $(ls outputs/*explorer-b* 2>/dev/null) ]]"
```
The gate passes if the file exists in **either** location. No need to pick one and stick to it — though `audits/` is preferred for Explorer outputs.

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
cd /Users/mp/ww/system
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
5. Explorer A/B outputs saved to `audits/` (or `outputs/` — both are accepted)
6. If command behavior/help/docs changed, update `config/command-syntax.yaml` in the same task

### High-Fragility Changes
See `workflows/high-fragility.md`. Pre-condition: Orchestrator approval in task card before dispatch.
