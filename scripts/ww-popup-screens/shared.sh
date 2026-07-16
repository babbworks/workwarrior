# ww-popup-screens/shared.sh — common helpers for all popup screens
# This file is SOURCED by the dispatcher and each screen module.
# NO SHEBANG — sourced only.

# --- Paths ---
WW_BASE="${WW_BASE:-${HOME}/ww}"
PROFILES_DIR="${WW_BASE}/profiles"
LIST_PY="${WW_BASE}/tools/list/list.py"
STATE_DIR="${HOME}/.config/ww"
RECENTS_FILE="${STATE_DIR}/popup-recents"

mkdir -p "$STATE_DIR" 2>/dev/null || true

# --- Page navigation state ---
POPUP_CURRENT_PAGE=1

# --- Launcher detection ---
# Priority: rofi (GUI) > fzf (TUI) > dmenu (GUI fallback)
LAUNCHER=""
if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v rofi &>/dev/null; then
  LAUNCHER="rofi"
elif command -v fzf &>/dev/null; then
  LAUNCHER="fzf"
elif command -v dmenu &>/dev/null; then
  LAUNCHER="dmenu"
fi

# --- Theme constants ---
ROFI_WIDTH="50%"
ROFI_LINES="15"
ROFI_LOCATION="center"

# --- Separator ---
SEP="───────────────────"

# --- Utility: strip ANSI escape codes ---
popup_strip_ansi() {
  sed 's/\x1b\[[0-9;]*m//g'
}

# --- Profile state ---
popup_active_profile() {
  local p="${WARRIOR_PROFILE:-}"
  if [[ -z "$p" ]]; then
    local state_file="${STATE_DIR}/last-profile"
    [[ -f "$state_file" ]] && p=$(cat "$state_file" 2>/dev/null | tr -d '[:space:]')
  fi
  echo "$p"
}

popup_profile_base() {
  local p="${1:-$(popup_active_profile)}"
  [[ -n "$p" ]] && echo "${PROFILES_DIR}/${p}" || echo ""
}

popup_taskrc() {
  local base
  base="$(popup_profile_base "${1:-}")"
  echo "${base}/.taskrc"
}

popup_taskdata() {
  local base
  base="$(popup_profile_base "${1:-}")"
  echo "${base}/.task"
}

popup_jrnl_cfg() {
  local base
  base="$(popup_profile_base "${1:-}")"
  echo "${base}/jrnl.yaml"
}

popup_ledger_file() {
  local base
  base="$(popup_profile_base "${1:-}")"
  [[ -z "$base" ]] && return
  local yaml="${base}/ledgers.yaml"
  [[ -f "$yaml" ]] || return
  local ledger_file
  ledger_file=$(grep -E '^\s*default:' "$yaml" 2>/dev/null | head -1 | sed 's/.*default:\s*//' | tr -d '[:space:]')
  [[ -z "$ledger_file" ]] && ledger_file="global.journal"
  [[ "$ledger_file" != /* ]] && ledger_file="${base}/ledgers/${ledger_file}"
  echo "$ledger_file"
}

popup_list_dir() {
  local base
  base="$(popup_profile_base "${1:-}")"
  [[ -n "$base" ]] && echo "${base}/list" || echo ""
}

popup_current_list() {
  local base
  base="$(popup_profile_base "${1:-}")"
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

# --- Task helpers ---
popup_task_export() {
  # Returns JSON for one task by ID
  local id="$1"
  local rc data
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"
  TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no "$id" export 2>/dev/null
}

popup_task_export_all() {
  # Returns all pending tasks as JSON array
  local rc data
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"
  TASKRC="$rc" TASKDATA="$data" task rc.confirmation=no status:pending export 2>/dev/null
}

popup_get_uda_names() {
  # Returns UDA names from .taskrc, one per line
  local rc
  rc="$(popup_taskrc)"
  [[ -f "$rc" ]] || return
  grep "^uda\." "$rc" | sed 's/^uda\.\([^.]*\)\..*/\1/' | sort -u
}

popup_get_projects() {
  # Returns unique project names, one per line
  local rc data
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"
  TASKRC="$rc" TASKDATA="$data" task _unique project 2>/dev/null | grep -v '^$'
}

popup_get_tags() {
  # Returns unique tags, one per line (splits comma-separated)
  local rc data
  rc="$(popup_taskrc)"
  data="$(popup_taskdata)"
  TASKRC="$rc" TASKDATA="$data" task _unique tags 2>/dev/null | tr ',' '\n' | grep -v '^$'
}

popup_get_accounts() {
  # Returns hledger accounts, one per line
  local ledger_file
  ledger_file="$(popup_ledger_file)"
  [[ -n "$ledger_file" && -f "$ledger_file" ]] || return
  hledger -f "$ledger_file" accounts 2>/dev/null
}

popup_journal_file() {
  # Resolve journal file path from jrnl.yaml for a given journal name
  # If no name given, uses the first (default) journal
  local name="${1:-}"
  local cfg base
  cfg="$(popup_jrnl_cfg)"
  base="$(popup_profile_base)"
  [[ -f "$cfg" ]] || return

  local jrnl_path
  if [[ -z "$name" ]]; then
    # Get the first journal's path
    jrnl_path=$(awk '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && /^  [a-zA-Z]/{gsub(/^ +/,""); sub(/:.*journal: /,"|"); sub(/:/,"|"); print}' "$cfg" | head -1)
    # Try to parse as "name: journal: path" or simpler format
    jrnl_path=$(awk '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && /journal:/{gsub(/.*journal:\s*/,""); gsub(/\s*$/,""); print; exit}' "$cfg")
  else
    # Get specific journal's path
    jrnl_path=$(awk -v name="$name" '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && $0 ~ "^  "name":"{jfound=1; next} jfound && /journal:/{gsub(/.*journal:\s*/,""); gsub(/\s*$/,""); print; exit} jfound && /^  [a-zA-Z]/{exit}' "$cfg")
  fi

  [[ -z "$jrnl_path" ]] && return
  # Resolve relative paths
  [[ "$jrnl_path" != /* ]] && jrnl_path="${base}/${jrnl_path}"
  echo "$jrnl_path"
}

# --- Timer state ---
popup_timer_status() {
  # Returns: "tracking|<description>|<duration>" or "idle|" or "unavailable|"
  if ! command -v timew &>/dev/null; then
    echo "unavailable|"
    return
  fi
  local base
  base="$(popup_profile_base)"
  local timew_out
  if [[ -n "$base" && -d "${base}/.timewarrior" ]]; then
    timew_out=$(TIMEWARRIORDB="${base}/.timewarrior" timew 2>/dev/null) || { echo "idle|"; return; }
  else
    timew_out=$(timew 2>/dev/null) || { echo "idle|"; return; }
  fi
  local first_line
  first_line=$(echo "$timew_out" | head -1)
  if [[ "$first_line" == "Tracking"* ]]; then
    local tracking
    tracking=$(echo "$first_line" | sed 's/^Tracking //' | sed 's/"//g' | sed 's/  *$//')
    local duration
    duration=$(echo "$timew_out" | grep -oE '[0-9]+:[0-9]{2}:[0-9]{2}' | head -1)
    [[ -z "$duration" ]] && duration=""
    echo "tracking|${tracking}|${duration}"
  else
    echo "idle|"
  fi
}

# --- Context bar ---
popup_context_bar() {
  local profile list_name parts=()

  profile="$(popup_active_profile)"
  if [[ -z "$profile" ]]; then
    echo "No profile active · select Switch Profile to begin"
    return
  fi

  list_name="$(popup_current_list)"
  parts+=("${profile} / ${list_name}")

  # Timer
  local timer_info
  timer_info="$(popup_timer_status)"
  local timer_state="${timer_info%%|*}"
  local timer_rest="${timer_info#*|}"
  case "$timer_state" in
    tracking)
      local t_desc="${timer_rest%%|*}"
      local t_dur="${timer_rest#*|}"
      [[ -n "$t_dur" ]] && parts+=("▶ ${t_desc} (${t_dur})") || parts+=("▶ ${t_desc}")
      ;;
    idle)
      parts+=("⏸ idle")
      ;;
  esac

  # Task count
  if command -v task &>/dev/null; then
    local base
    base="$(popup_profile_base)"
    if [[ -n "$base" && -d "${base}/.task" ]]; then
      local ready
      ready=$(TASKRC="${base}/.taskrc" TASKDATA="${base}/.task" task +READY count 2>/dev/null || echo "0")
      [[ "$ready" != "0" ]] && parts+=("${ready} tasks")
    fi
  fi

  local IFS=' · '
  echo "${parts[*]}"
}

# --- Recents tracking ---
popup_add_recent() {
  local entry="$1"
  [[ -z "$entry" ]] && return
  local tmp
  tmp=$(mktemp)
  echo "$entry" > "$tmp"
  if [[ -f "$RECENTS_FILE" ]]; then
    grep -vFx "$entry" "$RECENTS_FILE" 2>/dev/null | head -9 >> "$tmp"
  fi
  mv "$tmp" "$RECENTS_FILE"
}

popup_get_recents() {
  [[ -f "$RECENTS_FILE" ]] && cat "$RECENTS_FILE" || true
}

# --- UI wrappers (rofi / fzf / dmenu) ---

# Standard list prompt — shows items, allows selection or typing
popup_select() {
  local prompt="${1:-ww}" mesg="${2:-}"
  case "$LAUNCHER" in
    rofi)
      local args=(-dmenu -i -p "$prompt"
        -theme-str "window {width: ${ROFI_WIDTH}; location: ${ROFI_LOCATION};}"
        -theme-str "listview {lines: ${ROFI_LINES};}")
      [[ -n "$mesg" ]] && args+=(-mesg "$mesg")
      rofi "${args[@]}"
      ;;
    fzf)
      local args=(--prompt="${prompt}> " --ansi --reverse --no-info
        --height=~20 --min-height=10
        --bind="esc:abort" --print-query)
      [[ -n "$mesg" ]] && args+=(--header="$mesg")
      local result
      result=$(fzf "${args[@]}" 2>/dev/null) || return 1
      # fzf with --print-query outputs: line1=query, line2=selected
      # If user typed custom text (no match), only query line exists
      local query selected
      query=$(echo "$result" | head -1)
      selected=$(echo "$result" | tail -1)
      # If selected == query, user typed custom text (not from list)
      # If selected != query, they picked from the list
      if [[ "$selected" != "$query" && -n "$selected" ]]; then
        echo "$selected"
      else
        echo "$query"
      fi
      ;;
    dmenu)
      dmenu -i -p "$prompt"
      ;;
    *)
      # No launcher available — basic select fallback
      echo "ERROR: No launcher (rofi/fzf/dmenu) found" >&2
      return 1
      ;;
  esac
}

# Input-only prompt — no list, just a text field
popup_input() {
  local prompt="${1:-input}" mesg="${2:-}"
  case "$LAUNCHER" in
    rofi)
      local args=(-dmenu -i -p "$prompt"
        -theme-str "window {width: ${ROFI_WIDTH}; location: ${ROFI_LOCATION};}"
        -theme-str 'listview {lines: 0;}')
      [[ -n "$mesg" ]] && args+=(-mesg "$mesg")
      rofi "${args[@]}" < /dev/null
      ;;
    fzf)
      local args=(--prompt="${prompt}> " --ansi --reverse --no-info
        --height=~5 --min-height=3
        --print-query --bind="esc:abort")
      [[ -n "$mesg" ]] && args+=(--header="$mesg")
      local result
      result=$(echo "" | fzf "${args[@]}" 2>/dev/null) || return 1
      echo "$result" | head -1
      ;;
    dmenu)
      echo "" | dmenu -i -p "$prompt"
      ;;
    *)
      read -rp "${prompt}: " _popup_val
      echo "$_popup_val"
      ;;
  esac
}

# Display-only — shows content, returns selection or nothing on Esc
popup_display() {
  local prompt="${1:-info}" mesg="${2:-}" content="${3:-}"
  case "$LAUNCHER" in
    rofi)
      echo "$content" | rofi -dmenu -i -p "$prompt" \
        -mesg "$mesg" \
        -theme-str "window {width: ${ROFI_WIDTH}; location: ${ROFI_LOCATION};}" \
        -theme-str "listview {lines: ${ROFI_LINES};}"
      ;;
    fzf)
      local args=(--prompt="${prompt}> " --ansi --reverse --no-info
        --height=~20 --min-height=10
        --bind="esc:abort")
      [[ -n "$mesg" ]] && args+=(--header="$mesg")
      echo "$content" | fzf "${args[@]}" 2>/dev/null || true
      ;;
    dmenu)
      echo "$content" | dmenu -i -p "$prompt"
      ;;
    *)
      echo "=== $prompt ==="
      [[ -n "$mesg" ]] && echo "$mesg"
      echo "$content"
      read -rp "(press Enter) "
      ;;
  esac
}

# Confirmation dialog — returns 0 for yes, 1 for no/cancel
popup_confirm() {
  local prompt="$1" detail="${2:-}"
  local choice
  choice=$(printf "✓  Yes\n✗  Cancel" | popup_select "$prompt" "$detail") || return 1
  [[ "$choice" == *"Yes"* ]]
}

# Notification — brief toast (or terminal echo if no GUI)
popup_notify() {
  if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    notify-send -t 2500 "ww" "$1" 2>/dev/null || echo "[ww] $1" >&2
  else
    echo "[ww] $1" >&2
  fi
}

# --- Navigation helpers ---

# Check if selection is a separator
popup_is_sep() {
  [[ "$1" == "─"* ]]
}

# Require active profile — show message and return 1 if none
popup_require_profile() {
  local profile
  profile="$(popup_active_profile)"
  if [[ -z "$profile" ]]; then
    popup_notify "No active profile — use Switch Profile first"
    return 1
  fi
  return 0
}
