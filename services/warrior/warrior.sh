#!/usr/bin/env bash
# services/warrior/warrior.sh — ww warrior: cross-profile task aggregation + community management
set -euo pipefail

WW_BASE="${WW_BASE:-$HOME/ww}"
WW_LIB="${WW_LIB:-$WW_BASE/lib}"
STORE_PY="$WW_BASE/services/community/community_store.py"

show_help() {
  cat <<'EOF'
Warrior — cross-profile meta-control plane

Usage: ww warrior [subcommand] [args]

Subcommands:
  summary                    Aggregate pending/active task counts across all profiles (default)
  profiles                   List all profiles with their tool configuration status
  hooks                      List active on-modify/on-add hooks for the active profile
  report <name>              Run a named task report for the active profile
  read task <profile> <id>   Read a task from a named profile without switching
  read journal <profile> <slug>  Read a journal entry from a named profile
  community list             List communities with entry counts
  community export <name>    Export a community to shareable markdown
  community show <name>      Show community entries (same as: ww community show <name>)

Examples:
  ww warrior
  ww warrior profiles
  ww warrior read task work abc123
  ww warrior community list
  ww warrior community export my-project
EOF
}

_source_registry() {
  local reg="$WW_LIB/warrior-profile-registry.sh"
  if [[ ! -f "$reg" ]]; then
    echo "warrior: lib/warrior-profile-registry.sh not found at $reg" >&2; exit 1
  fi
  # shellcheck source=/dev/null
  source "$reg"
}

_require_ww_base() {
  if [[ ! -d "$WW_BASE/profiles" ]]; then
    echo "warrior: no profiles directory at $WW_BASE/profiles" >&2; exit 1
  fi
}

cmd_summary() {
  _require_ww_base
  local total_pending=0 total_active=0
  printf "  %-22s  %7s  %7s  %s\n" "Profile" "Pending" "Active" "Top task"
  printf "  %-22s  %7s  %7s\n" "-------" "-------" "------"
  for pdir in "$WW_BASE/profiles"/*/; do
    local pname taskrc taskdata pending active top_task
    pname=$(basename "$pdir")
    taskrc="$pdir.taskrc"
    taskdata="$pdir.task"
    [[ -f "$taskrc" && -d "$taskdata" ]] || continue
    pending=$(TASKRC="$taskrc" TASKDATA="$taskdata" task count status:pending 2>/dev/null || echo 0)
    active=$(TASKRC="$taskrc" TASKDATA="$taskdata" task count status:active 2>/dev/null || echo 0)
    top_task=$(TASKRC="$taskrc" TASKDATA="$taskdata" task rc.verbose=nothing limit:1 2>/dev/null | tail -1 | sed 's/^[0-9 ]*//' | cut -c1-40 || true)
    total_pending=$(( total_pending + pending ))
    total_active=$(( total_active + active ))
    printf "  %-22s  %7s  %7s  %s\n" "$pname" "$pending" "$active" "${top_task:-}"
  done
  printf "  %-22s  %7s  %7s\n" "-------" "-------" "------"
  printf "  %-22s  %7s  %7s\n" "TOTAL" "$total_pending" "$total_active"
}

cmd_profiles() {
  _source_registry
  _require_ww_base
  echo "Profiles ($WW_BASE/profiles):"
  warrior_list_profiles | while IFS= read -r line; do printf "  %s\n" "$line"; done
}

cmd_hooks() {
  if [[ -z "${WARRIOR_PROFILE:-}" ]]; then
    echo "warrior hooks: no active profile" >&2; exit 1
  fi
  local hooks_dir="${WW_BASE}/profiles/${WARRIOR_PROFILE}/.task/hooks"
  if [[ ! -d "$hooks_dir" ]]; then
    echo "No hooks directory at $hooks_dir"
    return 0
  fi
  echo "Hooks — $WARRIOR_PROFILE:"
  local found=0
  for hook in "$hooks_dir"/on-*; do
    [[ -f "$hook" ]] || continue
    found=1
    local name type
    name=$(basename "$hook")
    type=$(head -1 "$hook" 2>/dev/null | grep -o 'bash\|python\|sh\|python3' || echo "script")
    printf "  %-30s  %s\n" "$name" "$type"
  done
  [[ $found -eq 0 ]] && echo "  (no hooks installed)"
}

cmd_report() {
  local name="${1:-next}"
  if [[ -z "${WARRIOR_PROFILE:-}" ]]; then
    echo "warrior report: no active profile" >&2; exit 1
  fi
  TASKRC="$TASKRC" TASKDATA="$TASKDATA" task report "$name" "$@"
}

cmd_read() {
  _source_registry
  local kind="${1:-}"; shift 2>/dev/null || true
  case "$kind" in
    task)
      local profile="${1:-}" uuid="${2:-}"
      [[ -n "$profile" && -n "$uuid" ]] || { echo "Usage: ww warrior read task <profile> <uuid|id>" >&2; exit 1; }
      warrior_read_task "$profile" "$uuid"
      ;;
    journal)
      local profile="${1:-}" slug="${2:-}"
      [[ -n "$profile" && -n "$slug" ]] || { echo "Usage: ww warrior read journal <profile> <date-slug>" >&2; exit 1; }
      warrior_read_journal "$profile" "$slug"
      ;;
    *)
      echo "warrior read: kind must be 'task' or 'journal'" >&2; exit 1
      ;;
  esac
}

cmd_community() {
  local sub="${1:-list}"; shift 2>/dev/null || true
  if [[ ! -f "$STORE_PY" ]]; then
    echo "warrior community: community_store not found at $STORE_PY" >&2; exit 1
  fi
  case "$sub" in
    list)
      local out
      out=$(python3 "$STORE_PY" list "$WW_BASE" 2>/dev/null) || { echo "warrior: community list failed" >&2; exit 1; }
      # Parse JSON and format
      python3 - "$out" <<'PYEOF'
import sys, json
try:
    data = json.loads(sys.argv[1])
    communities = data.get("communities", [])
    if not communities:
        print("  (no communities)")
    else:
        print(f"  {'Community':<25}  {'Entries':>7}  Description")
        print(f"  {'-'*25}  {'-'*7}")
        for c in communities:
            desc = (c.get("description") or "")[:40]
            print(f"  {c['name']:<25}  {c.get('entry_count',0):>7}  {desc}")
except Exception as e:
    print(f"  (parse error: {e})")
PYEOF
      ;;
    export)
      local name="${1:-}"
      [[ -n "$name" ]] || { echo "Usage: ww warrior community export <name>" >&2; exit 1; }
      local out
      out=$(python3 "$STORE_PY" show "$WW_BASE" "$name" 2>/dev/null) || { echo "warrior: community show failed" >&2; exit 1; }
      python3 - "$name" "$out" <<'PYEOF'
import sys, json, datetime
name, raw = sys.argv[1], sys.argv[2]
try:
    data = json.loads(raw)
    entries = data.get("entries", [])
except Exception:
    entries = []
print(f"# Community: {name}")
print(f"*Exported {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}*\n")
for e in entries:
    cap = e.get("captured_state", {}) if isinstance(e.get("captured_state"), dict) else {}
    ref = e.get("source_ref", "")
    kind = "task" if ".task." in ref else "journal" if ".journal." in ref else "entry"
    desc = cap.get("description") or cap.get("body") or ref
    print(f"## {kind.capitalize()}: {desc[:80]}")
    print(f"*source: {ref}*\n")
    for c in e.get("comments", []):
        ts = c.get("created_at", "")[:16]
        print(f"- [{ts}] {c.get('body','')}")
    print()
PYEOF
      ;;
    show)
      local name="${1:-}"
      [[ -n "$name" ]] || { echo "Usage: ww warrior community show <name>" >&2; exit 1; }
      # Delegate to community.sh
      bash "$WW_BASE/services/community/community.sh" show "$name"
      ;;
    *)
      echo "warrior community: unknown subcommand '$sub' (list|export|show)" >&2; exit 1
      ;;
  esac
}

main() {
  local sub="${1:-summary}"
  shift 2>/dev/null || true
  case "$sub" in
    summary)    cmd_summary ;;
    profiles)   cmd_profiles ;;
    hooks)      cmd_hooks ;;
    report)     cmd_report "$@" ;;
    read)       cmd_read "$@" ;;
    community)  cmd_community "$@" ;;
    help|-h|--help) show_help ;;
    *)
      echo "warrior: unknown subcommand '$sub'" >&2
      show_help >&2
      exit 1
      ;;
  esac
}

main "$@"
