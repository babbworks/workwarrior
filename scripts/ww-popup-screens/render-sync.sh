# ww-popup-screens/render-sync.sh — GitHub Sync screen renderer (full functionality)

render_sync() {
  _init_profile

  emit_prompt "🔗 Sync"
  emit_message "GitHub Issues Sync"
  emit_data "sync"
  emit_hotkeys

  # Show sync status
  local status
  status=$(ww issues status 2>/dev/null | head -5)
  if [[ -n "$status" ]]; then
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$status"
    emit_sep
  fi

  emit_row "🔄  Sync (bidirectional)" "act:sync_run:sync"
  emit_row "⬆️  Push only" "act:sync_run:push"
  emit_row "⬇️  Pull only" "act:sync_run:pull"
  emit_sep
  emit_row "🔗  Enable Link (task↔issue)" "nav:sync_enable"
  emit_row "🚫  Disable Link" "nav:sync_disable"
  emit_sep
  emit_row "← Home" "nav:home"
}

render_sync_enable() {
  _init_profile

  emit_prompt "Enable Link"
  emit_message "Format: task_id issue_number org/repo"
  emit_data "sync_enable"
  emit_allow_custom
  emit_hotkeys

  # Show pending tasks for reference
  local rc data; rc="$(profile_taskrc)"; data="$(profile_taskdata)"
  local tasks
  tasks=$(TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no rc.verbose=nothing \
    status:pending export 2>/dev/null | python3 -c '
import json, sys
try:
    for t in json.load(sys.stdin)[:10]:
        print(f"  {t[\"id\"]}: {t.get(\"description\",\"\")}")
except:
    pass
' 2>/dev/null)

  if [[ -n "$tasks" ]]; then
    emit_label "Pending tasks:"
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$tasks"
  fi

  emit_sep
  emit_row "← Back" "nav:sync"
}

render_sync_disable() {
  _init_profile

  emit_prompt "Disable Link"
  emit_message "Type task ID to unlink from GitHub"
  emit_data "sync_disable"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type task ID above)"
  emit_sep
  emit_row "← Back" "nav:sync"
}
