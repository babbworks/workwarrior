# ww-popup-screens/home.sh — Home screen with all items on one page + input routing

screen_home() {
  popup_require_profile || { screen_profile; return; }

  local ctx
  ctx="$(popup_context_bar)"

  local items="🕐  Clock In / Out
📋  My Tasks
📝  My Lists
🔍  Search
${SEP}
📓  Journal
💰  Ledger
👥  Board (Who's In)
📊  Reports
🤝  Community
${SEP}
🔄  Switch Profile
🔗  GitHub Sync
⚙️  System"

  local choice
  choice=$(echo "$items" | popup_select "ww" "$ctx") || return

  # Check for separator
  popup_is_sep "$choice" && { screen_home; return; }

  # Handle input routing (user typed something)
  case "$choice" in
    .*)
      # Task add: .text → task add "text"
      _home_route_task_add "${choice#.}"
      screen_home; return
      ;;
    ">>"*)
      # Timew stop
      _home_route_timew_stop
      screen_home; return
      ;;
    ">"*)
      # Timew start: >text → timew start "text"
      _home_route_timew_start "${choice#>}"
      screen_home; return
      ;;
    "@"*)
      # Journal entry: @text
      _home_route_journal "${choice#@}"
      screen_home; return
      ;;
    '$'*)
      # Ledger: $amount account
      _home_route_ledger "${choice#\$}"
      screen_home; return
      ;;
    "?"*)
      # Search: ?query
      _home_route_search "${choice#?}"
      screen_home; return
      ;;
    "!"*)
      # Profile switch: !name or bare ! for picker
      _home_route_profile "${choice#!}"
      screen_home; return
      ;;
    "#"*)
      # Filter by tag
      _home_route_tag_filter "${choice#\#}"
      screen_home; return
      ;;
    "/"*)
      # Pass-through ww command: /command
      _home_route_ww_command "${choice#/}"
      screen_home; return
      ;;
  esac

  # Handle menu selections
  case "$choice" in
    *"Clock"*)       screen_clock; screen_home; return ;;
    *"Tasks"*)       screen_tasks; screen_home; return ;;
    *"Lists"*)       screen_lists; screen_home; return ;;
    *"Search"*)      screen_search; screen_home; return ;;
    *"Journal"*)     screen_journal; screen_home; return ;;
    *"Ledger"*)      screen_ledger; screen_home; return ;;
    *"Board"*)       screen_board; screen_home; return ;;
    *"Reports"*)     screen_reports; screen_home; return ;;
    *"Community"*)   screen_community; screen_home; return ;;
    *"Profile"*)     screen_profile; screen_home; return ;;
    *"Sync"*)        screen_sync; screen_home; return ;;
    *"System"*)      screen_system; screen_home; return ;;
    *)
      # Bare text → add to current list
      if [[ -n "$choice" ]]; then
        _home_route_list_add "$choice"
      fi
      screen_home; return
      ;;
  esac
}

# --- Input routing helpers ---

_home_route_task_add() {
  local desc="$1"
  [[ -z "$desc" ]] && return
  local rc data
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"
  TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no add "$desc" 2>/dev/null
  popup_notify "Task added: $desc"
}

_home_route_timew_start() {
  local activity="$1"
  [[ -z "$activity" ]] && return
  local base
  base="$(popup_profile_base)"
  TIMEWARRIORDB="${base}/.timewarrior" timew start "$activity" 2>/dev/null
  popup_add_recent "$activity"
  popup_notify "Tracking: $activity"
}

_home_route_timew_stop() {
  local base
  base="$(popup_profile_base)"
  TIMEWARRIORDB="${base}/.timewarrior" timew stop 2>/dev/null
  popup_notify "Timer stopped"
}

_home_route_journal() {
  local text="$1"
  [[ -z "$text" ]] && return
  local journal_file
  journal_file="$(popup_journal_file)"
  if [[ -n "$journal_file" ]]; then
    printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$text" >> "$journal_file"
    popup_notify "Journal entry added"
  else
    local cfg
    cfg="$(popup_jrnl_cfg)"
    jrnl --config-file "$cfg" "$text" 2>/dev/null
    popup_notify "Journal entry added"
  fi
}

_home_route_ledger() {
  local input="$1"
  [[ -z "$input" ]] && return
  # Parse: amount rest (rest becomes description)
  local amount desc
  amount=$(echo "$input" | awk '{print $1}')
  desc=$(echo "$input" | awk '{$1=""; sub(/^ /,""); print}')
  [[ -z "$desc" ]] && desc="Quick expense"
  # Ask for account
  local accounts account source
  accounts="$(popup_get_accounts)"
  account=$(echo "$accounts" | popup_select "Expense account") || return
  source=$(echo "$accounts" | popup_select "Source account") || return
  local ledger_file
  ledger_file="$(popup_ledger_file)"
  [[ -z "$ledger_file" ]] && { popup_notify "No ledger file found"; return; }
  printf '\n%s %s\n    %s  $%s\n    %s\n' \
    "$(date '+%Y-%m-%d')" "$desc" "$account" "$amount" "$source" >> "$ledger_file"
  popup_notify "Transaction logged: \$$amount"
}

_home_route_search() {
  local query="$1"
  [[ -z "$query" ]] && return
  screen_search "$query"
}

_home_route_profile() {
  local name="$1"
  if [[ -z "$name" ]]; then
    screen_profile
  else
    echo "$name" > "${STATE_DIR}/last-profile"
    popup_notify "Switched to profile: $name"
  fi
}

_home_route_tag_filter() {
  local tag="$1"
  [[ -z "$tag" ]] && return
  local list_dir list_name
  list_dir="$(popup_list_dir)"
  list_name="$(popup_current_list)"
  local profile
  profile="$(popup_active_profile)"
  local output
  output=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -g "#${tag}" 2>/dev/null)
  [[ -n "$output" ]] && popup_display "Tag: #${tag}" "" "$output" || return
}

_home_route_ww_command() {
  local cmd="$1"
  [[ -z "$cmd" ]] && return
  local output
  output=$(ww $cmd 2>&1) || true
  [[ -n "$output" ]] && popup_display "ww $cmd" "" "$output" || return
}

_home_route_list_add() {
  local text="$1"
  [[ -z "$text" ]] && return
  local list_dir list_name
  list_dir="$(popup_list_dir)"
  list_name="$(popup_current_list)"
  python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -q "$text" 2>/dev/null
  popup_notify "Added to ${list_name}: $text"
}
