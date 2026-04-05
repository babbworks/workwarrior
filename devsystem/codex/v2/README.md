# Workwarrior Devsystem (Codex v2 Hybrid)

Hybrid architecture combining:
- Codex v1 executable operations (`codexctl`, scripts, machine-checkable config)
- Claude v1 governance depth (roles, gates, workflows, fragility register, richer tasking)

## Location

- `/Users/mp/ww/devsystem/codex/v2`

## Hybrid Design

### Execution Layer (Codex)

- `bin/codexctl` - runnable operator CLI
- `scripts/` - task generation, worktree dispatch, phase checks
- `config/` - gates, roles, serialization paths, test baselines
- `audits/` and `reports/` - operational artifacts

### Governance Layer (Claude)

- `roles/` - role contracts and prompts
- `gates/` - gate definitions and release checklist
- `workflows/` - phase and delivery flows
- `fragility-register.md` - high-risk policy
- `services-CLAUDE.md` and `OPERATING-SPEC.md` - deployable context specs

### Canonical Tracking

- `TASKS.md` - seeded, card-driven source of truth
- `templates/` - codex templates plus `templates/claude/` governance templates

## Quick Start

```bash
cd /Users/mp/ww/devsystem/codex/v2
chmod +x bin/codexctl scripts/*.sh

# 1) Check system state
bin/codexctl status

# 2) Create or refine task cards
bin/codexctl new-task TASK-900 "Hybrid smoke test task"

# 3) Execute Phase 1 workflow guidance
cat workflows/phase1.md

# 4) Validate Phase 1 readiness checks
bin/codexctl verify-phase1

# 5) Dispatch isolated implementation stream
bin/codexctl dispatch builder profile-stats tasks/cards/TASK-900.md
```

## Notes

- `verify-phase1` accepts Explorer reports in either `audits/` (Codex style) or `outputs/` (Claude workflow style).
- Serialized ownership defaults apply to:
  - `bin/ww`
  - `lib/shell-integration.sh`
  - `lib/github-*.sh`
  - `lib/sync-*.sh`
