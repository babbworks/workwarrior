#!/usr/bin/env bash
# Workwarrior Shell Initialization
# This file is sourced by ~/.bashrc or ~/.zshrc after installation
# It sets up the environment and makes ww commands available

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

# Set base directory
export WW_BASE="${WW_BASE:-$HOME/ww}"

# Add ww bin to PATH (if not already there)
if [[ ":$PATH:" != *":$WW_BASE/bin:"* ]]; then
  export PATH="$WW_BASE/bin:$PATH"
fi

# ============================================================================
# SOURCE LIBRARIES
# ============================================================================

# Source core utilities for logging functions
if [[ -f "$WW_BASE/lib/core-utils.sh" ]]; then
  source "$WW_BASE/lib/core-utils.sh"
fi

# Source shell integration for use_task_profile, j, l functions
if [[ -f "$WW_BASE/lib/shell-integration.sh" ]]; then
  source "$WW_BASE/lib/shell-integration.sh"
fi

# ============================================================================
# INITIALIZATION COMPLETE
# ============================================================================

# Set flag to indicate initialization is complete
export WW_INITIALIZED=1
