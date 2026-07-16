# ww-popup-screens/shared-v2.sh — rofi-script mode helpers
# Sourced by ww-popup-script.sh. NO SHEBANG.
#
# Output protocol:
#   Headers: printf '\0key\x1fvalue\n'
#   Rows:    printf 'text\0key\x1fvalue\x1fkey2\x1fvalue2\n'

# --- Paths ---
WW_BASE="${WW_BASE:-${HOME}/ww}"
PROFILES_DIR="${WW_BASE}/profiles"
LIST_PY="${WW_BASE}/tools/list/list.py"
STATE_DIR="${HOME}/.config/ww"
CACHE_DIR="${HOME}/.cache/ww/popup"
RECENTS_FILE="${STATE_DIR}/popup-recents"

mkdir -p "$STATE_DIR" "$CACHE_DIR" 2>/dev/null || true

# --- Profile state ---
_profile=""
_profile_base=""

_init_profile() {
  [[ -n "$_profile" ]] && return
  _profile="${WARRIOR_PROFILE:-}"
  if [[ -z "$_profile" ]]; then
    local f="${STATE_DIR}/last-profile"
    [[ -f "$f" ]] && read -r _profile < "$f"
  fi
  _profile="${_profile//[[:space:]]/}"
  [[ -n "$_profile" ]] && _profile_base="${PROFILES_DIR}/${_profile}"
}

profile_name() { _init_profile; echo "$_profile"; }
profile_base() { _init_profile; echo "$_profile_base"; }
profile_taskrc() { _init_profile; echo "${_profile_base}/.taskrc"; }
profile_taskdata() { _init_profile; echo "${_profile_base}/.task"; }
profile_twdb() { _init_profile; echo "${_profile_base}/.timewarrior"; }

profile_jrnl_cfg() { _init_profile; echo "${_profile_base}/jrnl.yaml"; }

profile_ledger_file() {
  _init_profile
  local yaml="${_profile_base}/ledgers.yaml"
  [[ -f "$yaml" ]] || return
  local lf
  lf=$(grep -m1 -E '^\s*default:' "$yaml" 2>/dev/null | sed 's/.*default:\s*//' | tr -d '[:space:]')
  [[ -z "$lf" ]] && lf="global.journal"
  [[ "$lf" != /* ]] && lf="${_profile_base}/ledgers/${lf}"
  echo "$lf"
}

profile_list_dir() { _init_profile; echo "${_profile_base}/list"; }

profile_current_list() {
  _init_profile
  local yaml="${_profile_base}/lists.yaml"
  if [[ -f "$yaml" ]]; then
    local dl
    dl=$(grep -m1 -E '^\s*default:' "$yaml" 2>/dev/null | sed 's/.*default:\s*//' | tr -d '[:space:]')
    [[ -n "$dl" ]] && echo "$dl" || echo "tasks"
  else
    echo "tasks"
  fi
}

# --- Rofi-script output helpers ---

# Emit header options (call before any row output)
emit_prompt() { printf '\0prompt\x1f%s\n' "$1"; }
emit_message() { printf '\0message\x1f%s\n' "$1"; }
emit_data() { printf '\0data\x1f%s\n' "$1"; }
emit_markup_rows() { printf '\0markup-rows\x1ftrue\n'; }
emit_no_custom() { printf '\0no-custom\x1ftrue\n'; }
emit_allow_custom() { printf '\0no-custom\x1ffalse\n'; }
emit_hotkeys() { printf '\0use-hot-keys\x1ftrue\n'; }
emit_keep_selection() { printf '\0keep-selection\x1ftrue\n'; }
emit_new_selection() { printf '\0new-selection\x1f%s\n' "$1"; }

# Emit a selectable row
# Usage: emit_row "display text" "info_value" [meta_search_terms]
emit_row() {
  local text="$1" info="${2:-}" meta="${3:-}"
  local opts=""
  [[ -n "$info" ]] && opts="info\x1f${info}"
  [[ -n "$meta" ]] && { [[ -n "$opts" ]] && opts="${opts}\x1f"; opts="${opts}meta\x1f${meta}"; }
  if [[ -n "$opts" ]]; then
    printf '%s\0%b\n' "$text" "$opts"
  else
    printf '%s\n' "$text"
  fi
}

# Emit a non-selectable separator
emit_sep() {
  printf '───────────────────\0nonselectable\x1ftrue\n'
}

# Emit a non-selectable label/header
emit_label() {
  printf '%s\0nonselectable\x1ftrue\n' "$1"
}

# Emit a row marked as active (highlighted)
emit_row_active() {
  local text="$1" info="${2:-}"
  if [[ -n "$info" ]]; then
    printf '%s\0info\x1f%s\x1factive\x1ftrue\n' "$text" "$info"
  else
    printf '%s\0active\x1ftrue\n' "$text"
  fi
}

# Emit a row marked as urgent
emit_row_urgent() {
  local text="$1" info="${2:-}"
  if [[ -n "$info" ]]; then
    printf '%s\0info\x1f%s\x1furgent\x1ftrue\n' "$text" "$info"
  else
    printf '%s\0urgent\x1ftrue\n' "$text"
  fi
}

# --- Context bar (fast, parallel) ---

build_context_bar() {
  _init_profile
  [[ -z "$_profile" ]] && { echo "No profile · Switch Profile to begin"; return; }

  local list_name timer_part task_part

  # List name: pure file read
  list_name=$(profile_current_list)

  # Parallel: timer status + task count
  local tf cf
  tf=$(mktemp); cf=$(mktemp)

  (
    if [[ -d "${_profile_base}/.timewarrior" ]]; then
      local line
      line=$(TIMEWARRIORDB="${_profile_base}/.timewarrior" timew 2>/dev/null | head -1)
      if [[ "$line" == Tracking* ]]; then
        printf '▶ %s' "$(echo "$line" | sed 's/^Tracking //;s/"//g;s/ *$//')"
      else
        printf '⏸ idle'
      fi
    else
      printf '⏸ idle'
    fi
  ) > "$tf" &

  (
    TASKRC="${_profile_base}/.taskrc" TASKDATA="${_profile_base}/.task" task +READY count 2>/dev/null || printf '0'
  ) > "$cf" &

  wait
  timer_part=$(<"$tf"); task_part=$(<"$cf")
  rm -f "$tf" "$cf"

  local bar="${_profile} / ${list_name} · ${timer_part}"
  [[ "$task_part" != "0" && -n "$task_part" ]] && bar+=" · ${task_part} tasks"
  echo "$bar"
}

# --- Recents ---
add_recent() {
  local entry="$1"
  [[ -z "$entry" ]] && return
  local tmp; tmp=$(mktemp)
  printf '%s\n' "$entry" > "$tmp"
  [[ -f "$RECENTS_FILE" ]] && grep -vFx "$entry" "$RECENTS_FILE" 2>/dev/null | head -9 >> "$tmp"
  mv "$tmp" "$RECENTS_FILE"
}

get_recents() {
  [[ -f "$RECENTS_FILE" ]] && cat "$RECENTS_FILE" || true
}

# --- Notification (background, non-blocking) ---
notify() {
  if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    coproc ( notify-send -t 2500 "ww" "$1" 2>/dev/null )
  fi
}

# --- Cache helpers ---
cache_valid() {
  # Usage: cache_valid "filename" ttl_seconds
  local file="${CACHE_DIR}/$1" ttl="${2:-5}"
  [[ -f "$file" ]] || return 1
  local age=$(( $(date +%s) - $(stat -c %Y "$file") ))
  (( age < ttl ))
}

cache_read() { cat "${CACHE_DIR}/$1" 2>/dev/null; }
cache_write() { cat > "${CACHE_DIR}/$1"; }
cache_invalidate() { rm -f "${CACHE_DIR}/$1" 2>/dev/null; }

# --- Screen dispatch ---

render_screen() {
  local screen="$1" arg="$2"
  case "$screen" in
    home)      render_home ;;
    clock)     render_clock ;;
    tasks)     render_tasks ;;
    lists)     render_lists ;;
    journal)   render_journal ;;
    ledger)    render_ledger ;;
    board)     render_board ;;
    reports)   render_reports ;;
    search)    render_search "$arg" ;;
    profile)   render_profile ;;
    sync)      render_sync ;;
    community) render_community ;;
    system)    render_system ;;
    # Sub-screens: clock
    clock_input)     render_clock_input "$arg" ;;
    clock_summary)   render_clock_summary ;;
    clock_past)      render_clock_past ;;
    clock_intervals) render_clock_intervals ;;
    # Sub-screens: tasks
    task_action)     render_task_action "$arg" ;;
    task_detail)     render_task_action "$arg" ;;
    task_add)        render_task_add ;;
    task_post_add)   render_task_post_add "$arg" ;;
    task_annotate)   render_task_annotate "$arg" ;;
    task_annotations) render_task_annotations "$arg" ;;
    task_notes)      render_task_notes "$arg" ;;
    task_project)    render_task_project "$arg" ;;
    task_priority)   render_task_priority "$arg" ;;
    task_due)        render_task_due "$arg" ;;
    task_tags)       render_task_tags "$arg" ;;
    task_description) render_task_description "$arg" ;;
    task_wait)       render_task_wait "$arg" ;;
    task_uda)        render_task_uda "$arg" ;;
    task_uda_edit)   render_task_uda_edit "$arg" ;;
    # Sub-screens: lists
    list_action)     render_list_action "$arg" ;;
    list_picker)     render_list_picker ;;
    list_new)        render_list_new ;;
    list_edit)       render_list_edit "$arg" ;;
    list_note)       render_list_note "$arg" ;;
    # Sub-screens: journal
    journal_search)         render_journal_search ;;
    journal_search_results) render_journal_search_results "$arg" ;;
    journal_add)            render_journal_add ;;
    journal_add_named)      render_journal_add_named "$arg" ;;
    journal_entry)          render_journal_entry "$arg" ;;
    journal_picker)         render_journal_picker ;;
    # Sub-screens: ledger
    ledger_balances)        render_ledger_balances ;;
    ledger_register)        render_ledger_register ;;
    ledger_monthly)         render_ledger_monthly ;;
    ledger_balancesheet)    render_ledger_balancesheet ;;
    ledger_incomestatement) render_ledger_incomestatement ;;
    ledger_search)          render_ledger_search ;;
    ledger_comment)         render_ledger_comment ;;
    # Sub-screens: reports
    report_time_day)   render_report_time_day ;;
    report_time_week)  render_report_time_week ;;
    report_tasks_done) render_report_tasks_done ;;
    report_spending)   render_report_spending ;;
    # Sub-screens: community
    community_show)    render_community_show "$arg" ;;
    community_create)  render_community_create ;;
    community_add)     render_community_add "$arg" ;;
    # Sub-screens: stream/board
    stream_status)       render_stream_status ;;
    stream_lens_picker)  render_stream_lens_picker ;;
    stream_lens)         render_stream_lens "$arg" ;;
    # Sub-screens: profile
    profile_info)    render_profile_info ;;
    profile_create)  render_profile_create ;;
    # Sub-screens: sync
    sync_enable)   render_sync_enable ;;
    sync_disable)  render_sync_disable ;;
    # Sub-screens: system
    system_groups)   render_system_groups ;;
    system_models)   render_system_models ;;
    system_deps)     render_system_deps ;;
    system_services) render_system_services ;;
    *)         render_home ;;
  esac
}

# --- Selection routing ---

handle_selection() {
  local info="$1" selection="$2" screen="$3" arg="$4"

  # Parse info field: "action:target:extra"
  local action="${info%%:*}"
  local rest="${info#*:}"
  local target="${rest%%:*}"
  local extra="${rest#*:}"
  [[ "$extra" == "$rest" ]] && extra=""

  case "$action" in
    nav)
      # Navigate to a screen
      render_screen "$target" "$extra"
      ;;
    act)
      # Execute an action, then re-render current screen
      execute_action "$target" "$extra" "$screen" "$arg"
      ;;
    pick)
      # User picked an item — show action menu for it
      handle_pick "$target" "$extra" "$screen" "$arg"
      ;;
    back)
      # Go back to specified screen
      render_screen "$target" "$extra"
      ;;
    noop)
      # Re-render current screen (e.g., clicked a label)
      render_screen "$screen" "$arg"
      ;;
    *)
      # Unknown — re-render current
      render_screen "$screen" "$arg"
      ;;
  esac
}

# --- Custom input routing (prefix commands) ---

handle_custom_input() {
  local input="$1" screen="$2" arg="$3"
  _init_profile

  # --- Sub-screen input handling (context-aware) ---
  case "$screen" in
    task_add)
      # User typed a task description — create task then show post-add options
      [[ -z "$input" ]] && { render_screen "tasks" ""; return; }
      local add_output
      add_output=$(TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no add $input 2>/dev/null)
      # Parse task ID from "Created task N."
      local new_id
      new_id=$(echo "$add_output" | grep -oE '[0-9]+' | tail -1)
      notify "Task added: $input"
      cache_invalidate "tasks"
      if [[ -n "$new_id" ]]; then
        render_screen "task_post_add" "$new_id"
      else
        render_screen "tasks" ""
      fi
      return
      ;;
    journal_add)
      # User typed a journal entry (default journal)
      [[ -z "$input" ]] && { render_screen "journal" ""; return; }
      local jfile; jfile=$(_resolve_journal_file)
      if [[ -n "$jfile" ]]; then
        printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$input" >> "$jfile"
      fi
      notify "Journal entry added"
      # Show post-add options
      emit_prompt "✅ Entry added"
      emit_message "$input"
      emit_data "journal"
      emit_hotkeys
      emit_row "✓  Done — back to journal" "nav:journal"
      emit_row "✏️  Add another entry" "nav:journal_add"
      emit_row "📚  Write to different journal" "nav:journal_picker"
      emit_row "← Home" "nav:home"
      return
      ;;
    journal_add_named)
      # User typed entry for a named journal
      [[ -z "$input" ]] && { render_screen "journal" ""; return; }
      local jname="$arg"
      local cfg; cfg="$(profile_jrnl_cfg)"
      # Resolve named journal path
      local jpath
      jpath=$(awk -v name="$jname" '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && $0 ~ "^  "name":"{sub(/^  [a-zA-Z_-]+: */,""); print; exit}' "$cfg" 2>/dev/null)
      [[ -z "$jpath" ]] && jpath=$(_resolve_journal_file)
      [[ "$jpath" != /* ]] && jpath="${_profile_base}/${jpath}"
      if [[ -n "$jpath" ]]; then
        printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$input" >> "$jpath"
      fi
      notify "Entry added to ${jname}"
      render_screen "journal" ""
      return
      ;;
    journal_search)
      # Search journal
      [[ -z "$input" ]] && { render_screen "journal" ""; return; }
      render_screen "journal_search_results" "$input"
      return
      ;;
    clock_input)
      # User typed an activity name
      [[ -z "$input" ]] && { render_screen "clock" ""; return; }
      local twdb; twdb="$(profile_twdb)"
      if [[ "$arg" == "switch" ]]; then
        TIMEWARRIORDB="$twdb" timew stop 2>/dev/null
      fi
      TIMEWARRIORDB="$twdb" timew start $input 2>/dev/null
      add_recent "$input"
      notify "Tracking: $input"
      render_screen "clock" ""
      return
      ;;
    clock_past)
      # User typed "duration activity" for past interval
      [[ -z "$input" ]] && { render_screen "clock" ""; return; }
      local twdb; twdb="$(profile_twdb)"
      # Parse: first token is duration, rest is activity tags
      local duration="${input%% *}"
      local activity="${input#* }"
      [[ "$activity" == "$duration" ]] && activity=""
      TIMEWARRIORDB="$twdb" timew track "$duration" $activity 2>/dev/null
      [[ -n "$activity" ]] && add_recent "$activity"
      notify "Logged: ${duration} ${activity}"
      render_screen "clock" ""
      return
      ;;
    task_annotate)
      # User typed a note for a task
      local task_id="$arg"
      [[ -z "$input" ]] && { render_screen "task_action" "$task_id"; return; }
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$task_id" annotate "$input" 2>/dev/null
      notify "Note added to #${task_id}"
      render_screen "task_action" "$task_id"
      return
      ;;
    task_project)
      # User typed a new project name
      local task_id="$arg"
      [[ -z "$input" ]] && { render_screen "task_action" "$task_id"; return; }
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$task_id" modify "project:${input}" 2>/dev/null
      notify "Project set: $input"
      cache_invalidate "tasks"
      render_screen "task_action" "$task_id"
      return
      ;;
    task_due)
      # User typed a due date
      local task_id="$arg"
      [[ -z "$input" ]] && { render_screen "task_action" "$task_id"; return; }
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$task_id" modify "due:${input}" 2>/dev/null
      notify "Due date set: $input"
      cache_invalidate "tasks"
      render_screen "task_action" "$task_id"
      return
      ;;
    task_tags)
      # User typed +tag
      local task_id="$arg"
      [[ -z "$input" ]] && { render_screen "task_action" "$task_id"; return; }
      # Ensure it has + prefix
      [[ "$input" != "+"* && "$input" != "-"* ]] && input="+${input}"
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$task_id" modify "${input}" 2>/dev/null
      notify "Tag updated: $input"
      cache_invalidate "tasks"
      render_screen "task_tags" "$task_id"
      return
      ;;
    task_description)
      # User typed new description
      local task_id="$arg"
      [[ -z "$input" ]] && { render_screen "task_action" "$task_id"; return; }
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$task_id" modify "description:${input}" 2>/dev/null
      notify "Description updated"
      cache_invalidate "tasks"
      render_screen "task_action" "$task_id"
      return
      ;;
    task_wait)
      # User typed a custom wait date
      local task_id="$arg"
      [[ -z "$input" ]] && { render_screen "task_action" "$task_id"; return; }
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$task_id" modify "wait:${input}" 2>/dev/null
      notify "Wait set: $input"
      cache_invalidate "tasks"
      render_screen "task_action" "$task_id"
      return
      ;;
    task_uda_edit)
      # User typed UDA value — arg format: "task_id|uda_name"
      local task_id="${arg%%|*}" uda_name="${arg#*|}"
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$task_id" modify "${uda_name}:${input}" 2>/dev/null
      notify "UDA ${uda_name} updated"
      cache_invalidate "tasks"
      render_screen "task_uda" "$task_id"
      return
      ;;
    task_annotations)
      # User typed a new annotation
      local task_id="$arg"
      [[ -z "$input" ]] && { render_screen "task_action" "$task_id"; return; }
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$task_id" annotate "$input" 2>/dev/null
      notify "Note added to #${task_id}"
      render_screen "task_annotations" "$task_id"
      return
      ;;
    list_new)
      # User typed new list name
      [[ -z "$input" ]] && { render_screen "lists" ""; return; }
      local list_dir list_name profile
      list_dir="$(profile_list_dir)"
      list_name="$(profile_current_list)"
      profile="$(profile_name)"
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --profile-name "$profile" new "$input" 2>/dev/null
      notify "Created list: $input"
      cache_invalidate "lists"
      render_screen "lists" ""
      return
      ;;
    list_edit)
      # User typed replacement text
      local prefix="$arg"
      [[ -z "$input" ]] && { render_screen "lists" ""; return; }
      local list_dir list_name
      list_dir="$(profile_list_dir)"
      list_name="$(profile_current_list)"
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -e "$prefix" "$input" 2>/dev/null
      notify "Item updated"
      cache_invalidate "lists"
      render_screen "lists" ""
      return
      ;;
    list_note)
      # User typed note text
      local prefix="$arg"
      [[ -z "$input" ]] && { render_screen "lists" ""; return; }
      local list_dir list_name
      list_dir="$(profile_list_dir)"
      list_name="$(profile_current_list)"
      # Get current text, append note
      local item_line base_text
      item_line=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" 2>/dev/null | grep "^${prefix} - ")
      base_text="${item_line#* - }"
      base_text="${base_text%% // *}"
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -e "$prefix" "${base_text} // ${input}" 2>/dev/null
      notify "Note added"
      cache_invalidate "lists"
      render_screen "lists" ""
      return
      ;;
    journal_search)
      # Search journal
      [[ -z "$input" ]] && { render_screen "journal" ""; return; }
      local jfile; jfile=$(_resolve_journal_file)
      emit_prompt "📓 '${input}'"
      emit_message "Journal search: ${input}"
      emit_data "journal"
      emit_hotkeys
      if [[ -n "$jfile" && -f "$jfile" ]]; then
        local results
        results=$(LC_ALL=C grep -i "$input" "$jfile" 2>/dev/null | tail -15)
        if [[ -n "$results" ]]; then
          while IFS= read -r line; do
            emit_label "$line"
          done <<< "$results"
        else
          emit_label "(no matches)"
        fi
      fi
      emit_sep
      emit_row "← Back" "nav:journal"
      return
      ;;
    ledger_search)
      # Search ledger
      [[ -z "$input" ]] && { render_screen "ledger" ""; return; }
      local ledger_file; ledger_file=$(profile_ledger_file)
      emit_prompt "💰 '${input}'"
      emit_message "Ledger search: ${input}"
      emit_data "ledger"
      emit_hotkeys
      if [[ -n "$ledger_file" && -f "$ledger_file" ]]; then
        local results
        results=$(hledger -f "$ledger_file" register "desc:${input}" 2>/dev/null | tail -15)
        if [[ -n "$results" ]]; then
          while IFS= read -r line; do
            emit_label "$line"
          done <<< "$results"
        else
          emit_label "(no matches)"
        fi
      fi
      emit_sep
      emit_row "← Back" "nav:ledger"
      return
      ;;
    community_create)
      # Create collection
      [[ -z "$input" ]] && { render_screen "community" ""; return; }
      ww community create "$input" 2>/dev/null
      notify "Collection created: $input"
      render_screen "community" ""
      return
      ;;
    community_add)
      # Add item to collection
      [[ -z "$input" ]] && { render_screen "community_show" "$arg"; return; }
      ww community add "$arg" "$input" 2>/dev/null
      notify "Added to ${arg}"
      render_screen "community_show" "$arg"
      return
      ;;
    community_show)
      # Bare text on community_show = add to collection
      [[ -z "$input" ]] && { render_screen "community_show" "$arg"; return; }
      ww community add "$arg" "$input" 2>/dev/null
      notify "Added to ${arg}"
      render_screen "community_show" "$arg"
      return
      ;;
    ledger_comment)
      # Add comment to ledger file
      [[ -z "$input" ]] && { render_screen "ledger" ""; return; }
      local ledger_file; ledger_file=$(profile_ledger_file)
      if [[ -n "$ledger_file" && -f "$ledger_file" ]]; then
        printf '; [%s] %s\n' "$(date '+%Y-%m-%d')" "$input" >> "$ledger_file"
        notify "Ledger note added"
      fi
      render_screen "ledger" ""
      return
      ;;
    sync_enable)
      # Format: task_id issue_number org/repo
      [[ -z "$input" ]] && { render_screen "sync" ""; return; }
      local task_id issue_num repo
      read -r task_id issue_num repo <<< "$input"
      if [[ -n "$task_id" && -n "$issue_num" && -n "$repo" ]]; then
        ww issues enable "$task_id" "$issue_num" "$repo" 2>/dev/null
        notify "Linked task #${task_id} ↔ ${repo}#${issue_num}"
      else
        notify "Format: task_id issue_num org/repo"
      fi
      render_screen "sync" ""
      return
      ;;
    sync_disable)
      # Just a task ID
      [[ -z "$input" ]] && { render_screen "sync" ""; return; }
      ww issues disable "$input" 2>/dev/null
      notify "Unlinked task #${input}"
      render_screen "sync" ""
      return
      ;;
    profile_create)
      # Create new profile
      [[ -z "$input" ]] && { render_screen "profile" ""; return; }
      ww profile create "$input" --non-interactive 2>/dev/null
      notify "Profile created: $input"
      render_screen "profile" ""
      return
      ;;
  esac

  # --- Global prefix routing (works from any screen) ---
  case "$input" in
    .*)
      # Task add
      local desc="${input#.}"
      [[ -z "$desc" ]] && { render_screen "$screen" "$arg"; return; }
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no add "$desc" 2>/dev/null
      notify "Task added: $desc"
      cache_invalidate "tasks"
      render_screen "$screen" "$arg"
      ;;
    ">>"*)
      # Timew stop
      TIMEWARRIORDB="$(profile_twdb)" timew stop 2>/dev/null
      notify "Timer stopped"
      render_screen "$screen" "$arg"
      ;;
    ">"*)
      # Timew start
      local activity="${input#>}"
      [[ -z "$activity" ]] && { render_screen "$screen" "$arg"; return; }
      TIMEWARRIORDB="$(profile_twdb)" timew start $activity 2>/dev/null
      add_recent "$activity"
      notify "Tracking: $activity"
      render_screen "$screen" "$arg"
      ;;
    "@"*)
      # Journal entry (direct file write)
      local text="${input#@}"
      [[ -z "$text" ]] && { render_screen "$screen" "$arg"; return; }
      local jfile
      jfile=$(_resolve_journal_file)
      if [[ -n "$jfile" && -f "$jfile" ]]; then
        printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M')" "$text" >> "$jfile"
      else
        local cfg; cfg="$(profile_jrnl_cfg)"
        jrnl --config-file "$cfg" "$text" 2>/dev/null
      fi
      notify "Journal: $text"
      render_screen "$screen" "$arg"
      ;;
    '$'*)
      # Ledger — quick expense (requires follow-up for accounts)
      local expense="${input#\$}"
      [[ -z "$expense" ]] && { render_screen "$screen" "$arg"; return; }
      # Store pending expense and show account picker
      emit_data "ledger_pending:${expense}"
      render_ledger_account_picker "$expense"
      ;;
    "?"*)
      # Search
      local query="${input#?}"
      [[ -z "$query" ]] && { render_screen "$screen" "$arg"; return; }
      render_screen "search" "$query"
      ;;
    "!"*)
      # Profile switch
      local name="${input#!}"
      if [[ -z "$name" ]]; then
        render_screen "profile" ""
      else
        echo "$name" > "${STATE_DIR}/last-profile"
        _profile="" _profile_base=""
        notify "Switched to: $name"
        render_screen "home" ""
      fi
      ;;
    "#"*)
      # Tag filter on current list
      local tag="${input#\#}"
      [[ -z "$tag" ]] && { render_screen "$screen" "$arg"; return; }
      render_list_filtered "$tag"
      ;;
    "/"*)
      # ww CLI passthrough
      local cmd="${input#/}"
      [[ -z "$cmd" ]] && { render_screen "$screen" "$arg"; return; }
      local output
      output=$(ww $cmd 2>&1) || true
      emit_prompt "ww $cmd"
      emit_message "Output:"
      emit_data "$screen:$arg"
      emit_hotkeys
      if [[ -n "$output" ]]; then
        while IFS= read -r line; do
          emit_row "$line" "noop"
        done <<< "$output"
      else
        emit_label "(no output)"
      fi
      emit_sep
      emit_row "← Back" "nav:${screen}:${arg}"
      ;;
    *)
      # Bare text — add to current list
      [[ -z "$input" ]] && { render_screen "$screen" "$arg"; return; }
      local list_dir list_name
      list_dir="$(profile_list_dir)"
      list_name="$(profile_current_list)"
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -q "$input" 2>/dev/null
      notify "Added to ${list_name}: $input"
      cache_invalidate "lists"
      render_screen "$screen" "$arg"
      ;;
  esac
}

# --- kb-custom handlers ---

handle_kb_done() {
  local info="$1" selection="$2" screen="$3"
  _init_profile

  case "$screen" in
    tasks)
      # Complete the selected task
      local task_id
      task_id=$(echo "$info" | grep -oE '[0-9]+$')
      if [[ -n "$task_id" ]]; then
        TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
          task rc.confirmation=no "$task_id" done 2>/dev/null
        notify "Task #${task_id} completed"
        cache_invalidate "tasks"
      fi
      render_screen "tasks" ""
      ;;
    clock)
      # Clock out
      TIMEWARRIORDB="$(profile_twdb)" timew stop 2>/dev/null
      notify "Clocked out"
      render_screen "clock" ""
      ;;
    lists)
      # Finish list item
      local prefix
      prefix=$(echo "$info" | sed 's/.*://')
      if [[ -n "$prefix" ]]; then
        local list_dir list_name
        list_dir="$(profile_list_dir)"
        list_name="$(profile_current_list)"
        python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -f "$prefix" 2>/dev/null
        notify "Item done"
        cache_invalidate "lists"
      fi
      render_screen "lists" ""
      ;;
    *)
      render_screen "$screen" ""
      ;;
  esac
}

handle_kb_edit() {
  local info="$1" selection="$2" screen="$3"

  case "$screen" in
    tasks)
      local task_id
      task_id=$(echo "$info" | grep -oE '[0-9]+$')
      [[ -n "$task_id" ]] && render_screen "task_action" "$task_id"
      ;;
    lists)
      local prefix
      prefix=$(echo "$info" | sed 's/.*://')
      [[ -n "$prefix" ]] && render_screen "list_action" "$prefix"
      ;;
    *)
      render_screen "$screen" ""
      ;;
  esac
}

handle_kb_timer() {
  local info="$1" selection="$2" screen="$3"
  _init_profile

  case "$screen" in
    tasks)
      # Start timer with task description
      local task_id desc
      task_id=$(echo "$info" | grep -oE '[0-9]+$')
      if [[ -n "$task_id" ]]; then
        desc=$(TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
          task rc.confirmation=no "$task_id" export 2>/dev/null | \
          python3 -c "import json,sys;print(json.load(sys.stdin)[0].get('description',''))" 2>/dev/null)
        TIMEWARRIORDB="$(profile_twdb)" timew start $desc 2>/dev/null
        add_recent "$desc"
        notify "Tracking: $desc"
      fi
      render_screen "tasks" ""
      ;;
    *)
      render_screen "$screen" ""
      ;;
  esac
}

handle_kb_add() {
  local info="$1" selection="$2" screen="$3"
  # This is handled by the user just typing — ROFI_RETV=2 catches it.
  # But if they press Ctrl+N on a screen, we can render an input-focused view.
  render_screen "$screen" ""
}

# --- Action execution ---

execute_action() {
  local target="$1" extra="$2" screen="$3" arg="$4"
  _init_profile

  case "$target" in
    clock_out)
      TIMEWARRIORDB="$(profile_twdb)" timew stop 2>/dev/null
      notify "Clocked out"
      render_screen "clock" ""
      ;;
    clock_in)
      # extra = activity name
      TIMEWARRIORDB="$(profile_twdb)" timew start $extra 2>/dev/null
      add_recent "$extra"
      notify "Tracking: $extra"
      render_screen "clock" ""
      ;;
    clock_track)
      # extra = "duration activity" for past interval
      local duration="${extra%% *}"
      local activity="${extra#* }"
      [[ "$activity" == "$duration" ]] && activity=""
      TIMEWARRIORDB="$(profile_twdb)" timew track "$duration" $activity 2>/dev/null
      [[ -n "$activity" ]] && add_recent "$activity"
      notify "Logged: ${duration} ${activity}"
      render_screen "clock" ""
      ;;
    task_done)
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$extra" done 2>/dev/null
      notify "Task #${extra} completed"
      cache_invalidate "tasks"
      render_screen "tasks" ""
      ;;
    task_defer_1d)
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$extra" modify wait:+1d 2>/dev/null
      notify "Task deferred +1d"
      cache_invalidate "tasks"
      render_screen "tasks" ""
      ;;
    task_defer_1w)
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$extra" modify wait:+1w 2>/dev/null
      notify "Task deferred +1w"
      cache_invalidate "tasks"
      render_screen "tasks" ""
      ;;
    task_delete)
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$extra" delete 2>/dev/null
      notify "Task #${extra} deleted"
      cache_invalidate "tasks"
      render_screen "tasks" ""
      ;;
    task_start)
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$extra" start 2>/dev/null
      notify "Task #${extra} started"
      cache_invalidate "tasks"
      render_screen "tasks" ""
      ;;
    task_stop)
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$extra" stop 2>/dev/null
      notify "Task #${extra} stopped"
      cache_invalidate "tasks"
      render_screen "tasks" ""
      ;;
    list_finish)
      local list_dir list_name
      list_dir="$(profile_list_dir)"
      list_name="$(profile_current_list)"
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -f "$extra" 2>/dev/null
      notify "Item done"
      cache_invalidate "lists"
      render_screen "lists" ""
      ;;
    list_remove)
      local list_dir list_name
      list_dir="$(profile_list_dir)"
      list_name="$(profile_current_list)"
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -r "$extra" 2>/dev/null
      notify "Item removed"
      cache_invalidate "lists"
      render_screen "lists" ""
      ;;
    list_switch)
      local list_dir list_name profile
      list_dir="$(profile_list_dir)"
      list_name="$(profile_current_list)"
      profile="$(profile_name)"
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --profile-name "$profile" switch "$extra" 2>/dev/null
      notify "Switched to: $extra"
      cache_invalidate "lists"
      render_screen "lists" ""
      ;;
    profile_switch)
      echo "$extra" > "${STATE_DIR}/last-profile"
      _profile="" _profile_base=""
      notify "Switched to: $extra"
      render_screen "home" ""
      ;;
    sync_run)
      ww issues "$extra" 2>/dev/null &
      notify "Sync: $extra started"
      render_screen "sync" ""
      ;;
    task_start_timer)
      local desc
      desc=$(TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$extra" export 2>/dev/null | \
        python3 -c "import json,sys;print(json.load(sys.stdin)[0].get('description',''))" 2>/dev/null)
      TIMEWARRIORDB="$(profile_twdb)" timew start $desc 2>/dev/null
      add_recent "$desc"
      notify "Tracking: $desc"
      render_screen "tasks" ""
      ;;
    task_set_project)
      local tid="${extra%%|*}" proj="${extra#*|}"
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$tid" modify "project:${proj}" 2>/dev/null
      notify "Project updated"
      cache_invalidate "tasks"
      render_screen "task_action" "$tid"
      ;;
    task_set_priority)
      local tid="${extra%%|*}" pri="${extra#*|}"
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$tid" modify "priority:${pri}" 2>/dev/null
      notify "Priority updated"
      cache_invalidate "tasks"
      render_screen "task_action" "$tid"
      ;;
    task_set_due)
      local tid="${extra%%|*}" due="${extra#*|}"
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$tid" modify "due:${due}" 2>/dev/null
      notify "Due date updated"
      cache_invalidate "tasks"
      render_screen "task_action" "$tid"
      ;;
    task_add_tag)
      local tid="${extra%%|*}" tag="${extra#*|}"
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$tid" modify "+${tag}" 2>/dev/null
      notify "Tag added: +${tag}"
      cache_invalidate "tasks"
      render_screen "task_tags" "$tid"
      ;;
    task_remove_tag)
      local tid="${extra%%|*}" tag="${extra#*|}"
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$tid" modify "-${tag}" 2>/dev/null
      notify "Tag removed: -${tag}"
      cache_invalidate "tasks"
      render_screen "task_tags" "$tid"
      ;;
    task_denotate)
      local tid="${extra%%|*}" text="${extra#*|}"
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$tid" denotate "$text" 2>/dev/null
      notify "Note removed"
      cache_invalidate "tasks"
      render_screen "task_annotations" "$tid"
      ;;
    task_set_wait)
      local tid="${extra%%|*}" val="${extra#*|}"
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$tid" modify "wait:${val}" 2>/dev/null
      notify "Wait updated"
      cache_invalidate "tasks"
      render_screen "task_action" "$tid"
      ;;
    task_set_scheduled)
      local tid="${extra%%|*}" val="${extra#*|}"
      TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" \
        task rc.confirmation=no "$tid" modify "scheduled:${val}" 2>/dev/null
      notify "Scheduled updated"
      cache_invalidate "tasks"
      render_screen "task_action" "$tid"
      ;;
    journal_switch)
      # Switch to a named journal (store preference, re-render)
      # For now just re-render journal — multi-journal reading needs the name
      notify "Viewing: $extra"
      render_screen "journal" ""
      ;;
    ledger_log)
      local expense="${extra%%|*}" account="${extra#*|}"
      local amount desc
      amount=$(echo "$expense" | awk '{print $1}')
      desc=$(echo "$expense" | awk '{$1=""; sub(/^ /,""); print}')
      [[ -z "$desc" ]] && desc="Quick expense"
      local ledger_file; ledger_file=$(profile_ledger_file)
      if [[ -n "$ledger_file" ]]; then
        printf '\n%s %s\n    %s  $%s\n    %s\n' \
          "$(date '+%Y-%m-%d')" "$desc" "$account" "$amount" "assets:checking" >> "$ledger_file"
        notify "Logged: \$${amount} ${desc}"
      fi
      render_screen "ledger" ""
      ;;
    *)
      render_screen "$screen" "$arg"
      ;;
  esac
}

# --- Pick handler (item selected, show action menu) ---

handle_pick() {
  local target="$1" extra="$2" screen="$3" arg="$4"

  case "$target" in
    task)
      render_screen "task_action" "$extra"
      ;;
    list_item)
      render_screen "list_action" "$extra"
      ;;
    recent)
      # Start timer with recent activity
      _init_profile
      TIMEWARRIORDB="$(profile_twdb)" timew stop 2>/dev/null
      TIMEWARRIORDB="$(profile_twdb)" timew start $extra 2>/dev/null
      add_recent "$extra"
      notify "Tracking: $extra"
      render_screen "clock" ""
      ;;
    journal_entry)
      # View a journal entry by line number
      render_screen "journal_entry" "$extra"
      ;;
    *)
      render_screen "$screen" "$arg"
      ;;
  esac
}

# --- Journal file resolution ---

_resolve_journal_file() {
  _init_profile
  local cfg="${_profile_base}/jrnl.yaml"
  [[ -f "$cfg" ]] || return

  # jrnl.yaml format under journals: section is either:
  #   name: /absolute/path
  #   name: relative/path
  # OR (nested):
  #   name:
  #     journal: /path
  # Handle both formats.
  local jpath
  # Try flat format first (most common): "  name: /path"
  jpath=$(awk '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && /^  [a-zA-Z]/{sub(/^  [a-zA-Z_-]+: */,""); print; exit}' "$cfg")

  # If that didn't work, try nested format: "    journal: /path"
  if [[ -z "$jpath" ]]; then
    jpath=$(awk '/^journals:/{found=1; next} found && /^[^ ]/{exit} found && /journal:/{gsub(/.*journal:\s*/,""); gsub(/\s*$/,""); print; exit}' "$cfg")
  fi

  [[ -z "$jpath" ]] && return
  # Resolve relative paths
  [[ "$jpath" != /* ]] && jpath="${_profile_base}/${jpath}"
  echo "$jpath"
}

# --- Ledger account picker (for $ prefix) ---

render_ledger_account_picker() {
  local expense="$1"
  local ledger_file
  ledger_file=$(profile_ledger_file)
  emit_prompt "Expense account"
  emit_message "Logging: \$${expense}"
  emit_data "ledger_pending:${expense}"
  emit_hotkeys

  if [[ -n "$ledger_file" && -f "$ledger_file" ]]; then
    local accounts
    accounts=$(hledger -f "$ledger_file" accounts 2>/dev/null)
    while IFS= read -r acct; do
      [[ -n "$acct" ]] && emit_row "$acct" "act:ledger_log:${expense}|${acct}"
    done <<< "$accounts"
  fi
  emit_sep
  emit_row "← Cancel" "nav:home"
}

# --- List filtered view ---

render_list_filtered() {
  local tag="$1"
  local list_dir list_name
  list_dir="$(profile_list_dir)"
  list_name="$(profile_current_list)"

  emit_prompt "#${tag}"
  emit_message "Filtered: ${list_name} #${tag}"
  emit_data "lists"
  emit_hotkeys

  local output
  output=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -g "#${tag}" 2>/dev/null)
  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      local prefix="${line%% - *}"
      emit_row "$line" "pick:list_item:${prefix}"
    done <<< "$output"
  else
    emit_label "(no matches for #${tag})"
  fi
  emit_sep
  emit_row "← Back to Lists" "nav:lists"
}
