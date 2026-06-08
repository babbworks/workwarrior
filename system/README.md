# Workwarrior Dev System

`system/` is the control plane for Workwarrior development. It is not shipped with the product.

---

## Quick Start

```bash
cd system
eval "$(ww agent init --instance ~/wwv02 --profile ww-development)"
bin/wwctl status
bin/wwctl new-task TASK-XXX "goal"
bin/wwctl dispatch builder <topic> tasks/cards/TASK-XXX.md
```

Start with `system/ONBOARDING.md` if this is your first session.

---

## Structure

```
system/
├── ONBOARDING.md           ← start here
├── CLAUDE.md               ← full project + agent rules
├── TASKS.md                ← summary task board; links to tasks/cards/
├── dev-instance.md         ← three-directory model: repo / ww-dev / wwv02
├── fragility-register.md   ← file-by-file access policy
├── services-CLAUDE.md      ← service development contract
├── total-architecture.md   ← system-wide architecture overview
│
├── bin/
│   └── wwctl               ← CLI: status, new-task, dispatch, verify, docs
│
├── config/
│   ├── gates.yaml          ← Gates A–E (machine-parseable)
│   ├── roles.yaml          ← Role definitions + phase profiles
│   ├── command-syntax.yaml ← Canonical command/subcommand/flag contract (CSSOT)
│   ├── test-baseline.yaml  ← Required tests by change type
│   └── serialization-paths.txt
│
├── context/
│   ├── session-init.md         ← Session startup protocol (ww agent init)
│   ├── task-conventions.md     ← UUID rule, lifecycle, annotations, UDAs, parallel work
│   ├── journal-ledger-conventions.md  ← Sub-journal model, ledger taxonomy, posting
│   ├── instance-registry.md    ← Registry location, ww instance commands, agent rules
│   ├── working-conventions.md  ← Operator preferences, response style, multi-agent norms
│   └── reference/              ← Supporting reference material
│
├── scripts/
│   ├── dev-sync.sh         ← Sync program files: repo → ww-dev or wwv02
│   ├── select-tests.sh     ← Test matrix by change type
│   ├── check-parity.sh     ← Gate C: CSSOT vs ww help output
│   ├── new-task.sh         ← Generate task card + update TASKS.md
│   ├── system-status.sh    ← System health check
│   └── dispatch-worktree.sh← Create git worktree on agent/<role>/<topic>
│
├── roles/                  ← Role definitions + agent prompt prefixes
├── gates/                  ← Gates A–E checklists + release checklist
├── templates/              ← task-card, builder-risk-brief, verifier-signoff
├── workflows/
│   ├── feature-delivery.md ← Standard 6-step delivery loop
│   ├── high-fragility.md   ← Sync-specific additional gates and rollback
│   └── release.md          ← Release gate: checklist → save → tag
│
├── tasks/
│   ├── INDEX.md            ← Scannable manifest of all task cards
│   └── cards/              ← Individual task card files (TASK-XXX.md)
│
├── audits/                 ← Explorer A/B report outputs
├── reports/                ← Verifier sign-off outputs
├── logs/                   ← Operational logs, decisions, session notes
├── specs/                  ← Feature specs and design documents
└── archive/                ← Phase 1 artifacts and historical docs
```
