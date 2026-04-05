# Workwarrior Devsystem (Codex)

Production-oriented multi-agent operating system for building Workwarrior.

This system is ratified from:
- `system/plans/claude-tablecomparison.md`
- `system/plans/codex-tablecomparison.md`
- supporting plan/remix/semi-final docs in `system/plans/`

## Location

- Requested path: `/home/mp/ww/devsystem/codex`
- Active path in this environment: `/Users/mp/ww/devsystem/codex`

## Core Rules

- Hard gates A-E are mandatory.
- No self-approval (author and approver cannot be same role).
- Parallel work only with disjoint write scopes.
- Canonical task source is `TASKS.md` (not `pending/`).

## Structure

- `bin/codexctl` - primary command entrypoint
- `scripts/` - operational scripts
- `config/` - role, gate, phase, and baseline policy
- `templates/` - task/report templates
- `tasks/cards/` - dispatchable task cards
- `audits/` - explorer outputs
- `reports/` - verifier and closure reports
- `runbooks/` - execution procedures

## Quick Start

```bash
cd /Users/mp/ww/devsystem/codex
chmod +x bin/codexctl scripts/*.sh

# See current readiness
bin/codexctl status

# Create a new task card
bin/codexctl new-task TASK-001 "Reconcile status docs"

# Verify phase-1 gates
bin/codexctl verify-phase1

# Create a branch + worktree for a task
bin/codexctl dispatch builder status-reconcile tasks/cards/TASK-001.md
```

