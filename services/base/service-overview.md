# Service overview: `base`

**Source:** TASK-DESIGN-001 (design-only; no implementation in this change set beyond this document.)

## Purpose

Define a stable “foundation” namespace for cross-cutting profile operations that do not belong in `profile/` (lifecycle) or `custom/` (wizards)—for example shared defaults, bootstrap snippets, or canonical paths referenced by other services.

## Target user

Orchestrator and Builder agents; advanced users who reason about ww’s directory layout and extension points.

## Command surface (sketch)

- `ww base …` (future): `show-paths`, `validate-layout`, `dump-template` — read-only introspection of expected profile skeleton vs actual tree.
- Optional: `ww base sync-defaults` — merge non-destructive resource updates from `resources/` into a profile (explicit flags, dry-run default).

## Data / integrations

- Reads: `$WW_BASE/resources/`, active `WORKWARRIOR_BASE` tree, `system/config` where relevant.
- Writes: none in read-only modes; guarded writes only with `--apply` and backup hook (future).

## Open questions

- Should `base` subsume any logic today split across `scripts/` and `services/scripts/`?
- How does `base` relate to `z-default` (catch-all) vs explicit empty categories in the registry?
- What is the minimal BATS contract for any future `ww base` command (smoke + dry-run)?
