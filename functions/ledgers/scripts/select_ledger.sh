#!/usr/bin/env bash
# ledgers.sh - List ledgers and prompt selection

PROFILE_NAME="$1"
if [[ -z "$PROFILE_NAME" ]]; then
  echo "Usage: ledgers <profile-name>"
  exit 1
fi

BASE="$HOME/ww/profiles/$PROFILE_NAME"
LEDGER_CONFIG="$BASE/ledgers.yaml"

if [[ ! -f "$LEDGER_CONFIG" ]]; then
  echo "Ledger config not found: $LEDGER_CONFIG"
  exit 1
fi

# Extract ledger names from ledgers.yaml (keys under 'ledgers:')
mapfile -t ledger_names < <(awk '/^ledgers:/ {flag=1; next} /^[^ ]/ {flag=0} flag && /^[[:space:]]+[a-zA-Z0-9_-]+:/ {gsub(/:/,"",$1); print $1}' "$LEDGER_CONFIG")

if [[ ${#ledger_names[@]} -eq 0 ]]; then
  echo "No ledgers found in $LEDGER_CONFIG"
  exit 1
fi

echo "Available ledgers for profile '$PROFILE_NAME':"
for i in "${!ledger_names[@]}"; do
  printf "  %d. %s\n" $((i+1)) "${ledger_names[$i]}"
done

echo "Select a ledger by number or name:"
read -r selection

if [[ "$selection" =~ ^[0-9]+$ ]]; then
  idx=$((selection-1))
  if (( idx < 0 || idx >= ${#ledger_names[@]} )); then
    echo "Invalid selection"
    exit 1
  fi
  selection="${ledger_names[$idx]}"
else
  # Validate name exists
  found=0
  for ln in "${ledger_names[@]}"; do
    if [[ "$ln" == "$selection" ]]; then
      found=1
      break
    fi
  done
  if (( found == 0 )); then
    echo "Invalid ledger name"
    exit 1
  fi
fi

export LEDGER_FILE="/path/to/selected-ledger.journal"
echo "Now using: $LEDGER_FILE"


echo "hledger register -n5"
