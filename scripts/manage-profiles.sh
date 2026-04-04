#!/usr/bin/env bash
# Profile Management Script
# Provides commands for managing Workwarrior profiles
# Usage: manage-profiles.sh <command> [arguments]

set -e

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Source required libraries
source "$LIB_DIR/core-utils.sh"
source "$LIB_DIR/config-utils.sh"
source "$LIB_DIR/profile-manager.sh"
source "$LIB_DIR/shell-integration.sh"

# ============================================================================
# USAGE AND HELP
# ============================================================================

show_usage() {
  cat << EOF
Usage: manage-profiles.sh <command> [arguments]

Manage Workwarrior profiles - list, delete, backup, import, and restore profiles.

Commands:
  list                           List all existing profiles (sorted)
  delete <profile-name>          Delete a profile and all its data
  info <profile-name>            Display profile information (location, disk usage, counts)
  backup <profile-name> [dest]   Create a backup archive of a profile
  import <archive> [new-name]    Create a new profile from a backup archive
  restore <profile> <archive>    Replace an existing profile from a backup archive
  help                           Show this help message

Examples:
  manage-profiles.sh list
  manage-profiles.sh delete old-project
  manage-profiles.sh info work
  manage-profiles.sh backup work
  manage-profiles.sh backup work /path/to/backups
  manage-profiles.sh import work-backup-20260101.tar.gz
  manage-profiles.sh import work-backup-20260101.tar.gz work-restored
  manage-profiles.sh restore work work-backup-20260101.tar.gz

EOF
}

# ============================================================================
# LIST PROFILES COMMAND
# ============================================================================

cmd_list() {
  log_info "Existing profiles:"
  echo ""
  
  if [[ ! -d "$PROFILES_DIR" ]]; then
    log_warning "Profiles directory not found at $PROFILES_DIR"
    return 0
  fi
  
  local profiles=()
  while IFS= read -r -d '' dir; do
    profiles+=( "$(basename "$dir")" )
  done < <(command find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -print0)
  
  if (( ${#profiles[@]} == 0 )); then
    log_info "No profiles found"
    echo ""
    log_info "Create a profile with: create-ww-profile.sh <profile-name>"
    return 0
  fi
  
  # Sort and display profiles
  local sorted_profiles
  mapfile -t sorted_profiles < <(printf '%s\n' "${profiles[@]}" | sort)
  
  for profile in "${sorted_profiles[@]}"; do
    echo "  • $profile"
  done
  
  echo ""
  log_info "Total: ${#profiles[@]} profile(s)"
  echo ""
  log_info "Activate a profile with: p-<profile-name>"
  
  return 0
}

# ============================================================================
# DELETE PROFILE COMMAND
# ============================================================================

cmd_delete() {
  local profile_name="$1"
  
  # Validate profile name
  if [[ -z "$profile_name" ]]; then
    log_error "Profile name is required"
    echo "Usage: manage-profiles.sh delete <profile-name>"
    return 1
  fi
  
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi
  
  # Check if profile exists
  if ! profile_exists "$profile_name"; then
    log_error "Profile '$profile_name' does not exist"
    log_info "Available profiles:"
    list_profiles | sed 's/^/  /'
    return 1
  fi
  
  local profile_base="$PROFILES_DIR/$profile_name"
  
  # Confirm deletion
  echo ""
  log_warning "This will permanently delete the profile '$profile_name' and all its data!"
  log_info "Profile location: $profile_base"
  echo ""
  read -p "Are you sure you want to delete this profile? (yes/no): " confirm
  
  if [[ "$confirm" != "yes" ]]; then
    log_info "Deletion cancelled"
    return 0
  fi
  
  echo ""
  log_step "Deleting profile '$profile_name'"
  
  # Remove profile directory and all contents
  if ! rm -rf "$profile_base"; then
    log_error "Failed to remove profile directory: $profile_base"
    return 1
  fi
  
  log_success "Profile directory removed"
  
  # Remove aliases from ~/.bashrc
  log_step "Removing shell aliases"
  if ! remove_profile_aliases "$profile_name"; then
    log_warning "Failed to remove some aliases (non-fatal)"
  fi
  
  echo ""
  log_success "Profile '$profile_name' deleted successfully"
  log_info "Reload your shell or run: source ~/.bashrc"
  echo ""
  
  return 0
}

# ============================================================================
# INFO PROFILE COMMAND
# ============================================================================

cmd_info() {
  local profile_name="$1"
  
  # Validate profile name
  if [[ -z "$profile_name" ]]; then
    log_error "Profile name is required"
    echo "Usage: manage-profiles.sh info <profile-name>"
    return 1
  fi
  
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi
  
  # Check if profile exists
  if ! profile_exists "$profile_name"; then
    log_error "Profile '$profile_name' does not exist"
    log_info "Available profiles:"
    list_profiles | sed 's/^/  /'
    return 1
  fi
  
  local profile_base="$PROFILES_DIR/$profile_name"
  
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  log_info "Profile Information: $profile_name"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  # Basic information
  echo "Location:"
  echo "  $profile_base"
  echo ""
  
  # Disk usage
  echo "Disk Usage:"
  if command -v du &> /dev/null; then
    local disk_usage
    disk_usage=$(du -sh "$profile_base" 2>/dev/null | awk '{print $1}')
    echo "  $disk_usage"
  else
    echo "  (du command not available)"
  fi
  echo ""
  
  # Task count
  echo "Tasks:"
  local task_count=0
  if [[ -f "$profile_base/.task/taskchampion.sqlite3" ]]; then
    # Try to count tasks using task command if available
    if command -v task &> /dev/null; then
      task_count=$(TASKRC="$profile_base/.taskrc" TASKDATA="$profile_base/.task" task count 2>/dev/null || echo "0")
    fi
    echo "  $task_count task(s)"
  else
    echo "  No task database found"
  fi
  echo ""
  
  # Journal count
  echo "Journals:"
  local journal_count=0
  if [[ -d "$profile_base/journals" ]]; then
    journal_count=$(command find "$profile_base/journals" -name "*.txt" -type f 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  $journal_count journal file(s)"
  
  if [[ -f "$profile_base/jrnl.yaml" ]]; then
    echo "  Configured journals:"
    grep "^  [a-zA-Z]" "$profile_base/jrnl.yaml" | sed 's/^/    /'
  fi
  echo ""
  
  # Ledger count
  echo "Ledgers:"
  local ledger_count=0
  if [[ -d "$profile_base/ledgers" ]]; then
    ledger_count=$(command find "$profile_base/ledgers" -name "*.journal" -type f 2>/dev/null | wc -l | tr -d ' ')
  fi
  echo "  $ledger_count ledger file(s)"
  
  if [[ -f "$profile_base/ledgers.yaml" ]]; then
    echo "  Configured ledgers:"
    grep "^  [a-zA-Z]" "$profile_base/ledgers.yaml" | sed 's/^/    /'
  fi
  echo ""
  
  # TimeWarrior hook
  echo "TimeWarrior Integration:"
  if [[ -f "$profile_base/.task/hooks/on-modify.timewarrior" ]]; then
    if [[ -x "$profile_base/.task/hooks/on-modify.timewarrior" ]]; then
      echo "  ✓ Hook installed and executable"
    else
      echo "  ⚠ Hook installed but not executable"
    fi
  else
    echo "  ✗ Hook not installed"
  fi
  echo ""
  
  # Configuration files
  echo "Configuration Files:"
  [[ -f "$profile_base/.taskrc" ]] && echo "  ✓ .taskrc" || echo "  ✗ .taskrc"
  [[ -f "$profile_base/jrnl.yaml" ]] && echo "  ✓ jrnl.yaml" || echo "  ✗ jrnl.yaml"
  [[ -f "$profile_base/ledgers.yaml" ]] && echo "  ✓ ledgers.yaml" || echo "  ✗ ledgers.yaml"
  echo ""
  
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  return 0
}

# ============================================================================
# BACKUP PROFILE COMMAND
# ============================================================================

cmd_backup() {
  local profile_name="$1"
  local dest_dir="${2:-}"
  if [[ -z "$dest_dir" ]]; then
    dest_dir="$HOME"
  fi
  
  # Validate profile name
  if [[ -z "$profile_name" ]]; then
    log_error "Profile name is required"
    echo "Usage: manage-profiles.sh backup <profile-name> [destination]"
    return 1
  fi
  
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi
  
  # Check if profile exists
  if ! profile_exists "$profile_name"; then
    log_error "Profile '$profile_name' does not exist"
    log_info "Available profiles:"
    list_profiles | sed 's/^/  /'
    return 1
  fi
  
  local profile_base="$PROFILES_DIR/$profile_name"
  
  # Validate destination directory
  if [[ ! -d "$dest_dir" ]]; then
    log_error "Destination directory does not exist: $dest_dir"
    return 1
  fi
  
  if [[ ! -w "$dest_dir" ]]; then
    log_error "Destination directory is not writable: $dest_dir"
    return 1
  fi
  
  # Generate backup filename with timestamp
  local timestamp
  timestamp=$(date "+%Y%m%d%H%M%S")
  local backup_filename="${profile_name}-backup-${timestamp}.tar.gz"
  local backup_path="$dest_dir/$backup_filename"
  
  echo ""
  log_step "Creating backup of profile '$profile_name'"
  log_info "Source: $profile_base"
  log_info "Destination: $backup_path"
  echo ""
  
  # Create tar.gz archive
  # Use -C to change to parent directory and archive just the profile directory
  local profiles_parent
  profiles_parent=$(dirname "$PROFILES_DIR")
  local profiles_basename
  profiles_basename=$(basename "$PROFILES_DIR")
  
  if ! tar -czf "$backup_path" -C "$profiles_parent" "$profiles_basename/$profile_name" 2>/dev/null; then
    log_error "Failed to create backup archive"
    return 1
  fi
  
  # Verify backup was created
  if [[ ! -f "$backup_path" ]]; then
    log_error "Backup file was not created: $backup_path"
    return 1
  fi
  
  # Get backup file size
  local backup_size
  if command -v du &> /dev/null; then
    backup_size=$(du -sh "$backup_path" 2>/dev/null | awk '{print $1}')
  else
    backup_size=$(ls -lh "$backup_path" 2>/dev/null | awk '{print $5}')
  fi
  
  echo ""
  log_success "Backup created successfully"
  echo ""
  echo "Backup file: $backup_path"
  echo "Size: $backup_size"
  echo ""
  log_info "To restore this backup on another system:"
  echo "  1. Extract: tar -xzf $backup_filename"
  echo "  2. Move to: ~/ww/profiles/"
  echo "  3. Update paths in configuration files if needed"
  echo ""
  
  return 0
}

# ============================================================================
# IMPORT PROFILE COMMAND
# ============================================================================

cmd_import() {
  local archive="$1"
  local new_name="${2:-}"

  if [[ -z "$archive" ]]; then
    log_error "Archive path is required"
    echo "Usage: manage-profiles.sh import <archive> [new-name]"
    return 1
  fi

  import_profile "$archive" "$new_name"
  return $?
}

# ============================================================================
# RESTORE PROFILE COMMAND
# ============================================================================

cmd_restore() {
  local profile_name="$1"
  local archive="$2"

  if [[ -z "$profile_name" ]]; then
    log_error "Profile name is required"
    echo "Usage: manage-profiles.sh restore <profile-name> <archive>"
    return 1
  fi

  if [[ -z "$archive" ]]; then
    log_error "Archive path is required"
    echo "Usage: manage-profiles.sh restore <profile-name> <archive>"
    return 1
  fi

  restore_profile "$profile_name" "$archive"
  return $?
}

# ============================================================================
# COMMAND DISPATCHER
# ============================================================================

main() {
  local command="${1:-}"
  
  # Check if command is provided
  if [[ -z "$command" ]]; then
    log_error "Command is required"
    echo ""
    show_usage
    exit 1
  fi
  
  # Dispatch to appropriate command
  case "$command" in
    list)
      cmd_list
      exit $?
      ;;
    delete)
      shift
      cmd_delete "$@"
      exit $?
      ;;
    info)
      shift
      cmd_info "$@"
      exit $?
      ;;
    backup)
      shift
      cmd_backup "$@"
      exit $?
      ;;
    import)
      shift
      cmd_import "$@"
      exit $?
      ;;
    restore)
      shift
      cmd_restore "$@"
      exit $?
      ;;
    help|--help|-h)
      show_usage
      exit 0
      ;;
    *)
      log_error "Unknown command: $command"
      echo ""
      show_usage
      exit 1
      ;;
  esac
}

# Run main function
main "$@"
