#!/usr/bin/env bash
# Workwarrior Uninstallation Script
# Cleanly removes workwarrior CLI tool
#
# Usage:
#   ./uninstall.sh              Remove workwarrior (preserve profiles)
#   ./uninstall.sh --force      Skip confirmation prompts
#   ./uninstall.sh --purge      Remove everything including profiles

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

WW_INSTALL_DIR="$HOME/ww"

# Section markers (must match installer-utils.sh)
SECTION_WW_INSTALL="# --- Workwarrior Installation ---"
SECTION_WW_INSTALL_END="# --- End Workwarrior Installation ---"

# ============================================================================
# LOGGING (standalone - doesn't require libraries)
# ============================================================================

log_info() { echo "info $*"; }
log_success() { echo "ok $*"; }
log_warning() { echo "warn $*"; }
log_error() { echo "err $*" >&2; }
log_step() { echo ">> $*"; }

# Try to source installer utils for better functions
if [[ -f "$WW_INSTALL_DIR/lib/installer-utils.sh" ]]; then
  source "$WW_INSTALL_DIR/lib/installer-utils.sh" 2>/dev/null || true
fi

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

FORCE_UNINSTALL=0
REMOVE_DATA=0

show_uninstall_usage() {
  cat << EOF
Workwarrior Uninstallation

Usage: ./uninstall.sh [options]

Options:
  --force, -f              Skip confirmation prompts
  --purge, --remove-data   Remove everything including profiles and data
  --help, -h               Show this help message

By default, profiles in ~/ww/profiles are preserved.
Use --purge to completely remove all workwarrior data.

Examples:
  ./uninstall.sh           Remove workwarrior, keep profiles
  ./uninstall.sh --purge   Remove everything
  ./uninstall.sh -f        Force remove without prompts

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|-f)
      FORCE_UNINSTALL=1
      shift
      ;;
    --purge|--remove-data)
      REMOVE_DATA=1
      shift
      ;;
    --help|-h)
      show_uninstall_usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_uninstall_usage
      exit 1
      ;;
  esac
done

# ============================================================================
# UNINSTALLATION FUNCTIONS
# ============================================================================

confirm_uninstall() {
  if (( FORCE_UNINSTALL == 1 )); then
    return 0
  fi

  echo ""
  log_warning "This will remove workwarrior from your system"
  echo ""

  if (( REMOVE_DATA == 1 )); then
    log_warning "WARNING: --purge flag set"
    log_warning "This will DELETE all profiles and data!"
    echo ""
  else
    log_info "Profiles in ~/ww/profiles will be preserved"
    echo ""
  fi

  read -p "Continue with uninstallation? (yes/no): " confirm

  if [[ "$confirm" != "yes" ]]; then
    log_info "Uninstallation cancelled"
    exit 0
  fi
}

remove_shell_config() {
  log_step "Removing shell configuration..."

  local rc_files=("$HOME/.bashrc" "$HOME/.zshrc")

  for rc_file in "${rc_files[@]}"; do
    if [[ ! -f "$rc_file" ]]; then
      continue
    fi

    # Check if workwarrior config exists
    if ! grep -Fq "$SECTION_WW_INSTALL" "$rc_file"; then
      log_info "No workwarrior config in $(basename "$rc_file")"
      continue
    fi

    # Create backup
    local backup_file="$rc_file.ww-uninstall-backup.$(date +%Y%m%d%H%M%S)"
    cp "$rc_file" "$backup_file"

    # Remove workwarrior section using awk
    awk -v start="$SECTION_WW_INSTALL" -v end="$SECTION_WW_INSTALL_END" '
      $0 == start { skip = 1; next }
      $0 == end { skip = 0; next }
      !skip { print }
    ' "$rc_file" > "$rc_file.tmp"

    mv "$rc_file.tmp" "$rc_file"

    log_success "Removed workwarrior from $(basename "$rc_file")"
    log_info "Backup: $backup_file"
  done
}

remove_installation() {
  log_step "Removing installation files..."

  if [[ ! -d "$WW_INSTALL_DIR" ]]; then
    log_warning "Installation directory not found: $WW_INSTALL_DIR"
    return 0
  fi

  if (( REMOVE_DATA == 1 )); then
    # Remove everything
    rm -rf "$WW_INSTALL_DIR"
    log_success "Removed $WW_INSTALL_DIR (including all data)"
  else
    # Preserve profiles directory
    local profiles_dir="$WW_INSTALL_DIR/profiles"
    local has_profiles=0

    if [[ -d "$profiles_dir" ]] && [[ -n "$(ls -A "$profiles_dir" 2>/dev/null)" ]]; then
      has_profiles=1
    fi

    if (( has_profiles == 1 )); then
      # Move profiles to temp location
      local temp_profiles="/tmp/ww-profiles-backup-$$"
      mv "$profiles_dir" "$temp_profiles"

      # Remove installation
      rm -rf "$WW_INSTALL_DIR"

      # Recreate and restore profiles
      mkdir -p "$WW_INSTALL_DIR"
      mv "$temp_profiles" "$profiles_dir"

      log_success "Removed workwarrior installation"
      log_info "Profiles preserved in: $profiles_dir"
    else
      # No profiles, remove everything
      rm -rf "$WW_INSTALL_DIR"
      log_success "Removed $WW_INSTALL_DIR"
    fi
  fi
}

show_success_message() {
  echo ""
  echo "============================================================"
  log_success "Workwarrior has been uninstalled"
  echo "============================================================"
  echo ""
  echo "Please reload your shell configuration:"
  echo "  source ~/.bashrc"
  if [[ -f "$HOME/.zshrc" ]]; then
    echo "  (or: source ~/.zshrc)"
  fi
  echo ""

  if (( REMOVE_DATA == 0 )) && [[ -d "$WW_INSTALL_DIR/profiles" ]]; then
    echo "Your profiles are still available at:"
    echo "  $WW_INSTALL_DIR/profiles"
    echo ""
    echo "To reinstall workwarrior later, your profiles will be preserved."
    echo ""
  fi
}

# ============================================================================
# MAIN UNINSTALLATION WORKFLOW
# ============================================================================

main() {
  echo ""
  echo "Workwarrior Uninstaller"
  echo ""

  # Check if installed
  if [[ ! -d "$WW_INSTALL_DIR" ]]; then
    log_info "Workwarrior does not appear to be installed"
    log_info "Directory not found: $WW_INSTALL_DIR"
    exit 0
  fi

  # Confirm uninstallation
  confirm_uninstall

  # Remove shell configuration
  remove_shell_config

  # Remove installation files
  remove_installation

  # Show success message
  show_success_message
}

main "$@"
