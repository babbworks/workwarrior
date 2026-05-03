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

# Source companion activation functions for non-registry installs
_ww_cfg="${WW_CONFIG_HOME:-$HOME/.config/ww}"
if [[ -f "${_ww_cfg}/instance-functions.sh" ]]; then
  source "${_ww_cfg}/instance-functions.sh"
fi
unset _ww_cfg

# ============================================================================
# ALIASES
# ============================================================================

alias p='profile'
alias p-none='deactivate_task_profile'


# ============================================================================
# STARTUP STATUS
# ============================================================================

_ww_startup_status() {
  local profiles_dir="${WW_BASE:?WW_BASE not set}/profiles"
  local profiles=()

  if [[ -d "$profiles_dir" ]]; then
    while IFS= read -r -d '' dir; do
      profiles+=("$(basename "$dir")")
    done < <(command find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  fi

  if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "  ww  ·  no profiles yet  ·  get started: profile create <name>"
  else
  local list
  list=$(
    printf '%s\n' "${profiles[@]}" |
    sort |
    paste -sd '  ' -
  )

  echo "  ww  ·  profiles: ${list}  ·  activate: p-<name> (e.g. p-work)"
fi
}

# Startup status intentionally disabled to keep new terminals quiet.
# _ww_startup_status

# ============================================================================
# PROMPT PREFIX
# ============================================================================

_ww_prompt_prefix() {
  local profile="${WARRIOR_PROFILE:-}"
  [[ -z "$profile" ]] && return 0  # silent when no profile active
  local instance="${WW_ACTIVE_INSTANCE:-${WW_ORCH_INSTANCE:-}}"
  local pin_marker=""
  [[ -n "${WW_PINNED_INSTANCE:-}" ]] && pin_marker="[pin]"
  if [[ -n "$instance" && "$instance" != "ww" && "$instance" != "main" ]]; then
    printf 'ww|%s:%s%s' "$instance" "$profile" "$pin_marker"
  else
    printf 'ww|%s%s' "$profile" "$pin_marker"
  fi
}

_ww_apply_prompt_prefix() {
  local pfx
  pfx="$(_ww_prompt_prefix)"
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    if [[ -n "$pfx" ]]; then
      [[ "$PROMPT" == ww\|* ]] || PROMPT="${pfx} ${PROMPT}"
    else
      # Strip ww| prefix when profile deactivated
      [[ "$PROMPT" == ww\|* ]] && PROMPT="${PROMPT#*\|* }"
    fi
  else
    if [[ -n "$pfx" ]]; then
      [[ "$PS1" == ww\|* ]] || PS1="${pfx} ${PS1}"
    else
      PS1="${PS1#ww|* }"
    fi
  fi
}

_ww_apply_prompt_prefix
if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -U add-zsh-hook >/dev/null 2>&1 || true
  add-zsh-hook precmd _ww_apply_prompt_prefix >/dev/null 2>&1 || true
else
  case "${PROMPT_COMMAND:-}" in
    *_ww_apply_prompt_prefix*) ;;
    "") PROMPT_COMMAND="_ww_apply_prompt_prefix" ;;
    *) PROMPT_COMMAND="_ww_apply_prompt_prefix; $PROMPT_COMMAND" ;;
  esac
fi

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
( _ww_sense_ollama &>/dev/null & )  # subshell owns the job; parent never reports it

# ============================================================================
# DONE
# ============================================================================

export WW_INITIALIZED=1
