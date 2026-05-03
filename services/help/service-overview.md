# Service overview: `help`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

Structured help beyond one-line `ww help` strings: topic pages, flag compatibility matrices, and deep links into `docs/` and `system/config/command-syntax.yaml` (CSSOT).

## Target user

End users learning ww; Docs agent for cross-checking Gate C.

## Command surface (sketch)

- `ww help topics` — list stable topic IDs.
- `ww help topic <id>` — render long-form help (markdown or plain text) with examples.
- `ww help cssot` — show how CLI maps to `command-syntax.yaml` domains.

## Data / integrations

- Reads: `docs/`, `system/config/command-syntax.yaml`, per-service `--help` where available.
- Writes: none (generation stays in docs pipeline unless explicitly scoped).

## Open questions

- Single source vs duplication with `ww service help` and `bin/ww` embedded strings (Gate C risk).
- Output modes: is `--json` meaningful for help topics (AST), or skip?
- Offline vs online links (GitBook, raw repo paths).
