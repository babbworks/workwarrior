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

_comm_require_name() {
  local name="${1:-}" usage="${2:-}"
  if [[ -z "$name" ]]; then log_error "${usage}"; return 1; fi
}

_comm_require_ww_base() {
  if [[ -z "${COMM_WW_BASE:-}" ]]; then
    log_error "WW_BASE not set — activate a profile or set WW_BASE before using community commands"
    return 1
  fi
  return 0
}

_comm_print_error() {
  local json="${1:-}" fallback="${2:-failed}"
  local err
  err="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('error','$fallback'))" "$json" 2>/dev/null || echo "$fallback")"
  log_error "$err"
}

cmd_list() {
  local show_all=0
  [[ "${1:-}" == "--all" ]] && show_all=1
  if [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]]; then
    [[ "$show_all" -eq 1 ]] && _comm_store_cli list --all || _comm_store_cli list
    return 0
  fi
  local json_out
  [[ "$show_all" -eq 1 ]] && json_out="$(_comm_store_cli list --all)" || json_out="$(_comm_store_cli list)"
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
        arch = ' [archived]' if c.get('archived') else ''
        desc = ('  — ' + c['description']) if c.get('description') else ''
        print('  • %s%s\t(%s entries)%s' % (c['name'], arch, c['entry_count'], desc))
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

cmd_remove() {
  local name="${1:-}" entry_id="${2:-}"
  if [[ "$name" == "--help" || "$name" == "-h" ]]; then
    cat << 'EOF'
Usage: ww community remove <name> <entry-id>

Remove an entry from a community by its numeric ID.
Use 'ww community show <name>' to list entry IDs.

Exit codes: 0 success, 1 user/not-found error
EOF
    return 0
  fi
  if [[ -z "$name" || -z "$entry_id" ]]; then
    log_error "Usage: ww community remove <name> <entry-id>"
    exit 1
  fi
  validate_community_name "$name" || exit 1
  if ! [[ "$entry_id" =~ ^[0-9]+$ ]]; then
    log_error "Entry ID must be a positive integer"
    exit 1
  fi
  if [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]]; then
    _comm_store_cli remove-entry "$name" "$entry_id"
    return $?
  fi
  local out ec=0
  set +e
  out="$(_comm_store_cli remove-entry "$name" "$entry_id")"
  ec=$?
  set -e
  if [[ "$ec" -ne 0 ]]; then
    err="$(python3 -c "import json,sys; print(json.load(sys.stdin).get('error','failed'))" <<<"$out" 2>/dev/null || true)"
    log_error "${err:-remove failed}"
    exit 1
  fi
  log_success "Removed entry $entry_id from community $name"
}

cmd_archive() {
  local name="${1:-}" unarchive="${2:-}"
  _comm_require_name "${name:-}" "Usage: ww community archive <name>" || exit 1
  validate_community_name "$name" || exit 1
  local cmd="archive"
  [[ "$unarchive" == "--unarchive" ]] && cmd="unarchive"
  local out ec=0
  set +e; out="$(_comm_store_cli $cmd "$name")"; ec=$?; set -e
  [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]] && { echo "$out"; return $ec; }
  if [[ "$ec" -ne 0 ]]; then
    _comm_print_error "$out" "${cmd} failed"; exit 1
  fi
  if [[ "$cmd" == "unarchive" ]]; then
    log_success "Unarchived community '$name'"
  else
    log_success "Archived community '$name' (use 'ww community unarchive $name' to restore)"
  fi
}

cmd_unarchive() {
  cmd_archive "${1:-}" --unarchive
}

cmd_describe() {
  local name="${1:-}" desc="${2:-}"
  _comm_require_name "${name:-}" "Usage: ww community describe <name> <description>" || exit 1
  if [[ -z "$desc" ]]; then
    log_error "Description text required"
    exit 1
  fi
  validate_community_name "$name" || exit 1
  local out ec=0
  set +e; out="$(_comm_store_cli describe "$name" "$desc")"; ec=$?; set -e
  [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]] && { echo "$out"; return $ec; }
  if [[ "$ec" -ne 0 ]]; then _comm_print_error "$out" "describe failed"; exit 1; fi
  log_success "Description set for '$name'"
}

cmd_rename() {
  local old="${1:-}" new="${2:-}"
  if [[ -z "$old" || -z "$new" ]]; then
    log_error "Usage: ww community rename <old-name> <new-name>"
    exit 1
  fi
  validate_community_name "$old" || exit 1
  validate_community_name "$new" || exit 1
  local out ec=0
  set +e; out="$(_comm_store_cli rename "$old" "$new")"; ec=$?; set -e
  [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]] && { echo "$out"; return $ec; }
  if [[ "$ec" -ne 0 ]]; then _comm_print_error "$out" "rename failed"; exit 1; fi
  log_success "Renamed community '$old' → '$new'"
}

cmd_modify_entry() {
  local eid="${1:-}"; shift 2>/dev/null || true
  if [[ -z "$eid" ]] || ! [[ "$eid" =~ ^[0-9]+$ ]]; then
    log_error "Usage: ww community modify <entry-id> [--tags x] [--priority H|M|L] [--project p]"
    exit 1
  fi
  local out ec=0
  set +e; out="$(_comm_store_cli modify-entry "$eid" "$@")"; ec=$?; set -e
  [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]] && { echo "$out"; return $ec; }
  if [[ "$ec" -ne 0 ]]; then _comm_print_error "$out" "modify failed"; exit 1; fi
  log_success "Entry $eid updated"
}

cmd_refresh() {
  local comm="${1:-}" eid="${2:-}"
  if [[ -z "$comm" || -z "$eid" ]] || ! [[ "$eid" =~ ^[0-9]+$ ]]; then
    log_error "Usage: ww community refresh <community> <entry-id>"
    exit 1
  fi
  validate_community_name "$comm" || exit 1
  # Entry must be a task type to re-export; check source_ref
  if [[ -z "${TASKRC:-}" || -z "${WARRIOR_PROFILE:-}" ]]; then
    log_error "No task context (TASKRC / WARRIOR_PROFILE) — activate a profile first"
    exit 1
  fi
  # Get the source_ref to find the uuid
  local meta ec=0
  set +e; meta="$(_comm_store_cli entry-meta "$eid")"; ec=$?; set -e
  if [[ "$ec" -ne 0 ]]; then _comm_print_error "$meta" "entry not found"; exit 1; fi
  local source_ref uuid
  source_ref="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('source_ref',''))" "$meta" 2>/dev/null)"
  if [[ "$source_ref" != *".task."* ]]; then
    log_error "refresh only applies to task entries (got: $source_ref)"
    exit 1
  fi
  uuid="${source_ref##*.task.}"
  local tmp
  tmp="$(mktemp)"
  task rc.confirmation=no "$uuid" export >"$tmp" 2>/dev/null || true
  if ! grep -q '"uuid"' "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    log_error "Task not found or export failed for uuid $uuid"
    exit 1
  fi
  local out
  set +e; out="$(_comm_store_cli refresh-entry "$comm" "$eid" "$tmp")"; ec=$?; set -e
  rm -f "$tmp"
  [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]] && { echo "$out"; return $ec; }
  if [[ "$ec" -ne 0 ]]; then _comm_print_error "$out" "refresh failed"; exit 1; fi
  log_success "Entry $eid refreshed with current task state"
}

cmd_move() {
  local eid="${1:-}" from="${2:-}" to="${3:-}"
  if [[ -z "$eid" || -z "$from" || -z "$to" ]] || ! [[ "$eid" =~ ^[0-9]+$ ]]; then
    log_error "Usage: ww community move <entry-id> <from-community> <to-community>"
    exit 1
  fi
  validate_community_name "$from" || exit 1
  validate_community_name "$to" || exit 1
  local out ec=0
  set +e; out="$(_comm_store_cli move-entry "$eid" "$from" "$to")"; ec=$?; set -e
  [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]] && { echo "$out"; return $ec; }
  if [[ "$ec" -ne 0 ]]; then _comm_print_error "$out" "move failed"; exit 1; fi
  log_success "Moved entry $eid from '$from' to '$to'"
}

cmd_recent() {
  local n="${1:-10}"
  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    log_error "Usage: ww community recent [n]  (default 10)"
    exit 1
  fi
  _comm_require_ww_base || exit 1
  if [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]]; then
    _comm_store_cli recent "$n"
    return 0
  fi
  local out
  out="$(_comm_store_cli recent "$n")"
  python3 -c "
import json, sys
d = json.loads(sys.argv[1])
rows = d.get('entries') or []
if not rows:
    print('  (no recent entries)')
else:
    for e in rows:
        tag = ('[archived]' if e.get('archived') else '')
        parts = [e['added_at'][:16], e['community_name'], str(e['id']), e['source_ref']]
        if e.get('community_project'): parts.append('project:' + e['community_project'])
        if e.get('community_priority'): parts.append('!' + e['community_priority'])
        print('  ' + '  '.join(parts))
" "$out"
}

cmd_comment() {
  local eid="${1:-}" body="${2:-}"
  if [[ -z "$eid" || -z "$body" ]] || ! [[ "$eid" =~ ^[0-9]+$ ]]; then
    log_error "Usage: ww community comment <entry-id> <text> [--copy-back]"
    exit 1
  fi
  _comm_require_ww_base || exit 1
  local copy_back=0
  [[ "${*}" == *"--copy-back"* ]] && copy_back=1
  local out ec=0
  set +e; out="$(_comm_store_cli add-comment "$eid" "$body")"; ec=$?; set -e
  if [[ "$ec" -ne 0 ]]; then _comm_print_error "$out" "comment failed"; exit 1; fi

  if [[ "$copy_back" -eq 1 ]]; then
    local meta
    set +e; meta="$(_comm_store_cli entry-meta "$eid")"; ec=$?; set -e
    local source_ref
    source_ref="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('source_ref',''))" "$meta" 2>/dev/null)"
    if [[ "$source_ref" == *".task."* ]]; then
      local uuid src_profile t_base t_taskrc t_taskdata
      uuid="${source_ref##*.task.}"
      src_profile="${source_ref%%.*}"
      t_base="$COMM_WW_BASE/profiles/$src_profile"
      t_taskrc="$t_base/.taskrc"
      t_taskdata="$t_base/.task"
      if [[ -f "$t_taskrc" ]]; then
        local ann_text="community: $body"
        TASKRC="$t_taskrc" TASKDATA="$t_taskdata" task rc.confirmation=no "$uuid" annotate "$ann_text" 2>/dev/null && {
          local comment_id
          comment_id="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('comment_id',''))" "$out" 2>/dev/null)"
          [[ -n "$comment_id" ]] && _comm_store_cli mark-copied "$comment_id" >/dev/null 2>&1
        } || log_error "Warning: could not annotate task $uuid (profile '$src_profile' may not be active)"
      else
        log_error "Warning: could not copy back — profile '$src_profile' taskrc not found at $t_taskrc"
      fi
    else
      log_error "Warning: --copy-back only applies to task entries (source: $source_ref)"
    fi
  fi

  [[ "${WW_OUTPUT_MODE:-compact}" == "json" ]] && { echo "$out"; return 0; }
  local comment_id
  comment_id="$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('comment_id',''))" "$out" 2>/dev/null)"
  log_success "Comment #${comment_id} added to entry $eid${copy_back:+ (copied back to task)}"
}

cmd_export() {
  local name="${1:-}"
  if [[ "$name" == "--help" || "$name" == "-h" ]]; then
    printf 'Usage: ww community export <name>\n\nExport requires the warrior service (TASK-COMM-009).\n'
    return 0
  fi
  if [[ -z "$name" ]]; then
    log_error "Usage: ww community export <name>"
    exit 1
  fi
  log_error "community export requires the warrior service (not yet available — TASK-COMM-009)"
  exit 1
}

action="${1:-}"
shift 2>/dev/null || true

case "$action" in
  ""|help|-h|--help)
    cat << 'EOF'
Community — global shared collections (not per-profile)

Database: $WW_BASE/.community/community.db

Usage:
  ww community list [--all]
  ww community show <name>
  ww community create <name>
  ww community describe <name> <description>
  ww community rename <old-name> <new-name>
  ww community archive <name>
  ww community unarchive <name>
  ww community add <name> task <uuid> [--tags x] [--priority H|M|L] [--project p]
  ww community add <name> journal <YYYY-MM-DD_HH-MM>
  ww community comment <entry-id> <text> [--copy-back]
  ww community modify <entry-id> [--tags x] [--priority H|M|L] [--project p]
  ww community refresh <community> <entry-id>
  ww community move <entry-id> <from> <to>
  ww community recent [n]
  ww community remove <name> <entry-id>
  ww community export <name>

Add --help to any subcommand for details.
EOF
    ;;
  list)    cmd_list "${1:-}" ;;
  show)    cmd_show "${1:-}" ;;
  create)  cmd_create "${1:-}" ;;
  describe) cmd_describe "${1:-}" "${2:-}" ;;
  rename)  cmd_rename "${1:-}" "${2:-}" ;;
  archive) cmd_archive "${1:-}" ;;
  unarchive) cmd_unarchive "${1:-}" ;;
  comment) cmd_comment "${1:-}" "${2:-}" "${3:-}" ;;
  modify)  cmd_modify_entry "$@" ;;
  refresh) cmd_refresh "${1:-}" "${2:-}" ;;
  move)    cmd_move "${1:-}" "${2:-}" "${3:-}" ;;
  recent)  cmd_recent "${1:-10}" ;;
  add)
    comm="${1:-}"
    kind="${2:-}"
    if [[ "$comm" == "--help" || "$comm" == "-h" ]]; then
      cat << 'EOF'
Usage: ww community add <name> task <uuid> [--tags x] [--priority H] [--project p]
       ww community add <name> journal <YYYY-MM-DD_HH-MM>

Examples:
  ww community add my-project task abc123-uuid --priority H --project sprint
  ww community add my-project journal 2026-04-22_14-30
EOF
    else
      shift 2 2>/dev/null || true
      case "$kind" in
        task)    cmd_add_task "$comm" "${1:-}" ;;
        journal) cmd_add_journal "$comm" "${1:-}" ;;
        *)
          log_error "Usage: ww community add <community> task <uuid> | journal <slug>"
          exit 1
          ;;
      esac
    fi
    ;;
  remove)
    cmd_remove "${1:-}" "${2:-}"
    ;;
  export)
    cmd_export "${1:-}"
    ;;
  *)
    log_error "Unknown community action: $action"
    echo "Run: ww community help"
    exit 1
    ;;
esac
