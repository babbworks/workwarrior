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

show_install_usage() {
  cat << EOF
Workwarrior Installation

Usage: ./install.sh [options]

Options:
  --non-interactive, -y    Skip all prompts, use defaults
  --force, -f              Force reinstall if already installed
  --skip-deps              Skip dependency installation
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

confirm_installation() {
  if (( NON_INTERACTIVE == 1 )); then
    return 0
  fi

  echo "This will install workwarrior to: $WW_INSTALL_DIR"
  echo ""
  read -p "Continue with installation? (yes/no): " confirm

  if [[ "$confirm" != "yes" ]]; then
    log_info "Installation cancelled"
    exit 0
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

  # Create version file
  echo "$WW_VERSION" > "$WW_INSTALL_DIR/VERSION"

  log_success "Files copied successfully"
}

configure_shells() {
  log_step "Configuring shell integration..."

  local rc_files
  mapfile -t rc_files < <(get_shell_rc_files)

  local configured=0
  for rc_file in "${rc_files[@]}"; do
    if add_ww_to_shell_rc "$rc_file"; then
      ((configured++))
    fi
  done

  if (( configured > 0 )); then
    log_success "Shell configuration complete"
  else
    log_warning "No shell configuration files were updated"
  fi
}

show_success_message() {
  echo ""
  echo "============================================================"
  log_success "Workwarrior installed successfully!"
  echo "============================================================"
  echo ""
  echo "Installation directory: $WW_INSTALL_DIR"

  # Display available shortcuts
  if [[ -f "$WW_INSTALL_DIR/lib/shortcode-registry.sh" ]]; then
    export WW_BASE="$WW_INSTALL_DIR"
    source "$WW_INSTALL_DIR/lib/shortcode-registry.sh"
    display_shortcuts_compact
  fi

  echo "Next steps:"
  echo ""
  echo "  1. Reload your shell configuration:"
  echo "     source ~/.bashrc"
  if [[ -f "$HOME/.zshrc" ]]; then
    echo "     (or: source ~/.zshrc)"
  fi
  echo ""
  echo "  2. Verify installation:"
  echo "     ww version"
  echo ""
  echo "  3. Create your first profile:"
  echo "     ww profile create work"
  echo ""
  echo "  4. Activate the profile:"
  echo "     p-work"
  echo ""
  echo "  5. Get help:"
  echo "     ww help"
  echo ""
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
    run_dependency_installer
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
  mapfile -t rc_files < <(get_shell_rc_files)

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
  show_banner

  # Ask for install directory before showing the overview (overview uses the path)
  ask_install_dir

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

  # Step 3: Shell configuration
  configure_shell_integration

  # Final summary
  show_success_message
}

main "$@"
