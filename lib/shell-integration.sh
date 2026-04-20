#!/usr/bin/env bash
# Shell Integration Library
# Functions for managing shell aliases, functions, and environment
# Source this file: source "$(dirname "$0")/../lib/shell-integration.sh"
#
# NOTE: set -euo pipefail intentionally omitted here.
# This file is sourced into the user's interactive shell (.bashrc/.zshrc).
# File-level set flags propagate to the caller — setting -u in an interactive
# shell would cause unbound-variable errors on normal shell usage.
# Individual functions handle errors via return codes and local variable checks.

# Source core utilities if not already loaded
if [[ -z "${CORE_UTILS_LOADED:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$SCRIPT_DIR/core-utils.sh"
fi

# Skip re-initialization within the same shell session
[[ -n "${SHELL_INTEGRATION_LOADED:-}" ]] && return 0

# ============================================================================
# SHELL CONFIGURATION CONSTANTS
# ============================================================================

# Section markers for ~/.bashrc organization — plain vars, not readonly,
# so re-sourcing this file in the same shell does not error.
SECTION_PROFILE_ALIASES="# -- Workwarrior Profile Aliases ---"
SECTION_JOURNAL_ALIASES="# -- Direct Alias for Journals ---"
SECTION_LEDGER_ALIASES="# -- Direct Aliases for Hledger ---"
SECTION_CORE_FUNCTIONS="# --- Workwarrior Core Functions ---"

# Default shell configuration file
SHELL_CONFIG="${SHELL_CONFIG:-${SHELL_RC:-${HOME}/.bashrc}}"

# Global workspace defaults
WW_GLOBAL_BASE="${WW_GLOBAL_BASE:-${WW_BASE:-$HOME/ww}/global}"

# Return all active shell rc files (bashrc and/or zshrc if they exist).
# This is the single source of truth used by all functions that write to shell config.
# Creates ~/.bashrc as default if neither exists.
get_ww_rc_files() {
  local rc_files=()
  [[ -f "$HOME/.bashrc" ]] && rc_files+=("$HOME/.bashrc")
  [[ -f "$HOME/.zshrc" ]]  && rc_files+=("$HOME/.zshrc")
  if [[ ${#rc_files[@]} -eq 0 ]]; then
    touch "$HOME/.bashrc"
    rc_files+=("$HOME/.bashrc")
  fi
  printf '%s\n' "${rc_files[@]}"
}

# ============================================================================
# ALIAS MANAGEMENT FUNCTIONS
# ============================================================================

# Add an alias to a specific section in a shell rc file
# Checks if alias already exists (prevents duplicates)
# Ensures section marker exists in the target file
# Adds alias after section marker using awk for precise insertion
#
# Usage: add_alias_to_section "alias_line" "section_marker" [rc_file]
# Example: add_alias_to_section "alias p-work='use_task_profile work'" "$SECTION_PROFILE_ALIASES"
# Example: add_alias_to_section "alias p-work='use_task_profile work'" "$SECTION_PROFILE_ALIASES" "$HOME/.zshrc"
# Returns: 0 on success, 1 on failure
# Validates: Requirements 4.5, 4.6, 17.1, 17.2, 17.3, 17.4, 17.5, 17.6, 17.7, 17.8, 17.9, 17.10
add_alias_to_section() {
  local alias_line="$1"
  local section_marker="$2"
  local target_file="${3:-$SHELL_CONFIG}"

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
  if [[ ! -f "$target_file" ]]; then
    log_info "Creating $target_file"
    touch "$target_file"
  fi

  # Check if alias already exists (idempotence — silent if already present)
  if grep -Fxq "$alias_line" "$target_file"; then
    return 0
  fi

  # Ensure section marker exists
  if ! grep -Fxq "$section_marker" "$target_file"; then
    echo "" >> "$target_file"
    echo "$section_marker" >> "$target_file"
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
  ' "$target_file" > "$target_file.tmp"

  # Replace original with updated version
  if ! mv "$target_file.tmp" "$target_file"; then
    log_error "Failed to update $target_file"
    rm -f "$target_file.tmp"
    return 1
  fi

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
  local profile_name="${1:-}"

  # Validate profile name
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi

  local profile_base="$PROFILES_DIR/$profile_name"
  local jrnl_config="$profile_base/jrnl.yaml"
  local ledger_config="$profile_base/ledgers.yaml"

  # Check if profile exists
  if [[ ! -d "$profile_base" ]]; then
    log_error "Profile directory does not exist: $profile_base"
    return 1
  fi

  # Collect all active rc files to write aliases into
  local rc_files=()
  while IFS= read -r _f; do rc_files+=("$_f"); done < <(get_ww_rc_files)

  # Build alias strings
  local p_alias="alias p-${profile_name}='use_task_profile ${profile_name}'"
  local shorthand_alias="alias ${profile_name}='use_task_profile ${profile_name}'"

  local j_alias=""
  if [[ -f "$jrnl_config" ]]; then
    j_alias="alias j-${profile_name}='jrnl --config-file ${jrnl_config}'"
  else
    log_warning "jrnl.yaml not found, skipping journal alias"
  fi

  # Write p-alias, shorthand, and j-alias to each rc file
  for _rc in "${rc_files[@]}"; do
    # Create p-<profile-name> alias for profile activation
    if ! add_alias_to_section "$p_alias" "$SECTION_PROFILE_ALIASES" "$_rc"; then
      log_error "Failed to add p-${profile_name} alias to $_rc"
      return 1
    fi

    # Create <profile-name> alias as shorthand (skip reserved CLI names)
    case "${profile_name}" in
      ww|task|timew|jrnl|hledger)
        log_warning "Skipping bare alias for reserved name '${profile_name}' — use p-${profile_name} instead"
        ;;
      *)
        if ! add_alias_to_section "$shorthand_alias" "$SECTION_PROFILE_ALIASES" "$_rc"; then
          log_error "Failed to add ${profile_name} alias to $_rc"
          return 1
        fi
        ;;
    esac

    # Create j-<profile-name> alias for journal access
    if [[ -n "$j_alias" ]]; then
      if ! add_alias_to_section "$j_alias" "$SECTION_JOURNAL_ALIASES" "$_rc"; then
        log_error "Failed to add j-${profile_name} alias to $_rc"
        return 1
      fi
    fi
  done
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
        for _rc in "${rc_files[@]}"; do
          add_alias_to_section "$l_alias" "$SECTION_LEDGER_ALIASES" "$_rc" \
            || log_warning "Failed to add l-${profile_name} alias to $_rc"
        done
      else
        # For named ledgers, use l-<profile-name>-<ledger-name>
        local l_alias="alias l-${profile_name}-${ledger_name}='hledger -f ${ledger_path}'"
        for _rc in "${rc_files[@]}"; do
          add_alias_to_section "$l_alias" "$SECTION_LEDGER_ALIASES" "$_rc" \
            || log_warning "Failed to add l-${profile_name}-${ledger_name} alias to $_rc"
        done
      fi
    done < "$ledger_config"
  else
    log_warning "ledgers.yaml not found, skipping ledger aliases"
  fi

  local rc_names=()
  local _rc
  for _rc in "${rc_files[@]}"; do rc_names+=("$(basename "$_rc")"); done
  log_success "Aliases written  →  ${rc_names[*]}"

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
  local profile_name="${1:-}"

  # Validate profile name
  if ! validate_profile_name "$profile_name"; then
    return 1
  fi

  log_step "Removing shell aliases for profile '$profile_name'"

  # Collect all active rc files
  local rc_files=()
  while IFS= read -r _f; do rc_files+=("$_f"); done < <(get_ww_rc_files)

  local timestamp
  timestamp=$(date '+%Y%m%d%H%M%S')
  local any_found=0

  for _rc in "${rc_files[@]}"; do
    # Skip if the file does not exist
    if [[ ! -f "$_rc" ]]; then
      log_warning "$_rc not found, skipping"
      continue
    fi

    any_found=1

    # Create a timestamped backup for this file
    local backup_file="${_rc}.ww-backup.${timestamp}"
    if ! cp "$_rc" "$backup_file"; then
      log_error "Failed to create backup of $_rc"
      return 1
    fi

    # Remove aliases using a portable approach (BSD/GNU sed compatible)
    local tmp_file="${_rc}.tmp"
    if ! sed \
      -e "/^alias p-${profile_name}=/d" \
      -e "/^alias ${profile_name}='use_task_profile ${profile_name}'/d" \
      -e "/^alias j-${profile_name}=/d" \
      -e "/^alias l-${profile_name}/d" \
      "$_rc" > "$tmp_file"; then
      log_error "Failed to update $_rc"
      rm -f "$tmp_file"
      return 1
    fi

    if ! mv "$tmp_file" "$_rc"; then
      log_error "Failed to save updated $_rc"
      rm -f "$tmp_file"
      return 1
    fi

    log_info "Backup saved to: $backup_file"
  done

  if [[ "$any_found" -eq 0 ]]; then
    log_warning "No rc files found, nothing to remove"
    return 0
  fi

  log_success "Removed aliases for profile '$profile_name'"
  log_info "Reload your shell or run: source ${rc_files[0]}"

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
  elif [[ -n "${WORKWARRIOR_BASE:-}" && -n "${WARRIOR_PROFILE:-}" ]]; then
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
  local profile_name="${1:-}"

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
  # Point bugwarrior to profile-specific config (toml takes precedence over ini)
  if [[ -f "$profile_base/.config/bugwarrior/bugwarrior.toml" ]]; then
    export BUGWARRIORRC="$profile_base/.config/bugwarrior/bugwarrior.toml"
  else
    export BUGWARRIORRC="$profile_base/.config/bugwarrior/bugwarriorrc"
  fi
  set_last_profile "$profile_name" >/dev/null 2>&1 || true

  # Display confirmation message
  echo "  ✓ ${profile_name}  ·  ${profile_base}"

  return 0
}

# Deactivate the current profile by unsetting all profile env vars.
# Usage: deactivate_task_profile  (or via alias: p-none)
deactivate_task_profile() {
  local prev="${WARRIOR_PROFILE:-}"
  unset WARRIOR_PROFILE WORKWARRIOR_BASE TASKRC TASKDATA TIMEWARRIORDB BUGWARRIORRC
  if [[ -n "$prev" ]]; then
    echo "  ✓ deactivated  ·  was: ${prev}"
  else
    echo "  ✓ no profile was active"
  fi
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

# ============================================================================
# STANDALONE WRAPPERS — no ww prefix required
# Each function: bare call = sensible default; subcommands pass through to ww.
# Subcommands marked "# future" route correctly but are not yet implemented in ww.
# ============================================================================

# Profile management
profile() {
  local cmd="${1:-}"
  case "$cmd" in
    "")
      # Bare: show current profile card if active, else list profiles
      if [[ -n "${WARRIOR_PROFILE:-}" ]]; then
        ww profile info "$WARRIOR_PROFILE"
      else
        ww profile list
      fi
      ;;
    create|list|delete|backup|restore|import|info|stats|meta|help|--help|-h)
      ww profile "$@"
      ;;
    *)
      echo "Unknown profile command: $cmd" >&2
      echo "Usage: profile <create|list|delete|backup|restore|import|info|stats>" >&2
      return 1
      ;;
  esac
}

# Shorthand: list all profiles
profiles() {
  ww profile list "$@"
}

# Journal namespace management (list/create/delete/rename journals within a profile)
# Bare form lists journal names from the active profile's jrnl.yaml.
# Bug fix: reads only keys under the 'journals:' section, not all YAML keys.
journals() {
  local cmd="${1:-}"
  case "$cmd" in
    "")
      if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
        echo "Error: No profile is active" >&2
        return 1
      fi
      local jrnl_config="$WORKWARRIOR_BASE/jrnl.yaml"
      if [[ ! -f "$jrnl_config" ]]; then
        echo "Error: Journal configuration not found: $jrnl_config" >&2
        return 1
      fi
      awk '/^journals:/{f=1;next} f && /^[^ ]/{f=0} f && /^  [a-zA-Z0-9_-]+:/{match($0,/[a-zA-Z0-9_-]+/); print "  • " substr($0,RSTART,RLENGTH)}' "$jrnl_config"
      ;;
    create|list|delete|rename|add|remove|help|--help|-h)
      ww journal "$@"  # future: ww journal create/delete/rename not yet implemented
      ;;
    *)
      echo "Unknown journals command: $cmd" >&2
      echo "Usage: journals <create|list|delete|rename>" >&2
      return 1
      ;;
  esac
}

# Ledger namespace management (list/create/delete/rename ledgers within a profile)
ledgers() {
  local cmd="${1:-}"
  case "$cmd" in
    "")
      if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
        echo "Error: No profile is active" >&2
        return 1
      fi
      local ledger_config="$WORKWARRIOR_BASE/ledgers.yaml"
      if [[ ! -f "$ledger_config" ]]; then
        echo "Error: Ledger configuration not found: $ledger_config" >&2
        return 1
      fi
      awk '/^ledgers:/{f=1;next} f && /^[^ ]/{f=0} f && /^  [a-zA-Z0-9_-]+:/{match($0,/[a-zA-Z0-9_-]+/); print "  • " substr($0,RSTART,RLENGTH)}' "$ledger_config"
      ;;
    create|list|delete|rename|add|remove|help|--help|-h)
      ww ledger "$@"  # future: ww ledger create/delete/rename not yet implemented
      ;;
    *)
      echo "Unknown ledgers command: $cmd" >&2
      echo "Usage: ledgers <create|list|delete|rename>" >&2
      return 1
      ;;
  esac
}

# Service browser
services() {
  if [[ $# -eq 0 ]]; then
    ww service list
  else
    ww service "$@"
  fi
}

# Groups registry
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

# Models registry
models() {
  if [[ $# -eq 0 ]]; then
    ww models list
  else
    ww models "$@"
  fi
}

# Extensions registry
extensions() {
  if [[ $# -eq 0 ]]; then
    ww extensions taskwarrior list
  else
    ww extensions "$@"
  fi
}

# Interactive service configuration (journals, tasks, times, ledgers, issues)
custom() {
  local cmd="${1:-}"
  case "$cmd" in
    "")
      ww custom
      ;;
    journals|tasks|times|ledgers|issues|help|--help|-h)
      ww custom "$@"
      ;;
    *)
      echo "Unknown custom command: $cmd" >&2
      echo "Usage: custom <journals|tasks|times|ledgers|issues>" >&2
      return 1
      ;;
  esac
}

# Shortcut reference
shortcuts() {
  local cmd="${1:-}"
  case "$cmd" in
    "")       ww shortcut list ;;
    list|info|compact|help|--help|-h) ww shortcut "$@" ;;
    *)        ww shortcut "$@" ;;
  esac
}

# Dependency management
deps() {
  local cmd="${1:-}"
  case "$cmd" in
    "")       ww deps check ;;
    check|install|list|help|--help|-h) ww deps "$@" ;;
    *)        ww deps "$@" ;;
  esac
}

# Version info
version() {
  ww version "$@"
}

# Search / find queries (renamed from find to avoid shadowing system find)
search() {
  if [[ $# -eq 0 ]]; then
    ww find --list-queries
  else
    ww find "$@"
  fi
}

# Task passthrough (profile-scoped)
tasks() {
  task "$@"
}

# Time tracking passthrough (profile-scoped)
times() {
  timew "$@"
}

# Global issues function - operates on active profile's bugwarrior config
# Checks WORKWARRIOR_BASE is set (profile must be active)
# Routes "i help"   to command routing matrix
# Routes "i custom" to configuration tool
# Routes GitHub sync commands (push, sync, enable-sync/enable, disable-sync/disable, sync-status/status) to github-sync.sh
# Routes bugwarrior commands (pull, uda) to bugwarrior
# Supports --json for pull (suppresses banner, emits JSON result) and status (captures output as JSON)
# Sets bugwarrior environment variables for profile isolation
# Validates configuration exists before executing
# Displays error if no profile active or configuration not found
#
# Usage: i [subcommand] [--json] [args...]
# Subcommands:
#   help                      - Show this command routing matrix
#   pull [--dry-run] [--json] - Pull issues from configured services (bugwarrior, one-way)
#   push [task-id]            - Push task changes to GitHub (github-sync, two-way)
#   sync [task-id]            - Bidirectional sync with GitHub (github-sync)
#   enable-sync <task> <issue> <repo> - Enable GitHub sync for a task
#   disable-sync <task>       - Disable GitHub sync for a task
#   status [--json]           - Show GitHub sync status
#   uda                       - List bugwarrior UDAs
#   custom                    - Configure issue services interactively
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

  # Parse --json flag (strip from args before routing)
  local json_mode=0
  local filtered_args=()
  for arg in "${args[@]}"; do
    if [[ "$arg" == "--json" ]]; then
      json_mode=1
    else
      filtered_args+=("$arg")
    fi
  done
  args=("${filtered_args[@]}")

  # Handle 'i help' command
  if [[ ${#args[@]} -eq 0 || "${args[0]}" == "help" || "${args[0]}" == "--help" || "${args[0]}" == "-h" ]]; then
    cat << 'EOF'
Issues Service

Routes to bugwarrior (one-way pull) or github-sync (two-way):

  i pull [--dry-run] [--json]              Pull issues from all configured services into TaskWarrior
  i uda                                     List TaskWarrior UDAs for configured services

  i push [task-id]                          Push task changes to GitHub
  i sync [task-id]                          Bidirectional sync with GitHub
  i enable-sync <task-id> <issue> <repo>    Enable GitHub sync for a task
  i disable-sync <task-id>                  Disable GitHub sync for a task
  i status [--json]                         Show GitHub sync status

  i custom                                  Configure issue services interactively
  i help                                    Show this help

Note: 'i' and 'ww issues' are synonymous.
Requires an active profile: p-<profile-name>

Bugwarrior is one-way only (external services → TaskWarrior).
For two-way GitHub sync, use: i push / i sync / i enable-sync

EOF
    return 0
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
        if [[ "$sync_command" == "status" && "$json_mode" -eq 1 ]]; then
          local sync_output
          local sync_exit=0
          sync_output=$(WORKWARRIOR_BASE="$WW_SCOPE_BASE" WARRIOR_PROFILE="$WW_SCOPE_PROFILE" \
            "$github_sync_cli" "$sync_command" "${remaining[@]}" 2>&1) || sync_exit=$?
          local escaped_output
          escaped_output="${sync_output//\\/\\\\}"
          escaped_output="${escaped_output//\"/\\\"}"
          escaped_output="${escaped_output//$'\n'/\\n}"
          if [[ "$sync_exit" -eq 0 ]]; then
            echo "{\"command\":\"status\",\"status\":\"success\",\"output\":\"${escaped_output}\"}"
          else
            echo "{\"command\":\"status\",\"status\":\"failed\",\"exit_code\":${sync_exit},\"output\":\"${escaped_output}\"}"
          fi
          return "$sync_exit"
        fi
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
    echo "Install with: pipx install bugwarrior && pipx inject bugwarrior setuptools" >&2
    echo "Or: pipx install bugwarrior" >&2
    return 1
  fi

  # Display sync direction message for pull command (suppressed in --json mode)
  if [[ ${#args[@]} -gt 0 && "${args[0]}" == "pull" && "$json_mode" -eq 0 ]]; then
    echo "⚠️  One-way sync: External services → TaskWarrior"
    echo "   Changes in TaskWarrior will NOT sync back to issue trackers"
    echo "   For two-way GitHub sync, use: i push, i sync, or i enable-sync"
    echo ""
  fi

  # Execute bugwarrior with profile-specific config
  if [[ "$json_mode" -eq 1 ]]; then
    local bw_exit=0
    BUGWARRIORRC="$bugwarrior_config" \
    BUGWARRIOR_TASKRC="$WW_SCOPE_BASE/.taskrc" \
    BUGWARRIOR_TASKDATA="$WW_SCOPE_BASE/.task" \
      bugwarrior "${args[@]}" >/dev/null 2>&1 || bw_exit=$?
    local subcmd="${args[0]:-run}"
    if [[ "$bw_exit" -eq 0 ]]; then
      echo "{\"command\":\"${subcmd}\",\"status\":\"success\"}"
    else
      echo "{\"command\":\"${subcmd}\",\"status\":\"failed\",\"exit_code\":${bw_exit}}"
    fi
    return "$bw_exit"
  fi

  BUGWARRIORRC="$bugwarrior_config" \
  BUGWARRIOR_TASKRC="$WW_SCOPE_BASE/.taskrc" \
  BUGWARRIOR_TASKDATA="$WW_SCOPE_BASE/.task" \
    bugwarrior "${args[@]}"
  return $?
}

# Ensure ww-init.sh is sourced in the user's shell config.
# All functions live in shell-integration.sh (sourced by ww-init.sh) — there is
# no need to inject per-function stubs into the rc file. A single source line
# is the only thing that needs to be present.
#
# Usage: ensure_shell_functions
# Returns: 0 on success, 1 on failure
ensure_shell_functions() {

  local ww_base="${WW_BASE:-$HOME/ww}"
  local ww_init="$ww_base/bin/ww-init.sh"

  # Collect all active rc files
  local rc_files=()
  while IFS= read -r _f; do rc_files+=("$_f"); done < <(get_ww_rc_files)

  for _rc in "${rc_files[@]}"; do
    if [[ ! -f "$_rc" ]]; then
      log_info "Creating $_rc"
      touch "$_rc" || { log_error "Cannot create $_rc"; return 1; }
    fi

    # If ww-init.sh is already referenced, nothing to do for this file
    if grep -qF "ww-init.sh" "$_rc" 2>/dev/null; then
      continue
    fi

    # Add source block — uses the same section markers as installer-utils.sh
    cat >> "$_rc" << EOF

# --- Workwarrior Installation ---
# Added by workwarrior profile creation
if [[ -f "${ww_init}" ]]; then
  source "${ww_init}"
fi
# --- End Workwarrior Installation ---
EOF

    log_success "Shell integration added to $(basename "$_rc")"
    log_info "Reload your shell or run: source $_rc"
  done

  return 0
}

# ============================================================================
# LIBRARY LOADED INDICATOR
# ============================================================================

SHELL_INTEGRATION_LOADED=1
