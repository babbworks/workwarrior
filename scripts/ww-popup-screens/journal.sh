# ww-popup-screens/journal.sh — Journal screen (direct file write + jrnl read with ANSI strip)

screen_journal() {
  popup_require_profile || return

  local cfg
  cfg="$(popup_jrnl_cfg)"

  # Get journal names
  local journal_names
  journal_names=$(awk '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && /^  [a-zA-Z]/{gsub(/^ +/,""); gsub(/:.*$/,""); print}' "$cfg" 2>/dev/null)

  # Get recent entries (short form, ANSI stripped)
  local recent_entries
  recent_entries=$(jrnl --config-file "$cfg" --short -n 10 2>/dev/null | popup_strip_ansi) || recent_entries=""

  local ctx
  ctx="$(popup_context_bar)"

  local menu="✏️  New Entry
🔍  Search
📓  Switch Journal
${SEP}"

  if [[ -n "$recent_entries" ]]; then
    menu="${menu}
${recent_entries}"
  else
    menu="${menu}
(no entries)"
  fi

  local choice
  choice=$(echo "$menu" | popup_select "📓 Journal" "$ctx") || return

  popup_is_sep "$choice" && { screen_journal; return; }

  case "$choice" in
    *"New Entry"*)
      _journal_new_entry
      screen_journal; return
      ;;
    *"Search"*)
      _journal_search
      screen_journal; return
      ;;
    *"Switch Journal"*)
      _journal_switch "$journal_names"
      screen_journal; return
      ;;
    "(no entries)")
      screen_journal; return
      ;;
    *)
      # Entry selected — try to view it
      # Format is "YYYY-MM-DD HH:MM Title"
      local entry_date
      entry_date=$(echo "$choice" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
      if [[ -n "$entry_date" ]]; then
        _journal_view_entry "$entry_date"
      fi
      screen_journal; return
      ;;
  esac
}

_journal_new_entry() {
  local text
  text=$(popup_input "Journal entry (Title. Body text)") || return
  [[ -z "$text" ]] && return

  # Use direct file write (browser approach) to avoid jrnl interactive issues
  local journal_file
  journal_file="$(popup_journal_file)"
  if [[ -n "$journal_file" && -f "$journal_file" ]]; then
    printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$text" >> "$journal_file"
    popup_notify "Journal entry added"
  else
    # Fallback to jrnl CLI
    local cfg
    cfg="$(popup_jrnl_cfg)"
    jrnl --config-file "$cfg" "$text" 2>/dev/null
    popup_notify "Journal entry added"
  fi
}

_journal_search() {
  local query
  query=$(popup_input "Search journal") || return
  [[ -z "$query" ]] && return

  local cfg results
  cfg="$(popup_jrnl_cfg)"
  results=$(jrnl --config-file "$cfg" --short -contains "$query" 2>/dev/null | popup_strip_ansi) || results=""

  if [[ -n "$results" ]]; then
    local selected
    selected=$(echo "$results" | popup_display "Search: ${query}" "" "$results") || return
    # If user selects an entry, try to view it
    local entry_date
    entry_date=$(echo "$selected" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
    [[ -n "$entry_date" ]] && _journal_view_entry "$entry_date"
  else
    popup_notify "No results for: $query"
  fi
}

_journal_switch() {
  local journal_names="$1"
  [[ -z "$journal_names" ]] && { popup_notify "No journals found"; return; }

  local selected
  selected=$(echo "$journal_names" | popup_select "Journal") || return
  [[ -z "$selected" ]] && return

  # Ask what to do with the selected journal
  local action
  action=$(printf "✏️  New entry to %s\n📖  View recent from %s" "$selected" "$selected" | popup_select "$selected") || return

  local cfg
  cfg="$(popup_jrnl_cfg)"

  case "$action" in
    *"New entry"*)
      local text
      text=$(popup_input "Entry for ${selected}") || return
      [[ -z "$text" ]] && return
      # Use direct file write for the specific journal
      local journal_file
      journal_file="$(popup_journal_file "$selected")"
      if [[ -n "$journal_file" && -f "$journal_file" ]]; then
        printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$text" >> "$journal_file"
        popup_notify "Entry added to ${selected}"
      else
        # Fallback: jrnl CLI — journal name BEFORE --config-file
        jrnl "$selected" --config-file "$cfg" "$text" 2>/dev/null
        popup_notify "Entry added to ${selected}"
      fi
      ;;
    *"View recent"*)
      local entries
      entries=$(jrnl "$selected" --config-file "$cfg" --short -n 10 2>/dev/null | popup_strip_ansi) || entries=""
      if [[ -n "$entries" ]]; then
        popup_display "$selected" "" "$entries" || true
      else
        popup_notify "No entries in ${selected}"
      fi
      ;;
  esac
}

_journal_view_entry() {
  local entry_date="$1"
  local cfg
  cfg="$(popup_jrnl_cfg)"
  local content
  content=$(jrnl --config-file "$cfg" -on "$entry_date" 2>/dev/null | popup_strip_ansi) || content=""
  if [[ -n "$content" ]]; then
    popup_display "Entry: ${entry_date}" "" "$content" || true
  else
    popup_notify "No entry found for ${entry_date}"
  fi
}
