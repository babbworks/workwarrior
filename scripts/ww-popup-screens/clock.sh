# ww-popup-screens/clock.sh — Clock screen using timew

screen_clock() {
  popup_require_profile || return

  local base
  base="$(popup_profile_base)"
  local twdb="${base}/.timewarrior"

  # Get current state
  local timer_info state desc duration
  timer_info="$(popup_timer_status)"
  state="${timer_info%%|*}"
  local rest="${timer_info#*|}"
  desc="${rest%%|*}"
  duration="${rest#*|}"

  local ctx
  ctx="$(popup_context_bar)"

  # Build status header
  local status_msg
  if [[ "$state" == "tracking" ]]; then
    status_msg="▶ Tracking: ${desc} (${duration})"
  else
    status_msg="⏸ Not tracking"
  fi

  # Get today's summary (compact)
  local today_summary
  today_summary=$(TIMEWARRIORDB="$twdb" timew summary :day 2>/dev/null | head -15) || today_summary=""

  # Build menu
  local menu=""
  if [[ "$state" == "tracking" ]]; then
    menu="⏹️  Clock Out
🔄  Switch Activity"
  else
    menu="▶️  Clock In"
  fi

  # Add recents
  local recents
  recents=$(popup_get_recents)
  if [[ -n "$recents" ]]; then
    menu="${menu}
${SEP}
Recent:"
    while IFS= read -r recent; do
      menu="${menu}
  ⏱️  ${recent}"
    done <<< "$recents"
  fi

  # Add today's summary at bottom
  if [[ -n "$today_summary" ]]; then
    menu="${menu}
${SEP}
📊  View Today's Summary"
  fi

  local choice
  choice=$(echo "$menu" | popup_select "🕐 Clock" "${status_msg}") || return

  popup_is_sep "$choice" && { screen_clock; return; }

  case "$choice" in
    *"Clock Out"*)
      TIMEWARRIORDB="$twdb" timew stop 2>/dev/null
      popup_notify "Clocked out"
      screen_clock; return
      ;;
    *"Clock In"*)
      local activity
      activity=$(popup_input "Activity (what are you working on?)") || { screen_clock; return; }
      [[ -z "$activity" ]] && { screen_clock; return; }
      TIMEWARRIORDB="$twdb" timew start "$activity" 2>/dev/null
      popup_add_recent "$activity"
      popup_notify "Tracking: $activity"
      screen_clock; return
      ;;
    *"Switch"*)
      local activity
      activity=$(popup_input "New activity") || { screen_clock; return; }
      [[ -z "$activity" ]] && { screen_clock; return; }
      TIMEWARRIORDB="$twdb" timew stop 2>/dev/null
      TIMEWARRIORDB="$twdb" timew start "$activity" 2>/dev/null
      popup_add_recent "$activity"
      popup_notify "Switched to: $activity"
      screen_clock; return
      ;;
    *"Today's Summary"*)
      popup_display "Today" "" "$today_summary" || true
      screen_clock; return
      ;;
    *"Recent:"*)
      screen_clock; return
      ;;
    *"⏱️"*)
      # Start a recent activity
      local recent_activity
      recent_activity=$(echo "$choice" | sed 's/.*⏱️  //')
      [[ -z "$recent_activity" ]] && { screen_clock; return; }
      if [[ "$state" == "tracking" ]]; then
        TIMEWARRIORDB="$twdb" timew stop 2>/dev/null
      fi
      TIMEWARRIORDB="$twdb" timew start "$recent_activity" 2>/dev/null
      popup_add_recent "$recent_activity"
      popup_notify "Tracking: $recent_activity"
      screen_clock; return
      ;;
    *)
      screen_clock; return
      ;;
  esac
}
