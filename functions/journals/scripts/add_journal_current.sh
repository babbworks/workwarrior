#!/usr/bin/env bash
set -e

# Determine profile
if [[ $# -gt 0 ]]; then
  PROFILE="$1"
elif [[ -n "${WARRIOR_PROFILE:-}" ]]; then
  PROFILE="$WARRIOR_PROFILE"
else
  echo "❌ No Workwarrior profile specified."
  echo "Usage: new-j <profile> OR set WARRIOR_PROFILE first with 'use_task_profile <name>'."
  exit 1
fi

# Call the main add_journal.sh with the resolved profile
exec "$HOME/ww/functions/journals/scripts/add_journal.sh" "$PROFILE"
