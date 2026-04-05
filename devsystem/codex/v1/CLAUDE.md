# Codex Workwarrior Operating Contract

## Purpose

This repo section defines the production multi-agent workflow for developing Workwarrior.

## Roles

- Always active: `Orchestrator`, `Builder`, `Verifier`, `Docs`
- Conditional: `Explorer` (audit/high-risk), `Simplifier` (large/high-risk diffs)

## Hard Gates

- Gate A: no implementation without explicit acceptance criteria.
- Gate B: no merge with failing required tests or unresolved high-severity findings.
- Gate C: no completion claim unless docs/help align with behavior.
- Gate D: no release-ready claim with unchecked critical release items.
- Gate E: no untracked TODO/placeholder in production paths.

## Parallelization

- Parallel only when write scopes are disjoint.
- Default serialized ownership:
  - `bin/ww`
  - `lib/shell-integration.sh`
  - `lib/github-*.sh`
  - `lib/sync-*.sh`

## Canonical Tracking

- Task source of truth: `TASKS.md`
- `pending/` is archive-only after reconciliation.

## Task Card Contract (Required)

1. Goal
2. Acceptance criteria
3. Write scope
4. Tests required
5. Rollback
6. Fragility
7. Risk notes
8. Status

