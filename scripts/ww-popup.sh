#!/usr/bin/env bash
# ww-popup.sh — unified rofi popup launcher for workwarrior
#
# Bare text     → add to current list
# .text         → add TaskWarrior task
# >text         → timew start
# >>            → timew stop
# @text         → jrnl entry
# $posting      → hledger transaction
# ?query        → ww find
# !name         → switch profile (bare ! = picker)
# #tag          → filter list by tag
# /             → status dashboard
# /lists        → list picker
# /tasks        → task browser
# /j            → journal entries
# /l            → ledger balances
# /timew        → time report
# /stream       → stream board
#
# Bind to a keyboard shortcut. Requires rofi (preferred) or dmenu.

set -euo pipefail

# --- Paths ---
WW_BASE="${HOME}/ww"
PROFILES_DIR="${WW_BASE}/profiles"
LIST_PY="${WW_BASE}/tools/list/list.py"

# --- Launcher detection ---
if command -v rofi &>/dev/null; then
  LAUNCHER="rofi"
elif command -v dmenu &>/dev/null; then
  LAUNCHER="dmenu"
else
  notify-send "ww-popup" "rofi or dmenu required" 2>/dev/null
  exit 1
fi

# --- Profile state ---
_active_profile() {
  # Try env var first (terminal context), fall back to persisted last-profile
  local p="${WARRIOR_PROFILE:-}"
  if [[ -z "$p" ]]; then
    local state_file="${HOME}/.config/ww/last-profile"
    [[ -f "$state_file" ]] && p=$(cat "$state_file" 2>/dev/null | tr -d '[:space:]')
  fi
  echo "$p"
}

_profile_base() {
  local p="${1:-$(_active_profile)}"
  [[ -n "$p" ]] && echo "${PROFILES_DIR}/${p}" || echo ""
}

_list_dir() {
  local base
  base="$(_profile_base "$@")"
  [[ -n "$base" ]] && echo "${base}/list" || echo ""
}

_current_list() {
  local base
  base="$(_profile_base "$@")"
  [[ -z "$base" ]] && echo "tasks" && return
  local yaml="${base}/lists.yaml"
  if [[ -f "$yaml" ]]; then
    local dl
    dl=$(grep -E '^\s*default:' "$yaml" 2>/dev/null | head -1 | sed 's/.*default:\s*//' | tr -d '[:space:]')
    [[ -n "$dl" ]] && echo "$dl" || echo "tasks"
  else
    echo "tasks"
  fi
}

# --- Context bar (must be <200ms) ---
_context_bar() {
  local profile list_name timer_info task_count parts=()

  profile="$(_active_profile)"
  if [[ -z "$profile" ]]; then
    echo "no profile active · type ! to switch"
    return
  fi

  list_name="$(_current_list)"
  parts+=("${profile} / ${list_name}")

  # Active timer (timew)
  if command -v timew &>/dev/null; then
    local timew_out
    timew_out=$(timew 2>/dev/null | head -1)
    if [[ "$timew_out" == Tracking* ]]; then
      local tracking
      tracking=$(echo "$timew_out" | sed 's/^Tracking //' | sed 's/  .*//')
      parts+=("▶ ${tracking}")
    fi
  fi

  # Urgent task count
  if command -v task &>/dev/null; then
    local base
    base="$(_profile_base)"
    if [[ -d "${base}/.task" ]]; then
      task_count=$(TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task +READY count 2>/dev/null || echo "0")
      [[ "$task_count" != "0" ]] && parts+=("${task_count} tasks ready")
    fi
  fi

  local IFS=' · '
  echo "${parts[*]}"
}

# --- Rofi prompt ---
_rofi_prompt() {
  local prompt="${1:-ww}" mesg="${2:-}"
  if [[ "$LAUNCHER" == "rofi" ]]; then
    if [[ -n "$mesg" ]]; then
      rofi -dmenu -i -p "$prompt" \
        -mesg "$mesg" \
        -theme-str 'window {width: 50%; location: center;}' \
        -theme-str 'listview {lines: 12;}'
    else
      rofi -dmenu -i -p "$prompt" \
        -theme-str 'window {width: 50%; location: center;}' \
        -theme-str 'listview {lines: 12;}'
    fi
  else
    dmenu -i -p "$prompt"
  fi
}

_rofi_info() {
  # Display-only rofi (no input selection needed — just show and wait for Esc)
  local prompt="${1:-info}" mesg="${2:-}" content="${3:-}"
  if [[ "$LAUNCHER" == "rofi" ]]; then
    echo "$content" | rofi -dmenu -i -p "$prompt" \
      -mesg "$mesg" \
      -theme-str 'window {width: 50%; location: center;}' \
      -theme-str 'listview {lines: 15;}' \
      >/dev/null 2>&1 || true
  else
    echo "$content" | dmenu -i -p "$prompt" >/dev/null 2>&1 || true
  fi
}

_notify() {
  notify-send -t 2000 "ww" "$1" 2>/dev/null || true
}

# --- Handlers ---

_handle_list_add() {
  local text="$1"
  local list_dir list_name
  list_dir="$(_list_dir)"
  list_name="$(_current_list)"
  [[ -z "$list_dir" ]] && _notify "No active profile" && return
  mkdir -p "$list_dir"
  python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -q "$text" 2>/dev/null
  _notify "✓ added to ${list_name}"
}

_handle_profile_switch() {
  local target="$1"
  local profiles
  profiles=$(find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)
  [[ -z "$profiles" ]] && _notify "No profiles found" && return

  if [[ -z "$target" ]]; then
    # Show picker
    local active="$(_active_profile)"
    local display
    display=$(echo "$profiles" | while read -r p; do
      if [[ "$p" == "$active" ]]; then echo "* $p"; else echo "  $p"; fi
    done)
    target=$(echo "$display" | _rofi_prompt "switch profile" "Current: ${active:-none}")
    [[ -z "$target" ]] && return
    target=$(echo "$target" | sed 's/^[* ] *//')
  fi

  if [[ ! -d "${PROFILES_DIR}/${target}" ]]; then
    _notify "Profile '${target}' not found"
    return
  fi

  # Export for this session (won't persist to parent shell, but popup will use it)
  # Write to a state file that shell-integration can pick up
  echo "$target" > "${WW_BASE}/.state/last-popup-profile" 2>/dev/null || true
  _notify "→ ${target} (use p-${target} in terminal to activate)"
}

_handle_task_add() {
  local text="$1"
  local base
  base="$(_profile_base)"
  [[ -z "$base" ]] && _notify "No active profile" && return
  TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task add "$text" 2>/dev/null
  _notify "✓ task added"
}

_handle_timew_start() {
  local tags="$1"
  timew start $tags 2>/dev/null
  _notify "▶ tracking: ${tags}"
}

_handle_timew_stop() {
  timew stop 2>/dev/null
  _notify "⏹ timer stopped"
}

_handle_journal() {
  local text="$1"
  local base
  base="$(_profile_base)"
  [[ -z "$base" ]] && _notify "No active profile" && return
  local jrnl_cfg="${base}/jrnl.yaml"
  if [[ -f "$jrnl_cfg" ]]; then
    jrnl --config-file "$jrnl_cfg" "$text" 2>/dev/null
    _notify "✓ journaled"
  else
    _notify "No jrnl.yaml for profile"
  fi
}

_handle_ledger() {
  local posting="$1"
  local base
  base="$(_profile_base)"
  [[ -z "$base" ]] && _notify "No active profile" && return
  # Parse: $amount account1 account2
  # Simple: append raw transaction to default ledger
  local ledger_file
  ledger_file=$(grep -r 'default:' "${base}/ledgers.yaml" 2>/dev/null | head -1 | sed 's/.*default:\s*//' | tr -d '[:space:]')
  if [[ -z "$ledger_file" ]]; then
    ledger_file="${base}/ledgers/global.journal"
  fi
  if [[ ! "$ledger_file" = /* ]]; then
    ledger_file="${base}/ledgers/${ledger_file}"
  fi
  local today
  today=$(date '+%Y-%m-%d')
  # Expect format: amount account [source-account]
  # e.g., "50 expenses:coffee assets:cash"
  local amount account source
  read -r amount account source <<< "$posting"
  source="${source:-assets:checking}"
  printf '\n%s * popup entry\n    %s  %s\n    %s\n' "$today" "$account" "$amount" "$source" >> "$ledger_file"
  _notify "✓ posted to ledger"
}

_handle_search() {
  local query="$1"
  local base
  base="$(_profile_base)"
  [[ -z "$base" ]] && _notify "No active profile" && return
  local results
  results=$(WORKWARRIOR_BASE="$base" "${WW_BASE}/bin/ww" find "$query" 2>/dev/null | head -30)
  if [[ -z "$results" ]]; then
    _notify "No results for: ${query}"
  else
    _rofi_info "find: ${query}" "Results for '${query}'" "$results"
  fi
}

_handle_tag_filter() {
  local tag="$1"
  local list_dir list_name
  list_dir="$(_list_dir)"
  list_name="$(_current_list)"
  [[ -z "$list_dir" ]] && _notify "No active profile" && return
  local items
  items=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --print -g "$tag" 2>/dev/null)
  if [[ -z "$items" ]]; then
    _notify "No items matching ${tag}"
  else
    _rofi_info "#${tag}" "$(_active_profile) / ${list_name}" "$items"
  fi
}

_handle_status() {
  local profile list_name timer_line task_lines ledger_line status=""
  profile="$(_active_profile)"

  if [[ -z "$profile" ]]; then
    status="No profile active.\n\nUse ! to switch profiles."
    _rofi_info "status" "" "$(echo -e "$status")"
    return
  fi

  local base
  base="$(_profile_base)"
  list_name="$(_current_list)"

  status="Profile:  ${profile}\nList:     ${list_name}\n"

  # Timer
  if command -v timew &>/dev/null; then
    timer_line=$(timew 2>/dev/null | head -3)
    status="${status}\n─── Timer ───\n${timer_line}\n"
  fi

  # Tasks
  if command -v task &>/dev/null && [[ -d "${base}/.task" ]]; then
    local ready overdue
    ready=$(TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task +READY count 2>/dev/null || echo "0")
    overdue=$(TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task +OVERDUE count 2>/dev/null || echo "0")
    status="${status}\n─── Tasks ───\nReady: ${ready}  Overdue: ${overdue}\n"
  fi

  # Lists
  local list_dir="$(_list_dir)"
  if [[ -d "$list_dir" ]]; then
    local list_count
    list_count=$(find "$list_dir" -maxdepth 1 -type f -not -name '.*' 2>/dev/null | wc -l)
    local item_count
    item_count=$(wc -l < "${list_dir}/${list_name}" 2>/dev/null || echo "0")
    status="${status}\n─── Lists ───\n${list_count} lists · ${item_count} items in '${list_name}'\n"
  fi

  _rofi_info "status" "${profile} / ${list_name}" "$(echo -e "$status")"
}

_handle_lists_picker() {
  local list_dir list_name profile
  profile="$(_active_profile)"
  list_dir="$(_list_dir)"
  list_name="$(_current_list)"

  [[ -z "$list_dir" ]] && _notify "No active profile" && return

  local list_names
  list_names=$(find "$list_dir" -maxdepth 1 -type f -not -name '.*' -printf '%f\n' 2>/dev/null | sort)
  [[ -z "$list_names" ]] && _notify "No lists" && return

  local display
  display=$(echo "$list_names" | while read -r name; do
    if [[ "$name" == "$list_name" ]]; then echo "* $name"; else echo "  $name"; fi
  done)

  local choice
  choice=$(echo "$display" | _rofi_prompt "${profile} / lists" "Select list to browse")
  [[ -z "$choice" ]] && return
  choice=$(echo "$choice" | sed 's/^[* ] *//')

  # Show items from chosen list
  local items
  items=$(python3 "$LIST_PY" -t "$list_dir" -l "$choice" --print 2>/dev/null)
  if [[ -z "$items" ]]; then
    _rofi_info "${profile}/${choice}" "Empty list" "(no items)"
  else
    local selected
    selected=$(echo "$items" | _rofi_prompt "${profile}/${choice}" "Select item or Esc to quit")
    # Could add actions here later
  fi
}

_handle_tasks_browse() {
  local base
  base="$(_profile_base)"
  [[ -z "$base" ]] && _notify "No active profile" && return

  local tasks
  tasks=$(TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task rc.verbose=nothing rc.report.next.columns=id,urgency,description rc.report.next.labels=ID,U,Description limit:15 next 2>/dev/null || echo "")
  [[ -z "$tasks" ]] && _notify "No tasks" && return

  local choice
  choice=$(echo "$tasks" | _rofi_prompt "tasks" "$(_active_profile) · select to act")
  [[ -z "$choice" ]] && return

  # Extract task ID (first column)
  local tid
  tid=$(echo "$choice" | awk '{print $1}')
  [[ -z "$tid" || ! "$tid" =~ ^[0-9]+$ ]] && return

  # Action picker
  local action
  action=$(printf "✓ done\n▶ start timer\n⏸ defer (+1d)\n✎ modify" | _rofi_prompt "task ${tid}")
  case "$action" in
    "✓ done")
      TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task rc.confirmation=no "$tid" done 2>/dev/null
      _notify "✓ task ${tid} done"
      ;;
    "▶ start timer")
      local desc
      desc=$(TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task _get "$tid".description 2>/dev/null || echo "task-${tid}")
      timew start "$desc" 2>/dev/null
      _notify "▶ tracking: ${desc}"
      ;;
    "⏸ defer (+1d)")
      TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task rc.confirmation=no "$tid" modify wait:+1d 2>/dev/null
      _notify "⏸ deferred 1 day"
      ;;
    "✎ modify")
      local new_desc
      new_desc=$(echo "" | _rofi_prompt "new description")
      [[ -n "$new_desc" ]] && TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task rc.confirmation=no "$tid" modify "$new_desc" 2>/dev/null
      ;;
  esac
}

# --- Main dispatcher ---

# --- Interactive handlers (for menu item selection) ---

_handle_task_add_interactive() {
  local text
  text=$(echo "" | _rofi_prompt ".task" "Type task description")
  [[ -z "$text" ]] && return
  _handle_task_add "$text"
}

_handle_timew_start_interactive() {
  local tags
  tags=$(echo "" | _rofi_prompt ">start" "Type tags/description for timer")
  [[ -z "$tags" ]] && return
  _handle_timew_start "$tags"
}

_handle_journal_interactive() {
  local text
  text=$(echo "" | _rofi_prompt "@journal" "Type journal entry")
  [[ -z "$text" ]] && return
  _handle_journal "$text"
}

_handle_ledger_interactive() {
  local text
  text=$(echo "" | _rofi_prompt "\$ledger" "Format: amount account [source]")
  [[ -z "$text" ]] && return
  _handle_ledger "$text"
}

_handle_search_interactive() {
  local text
  text=$(echo "" | _rofi_prompt "?search" "Search query")
  [[ -z "$text" ]] && return
  _handle_search "$text"
}

_handle_tag_interactive() {
  local text
  text=$(echo "" | _rofi_prompt "#tag" "Tag to filter (e.g. #reading)")
  [[ -z "$text" ]] && return
  [[ "$text" != \#* ]] && text="#${text}"
  _handle_tag_filter "$text"
}

# --- Main dispatcher ---

main() {
  local context_bar
  context_bar="$(_context_bar)"

  local input
  local menu_items="/  status dashboard
/lists  browse lists
/tasks  browse tasks
.  add task
>  start timer
>>  stop timer
@  journal entry
\$  ledger posting
?  search
!  switch profile
#  filter by tag"

  if [[ "$LAUNCHER" == "rofi" ]]; then
    input=$(echo "$menu_items" | rofi -dmenu -i -p "ww" \
      -mesg "$context_bar" \
      -theme-str 'window {width: 50%; location: center;}' \
      -theme-str 'listview {lines: 11;}') || exit 0
  else
    input=$(echo "$menu_items" | dmenu -i -p "ww") || exit 0
  fi

  # If they selected a menu item, extract just the command prefix
  case "$input" in
    "/"*"status dashboard")   input="/" ;;
    "/lists"*)                input="/lists" ;;
    "/tasks"*)                input="/tasks" ;;
    "."*"add task")           input="" ; _handle_task_add_interactive; exit 0 ;;
    ">"*"start timer")        input="" ; _handle_timew_start_interactive; exit 0 ;;
    ">>"*"stop timer")        input=">>" ;;
    "@"*"journal entry")      input="" ; _handle_journal_interactive; exit 0 ;;
    "\$"*"ledger posting")    input="" ; _handle_ledger_interactive; exit 0 ;;
    "?"*"search")             input="" ; _handle_search_interactive; exit 0 ;;
    "!"*"switch profile")     input="!" ;;
    "#"*"filter by tag")      input="" ; _handle_tag_interactive; exit 0 ;;
  esac
  [[ -z "$input" ]] && exit 0

  # Route based on first character(s)
  case "$input" in
    /lists)   _handle_lists_picker ;;
    /tasks)   _handle_tasks_browse ;;
    /j)       _rofi_info "journal" "not yet implemented" "Coming soon" ;;
    /l)       _rofi_info "ledger" "not yet implemented" "Coming soon" ;;
    /timew)   _rofi_info "timew" "not yet implemented" "Coming soon" ;;
    /stream)  _rofi_info "stream" "not yet implemented" "Coming soon" ;;
    /|/status) _handle_status ;;
    /*)       _rofi_info "help" "Unknown command" "Available: / /lists /tasks /j /l /timew /stream" ;;
    '.'*)     _handle_task_add "${input#.}" ;;
    '>>'*)    _handle_timew_stop ;;
    '>'*)     _handle_timew_start "${input#>}" ;;
    '@'*)     _handle_journal "${input#@}" ;;
    '$'*)     _handle_ledger "${input#\$}" ;;
    '?'*)     _handle_search "${input#\?}" ;;
    '!'*)     _handle_profile_switch "${input#!}" ;;
    '#'*)     _handle_tag_filter "$input" ;;
    *)        _handle_list_add "$input" ;;
  esac
}

main "$@"
