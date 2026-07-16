# ww-popup-screens/render-clock.sh — Clock screen renderer (rofi-script mode)

render_clock() {
  _init_profile
  local twdb; twdb="$(profile_twdb)"

  # Get current tracking state
  local timew_out state desc duration
  if [[ -d "$twdb" ]]; then
    timew_out=$(TIMEWARRIORDB="$twdb" timew 2>/dev/null) || timew_out=""
  fi

  local first_line="${timew_out%%$'\n'*}"
  local status_msg
  if [[ "$first_line" == Tracking* ]]; then
    state="tracking"
    desc=$(echo "$first_line" | sed 's/^Tracking //;s/"//g;s/ *$//')
    duration=$(echo "$timew_out" | grep -oE '[0-9]+:[0-9]{2}:[0-9]{2}' | head -1)
    status_msg="▶ Tracking: ${desc} (${duration:-...})"
  else
    state="idle"
    status_msg="⏸ Not tracking"
  fi

  emit_prompt "🕐 Clock"
  emit_message "$status_msg"
  emit_data "clock"
  emit_allow_custom
  emit_hotkeys

  # Main actions
  if [[ "$state" == "tracking" ]]; then
    emit_row_active "⏹️  Clock Out" "act:clock_out"
    emit_row "🔄  Switch Activity" "nav:clock_input:switch" "switch change"
  else
    emit_row "▶️  Clock In (type activity or select below)" "nav:clock_input:start" "clock start begin"
  fi

  emit_row "⏪  Log Past Interval" "nav:clock_past" "past backfill log"

  # Recents
  local recents
  recents=$(get_recents)
  if [[ -n "$recents" ]]; then
    emit_sep
    emit_label "Recent activities:"
    while IFS= read -r recent; do
      [[ -n "$recent" ]] && emit_row "  ⏱️  ${recent}" "pick:recent:${recent}" "$recent"
    done <<< "$recents"
  fi

  # Today summary + intervals
  emit_sep
  emit_row "📊  View Today's Summary" "nav:clock_summary"
  emit_row "📋  Today's Intervals (detail)" "nav:clock_intervals"
  emit_row "← Home" "nav:home"
}

render_clock_input() {
  local mode="$1"  # "start" or "switch"
  _init_profile

  local prompt_text
  [[ "$mode" == "switch" ]] && prompt_text="New activity" || prompt_text="Activity"

  emit_prompt "$prompt_text"
  emit_message "Type what you're working on, then press Enter"
  emit_data "clock_input:${mode}"
  emit_allow_custom
  emit_hotkeys

  # Show recents as suggestions
  local recents
  recents=$(get_recents)
  if [[ -n "$recents" ]]; then
    while IFS= read -r recent; do
      [[ -n "$recent" ]] && emit_row "$recent" "act:clock_in:${recent}"
    done <<< "$recents"
  fi

  emit_sep
  emit_row "← Back to Clock" "nav:clock"
}

render_clock_summary() {
  _init_profile
  local twdb; twdb="$(profile_twdb)"

  emit_prompt "📊 Today"
  emit_message "Time tracked today"
  emit_data "clock"
  emit_hotkeys

  local summary
  summary=$(TIMEWARRIORDB="$twdb" timew summary :day 2>/dev/null)
  if [[ -n "$summary" ]]; then
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$summary"
  else
    emit_label "(no time tracked today)"
  fi

  emit_sep
  emit_row "← Back to Clock" "nav:clock"
}

render_clock_past() {
  _init_profile

  emit_prompt "Log Past"
  emit_message "Format: duration activity (e.g. '30min coding' or '1h meeting')"
  emit_data "clock_past"
  emit_allow_custom
  emit_hotkeys

  emit_label "Examples:"
  emit_row "  30min meeting" "act:clock_track:30min meeting"
  emit_row "  1h coding" "act:clock_track:1h coding"
  emit_row "  2h30min deep work" "act:clock_track:2h30min deep work"
  emit_sep
  emit_row "← Back to Clock" "nav:clock"
}

render_clock_intervals() {
  _init_profile
  local twdb; twdb="$(profile_twdb)"

  emit_prompt "📋 Intervals"
  emit_message "Today's tracked intervals"
  emit_data "clock"
  emit_hotkeys

  local output
  output=$(TIMEWARRIORDB="$twdb" timew export :day 2>/dev/null | python3 -c '
import json, sys
try:
    intervals = json.load(sys.stdin)
except:
    sys.exit(0)
for iv in intervals:
    start = iv.get("start","")[:16].replace("T"," ")
    end = iv.get("end","")[:16].replace("T"," ") if iv.get("end") else "now"
    tags = " ".join(iv.get("tags",[]))
    print(f"  {start} → {end}  [{tags}]")
' 2>/dev/null)

  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no intervals today)"
  fi

  emit_sep
  emit_row "← Back to Clock" "nav:clock"
}
