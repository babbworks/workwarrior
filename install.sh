#!/usr/bin/env bash
# Workwarrior Installation Script
# Installs workwarrior CLI tool to ~/ww
#
# Usage:
#   ./install.sh                    Interactive installation
#   ./install.sh --non-interactive  Automated installation (no prompts)
#   ./install.sh --force            Reinstall/upgrade existing installation

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

# Get script directory (where repo is cloned)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/core-utils.sh"
source "$SCRIPT_DIR/lib/installer-utils.sh"
source "$SCRIPT_DIR/lib/dependency-installer.sh"

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

NON_INTERACTIVE=0
FORCE_INSTALL=0
SKIP_DEPS=0
INSTALL_ALIAS=""
INSTALL_PRESET="basic"
COMMAND_NAME="ww"
ENABLE_INSTANCE_ALIASES=0
SECURITY_BACKEND="auto"

show_install_usage() {
  cat << EOF
Workwarrior Installation

Usage: ./install.sh [options]

Options:
  --non-interactive, -y    Skip all prompts, use defaults
  --force, -f              Force reinstall if already installed
  --skip-deps              Skip dependency installation
  --preset <name>          Install preset: plain|multi|isolated|hardened
  --cmd <name>             Command launcher name (default: ww)
  --enable-instance-aliases Enable bare instance aliases in shell
  --security-backend <name> Security backend: auto|keychain|libsecret|pass
  --help, -h               Show this help message

Examples:
  ./install.sh             Interactive installation
  ./install.sh -y          Non-interactive installation
  ./install.sh --force     Reinstall/upgrade
  ./install.sh --skip-deps Install workwarrior only (no dependencies)

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive|-y)
      NON_INTERACTIVE=1
      shift
      ;;
    --force|-f)
      FORCE_INSTALL=1
      shift
      ;;
    --skip-deps)
      SKIP_DEPS=1
      shift
      ;;
    --preset)
      INSTALL_PRESET="${2:-}"
      shift 2
      ;;
    --cmd)
      COMMAND_NAME="${2:-}"
      shift 2
      ;;
    --enable-instance-aliases)
      ENABLE_INSTANCE_ALIASES=1
      shift
      ;;
    --security-backend)
      SECURITY_BACKEND="${2:-}"
      shift 2
      ;;
    --help|-h)
      show_install_usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_install_usage
      exit 1
      ;;
  esac
done

# Compute anchor-specific config home (each anchor owns its own registry).
# Unconditional: library default (~/.config/ww) is overridden here based on --cmd.
# Users who need a custom path can set WW_CONFIG_HOME_OVERRIDE in their environment.
if [[ -n "${WW_CONFIG_HOME_OVERRIDE:-}" ]]; then
  export WW_CONFIG_HOME="$WW_CONFIG_HOME_OVERRIDE"
else
  export WW_CONFIG_HOME="$HOME/.config/$COMMAND_NAME"
fi
export WW_REGISTRY_DIR="$WW_CONFIG_HOME/registry"

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

show_banner() {
  echo ""
  echo "============================================================"
  echo "         Workwarrior CLI Installation"
  echo "         Version: $WW_VERSION"
  echo "============================================================"
  echo ""
}

ask_install_dir() {
  if (( NON_INTERACTIVE == 1 )); then
    log_info "Install directory: $WW_INSTALL_DIR"
    return 0
  fi

  local suggested="$HOME/ww"
  local chosen=""

  echo "Install location"
  echo "────────────────"
  echo ""
  echo "  Suggested:  $suggested"
  echo ""
  echo "  Press Enter to use the suggested location,"
  echo "  or type an absolute path to install elsewhere."
  echo "  (The directory will be created if it does not exist.)"
  echo ""
  read -rp "  Install to [$suggested]: " chosen

  # Empty input → use suggested
  if [[ -z "$chosen" ]]; then
    chosen="$suggested"
  fi

  # Expand leading ~ manually (read does not expand it)
  chosen="${chosen/#\~/$HOME}"

  # Require absolute path
  if [[ "$chosen" != /* ]]; then
    log_error "Path must be absolute (start with /). Got: $chosen"
    exit 1
  fi

  # Warn if the directory already exists and contains files
  if [[ -d "$chosen" ]] && [[ -n "$(ls -A "$chosen" 2>/dev/null)" ]]; then
    echo ""
    log_warning "$chosen already exists and is not empty."
    read -rp "  Continue anyway? [y/n]: " ok
    if [[ "$ok" != "y" && "$ok" != "Y" ]]; then
      log_info "Installation cancelled"
      exit 0
    fi
  fi

  # Apply — export so all sourced functions see the updated value
  export WW_INSTALL_DIR="$chosen"
  echo ""
  log_info "Install directory set to: $WW_INSTALL_DIR"
  echo ""
}

prompt_install_alias() {
  if (( NON_INTERACTIVE == 1 )); then
    INSTALL_ALIAS=""
    return 0
  fi

  echo ""
  read -rp "Command name for this installation (optional, Enter to skip): " alias_input

  # normalize whitespace
  alias_input="$(echo "$alias_input" | xargs)"

  if [[ -z "$alias_input" ]]; then
    INSTALL_ALIAS=""
    return 0
  fi

  INSTALL_ALIAS="$alias_input"
  COMMAND_NAME="$alias_input"
  # Update config home to match the new command name
  export WW_CONFIG_HOME="$HOME/.config/$COMMAND_NAME"
  export WW_REGISTRY_DIR="$WW_CONFIG_HOME/registry"
}

prompt_install_options() {
  if (( NON_INTERACTIVE == 1 )); then
    return 0
  fi

  local p
  echo ""
  echo "Install preset:"
  echo "  1) basic     — source block + PATH via ww-init.sh (simplest, no launcher)"
  echo "  2) direct    — explicit launcher at ~/.local/bin, lowest runtime overhead"
  echo "  3) multi     — bootstrap + registry, visible registered instance"
  echo "  4) hidden    — bootstrap + registry, excluded from default instance list"
  echo "  5) isolated  — launcher only, not registered (register later with: ww instance register)"
  echo "  6) hardened  — multi + mandatory security unlock"
  read -rp "Choose preset [1-6, default 1]: " p
  case "${p:-1}" in
    1) INSTALL_PRESET="basic" ;;
    2) INSTALL_PRESET="direct" ;;
    3) INSTALL_PRESET="multi" ;;
    4) INSTALL_PRESET="hidden" ;;
    5) INSTALL_PRESET="isolated" ;;
    6) INSTALL_PRESET="hardened" ;;
    *) INSTALL_PRESET="basic" ;;
  esac

  if [[ "$INSTALL_PRESET" == "multi" || "$INSTALL_PRESET" == "hidden" || "$INSTALL_PRESET" == "hardened" ]]; then
    read -rp "Enable per-instance shell aliases? [y/n]: " yn
    [[ "$yn" == "y" || "$yn" == "Y" ]] && ENABLE_INSTANCE_ALIASES=1 || ENABLE_INSTANCE_ALIASES=0
  fi

  if [[ "$INSTALL_PRESET" == "hardened" ]]; then
    echo "Security backend preference:"
    echo "  1) auto"
    echo "  2) keychain"
    echo "  3) libsecret"
    echo "  4) pass"
    read -rp "Choose backend [1-4, default 1]: " b
    case "${b:-1}" in
      2) SECURITY_BACKEND="keychain" ;;
      3) SECURITY_BACKEND="libsecret" ;;
      4) SECURITY_BACKEND="pass" ;;
      *) SECURITY_BACKEND="auto" ;;
    esac
  fi
}

handle_existing_installation() {
  if is_ww_installed; then
    local installed_version
    installed_version=$(get_installed_version)

    echo ""
    log_warning "Workwarrior is already installed (version: $installed_version)"

    if (( FORCE_INSTALL == 1 )); then
      log_info "Force flag set, proceeding with reinstall..."
      return 0
    fi

    if (( NON_INTERACTIVE == 1 )); then
      log_error "Cannot reinstall in non-interactive mode without --force"
      log_info "Run with --force to reinstall"
      exit 1
    fi

    echo ""
    read -p "Reinstall/upgrade workwarrior? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
      log_info "Installation cancelled"
      exit 0
    fi
  fi
}

copy_installation_files() {
  log_step "Copying files to $WW_INSTALL_DIR..."

  # Copy libraries
  if [[ -d "$SCRIPT_DIR/lib" ]]; then
    cp -r "$SCRIPT_DIR/lib/"* "$WW_INSTALL_DIR/lib/" 2>/dev/null || true
    log_info "Copied lib/"
  fi

  # Copy scripts
  if [[ -d "$SCRIPT_DIR/scripts" ]]; then
    cp -r "$SCRIPT_DIR/scripts/"* "$WW_INSTALL_DIR/scripts/" 2>/dev/null || true
    log_info "Copied scripts/"
  fi

  # Copy bin files
  if [[ -d "$SCRIPT_DIR/bin" ]]; then
    cp -r "$SCRIPT_DIR/bin/"* "$WW_INSTALL_DIR/bin/" 2>/dev/null || true
    chmod +x "$WW_INSTALL_DIR/bin/"* 2>/dev/null || true
    log_info "Copied bin/"
  fi

  # Copy services (preserve existing profile services)
  if [[ -d "$SCRIPT_DIR/services" ]]; then
    # Copy each service category
    for service_dir in "$SCRIPT_DIR/services/"*/; do
      if [[ -d "$service_dir" ]]; then
        local category
        category="$(basename "$service_dir")"
        mkdir -p "$WW_INSTALL_DIR/services/$category"
        cp -r "$service_dir"* "$WW_INSTALL_DIR/services/$category/" 2>/dev/null || true
      fi
    done
    log_info "Copied services/"
  fi

  # Copy resources (if exists)
  if [[ -d "$SCRIPT_DIR/resources" ]]; then
    cp -r "$SCRIPT_DIR/resources/"* "$WW_INSTALL_DIR/resources/" 2>/dev/null || true
    log_info "Copied resources/"
  fi

  # Copy config (if exists)
  if [[ -d "$SCRIPT_DIR/config" ]]; then
    cp -r "$SCRIPT_DIR/config/"* "$WW_INSTALL_DIR/config/" 2>/dev/null || true
    log_info "Copied config/"
  fi

  # Copy functions (if exists)
  if [[ -d "$SCRIPT_DIR/functions" ]]; then
    cp -r "$SCRIPT_DIR/functions/"* "$WW_INSTALL_DIR/functions/" 2>/dev/null || true
    log_info "Copied functions/"
  fi

  # Copy tools (if exists)
  if [[ -d "$SCRIPT_DIR/tools" ]]; then
    cp -r "$SCRIPT_DIR/tools/"* "$WW_INSTALL_DIR/tools/" 2>/dev/null || true
    log_info "Copied tools/"
  fi

  # Copy system docs/logs (if exists) — never overwrites profile data
  if [[ -d "$SCRIPT_DIR/system" ]]; then
    mkdir -p "$WW_INSTALL_DIR/system"
    cp -r "$SCRIPT_DIR/system/"* "$WW_INSTALL_DIR/system/" 2>/dev/null || true
    log_info "Copied system/"
  fi

  # Create version file
  echo "$WW_VERSION" > "$WW_INSTALL_DIR/VERSION"

  log_success "Files copied successfully"
}

configure_shells() {
  log_step "Configuring shell integration..."

  local rc_files
  rc_files=()
  while IFS= read -r _line; do rc_files+=("$_line"); done < <(get_shell_rc_files)

  local configured=0

  for rc_file in "${rc_files[@]}"; do
    if add_ww_to_shell_rc "$rc_file" "${COMMAND_NAME:-ww}"; then
      configured=$(( configured + 1 ))
    fi
  done

  if (( configured > 0 )); then
    log_success "Shell configuration complete"
  else
    log_warning "No shell configuration files were updated"
  fi
}

migrate_legacy_shell_blocks() {
  local rc_files
  rc_files=()
  while IFS= read -r _line; do rc_files+=("$_line"); done < <(get_shell_rc_files)
  local rc
  for rc in "${rc_files[@]}"; do
    [[ -f "$rc" ]] || continue
    if grep -Fq "Workwarrior Installation" "$rc" || grep -Fq "ww-init.sh" "$rc"; then
      local backup="${rc}.ww-migrate.$(date +%Y%m%d%H%M%S)"
      cp "$rc" "$backup" || true
      # Remove old managed block to avoid conflicting source entries.
      awk '
        $0=="# --- Workwarrior Installation ---" {skip=1; next}
        $0=="# --- End Workwarrior Installation ---" {skip=0; next}
        !skip {print}
      ' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
      log_info "Legacy shell block migrated in $(basename "$rc") (backup: $backup)"
    fi
  done
}

configure_multi_bootstrap() {
  local bootstrap_dir="${WW_CONFIG_HOME}"
  local bootstrap_file="$bootstrap_dir/bootstrap.sh"
  mkdir -p "$bootstrap_dir"

  local guard_var="WW_BOOTSTRAP_LOADED_$(printf '%s' "$COMMAND_NAME" | tr '[:lower:]' '[:upper:]')"
  guard_var="${guard_var//-/_}"

  cat > "$bootstrap_file" << EOF
#!/usr/bin/env bash
# Workwarrior multi-instance bootstrap
[[ -n "\${${guard_var}:-}" ]] && return 0
export ${guard_var}=1
export WW_CONFIG_HOME="\${WW_CONFIG_HOME:-${WW_CONFIG_HOME}}"
export WW_REGISTRY_DIR="\${WW_REGISTRY_DIR:-\$WW_CONFIG_HOME/registry}"
export WW_LAST_INSTANCE_FILE="\${WW_LAST_INSTANCE_FILE:-\$WW_CONFIG_HOME/last-instance}"

_ww_resolve_default_base() {
  local cfg_file="\${WW_CONFIG_HOME}/runtime.conf"
  local resume_last="on"
  local allow_hidden_last="off"
  if [[ -f "\$cfg_file" ]]; then
    resume_last="\$(awk -F= '/^resume_last=/{print \$2}' "\$cfg_file" | tail -1)"
    allow_hidden_last="\$(awk -F= '/^allow_hidden_last=/{print \$2}' "\$cfg_file" | tail -1)"
    [[ -z "\$resume_last" ]] && resume_last="on"
    [[ -z "\$allow_hidden_last" ]] && allow_hidden_last="off"
  fi
  if [[ -n "\${WW_ACTIVE_INSTANCE:-}" && -f "\$WW_REGISTRY_DIR/\${WW_ACTIVE_INSTANCE}.json" ]]; then
    export WW_ORCH_INSTANCE="\${WW_ACTIVE_INSTANCE}"
    python3 - "\$WW_REGISTRY_DIR/\${WW_ACTIVE_INSTANCE}.json" << 'PY'
import json,sys
print(json.load(open(sys.argv[1])).get("install_path",""))
PY
    return 0
  fi
  if [[ -n "\${WW_BASE:-}" && -x "\$WW_BASE/bin/ww" ]]; then
    [[ -z "\${WW_ORCH_INSTANCE:-}" ]] && export WW_ORCH_INSTANCE="ww"
    echo "\$WW_BASE"; return 0
  fi
  if [[ "\$resume_last" == "on" && -f "\$WW_LAST_INSTANCE_FILE" ]]; then
    local iid
    iid="\$(cat "\$WW_LAST_INSTANCE_FILE" 2>/dev/null)"
    if [[ -f "\$WW_REGISTRY_DIR/\$iid.json" ]]; then
      export WW_ORCH_INSTANCE="\$iid"
      python3 - "\$WW_REGISTRY_DIR/\$iid.json" "\$allow_hidden_last" << 'PY'
import json,sys
d=json.load(open(sys.argv[1]))
allow_hidden=sys.argv[2]=="on"
if d.get("visibility")=="hidden" and not allow_hidden:
    print("")
else:
    print(d.get("install_path",""))
PY
      return 0
    fi
  fi
  export WW_ORCH_INSTANCE="ww"
  echo "$WW_INSTALL_DIR"
}

# Look up an instance's install_path from the registry
_ww_instance_path() {
  local iid="\$1"
  python3 - "\${WW_REGISTRY_DIR}" "\$iid" << 'PY' 2>/dev/null || true
import json, glob, sys, os
reg, iid = sys.argv[1], sys.argv[2]
for f in glob.glob(os.path.join(reg, '*.json')):
    try:
        d = json.load(open(f))
        if d.get('id') == iid or d.get('name') == iid:
            print(d.get('install_path', ''))
            break
    except Exception:
        pass
PY
}

unalias ${COMMAND_NAME} 2>/dev/null || true
${COMMAND_NAME}() {
  # @instance [profile] [command...] routing
  if [[ "\${1:-}" == @* ]]; then
    local iid="\${1#@}"; shift
    local _pin="\${WW_PINNED_INSTANCE:-}"
    if [[ -n "\$_pin" && "\$_pin" != "\$iid" && "\${1:-}" != "--force" ]]; then
      echo "ww: tab is pinned to '\${_pin}'. Use 'ww unpin' first or add --force." >&2
      return 1
    fi
    [[ "\${1:-}" == "--force" ]] && shift
    local inst_base
    inst_base="\$(_ww_instance_path "\$iid")"
    if [[ -z "\$inst_base" || ! -d "\$inst_base" ]]; then
      echo "ww: instance not found: \$iid" >&2; return 1
    fi
    # Detect optional profile arg (exists as a directory in that instance)
    local profile_arg=""
    if [[ \$# -ge 1 && -d "\${inst_base}/profiles/\${1}" ]]; then
      profile_arg="\$1"; shift
    fi
    if [[ \$# -eq 0 ]]; then
      # ACTIVATE: set env vars directly in this shell
      local last_profile="\${profile_arg}"
      if [[ -z "\$last_profile" ]]; then
        last_profile="\$(cat "\${WW_CONFIG_HOME}/last-profile-\${iid}" 2>/dev/null || echo "default")"
      fi
      if [[ ! -d "\${inst_base}/profiles/\${last_profile}" ]]; then
        echo "  No profile found for '\${iid}'. Create one with:" >&2
        echo "    ${COMMAND_NAME} @\${iid} profile create <name>" >&2
        return 0
      fi
      export WW_BASE="\$inst_base"
      export WW_ACTIVE_INSTANCE="\$iid"
      export WARRIOR_PROFILE="\$last_profile"
      local _pb="\${inst_base}/profiles/\${last_profile}"
      export WORKWARRIOR_BASE="\$_pb"
      export TASKRC="\$_pb/.taskrc"
      export TASKDATA="\$_pb/.task"
      export TIMEWARRIORDB="\$_pb/.timewarrior"
      printf '%s\n' "\$last_profile" > "\${WW_CONFIG_HOME}/last-profile-\${iid}" 2>/dev/null || true
      printf '%s\n' "\$iid" > "\${WW_LAST_INSTANCE_FILE}" 2>/dev/null || true
      echo "  ✓ \${iid}:\${last_profile}  ·  \${_pb}"
      return 0
    else
      # DISPATCH: run command in instance context without switching shell
      if [[ -n "\$profile_arg" ]]; then
        local _pb="\${inst_base}/profiles/\${profile_arg}"
        env WW_BASE="\$inst_base" WW_ACTIVE_INSTANCE="\$iid" \
            WARRIOR_PROFILE="\$profile_arg" WORKWARRIOR_BASE="\$_pb" \
            TASKRC="\$_pb/.taskrc" TASKDATA="\$_pb/.task" \
            TIMEWARRIORDB="\$_pb/.timewarrior" \
            "\$inst_base/bin/ww" "\$@"
      else
        env WW_BASE="\$inst_base" WW_ACTIVE_INSTANCE="\$iid" "\$inst_base/bin/ww" "\$@"
      fi
    fi
  else
    if [[ \$# -eq 0 ]]; then
      # No args: activate last known instance (or main)
      local _last_iid
      _last_iid="\$(cat "\${WW_LAST_INSTANCE_FILE}" 2>/dev/null || echo "main")"
      if [[ -f "\${WW_REGISTRY_DIR}/\${_last_iid}.json" ]]; then
        ${COMMAND_NAME} "@\${_last_iid}"
      else
        ${COMMAND_NAME} "@main"
      fi
    else
      local base
      base="\$(_ww_resolve_default_base)"
      env WW_BASE="\$base" "\$base/bin/ww" "\$@"
    fi
  fi
}

task() {
  local base
  base="\$(_ww_resolve_default_base)"
  env WW_BASE="\$base" "\$base/bin/ww" task "\$@"
}

timew() {
  local base
  base="\$(_ww_resolve_default_base)"
  env WW_BASE="\$base" "\$base/bin/ww" timew "\$@"
}

_ww_prompt_prefix() {
  local profile="\${WARRIOR_PROFILE:-}"
  [[ -z "\$profile" ]] && return 0
  local instance="\${WW_ACTIVE_INSTANCE:-}"
  local pin_marker=""
  [[ -n "\${WW_PINNED_INSTANCE:-}" ]] && pin_marker="[pin]"
  if [[ -z "\$instance" || "\$instance" == "main" ]]; then
    printf '${COMMAND_NAME}|%s%s' "\$profile" "\$pin_marker"
  elif [[ -f "\${WW_REGISTRY_DIR}/\${instance}.json" ]]; then
    printf '${COMMAND_NAME}|%s:%s%s' "\$instance" "\$profile" "\$pin_marker"
  else
    printf '%s|%s%s' "\$instance" "\$profile" "\$pin_marker"
  fi
}

_ww_apply_prompt_prefix() {
  local pfx
  pfx="\$(_ww_prompt_prefix)"
  if [[ -n "\${ZSH_VERSION:-}" ]]; then
    if [[ -n "\$pfx" ]]; then
      [[ "\$PROMPT" == "\${pfx} "* ]] || PROMPT="\${pfx} \${PROMPT}"
    elif [[ -n "\${_WW_LAST_PREFIX:-}" ]]; then
      PROMPT="\${PROMPT#\${_WW_LAST_PREFIX} }"
    fi
  else
    if [[ -n "\$pfx" ]]; then
      [[ "\$PS1" == "\${pfx} "* ]] || PS1="\${pfx} \${PS1}"
    elif [[ -n "\${_WW_LAST_PREFIX:-}" ]]; then
      PS1="\${PS1#\${_WW_LAST_PREFIX} }"
    fi
  fi
  _WW_LAST_PREFIX="\$pfx"
}

_ww_apply_prompt_prefix
if [[ -n "\${ZSH_VERSION:-}" ]]; then
  autoload -U add-zsh-hook >/dev/null 2>&1 || true
  add-zsh-hook precmd _ww_apply_prompt_prefix >/dev/null 2>&1 || true
else
  case "\${PROMPT_COMMAND:-}" in
    *_ww_apply_prompt_prefix*) ;;
    "") PROMPT_COMMAND="_ww_apply_prompt_prefix" ;;
    *) PROMPT_COMMAND="_ww_apply_prompt_prefix; \$PROMPT_COMMAND" ;;
  esac
fi
EOF
  chmod +x "$bootstrap_file"

  local rc_files
  rc_files=()
  while IFS= read -r _line; do rc_files+=("$_line"); done < <(get_shell_rc_files)
  local rc_file
  for rc_file in "${rc_files[@]}"; do
    if ! grep -Fq "source \"$bootstrap_file\"" "$rc_file"; then
      {
        echo ""
        echo "# Workwarrior multi-instance bootstrap"
        echo "if [[ -f \"$bootstrap_file\" ]]; then"
        echo "  source \"$bootstrap_file\""
        echo "fi"
      } >> "$rc_file"
    fi

    if (( ENABLE_INSTANCE_ALIASES == 1 )); then
      if ! grep -Fq "alias main='ww main'" "$rc_file"; then
        {
          echo ""
          echo "# Workwarrior optional instance aliases"
          echo "alias main='ww main'"
        } >> "$rc_file"
      fi
    fi
  done
}

create_default_main_profile() {
  local cli="$WW_INSTALL_DIR/bin/ww"
  [[ -x "$cli" ]] || return 0
  if [[ -d "$WW_INSTALL_DIR/profiles/default" ]]; then
    return 0
  fi
  if env WW_BASE="$WW_INSTALL_DIR" "$cli" profile create default --non-interactive >/dev/null 2>&1; then
    log_success "Created default profile: default"
  else
    log_warning "Failed to auto-create default profile 'default' (can create later with: $COMMAND_NAME profile create default)"
  fi
}

ensure_launcher_path() {
  local launcher_dir="$HOME/.local/bin"
  if [[ ":$PATH:" == *":$launcher_dir:"* ]]; then
    return 0
  fi
  if (( NON_INTERACTIVE == 1 )); then
    log_warning "$launcher_dir is not in PATH. Add it manually to use '$COMMAND_NAME' in new shells."
    return 0
  fi
  read -rp "Add $launcher_dir to shell PATH in rc files? [y/n]: " yn
  if [[ "$yn" != "y" && "$yn" != "Y" ]]; then
    log_warning "Skipping PATH update. Add this line manually:"
    echo "export PATH=\"$launcher_dir:\$PATH\""
    return 0
  fi
  local rc_files
  rc_files=()
  while IFS= read -r _line; do rc_files+=("$_line"); done < <(get_shell_rc_files)
  local rc_file
  for rc_file in "${rc_files[@]}"; do
    if ! grep -Fq "export PATH=\"$launcher_dir:\$PATH\"" "$rc_file"; then
      {
        echo ""
        echo "# Workwarrior launcher path"
        echo "export PATH=\"$launcher_dir:\$PATH\""
      } >> "$rc_file"
    fi
  done
  log_success "Added $launcher_dir to shell PATH in rc files"
}

show_success_message() {
  echo ""
  echo "============================================================"
  log_success "Workwarrior installed successfully!"
  echo "============================================================"
  echo ""
  echo "Installation directory: $WW_INSTALL_DIR"
  echo "Preset: $INSTALL_PRESET"
  echo "Command launcher: $COMMAND_NAME"

  # Shortcut preview intentionally omitted here to avoid readonly WW_BASE collisions.

  echo "Next steps:"
  echo ""
  echo "  1. Reload your shell configuration:"
  echo "     source ~/.bashrc"
  if [[ -f "$HOME/.zshrc" ]]; then
    echo "     (or: source ~/.zshrc)"
  fi
  echo ""
  echo "  2. Verify installation:"
  echo "     $COMMAND_NAME version"
  echo ""
  echo "  3. Create your first profile (a 'default' profile was auto-created):"
  echo "     profile create work"
  echo ""
  echo "  4. Activate the profile:"
  echo "     p-work"
  echo ""
  echo "  5. Get help:"
  echo "     $COMMAND_NAME help"
  echo ""
  if [[ "$INSTALL_PRESET" == "basic" || "$INSTALL_PRESET" == "direct" || "$INSTALL_PRESET" == "isolated" ]]; then
    echo ""
    echo "  Note: For cross-instance routing, install a 'multi' preset anchor (recommended"
    echo "  name: 'ww') and register this instance: ww instance register $COMMAND_NAME $WW_INSTALL_DIR"
  fi
}

# ============================================================================
# MAIN INSTALLATION WORKFLOW
# ============================================================================

show_installation_overview() {
  echo ""
  echo "Installation Overview"
  echo "---------------------"
  echo ""
  echo "This installer will:"
  echo ""
  echo "  1. Check/install external tool dependencies (per-tool, with your permission)"
  echo "     • TaskWarrior  task management"
  echo "     • TimeWarrior  time tracking"
  echo "     • Hledger      plain-text accounting"
  echo "     • JRNL         journalling"
  echo "     • Bugwarrior   issue sync from GitHub/GitLab/Jira (optional)"
  echo "     • Python 3     runtime for task/timew integration hook"
  echo "     • pipx         installer for jrnl and bugwarrior"
  echo ""
  echo "     Bundled (no install needed):"
  echo "     • list         simple list manager"
  echo ""
  echo "  2. Install workwarrior to $WW_INSTALL_DIR"
  echo ""
  echo "     Code and libraries:"
  echo "     • bin/         ww command, ww-init.sh"
  echo "     • lib/         core libraries (profile, sync, shell integration, ...)"
  echo "     • scripts/     profile create/manage/backup scripts"
  echo "     • services/    service modules (tasks, journals, ledgers, issues,"
  echo "                    groups, models, github-sync, and more)"
  echo "     • functions/   function implementations (issues, journals, ledgers,"
  echo "                    tasks, times)"
  echo "     • tools/       bundled tools (list manager)"
  echo ""
  echo "     Configuration:"
  echo "     • config/      groups, models, shortcuts, extensions definitions"
  echo "     • resources/   templates and default configuration files"
  echo ""
  echo "     Data (populated when you create profiles):"
  echo "     • profiles/<name>/"
  echo "       ├── .taskrc              taskwarrior config"
  echo "       ├── .task/               task database + on-modify.timewarrior hook"
  echo "       ├── .timewarrior/        timewarrior database and config"
  echo "       ├── jrnl.yaml            journal config"
  echo "       ├── journals/            journal text files"
  echo "       ├── ledgers/             ledger journal files"
  echo "       ├── ledgers.yaml         ledger config"
  echo "       ├── .config/bugwarrior/  issue sync config"
  echo "       ├── .config/github-sync/ github sync state"
  echo "       └── list/                list manager data"
  echo ""
  echo "  3. Configure shell integration"
  echo "     • Source ww-init.sh on shell startup (adds ww to PATH, loads"
  echo "       profile functions: p-<name>, j, l, i, task, timew, ...)"
  echo "     • Files modified: ~/.bashrc and/or ~/.zshrc"
  echo ""
}

offer_dependency_installation() {
  if (( SKIP_DEPS == 1 )); then
    log_info "Skipping dependency installation (--skip-deps)"
    return 0
  fi

  if (( NON_INTERACTIVE == 1 )); then
    log_info "Non-interactive mode: checking dependencies only"
    check_all_dependencies
    display_dependency_status
    return 0
  fi

  echo ""
  echo "============================================================"
  echo "         Step 1: External Dependencies"
  echo "============================================================"
  echo ""
  echo "Workwarrior integrates with these external tools:"
  echo ""
  echo "  • TaskWarrior  - Task management"
  echo "  • TimeWarrior  - Time tracking"
  echo "  • Hledger      - Ledger accounting"
  echo "  • JRNL         - Journaling"
  echo "  • Bugwarrior   - Issue synchronization (optional)"
  echo ""
  echo "Bundled tools (included with Workwarrior):"
  echo ""
  echo "  • list         - Simple list manager"
  echo ""
  read -p "Would you like to check/install external dependencies? [y/n]: " install_deps

  if [[ "$install_deps" == "y" || "$install_deps" == "Y" ]]; then
    run_dependency_installer || log_warning "Dependency check encountered issues — run 'ww deps install' after setup to retry"
  else
    log_info "Skipping dependency installation"
    echo ""
    echo "You can install dependencies later by running:"
    echo "  ww deps install"
    echo ""
  fi
}

install_workwarrior() {
  echo ""
  echo "============================================================"
  echo "         Step 2: Install Workwarrior"
  echo "============================================================"

  # Confirm installation
  if (( NON_INTERACTIVE == 0 )); then
    echo ""
    echo "This will install workwarrior to: $WW_INSTALL_DIR"
    echo ""
    read -p "Continue? [y/n]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      log_info "Installation cancelled"
      exit 0
    fi
  fi

  # Handle existing installation
  handle_existing_installation

  # Create directory structure
  echo ""
  log_step "Creating directory structure..."
  if ! create_install_structure; then
    log_error "Failed to create directory structure"
    exit 1
  fi

  # Copy files
  copy_installation_files

  echo ""
  log_success "Workwarrior files installed"
}

configure_shell_integration() {
  echo ""
  echo "============================================================"
  echo "         Step 3: Shell Configuration"
  echo "============================================================"
  echo ""
  echo "This will add workwarrior initialization to your shell config."
  echo ""
  echo "Files to be modified:"

  local rc_files
  rc_files=()
  while IFS= read -r _line; do rc_files+=("$_line"); done < <(get_shell_rc_files)

  for rc_file in "${rc_files[@]}"; do
    echo "  • $(basename "$rc_file")"
  done

  echo ""
  echo "Changes:"
  echo "  • Source $WW_INSTALL_DIR/bin/ww-init.sh on shell startup"
  echo "  • Add $WW_INSTALL_DIR/bin to PATH"
  echo ""

  if (( NON_INTERACTIVE == 0 )); then
    read -p "Proceed with shell configuration? [y/n]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      log_warning "Skipping shell configuration"
      echo ""
      echo "To configure manually, add this to your shell config:"
      echo ""
      echo "  source \"$WW_INSTALL_DIR/bin/ww-init.sh\""
      echo ""
      return 0
    fi
  fi

  configure_shells
}

main() {
  # Bash 3.x (macOS default /bin/bash) is supported; bash 4+ recommended.
  # Process substitution < <(...) requires bash 3.x+, which all supported platforms provide.
  local _bv="${BASH_VERSINFO[0]:-0}"
  if (( _bv < 3 )); then
    echo "ERROR: Workwarrior installer requires bash 3.2 or later." >&2
    echo "Current shell: bash ${BASH_VERSION:-unknown}" >&2
    exit 1
  fi

  show_banner

  # Handle deprecated 'plain' preset
  if [[ "$INSTALL_PRESET" == "plain" ]]; then
    log_warning "'plain' preset is deprecated — using 'basic' instead"
    INSTALL_PRESET="basic"
  fi

  case "$INSTALL_PRESET" in
    basic|direct|multi|hidden|isolated|hardened) ;;
    *)
      log_error "Invalid preset: $INSTALL_PRESET"
      exit 1
      ;;
  esac
  export WW_PRESET="$INSTALL_PRESET"
  export WW_COMMAND_NAME="$COMMAND_NAME"
  export WW_SECURITY_BACKEND="$SECURITY_BACKEND"

  # Ask for install directory before showing the overview (overview uses the path)
  ask_install_dir

  prompt_install_options
  prompt_install_alias

  show_installation_overview

  if (( NON_INTERACTIVE == 0 )); then
    read -p "Begin installation? [y/n]: " begin
    if [[ "$begin" != "y" && "$begin" != "Y" ]]; then
      log_info "Installation cancelled"
      exit 0
    fi
  fi

  # Step 1: Dependencies
  offer_dependency_installation

  # Step 2: Install workwarrior
  install_workwarrior

  # Step 3: Shell integration and preset-specific setup
  migrate_legacy_shell_blocks

  # All presets: configure shell rc (WW_BASE export + source ww-init.sh)
  configure_shell_integration

  # All except basic: create launcher at ~/.local/bin/<cmd>
  if [[ "$INSTALL_PRESET" != "basic" ]]; then
    if ! create_command_launcher "$COMMAND_NAME"; then
      log_error "Failed to create command launcher '$COMMAND_NAME'"
      exit 1
    fi
    ensure_launcher_path
  fi

  # multi, hidden, hardened: bootstrap + registry
  if [[ "$INSTALL_PRESET" == "multi" || "$INSTALL_PRESET" == "hidden" || "$INSTALL_PRESET" == "hardened" ]]; then
    configure_multi_bootstrap
    local vis="visible"
    [[ "$INSTALL_PRESET" == "hidden" ]] && vis="hidden"
    write_instance_manifest "main" "$vis" "$COMMAND_NAME"
    if (( ENABLE_INSTANCE_ALIASES == 1 )); then
      WW_BASE="$WW_INSTALL_DIR" "$WW_INSTALL_DIR/bin/ww" instance aliases sync >/dev/null 2>&1 || true
    fi
  elif [[ "$INSTALL_PRESET" == "isolated" ]]; then
    log_info "Isolated preset: not registering instance (use 'ww instance register' later)"
  fi

  # basic, direct, isolated: write companion activation function
  if [[ "$INSTALL_PRESET" == "basic" || "$INSTALL_PRESET" == "direct" || "$INSTALL_PRESET" == "isolated" ]]; then
    write_instance_function "$COMMAND_NAME" "$WW_INSTALL_DIR"
  fi

  create_default_main_profile

  # Final summary
  show_success_message
}

main "$@"
