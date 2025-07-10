#!/usr/bin/env bash

PROFILE_DIR="$HOME/ww/profiles"
SHELL_RC="$HOME/.bashrc"

# List all profiles
profiles=()
while IFS= read -r line; do
  profiles+=("$line")
done < <(find "$PROFILE_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)

if [[ ${#profiles[@]} -eq 0 ]]; then
  echo "No profiles found in $PROFILE_DIR"
  exit 1
fi

echo "Select a profile to add new journal(s):"
for i in "${!profiles[@]}"; do
  printf "  %d. %s\n" $((i+1)) "${profiles[$i]}"
done

read -p "Enter profile number or name: " profile_input

# Determine selected profile
PROFILE=""
if [[ "$profile_input" =~ ^[0-9]+$ ]]; then
  idx=$((profile_input-1))
  if (( idx < 0 || idx >= ${#profiles[@]} )); then
    echo "Invalid selection."
    exit 1
  fi
  PROFILE="${profiles[$idx]}"
else
  for p in "${profiles[@]}"; do
    if [[ "$p" == "$profile_input" ]]; then
      PROFILE="$p"
      break
    fi
  done
  if [[ -z "$PROFILE" ]]; then
    echo "Profile not found."
    exit 1
  fi
fi

BASE="$PROFILE_DIR/$PROFILE"
JOURNALS="$BASE/journals"
JRNL_CONFIG="$BASE/jrnl.yaml"

mkdir -p "$JOURNALS"

# Ensure jrnl.yaml exists and has the journals: section
if [[ ! -f "$JRNL_CONFIG" ]]; then
  cat > "$JRNL_CONFIG" <<EOF
journals:
editor: nano
encrypt: false
tagsymbols: '@'
default_hour: 9
default_minute: 0
timeformat: "%Y-%m-%d %H:%M"
highlight: true
linewrap: 79
template: false
colors:
  body: none
  date: blue
  tags: yellow
  title: cyan
EOF
fi

echo "Enter unique journal names for $PROFILE, one at a time. Leave blank to finish."
while true; do
  read -p "Journal name: " journal_name
  [[ -z "$journal_name" ]] && break

  journal_file="$JOURNALS/$journal_name.txt"
  if [[ -f "$journal_file" ]]; then
    echo "Journal '$journal_name' already exists. Skipping."
    continue
  fi

  echo "$(date '+%Y-%m-%d %H:%M'): Welcome to your $journal_name journal!" > "$journal_file"

  # Add to jrnl.yaml if not already present
  if ! grep -qE "^[[:space:]]+$journal_name:" "$JRNL_CONFIG"; then
    # Insert after 'journals:' line
    awk -v name="$journal_name" -v file="$journal_file" '
      BEGIN{added=0}
      /^journals:/ {
        print
        print "  " name ": " file
        added=1
        next
      }
      {print}
      END{if(!added) print "journals:\n  " name ": " file}
    ' "$JRNL_CONFIG" > "$JRNL_CONFIG.tmp" && mv "$JRNL_CONFIG.tmp" "$JRNL_CONFIG"
  fi

  # Add aliases
  J_ALIAS="alias j-$journal_name='jrnl --config-file \"$JRNL_CONFIG\" --journal $journal_name'"
  J_ALIAS_LONG="alias j-$PROFILE-$journal_name='jrnl --config-file \"$JRNL_CONFIG\" --journal $journal_name'"
  if ! grep -Fxq "$J_ALIAS" "$SHELL_RC"; then
    echo "$J_ALIAS" >> "$SHELL_RC"
  fi
  if ! grep -Fxq "$J_ALIAS_LONG" "$SHELL_RC"; then
    echo "$J_ALIAS_LONG" >> "$SHELL_RC"
  fi

  echo "✓ Created journal '$journal_name' for profile '$PROFILE' and updated config/aliases."
done

echo "Done. Remember to 'source $SHELL_RC' to use new aliases."
