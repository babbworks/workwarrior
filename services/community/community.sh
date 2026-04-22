#!/usr/bin/env bash
# Service: community — global shared collections ($WW_BASE/.community/community.db)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Capture WW_BASE before core-utils (first load makes WW_BASE readonly).
_PRE_WW_BASE="${WW_BASE:-}"
# shellcheck source=../../lib/core-utils.sh
source "$SCRIPT_DIR/../../lib/core-utils.sh"

COMM_WW_BASE="${_PRE_WW_BASE:-$WW_BASE}"
COMM_DB="${COMM_WW_BASE}/.community/community.db"
STORE_PY="$SCRIPT_DIR/community_store.py"

validate_community_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    log_error "Community name required"
    return 1
  fi
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Community name must be letters, numbers, hyphens, underscores only"
    return 1
  fi
  return 0
}

_comm_store_cli() {
  python3 "$STORE_PY" "$1" "$COMM_WW_BASE" "${@:2}"
}

cmd_list() {
  if [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]]; then
    _comm_store_cli list
    return 0
  fi
  local json_out
  json_out="$(_comm_store_cli list)"
  if ! python3 -c "import json,sys; json.loads(sys.argv[1])" "$json_out" 2>/dev/null; then
    log_error "Failed to read community database"
    exit 2
  fi
  echo "Communities:"
  python3 -c "
import json, sys
d = json.loads(sys.argv[1])
rows = d.get('communities') or []
if not rows:
    print('  (none — ww community create <name>)')
else:
    for c in rows:
        print('  • %s\t(%s entries)' % (c['name'], c['entry_count']))
" "$json_out"
}

cmd_show() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    log_error "Usage: ww community show <name>"
    exit 1
  fi
  if [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]]; then
    _comm_store_cli show "$name"
    return 0
  fi
  local json_out ec=0
  json_out="$(_comm_store_cli show "$name")" || ec=$?
  if [[ "$ec" -ne 0 ]]; then
    python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('error','not found'))" "$json_out" 2>/dev/null || echo "community not found"
    exit 1
  fi
  python3 -c "
import json, sys
d = json.loads(sys.argv[1])
if not d.get('ok'):
    print('error:', d.get('error', '?'))
    sys.exit(1)
print('Community: %s' % d['name'])
for e in d.get('entries', []):
    print('  [%s] %s @ %s' % (e['id'], e['source_ref'], e['added_at']))
    for c in e.get('comments', []):
        body = c.get('body', '') or ''
        suf = '…' if len(body) > 80 else ''
        print('      — %s: %s%s' % (c['created_at'], body[:80], suf))
" "$json_out"
}

cmd_create() {
  local name="${1:-}"
  validate_community_name "$name" || exit 1
  if [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]]; then
    _comm_store_cli create "$name"
    return $?
  fi
  local out ec=0
  set +e
  out="$(_comm_store_cli create "$name")"
  ec=$?
  set -e
  if [[ "$ec" -ne 0 ]]; then
    err="$(python3 -c "import json,sys; print(json.load(sys.stdin).get('error','failed'))" <<<"$out" 2>/dev/null || true)"
    log_error "${err:-create failed}"
    exit 1
  fi
  log_success "Created community '$name'"
}

cmd_add_task() {
  local comm="$1" uuid="$2"
  validate_community_name "$comm" || exit 1
  if [[ -z "$uuid" ]]; then
    log_error "Usage: ww community add <community> task <uuid>"
    exit 1
  fi
  if [[ -z "${TASKRC:-}" || -z "${TASKDATA:-}" ]]; then
    log_error "No task context (TASKRC/TASKDATA) — activate a profile first"
    exit 1
  fi
  local profile="${WARRIOR_PROFILE:-}"
  if [[ -z "$profile" ]]; then
    log_error "WARRIOR_PROFILE not set — activate a profile first"
    exit 1
  fi
  local tmp
  tmp="$(mktemp)"
  task rc.confirmation=no "$uuid" export >"$tmp" 2>/dev/null || true
  if ! grep -q '"uuid"' "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    log_error "Task not found or export failed for uuid $uuid"
    exit 1
  fi
  local source_ref="${profile}.task.${uuid}"
  local out ec=0
  set +e
  out="$(python3 "$STORE_PY" add-entry "$COMM_WW_BASE" "$comm" "$source_ref" "$tmp")"
  ec=$?
  set -e
  rm -f "$tmp"
  if [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]]; then
    echo "$out"
    return $ec
  fi
  if [[ "$ec" -ne 0 ]]; then
    err="$(python3 -c "import json,sys; print(json.load(sys.stdin).get('error','failed'))" <<<"$out" 2>/dev/null || true)"
    log_error "${err:-add failed}"
    exit 1
  fi
  log_success "Added task $uuid to community $comm"
}

cmd_add_journal() {
  local comm="$1" slug="$2"
  validate_community_name "$comm" || exit 1
  if [[ -z "$slug" ]]; then
    log_error "Usage: ww community add <community> journal <YYYY-MM-DD_HH-MM>"
    exit 1
  fi
  local profile="${WARRIOR_PROFILE:-}"
  if [[ -z "$profile" || -z "${WORKWARRIOR_BASE:-}" ]]; then
    log_error "Active profile required (WORKWARRIOR_BASE / WARRIOR_PROFILE)"
    exit 1
  fi
  local hdr
  hdr="$(python3 -c "import sys; s=sys.argv[1];
if '_' not in s: raise SystemExit(1)
a,b=s.split('_',1); print(a+' '+b.replace('-',':'))" "$slug")" || {
    log_error "Invalid journal slug (expected e.g. 2026-04-22_14-30)"
    exit 1
  }
  local jf="${JOURNAL_FILE:-}"
  if [[ -z "$jf" ]]; then
    # Default: same layout as browser — journals/default.txt under profile
    if [[ -f "${WORKWARRIOR_BASE}/journals/default.txt" ]]; then
      jf="${WORKWARRIOR_BASE}/journals/default.txt"
    elif [[ -f "${WORKWARRIOR_BASE}/journals/${profile}.txt" ]]; then
      jf="${WORKWARRIOR_BASE}/journals/${profile}.txt"
    fi
  fi
  if [[ -z "$jf" || ! -f "$jf" ]]; then
    log_error "Journal file not found. Set JOURNAL_FILE to your journal .txt path."
    exit 1
  fi
  local out ec=0
  set +e
  out="$(python3 "$STORE_PY" add-journal "$COMM_WW_BASE" "$comm" "$profile" "$jf" "$hdr" "default")"
  ec=$?
  set -e
  if [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]]; then
    echo "$out"
    return $ec
  fi
  if [[ "$ec" -ne 0 ]]; then
    err="$(python3 -c "import json,sys; print(json.load(sys.stdin).get('error','failed'))" <<<"$out" 2>/dev/null || true)"
    log_error "${err:-add failed}"
    exit 1
  fi
  log_success "Added journal entry [$hdr] to community $comm"
}

action="${1:-}"
shift 2>/dev/null || true

case "$action" in
  ""|help|-h|--help)
    cat << 'EOF'
Community — global shared collections (not per-profile)

Database: $WW_BASE/.community/community.db

Usage:
  ww community list [--json]
  ww community show <name> [--json]
  ww community create <name> [--json]
  ww community add <name> task <uuid>
  ww community add <name> journal <YYYY-MM-DD_HH-MM>   (slug from journal header; set JOURNAL_FILE if needed)

Entries and comments: browser or future actions.
EOF
    ;;
  list)
    cmd_list
    ;;
  show)
    cmd_show "${1:-}"
    ;;
  create)
    cmd_create "${1:-}"
    ;;
  add)
    comm="${1:-}"
    kind="${2:-}"
    shift 2>/dev/null || true
    case "$kind" in
      task)
        cmd_add_task "$comm" "${1:-}"
        ;;
      journal)
        cmd_add_journal "$comm" "${1:-}"
        ;;
      *)
        log_error "Usage: ww community add <community> task <uuid> | journal <slug>"
        exit 1
        ;;
    esac
    ;;
  *)
    log_error "Unknown community action: $action"
    echo "Run: ww community help"
    exit 1
    ;;
esac
