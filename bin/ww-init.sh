#!/usr/bin/env bash
# Workwarrior Shell Initialization
# Sourced by ~/.bashrc or ~/.zshrc on shell startup.

# Skip re-initialization within the same shell session (prevents readonly errors
# and duplicate output when the user runs: source ~/.bashrc)
[[ -n "${WW_INITIALIZED:-}" ]] && return 0

# ============================================================================
# ENVIRONMENT
# ============================================================================

# Set base directory only if not already set (may have been exported externally)
if [[ -z "${WW_BASE:-}" ]]; then
  export WW_BASE="$HOME/ww"
fi

# Add ww bin to PATH
if [[ ":$PATH:" != *":$WW_BASE/bin:"* ]]; then
  export PATH="$WW_BASE/bin:$PATH"
fi

# Add ww system/bin to PATH (wwctl and other dev tools)
if [[ ":$PATH:" != *":$WW_BASE/system/bin:"* ]]; then
  export PATH="$WW_BASE/system/bin:$PATH"
fi

# ============================================================================
# LOAD LIBRARIES
# ============================================================================

if [[ -f "$WW_BASE/lib/core-utils.sh" ]]; then
  source "$WW_BASE/lib/core-utils.sh"
fi

if [[ -f "$WW_BASE/lib/shell-integration.sh" ]]; then
  source "$WW_BASE/lib/shell-integration.sh"
fi

# ============================================================================
# ALIASES
# ============================================================================

alias p='profile'

# ============================================================================
# STARTUP STATUS
# ============================================================================

_ww_startup_status() {
  local profiles_dir="$WW_BASE/profiles"
  local profiles=()

  if [[ -d "$profiles_dir" ]]; then
    while IFS= read -r -d '' dir; do
      profiles+=("$(basename "$dir")")
    done < <(command find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  fi

  if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "  ww  ·  no profiles yet  ·  get started: profile create <name>"
  else
    local sorted_profiles=()
    while IFS= read -r name; do
      sorted_profiles+=("$name")
    done < <(printf '%s\n' "${profiles[@]}" | sort)
    local list
    list=$(printf '%s  ' "${sorted_profiles[@]}")
    echo "  ww  ·  profiles: ${list%  }  ·  activate: p-<name>"
  fi
}

_ww_startup_status

# ============================================================================
# AI SENSING (lightweight — 1s timeout)
# ============================================================================

_ww_sense_ollama() {
  if command -v curl &>/dev/null; then
    if curl -s --max-time 1 http://localhost:11434/api/tags >/dev/null 2>&1; then
      export WW_OLLAMA_AVAILABLE=1
    fi
  fi
}
{ _ww_sense_ollama & } 2>/dev/null  # background, suppress job control noise

# ============================================================================
# DONE
# ============================================================================

export WW_INITIALIZED=1
