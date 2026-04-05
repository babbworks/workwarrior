# Phase 1 Runbook

## Objective

Establish operating foundation before feature work:

1. Root `CLAUDE.md`
2. `services/CLAUDE.md`
3. Parallel Explorer A/B audits
4. Orchestrator synthesis
5. Canonical `TASKS.md`
6. Test baseline mapping by change type
7. Artifact cleanup

## Explorer A Output

- Write report in `audits/<date>-explorer-a.md` using `templates/explorer-a-report.md`.

## Explorer B Output

- Write report in `audits/<date>-explorer-b.md` using `templates/explorer-b-report.md`.

## Synthesis Output

- Update `TASKS.md` with dispatchable cards.
- Ensure deferred TODOs in production paths are tracked (Gate E).

## Completion Check

Run:

```bash
bin/codexctl verify-phase1
```

