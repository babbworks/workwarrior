#!/usr/bin/env bash
# Script to clean WorkWarrior-related sections from bashrc
# This creates a backup and removes old WorkWarrior configuration

set -e

BASHRC="$HOME/.bashrc"
BACKUP="$HOME/.bashrc.backup-$(date +%Y%m%d-%H%M%S)"

echo "Creating backup: $BACKUP"
cp "$BASHRC" "$BACKUP"

echo "Removing old WorkWarrior sections from bashrc..."

# Create a temporary file
TEMP_FILE=$(mktemp)

# Remove sections between WorkWarrior markers
awk '
  /^# -- Confirmation of Alternative Workwarrior BASHRC/,/^# --- End Workwarrior/ { next }
  /^# --- Workwarrior Help Aliases ---/,/^# --- End/ { next }
  /^# -- Workwarrior Profile Aliases ---/,/^# --- End/ { next }
  /^# -- Direct Alias for Journals ---/,/^# --- End/ { next }
  /^# -- Direct Aliases for Hledger ---/,/^# --- End/ { next }
  /^# --- Workwarrior Core Functions ---/,/^# --- End/ { next }
  /^# ---- ~\/scripts\/taskwarrior\//,/^$/ { next }
  /^alias p-[a-zA-Z0-9_-]*=/ { next }
  /^alias j-[a-zA-Z0-9_-]*=/ { next }
  /^alias l-[a-zA-Z0-9_-]*=/ { next }
  /^function use_task_profile/,/^}/ { next }
  /^function j\(\)/,/^}/ { next }
  /^function l\(\)/,/^}/ { next }
  /^function t\(\)/,/^}/ { next }
  { print }
' "$BASHRC" > "$TEMP_FILE"

# Replace original with cleaned version
mv "$TEMP_FILE" "$BASHRC"

echo "✓ Cleaned bashrc"
echo "✓ Backup saved to: $BACKUP"
echo ""
echo "To restore the backup if needed:"
echo "  cp $BACKUP ~/.bashrc"
