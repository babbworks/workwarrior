# Service overview: `saves`

**Source:** TASK-DESIGN-001 (design-only.) This directory did not exist before; it holds design intent only until implemented.

## Purpose

Named snapshots of profile state beyond `ww profile backup`—lightweight “save points” users can rotate through (e.g. before risky sync or heuristic experiments), with metadata and optional auto-expiry.

## Target user

Power users and Orchestrator-led experiments on a single profile.

## Command surface (sketch)

- `ww saves list` — id, created, size, notes.
- `ww saves create <label>` — tarball or rsync-style snapshot under a controlled subtree of the profile.
- `ww saves restore <id>` — restore with confirmation and Gate B tests hook (future).
- `ww saves prune --keep N` — retention policy.

## Data / integrations

- Reads/writes: under `WORKWARRIOR_BASE/.ww-saves/` (hypothetical) — never mixed with `.task` data files.
- Integrates: optional call into `ww profile backup` format for compatibility.

## Open questions

- Deduplication vs full copies; encryption at rest.
- Interaction with `ww remove` and Gitignored paths.
- Whether snapshots include `TIMEWARRIORDB` and journals by default or opt-in per domain.
