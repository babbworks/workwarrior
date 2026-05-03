#!/usr/bin/env bash
# Workwarrior Uninstallation Script
# Cleanly removes workwarrior CLI tool
#
# Usage:
#   ./uninstall.sh                   Remove workwarrior, keep profiles and tools
#   ./uninstall.sh --purge           Remove workwarrior + all profile data
#   ./uninstall.sh --remove-tools    Also offer to remove external tools
#   ./uninstall.sh --force           Skip confirmation prompts

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

# Allow override for testing: WW_INSTALL_DIR=/tmp/ww-test ./uninstall.sh
WW_INSTALL_DIR="${WW_INSTALL_DIR:-$HOME/ww}"

# Section markers (must match installer-utils.sh)
SECTION_WW_INSTALL="# --- Workwarrior Installation ---"
SECTION_WW_INSTALL_END="# --- End Workwarrior Installation ---"

# ============================================================================
# LOGGING (standalone - works even if libs are unavailable)
# ============================================================================

log_info()    { echo "  info  $*"; }
log_success() { echo "  ok    $*"; }
log_warning() { echo "  warn  $*"; }
log_error()   { echo "  err   $*" >&2; }
log_step()    { echo ""; echo ">> $*"; }

# Try to source installer utils for richer logging/helpers
if [[ -f "$WW_INSTALL_DIR/lib/installer-utils.sh" ]]; then
  source "$WW_INSTALL_DIR/lib/installer-utils.sh" 2>/dev/null || true
fi

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

FORCE_UNINSTALL=0
REMOVE_DATA=0
REMOVE_TOOLS=0

show_uninstall_usage() {
  cat << EOF
Workwarrior Uninstallation

Usage: ./uninstall.sh [options]

Options:
  --force, -f       Skip confirmation prompts
  --purge           Remove everything including profiles and task data
  --remove-tools    Interactively offer to uninstall external tools
                    (task, timew, hledger, jrnl, bugwarrior)
  --help, -h        Show this help message

By default:
  • Workwarrior code is removed from $WW_INSTALL_DIR
  • Profiles (task databases, journals, ledgers) are preserved
  • External tools (task, timew, etc.) are left installed
  • Modified tool configs (~/.taskrc, jrnl.yaml) are restored from backup

Examples:
  ./uninstall.sh                   Remove ww, keep profiles + tools
  ./uninstall.sh --purge           Remove ww + all profile data
  ./uninstall.sh --remove-tools    Remove ww and offer to remove tools
  ./uninstall.sh --purge --remove-tools --force   Full clean wipe

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|-f)       FORCE_UNINSTALL=1; shift ;;
    --purge|--remove-data) REMOVE_DATA=1; shift ;;
    --remove-tools)   REMOVE_TOOLS=1; shift ;;
    --help|-h)        show_uninstall_usage; exit 0 ;;
    *)
      log_error "Unknown option: $1"
      show_uninstall_usage
      exit 1
      ;;
  esac
done

# ============================================================================
# TOOL DETECTION (standalone, no dependency on libs)
# ============================================================================

detect_pm() {
  if   command -v brew   &>/dev/null; then echo "brew"
  elif command -v apt    &>/dev/null; then echo "apt"
  elif command -v dnf    &>/dev/null; then echo "dnf"
  elif command -v pacman &>/dev/null; then echo "pacman"
  else echo "unknown"
  fi
}

tool_version() {
  local tool="$1"
  if ! command -v "$tool" &>/dev/null; then
    echo "not_installed"
    return
  fi
  case "$tool" in
    task)       task --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 ;;
    timew)      timew --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 ;;
    hledger)    hledger --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 ;;
    jrnl)       jrnl --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 ;;
    bugwarrior) bugwarrior --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 ;;
    *)          echo "unknown" ;;
  esac
}

get_tool_uninstall_cmd() {
  local tool="$1" pm="$2"
  case "$pm" in
    brew)
      case "$tool" in
        task)       echo "brew uninstall task" ;;
        timew)      echo "brew uninstall timewarrior" ;;
        hledger)    echo "brew uninstall hledger" ;;
        jrnl)       echo "pipx uninstall jrnl" ;;
        bugwarrior) echo "pipx uninstall bugwarrior" ;;
      esac ;;
    apt)
      case "$tool" in
        task)       echo "sudo apt remove taskwarrior" ;;
        timew)      echo "sudo apt remove timewarrior" ;;
        hledger)    echo "sudo apt remove hledger" ;;
        jrnl)       echo "pipx uninstall jrnl" ;;
        bugwarrior) echo "pipx uninstall bugwarrior" ;;
      esac ;;
    dnf)
      case "$tool" in
        task)       echo "sudo dnf remove task" ;;
        timew)      echo "sudo dnf remove timew" ;;
        hledger)    echo "sudo dnf remove hledger" ;;
        jrnl)       echo "pipx uninstall jrnl" ;;
        bugwarrior) echo "pipx uninstall bugwarrior" ;;
      esac ;;
    pacman)
      case "$tool" in
        task)       echo "sudo pacman -R task" ;;
        timew)      echo "sudo pacman -R timew" ;;
        hledger)    echo "sudo pacman -R hledger" ;;
        jrnl)       echo "pipx uninstall jrnl" ;;
        bugwarrior) echo "pipx uninstall bugwarrior" ;;
      esac ;;
    *)
      echo "# manual uninstall required for $tool" ;;
  esac
}

# ============================================================================
# UNINSTALLATION FUNCTIONS
# ============================================================================

confirm_uninstall() {
  if (( FORCE_UNINSTALL == 1 )); then return 0; fi

  echo ""
  log_warning "This will remove Workwarrior from $WW_INSTALL_DIR"
  echo ""

  if (( REMOVE_DATA == 1 )); then
    log_warning "WARNING: --purge is set — all profile data will be deleted"
    echo ""
  else
    log_info "Profile data in $WW_INSTALL_DIR/profiles will be preserved"
    echo ""
  fi

  if (( REMOVE_TOOLS == 1 )); then
    log_info "--remove-tools is set — you will be asked about each external tool"
    echo ""
  fi

  read -rp "Continue with uninstallation? (yes/no): " confirm
  if [[ "$confirm" != "yes" ]]; then
    log_info "Uninstallation cancelled"
    exit 0
  fi
}

restore_tool_configs() {
  log_step "Restoring tool configurations modified during install..."

  # Restore ~/.taskrc from most recent ww backup
  local latest_taskrc
  latest_taskrc=$(ls -t "$HOME/.taskrc.pre-ww-"* 2>/dev/null | head -1)
  if [[ -n "$latest_taskrc" ]]; then
    cp "$latest_taskrc" "$HOME/.taskrc"
    log_success "Restored ~/.taskrc from $(basename "$latest_taskrc")"
  elif [[ -f "$HOME/.taskrc" ]] && grep -q "Workwarrior-managed" "$HOME/.taskrc" 2>/dev/null; then
    rm "$HOME/.taskrc"
    log_info "Removed ww sentinel ~/.taskrc (no pre-ww backup found)"
  else
    log_info "~/.taskrc — no changes needed"
  fi

  # Restore ~/.config/jrnl/jrnl.yaml from most recent ww backup
  local jrnl_cfg="$HOME/.config/jrnl/jrnl.yaml"
  local latest_jrnl
  latest_jrnl=$(ls -t "${jrnl_cfg}.pre-ww-"* 2>/dev/null | head -1)
  if [[ -n "$latest_jrnl" ]]; then
    cp "$latest_jrnl" "$jrnl_cfg"
    log_success "Restored jrnl config from $(basename "$latest_jrnl")"
  else
    log_info "~/.config/jrnl/jrnl.yaml — no pre-ww backup found, leaving as-is"
  fi

  # Restore bugwarrior config if backed up
  local bw_cfg="$HOME/.config/bugwarrior/bugwarrior.cfg"
  local latest_bw
  latest_bw=$(ls -t "${bw_cfg}.pre-ww-"* 2>/dev/null | head -1)
  if [[ -n "$latest_bw" ]]; then
    cp "$latest_bw" "$bw_cfg"
    log_success "Restored bugwarrior config from $(basename "$latest_bw")"
  fi
}

remove_shell_config() {
  log_step "Removing shell configuration..."

  local rc_files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile")

  for rc_file in "${rc_files[@]}"; do
    [[ ! -f "$rc_file" ]] && continue

    if ! grep -Fq "$SECTION_WW_INSTALL" "$rc_file"; then
      log_info "No ww config in $(basename "$rc_file") — skipping"
      continue
    fi

    local backup="$rc_file.ww-uninstall-backup.$(date +%Y%m%d%H%M%S)"
    cp "$rc_file" "$backup"

    awk -v start="$SECTION_WW_INSTALL" -v end="$SECTION_WW_INSTALL_END" '
      $0 == start { skip=1; next }
      $0 == end   { skip=0; next }
      !skip        { print }
    ' "$rc_file" > "$rc_file.tmp"

    mv "$rc_file.tmp" "$rc_file"
    log_success "Removed ww block from $(basename "$rc_file")  (backup: $(basename "$backup"))"
  done
}

remove_installation() {
  log_step "Removing installation files..."

  if [[ ! -d "$WW_INSTALL_DIR" ]]; then
    log_warning "Installation directory not found: $WW_INSTALL_DIR"
    return 0
  fi

  if (( REMOVE_DATA == 1 )); then
    rm -rf "$WW_INSTALL_DIR"
    log_success "Removed $WW_INSTALL_DIR (including all profile data)"
    return 0
  fi

  # Preserve profiles directory
  local profiles_dir="$WW_INSTALL_DIR/profiles"

  if [[ -d "$profiles_dir" ]] && [[ -n "$(ls -A "$profiles_dir" 2>/dev/null)" ]]; then
    local temp_profiles="/tmp/ww-profiles-backup-$$"
    mv "$profiles_dir" "$temp_profiles"
    rm -rf "$WW_INSTALL_DIR"
    mkdir -p "$WW_INSTALL_DIR"
    mv "$temp_profiles" "$profiles_dir"
    log_success "Removed workwarrior code"
    log_info "Profiles preserved at: $profiles_dir"
  else
    rm -rf "$WW_INSTALL_DIR"
    log_success "Removed $WW_INSTALL_DIR"
  fi
}

remove_external_tools() {
  log_step "External tool removal (optional)..."

  local pm
  pm=$(detect_pm)

  if [[ "$pm" == "unknown" ]]; then
    log_warning "No supported package manager found — cannot auto-remove tools"
    log_info "Remove task, timew, hledger, jrnl, bugwarrior manually if desired"
    return 0
  fi

  local tools=("task" "timew" "hledger" "jrnl" "bugwarrior")
  local tool_labels=("TaskWarrior" "TimeWarrior" "Hledger" "JRNL" "Bugwarrior")

  echo ""
  echo "  The following tools were used by Workwarrior."
  echo "  They are independent programs and can be kept or removed."
  echo ""

  for i in "${!tools[@]}"; do
    local tool="${tools[$i]}"
    local label="${tool_labels[$i]}"
    local version
    version=$(tool_version "$tool")

    if [[ "$version" == "not_installed" ]]; then
      printf "  –  %-14s not installed — skipping\n" "$label"
      continue
    fi

    local cmd
    cmd=$(get_tool_uninstall_cmd "$tool" "$pm")

    echo ""
    printf "  %-14s %s\n" "$label" "$version"
    echo "    Uninstall: $cmd"
    read -rp "    Remove $label? [y/n] : " choice
    case "$choice" in
      y|Y)
        if eval "$cmd"; then
          log_success "$label removed"
        else
          log_warning "Failed to remove $label — try manually: $cmd"
        fi
        ;;
      *) log_info "Keeping $label" ;;
    esac
  done
}

show_success_message() {
  echo ""
  echo "============================================================"
  log_success "Workwarrior has been uninstalled"
  echo "============================================================"
  echo ""
  echo "  Reload your shell to clear ww functions and aliases:"
  echo "    source ~/.bashrc   (or source ~/.zshrc)"
  echo ""

  if (( REMOVE_DATA == 0 )) && [[ -d "$WW_INSTALL_DIR/profiles" ]]; then
    echo "  Your profiles are preserved at:"
    echo "    $WW_INSTALL_DIR/profiles"
    echo ""
    echo "  To reinstall Workwarrior later, your profiles will be intact."
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

  if [[ ! -d "$WW_INSTALL_DIR" ]]; then
    log_info "Workwarrior does not appear to be installed at $WW_INSTALL_DIR"
    exit 0
  fi

  confirm_uninstall

  # Always restore configs modified during install
  restore_tool_configs

  # Remove shell rc entries
  remove_shell_config

  # Optionally remove external tools before removing ww files (libs still available)
  if (( REMOVE_TOOLS == 1 )); then
    remove_external_tools
  fi

  # Remove ww installation files
  remove_installation

  show_success_message
}

main "$@"
