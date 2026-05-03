# Service overview: `open`

**Source:** TASK-DESIGN-001 (design-only.)

## Purpose

Cross-platform “open this URL or file in the user’s default application” with consistent logging and dry-run for headless environments—complementing `ww browser` and shortcut commands.

## Target user

CLI users and agents invoking documentation links, GitHub issues, or exported HTML.

## Command surface (sketch)

- `ww open <url|path>` — macOS `open`, Windows `start`, XDG `xdg-open` fallback.
- `ww open --dry-run` — print resolved command without executing.

## Data / integrations

- Reads: filesystem paths under user control; URLs validated as `http(s)://` by default.
- Writes: none.

## Open questions

- Security policy for `file://` and local path traversal.
- Interaction with `WW_BASE` paths (always absolute via `WORKWARRIOR_BASE`).
- Whether `open` belongs in `shortcut` instead (single UX surface).
