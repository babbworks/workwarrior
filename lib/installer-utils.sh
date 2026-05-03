#!/usr/bin/env bash
# Installer Utilities Library
# Shared functions for install.sh and uninstall.sh
# Source this file: source "$(dirname "$0")/lib/installer-utils.sh"

# Source core utilities if not already loaded
if [[ -z "$CORE_UTILS_LOADED" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$SCRIPT_DIR/core-utils.sh"
fi

# ============================================================================
# INSTALLATION CONSTANTS
# ============================================================================

readonly WW_VERSION="1.0.0"
# Allow override via environment variable for testing (e.g. WW_INSTALL_DIR=/tmp/ww-test ./install.sh)
WW_INSTALL_DIR="${WW_INSTALL_DIR:-$HOME/ww}"
WW_PRESET="${WW_PRESET:-basic}"
WW_COMMAND_NAME="${WW_COMMAND_NAME:-ww}"
WW_SECURITY_BACKEND="${WW_SECURITY_BACKEND:-auto}"

# Section markers for shell configuration
readonly SECTION_WW_INSTALL="# --- Workwarrior Installation ---"
readonly SECTION_WW_INSTALL_END="# --- End Workwarrior Installation ---"

# Shell RC files
readonly SHELL_RC_BASH="$HOME/.bashrc"
readonly SHELL_RC_ZSH="$HOME/.zshrc"
WW_CONFIG_HOME="${WW_CONFIG_HOME:-$HOME/.config/ww}"
WW_REGISTRY_DIR="${WW_REGISTRY_DIR:-$WW_CONFIG_HOME/registry}"

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

# Check if a command exists
# Usage: command_exists "command-name"
# Returns: 0 if exists, 1 if not
command_exists() {
  command -v "$1" &>/dev/null
}

# Check all external dependencies and report status
# Warns about missing dependencies but continues (non-blocking)
# Usage: check_dependencies
# Returns: 0 always (warnings only)
check_dependencies() {
  local missing=0

  log_info "Checking external dependencies..."
  echo ""

  # TaskWarrior
  if command_exists "task"; then
    log_success "TaskWarrior (task) - found"
  else
    log_warning "TaskWarrior (task) - not found"
    ((missing++))
  fi

  # TimeWarrior
  if command_exists "timew"; then
    log_success "TimeWarrior (timew) - found"
  else
    log_warning "TimeWarrior (timew) - not found"
    ((missing++))
  fi

  # JRNL
  if command_exists "jrnl"; then
    log_success "JRNL (jrnl) - found"
  else
    log_warning "JRNL (jrnl) - not found"
    ((missing++))
  fi

  # Hledger
  if command_exists "hledger"; then
    log_success "Hledger (hledger) - found"
  else
    log_warning "Hledger (hledger) - not found"
    ((missing++))
  fi

  # Python 3
  if command_exists "python3"; then
    log_success "Python 3 (python3) - found"
  else
    log_warning "Python 3 (python3) - not found"
    ((missing++))
  fi

  echo ""

  if (( missing > 0 )); then
    log_warning "$missing optional dependencies not found"
    log_info "Some features may be unavailable until dependencies are installed"
  else
    log_success "All dependencies found"
  fi

  return 0
}

# ============================================================================
# SHELL DETECTION AND CONFIGURATION
# ============================================================================

# Detect user's current shell
# Usage: detect_shell
# Returns: "bash", "zsh", or "unknown"
detect_shell() {
  local shell_name
  shell_name="$(basename "$SHELL")"

  case "$shell_name" in
    bash|zsh)
      echo "$shell_name"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Get list of shell RC files to configure
# Returns both .bashrc and .zshrc if they exist
# Creates .bashrc if neither exists
# Usage: get_shell_rc_files
# Prints: newline-separated list of RC file paths
get_shell_rc_files() {
  local rc_files=()

  # Check for existing RC files
  [[ -f "$SHELL_RC_BASH" ]] && rc_files+=("$SHELL_RC_BASH")
  [[ -f "$SHELL_RC_ZSH" ]] && rc_files+=("$SHELL_RC_ZSH")

  # If neither exists, create .bashrc as default
  if (( ${#rc_files[@]} == 0 )); then
    touch "$SHELL_RC_BASH"
    rc_files+=("$SHELL_RC_BASH")
  fi

  printf '%s\n' "${rc_files[@]}"
}

# Add workwarrior configuration to a shell RC file
# Idempotent - safe to run multiple times
# Usage: add_ww_to_shell_rc "/path/to/.bashrc"
# Returns: 0 on success, 1 on failure
add_ww_to_shell_rc() {
  local rc_file="$1"

  if [[ -z "$rc_file" ]]; then
    log_error "RC file path required"
    return 1
  fi

  # Create file if it doesn't exist
  if [[ ! -f "$rc_file" ]]; then
    touch "$rc_file" || {
      log_error "Failed to create $rc_file"
      return 1
    }
  fi

  # Check if already configured (idempotence)
  if grep -Fq "$SECTION_WW_INSTALL" "$rc_file"; then
    log_info "Workwarrior already configured in $(basename "$rc_file")"
    return 0
  fi

  # Append configuration block (uses actual install dir, not hardcoded $HOME/ww)
  cat >> "$rc_file" << EOF

# --- Workwarrior Installation ---
# Added by workwarrior installer
export WW_BASE="${WW_INSTALL_DIR}"
if [[ -f "${WW_INSTALL_DIR}/bin/ww-init.sh" ]]; then
  source "${WW_INSTALL_DIR}/bin/ww-init.sh"
fi
# --- End Workwarrior Installation ---
EOF

  log_success "Added workwarrior to $(basename "$rc_file")"
  return 0
}

# Remove workwarrior configuration from a shell RC file
# Usage: remove_ww_from_shell_rc "/path/to/.bashrc"
# Returns: 0 on success, 1 on failure
remove_ww_from_shell_rc() {
  local rc_file="$1"

  if [[ -z "$rc_file" ]]; then
    log_error "RC file path required"
    return 1
  fi

  if [[ ! -f "$rc_file" ]]; then
    return 0
  fi

  # Check if configured
  if ! grep -Fq "$SECTION_WW_INSTALL" "$rc_file"; then
    log_info "Workwarrior not configured in $(basename "$rc_file")"
    return 0
  fi

  # Create backup
  local backup_file="$rc_file.ww-backup.$(date +%Y%m%d%H%M%S)"
  cp "$rc_file" "$backup_file" || {
    log_error "Failed to create backup of $rc_file"
    return 1
  }

  # Remove section using awk
  awk -v start="$SECTION_WW_INSTALL" -v end="$SECTION_WW_INSTALL_END" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$rc_file" > "$rc_file.tmp"

  # Also remove any blank lines before the section that we added
  mv "$rc_file.tmp" "$rc_file" || {
    log_error "Failed to update $rc_file"
    rm -f "$rc_file.tmp"
    return 1
  }

  log_success "Removed workwarrior from $(basename "$rc_file")"
  log_info "Backup saved: $backup_file"
  return 0
}

# ============================================================================
# INSTALLATION HELPERS
# ============================================================================

# Create installation directory structure
# Usage: create_install_structure
# Returns: 0 on success, 1 on failure
create_install_structure() {
  local dirs=(
    "$WW_INSTALL_DIR"
    "$WW_INSTALL_DIR/bin"
    "$WW_INSTALL_DIR/lib"
    "$WW_INSTALL_DIR/scripts"
    "$WW_INSTALL_DIR/services"
    "$WW_INSTALL_DIR/profiles"
    "$WW_INSTALL_DIR/resources"
    "$WW_INSTALL_DIR/config"
    "$WW_INSTALL_DIR/functions"
    "$WW_INSTALL_DIR/tools"
    "$WW_CONFIG_HOME"
    "$WW_REGISTRY_DIR"
  )

  for dir in "${dirs[@]}"; do
    if ! mkdir -p "$dir" 2>/dev/null; then
      log_error "Failed to create directory: $dir"
      return 1
    fi
  done

  log_success "Created directory structure at $WW_INSTALL_DIR"
  return 0
}

create_command_launcher() {
  local command_name="${1:-ww}"
  local launcher_dir="$HOME/.local/bin"
  local launcher_path="$launcher_dir/$command_name"

  mkdir -p "$launcher_dir" || {
    log_error "Failed to create launcher directory: $launcher_dir"
    return 1
  }

  if [[ -e "$launcher_path" ]]; then
    rm -f "$launcher_path" || {
      log_error "Failed to replace existing launcher: $launcher_path"
      return 1
    }
    log_info "Replaced existing launcher: $launcher_path"
  fi

  cat > "$launcher_path" << EOF
#!/usr/bin/env bash
export WW_BASE="${WW_INSTALL_DIR}"
exec "${WW_INSTALL_DIR}/bin/ww" "\$@"
EOF
  chmod +x "$launcher_path" || {
    log_error "Failed to make launcher executable: $launcher_path"
    return 1
  }
  log_success "Created launcher: $launcher_path"
  return 0
}

write_instance_manifest() {
  local instance_id="$1"
  local visibility="${2:-visible}"
  local command_name="${3:-ww}"
  local manifest="$WW_REGISTRY_DIR/$instance_id.json"

  mkdir -p "$WW_REGISTRY_DIR" || return 1
  cat > "$manifest" << EOF
{
  "id": "$instance_id",
  "alias": "$instance_id",
  "version": "$WW_VERSION",
  "visibility": "$visibility",
  "install_path": "$WW_INSTALL_DIR",
  "preset": "$WW_PRESET",
  "command_name": "$command_name",
  "security_backend": "$WW_SECURITY_BACKEND",
  "parent_anchor": null,
  "allowed_orchestrators": [],
  "registered_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "active"
}
EOF
  log_success "Registered instance manifest: $manifest"
}

write_instance_function() {
  local cmd_name="$1"
  local install_path="$2"
  local func_file="${WW_CONFIG_HOME}/instance-functions.sh"
  mkdir -p "${WW_CONFIG_HOME}" || return 1

  # Remove any existing function block for this command name
  if [[ -f "$func_file" ]]; then
    local tmp
    tmp="$(mktemp)"
    awk -v cmd="$cmd_name" '
      /^# ww-instance-fn: / && $3==cmd { skip=1 }
      /^# ww-instance-fn-end: / && $3==cmd { skip=0; next }
      !skip { print }
    ' "$func_file" > "$tmp" && mv "$tmp" "$func_file"
  fi

  cat >> "$func_file" << FNEOF
# ww-instance-fn: ${cmd_name}
${cmd_name}() {
  if [[ \$# -eq 0 ]]; then
    export WW_BASE="${install_path}"
    export WW_ACTIVE_INSTANCE="${cmd_name}"
    local last
    last="\$(cat "\${WW_CONFIG_HOME:-\$HOME/.config/ww}/last-profile-${cmd_name}" 2>/dev/null || echo "default")"
    if command -v use_task_profile &>/dev/null; then
      use_task_profile "\$last" 2>/dev/null || true
    else
      p-"\$last" 2>/dev/null || true
    fi
  else
    env WW_BASE="${install_path}" "${install_path}/bin/ww" "\$@"
  fi
}
# ww-instance-fn-end: ${cmd_name}
FNEOF
  log_success "Registered instance function: ${cmd_name}()"
}

# Check if workwarrior is already installed
# Usage: is_ww_installed
# Returns: 0 if installed, 1 if not
is_ww_installed() {
  [[ -d "$WW_INSTALL_DIR" ]] && [[ -f "$WW_INSTALL_DIR/bin/ww" ]]
}

# Get installed version
# Usage: get_installed_version
# Returns: version string or "unknown"
get_installed_version() {
  if [[ -f "$WW_INSTALL_DIR/VERSION" ]]; then
    cat "$WW_INSTALL_DIR/VERSION"
  else
    echo "unknown"
  fi
}

# ============================================================================
# LIBRARY LOADED INDICATOR
# ============================================================================

readonly INSTALLER_UTILS_LOADED=1
