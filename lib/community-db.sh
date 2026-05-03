#!/usr/bin/env bash
# lib/community-db.sh — shared bash helpers for community.db operations.
#
# Source this file; do not execute directly.
# All functions require WW_BASE to be set.
# Functions emit JSON on stdout and return 0 on success, 1 on error.
#
# Usage:
#   source "$WW_LIB/community-db.sh"
#   community_create "my-project"
#   community_add_task "my-project" "$task_uuid"

_COMM_STORE_PY="$(dirname "${BASH_SOURCE[0]}")/../services/community/community_store.py"

# ── internal ─────────────────────────────────────────────────────────────────

_comm_store() {
  python3 "$_COMM_STORE_PY" "$@"
}

_comm_require_ww_base() {
  if [[ -z "${WW_BASE:-}" ]]; then
    echo '{"ok":false,"error":"WW_BASE not set"}' >&2
    return 1
  fi
}

# ── public API ────────────────────────────────────────────────────────────────

# community_list — list all communities with entry counts.
# Output: {"ok":true,"communities":[{"name":"x","entry_count":N},...]}
community_list() {
  _comm_require_ww_base || return 1
  _comm_store list "$WW_BASE"
}

# community_create <name> — create a new community (letters/numbers/hyphens/underscores).
# Output: {"ok":true,"name":"x"} | {"ok":false,"error":"..."}
community_create() {
  local name="${1:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$name" ]]; then
    echo '{"ok":false,"error":"name required"}'; return 1
  fi
  _comm_store create "$WW_BASE" "$name"
}

# community_show <name> — return entries + comments for a community.
# Output: {"ok":true,"name":"x","entries":[...]}
community_show() {
  local name="${1:-}"
  _comm_require_ww_base || return 1
  _comm_store show "$WW_BASE" "$name"
}

# community_add_task <community> <task_uuid>
# Exports the task via `task uuid export`, writes captured state to community.db.
# Requires TASKRC, TASKDATA, and WARRIOR_PROFILE to be set.
# Output: {"ok":true,"entry_id":N,"source_ref":"..."}
community_add_task() {
  local comm="${1:-}" uuid="${2:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$comm" || -z "$uuid" ]]; then
    echo '{"ok":false,"error":"community and uuid required"}'; return 1
  fi
  if [[ -z "${TASKRC:-}" ]]; then
    echo '{"ok":false,"error":"TASKRC not set — activate a profile first"}'; return 1
  fi
  if [[ -z "${WARRIOR_PROFILE:-}" ]]; then
    echo '{"ok":false,"error":"WARRIOR_PROFILE not set — activate a profile first"}'; return 1
  fi
  local tmp ec=0
  tmp="$(mktemp)"
  task rc.confirmation=no "$uuid" export >"$tmp" 2>/dev/null || ec=$?
  if [[ "$ec" -ne 0 ]] || ! grep -q '"uuid"' "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    echo "{\"ok\":false,\"error\":\"task not found: $uuid\"}"; return 1
  fi
  local source_ref="${WARRIOR_PROFILE}.task.${uuid}"
  local out
  out="$(_comm_store add-entry "$WW_BASE" "$comm" "$source_ref" "$tmp")"
  rm -f "$tmp"
  echo "$out"
  python3 -c "import json,sys; sys.exit(0 if json.loads(sys.argv[1]).get('ok') else 1)" "$out" 2>/dev/null
}

# community_add_journal <community> <date_slug> [journal_file]
# date_slug: YYYY-MM-DD_HH-MM. Reads from JOURNAL_FILE env or supplied path.
# Requires WARRIOR_PROFILE to be set.
# Output: {"ok":true,"entry_id":N,...}
community_add_journal() {
  local comm="${1:-}" slug="${2:-}" jfile="${3:-${JOURNAL_FILE:-}}"
  _comm_require_ww_base || return 1
  if [[ -z "$comm" || -z "$slug" ]]; then
    echo '{"ok":false,"error":"community and date_slug required"}'; return 1
  fi
  if [[ -z "${WARRIOR_PROFILE:-}" ]]; then
    echo '{"ok":false,"error":"WARRIOR_PROFILE not set"}'; return 1
  fi
  if [[ -z "$jfile" || ! -f "$jfile" ]]; then
    echo '{"ok":false,"error":"journal file not found — set JOURNAL_FILE or pass path as third argument"}'; return 1
  fi
  local hdr
  hdr="$(python3 -c "
import sys
s = sys.argv[1]
if '_' not in s: sys.exit(1)
a, b = s.split('_', 1)
print(a + ' ' + b.replace('-', ':', 1))
" "$slug")" || { echo '{"ok":false,"error":"invalid date_slug (expected YYYY-MM-DD_HH-MM)"}'; return 1; }
  local nb="${JOURNAL_NOTEBOOK:-default}"
  _comm_store add-journal "$WW_BASE" "$comm" "$WARRIOR_PROFILE" "$jfile" "$hdr" "$nb"
}

# community_add_comment <entry_id> <body>
# Appends a comment/annotation to an existing community entry.
# Output: {"ok":true,"comment_id":N,"entry_id":N}
community_add_comment() {
  local entry_id="${1:-}" body="${2:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$entry_id" || -z "$body" ]]; then
    echo '{"ok":false,"error":"entry_id and body required"}'; return 1
  fi
  _comm_store add-comment "$WW_BASE" "$entry_id" "$body"
}

# community_remove_entry <community> <entry_id>
# Output: {"ok":true,"entry_id":N}
community_remove_entry() {
  local comm="${1:-}" eid="${2:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$comm" || -z "$eid" ]]; then
    echo '{"ok":false,"error":"community and entry_id required"}'; return 1
  fi
  _comm_store remove-entry "$WW_BASE" "$comm" "$eid"
}

# community_entry_meta <entry_id>
# Return source_ref + captured_state for a single entry (for backlink building).
# Output: {"source_ref":"...","captured_state":{...}}
community_entry_meta() {
  local eid="${1:-}"
  _comm_require_ww_base || return 1
  _comm_store entry-meta "$WW_BASE" "$eid"
}

# community_exists <name> — returns 0 if community exists, 1 if not.
community_exists() {
  local name="${1:-}"
  _comm_require_ww_base || return 1
  local out
  out="$(_comm_store show "$WW_BASE" "$name" 2>/dev/null)"
  python3 -c "import json,sys; sys.exit(0 if json.loads(sys.argv[1]).get('ok') else 1)" "$out" 2>/dev/null
}

# community_archive <name> — archive a community (hidden from list, data preserved).
community_archive() {
  local name="${1:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$name" ]]; then echo '{"ok":false,"error":"name required"}'; return 1; fi
  _comm_store archive "$WW_BASE" "$name"
}

# community_unarchive <name> — restore an archived community.
community_unarchive() {
  local name="${1:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$name" ]]; then echo '{"ok":false,"error":"name required"}'; return 1; fi
  _comm_store unarchive "$WW_BASE" "$name"
}

# community_describe <name> <description> — set or clear a community description.
community_describe() {
  local name="${1:-}" desc="${2:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$name" || -z "$desc" ]]; then echo '{"ok":false,"error":"name and description required"}'; return 1; fi
  _comm_store describe "$WW_BASE" "$name" "$desc"
}

# community_rename <old> <new> — rename a community (entry IDs unchanged).
community_rename() {
  local old="${1:-}" new="${2:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$old" || -z "$new" ]]; then echo '{"ok":false,"error":"old and new names required"}'; return 1; fi
  _comm_store rename "$WW_BASE" "$old" "$new"
}

# community_modify_entry <entry_id> [--tags x] [--priority H|M|L] [--project p] [--derivative 0|1]
community_modify_entry() {
  local eid="${1:-}"; shift 2>/dev/null || true
  _comm_require_ww_base || return 1
  if [[ -z "$eid" ]]; then echo '{"ok":false,"error":"entry_id required"}'; return 1; fi
  _comm_store modify-entry "$WW_BASE" "$eid" "$@"
}

# community_refresh_entry <community> <entry_id> <json_file>
# Re-snapshot the captured_state from a fresh task export file.
community_refresh_entry() {
  local comm="${1:-}" eid="${2:-}" jfile="${3:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$comm" || -z "$eid" || -z "$jfile" ]]; then
    echo '{"ok":false,"error":"community, entry_id, and json_file required"}'; return 1
  fi
  _comm_store refresh-entry "$WW_BASE" "$comm" "$eid" "$jfile"
}

# community_move_entry <entry_id> <from_community> <to_community>
community_move_entry() {
  local eid="${1:-}" from="${2:-}" to="${3:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$eid" || -z "$from" || -z "$to" ]]; then
    echo '{"ok":false,"error":"entry_id, from, and to required"}'; return 1
  fi
  _comm_store move-entry "$WW_BASE" "$eid" "$from" "$to"
}

# community_recent [n] — cross-community recent activity feed (default 10).
community_recent() {
  local n="${1:-10}"
  _comm_require_ww_base || return 1
  _comm_store recent "$WW_BASE" "$n"
}

# community_mark_comment_copied <comment_id> — mark comment as copied to source task.
community_mark_comment_copied() {
  local cid="${1:-}"
  _comm_require_ww_base || return 1
  if [[ -z "$cid" ]]; then echo '{"ok":false,"error":"comment_id required"}'; return 1; fi
  _comm_store mark-copied "$WW_BASE" "$cid"
}
