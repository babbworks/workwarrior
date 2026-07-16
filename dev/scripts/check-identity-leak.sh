#!/usr/bin/env bash
# dev/scripts/check-identity-leak.sh — TASK-SEC-001 grep gate.
#
# Exits 0 if no machine/user identity leaks are found in tracked files.
# Exits 1 with a report if any are found.
#
# Allowlist: third-party docs that quote other projects' paths (not ours),
# Docker container paths (/home/nextjs), generic examples (/home/$user),
# and this script's own card (TASK-SEC-001.md).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FAIL=0
SELF="check-identity-leak.sh"

# --- Our specific identity patterns (the actual leak) ---
# /Users/mp/ — previous macOS machine
if git grep -lI '/Users/mp/' 2>/dev/null | grep -v "TASK-SEC-001\|$SELF" | head -1 | grep -q .; then
  echo "FAIL: /Users/mp/ found in tracked files:"
  git grep -lI '/Users/mp/' 2>/dev/null | grep -v "TASK-SEC-001\|$SELF"
  FAIL=1
fi

# /home/morgen/ — current user's home
if git grep -lI '/home/morgen/' 2>/dev/null | grep -v "TASK-SEC-001\|$SELF" | head -1 | grep -q .; then
  echo "FAIL: /home/morgen/ found in tracked files:"
  git grep -lI '/home/morgen/' 2>/dev/null | grep -v "TASK-SEC-001\|$SELF"
  FAIL=1
fi

# Absolute instance paths that are our specific machines
if git grep -lI '~/wwv02' 2>/dev/null | grep -v "TASK-SEC-001\|\.claude/\|$SELF" | head -1 | grep -q .; then
  echo "FAIL: ~/wwv02 (old instance name) found in tracked files:"
  git grep -lI '~/wwv02' 2>/dev/null | grep -v "TASK-SEC-001\|\.claude/\|$SELF"
  FAIL=1
fi

# --- Summary ---
if [[ $FAIL -eq 0 ]]; then
  echo "✓ No machine/user identity leaks found."
  exit 0
else
  echo ""
  echo "Fix the above leaks before publishing."
  exit 1
fi
