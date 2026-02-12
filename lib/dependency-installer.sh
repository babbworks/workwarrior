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
        bugwarrior) echo "pipx install bugwarrior" ;;
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
        bugwarrior) echo "pipx install bugwarrior" ;;
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
        bugwarrior) echo "pipx install bugwarrior" ;;
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
        bugwarrior) echo "pipx install bugwarrior" ;;
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
# MAIN INSTALLATION FLOW
# ============================================================================

# Run the complete dependency installation flow
run_dependency_installer() {
  local pm
  local pm_name

  echo ""
  echo "============================================================"
  echo "         Dependency Installation"
  echo "============================================================"

  # Step 1: Detect package manager
  pm=$(detect_package_manager)
  pm_name=$(get_package_manager_name "$pm")

  echo ""
  log_info "Detected package manager: $pm_name"

  if [[ "$pm" == "unknown" ]]; then
    log_warning "No supported package manager found"
    log_info "You will need to install dependencies manually"
    echo ""
    echo "Required tools:"
    echo "  • TaskWarrior (task)"
    echo "  • TimeWarrior (timew)"
    echo "  • Hledger (hledger)"
    echo "  • JRNL (jrnl)"
    echo "  • Python 3 (python3)"
    echo ""
    return 1
  fi

  # Step 2: Check current status
  check_all_dependencies
  display_dependency_status

  # Step 3: Offer online version check
  echo "Would you like to check for latest versions online?"
  show_online_check_endpoints "$pm"
  read -p "[y] Yes, check online  [n] No, continue: " check_online

  if [[ "$check_online" == "y" || "$check_online" == "Y" ]]; then
    fetch_latest_versions "$pm"
    display_latest_versions
  fi

  # Step 4: Determine what needs to be installed
  local tools_to_install=()
  local tool_names=("task" "timew" "hledger" "jrnl" "bugwarrior" "python3" "pipx")

  for i in "${!DEP_STATUS[@]}"; do
    if [[ "${DEP_STATUS[$i]}" == "missing" ]]; then
      tools_to_install+=("${tool_names[$i]}")
    fi
  done

  if [[ ${#tools_to_install[@]} -eq 0 ]]; then
    log_success "All dependencies are installed"
    echo ""
    return 0
  fi

  # Step 5: Show installation plan
  echo ""
  echo "┌─────────────────────────────────────────────────────────────"
  echo "│ Installation Plan"
  echo "└─────────────────────────────────────────────────────────────"
  echo ""
  echo "The following tools will be installed:"
  echo ""

  # Ensure pipx is installed first if jrnl or bugwarrior is needed
  local need_pipx=0
  for tool in "${tools_to_install[@]}"; do
    if [[ "$tool" == "jrnl" || "$tool" == "bugwarrior" ]]; then
      need_pipx=1
    fi
  done

  # Check if pipx is missing and needed
  if [[ $need_pipx -eq 1 ]]; then
    local pipx_version
    pipx_version=$(get_tool_version "pipx")
    if [[ "$pipx_version" == "not_installed" ]]; then
      # Add pipx to front of list if not already there
      local has_pipx=0
      for tool in "${tools_to_install[@]}"; do
        [[ "$tool" == "pipx" ]] && has_pipx=1
      done
      if [[ $has_pipx -eq 0 ]]; then
        tools_to_install=("pipx" "${tools_to_install[@]}")
      fi
    fi
  fi

  local step=1
  for tool in "${tools_to_install[@]}"; do
    local cmd
    cmd=$(get_install_command "$tool" "$pm")
    echo "  Step $step: $cmd"
    ((step++))
  done

  echo ""
  echo "Installation directory: System default (via $pm_name)"
  echo ""
  read -p "Proceed with installation? [y/n]: " confirm

  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Installation cancelled"
    return 1
  fi

  # Step 6: Execute installations
  local failed=0
  for tool in "${tools_to_install[@]}"; do
    local cmd
    cmd=$(get_install_command "$tool" "$pm")
    if ! execute_install "$tool" "$cmd" "${DEP_NAMES[$i]:-$tool}"; then
      ((failed++))
    fi

    # Special handling for jrnl
    if [[ "$tool" == "jrnl" ]]; then
      show_jrnl_setup_guide
      echo "Would you like to run jrnl now to complete initial setup?"
      read -p "[y] Yes  [n] No, I'll do it later: " run_jrnl
      if [[ "$run_jrnl" == "y" || "$run_jrnl" == "Y" ]]; then
        echo ""
        log_info "Running 'jrnl' for first-time setup..."
        jrnl --diagnostic || true
      fi
    fi
  done

  # Step 7: Check PATH for pipx
  if ! check_local_bin_in_path; then
    show_path_configuration
    read -p "Add ~/.local/bin to PATH? [y/n]: " add_path

    if [[ "$add_path" == "y" || "$add_path" == "Y" ]]; then
      # Add to appropriate shell RC files
      [[ -f "$HOME/.bashrc" ]] && add_local_bin_to_path "$HOME/.bashrc"
      [[ -f "$HOME/.zshrc" ]] && add_local_bin_to_path "$HOME/.zshrc"
    fi
  fi

  # Step 8: Summary
  echo ""
  echo "============================================================"
  if [[ $failed -eq 0 ]]; then
    log_success "All dependencies installed successfully"
  else
    log_warning "$failed tool(s) failed to install"
  fi
  echo "============================================================"
  echo ""

  return $failed
}

# ============================================================================
# LIBRARY LOADED INDICATOR
# ============================================================================

readonly DEPENDENCY_INSTALLER_LOADED=1
