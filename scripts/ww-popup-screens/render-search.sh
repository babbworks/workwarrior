# ww-popup-screens/render-search.sh — Search screen renderer

render_search() {
  local query="$1"
  _init_profile

  if [[ -z "$query" ]]; then
    # Show search prompt
    emit_prompt "🔍 Search"
    emit_message "Type ?query or enter search term"
    emit_data "search"
    emit_allow_custom
    emit_hotkeys
    emit_label "(type your search above and press Enter)"
    emit_sep
    emit_row "← Home" "nav:home"
    return
  fi

  # Execute cross-tool search
  emit_prompt "🔍 ${query}"
  emit_message "Results for: ${query}"
  emit_data "search:${query}"
  emit_hotkeys

  local found=0

  # Tasks
  local rc data
  rc="$(profile_taskrc)"
  data="$(profile_taskdata)"
  local task_results
  task_results=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no rc.verbose=nothing \
    status:pending "description.contains:${query}" limit:5 export 2>/dev/null | python3 -c "
import json, sys
try:
    tasks = json.load(sys.stdin)
except:
    sys.exit(0)
for t in tasks:
    print(f\"📋 {t.get('id')}: {t.get('description','')}\")
" 2>/dev/null)
  if [[ -n "$task_results" ]]; then
    found=1
    while IFS= read -r line; do
      emit_row "$line" "noop" "$line"
    done <<< "$task_results"
  fi

  # Lists
  local list_dir list_name
  list_dir="$(profile_list_dir)"
  list_name="$(profile_current_list)"
  local list_results
  list_results=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -g "$query" 2>/dev/null | head -5)
  if [[ -n "$list_results" ]]; then
    found=1
    while IFS= read -r line; do
      emit_row "📝 ${line}" "noop"
    done <<< "$list_results"
  fi

  # Journal (direct file grep — fast)
  local jfile
  jfile=$(_resolve_journal_file)
  if [[ -n "$jfile" && -f "$jfile" ]]; then
    local jrnl_results
    jrnl_results=$(LC_ALL=C grep -i "$query" "$jfile" 2>/dev/null | tail -5)
    if [[ -n "$jrnl_results" ]]; then
      found=1
      while IFS= read -r line; do
        emit_row "📓 ${line}" "noop"
      done <<< "$jrnl_results"
    fi
  fi

  # Ledger
  local ledger_file
  ledger_file=$(profile_ledger_file)
  if [[ -n "$ledger_file" && -f "$ledger_file" ]]; then
    local ledger_results
    ledger_results=$(hledger -f "$ledger_file" register "desc:${query}" 2>/dev/null | tail -5)
    if [[ -n "$ledger_results" ]]; then
      found=1
      while IFS= read -r line; do
        emit_row "💰 ${line}" "noop"
      done <<< "$ledger_results"
    fi
  fi

  if (( found == 0 )); then
    emit_label "(no results for '${query}')"
  fi

  emit_sep
  emit_row "← Home" "nav:home"
}
