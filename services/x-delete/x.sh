#!/usr/bin/env bash
# X Service - Delete profiles and data with safety measures
# Usage: x [type] [options]

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

WW_BASE="${WW_BASE:-$HOME/ww}"

# Source libraries
if [[ -f "$WW_BASE/lib/core-utils.sh" ]]; then
  source "$WW_BASE/lib/core-utils.sh"
else
  log_info() { echo "info: $*"; }
  log_error() { echo "error: $*" >&2; }
  log_success() { echo "ok: $*"; }
  log_warning() { echo "warn: $*"; }
fi

if [[ -f "$WW_BASE/lib/delete-utils.sh" ]]; then
  source "$WW_BASE/lib/delete-utils.sh"
else
  log_error "Delete utilities library not found"
  exit 1
fi

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

DELETE_TYPE=""
PROFILE_NAME=""
DRY_RUN=false
FORCE=false
NO_BACKUP=false

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      profile|tasks|time|journal|ledger|config|aliases|exports)
        DELETE_TYPE="$1"
        shift
        # Next arg might be profile name or tool name
        if [[ -n "${1:-}" && ! "$1" =~ ^- ]]; then
          PROFILE_NAME="$1"
          shift
        fi
        ;;
      -p|--profile)
        PROFILE_NAME="$2"
        shift 2
        ;;
      -n|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      --no-backup)
        NO_BACKUP=true
        shift
        ;;
      -h|--help|help)
        show_help
        exit 0
        ;;
      *)
        log_error "Unknown argument: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

resolve_profile() {
  if [[ -z "$PROFILE_NAME" ]]; then
    PROFILE_NAME="$WARRIOR_PROFILE"
  fi

  if [[ -z "$PROFILE_NAME" ]]; then
    log_error "No profile specified and no active profile"
    log_info "Use: x <type> --profile <name> or specify profile name"
    exit 1
  fi
}

confirm_deletion() {
  local message="$1"

  if [[ "$FORCE" == true ]]; then
    return 0
  fi

  echo ""
  echo "$message"
  echo ""
  read -p "Type 'yes' to confirm deletion: " confirm

  if [[ "$confirm" != "yes" ]]; then
    log_info "Deletion cancelled"
    exit 0
  fi
}

# ============================================================================
# DELETE COMMANDS
# ============================================================================

do_delete_profile() {
  local profile_name="$1"

  # Get profile directory
  local profile_dir
  profile_dir=$(get_profile_dir "$profile_name") || exit 1

  # Check if active
  if ! require_inactive_profile "$profile_name"; then
    exit 1
  fi

  # Dry run
  if [[ "$DRY_RUN" == true ]]; then
    preview_profile_deletion "$profile_name" "$profile_dir"
    return 0
  fi

  # Gather stats for confirmation
  local task_count time_count journal_count ledger_count
  task_count=$(get_task_count "$profile_dir")
  time_count=$(get_time_count "$profile_dir")
  journal_count=$(get_journal_count "$profile_dir")
  ledger_count=$(get_ledger_count "$profile_dir")

  # Show warning and confirm
  local warning="WARNING: This will permanently delete:
  - Profile: $profile_name
  - Tasks: $task_count
  - Time: $time_count
  - Journal: $journal_count
  - Ledger: $ledger_count
  - Config files and aliases"

  if [[ "$NO_BACKUP" != true ]]; then
    warning+="\n\nA backup will be created before deletion."
  else
    warning+="\n\nWARNING: --no-backup specified, NO BACKUP will be created!"
  fi

  confirm_deletion "$warning"

  # Create backup
  if [[ "$NO_BACKUP" != true ]]; then
    log_info "Creating backup..."
    local backup_path
    backup_path=$(backup_before_delete "$profile_name" "$profile_dir")
    if [[ -n "$backup_path" ]]; then
      log_success "Backup created: $backup_path"
    else
      log_error "Backup failed, aborting deletion"
      exit 1
    fi
  fi

  # Delete aliases
  log_info "Removing shell aliases..."
  delete_profile_aliases "$profile_name"

  # Delete profile directory
  log_info "Deleting profile directory..."
  delete_profile "$profile_name" "$profile_dir"

  log_success "Profile '$profile_name' deleted"
}

do_delete_tasks() {
  local profile_name="$1"

  local profile_dir
  profile_dir=$(get_profile_dir "$profile_name") || exit 1

  if ! require_inactive_profile "$profile_name"; then
    exit 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    preview_tool_deletion "$profile_dir" "tasks"
    return 0
  fi

  local task_count
  task_count=$(get_task_count "$profile_dir")

  confirm_deletion "WARNING: This will delete all TaskWarrior data for '$profile_name':
  - Tasks: $task_count

Data directory: $profile_dir/.task/"

  if [[ "$NO_BACKUP" != true ]]; then
    log_info "Creating backup..."
    backup_before_delete "$profile_name" "$profile_dir" >/dev/null
  fi

  log_info "Deleting task data..."
  delete_tasks_data "$profile_dir"

  log_success "Task data deleted for '$profile_name'"
}

do_delete_time() {
  local profile_name="$1"

  local profile_dir
  profile_dir=$(get_profile_dir "$profile_name") || exit 1

  if ! require_inactive_profile "$profile_name"; then
    exit 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    preview_tool_deletion "$profile_dir" "time"
    return 0
  fi

  local time_count
  time_count=$(get_time_count "$profile_dir")

  confirm_deletion "WARNING: This will delete all TimeWarrior data for '$profile_name':
  - Time: $time_count

Data directory: $profile_dir/.timewarrior/data/"

  if [[ "$NO_BACKUP" != true ]]; then
    log_info "Creating backup..."
    backup_before_delete "$profile_name" "$profile_dir" >/dev/null
  fi

  log_info "Deleting time data..."
  delete_time_data "$profile_dir"

  log_success "Time data deleted for '$profile_name'"
}

do_delete_journal() {
  local profile_name="$1"

  local profile_dir
  profile_dir=$(get_profile_dir "$profile_name") || exit 1

  if ! require_inactive_profile "$profile_name"; then
    exit 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    preview_tool_deletion "$profile_dir" "journal"
    return 0
  fi

  local journal_count
  journal_count=$(get_journal_count "$profile_dir")

  confirm_deletion "WARNING: This will delete all journal entries for '$profile_name':
  - Journal: $journal_count

Data directory: $profile_dir/journals/"

  if [[ "$NO_BACKUP" != true ]]; then
    log_info "Creating backup..."
    backup_before_delete "$profile_name" "$profile_dir" >/dev/null
  fi

  log_info "Deleting journal data..."
  delete_journal_data "$profile_dir"

  log_success "Journal data deleted for '$profile_name'"
}

do_delete_ledger() {
  local profile_name="$1"

  local profile_dir
  profile_dir=$(get_profile_dir "$profile_name") || exit 1

  if ! require_inactive_profile "$profile_name"; then
    exit 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    preview_tool_deletion "$profile_dir" "ledger"
    return 0
  fi

  local ledger_count
  ledger_count=$(get_ledger_count "$profile_dir")

  confirm_deletion "WARNING: This will delete all ledger data for '$profile_name':
  - Ledger: $ledger_count

Data directory: $profile_dir/ledgers/"

  if [[ "$NO_BACKUP" != true ]]; then
    log_info "Creating backup..."
    backup_before_delete "$profile_name" "$profile_dir" >/dev/null
  fi

  log_info "Deleting ledger data..."
  delete_ledger_data "$profile_dir"

  log_success "Ledger data deleted for '$profile_name'"
}

do_delete_config() {
  local tool="$1"

  resolve_profile
  local profile_dir
  profile_dir=$(get_profile_dir "$PROFILE_NAME") || exit 1

  case "$tool" in
    tasks|taskwarrior)
      confirm_deletion "This will delete TaskWarrior config for '$PROFILE_NAME':
  - File: $profile_dir/.taskrc"
      delete_task_config "$profile_dir"
      log_success "TaskWarrior config deleted"
      ;;
    time|timewarrior)
      confirm_deletion "This will delete TimeWarrior config for '$PROFILE_NAME':
  - File: $profile_dir/.timewarrior/timewarrior.cfg"
      delete_time_config "$profile_dir"
      log_success "TimeWarrior config deleted"
      ;;
    journal|jrnl)
      confirm_deletion "This will delete JRNL config for '$PROFILE_NAME':
  - File: $profile_dir/jrnl.yaml"
      delete_journal_config "$profile_dir"
      log_success "JRNL config deleted"
      ;;
    ledger|hledger)
      confirm_deletion "This will delete Hledger config for '$PROFILE_NAME':
  - File: $profile_dir/ledgers.yaml"
      delete_ledger_config "$profile_dir"
      log_success "Hledger config deleted"
      ;;
    *)
      log_error "Unknown tool: $tool"
      log_info "Available: tasks, time, journal, ledger"
      exit 1
      ;;
  esac
}

do_delete_aliases() {
  local profile_name="$1"

  # Check profile exists
  get_profile_dir "$profile_name" >/dev/null || exit 1

  if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "DRY RUN - Would remove aliases for '$profile_name' from ~/.bashrc"
    grep -E "alias (p|j|l|list|tui)-${profile_name}=" ~/.bashrc 2>/dev/null || echo "(no aliases found)"
    return 0
  fi

  confirm_deletion "This will remove shell aliases for '$profile_name':
  - p-$profile_name
  - j-$profile_name
  - l-$profile_name
  - list-$profile_name (if exists)
  - tui-$profile_name (if exists)"

  log_info "Removing aliases..."
  delete_profile_aliases "$profile_name"

  log_success "Aliases removed for '$profile_name'"
  log_info "Run 'source ~/.bashrc' to apply changes"
}

do_delete_exports() {
  resolve_profile

  local export_dir="$WW_BASE/exports/$PROFILE_NAME"

  if [[ ! -d "$export_dir" ]]; then
    log_info "No exports found for '$PROFILE_NAME'"
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "DRY RUN - Would delete export directory:"
    echo "  $export_dir"
    local count
    count=$(find "$export_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  ($count files)"
    return 0
  fi

  local count
  count=$(find "$export_dir" -type f 2>/dev/null | wc -l | tr -d ' ')

  confirm_deletion "This will delete all exports for '$PROFILE_NAME':
  - Directory: $export_dir
  - Files: $count"

  log_info "Deleting exports..."
  delete_profile_exports "$PROFILE_NAME"

  log_success "Exports deleted for '$PROFILE_NAME'"
}

# ============================================================================
# INTERACTIVE MODE
# ============================================================================

interactive_delete() {
  echo ""
  echo "Delete Service"
  echo "=============="
  echo ""
  echo "What would you like to delete?"
  echo ""
  echo "  1. profile   - Delete entire profile"
  echo "  2. tasks     - Clear TaskWarrior data"
  echo "  3. time      - Clear TimeWarrior data"
  echo "  4. journal   - Clear journal entries"
  echo "  5. ledger    - Clear ledger data"
  echo "  6. config    - Remove tool configuration"
  echo "  7. aliases   - Remove shell aliases"
  echo "  8. exports   - Purge export files"
  echo ""
  read -p "Enter choice (1-8 or name): " choice

  case "$choice" in
    1|profile) DELETE_TYPE="profile" ;;
    2|tasks) DELETE_TYPE="tasks" ;;
    3|time) DELETE_TYPE="time" ;;
    4|journal) DELETE_TYPE="journal" ;;
    5|ledger) DELETE_TYPE="ledger" ;;
    6|config) DELETE_TYPE="config" ;;
    7|aliases) DELETE_TYPE="aliases" ;;
    8|exports) DELETE_TYPE="exports" ;;
    *)
      log_error "Invalid choice"
      exit 1
      ;;
  esac

  # Get profile name
  if [[ -z "$PROFILE_NAME" ]]; then
    echo ""
    echo "Available profiles:"
    for dir in "$WW_BASE/profiles/"*/; do
      if [[ -d "$dir" ]]; then
        local name
        name=$(basename "$dir")
        if [[ "$name" == "$WARRIOR_PROFILE" ]]; then
          echo "  - $name (active)"
        else
          echo "  - $name"
        fi
      fi
    done
    echo ""
    read -p "Enter profile name: " PROFILE_NAME
  fi

  # For config, also need tool name
  if [[ "$DELETE_TYPE" == "config" ]]; then
    echo ""
    echo "Which tool config to delete?"
    echo "  1. tasks (TaskWarrior)"
    echo "  2. time (TimeWarrior)"
    echo "  3. journal (JRNL)"
    echo "  4. ledger (Hledger)"
    echo ""
    read -p "Enter choice: " tool_choice
    case "$tool_choice" in
      1|tasks) PROFILE_NAME="tasks" ;;
      2|time) PROFILE_NAME="time" ;;
      3|journal) PROFILE_NAME="journal" ;;
      4|ledger) PROFILE_NAME="ledger" ;;
      *) log_error "Invalid choice"; exit 1 ;;
    esac
  fi

  echo ""
  run_delete
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

run_delete() {
  case "$DELETE_TYPE" in
    profile)
      resolve_profile
      do_delete_profile "$PROFILE_NAME"
      ;;
    tasks)
      resolve_profile
      do_delete_tasks "$PROFILE_NAME"
      ;;
    time)
      resolve_profile
      do_delete_time "$PROFILE_NAME"
      ;;
    journal)
      resolve_profile
      do_delete_journal "$PROFILE_NAME"
      ;;
    ledger)
      resolve_profile
      do_delete_ledger "$PROFILE_NAME"
      ;;
    config)
      do_delete_config "$PROFILE_NAME"
      ;;
    aliases)
      if [[ -z "$PROFILE_NAME" ]]; then
        log_error "Profile name required for aliases deletion"
        exit 1
      fi
      do_delete_aliases "$PROFILE_NAME"
      ;;
    exports)
      do_delete_exports
      ;;
    *)
      log_error "Unknown delete type: $DELETE_TYPE"
      exit 1
      ;;
  esac
}

show_help() {
  cat << 'EOF'
X Service - Delete profiles and data safely

Usage: x [type] [name] [options]
       ww x [type] [name] [options]

Types:
  profile <name>      Delete entire profile
  tasks               Clear TaskWarrior data
  time                Clear TimeWarrior data
  journal             Clear journal entries
  ledger              Clear ledger data
  config <tool>       Remove tool config (tasks, time, journal, ledger)
  aliases <name>      Remove shell aliases for profile
  exports             Purge export files

Options:
  -p, --profile <name>  Target profile (default: active profile)
  -n, --dry-run         Preview what will be deleted
  -f, --force           Skip confirmation (still creates backup)
  --no-backup           Skip backup (requires --force)
  -h, --help            Show this help

Safety:
  - Cannot delete active profile (deactivate first)
  - Creates backup before deletion (unless --no-backup)
  - Requires typing 'yes' to confirm (unless --force)

Examples:
  x                              Interactive mode
  x profile work                 Delete 'work' profile
  x profile work --dry-run       Preview deletion
  x tasks --profile work         Clear tasks in 'work'
  x journal                      Clear journals in active profile
  x config tasks                 Remove TaskWarrior config
  x aliases work                 Remove shell aliases
  x exports                      Purge exports for active profile

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  parse_arguments "$@"

  if [[ -z "$DELETE_TYPE" ]]; then
    interactive_delete
  else
    run_delete
  fi
}

main "$@"
