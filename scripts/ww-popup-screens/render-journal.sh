# ww-popup-screens/render-journal.sh — Journal screen renderer (full functionality)

render_journal() {
  _init_profile
  local cfg; cfg="$(profile_jrnl_cfg)"

  # Get journal names
  local journals=""
  if [[ -f "$cfg" ]]; then
    journals=$(awk '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && /^  [a-zA-Z]/{gsub(/^ +/,""); gsub(/:.*$/,""); print}' "$cfg")
  fi
  local current_journal
  current_journal=$(echo "$journals" | head -1)

  emit_prompt "📓 Journal"
  emit_message "Active: ${current_journal:-default}  |  @text to add entry"
  emit_data "journal"
  emit_allow_custom
  emit_hotkeys

  # Actions
  emit_row "✏️  New Entry" "nav:journal_add" "add write new entry"
  if [[ $(echo "$journals" | wc -l) -gt 1 ]]; then
    emit_row "📚  Switch Journal" "nav:journal_picker" "switch journal"
  fi
  emit_row "🔍  Search" "nav:journal_search" "search find"

  emit_sep

  # Read recent entries from file (fast — avoids jrnl 227ms startup)
  local jfile
  jfile=$(_resolve_journal_file)

  if [[ -n "$jfile" && -f "$jfile" ]]; then
    local entries
    entries=$(grep -n -E '^\[20[0-9]{2}-' "$jfile" 2>/dev/null | tail -15 | tac)
    if [[ -n "$entries" ]]; then
      while IFS= read -r line; do
        # line format: "linenum:[YYYY-MM-DD HH:MM] Title text"
        local lineno="${line%%:*}"
        local entry="${line#*:}"
        local date_part="${entry:0:17}"  # [YYYY-MM-DD HH:MM]
        local title="${entry:18}"
        emit_row "${date_part} ${title}" "pick:journal_entry:${lineno}" "$title $date_part"
      done <<< "$entries"
    else
      emit_label "(no entries)"
    fi
  else
    emit_label "(journal file not found)"
  fi

  emit_sep
  emit_row "← Home" "nav:home"
}

render_journal_add() {
  _init_profile
  local cfg; cfg="$(profile_jrnl_cfg)"

  # Get journal names for display
  local journals=""
  if [[ -f "$cfg" ]]; then
    journals=$(awk '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && /^  [a-zA-Z]/{gsub(/^ +/,""); gsub(/:.*$/,""); print}' "$cfg")
  fi

  emit_prompt "New entry"
  emit_message "Type entry text. First sentence (ending with .) becomes title."
  emit_data "journal_add"
  emit_allow_custom
  emit_hotkeys

  # Show named journals as options for targeted entry
  if [[ -n "$journals" ]]; then
    emit_label "Or select a journal to write to:"
    while IFS= read -r jname; do
      [[ -n "$jname" ]] && emit_row "  → ${jname}" "nav:journal_add_named:${jname}"
    done <<< "$journals"
  fi

  emit_sep
  emit_row "← Back" "nav:journal"
}

render_journal_add_named() {
  local jname="$1"

  emit_prompt "📓 ${jname}"
  emit_message "Type entry for journal: ${jname}"
  emit_data "journal_add_named:${jname}"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type entry above and press Enter)"
  emit_sep
  emit_row "← Back" "nav:journal"
}

render_journal_entry() {
  local lineno="$1"
  _init_profile
  local jfile; jfile=$(_resolve_journal_file)

  emit_prompt "Entry"
  emit_data "journal"
  emit_hotkeys

  if [[ -n "$jfile" && -f "$jfile" ]]; then
    # Read from lineno until next entry or EOF
    local content
    content=$(awk -v start="$lineno" '
      NR == start { found=1 }
      NR > start && /^\[20[0-9][0-9]-/ { exit }
      found { print }
    ' "$jfile")

    if [[ -n "$content" ]]; then
      local title
      title=$(echo "$content" | head -1)
      emit_message "$title"
      while IFS= read -r line; do
        emit_label "$line"
      done <<< "$content"
    else
      emit_label "(entry not found)"
    fi
  fi

  emit_sep
  emit_row "← Back to Journal" "nav:journal"
}

render_journal_picker() {
  _init_profile
  local cfg; cfg="$(profile_jrnl_cfg)"

  emit_prompt "Journals"
  emit_message "Select journal to view"
  emit_data "journal"
  emit_hotkeys

  if [[ -f "$cfg" ]]; then
    local journals
    journals=$(awk '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && /^  [a-zA-Z]/{gsub(/^ +/,""); gsub(/:.*$/,""); print}' "$cfg")
    while IFS= read -r jname; do
      [[ -n "$jname" ]] && emit_row "📓  ${jname}" "act:journal_switch:${jname}"
    done <<< "$journals"
  fi

  emit_sep
  emit_row "← Back" "nav:journal"
}

render_journal_search() {
  emit_prompt "Search journal"
  emit_message "Type search term and press Enter"
  emit_data "journal_search"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type query above)"
  emit_sep
  emit_row "← Back" "nav:journal"
}

render_journal_search_results() {
  local query="$1"
  _init_profile
  local jfile; jfile=$(_resolve_journal_file)

  emit_prompt "📓 '${query}'"
  emit_message "Results for: ${query}"
  emit_data "journal"
  emit_hotkeys

  if [[ -n "$jfile" && -f "$jfile" ]]; then
    # Find matching lines with line numbers for navigation
    local results
    results=$(grep -n -i "$query" "$jfile" 2>/dev/null | tail -20)
    if [[ -n "$results" ]]; then
      while IFS= read -r line; do
        local lineno="${line%%:*}"
        local text="${line#*:}"
        emit_row "$text" "pick:journal_entry:${lineno}" "$text"
      done <<< "$results"
    else
      emit_label "(no matches for '${query}')"
    fi
  else
    emit_label "(journal file not found)"
  fi

  emit_sep
  emit_row "← Back" "nav:journal"
}
