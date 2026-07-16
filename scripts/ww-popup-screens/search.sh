# ww-popup-screens/search.sh — Cross-tool search

screen_search() {
  popup_require_profile || return

  local query="${1:-}"
  if [[ -z "$query" ]]; then
    query=$(popup_input "Search across all tools") || return
    [[ -z "$query" ]] && return
  fi

  local results=""
  local rc data base cfg ledger_file list_dir list_name
  base="$(popup_profile_base)"
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"
  cfg="$(popup_jrnl_cfg)"
  ledger_file="$(popup_ledger_file)"
  list_dir="$(popup_list_dir)"
  list_name="$(popup_current_list)"

  # Search tasks
  local task_results
  task_results=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no rc.verbose=nothing status:pending "description.contains:${query}" limit:5 export 2>/dev/null | python3 -c "
import json, sys
try:
    tasks = json.load(sys.stdin)
    for t in tasks[:5]:
        print(f\"📋 {t.get('id','?')}: {t.get('description','')}\")
except:
    pass
" 2>/dev/null)
  [[ -n "$task_results" ]] && results="${results}${task_results}\n"

  # Search lists
  local list_results
  list_results=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -g "$query" 2>/dev/null | head -5)
  if [[ -n "$list_results" ]]; then
    while IFS= read -r line; do
      results="${results}📝 ${line}\n"
    done <<< "$list_results"
  fi

  # Search journal (with ANSI strip)
  if [[ -f "$cfg" ]]; then
    local jrnl_results
    jrnl_results=$(jrnl --config-file "$cfg" --short -contains "$query" 2>/dev/null | popup_strip_ansi | head -5)
    if [[ -n "$jrnl_results" ]]; then
      while IFS= read -r line; do
        results="${results}📓 ${line}\n"
      done <<< "$jrnl_results"
    fi
  fi

  # Search ledger
  if [[ -n "$ledger_file" && -f "$ledger_file" ]]; then
    local ledger_results
    ledger_results=$(hledger -f "$ledger_file" register "desc:${query}" 2>/dev/null | head -5)
    if [[ -n "$ledger_results" ]]; then
      while IFS= read -r line; do
        results="${results}💰 ${line}\n"
      done <<< "$ledger_results"
    fi
  fi

  if [[ -z "$results" ]]; then
    popup_notify "No results for: $query"
    return
  fi

  local formatted
  formatted=$(printf "%b" "$results")
  popup_display "🔍 ${query}" "Results across all tools" "$formatted" || true
}
