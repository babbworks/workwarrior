# TASK-INSTALL-004 — install.sh bash 3.2 compatibility + community.sh add bug

**Status:** complete
**Priority:** HIGH
**Phase:** 2
**Component:** install.sh, services/community/community.sh

---

## Goal

Fix install.sh failures on fresh macOS machines (bash 3.2 — the macOS default) and community.sh add command routing bug.

## Problems Found

**install.sh — two bash 4.0+ features:**

1. `mapfile -t arr < <(cmd)` — bash 4.0+ only. All 5 uses fail with "command not found" under `set -e`, crashing the installer.
2. `${var^^}` uppercase expansion — bash 4.0+ only. In `configure_multi_bootstrap()` for the guard variable.

**community.sh — two bugs:**

3. `ww community add <community> task <uuid>` — inner `shift 2>/dev/null || true` only shifts by 1. After the outer shift, args are `comm kind uuid`; second shift removes `comm`, leaving `kind uuid`. So `${1:-}` = "kind" (literally "task") not the uuid.
4. `_comm_require_ww_base` function referenced in `cmd_comment()` but never defined — crashes `ww community comment`.

## Fixes Applied

- All 5 `mapfile -t arr < <(get_shell_rc_files)` replaced with `while IFS= read -r _line` pattern
- `${COMMAND_NAME^^}` replaced with `printf '%s' ... | tr '[:lower:]' '[:upper:]'`
- Added bash version guard in `main()` (graceful error for bash < 3.x)
- `shift 2>/dev/null || true` → `shift 2 2>/dev/null || true` in community.sh add case
- Added `_comm_require_ww_base()` function definition to community.sh

## Taskwarrior

ww-development task 22 (bbf1b720-3e2f-4364-99c5-56e0633d24ab)
