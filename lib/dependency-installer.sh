#!/usr/bin/env bash
# Dependency Installer Library
# Handles detection, version checking, and installation of external tools
# Source this file: source "$(dirname "$0")/lib/dependency-installer.sh"

# Source core utilities if not already loaded
if [[ -z "$CORE_UTILS_LOADED" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$SCRIPT_DIR/core-utils.sh"
fi

# ============================================================================
# MINIMUM VERSION REQUIREMENTS
# These are versions we've tested with and recommend
# ============================================================================

readonly MIN_VERSION_TASK="2.6.0"
readonly MIN_VERSION_TIMEW="1.4.0"
readonly MIN_VERSION_HLEDGER="1.30"
readonly MIN_VERSION_JRNL="4.0"
readonly MIN_VERSION_PYTHON="3.9"
readonly MIN_VERSION_BUGWARRIOR="1.8.0"

# ============================================================================
# ONLINE VERSION CHECK ENDPOINTS
# Listed explicitly for user transparency
# ============================================================================

readonly ENDPOINT_BREW_TASK="https://formulae.brew.sh/api/formula/task.json"
readonly ENDPOINT_BREW_TIMEW="https://formulae.brew.sh/api/formula/timewarrior.json"
readonly ENDPOINT_BREW_HLEDGER="https://formulae.brew.sh/api/formula/hledger.json"
readonly ENDPOINT_GITHUB_TASK="https://api.github.com/repos/GothenburgBitFactory/taskwarrior/releases/latest"
readonly ENDPOINT_GITHUB_TIMEW="https://api.github.com/repos/GothenburgBitFactory/timewarrior/releases/latest"
readonly ENDPOINT_GITHUB_HLEDGER="https://api.github.com/repos/simonmichael/hledger/releases/latest"
readonly ENDPOINT_PYPI_JRNL="https://pypi.org/pypi/jrnl/json"

# ============================================================================
# PACKAGE MANAGER DETECTION
# ============================================================================

# Detect available package manager
# Returns: brew, apt, dnf, pacman, or unknown
detect_package_manager() {
  if command -v brew &>/dev/null; then
    echo "brew"
  elif command -v apt &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v pacman &>/dev/null; then
    echo "pacman"
  else
    echo "unknown"
  fi
}

# Get display name for package manager
get_package_manager_name() {
  local pm="$1"
  case "$pm" in
    brew)   echo "Homebrew" ;;
    apt)    echo "APT (Debian/Ubuntu)" ;;
    dnf)    echo "DNF (Fedora/RHEL)" ;;
    pacman) echo "Pacman (Arch)" ;;
    *)      echo "Unknown" ;;
  esac
}

# ============================================================================
# VERSION EXTRACTION
# ============================================================================

# Extract version number from command output
# Handles various version string formats
extract_version() {
  local version_string="$1"
  # Extract first version-like pattern (X.Y.Z or X.Y)
  echo "$version_string" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# Get installed version of a tool
# Usage: get_installed_version "tool-name"
# Returns: version string or "not_installed"
get_tool_version() {
  local tool="$1"
  local version_output

  case "$tool" in
    task)
      if command -v task &>/dev/null; then
        version_output=$(task --version 2>/dev/null)
        extract_version "$version_output"
      else
        echo "not_installed"
      fi
      ;;
    timew)
      if command -v timew &>/dev/null; then
        version_output=$(timew --version 2>/dev/null)
        extract_version "$version_output"
      else
        echo "not_installed"
      fi
      ;;
    hledger)
      if command -v hledger &>/dev/null; then
        version_output=$(hledger --version 2>/dev/null)
        extract_version "$version_output"
      else
        echo "not_installed"
      fi
      ;;
    jrnl)
      if command -v jrnl &>/dev/null; then
        version_output=$(jrnl --version 2>/dev/null)
        extract_version "$version_output"
      else
        echo "not_installed"
      fi
      ;;
    bugwarrior)
      if command -v bugwarrior &>/dev/null; then
        version_output=$(bugwarrior --version 2>/dev/null)
        extract_version "$version_output"
      else
        echo "not_installed"
      fi
      ;;
    python3)
      if command -v python3 &>/dev/null; then
        version_output=$(python3 --version 2>/dev/null)
        extract_version "$version_output"
      else
        echo "not_installed"
      fi
      ;;
    pipx)
      if command -v pipx &>/dev/null; then
        version_output=$(pipx --version 2>/dev/null)
        extract_version "$version_output"
      else
        echo "not_installed"
      fi
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# ============================================================================
# VERSION COMPARISON
# ============================================================================

# Compare two version strings
# Returns: 0 if v1 >= v2, 1 if v1 < v2
version_gte() {
  local v1="$1"
  local v2="$2"

  # Handle not_installed case
  if [[ "$v1" == "not_installed" ]]; then
    return 1
  fi

  # Use sort -V for version comparison
  local lowest
  lowest=$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | head -1)

  if [[ "$lowest" == "$v2" ]]; then
    return 0  # v1 >= v2
  else
    return 1  # v1 < v2
  fi
}

# ============================================================================
# DEPENDENCY STATUS CHECK
# ============================================================================

# Check all dependencies and their versions
# Populates global arrays with status
declare -a DEP_NAMES=()
declare -a DEP_INSTALLED_VERSIONS=()
declare -a DEP_MIN_VERSIONS=()
declare -a DEP_STATUS=()  # ok, update, missing

check_all_dependencies() {
  DEP_NAMES=("TaskWarrior" "TimeWarrior" "Hledger" "JRNL" "Bugwarrior" "Python 3" "pipx")
  local tools=("task" "timew" "hledger" "jrnl" "bugwarrior" "python3" "pipx")
  local mins=("$MIN_VERSION_TASK" "$MIN_VERSION_TIMEW" "$MIN_VERSION_HLEDGER" "$MIN_VERSION_JRNL" "$MIN_VERSION_BUGWARRIOR" "$MIN_VERSION_PYTHON" "1.0")

  DEP_INSTALLED_VERSIONS=()
  DEP_MIN_VERSIONS=()
  DEP_STATUS=()

  for i in "${!tools[@]}"; do
    local tool="${tools[$i]}"
    local min="${mins[$i]}"
    local installed

    installed=$(get_tool_version "$tool")
    DEP_INSTALLED_VERSIONS+=("$installed")
    DEP_MIN_VERSIONS+=("$min")

    if [[ "$installed" == "not_installed" ]]; then
      DEP_STATUS+=("missing")
    elif version_gte "$installed" "$min"; then
      DEP_STATUS+=("ok")
    else
      DEP_STATUS+=("update")
    fi
  done
}

# Display dependency status table
display_dependency_status() {
  echo ""
  echo "Checking installed tools..."
  echo ""
  printf "  %-14s %-12s %-14s %s\n" "Tool" "Installed" "Minimum" "Status"
  printf "  %-14s %-12s %-14s %s\n" "----" "---------" "-------" "------"

  for i in "${!DEP_NAMES[@]}"; do
    local name="${DEP_NAMES[$i]}"
    local installed="${DEP_INSTALLED_VERSIONS[$i]}"
    local min="${DEP_MIN_VERSIONS[$i]}"
    local status="${DEP_STATUS[$i]}"

    local status_display
    case "$status" in
      ok)      status_display="ok" ;;
      update)  status_display="⚠ update recommended" ;;
      missing) status_display="✗ not installed" ;;
    esac

    local version_display="$installed"
    if [[ "$installed" == "not_installed" ]]; then
      version_display="—"
    fi

    printf "  %-14s %-12s %-14s %s\n" "$name" "$version_display" "$min" "$status_display"
  done
  echo ""
}

# ============================================================================
# ONLINE VERSION CHECK
# ============================================================================

# Show endpoints that will be contacted
show_online_check_endpoints() {
  local pm="$1"

  echo ""
  echo "This will connect to:"
  if [[ "$pm" == "brew" ]]; then
    echo "  • formulae.brew.sh/api/formula/task.json"
    echo "  • formulae.brew.sh/api/formula/timewarrior.json"
    echo "  • formulae.brew.sh/api/formula/hledger.json"
  else
    echo "  • api.github.com/repos/GothenburgBitFactory/taskwarrior/releases/latest"
    echo "  • api.github.com/repos/GothenburgBitFactory/timewarrior/releases/latest"
    echo "  • api.github.com/repos/simonmichael/hledger/releases/latest"
  fi
  echo "  • pypi.org/pypi/jrnl/json"
  echo ""
}

# Fetch latest version from Homebrew API
fetch_brew_version() {
  local formula="$1"
  local url="https://formulae.brew.sh/api/formula/${formula}.json"
  local response

  response=$(curl -s --max-time 10 "$url" 2>/dev/null)
  if [[ -n "$response" ]]; then
    echo "$response" | grep -o '"stable":"[^"]*"' | head -1 | cut -d'"' -f4
  fi
}

# Fetch latest version from GitHub releases
fetch_github_version() {
  local repo="$1"
  local url="https://api.github.com/repos/${repo}/releases/latest"
  local response

  response=$(curl -s --max-time 10 "$url" 2>/dev/null)
  if [[ -n "$response" ]]; then
    echo "$response" | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//'
  fi
}

# Fetch latest version from PyPI
fetch_pypi_version() {
  local package="$1"
  local url="https://pypi.org/pypi/${package}/json"
  local response

  response=$(curl -s --max-time 10 "$url" 2>/dev/null)
  if [[ -n "$response" ]]; then
    echo "$response" | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4
  fi
}

# Perform online version check
# Returns results in LATEST_VERSIONS array
declare -a LATEST_VERSIONS=()

fetch_latest_versions() {
  local pm="$1"
  LATEST_VERSIONS=()

  echo "Fetching latest versions..."
  echo ""

  # TaskWarrior
  if [[ "$pm" == "brew" ]]; then
    LATEST_VERSIONS+=("$(fetch_brew_version "task")")
  else
    LATEST_VERSIONS+=("$(fetch_github_version "GothenburgBitFactory/taskwarrior")")
  fi

  # TimeWarrior
  if [[ "$pm" == "brew" ]]; then
    LATEST_VERSIONS+=("$(fetch_brew_version "timewarrior")")
  else
    LATEST_VERSIONS+=("$(fetch_github_version "GothenburgBitFactory/timewarrior")")
  fi

  # Hledger
  if [[ "$pm" == "brew" ]]; then
    LATEST_VERSIONS+=("$(fetch_brew_version "hledger")")
  else
    LATEST_VERSIONS+=("$(fetch_github_version "simonmichael/hledger")")
  fi

  # JRNL (always PyPI)
  LATEST_VERSIONS+=("$(fetch_pypi_version "jrnl")")

  # Bugwarrior (always PyPI)
  LATEST_VERSIONS+=("$(fetch_pypi_version "bugwarrior")")

  # Python (skip - system managed)
  LATEST_VERSIONS+=("—")

  # pipx (skip)
  LATEST_VERSIONS+=("—")
}

# Display latest versions comparison
display_latest_versions() {
  printf "  %-14s %-12s %-12s %s\n" "Tool" "Installed" "Latest" "Status"
  printf "  %-14s %-12s %-12s %s\n" "----" "---------" "------" "------"

  for i in "${!DEP_NAMES[@]}"; do
    local name="${DEP_NAMES[$i]}"
    local installed="${DEP_INSTALLED_VERSIONS[$i]}"
    local latest="${LATEST_VERSIONS[$i]}"

    local installed_display="$installed"
    if [[ "$installed" == "not_installed" ]]; then
      installed_display="—"
    fi

    local status=""
    if [[ "$installed" != "not_installed" ]] && [[ -n "$latest" ]] && [[ "$latest" != "—" ]]; then
      if [[ "$installed" != "$latest" ]]; then
        status="→ upgrade available"
      else
        status="✓ latest"
      fi
    fi

    printf "  %-14s %-12s %-12s %s\n" "$name" "$installed_display" "${latest:-?}" "$status"
  done
  echo ""
}

# ============================================================================
# INSTALLATION COMMANDS
# ============================================================================

# Get install command for a tool
get_install_command() {
  local tool="$1"
  local pm="$2"

  case "$pm" in
    brew)
      case "$tool" in
        task)       echo "brew install task" ;;
        timew)      echo "brew install timewarrior" ;;
        hledger)    echo "brew install hledger" ;;
        jrnl)       echo "pipx install jrnl" ;;
        bugwarrior) echo "pipx install bugwarrior && pipx inject bugwarrior setuptools" ;;
        python3)    echo "brew install python3" ;;
        pipx)       echo "brew install pipx" ;;
      esac
      ;;
    apt)
      case "$tool" in
        task)       echo "sudo apt install taskwarrior" ;;
        timew)      echo "sudo apt install timewarrior" ;;
        hledger)    echo "sudo apt install hledger" ;;
        jrnl)       echo "pipx install jrnl" ;;
        bugwarrior) echo "pipx install bugwarrior && pipx inject bugwarrior setuptools" ;;
        python3)    echo "sudo apt install python3 python3-pip" ;;
        pipx)       echo "sudo apt install pipx" ;;
      esac
      ;;
    dnf)
      case "$tool" in
        task)       echo "sudo dnf install task" ;;
        timew)      echo "sudo dnf install timew" ;;
        hledger)    echo "sudo dnf install hledger" ;;
        jrnl)       echo "pipx install jrnl" ;;
        bugwarrior) echo "pipx install bugwarrior && pipx inject bugwarrior setuptools" ;;
        python3)    echo "sudo dnf install python3 python3-pip" ;;
        pipx)       echo "sudo dnf install pipx" ;;
      esac
      ;;
    pacman)
      case "$tool" in
        task)       echo "sudo pacman -S task" ;;
        timew)      echo "sudo pacman -S timew" ;;
        hledger)    echo "sudo pacman -S hledger" ;;
        jrnl)       echo "pipx install jrnl" ;;
        bugwarrior) echo "pipx install bugwarrior && pipx inject bugwarrior setuptools" ;;
        python3)    echo "sudo pacman -S python python-pip" ;;
        pipx)       echo "sudo pacman -S python-pipx" ;;
      esac
      ;;
    *)
      echo "# Manual installation required for $tool"
      ;;
  esac
}

# Get upgrade command for a tool
get_upgrade_command() {
  local tool="$1"
  local pm="$2"

  case "$pm" in
    brew)
      case "$tool" in
        task)    echo "brew upgrade task" ;;
        timew)   echo "brew upgrade timewarrior" ;;
        hledger) echo "brew upgrade hledger" ;;
        jrnl)    echo "pipx upgrade jrnl" ;;
        python3) echo "brew upgrade python3" ;;
        pipx)    echo "brew upgrade pipx" ;;
      esac
      ;;
    apt)
      case "$tool" in
        task)    echo "sudo apt upgrade taskwarrior" ;;
        timew)   echo "sudo apt upgrade timewarrior" ;;
        hledger) echo "sudo apt upgrade hledger" ;;
        jrnl)    echo "pipx upgrade jrnl" ;;
        python3) echo "sudo apt upgrade python3" ;;
        pipx)    echo "sudo apt upgrade pipx" ;;
      esac
      ;;
    dnf)
      case "$tool" in
        task)    echo "sudo dnf upgrade task" ;;
        timew)   echo "sudo dnf upgrade timew" ;;
        hledger) echo "sudo dnf upgrade hledger" ;;
        jrnl)    echo "pipx upgrade jrnl" ;;
        python3) echo "sudo dnf upgrade python3" ;;
        pipx)    echo "sudo dnf upgrade pipx" ;;
      esac
      ;;
    pacman)
      case "$tool" in
        task)    echo "sudo pacman -Syu task" ;;
        timew)   echo "sudo pacman -Syu timew" ;;
        hledger) echo "sudo pacman -Syu hledger" ;;
        jrnl)    echo "pipx upgrade jrnl" ;;
        python3) echo "sudo pacman -Syu python" ;;
        pipx)    echo "sudo pacman -Syu python-pipx" ;;
      esac
      ;;
  esac
}

# ============================================================================
# INSTALLATION EXECUTION
# ============================================================================

# Execute an installation command with explanation
execute_install() {
  local tool="$1"
  local cmd="$2"
  local description="$3"

  echo ""
  echo "┌─────────────────────────────────────────────────────────────"
  echo "│ Installing: $description"
  echo "│ Command:    $cmd"
  echo "└─────────────────────────────────────────────────────────────"
  echo ""

  # Execute the command
  if eval "$cmd"; then
    log_success "$description installed successfully"
    return 0
  else
    log_error "Failed to install $description"
    return 1
  fi
}

# ============================================================================
# JRNL FIRST-RUN GUIDANCE
# ============================================================================

show_jrnl_setup_guide() {
  echo ""
  echo "┌─────────────────────────────────────────────────────────────"
  echo "│ JRNL First-Run Setup"
  echo "└─────────────────────────────────────────────────────────────"
  echo ""
  echo "JRNL will ask you some questions on first run:"
  echo ""
  echo "  1. Journal location"
  echo "     → You can accept the default or specify a path"
  echo "     → Workwarrior will use its own config per profile"
  echo ""
  echo "  2. Encryption"
  echo "     → Choose 'n' for no encryption (recommended for testing)"
  echo "     → You can enable encryption later per profile"
  echo ""
  echo "  3. Colors"
  echo "     → Choose 'y' for colored output"
  echo ""
  echo "Note: Workwarrior creates separate journal configs for each"
  echo "profile, so these defaults are just for the global jrnl command."
  echo ""
}

# ============================================================================
# PATH CONFIGURATION
# ============================================================================

check_local_bin_in_path() {
  if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    return 0
  else
    return 1
  fi
}

show_path_configuration() {
  echo ""
  echo "┌─────────────────────────────────────────────────────────────"
  echo "│ PATH Configuration"
  echo "└─────────────────────────────────────────────────────────────"
  echo ""
  echo "pipx installs tools to ~/.local/bin/"
  echo ""
  echo "This directory is not currently in your PATH."
  echo ""
  echo "To add it, the following line will be added to your shell config:"
  echo ""
  echo '  export PATH="$HOME/.local/bin:$PATH"'
  echo ""
}

add_local_bin_to_path() {
  local rc_file="$1"
  local marker="# --- pipx PATH (added by workwarrior) ---"

  if grep -Fq "$marker" "$rc_file" 2>/dev/null; then
    log_info "PATH already configured in $(basename "$rc_file")"
    return 0
  fi

  cat >> "$rc_file" << 'EOF'

# --- pipx PATH (added by workwarrior) ---
export PATH="$HOME/.local/bin:$PATH"
EOF

  log_success "Added ~/.local/bin to PATH in $(basename "$rc_file")"
  return 0
}

# ============================================================================
# TOOL METADATA
# ============================================================================

# One-line description of each tool's role in workwarrior
get_tool_description() {
  case "$1" in
    task)       echo "Task management — the core engine powering all ww task operations" ;;
    timew)      echo "Time tracking — starts/stops automatically when tasks are started/stopped" ;;
    hledger)    echo "Plain-text accounting — per-profile ledger tracking" ;;
    jrnl)       echo "Encrypted journalling — per-profile named journals" ;;
    bugwarrior) echo "Issue sync — pulls GitHub/GitLab/Jira issues into TaskWarrior (optional)" ;;
    python3)    echo "Python runtime — required for the TaskWarrior/TimeWarrior integration hook" ;;
    pipx)       echo "Python app installer — required to safely install jrnl and bugwarrior" ;;
    *)          echo "Unknown tool" ;;
  esac
}

# Files each tool creates by default on first run
get_tool_default_files() {
  case "$1" in
    task)
      echo "  ~/.taskrc                  global task configuration"
      echo "  ~/.task/                   global task database (SQLite)"
      echo "  ~/.task/hooks/             global hook scripts directory"
      ;;
    timew)
      echo "  ~/.timewarrior/            global timewarrior config and database"
      echo "  ~/.timewarrior/timewarrior.cfg"
      ;;
    hledger)
      echo "  ~/.hledger.journal         default journal (used only by bare 'hledger' command)"
      ;;
    jrnl)
      echo "  ~/.config/jrnl/jrnl.yaml   global journal list and preferences"
      echo "  ~/.local/share/jrnl/       default journal storage"
      ;;
    bugwarrior)
      echo "  ~/.config/bugwarrior/bugwarrior.cfg   global sync configuration"
      ;;
    python3)
      echo "  (system-managed runtime, no user-facing config files)"
      ;;
    pipx)
      echo "  ~/.local/bin/              installed tool binaries"
      echo "  ~/.local/share/pipx/       isolated Python environments"
      ;;
  esac
}

# How workwarrior manages each tool's integration
get_tool_ww_integration() {
  case "$1" in
    task)
      echo "  TASKRC env var        → redirects config to active profile's .taskrc"
      echo "  TASKDATA env var      → redirects database to active profile's .task/"
      echo "  ~/.taskrc             → backed up + replaced with a ww sentinel"
      echo "  on-modify.timewarrior → hook installed in each profile's .task/hooks/"
      ;;
    timew)
      echo "  TIMEWARRIORDB env var → redirects to active profile's .timewarrior/"
      echo "  ~/.timewarrior/       → left in place; ignored while a profile is active"
      ;;
    hledger)
      echo "  -f <ledger-file>      → passed explicitly by 'l' function per profile"
      echo "  ~/.hledger.journal    → ignored during profile use (ww always passes -f)"
      ;;
    jrnl)
      echo "  --config-file flag    → passed by 'j' function with per-profile jrnl.yaml"
      echo "  ~/.config/jrnl/jrnl.yaml → backed up + stripped to default journal only"
      ;;
    bugwarrior)
      echo "  BUGWARRIORRC env var  → redirects to active profile's bugwarriorrc"
      echo "  'i pull' / 'ww issues pull' → triggers sync for the active profile"
      ;;
    python3)
      echo "  Required runtime for on-modify.timewarrior hook (Python 3 script)"
      ;;
    pipx)
      echo "  Installs jrnl and bugwarrior into isolated environments"
      echo "  Binaries land in ~/.local/bin/ — ensure this is in your PATH"
      ;;
  esac
}

# ============================================================================
# PER-TOOL INSTALL CARD
# ============================================================================

show_tool_card() {
  local tool="$1"
  local pm="$2"
  local installed_version="$3"
  local latest_version="${4:-unavailable}"
  local min_version="$5"

  local display_name
  case "$tool" in
    task)       display_name="TaskWarrior" ;;
    timew)      display_name="TimeWarrior" ;;
    hledger)    display_name="Hledger" ;;
    jrnl)       display_name="JRNL" ;;
    bugwarrior) display_name="Bugwarrior" ;;
    python3)    display_name="Python 3" ;;
    pipx)       display_name="pipx" ;;
    *)          display_name="$tool" ;;
  esac

  local pm_name
  pm_name=$(get_package_manager_name "$pm")
  local install_cmd
  install_cmd=$(get_install_command "$tool" "$pm")

  echo ""
  echo "┌─────────────────────────────────────────────────────────────"
  printf "│  %-20s %s\n" "$display_name" "$(get_tool_description "$tool")"
  echo "├─────────────────────────────────────────────────────────────"
  echo "│  Versions"
  if [[ "$installed_version" == "not_installed" ]]; then
    printf "│    %-22s %s\n" "Installed:" "not installed"
  else
    printf "│    %-22s %s\n" "Installed:" "$installed_version"
  fi
  if [[ -z "$latest_version" || "$latest_version" == "—" ]]; then
    printf "│    %-22s %s\n" "Latest available:" "unavailable (offline?)"
  else
    printf "│    %-22s %s\n" "Latest available:" "$latest_version"
  fi
  printf "│    %-22s %s\n" "WW supported minimum:" "$min_version"
  echo "│"
  printf "│  Install via %s:\n" "$pm_name"
  echo "│    $install_cmd"
  echo "│"
  echo "│  Default files this tool creates:"
  while IFS= read -r line; do
    echo "│ $line"
  done < <(get_tool_default_files "$tool")
  echo "│"
  echo "│  Workwarrior integration:"
  while IFS= read -r line; do
    echo "│ $line"
  done < <(get_tool_ww_integration "$tool")
  echo "└─────────────────────────────────────────────────────────────"
}

# ============================================================================
# POST-INSTALL CONFLICT NEUTRALISATION
# ============================================================================

# Called immediately after each tool is installed.
# Backs up and neutralises any global config that would conflict with
# workwarrior's per-profile env-var redirection approach.
neutralise_tool_defaults() {
  local tool="$1"

  case "$tool" in
    task)
      # Replace ~/.taskrc with a ww sentinel so bare 'task' fails clearly
      # instead of silently writing to the wrong database.
      if [[ -f "$HOME/.taskrc" ]]; then
        local backup="$HOME/.taskrc.pre-ww-$(date +%Y%m%d%H%M%S)"
        cp "$HOME/.taskrc" "$backup"
        log_info "Backed up ~/.taskrc → $(basename "$backup")"
      fi
      cat > "$HOME/.taskrc" << 'SENTINEL'
# Workwarrior-managed — do not edit directly
# ─────────────────────────────────────────
# TaskWarrior on this system is managed per-profile by Workwarrior.
# Activate a profile before using task:
#
#   p-<profile-name>    e.g.  p-work
#
# The TASKRC and TASKDATA environment variables set by the profile
# override this file. If you see task errors, no profile is active.

data.location=/dev/null
hooks=off
SENTINEL
      log_success "Created ww sentinel at ~/.taskrc"
      ;;

    timew)
      # TIMEWARRIORDB env var handles redirection per profile.
      # The global ~/.timewarrior/ is only reachable outside a profile.
      if [[ -d "$HOME/.timewarrior" ]]; then
        log_info "~/.timewarrior/ exists — ignored while a ww profile is active (TIMEWARRIORDB overrides)"
      fi
      ;;

    jrnl)
      local jrnl_config="$HOME/.config/jrnl/jrnl.yaml"
      if [[ -f "$jrnl_config" ]]; then
        local backup="${jrnl_config}.pre-ww-$(date +%Y%m%d%H%M%S)"
        cp "$jrnl_config" "$backup"
        log_info "Backed up jrnl config → $(basename "$backup")"
        # Strip all journal entries except default; preserve preferences.
        awk '
          /^journals:/ { in_j=1; print; next }
          in_j && /^  default:/ { print; in_d=1; next }
          in_j && in_d && /^    / { print; next }
          in_j && in_d && !/^    / { in_d=0 }
          in_j && /^  [a-zA-Z]/ && !/^  default:/ { next }
          in_j && /^[^ ]/ { in_j=0 }
          { print }
        ' "$backup" > "$jrnl_config"
        log_success "Cleaned ~/.config/jrnl/jrnl.yaml (stripped old journal paths, kept preferences)"
      else
        # Pre-create minimal config so jrnl does not launch its interactive
        # first-run wizard (which would block the install flow).
        mkdir -p "$(dirname "$jrnl_config")"
        cat > "$jrnl_config" << 'JRNLCFG'
colors:
  body: none
  date: black
  tags: yellow
  title: cyan
default_hour: 9
default_minute: 0
editor: ''
encrypt: false
highlight: true
indent_character: '|'
journals:
  default:
    journal: ~/.local/share/jrnl/journal.txt
linewrap: 79
tagsymbols: '#@'
template: false
timeformat: '%F %r'
JRNLCFG
        log_success "Pre-created minimal ~/.config/jrnl/jrnl.yaml"
      fi
      ;;

    bugwarrior)
      # BUGWARRIORRC env var handles per-profile redirection.
      # Back up any pre-existing global config but do not delete it.
      local bw_config="$HOME/.config/bugwarrior/bugwarrior.cfg"
      if [[ -f "$bw_config" ]]; then
        local backup="${bw_config}.pre-ww-$(date +%Y%m%d%H%M%S)"
        cp "$bw_config" "$backup"
        log_info "Backed up bugwarrior config → $(basename "$backup")"
        log_info "BUGWARRIORRC env var will point to per-profile config when a profile is active"
      fi
      ;;

    hledger|python3|pipx)
      # No global config conflicts to neutralise.
      ;;
  esac
}

# ============================================================================
# MAIN INSTALLATION FLOW
# ============================================================================

# Interactive per-tool dependency installation.
# For each tool: shows a card (versions, file locations, ww integration),
# asks permission, installs, then immediately neutralises config conflicts.
run_dependency_installer() {
  local pm pm_name

  echo ""
  echo "============================================================"
  echo "       Workwarrior — Dependency Installation"
  echo "============================================================"

  # Step 1: Detect package manager
  pm=$(detect_package_manager)
  pm_name=$(get_package_manager_name "$pm")
  echo ""
  log_info "Package manager detected: $pm_name"

  if [[ "$pm" == "unknown" ]]; then
    log_warning "No supported package manager found (brew / apt / dnf / pacman)"
    echo ""
    echo "Install the following tools manually, then re-run 'ww deps install':"
    echo ""
    echo "  task        taskwarrior.org"
    echo "  timew       timewarrior.org"
    echo "  hledger     hledger.org"
    echo "  jrnl        jrnl.sh  (via: pipx install jrnl)"
    echo "  python3     python.org"
    echo ""
    return 1
  fi

  # Step 2: Check installed versions
  echo ""
  log_info "Checking installed tools..."
  check_all_dependencies

  # Step 3: Fetch latest available versions (single batch network call)
  echo ""
  echo "Fetching latest available versions online..."
  echo "  Contacting: formulae.brew.sh / api.github.com / pypi.org"
  echo ""
  fetch_latest_versions "$pm"

  # Step 4: Show overview table
  display_latest_versions

  # Step 5: Per-tool interactive loop
  # Order: pipx must come before jrnl and bugwarrior (they depend on it).
  local tool_order=("pipx" "python3" "task" "timew" "hledger" "jrnl" "bugwarrior")

  # Map tool name → index in DEP arrays (set by check_all_dependencies)
  # DEP order: TaskWarrior TimeWarrior Hledger JRNL Bugwarrior Python3 pipx
  declare -A tool_dep_index
  tool_dep_index[task]=0
  tool_dep_index[timew]=1
  tool_dep_index[hledger]=2
  tool_dep_index[jrnl]=3
  tool_dep_index[bugwarrior]=4
  tool_dep_index[python3]=5
  tool_dep_index[pipx]=6

  local installed_count=0 skipped_count=0 failed_count=0

  for tool in "${tool_order[@]}"; do
    local idx="${tool_dep_index[$tool]}"
    local installed_version="${DEP_INSTALLED_VERSIONS[$idx]}"
    local min_version="${DEP_MIN_VERSIONS[$idx]}"
    local status="${DEP_STATUS[$idx]}"
    local latest_version="${LATEST_VERSIONS[$idx]:-}"

    # ── Already installed and up to date ──────────────────────────────────
    if [[ "$status" == "ok" ]]; then
      local needs_upgrade=0
      if [[ -n "$latest_version" && "$latest_version" != "—" ]]; then
        version_gte "$installed_version" "$latest_version" || needs_upgrade=1
      fi

      if [[ $needs_upgrade -eq 0 ]]; then
        printf "  ✓  %-12s %s — up to date\n" "$tool" "$installed_version"
        continue
      fi

      # Upgrade available (not required — already meets minimum)
      show_tool_card "$tool" "$pm" "$installed_version" "$latest_version" "$min_version"
      echo ""
      echo "  ✓  Already installed ($installed_version) and meets WW minimum ($min_version)."
      echo "     Upgrade available: $latest_version"
      echo ""
      read -rp "  [u] Upgrade to $latest_version   [k] Keep $installed_version : " choice
      case "$choice" in
        u|U)
          local upgrade_cmd
          upgrade_cmd=$(get_upgrade_command "$tool" "$pm")
          if execute_install "$tool" "$upgrade_cmd" "$tool"; then
            ((installed_count++))
            neutralise_tool_defaults "$tool"
          else
            ((failed_count++))
          fi
          ;;
        *) echo "  Keeping $installed_version." ;;
      esac
      continue
    fi

    # ── Below minimum — upgrade required ──────────────────────────────────
    if [[ "$status" == "update" ]]; then
      show_tool_card "$tool" "$pm" "$installed_version" "$latest_version" "$min_version"
      echo ""
      echo "  ⚠  Version $installed_version is below WW minimum ($min_version)."
      echo "     Full compatibility is not guaranteed without upgrading."
      echo ""
      read -rp "  [u] Upgrade   [s] Skip (risk incompatibility) : " choice
      case "$choice" in
        u|U)
          local upgrade_cmd
          upgrade_cmd=$(get_upgrade_command "$tool" "$pm")
          if execute_install "$tool" "$upgrade_cmd" "$tool"; then
            ((installed_count++))
            neutralise_tool_defaults "$tool"
          else
            ((failed_count++))
          fi
          ;;
        *) echo "  Skipped."; ((skipped_count++)) ;;
      esac
      continue
    fi

    # ── Not installed ──────────────────────────────────────────────────────
    if [[ "$status" == "missing" ]]; then

      # pipx: only needed if jrnl or bugwarrior will be installed
      if [[ "$tool" == "pipx" ]]; then
        local jrnl_s="${DEP_STATUS[${tool_dep_index[jrnl]}]}"
        local bw_s="${DEP_STATUS[${tool_dep_index[bugwarrior]}]}"
        if [[ "$jrnl_s" != "missing" && "$bw_s" != "missing" ]]; then
          printf "  –  %-12s not needed (jrnl and bugwarrior already installed)\n" "$tool"
          ((skipped_count++))
          continue
        fi
      fi

      show_tool_card "$tool" "$pm" "not installed" "$latest_version" "$min_version"
      echo ""

      if [[ "$tool" == "bugwarrior" ]]; then
        echo "  Optional — only needed if you use GitHub/GitLab/Jira issue sync."
        echo "  You can install it later with: ww deps install"
        echo ""
      fi

      read -rp "  [y] Install   [s] Skip : " choice
      case "$choice" in
        y|Y)
          local install_cmd
          install_cmd=$(get_install_command "$tool" "$pm")
          if execute_install "$tool" "$install_cmd" "$tool"; then
            ((installed_count++))
            neutralise_tool_defaults "$tool"
          else
            ((failed_count++))
          fi
          ;;
        *) echo "  Skipped."; ((skipped_count++)) ;;
      esac
    fi
  done

  # Step 6: PATH check for pipx-installed tools
  if ! check_local_bin_in_path; then
    show_path_configuration
    read -rp "  Add ~/.local/bin to PATH in shell rc files? [y/n] : " add_path
    if [[ "$add_path" == "y" || "$add_path" == "Y" ]]; then
      [[ -f "$HOME/.bashrc" ]] && add_local_bin_to_path "$HOME/.bashrc"
      [[ -f "$HOME/.zshrc" ]]  && add_local_bin_to_path "$HOME/.zshrc"
    fi
  fi

  # Step 7: Summary
  echo ""
  echo "============================================================"
  echo "  Installed / upgraded : $installed_count"
  echo "  Skipped              : $skipped_count"
  [[ $failed_count -gt 0 ]] && echo "  Failed               : $failed_count"
  echo "============================================================"
  echo ""
  if [[ $failed_count -eq 0 ]]; then
    log_success "Done. Run 'ww deps check' to verify the full status."
  else
    log_warning "$failed_count installation(s) failed. Run 'ww deps check' to review."
  fi

  return $failed_count
}

# ============================================================================
# LIBRARY LOADED INDICATOR
# ============================================================================

readonly DEPENDENCY_INSTALLER_LOADED=1
