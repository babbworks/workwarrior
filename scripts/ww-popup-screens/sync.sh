# ww-popup-screens/sync.sh — GitHub Sync screen

screen_sync() {
  popup_require_profile || return

  local ctx
  ctx="$(popup_context_bar)"

  local menu="📡  Sync Status
🔄  Sync (bidirectional)
⬆️  Push Only
⬇️  Pull Only"

  local choice
  choice=$(echo "$menu" | popup_select "🔗 GitHub Sync" "$ctx") || return

  case "$choice" in
    *"Sync Status"*)
      local output
      output=$(ww issues status 2>&1) || output="(sync not configured)"
      popup_display "Sync Status" "" "$output" || true
      screen_sync; return
      ;;
    *"bidirectional"*)
      local output
      output=$(ww issues sync 2>&1) || output="(sync failed)"
      popup_display "Sync Result" "" "$output" || true
      popup_notify "Sync complete"
      screen_sync; return
      ;;
    *"Push Only"*)
      local output
      output=$(ww issues push 2>&1) || output="(push failed)"
      popup_display "Push Result" "" "$output" || true
      popup_notify "Push complete"
      screen_sync; return
      ;;
    *"Pull Only"*)
      local output
      output=$(ww issues pull 2>&1) || output="(pull failed)"
      popup_display "Pull Result" "" "$output" || true
      popup_notify "Pull complete"
      screen_sync; return
      ;;
    *)
      screen_sync; return
      ;;
  esac
}
