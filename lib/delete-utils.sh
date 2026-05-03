#!/usr/bin/env bash
# Delete Utilities Library
# Core functions for safely deleting profile data

# ============================================================================
# CONFIGURATION
# ============================================================================

WW_BASE="${WW_BASE:-$HOME/ww}"
EXPORT_DIR="${WW_BASE}/exports"
SHELL_RC="${HOME}/.bashrc"

# ============================================================================
# SAFETY CHECKS
# ============================================================================

# Check if a profile is currently active
check_profile_active() {
  local profile_name="$1"
  [[ "$WARRIOR_PROFILE" == "$profile_name" ]]
}

# Error if profile is active
require_inactive_profile() {
  local profile_name="$1"

  if check_profile_active "$profile_name"; then
    echo "ERROR: Cannot delete active profile '$profile_name'"
    echo ""
    echo "Deactivate the profile first by:"
    echo "  1. Opening a new terminal, or"
    echo "  2. Running: unset WARRIOR_PROFILE TASKRC TASKDATA TIMEWARRIORDB WORKWARRIOR_BASE"
    return 1
  fi
  return 0
}

# Get profile directory, verify it exists
get_profile_dir() {
  local profile_name="$1"
  local profile_dir="$WW_BASE/profiles/$profile_name"

  if [[ ! -d "$profile_dir" ]]; then
    echo "ERROR: Profile not found: $profile_name" >&2
    return 1
  fi

  echo "$profile_dir"
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

# Create backup before deletion
backup_before_delete() {
  local profile_name="$1"
  local profile_dir="$2"

  local backup_dir="$EXPORT_DIR/$profile_name"
  mkdir -p "$backup_dir"

  local timestamp
  timestamp=$(date +"%Y-%m-%d_%H%M%S")
  local backup_file="$backup_dir/${timestamp}_backup_pre-delete.tar.gz"

  if tar -czf "$backup_file" -C "$WW_BASE/profiles" "$profile_name" 2>/dev/null; then
    echo "$backup_file"
    return 0
  else
    echo "ERROR: Failed to create backup" >&2
    return 1
  fi
}

# ============================================================================
# STATISTICS FOR CONFIRMATION
# ============================================================================

# Get task count for profile
get_task_count() {
  local profile_dir="$1"
  local taskrc="$profile_dir/.taskrc"
  local taskdata="$profile_dir/.task"

  if [[ -d "$taskdata" ]] && command -v task &>/dev/null; then
    local pending completed
    pending=$(TASKRC="$taskrc" TASKDATA="$taskdata" task status:pending count 2>/dev/null || echo "0")
    completed=$(TASKRC="$taskrc" TASKDATA="$taskdata" task status:completed count 2>/dev/null || echo "0")
    echo "$pending pending, $completed completed"
  else
    echo "0"
  fi
}

# Get time entry count
get_time_count() {
  local profile_dir="$1"
  local timedb="$profile_dir/.timewarrior"

  if [[ -d "$timedb/data" ]]; then
    local count
    count=$(grep -h "^inc " "$timedb/data/"*.data 2>/dev/null | wc -l | tr -d ' ')
    echo "$count entries"
  else
    echo "0"
  fi
}

# Get journal entry count
get_journal_count() {
  local profile_dir="$1"
  local journals_dir="$profile_dir/journals"

  if [[ -d "$journals_dir" ]]; then
    local count=0
    local journal_count=0
    for f in "$journals_dir"/*.txt; do
      if [[ -f "$f" ]]; then
        ((journal_count++))
        local entries
        entries=$(grep -c '^\[' "$f" 2>/dev/null || echo "0")
        count=$((count + entries))
      fi
    done
    echo "$count entries across $journal_count journals"
  else
    echo "0"
  fi
}

# Get ledger transaction count
get_ledger_count() {
  local profile_dir="$1"
  local ledgers_dir="$profile_dir/ledgers"

  if [[ -d "$ledgers_dir" ]]; then
    local count=0
    for f in "$ledgers_dir"/*.journal; do
      if [[ -f "$f" ]]; then
        local txns
        txns=$(grep -cE '^[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}' "$f" 2>/dev/null || echo "0")
        count=$((count + txns))
      fi
    done
    echo "$count transactions"
  else
    echo "0"
  fi
}

# ============================================================================
# PROFILE DELETION
# ============================================================================

# Delete entire profile directory
delete_profile() {
  local profile_name="$1"
  local profile_dir="$2"

  if [[ -d "$profile_dir" ]]; then
    rm -rf "$profile_dir"
    return $?
  fi
  return 0
}

# Remove profile aliases from shell RC
delete_profile_aliases() {
  local profile_name="$1"

  if [[ ! -f "$SHELL_RC" ]]; then
    return 0
  fi

  local temp_file="${SHELL_RC}.tmp"

  # Remove lines containing profile-specific aliases
  grep -v "alias p-${profile_name}=" "$SHELL_RC" | \
  grep -v "alias j-${profile_name}=" | \
  grep -v "alias l-${profile_name}=" | \
  grep -v "alias list-${profile_name}=" | \
  grep -v "alias tui-${profile_name}=" > "$temp_file"

  mv "$temp_file" "$SHELL_RC"
}

# ============================================================================
# TOOL DATA DELETION
# ============================================================================

# Delete TaskWarrior data
delete_tasks_data() {
  local profile_dir="$1"
  local task_dir="$profile_dir/.task"

  if [[ -d "$task_dir" ]]; then
    rm -rf "$task_dir"
    # Recreate empty directory structure
    mkdir -p "$task_dir/hooks"
    return $?
  fi
  return 0
}

# Delete TimeWarrior data
delete_time_data() {
  local profile_dir="$1"
  local time_dir="$profile_dir/.timewarrior"

  if [[ -d "$time_dir/data" ]]; then
    rm -rf "$time_dir/data"
    mkdir -p "$time_dir/data"
    return $?
  fi
  return 0
}

# Delete journal data
delete_journal_data() {
  local profile_dir="$1"
  local journals_dir="$profile_dir/journals"

  if [[ -d "$journals_dir" ]]; then
    rm -rf "$journals_dir"
    mkdir -p "$journals_dir"
    return $?
  fi
  return 0
}

# Delete ledger data
delete_ledger_data() {
  local profile_dir="$1"
  local ledgers_dir="$profile_dir/ledgers"

  if [[ -d "$ledgers_dir" ]]; then
    rm -rf "$ledgers_dir"
    mkdir -p "$ledgers_dir"
    return $?
  fi
  return 0
}

# ============================================================================
# CONFIG DELETION
# ============================================================================

# Delete TaskWarrior config
delete_task_config() {
  local profile_dir="$1"
  local taskrc="$profile_dir/.taskrc"

  if [[ -f "$taskrc" ]]; then
    rm -f "$taskrc"
    return $?
  fi
  return 0
}

# Delete TimeWarrior config
delete_time_config() {
  local profile_dir="$1"
  local timecfg="$profile_dir/.timewarrior/timewarrior.cfg"

  if [[ -f "$timecfg" ]]; then
    rm -f "$timecfg"
    return $?
  fi
  return 0
}

# Delete journal config
delete_journal_config() {
  local profile_dir="$1"
  local jrnlcfg="$profile_dir/jrnl.yaml"

  if [[ -f "$jrnlcfg" ]]; then
    rm -f "$jrnlcfg"
    return $?
  fi
  return 0
}

# Delete ledger config
delete_ledger_config() {
  local profile_dir="$1"
  local ledgercfg="$profile_dir/ledgers.yaml"

  if [[ -f "$ledgercfg" ]]; then
    rm -f "$ledgercfg"
    return $?
  fi
  return 0
}

# ============================================================================
# EXPORT CLEANUP
# ============================================================================

# Delete profile exports
delete_profile_exports() {
  local profile_name="$1"
  local export_dir="$EXPORT_DIR/$profile_name"

  if [[ -d "$export_dir" ]]; then
    rm -rf "$export_dir"
    return $?
  fi
  return 0
}

# ============================================================================
# DRY-RUN / PREVIEW
# ============================================================================

# Preview what would be deleted for a profile
preview_profile_deletion() {
  local profile_name="$1"
  local profile_dir="$2"

  echo ""
  echo "DRY RUN - No changes will be made"
  echo ""
  echo "Would delete:"

  local dir_count=0
  local file_count=0
  local alias_count=0

  # Directories
  for dir in ".task" ".timewarrior" "journals" "ledgers" "todo"; do
    if [[ -d "$profile_dir/$dir" ]]; then
      echo "  [dir]  $profile_dir/$dir/"
      ((dir_count++))
    fi
  done

  # Config files
  for file in ".taskrc" "jrnl.yaml" "ledgers.yaml" "profile.yaml"; do
    if [[ -f "$profile_dir/$file" ]]; then
      echo "  [file] $profile_dir/$file"
      ((file_count++))
    fi
  done

  # Aliases
  if [[ -f "$SHELL_RC" ]]; then
    for alias_prefix in "p-" "j-" "l-" "list-" "tui-"; do
      if grep -q "alias ${alias_prefix}${profile_name}=" "$SHELL_RC" 2>/dev/null; then
        echo "  [alias] ${alias_prefix}${profile_name} (in $SHELL_RC)"
        ((alias_count++))
      fi
    done
  fi

  # Exports
  if [[ -d "$EXPORT_DIR/$profile_name" ]]; then
    local export_count
    export_count=$(find "$EXPORT_DIR/$profile_name" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  [dir]  $EXPORT_DIR/$profile_name/ ($export_count files)"
    ((dir_count++))
  fi

  echo ""
  echo "Total: $dir_count directories, $file_count files, $alias_count aliases"
  echo ""
}

# Preview tool data deletion
preview_tool_deletion() {
  local profile_dir="$1"
  local tool="$2"

  echo ""
  echo "DRY RUN - No changes will be made"
  echo ""
  echo "Would delete:"

  case "$tool" in
    tasks)
      if [[ -d "$profile_dir/.task" ]]; then
        local size
        size=$(du -sh "$profile_dir/.task" 2>/dev/null | cut -f1)
        echo "  [dir] $profile_dir/.task/ ($size)"
      fi
      ;;
    time)
      if [[ -d "$profile_dir/.timewarrior/data" ]]; then
        local size
        size=$(du -sh "$profile_dir/.timewarrior/data" 2>/dev/null | cut -f1)
        echo "  [dir] $profile_dir/.timewarrior/data/ ($size)"
      fi
      ;;
    journal)
      if [[ -d "$profile_dir/journals" ]]; then
        local size
        size=$(du -sh "$profile_dir/journals" 2>/dev/null | cut -f1)
        echo "  [dir] $profile_dir/journals/ ($size)"
      fi
      ;;
    ledger)
      if [[ -d "$profile_dir/ledgers" ]]; then
        local size
        size=$(du -sh "$profile_dir/ledgers" 2>/dev/null | cut -f1)
        echo "  [dir] $profile_dir/ledgers/ ($size)"
      fi
      ;;
  esac

  echo ""
}

# ============================================================================
# MAIN (for testing)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Delete Utils Library"
  echo "===================="
  echo ""
  echo "Functions available:"
  echo "  check_profile_active <name>"
  echo "  require_inactive_profile <name>"
  echo "  backup_before_delete <name> <dir>"
  echo "  delete_profile <name> <dir>"
  echo "  delete_profile_aliases <name>"
  echo "  delete_tasks_data <dir>"
  echo "  delete_time_data <dir>"
  echo "  delete_journal_data <dir>"
  echo "  delete_ledger_data <dir>"
  echo "  delete_task_config <dir>"
  echo "  delete_journal_config <dir>"
  echo "  delete_ledger_config <dir>"
  echo "  delete_profile_exports <name>"
  echo "  preview_profile_deletion <name> <dir>"
fi
