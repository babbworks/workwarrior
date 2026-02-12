#!/usr/bin/env bash
# Profile Statistics Library
# Gathers statistics from TaskWarrior, TimeWarrior, JRNL, and Hledger

# ============================================================================
# CONFIGURATION
# ============================================================================

# Requires these environment variables to be set:
# TASKRC, TASKDATA - TaskWarrior paths
# TIMEWARRIORDB - TimeWarrior database path
# WORKWARRIOR_BASE - Profile base directory

# ============================================================================
# TASKWARRIOR STATISTICS
# ============================================================================

# Get task counts and summary
# Returns: pending|completed|waiting|total|projects_count
get_task_stats() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/.task" ]]; then
    echo "0|0|0|0|0"
    return 1
  fi

  local taskrc="$profile_dir/.taskrc"
  local taskdata="$profile_dir/.task"

  if ! command -v task &>/dev/null; then
    echo "0|0|0|0|0"
    return 1
  fi

  # Get counts using task commands
  local pending completed waiting total projects
  pending=$(TASKRC="$taskrc" TASKDATA="$taskdata" task status:pending count 2>/dev/null || echo "0")
  completed=$(TASKRC="$taskrc" TASKDATA="$taskdata" task status:completed count 2>/dev/null || echo "0")
  waiting=$(TASKRC="$taskrc" TASKDATA="$taskdata" task status:waiting count 2>/dev/null || echo "0")
  total=$((pending + completed + waiting))

  # Count unique projects
  projects=$(TASKRC="$taskrc" TASKDATA="$taskdata" task _unique project 2>/dev/null | wc -l | tr -d ' ')

  echo "${pending}|${completed}|${waiting}|${total}|${projects}"
}

# Get recent task activity
# Returns: line-separated list of recent tasks
get_task_recent() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"
  local limit="${2:-5}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/.task" ]]; then
    return 1
  fi

  local taskrc="$profile_dir/.taskrc"
  local taskdata="$profile_dir/.task"

  if ! command -v task &>/dev/null; then
    return 1
  fi

  # Get recently modified tasks
  TASKRC="$taskrc" TASKDATA="$taskdata" task rc.verbose=nothing rc.report.recent.columns=description rc.report.recent.labels=Task limit:$limit modified.after:today-7d list 2>/dev/null | head -n "$limit"
}

# Get last task modification time
# Returns: ISO timestamp or empty
get_task_last_modified() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/.task" ]]; then
    return 1
  fi

  local taskrc="$profile_dir/.taskrc"
  local taskdata="$profile_dir/.task"

  if ! command -v task &>/dev/null; then
    return 1
  fi

  # Get the most recent modification
  TASKRC="$taskrc" TASKDATA="$taskdata" task rc.verbose=nothing rc.report.all.sort=modified- limit:1 _get 1.modified 2>/dev/null
}

# ============================================================================
# TIMEWARRIOR STATISTICS
# ============================================================================

# Get time tracking stats
# Returns: total_hours|week_hours|month_hours|entries_count
get_time_stats() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/.timewarrior" ]]; then
    echo "0|0|0|0"
    return 1
  fi

  local timedb="$profile_dir/.timewarrior"

  if ! command -v timew &>/dev/null; then
    echo "0|0|0|0"
    return 1
  fi

  # Get time summaries
  local total_seconds week_seconds month_seconds entries

  # Total time (all time)
  total_seconds=$(TIMEWARRIORDB="$timedb" timew export 2>/dev/null | \
    grep -o '"end":"[^"]*"' | wc -l | tr -d ' ')

  # This week
  week_seconds=$(TIMEWARRIORDB="$timedb" timew summary :week 2>/dev/null | \
    tail -1 | awk '{print $NF}' | sed 's/://g')

  # This month
  month_seconds=$(TIMEWARRIORDB="$timedb" timew summary :month 2>/dev/null | \
    tail -1 | awk '{print $NF}' | sed 's/://g')

  # Count entries from data files
  entries=0
  if [[ -d "$timedb/data" ]]; then
    entries=$(grep -h "^inc " "$timedb/data/"*.data 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Convert to hours (approximate from summary output)
  local total_hours week_hours month_hours
  total_hours=$(parse_time_to_hours "$total_seconds")
  week_hours=$(parse_time_summary "$week_seconds")
  month_hours=$(parse_time_summary "$month_seconds")

  echo "${total_hours:-0}|${week_hours:-0}|${month_hours:-0}|${entries:-0}"
}

# Parse timew summary time format (HH:MM:SS) to hours
parse_time_summary() {
  local time_str="$1"
  if [[ -z "$time_str" ]]; then
    echo "0"
    return
  fi

  # Handle HH:MM:SS format
  if [[ "$time_str" =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
    local hours="${BASH_REMATCH[1]}"
    local mins="${BASH_REMATCH[2]}"
    echo "$hours"
  elif [[ "$time_str" =~ ^([0-9]+):([0-9]+)$ ]]; then
    local hours="${BASH_REMATCH[1]}"
    echo "$hours"
  else
    echo "0"
  fi
}

# Parse total entries to approximate hours
parse_time_to_hours() {
  local entries="$1"
  # Rough estimate: average 30 min per entry
  echo $(( (entries * 30) / 60 ))
}

# Get recent time entries
get_time_recent() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"
  local limit="${2:-5}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/.timewarrior" ]]; then
    return 1
  fi

  local timedb="$profile_dir/.timewarrior"

  if ! command -v timew &>/dev/null; then
    return 1
  fi

  TIMEWARRIORDB="$timedb" timew summary :week :ids 2>/dev/null | head -n "$((limit + 2))" | tail -n "$limit"
}

# Get last time entry timestamp
get_time_last_entry() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/.timewarrior/data" ]]; then
    return 1
  fi

  # Get most recent entry from data files
  local latest_file
  latest_file=$(ls -t "$profile_dir/.timewarrior/data/"*.data 2>/dev/null | head -1)

  if [[ -n "$latest_file" ]]; then
    tail -1 "$latest_file" 2>/dev/null | grep -o '^inc [0-9T:-]*' | cut -d' ' -f2
  fi
}

# ============================================================================
# JRNL STATISTICS
# ============================================================================

# Get journal stats
# Returns: total_entries|journals_count|this_month_entries
get_journal_stats() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/journals" ]]; then
    echo "0|0|0"
    return 1
  fi

  local journals_dir="$profile_dir/journals"
  local total_entries=0
  local journals_count=0
  local month_entries=0
  local current_month
  current_month=$(date +"%Y-%m")

  # Count journals and entries
  for journal_file in "$journals_dir"/*.txt; do
    if [[ -f "$journal_file" ]]; then
      ((journals_count++))
      # Count entries (lines starting with [date])
      local entries
      entries=$(grep -c '^\[' "$journal_file" 2>/dev/null || echo "0")
      total_entries=$((total_entries + entries))

      # Count this month's entries
      local month_count
      month_count=$(grep -c "^\[$current_month" "$journal_file" 2>/dev/null || echo "0")
      month_entries=$((month_entries + month_count))
    fi
  done

  echo "${total_entries}|${journals_count}|${month_entries}"
}

# Get recent journal entries
get_journal_recent() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"
  local limit="${2:-5}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/journals" ]]; then
    return 1
  fi

  local journals_dir="$profile_dir/journals"

  # Collect recent entries from all journals, sort by date
  for journal_file in "$journals_dir"/*.txt; do
    if [[ -f "$journal_file" ]]; then
      # Extract entries with timestamps
      grep '^\[' "$journal_file" 2>/dev/null
    fi
  done | sort -r | head -n "$limit" | cut -c1-60
}

# Get last journal entry timestamp
get_journal_last_entry() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/journals" ]]; then
    return 1
  fi

  local journals_dir="$profile_dir/journals"
  local latest_date=""

  for journal_file in "$journals_dir"/*.txt; do
    if [[ -f "$journal_file" ]]; then
      local last_entry
      last_entry=$(grep '^\[' "$journal_file" 2>/dev/null | tail -1 | grep -o '^\[[^]]*\]' | tr -d '[]')
      if [[ "$last_entry" > "$latest_date" ]]; then
        latest_date="$last_entry"
      fi
    fi
  done

  echo "$latest_date"
}

# ============================================================================
# HLEDGER STATISTICS
# ============================================================================

# Get ledger stats
# Returns: transactions|accounts|ledgers_count
get_ledger_stats() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/ledgers" ]]; then
    echo "0|0|0"
    return 1
  fi

  local ledgers_dir="$profile_dir/ledgers"
  local total_transactions=0
  local total_accounts=0
  local ledgers_count=0

  # Count ledger files and transactions
  for ledger_file in "$ledgers_dir"/*.journal; do
    if [[ -f "$ledger_file" ]]; then
      ((ledgers_count++))

      if command -v hledger &>/dev/null; then
        # Use hledger for accurate counts
        local txns accts
        txns=$(hledger -f "$ledger_file" stats 2>/dev/null | grep "Transactions" | awk '{print $NF}' || echo "0")
        accts=$(hledger -f "$ledger_file" accounts 2>/dev/null | wc -l | tr -d ' ')
        total_transactions=$((total_transactions + txns))
        total_accounts=$((total_accounts + accts))
      else
        # Fallback: count transaction lines (lines starting with date)
        local txns
        txns=$(grep -cE '^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}' "$ledger_file" 2>/dev/null || echo "0")
        total_transactions=$((total_transactions + txns))
      fi
    fi
  done

  echo "${total_transactions}|${total_accounts}|${ledgers_count}"
}

# Get recent ledger transactions
get_ledger_recent() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"
  local limit="${2:-5}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/ledgers" ]]; then
    return 1
  fi

  local ledgers_dir="$profile_dir/ledgers"

  if command -v hledger &>/dev/null; then
    for ledger_file in "$ledgers_dir"/*.journal; do
      if [[ -f "$ledger_file" ]]; then
        hledger -f "$ledger_file" register -n "$limit" 2>/dev/null
      fi
    done | head -n "$limit"
  fi
}

# Get last ledger transaction date
get_ledger_last_entry() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"

  if [[ -z "$profile_dir" ]] || [[ ! -d "$profile_dir/ledgers" ]]; then
    return 1
  fi

  local ledgers_dir="$profile_dir/ledgers"
  local latest_date=""

  for ledger_file in "$ledgers_dir"/*.journal; do
    if [[ -f "$ledger_file" ]]; then
      local last_date
      last_date=$(grep -oE '^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}' "$ledger_file" 2>/dev/null | tail -1)
      if [[ "$last_date" > "$latest_date" ]]; then
        latest_date="$last_date"
      fi
    fi
  done

  echo "$latest_date"
}

# ============================================================================
# AGGREGATED STATISTICS
# ============================================================================

# Get overall profile activity summary
# Returns associative array via global variable
get_profile_summary() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"

  # Task stats
  local task_stats
  task_stats=$(get_task_stats "$profile_dir")
  PROFILE_TASKS_PENDING=$(echo "$task_stats" | cut -d'|' -f1)
  PROFILE_TASKS_COMPLETED=$(echo "$task_stats" | cut -d'|' -f2)
  PROFILE_TASKS_WAITING=$(echo "$task_stats" | cut -d'|' -f3)
  PROFILE_TASKS_TOTAL=$(echo "$task_stats" | cut -d'|' -f4)
  PROFILE_TASKS_PROJECTS=$(echo "$task_stats" | cut -d'|' -f5)

  # Time stats
  local time_stats
  time_stats=$(get_time_stats "$profile_dir")
  PROFILE_TIME_TOTAL=$(echo "$time_stats" | cut -d'|' -f1)
  PROFILE_TIME_WEEK=$(echo "$time_stats" | cut -d'|' -f2)
  PROFILE_TIME_MONTH=$(echo "$time_stats" | cut -d'|' -f3)
  PROFILE_TIME_ENTRIES=$(echo "$time_stats" | cut -d'|' -f4)

  # Journal stats
  local journal_stats
  journal_stats=$(get_journal_stats "$profile_dir")
  PROFILE_JOURNAL_TOTAL=$(echo "$journal_stats" | cut -d'|' -f1)
  PROFILE_JOURNAL_COUNT=$(echo "$journal_stats" | cut -d'|' -f2)
  PROFILE_JOURNAL_MONTH=$(echo "$journal_stats" | cut -d'|' -f3)

  # Ledger stats
  local ledger_stats
  ledger_stats=$(get_ledger_stats "$profile_dir")
  PROFILE_LEDGER_TXNS=$(echo "$ledger_stats" | cut -d'|' -f1)
  PROFILE_LEDGER_ACCTS=$(echo "$ledger_stats" | cut -d'|' -f2)
  PROFILE_LEDGER_COUNT=$(echo "$ledger_stats" | cut -d'|' -f3)
}

# Get the most recent activity across all tools
# Returns: timestamp|source|description
get_last_activity() {
  local profile_dir="${1:-$WORKWARRIOR_BASE}"

  local task_time journal_time ledger_time time_time
  local latest_source="" latest_time=""

  # Get last activity from each source
  task_time=$(get_task_last_modified "$profile_dir" 2>/dev/null)
  time_time=$(get_time_last_entry "$profile_dir" 2>/dev/null)
  journal_time=$(get_journal_last_entry "$profile_dir" 2>/dev/null)
  ledger_time=$(get_ledger_last_entry "$profile_dir" 2>/dev/null)

  # Find the most recent
  for entry in "task:$task_time" "time:$time_time" "journal:$journal_time" "ledger:$ledger_time"; do
    local source="${entry%%:*}"
    local time="${entry#*:}"
    if [[ -n "$time" && "$time" > "$latest_time" ]]; then
      latest_time="$time"
      latest_source="$source"
    fi
  done

  if [[ -n "$latest_time" ]]; then
    echo "${latest_time}|${latest_source}"
  fi
}

# Format relative time (e.g., "2 hours ago")
format_relative_time() {
  local timestamp="$1"

  if [[ -z "$timestamp" ]]; then
    echo "never"
    return
  fi

  # Try to parse the timestamp
  local epoch_then epoch_now diff

  # Handle different timestamp formats
  if [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
    # ISO format
    epoch_then=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${timestamp%%.*}" "+%s" 2>/dev/null || echo "0")
  elif [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ ]]; then
    # Date with space
    epoch_then=$(date -j -f "%Y-%m-%d %H:%M" "$timestamp" "+%s" 2>/dev/null || echo "0")
  elif [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    # Date only
    epoch_then=$(date -j -f "%Y-%m-%d" "$timestamp" "+%s" 2>/dev/null || echo "0")
  else
    echo "$timestamp"
    return
  fi

  epoch_now=$(date "+%s")
  diff=$((epoch_now - epoch_then))

  if (( diff < 60 )); then
    echo "just now"
  elif (( diff < 3600 )); then
    echo "$((diff / 60)) minutes ago"
  elif (( diff < 86400 )); then
    echo "$((diff / 3600)) hours ago"
  elif (( diff < 604800 )); then
    echo "$((diff / 86400)) days ago"
  else
    echo "$((diff / 604800)) weeks ago"
  fi
}

# ============================================================================
# MAIN (for testing)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  profile_dir="${1:-$WORKWARRIOR_BASE}"

  echo "Profile Statistics for: $profile_dir"
  echo "=================================="
  echo ""

  echo "Tasks: $(get_task_stats "$profile_dir")"
  echo "Time:  $(get_time_stats "$profile_dir")"
  echo "Journal: $(get_journal_stats "$profile_dir")"
  echo "Ledger: $(get_ledger_stats "$profile_dir")"
  echo ""
  echo "Last activity: $(get_last_activity "$profile_dir")"
fi
