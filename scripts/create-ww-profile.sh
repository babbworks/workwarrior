#!/usr/bin/env bash
# Profile Creation Script
# Main entry point for creating new Workwarrior profiles
# Usage: create-ww-profile.sh <profile-name> [options]

set -e

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Source required libraries
source "$LIB_DIR/core-utils.sh"
source "$LIB_DIR/profile-manager.sh"
source "$LIB_DIR/shell-integration.sh"

# ============================================================================
# USAGE AND HELP
# ============================================================================

show_usage() {
  cat << EOF
Usage: create-ww-profile.sh <profile-name> [options]

Create a new Workwarrior profile with TaskWarrior, TimeWarrior, JRNL, and Hledger integration.

Arguments:
  profile-name          Name of the profile to create (required)
                        Must contain only letters, numbers, hyphens, and underscores
                        Maximum 50 characters

Options:
  --taskrc-from PROFILE     Copy TaskRC configuration from existing profile
  --journal-from PROFILE    Copy journal configuration from existing profile
  --ledger-from PROFILE     Copy ledger configuration from existing profile
  --non-interactive         Skip all prompts, use defaults
  -h, --help                Show this help message

Examples:
  # Create a basic profile with defaults
  create-ww-profile.sh work

  # Create a profile copying configuration from another profile
  create-ww-profile.sh personal --taskrc-from work --journal-from work

  # Create a profile non-interactively
  create-ww-profile.sh project-x --non-interactive

EOF
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_arguments() {
  PROFILE_NAME=""
  TASKRC_SOURCE=""
  JOURNAL_SOURCE=""
  LEDGER_SOURCE=""
  NON_INTERACTIVE=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_usage
        exit 0
        ;;
      --taskrc-from)
        TASKRC_SOURCE="$2"
        shift 2
        ;;
      --journal-from)
        JOURNAL_SOURCE="$2"
        shift 2
        ;;
      --ledger-from)
        LEDGER_SOURCE="$2"
        shift 2
        ;;
      --non-interactive)
        NON_INTERACTIVE=1
        shift
        ;;
      -*)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
      *)
        if [[ -z "$PROFILE_NAME" ]]; then
          PROFILE_NAME="$1"
        else
          log_error "Multiple profile names specified: $PROFILE_NAME and $1"
          show_usage
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate profile name was provided
  if [[ -z "$PROFILE_NAME" ]]; then
    log_error "Profile name is required"
    show_usage
    exit 1
  fi
}

# ============================================================================
# INTERACTIVE PROMPTS
# ============================================================================

prompt_for_customization() {
  if [[ $NON_INTERACTIVE -eq 1 ]]; then
    log_info "Non-interactive mode: using default configurations"
    return 0
  fi

  echo ""
  log_info "Profile customization options"
  echo ""

  # Prompt for TaskRC source if not specified
  if [[ -z "$TASKRC_SOURCE" ]]; then
    echo "Would you like to copy TaskRC configuration from an existing profile?"
    echo "Available profiles:"
    list_profiles | sed 's/^/  /'
    echo ""
    read -p "Enter profile name (or press Enter to use default): " taskrc_input
    if [[ -n "$taskrc_input" ]]; then
      TASKRC_SOURCE="$taskrc_input"
    fi
  fi

  # Prompt for journal source if not specified
  if [[ -z "$JOURNAL_SOURCE" ]]; then
    echo ""
    echo "Would you like to copy journal configuration from an existing profile?"
    echo "Available profiles:"
    list_profiles | sed 's/^/  /'
    echo ""
    read -p "Enter profile name (or press Enter to use default): " journal_input
    if [[ -n "$journal_input" ]]; then
      JOURNAL_SOURCE="$journal_input"
    fi
  fi

  # Prompt for ledger source if not specified
  if [[ -z "$LEDGER_SOURCE" ]]; then
    echo ""
    echo "Would you like to copy ledger configuration from an existing profile?"
    echo "Available profiles:"
    list_profiles | sed 's/^/  /'
    echo ""
    read -p "Enter profile name (or press Enter to use default): " ledger_input
    if [[ -n "$ledger_input" ]]; then
      LEDGER_SOURCE="$ledger_input"
    fi
  fi

  echo ""
}

# ============================================================================
# PROFILE CREATION WORKFLOW
# ============================================================================

create_profile() {
  local profile_name="$1"
  local profile_base="$PROFILES_DIR/$profile_name"

  echo ""
  log_info "Creating profile: $profile_name"
  echo ""

  # Step 1: Validate profile name
  if ! validate_profile_name "$profile_name"; then
    log_error "Invalid profile name: $profile_name"
    return 1
  fi

  # Step 2: Check if profile already exists
  if profile_exists "$profile_name"; then
    log_warning "Profile '$profile_name' already exists at: $profile_base"
    
    if [[ $NON_INTERACTIVE -eq 1 ]]; then
      log_error "Cannot overwrite existing profile in non-interactive mode"
      return 1
    fi
    
    echo ""
    read -p "Do you want to overwrite it? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
      log_info "Profile creation cancelled"
      return 1
    fi
    
    log_warning "Removing existing profile..."
    rm -rf "$profile_base"
  fi

  # Step 3: Create directory structure
  if ! create_profile_directories "$profile_name"; then
    log_error "Failed to create profile directory structure"
    return 1
  fi

  # Step 4: Create or copy TaskRC configuration
  if [[ -n "$TASKRC_SOURCE" ]]; then
    log_step "Copying TaskRC from profile: $TASKRC_SOURCE"
    if ! copy_taskrc_from_profile "$TASKRC_SOURCE" "$profile_name"; then
      log_error "Failed to copy TaskRC from $TASKRC_SOURCE"
      return 1
    fi
  else
    log_step "Creating default TaskRC configuration"
    if ! create_taskrc "$profile_name"; then
      log_error "Failed to create TaskRC"
      return 1
    fi
  fi

  # Step 5: Create or copy journal configuration
  if [[ -n "$JOURNAL_SOURCE" ]]; then
    log_step "Copying journal configuration from profile: $JOURNAL_SOURCE"
    if ! copy_journal_from_profile "$JOURNAL_SOURCE" "$profile_name"; then
      log_error "Failed to copy journal configuration from $JOURNAL_SOURCE"
      return 1
    fi
  else
    log_step "Creating default journal configuration"
    if ! create_journal_config "$profile_name"; then
      log_error "Failed to create journal configuration"
      return 1
    fi
  fi

  # Step 6: Create or copy ledger configuration
  if [[ -n "$LEDGER_SOURCE" ]]; then
    log_step "Copying ledger configuration from profile: $LEDGER_SOURCE"
    if ! copy_ledger_from_profile "$LEDGER_SOURCE" "$profile_name"; then
      log_error "Failed to copy ledger configuration from $LEDGER_SOURCE"
      return 1
    fi
  else
    log_step "Creating default ledger configuration"
    if ! create_ledger_config "$profile_name"; then
      log_error "Failed to create ledger configuration"
      return 1
    fi
  fi

  # Step 7: Install TimeWarrior hook
  log_step "Installing TimeWarrior hook"
  if ! install_timewarrior_hook "$profile_name"; then
    log_error "Failed to install TimeWarrior hook"
    return 1
  fi

  # Step 8: Create shell aliases
  log_step "Creating shell aliases"
  if ! create_profile_aliases "$profile_name"; then
    log_error "Failed to create shell aliases"
    return 1
  fi

  # Step 9: Ensure global shell functions are defined
  log_step "Ensuring global shell functions"
  if ! ensure_shell_functions; then
    log_warning "Failed to ensure shell functions (non-fatal)"
  fi

  return 0
}

# ============================================================================
# SUCCESS MESSAGE
# ============================================================================

show_success_message() {
  local profile_name="$1"
  local profile_base="$PROFILES_DIR/$profile_name"

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  log_success "Profile '$profile_name' created successfully!"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  echo "Profile location: $profile_base"
  echo ""
  echo "Next steps:"
  echo ""
  echo "  1. Reload your shell configuration:"
  echo "     source ~/.bashrc"
  echo ""
  echo "  2. Activate the profile:"
  echo "     p-$profile_name"
  echo "     or"
  echo "     $profile_name"
  echo ""
  echo "  3. Start using the tools:"
  echo "     task add \"My first task\""
  echo "     j \"My first journal entry\""
  echo "     l balance"
  echo ""
  echo "Available commands:"
  echo "  • p-$profile_name          - Activate this profile"
  echo "  • $profile_name            - Shorthand activation"
  echo "  • j-$profile_name          - Direct journal access"
  echo "  • l-$profile_name          - Direct ledger access"
  echo ""
  echo "Global commands (when profile is active):"
  echo "  • j [journal] <entry>  - Write to journal"
  echo "  • l [args]             - Access default ledger"
  echo "  • task                 - TaskWarrior"
  echo "  • timew                - TimeWarrior"
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
  # Parse command-line arguments
  parse_arguments "$@"

  # Validate source profiles if specified
  if [[ -n "$TASKRC_SOURCE" ]] && ! profile_exists "$TASKRC_SOURCE"; then
    log_error "TaskRC source profile does not exist: $TASKRC_SOURCE"
    exit 1
  fi

  if [[ -n "$JOURNAL_SOURCE" ]] && ! profile_exists "$JOURNAL_SOURCE"; then
    log_error "Journal source profile does not exist: $JOURNAL_SOURCE"
    exit 1
  fi

  if [[ -n "$LEDGER_SOURCE" ]] && ! profile_exists "$LEDGER_SOURCE"; then
    log_error "Ledger source profile does not exist: $LEDGER_SOURCE"
    exit 1
  fi

  # Prompt for customization options if interactive
  prompt_for_customization

  # Create the profile
  if ! create_profile "$PROFILE_NAME"; then
    log_error "Profile creation failed"
    exit 1
  fi

  # Show success message with usage instructions
  show_success_message "$PROFILE_NAME"

  exit 0
}

# Run main function
main "$@"
