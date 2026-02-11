#!/usr/bin/env bash
# Shell Integration Library
# Functions for managing shell aliases, functions, and environment
# Source this file: source "$(dirname "$0")/../lib/shell-integration.sh"

# Source core utilities if not already loaded
if [[ -z "$CORE_UTILS_LOADED" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$SCRIPT_DIR/core-utils.sh"
fi

# ============================================================================
# SHELL CONFIGURATION CONSTANTS
# ============================================================================

# Section markers for ~/.bashrc organization
readonly SECTION_PROFILE_ALIASES="# -- Workwarrior Profile Aliases ---"
readonly SECTION_JOURNAL_ALIASES="# -- Direct Alias for Journals ---"
readonly SECTION_LEDGER_ALIASES="# -- Direct Aliases for Hledger ---"
readonly SECTION_CORE_FUNCTIONS="# --- Workwarrior Core Functions ---"

# Default shell configuration file
readonly SHELL_CONFIG="${HOME}/.bashrc"

# ============================================================================
# ALIAS MANAGEMENT FUNCTIONS
# ============================================================================

# Add an alias to a specific section in ~/.bashrc
# Checks if alias already exists (prevents duplicates)
# Ensures section marker exists in ~/.bashrc
# Adds alias after section marker using awk for precise insertion
#
# Usage: add_alias_to_section "alias_line" "section_marker"
# Example: add_alias_to_section "alias p-work='use_task_profile work'" "$SECTION_PROFILE_ALIASES"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 4.5, 4.6, 17.1, 17.2, 17.3, 17.4, 17.5, 17.6, 17.7, 17.8, 17.9, 17.10
add_alias_to_section() {
  local alias_line="$1"
  local section_marker="$2"

  # Validate inputs
  if [[ -z "$alias_line" ]]; then
    log_error "Alias line cannot be empty"
    return 1
  fi

  if [[ -z "$section_marker" ]]; then
    log_error "Section marker cannot be empty"
    return 1
  fi

  # Ensure shell config file exists
  if [[ ! -f "$SHELL_CONFIG" ]]; then
    log_info "Creating $SHELL_CONFIG"
    touch "$SHELL_CONFIG"
  fi

  # Check if alias already exists (idempotence)
  if grep -Fxq "$alias_line" "$SHELL_CONFIG"; then
    log_info "Alias already exists in $SHELL_CONFIG, skipping"
    return 0
  fi

  # Ensure section marker exists
  if ! grep -Fxq "$section_marker" "$SHELL_CONFIG"; then
    log_info "Section marker not found, adding: $section_marker"
    echo "" >> "$SHELL_CONFIG"
    echo "$section_marker" >> "$SHELL_CONFIG"
  fi

  # Add alias after section marker using awk
  # This inserts the alias line immediately after the section marker
  awk -v marker="$section_marker" -v alias="$alias_line" '
    {
      print
      if ($0 == marker) {
        print alias
      }
    }
  ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"

  # Replace original with updated version
  if ! mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"; then
    log_error "Failed to update $SHELL_CONFIG"
    rm -f "$SHELL_CONFIG.tmp"
    return 1
  fi

  log_success "Added alias to $SHELL_CONFIG"
  return 0
}

# Create all shell aliases for a profile
# Creates p-<profile-name> alias for profile activation
# Creates <profile-name> alias as shorthand
# Creates j-<profile-name> alias for journal access
# Creates l-<ledger-name> aliases for each ledger
#
# Usage: create_profile_aliases "profile-name"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 4.1, 4.2, 4.3, 4.4, 8.9, 9.6, 9.7
create_profile_aliases() {
  local profile_name="$1"

  # Validate profile name
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi

  local profile_base="$PROFILES_DIR/$profile_name"
  local jrnl_config="$profile_base/jrnl.yaml"
  local ledger_config="$profile_base/ledgers.yaml"

  log_step "Creating shell aliases for profile '$profile_name'"

  # Check if profile exists
  if [[ ! -d "$profile_base" ]]; then
    log_error "Profile directory does not exist: $profile_base"
    return 1
  fi

  # Create p-<profile-name> alias for profile activation
  local p_alias="alias p-${profile_name}='use_task_profile ${profile_name}'"
  if ! add_alias_to_section "$p_alias" "$SECTION_PROFILE_ALIASES"; then
    log_error "Failed to add p-${profile_name} alias"
    return 1
  fi
  log_info "Added alias: p-${profile_name}"

  # Create <profile-name> alias as shorthand
  local shorthand_alias="alias ${profile_name}='use_task_profile ${profile_name}'"
  if ! add_alias_to_section "$shorthand_alias" "$SECTION_PROFILE_ALIASES"; then
    log_error "Failed to add ${profile_name} alias"
    return 1
  fi
  log_info "Added alias: ${profile_name}"

  # Create j-<profile-name> alias for journal access
  if [[ -f "$jrnl_config" ]]; then
    local j_alias="alias j-${profile_name}='jrnl --config-file ${jrnl_config}'"
    if ! add_alias_to_section "$j_alias" "$SECTION_JOURNAL_ALIASES"; then
      log_error "Failed to add j-${profile_name} alias"
      return 1
    fi
    log_info "Added alias: j-${profile_name}"
  else
    log_warning "jrnl.yaml not found, skipping journal alias"
  fi

  # Create l-<ledger-name> aliases for each ledger
  if [[ -f "$ledger_config" ]]; then
    # Parse ledgers.yaml to get ledger names and paths
    # Format: "  ledger-name: /path/to/ledger.journal"
    while IFS=: read -r ledger_name ledger_path; do
      # Skip the "ledgers:" line and empty lines
      if [[ "$ledger_name" =~ ^[[:space:]]*ledgers[[:space:]]*$ ]] || [[ -z "$ledger_name" ]]; then
        continue
      fi
      
      # Trim whitespace from ledger name
      ledger_name=$(echo "$ledger_name" | xargs)
      ledger_path=$(echo "$ledger_path" | xargs)
      
      # Skip if ledger_path is empty
      if [[ -z "$ledger_path" ]]; then
        continue
      fi
      
      # Create alias for this ledger
      # If ledger name is "default", use profile name
      if [[ "$ledger_name" == "default" ]]; then
        local l_alias="alias l-${profile_name}='hledger -f ${ledger_path}'"
        if ! add_alias_to_section "$l_alias" "$SECTION_LEDGER_ALIASES"; then
          log_warning "Failed to add l-${profile_name} alias"
        else
          log_info "Added alias: l-${profile_name}"
        fi
      else
        # For named ledgers, use l-<profile-name>-<ledger-name>
        local l_alias="alias l-${profile_name}-${ledger_name}='hledger -f ${ledger_path}'"
        if ! add_alias_to_section "$l_alias" "$SECTION_LEDGER_ALIASES"; then
          log_warning "Failed to add l-${profile_name}-${ledger_name} alias"
        else
          log_info "Added alias: l-${profile_name}-${ledger_name}"
        fi
      fi
    done < "$ledger_config"
  else
    log_warning "ledgers.yaml not found, skipping ledger aliases"
  fi

  log_success "Shell aliases created for profile '$profile_name'"
  log_info "Reload your shell or run: source ~/.bashrc"
  
  return 0
}

# Remove all shell aliases associated with a profile
# Removes profile activation aliases (p-<profile-name>, <profile-name>)
# Removes journal alias (j-<profile-name>)
# Removes all ledger aliases (l-<profile-name>*, l-<ledger-name>)
# Uses sed to delete matching lines from ~/.bashrc
#
# Usage: remove_profile_aliases "profile-name"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 3.4
remove_profile_aliases() {
  local profile_name="$1"

  # Validate profile name
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi

  log_step "Removing shell aliases for profile '$profile_name'"

  # Check if shell config exists
  if [[ ! -f "$SHELL_CONFIG" ]]; then
    log_warning "$SHELL_CONFIG not found, nothing to remove"
    return 0
  fi

  # Create a backup
  if ! cp "$SHELL_CONFIG" "$SHELL_CONFIG.bak"; then
    log_error "Failed to create backup of $SHELL_CONFIG"
    return 1
  fi

  # Remove p-<profile-name> alias
  sed -i "/^alias p-${profile_name}=/d" "$SHELL_CONFIG"
  
  # Remove <profile-name> alias (shorthand)
  # Be careful to match the exact alias, not partial matches
  sed -i "/^alias ${profile_name}='use_task_profile ${profile_name}'/d" "$SHELL_CONFIG"
  
  # Remove j-<profile-name> alias
  sed -i "/^alias j-${profile_name}=/d" "$SHELL_CONFIG"
  
  # Remove all l-<profile-name>* aliases (including l-<profile-name>-<ledger-name>)
  sed -i "/^alias l-${profile_name}/d" "$SHELL_CONFIG"

  log_success "Removed aliases for profile '$profile_name'"
  log_info "Backup saved to: $SHELL_CONFIG.bak"
  log_info "Reload your shell or run: source ~/.bashrc"
  
  return 0
}

# ============================================================================
# GLOBAL SHELL FUNCTIONS
# ============================================================================

# Activate a profile and export all required environment variables
# Validates profile exists before activation
# Exports: WARRIOR_PROFILE, WORKWARRIOR_BASE, TASKRC, TASKDATA, TIMEWARRIORDB
# Displays confirmation message with usage instructions
# Handles non-existent profiles with error message
#
# Usage: use_task_profile "profile-name"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8
use_task_profile() {
  local profile_name="$1"

  # Validate profile name
  if [[ -z "$profile_name" ]]; then
    echo "Error: Profile name required" >&2
    echo "Usage: use_task_profile <profile-name>" >&2
    return 1
  fi

  local profile_base="$PROFILES_DIR/$profile_name"

  # Check if profile exists
  if [[ ! -d "$profile_base" ]]; then
    echo "Error: Profile '$profile_name' does not exist" >&2
    echo "Profile directory not found: $profile_base" >&2
    echo "" >&2
    echo "Available profiles:" >&2
    if command -v list_profiles &> /dev/null; then
      list_profiles | sed 's/^/  /' >&2
    else
      ls -1 "$PROFILES_DIR" 2>/dev/null | sed 's/^/  /' >&2
    fi
    return 1
  fi

  # Export environment variables
  export WARRIOR_PROFILE="$profile_name"
  export WORKWARRIOR_BASE="$profile_base"
  export TASKRC="$profile_base/.taskrc"
  export TASKDATA="$profile_base/.task"
  export TIMEWARRIORDB="$profile_base/.timewarrior"

  # Display confirmation message
  echo "✓ Activated profile: $profile_name"
  echo "  Location: $profile_base"
  echo ""
  echo "Global commands now available:"
  echo "  j [journal-name] <entry>  - Write to journal"
  echo "  l [args]                  - Access default ledger"
  echo ""
  echo "Profile-specific commands:"
  echo "  task                      - TaskWarrior"
  echo "  timew                     - TimeWarrior"
  echo "  j-${profile_name}         - Direct journal access"
  echo "  l-${profile_name}         - Direct ledger access"

  return 0
}

# Global journal function - operates on active profile's journal
# Checks WORKWARRIOR_BASE is set (profile must be active)
# Parses arguments to detect journal name
# If first arg is journal name, uses named journal
# If no journal name, uses default journal
# Validates journal exists in jrnl.yaml
# Executes jrnl with --config-file flag
# Displays error if no profile active or journal not found
#
# Usage: j [journal-name] <entry>
# Examples:
#   j "Today's entry"                    - Write to default journal
#   j work-log "Completed feature X"     - Write to named journal
#   j work-log                           - View named journal
# Returns: 0 on success, 1 on failure
# Validates: Requirements 4.7, 8.10, 8.11, 8.12, 8.13, 8.14, 8.15, 8.18
j() {
  # Check if profile is active
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No profile is active" >&2
    echo "Activate a profile first with: p-<profile-name>" >&2
    return 1
  fi

  local jrnl_config="$WORKWARRIOR_BASE/jrnl.yaml"

  # Check if jrnl.yaml exists
  if [[ ! -f "$jrnl_config" ]]; then
    echo "Error: Journal configuration not found: $jrnl_config" >&2
    return 1
  fi

  # If no arguments, just run jrnl to view default journal
  if [[ $# -eq 0 ]]; then
    jrnl --config-file "$jrnl_config"
    return $?
  fi

  # Check if first argument is a journal name
  # A journal name is a single word without spaces
  local first_arg="$1"
  local is_journal_name=0

  # Check if first arg exists as a journal in jrnl.yaml
  if grep -q "^  ${first_arg}:" "$jrnl_config"; then
    is_journal_name=1
  fi

  # If first arg is a journal name, use it
  if [[ $is_journal_name -eq 1 ]]; then
    local journal_name="$first_arg"
    shift  # Remove journal name from arguments
    
    # If no more arguments, view the journal
    if [[ $# -eq 0 ]]; then
      jrnl --config-file "$jrnl_config" "$journal_name"
      return $?
    fi
    
    # Write to named journal
    jrnl --config-file "$jrnl_config" "$journal_name" "$@"
    return $?
  else
    # Write to default journal
    jrnl --config-file "$jrnl_config" "$@"
    return $?
  fi
}

# Global ledger function - operates on active profile's default ledger
# Checks WORKWARRIOR_BASE is set (profile must be active)
# Uses profile's default ledger from ledgers.yaml
# Executes hledger with -f flag pointing to default ledger
# Displays error if no profile active
#
# Usage: l [hledger-args]
# Examples:
#   l balance                - Show balance
#   l register               - Show register
#   l add                    - Add transaction
# Returns: 0 on success, 1 on failure
# Validates: Requirements 4.8, 9.8, 9.9
l() {
  # Check if profile is active
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    echo "Error: No profile is active" >&2
    echo "Activate a profile first with: p-<profile-name>" >&2
    return 1
  fi

  local ledger_config="$WORKWARRIOR_BASE/ledgers.yaml"

  # Check if ledgers.yaml exists
  if [[ ! -f "$ledger_config" ]]; then
    echo "Error: Ledger configuration not found: $ledger_config" >&2
    return 1
  fi

  # Get default ledger path from ledgers.yaml
  local default_ledger
  default_ledger=$(grep "^  default:" "$ledger_config" | awk '{print $2}')

  if [[ -z "$default_ledger" ]]; then
    echo "Error: Default ledger not found in: $ledger_config" >&2
    return 1
  fi

  # Check if ledger file exists
  if [[ ! -f "$default_ledger" ]]; then
    echo "Error: Ledger file not found: $default_ledger" >&2
    return 1
  fi

  # Execute hledger with default ledger
  hledger -f "$default_ledger" "$@"
  return $?
}

# Ensure global shell functions are defined in ~/.bashrc
# Checks if functions exist in ~/.bashrc
# Adds functions to "# --- Workwarrior Core Functions ---" section
# Prevents duplicate function definitions
#
# Usage: ensure_shell_functions
# Returns: 0 on success, 1 on failure
# Validates: Requirements 17.5
ensure_shell_functions() {
  log_step "Ensuring global shell functions are defined in ~/.bashrc"

  # Ensure shell config file exists
  if [[ ! -f "$SHELL_CONFIG" ]]; then
    log_info "Creating $SHELL_CONFIG"
    touch "$SHELL_CONFIG"
  fi

  # Ensure section marker exists
  if ! grep -Fxq "$SECTION_CORE_FUNCTIONS" "$SHELL_CONFIG"; then
    log_info "Adding core functions section marker"
    echo "" >> "$SHELL_CONFIG"
    echo "$SECTION_CORE_FUNCTIONS" >> "$SHELL_CONFIG"
  fi

  # Check if use_task_profile function exists
  if ! grep -q "^use_task_profile()" "$SHELL_CONFIG" && ! grep -q "^function use_task_profile" "$SHELL_CONFIG"; then
    log_info "Adding use_task_profile function"
    
    # Add function after section marker
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Activate a Workwarrior profile"
          print "use_task_profile() {"
          print "  local profile_name=\"$1\""
          print "  local profile_base=\"$HOME/ww/profiles/$profile_name\""
          print ""
          print "  if [[ -z \"$profile_name\" ]]; then"
          print "    echo \"Error: Profile name required\" >&2"
          print "    echo \"Usage: use_task_profile <profile-name>\" >&2"
          print "    return 1"
          print "  fi"
          print ""
          print "  if [[ ! -d \"$profile_base\" ]]; then"
          print "    echo \"Error: Profile '\''$profile_name'\'' does not exist\" >&2"
          print "    echo \"Profile directory not found: $profile_base\" >&2"
          print "    return 1"
          print "  fi"
          print ""
          print "  export WARRIOR_PROFILE=\"$profile_name\""
          print "  export WORKWARRIOR_BASE=\"$profile_base\""
          print "  export TASKRC=\"$profile_base/.taskrc\""
          print "  export TASKDATA=\"$profile_base/.task\""
          print "  export TIMEWARRIORDB=\"$profile_base/.timewarrior\""
          print ""
          print "  echo \"✓ Activated profile: $profile_name\""
          print "  echo \"  Location: $profile_base\""
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  # Check if j function exists
  if ! grep -q "^j()" "$SHELL_CONFIG" && ! grep -q "^function j[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding j function"
    
    # Add function to core functions section
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Global journal function"
          print "j() {"
          print "  if [[ -z \"$WORKWARRIOR_BASE\" ]]; then"
          print "    echo \"Error: No profile is active\" >&2"
          print "    return 1"
          print "  fi"
          print "  local jrnl_config=\"$WORKWARRIOR_BASE/jrnl.yaml\""
          print "  if [[ ! -f \"$jrnl_config\" ]]; then"
          print "    echo \"Error: Journal configuration not found\" >&2"
          print "    return 1"
          print "  fi"
          print "  jrnl --config-file \"$jrnl_config\" \"$@\""
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  # Check if l function exists
  if ! grep -q "^l()" "$SHELL_CONFIG" && ! grep -q "^function l[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding l function"
    
    # Add function to core functions section
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Global ledger function"
          print "l() {"
          print "  if [[ -z \"$WORKWARRIOR_BASE\" ]]; then"
          print "    echo \"Error: No profile is active\" >&2"
          print "    return 1"
          print "  fi"
          print "  local ledger_config=\"$WORKWARRIOR_BASE/ledgers.yaml\""
          print "  if [[ ! -f \"$ledger_config\" ]]; then"
          print "    echo \"Error: Ledger configuration not found\" >&2"
          print "    return 1"
          print "  fi"
          print "  local default_ledger=$(grep \"^  default:\" \"$ledger_config\" | awk '\''{print $2}'\'')"
          print "  if [[ -z \"$default_ledger\" ]]; then"
          print "    echo \"Error: Default ledger not found\" >&2"
          print "    return 1"
          print "  fi"
          print "  hledger -f \"$default_ledger\" \"$@\""
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  log_success "Global shell functions ensured in ~/.bashrc"
  log_info "Reload your shell or run: source ~/.bashrc"
  
  return 0
}

# ============================================================================
# LIBRARY LOADED INDICATOR
# ============================================================================

readonly SHELL_INTEGRATION_LOADED=1
