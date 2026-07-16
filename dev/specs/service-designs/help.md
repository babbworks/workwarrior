# Service Design: help

*(Relocated from services/help/ — TASK-STRUCT-3)*

# Service overview: `help`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

Structured help beyond one-line `ww help` strings: topic pages, flag compatibility matrices, and deep links into `docs/` and `dev/config/command-syntax.yaml` (CSSOT).

## Target user

End users learning ww; Docs agent for cross-checking Gate C.

## Command surface (sketch)

- `ww help topics` — list stable topic IDs.
- `ww help topic <id>` — render long-form help (markdown or plain text) with examples.
- `ww help cssot` — show how CLI maps to `command-syntax.yaml` domains.

## Data / integrations

- Reads: `docs/`, `dev/config/command-syntax.yaml`, per-service `--help` where available.
- Writes: none (generation stays in docs pipeline unless explicitly scoped).

## Open questions

- Single source vs duplication with `ww service help` and `bin/ww` embedded strings (Gate C risk).
- Output modes: is `--json` meaningful for help topics (AST), or skip?
- Offline vs online links (GitBook, raw repo paths).

---

## Original README

# Service: help

This directory contains services for the "help" category.

## Purpose

Place scripts and supporting files here to provide help-related functionality. Scripts should be executable and follow the Workwarrior service conventions.

## Notes

- Profile-specific overrides can be placed at: <profile-base>/services/help/
- See services/README.md for registry behavior and best practices.
