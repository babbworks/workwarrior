# Service overview: `z-default`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

Catch-all namespace for experimental or legacy scripts that still need a service home in the registry—**not** for production-critical flows. Keeps `services/` tree complete while signaling “low contract” to Orchestrator.

## Target user

Orchestrator staging one-off scripts; deprecated paths awaiting rename into real domains.

## Command surface (sketch)

- Prefer **no** top-level `ww z-default` in production; if exposed, gate behind `WW_EXPERIMENTAL=1`.
- Internal: scripts callable only from other services or docs examples.

## Data / integrations

- Reads/writes: scoped to explicitly passed paths; no implicit profile mutation.

## Open questions

- Time-bounded sunset: when does a script graduate to a real service name?
- Lint rule: forbid `ww z-default` in CSSOT except in experimental appendix.
- Whether this folder should remain empty in clean installs.
