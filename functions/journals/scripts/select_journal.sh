#!/usr/bin/env bash
# journals.sh - List journals and prompt selection

PROFILE_NAME="$1"
if [[ -z "$PROFILE_NAME" ]]; then
  echo "Usage: journals <profile-name>"
  exit 1
fi

BASE="$HOME/ww/profiles/$PROFILE_NAME"
JRNL_CONFIG="$BASE/jrnl.yaml"

if [[ ! -f "$JRNL_CONFIG" ]]; then
  echo "Journal config not found: $JRNL_CONFIG"
  exit 1
fi

# Extract journal names from jrnl.yaml (keys under 'journals:')
mapfile -t journal_names < <(awk '/^journals:/ {flag=1; next} /^editor:/ {flag=0} flag && /^[[:space:]]+[a-zA-Z0-9_-]+:/ {gsub(/:/,"",$1); print $1}' "$JRNL_CONFIG")

if [[ ${#journal_names[@]} -eq 0 ]]; then
  echo "No journals found in $JRNL_CONFIG"
  exit 1
fi

echo "Available journals for profile '$PROFILE_NAME':"
for i in "${!journal_names[@]}"; do
  printf "  %d. %s\n" $((i+1)) "${journal_names[$i]}"
done

echo "Select a journal by number or name:"
read -r selection

if [[ "$selection" =~ ^[0-9]+$ ]]; then
  idx=$((selection-1))
  if (( idx < 0 || idx >= ${#journal_names[@]} )); then
    echo "Invalid selection"
    exit 1
  fi
  selection="${journal_names[$idx]}"
else
  # Validate name exists
  found=0
  for jn in "${journal_names[@]}"; do
    if [[ "$jn" == "$selection" ]]; then
      found=1
      break
    fi
  done
  if (( found == 0 )); then
    echo "Invalid journal name"
    exit 1
  fi
fi

echo "jrnl $selection -n 5"
