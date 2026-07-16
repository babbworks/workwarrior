#!/usr/bin/env bash
# resources/agent-templates/session-init.sh
#
# Prints current WW context at session start: profile, pending tasks, active branch.
# Usage: source this or run it to get oriented.

set -euo pipefail

WW_BASE="${WW_BASE:-$HOME/ww}"
WW_PROFILE="${WARRIOR_PROFILE:-${WW_PROFILE:-}}"

echo "── Workwarrior Session Context ──"
echo ""

# Profile
if [[ -n "$WW_PROFILE" ]]; then
  echo "  Profile:  $WW_PROFILE"
else
  echo "  Profile:  (none active)"
fi

# Instance
echo "  Instance: $WW_BASE"

# Git branch (if in a repo)
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  echo "  Branch:   $(git branch --show-current 2>/dev/null || echo 'detached')"
fi

# Pending task count
if [[ -n "$WW_PROFILE" ]]; then
  local_taskrc="${WW_BASE}/profiles/${WW_PROFILE}/.taskrc"
  if [[ -f "$local_taskrc" ]] && command -v task >/dev/null 2>&1; then
    pending=$(TASKRC="$local_taskrc" task +PENDING count 2>/dev/null || echo "?")
    echo "  Tasks:    $pending pending"
  fi
fi

# Active timer
if command -v timew >/dev/null 2>&1; then
  active=$(timew get dom.active 2>/dev/null || echo "")
  if [[ "$active" == "1" ]]; then
    echo "  Timer:    ACTIVE"
  else
    echo "  Timer:    idle"
  fi
fi

echo ""
echo "── Ready ──"
