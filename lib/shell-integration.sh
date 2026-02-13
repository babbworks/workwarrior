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

# Global workspace defaults
readonly WW_GLOBAL_BASE="${WW_GLOBAL_BASE:-${WW_BASE:-$HOME/ww}/global}"

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

  # Remove aliases using a portable approach (BSD/GNU sed compatible)
  local tmp_file="$SHELL_CONFIG.tmp"
  if ! sed \
    -e "/^alias p-${profile_name}=/d" \
    -e "/^alias ${profile_name}='use_task_profile ${profile_name}'/d" \
    -e "/^alias j-${profile_name}=/d" \
    -e "/^alias l-${profile_name}/d" \
    "$SHELL_CONFIG" > "$tmp_file"; then
    log_error "Failed to update $SHELL_CONFIG"
    rm -f "$tmp_file"
    return 1
  fi

  if ! mv "$tmp_file" "$SHELL_CONFIG"; then
    log_error "Failed to save updated $SHELL_CONFIG"
    rm -f "$tmp_file"
    return 1
  fi

  log_success "Removed aliases for profile '$profile_name'"
  log_info "Backup saved to: $SHELL_CONFIG.bak"
  log_info "Reload your shell or run: source ~/.bashrc"
  
  return 0
}

# ============================================================================
# GLOBAL SHELL FUNCTIONS
# ============================================================================

# Resolve scope for global/profile-aware commands
# Supports: --global, --profile <name>, --profile=<name>
# Sets: WW_SCOPE_BASE, WW_SCOPE_PROFILE, WW_SCOPE_MODE, WW_REMAINING_ARGS
ww_resolve_scope() {
  local scope_mode=""
  local scope_profile=""
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --global)
        scope_mode="global"
        shift
        ;;
      --profile)
        scope_mode="profile"
        scope_profile="${2:-}"
        shift 2
        ;;
      --profile=*)
        scope_mode="profile"
        scope_profile="${1#--profile=}"
        shift
        ;;
      --)
        shift
        args+=("$@")
        break
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  if [[ "$scope_mode" == "profile" && -z "$scope_profile" ]]; then
    echo "Error: --profile requires a profile name" >&2
    return 1
  fi

  if [[ -n "$scope_mode" ]]; then
    WW_SCOPE_MODE="$scope_mode"
  elif [[ -n "$WORKWARRIOR_BASE" && -n "$WARRIOR_PROFILE" ]]; then
    WW_SCOPE_MODE="active"
    WW_SCOPE_PROFILE="$WARRIOR_PROFILE"
    WW_SCOPE_BASE="$WORKWARRIOR_BASE"
  elif [[ "${WW_GLOBAL_DEFAULT:-}" == "1" ]]; then
    WW_SCOPE_MODE="global"
  else
    echo "Error: No profile is active. Use p-<profile> or add --global/--profile." >&2
    return 1
  fi

  if [[ "$WW_SCOPE_MODE" == "profile" ]]; then
    WW_SCOPE_PROFILE="$scope_profile"
    WW_SCOPE_BASE="${WW_BASE:-$HOME/ww}/profiles/$scope_profile"
    if [[ ! -d "$WW_SCOPE_BASE" ]]; then
      echo "Error: Profile '$scope_profile' does not exist at $WW_SCOPE_BASE" >&2
      return 1
    fi
  elif [[ "$WW_SCOPE_MODE" == "global" ]]; then
    WW_SCOPE_PROFILE="global"
    WW_SCOPE_BASE="$WW_GLOBAL_BASE"
  fi

  WW_REMAINING_ARGS=("${args[@]}")
  return 0
}

# Ensure global workspace exists with minimal structure
ensure_global_workspace() {
  local base="$WW_GLOBAL_BASE"
  local journals_dir="$base/journals"
  local ledgers_dir="$base/ledgers"
  local list_dir="$base/list"
  local task_dir="$base/.task"
  local task_hooks="$task_dir/hooks"
  local timew_dir="$base/.timewarrior"

  mkdir -p "$journals_dir" "$ledgers_dir" "$list_dir" "$task_dir" "$task_hooks" "$timew_dir"

  # Default journal
  local default_journal="$journals_dir/global.txt"
  if [[ ! -f "$default_journal" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M'): Welcome to your global journal!" > "$default_journal"
  fi

  # jrnl.yaml
  local jrnl_config="$base/jrnl.yaml"
  if [[ ! -f "$jrnl_config" ]]; then
    cat > "$jrnl_config" << EOF
journals:
  default: $default_journal
editor: nano
encrypt: false
tagsymbols: '@'
default_hour: 9
default_minute: 0
timeformat: "%Y-%m-%d %H:%M"
highlight: true
linewrap: 79
template: false
colors:
  body: none
  date: blue
  tags: yellow
  title: cyan
EOF
  fi

  # Default ledger
  local default_ledger="$ledgers_dir/global.journal"
  if [[ ! -f "$default_ledger" ]]; then
    cat > "$default_ledger" << EOF
; Hledger journal for global workspace
; Initialized on $(date '+%Y-%m-%d')
account assets:cash
account expenses:misc
account equity:opening-balances

$(date '+%Y-%m-%d') * Global initialization
    assets:cash          \$0.00
    equity:opening-balances   \$0.00
EOF
  fi

  # ledgers.yaml
  local ledgers_config="$base/ledgers.yaml"
  if [[ ! -f "$ledgers_config" ]]; then
    cat > "$ledgers_config" << EOF
ledgers:
  default: $default_ledger
EOF
  fi

  # Default list file
  local default_list="$list_dir/global_default.list"
  if [[ ! -f "$default_list" ]]; then
    echo "# List: global_default" > "$default_list"
  fi

  # Minimal .taskrc (if missing)
  local taskrc="$base/.taskrc"
  if [[ ! -f "$taskrc" ]]; then
    if [[ -f "${WW_BASE:-$HOME/ww}/resources/config-files/.taskrc" ]]; then
      cp "${WW_BASE:-$HOME/ww}/resources/config-files/.taskrc" "$taskrc"
      sed -i.bak \
        -e "s|^data.location=.*|data.location=$task_dir|" \
        -e "s|^hooks.location=.*|hooks.location=$task_hooks|" \
        "$taskrc" && rm -f "$taskrc.bak"
    else
      cat > "$taskrc" << EOF
data.location=$task_dir
hooks.location=$task_hooks
hooks=1
EOF
    fi
  fi
}

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
  if ! ww_resolve_scope "$@"; then
    return 1
  fi
  local args=("${WW_REMAINING_ARGS[@]}")

  if [[ "$WW_SCOPE_MODE" == "global" ]]; then
    ensure_global_workspace
  fi

  local jrnl_config="$WW_SCOPE_BASE/jrnl.yaml"

  # Check if jrnl.yaml exists
  if [[ ! -f "$jrnl_config" ]]; then
    echo "Error: Journal configuration not found: $jrnl_config" >&2
    return 1
  fi

  # If no arguments, just run jrnl to view default journal
  if [[ ${#args[@]} -eq 0 ]]; then
    jrnl --config-file "$jrnl_config"
    return $?
  fi

  # Check for special commands
  local first_arg="${args[0]}"
  
  # Handle 'j custom' command (reserved)
  if [[ "$first_arg" == "custom" ]]; then
    # Only valid when a profile is active or explicitly targeted
    if [[ "$WW_SCOPE_MODE" == "global" ]]; then
      echo "Error: 'j custom' is not available for global scope" >&2
      return 1
    fi
    local remaining=("${args[@]:1}")
    if command -v ww &>/dev/null; then
      WORKWARRIOR_BASE="$WW_SCOPE_BASE" WARRIOR_PROFILE="$WW_SCOPE_PROFILE" ww custom journals "${remaining[@]}"
    else
      local ww_base="${WW_BASE:-$HOME/ww}"
      WORKWARRIOR_BASE="$WW_SCOPE_BASE" WARRIOR_PROFILE="$WW_SCOPE_PROFILE" \
        "$ww_base/services/custom/configure-journals.sh" "${remaining[@]}"
    fi
    return $?
  fi

  # Check if first argument is a journal name
  # A journal name is a single word without spaces
  local is_journal_name=0

  # Check if first arg exists as a journal in jrnl.yaml
  if grep -q "^  ${first_arg}:" "$jrnl_config"; then
    is_journal_name=1
  fi

  # If first arg is a journal name, use it
  if [[ $is_journal_name -eq 1 ]]; then
    local journal_name="$first_arg"
    local remaining=("${args[@]:1}")
    
    # If no more arguments, view the journal
    if [[ ${#remaining[@]} -eq 0 ]]; then
      jrnl --config-file "$jrnl_config" "$journal_name"
      return $?
    fi
    
    # Write to named journal
    jrnl --config-file "$jrnl_config" "$journal_name" "${remaining[@]}"
    return $?
  else
    # Write to default journal
    jrnl --config-file "$jrnl_config" "${args[@]}"
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
  if ! ww_resolve_scope "$@"; then
    return 1
  fi
  local args=("${WW_REMAINING_ARGS[@]}")

  if [[ "$WW_SCOPE_MODE" == "global" ]]; then
    ensure_global_workspace
  fi

  local ledger_config="$WW_SCOPE_BASE/ledgers.yaml"

  # Check if ledgers.yaml exists
  if [[ ! -f "$ledger_config" ]]; then
    echo "Error: Ledger configuration not found: $ledger_config" >&2
    return 1
  fi

  # Handle 'l custom' command (reserved)
  if [[ ${#args[@]} -gt 0 && "${args[0]}" == "custom" ]]; then
    if [[ "$WW_SCOPE_MODE" == "global" ]]; then
      echo "Error: 'l custom' is not available for global scope" >&2
      return 1
    fi
    local remaining=("${args[@]:1}")
    if command -v ww &>/dev/null; then
      WORKWARRIOR_BASE="$WW_SCOPE_BASE" WARRIOR_PROFILE="$WW_SCOPE_PROFILE" ww custom ledgers "${remaining[@]}"
    else
      local ww_base="${WW_BASE:-$HOME/ww}"
      WORKWARRIOR_BASE="$WW_SCOPE_BASE" WARRIOR_PROFILE="$WW_SCOPE_PROFILE" \
        "$ww_base/services/custom/configure-ledgers.sh" "${remaining[@]}"
    fi
    return $?
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
  hledger -f "$default_ledger" "${args[@]}"
  return $?
}

# Global list function - operates on active or global scope
# Usage: list [--global|--profile <name>] [list-args]
list() {
  if ! ww_resolve_scope "$@"; then
    return 1
  fi
  local args=("${WW_REMAINING_ARGS[@]}")

  if [[ "$WW_SCOPE_MODE" == "global" ]]; then
    ensure_global_workspace
  fi

  local list_dir="$WW_SCOPE_BASE/list"
  local default_list_file="$list_dir/${WW_SCOPE_PROFILE}_default.list"

  if [[ ! -f "$default_list_file" ]]; then
    mkdir -p "$list_dir"
    echo "# List: ${WW_SCOPE_PROFILE}_default" > "$default_list_file"
  fi

  python3 "${WW_BASE:-$HOME/ww}/tools/list/list.py" -t "$list_dir" "${args[@]}"
  return $?
}

# TaskWarrior wrapper with scope support
task() {
  if ! ww_resolve_scope "$@"; then
    return 1
  fi
  local args=("${WW_REMAINING_ARGS[@]}")

  if [[ "$WW_SCOPE_MODE" == "global" ]]; then
    ensure_global_workspace
  fi

  local base="$WW_SCOPE_BASE"
  TASKRC="$base/.taskrc" TASKDATA="$base/.task" command task "${args[@]}"
}

# TimeWarrior wrapper with scope support
timew() {
  if ! ww_resolve_scope "$@"; then
    return 1
  fi
  local args=("${WW_REMAINING_ARGS[@]}")

  if [[ "$WW_SCOPE_MODE" == "global" ]]; then
    ensure_global_workspace
  fi

  local base="$WW_SCOPE_BASE"
  TIMEWARRIORDB="$base/.timewarrior" command timew "${args[@]}"
}

# Standalone wrappers (no ww prefix)
extensions() {
  if [[ $# -eq 0 ]]; then
    ww extensions taskwarrior list
  else
    ww extensions "$@"
  fi
}

models() {
  if [[ $# -eq 0 ]]; then
    ww models list
  else
    ww models "$@"
  fi
}

groups() {
  if [[ $# -eq 0 ]]; then
    if [[ -n "${WARRIOR_PROFILE:-}" ]]; then
      ww groups list --profile "$WARRIOR_PROFILE"
    else
      ww groups list
    fi
  else
    ww groups "$@"
  fi
}

journals() {
  if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
    echo "Error: No profile is active" >&2
    return 1
  fi
  local jrnl_config="$WORKWARRIOR_BASE/jrnl.yaml"
  if [[ ! -f "$jrnl_config" ]]; then
    echo "Error: Journal configuration not found: $jrnl_config" >&2
    return 1
  fi
  grep "^  [a-zA-Z0-9_-]\+:" "$jrnl_config" | sed 's/^  /  • /'
}

ledgers() {
  if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
    echo "Error: No profile is active" >&2
    return 1
  fi
  local ledger_config="$WORKWARRIOR_BASE/ledgers.yaml"
  if [[ ! -f "$ledger_config" ]]; then
    echo "Error: Ledger configuration not found: $ledger_config" >&2
    return 1
  fi
  grep "^  [a-zA-Z0-9_-]\+:" "$ledger_config" | sed 's/^  /  • /'
}

find() {
  if [[ $# -eq 0 ]]; then
    ww find --list-queries
  else
    ww find "$@"
  fi
}

tasks() {
  task "$@"
}

times() {
  timew "$@"
}

services() {
  if [[ $# -eq 0 ]]; then
    ww service list
  else
    ww service "$@"
  fi
}
# Global issues function - operates on active profile's bugwarrior config
# Checks WORKWARRIOR_BASE is set (profile must be active)
# Routes "i custom" to configuration tool
# Routes GitHub sync commands (push, sync, enable-sync/enable, disable-sync/disable, sync-status/status) to github-sync.sh
# Sets bugwarrior environment variables for profile isolation
# Validates configuration exists before executing
# Displays error if no profile active or configuration not found
#
# Usage: i [bugwarrior-args | github-sync-commands]
# Examples:
#   i pull                    - Pull issues from configured services (bugwarrior)
#   i push                    - Push task changes to GitHub (two-way sync)
#   i sync                    - Bidirectional sync with GitHub (two-way sync)
#   i enable-sync <task> <issue> <repo>  - Enable GitHub sync for a task
#   i disable-sync <task>     - Disable GitHub sync for a task
#   i sync-status             - Show GitHub sync status
#   i status                  - Alias for i sync-status
#   i pull --dry-run          - Test configuration without syncing
#   i uda                     - List bugwarrior UDAs
#   i custom                  - Configure issue services
# Returns: 0 on success, 1 on failure
# Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 3.3, 14.4, 14.5, 14.6, 19.1, 19.2, 19.3, 19.4, 19.5
i() {
  if ! ww_resolve_scope "$@"; then
    return 1
  fi
  local args=("${WW_REMAINING_ARGS[@]}")

  # Global scope not supported for issues
  if [[ "$WW_SCOPE_MODE" == "global" ]]; then
    echo "Error: Issues service requires a profile" >&2
    echo "Activate a profile with: p-<profile-name>" >&2
    return 1
  fi

  # Handle 'i custom' command (reserved)
  if [[ ${#args[@]} -gt 0 && "${args[0]}" == "custom" ]]; then
    local remaining=("${args[@]:1}")
    if command -v ww &>/dev/null; then
      WORKWARRIOR_BASE="$WW_SCOPE_BASE" WARRIOR_PROFILE="$WW_SCOPE_PROFILE" ww custom issues "${remaining[@]}"
    else
      local ww_base="${WW_BASE:-$HOME/ww}"
      WORKWARRIOR_BASE="$WW_SCOPE_BASE" WARRIOR_PROFILE="$WW_SCOPE_PROFILE" \
        "$ww_base/services/custom/configure-issues.sh" "${remaining[@]}"
    fi
    return $?
  fi

  # Route GitHub two-way sync commands to github-sync.sh
  if [[ ${#args[@]} -gt 0 ]]; then
    local first_arg="${args[0]}"
    case "$first_arg" in
      push|sync|enable-sync|disable-sync|sync-status|enable|disable|status)
        # Route to GitHub sync CLI
        local ww_base="${WW_BASE:-$HOME/ww}"
        local github_sync_cli="$ww_base/services/custom/github-sync.sh"
        
        if [[ ! -f "$github_sync_cli" ]]; then
          echo "Error: GitHub sync CLI not found at $github_sync_cli" >&2
          return 1
        fi
        
        # Map i() commands to github-sync commands
        local sync_command=""
        case "$first_arg" in
          push)
            sync_command="push"
            ;;
          sync)
            sync_command="sync"
            ;;
          enable-sync|enable)
            sync_command="enable"
            ;;
          disable-sync|disable)
            sync_command="disable"
            ;;
          sync-status|status)
            sync_command="status"
            ;;
        esac
        
        # Execute github-sync with remaining arguments
        local remaining=("${args[@]:1}")
        WORKWARRIOR_BASE="$WW_SCOPE_BASE" WARRIOR_PROFILE="$WW_SCOPE_PROFILE" \
          "$github_sync_cli" "$sync_command" "${remaining[@]}"
        return $?
        ;;
    esac
  fi

  # Check if bugwarrior config exists
  local bugwarrior_config="$WW_SCOPE_BASE/.config/bugwarrior/bugwarriorrc"
  if [[ ! -f "$bugwarrior_config" ]]; then
    # Try TOML format
    bugwarrior_config="$WW_SCOPE_BASE/.config/bugwarrior/bugwarrior.toml"
    if [[ ! -f "$bugwarrior_config" ]]; then
      echo "Error: Bugwarrior configuration not found" >&2
      echo "Run 'i custom' to configure the issues service" >&2
      return 1
    fi
  fi

  # Check if bugwarrior is installed
  if ! command -v bugwarrior &> /dev/null; then
    echo "Error: bugwarrior is not installed" >&2
    echo "Install with: pip install bugwarrior" >&2
    echo "Or: pipx install bugwarrior" >&2
    return 1
  fi

  # Display sync direction message for pull command
  if [[ ${#args[@]} -gt 0 && "${args[0]}" == "pull" ]]; then
    echo "⚠️  One-way sync: External services → TaskWarrior"
    echo "   Changes in TaskWarrior will NOT sync back to issue trackers"
    echo "   For two-way GitHub sync, use: i push, i sync, or i enable-sync"
    echo ""
  fi

  # Execute bugwarrior with profile-specific config
  BUGWARRIORRC="$bugwarrior_config" \
  BUGWARRIOR_TASKRC="$WW_SCOPE_BASE/.taskrc" \
  BUGWARRIOR_TASKDATA="$WW_SCOPE_BASE/.task" \
    bugwarrior "${args[@]}"
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
          print "# Global journal function (delegates to shell-integration.sh)"
          print "j() {"
          print "  local ww_base=\"${WW_BASE:-$HOME/ww}\""
          print "  if [[ -f \"$ww_base/lib/shell-integration.sh\" ]]; then"
          print "    unset -f j"
          print "    source \"$ww_base/lib/shell-integration.sh\""
          print "    j \"$@\""
          print "    return $?"
          print "  fi"
          print "  echo \"Error: shell integration not found at $ww_base/lib/shell-integration.sh\" >&2"
          print "  return 1"
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
          print "# Global ledger function (delegates to shell-integration.sh)"
          print "l() {"
          print "  local ww_base=\"${WW_BASE:-$HOME/ww}\""
          print "  if [[ -f \"$ww_base/lib/shell-integration.sh\" ]]; then"
          print "    unset -f l"
          print "    source \"$ww_base/lib/shell-integration.sh\""
          print "    l \"$@\""
          print "    return $?"
          print "  fi"
          print "  echo \"Error: shell integration not found at $ww_base/lib/shell-integration.sh\" >&2"
          print "  return 1"
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  # Check if list function exists
  if ! grep -q "^list()" "$SHELL_CONFIG" && ! grep -q "^function list[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding list function"
    
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Global list function (delegates to shell-integration.sh)"
          print "list() {"
          print "  local ww_base=\"${WW_BASE:-$HOME/ww}\""
          print "  if [[ -f \"$ww_base/lib/shell-integration.sh\" ]]; then"
          print "    unset -f list"
          print "    source \"$ww_base/lib/shell-integration.sh\""
          print "    list \"$@\""
          print "    return $?"
          print "  fi"
          print "  echo \"Error: shell integration not found at $ww_base/lib/shell-integration.sh\" >&2"
          print "  return 1"
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  # Check if task function exists
  if ! grep -q "^task()" "$SHELL_CONFIG" && ! grep -q "^function task[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding task function"
    
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# TaskWarrior wrapper (delegates to shell-integration.sh)"
          print "task() {"
          print "  local ww_base=\"${WW_BASE:-$HOME/ww}\""
          print "  if [[ -f \"$ww_base/lib/shell-integration.sh\" ]]; then"
          print "    unset -f task"
          print "    source \"$ww_base/lib/shell-integration.sh\""
          print "    task \"$@\""
          print "    return $?"
          print "  fi"
          print "  echo \"Error: shell integration not found at $ww_base/lib/shell-integration.sh\" >&2"
          print "  return 1"
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  # Check if timew function exists
  if ! grep -q "^timew()" "$SHELL_CONFIG" && ! grep -q "^function timew[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding timew function"
    
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# TimeWarrior wrapper (delegates to shell-integration.sh)"
          print "timew() {"
          print "  local ww_base=\"${WW_BASE:-$HOME/ww}\""
          print "  if [[ -f \"$ww_base/lib/shell-integration.sh\" ]]; then"
          print "    unset -f timew"
          print "    source \"$ww_base/lib/shell-integration.sh\""
          print "    timew \"$@\""
          print "    return $?"
          print "  fi"
          print "  echo \"Error: shell integration not found at $ww_base/lib/shell-integration.sh\" >&2"
          print "  return 1"
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  # Check if i function exists
  if ! grep -q "^i()" "$SHELL_CONFIG" && ! grep -q "^function i[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding i function"
    
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Global issues function (delegates to shell-integration.sh)"
          print "i() {"
          print "  local ww_base=\"${WW_BASE:-$HOME/ww}\""
          print "  if [[ -f \"$ww_base/lib/shell-integration.sh\" ]]; then"
          print "    unset -f i"
          print "    source \"$ww_base/lib/shell-integration.sh\""
          print "    i \"$@\""
          print "    return $?"
          print "  fi"
          print "  echo \"Error: shell integration not found at $ww_base/lib/shell-integration.sh\" >&2"
          print "  return 1"
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  # Check if help function exists
  if ! grep -q "^help()" "$SHELL_CONFIG" && ! grep -q "^function help[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding help function"
    
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Help wrapper (delegates to ww help)"
          print "help() {"
          print "  if command -v ww &>/dev/null; then"
          print "    if [[ -n \"$1\" ]]; then"
          print "      ww help \"$1\""
          print "    else"
          print "      ww help"
          print "    fi"
          print "    return $?"
          print "  fi"
          print "  echo \"Error: ww command not found\" >&2"
          print "  return 1"
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  # Standalone wrappers
  if ! grep -q "^extensions()" "$SHELL_CONFIG" && ! grep -q "^function extensions[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding extensions function"
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Extensions wrapper"
          print "extensions() {"
          print "  if [[ $# -eq 0 ]]; then"
          print "    ww extensions taskwarrior list"
          print "  else"
          print "    ww extensions \"$@\""
          print "  fi"
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  if ! grep -q "^models()" "$SHELL_CONFIG" && ! grep -q "^function models[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding models function"
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Models wrapper"
          print "models() {"
          print "  if [[ $# -eq 0 ]]; then"
          print "    ww models list"
          print "  else"
          print "    ww models \"$@\""
          print "  fi"
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  if ! grep -q "^groups()" "$SHELL_CONFIG" && ! grep -q "^function groups[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding groups function"
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Groups wrapper"
          print "groups() {"
          print "  if [[ $# -eq 0 ]]; then"
          print "    if [[ -n \"$WARRIOR_PROFILE\" ]]; then"
          print "      ww groups list --profile \"$WARRIOR_PROFILE\""
          print "    else"
          print "      ww groups list"
          print "    fi"
          print "  else"
          print "    ww groups \"$@\""
          print "  fi"
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  if ! grep -q "^journals()" "$SHELL_CONFIG" && ! grep -q "^function journals[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding journals function"
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Journals wrapper"
          print "journals() {"
          print "  if [[ -z \"$WORKWARRIOR_BASE\" ]]; then"
          print "    echo \"Error: No profile is active\" >&2"
          print "    return 1"
          print "  fi"
          print "  local jrnl_config=\"$WORKWARRIOR_BASE/jrnl.yaml\""
          print "  if [[ ! -f \"$jrnl_config\" ]]; then"
          print "    echo \"Error: Journal configuration not found: $jrnl_config\" >&2"
          print "    return 1"
          print "  fi"
          print "  grep \"^  [a-zA-Z0-9_-]\\+:\" \"$jrnl_config\" | sed \"s/^  /  • /\""
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  if ! grep -q "^ledgers()" "$SHELL_CONFIG" && ! grep -q "^function ledgers[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding ledgers function"
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Ledgers wrapper"
          print "ledgers() {"
          print "  if [[ -z \"$WORKWARRIOR_BASE\" ]]; then"
          print "    echo \"Error: No profile is active\" >&2"
          print "    return 1"
          print "  fi"
          print "  local ledger_config=\"$WORKWARRIOR_BASE/ledgers.yaml\""
          print "  if [[ ! -f \"$ledger_config\" ]]; then"
          print "    echo \"Error: Ledger configuration not found: $ledger_config\" >&2"
          print "    return 1"
          print "  fi"
          print "  grep \"^  [a-zA-Z0-9_-]\\+:\" \"$ledger_config\" | sed \"s/^  /  • /\""
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  if ! grep -q "^find()" "$SHELL_CONFIG" && ! grep -q "^function find[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding find function"
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Find wrapper"
          print "find() {"
          print "  if [[ $# -eq 0 ]]; then"
          print "    ww find --list-queries"
          print "  else"
          print "    ww find \"$@\""
          print "  fi"
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  if ! grep -q "^tasks()" "$SHELL_CONFIG" && ! grep -q "^function tasks[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding tasks function"
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Tasks wrapper"
          print "tasks() {"
          print "  task \"$@\""
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  if ! grep -q "^times()" "$SHELL_CONFIG" && ! grep -q "^function times[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding times function"
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Times wrapper"
          print "times() {"
          print "  timew \"$@\""
          print "}"
          added = 1
        }
      }
    ' "$SHELL_CONFIG" > "$SHELL_CONFIG.tmp"
    mv "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
  fi

  if ! grep -q "^services()" "$SHELL_CONFIG" && ! grep -q "^function services[[:space:]]*{" "$SHELL_CONFIG"; then
    log_info "Adding services function"
    awk -v marker="$SECTION_CORE_FUNCTIONS" '
      {
        print
        if ($0 == marker && !added) {
          print ""
          print "# Services wrapper"
          print "services() {"
          print "  if [[ $# -eq 0 ]]; then"
          print "    ww service list"
          print "  else"
          print "    ww service \"$@\""
          print "  fi"
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
