# ww-popup-screens/render-board.sh — Board/Stream screen renderer (full functionality)

render_board() {
  _init_profile

  emit_prompt "👥 Board"
  emit_message "Stream activity + lenses"
  emit_data "board"
  emit_hotkeys

  emit_row "📡  Stream Status" "nav:stream_status" "status info"
  emit_row "📊  View Lens" "nav:stream_lens_picker" "lens view"

  emit_sep

  # Show recent stream events
  local stream_log="${WW_BASE}/stream/stream.log"
  if [[ -f "$stream_log" ]]; then
    local events
    events=$(tail -15 "$stream_log" 2>/dev/null | tac)
    if [[ -n "$events" ]]; then
      emit_label "Recent events:"
      while IFS= read -r line; do
        [[ -n "$line" ]] && emit_row "  $line" "noop" "$line"
      done <<< "$events"
    else
      emit_label "(no stream events)"
    fi
  else
    # Fallback: today's time summary
    local twdb; twdb="$(profile_twdb)"
    local summary
    summary=$(TIMEWARRIORDB="$twdb" timew summary :day 2>/dev/null | head -10)
    if [[ -n "$summary" ]]; then
      emit_label "Today's time (no stream log):"
      while IFS= read -r line; do
        emit_label "  $line"
      done <<< "$summary"
    else
      emit_label "(no activity)"
    fi
  fi

  emit_sep
  emit_row "← Home" "nav:home"
}

render_stream_status() {
  _init_profile

  emit_prompt "📡 Status"
  emit_data "board"
  emit_hotkeys

  local output
  output=$(ww stream status 2>/dev/null)
  if [[ -n "$output" ]]; then
    emit_message "Stream status"
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(stream not initialized or ww stream unavailable)"
  fi

  emit_sep
  emit_row "← Back" "nav:board"
}

render_stream_lens_picker() {
  emit_prompt "Lens"
  emit_message "Select a lens to view stream through"
  emit_data "board"
  emit_hotkeys

  # Available lenses from dev guide
  emit_row "🕐  Bundy (time clock)" "nav:stream_lens:bundy" "bundy time clock punch"
  emit_row "📋  Frick (task tracking)" "nav:stream_lens:frick" "frick tasks"
  emit_row "📊  Dey (daily summary)" "nav:stream_lens:dey" "dey daily summary"
  emit_row "🏭  Cooper (production)" "nav:stream_lens:cooper" "cooper production"
  emit_row "📇  Hollerith (data cards)" "nav:stream_lens:hollerith" "hollerith data"
  emit_row "💰  Pacioli (accounting)" "nav:stream_lens:pacioli" "pacioli accounting ledger"
  emit_row "📝  Burroughs (records)" "nav:stream_lens:burroughs" "burroughs records"
  emit_row "🧮  Felt (calculation)" "nav:stream_lens:felt" "felt calculation"

  emit_sep
  emit_row "← Back" "nav:board"
}

render_stream_lens() {
  local lens="$1"

  emit_prompt "🔭 ${lens}"
  emit_data "board"
  emit_hotkeys

  local output
  output=$(ww stream view --lens "$lens" 2>/dev/null)
  if [[ -n "$output" ]]; then
    emit_message "Lens: ${lens}"
    while IFS= read -r line; do
      [[ -n "$line" ]] && emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no output from lens '${lens}')"
  fi

  emit_sep
  emit_row "← Back to Lenses" "nav:stream_lens_picker"
  emit_row "← Back to Board" "nav:board"
}
