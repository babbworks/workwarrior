#!/usr/bin/env bash
set -e

PROFILE_DIR="$HOME/ww/profiles"
SHELL_RC="$HOME/.bashrc"

# Function to add aliases
if ! declare -f add_alias_to_section > /dev/null; then
    add_alias_to_section() {
        local alias_line="$1"
        local section_marker="$2"
        local temp_file=$(mktemp)

        if grep -Fxq "$alias_line" "$SHELL_RC"; then
            echo "Alias already exists for: $(echo "$alias_line" | awk '{print $2}')"
            return 0
        fi

        if ! grep -Fxq "$section_marker" "$SHELL_RC"; then
            echo "" >> "$SHELL_RC"
            echo "$section_marker" >> "$SHELL_RC"
        fi

        awk -v section="$section_marker" -v new_alias="$alias_line" '
            {
              print $0
              if ($0 == section && !added) {
                print new_alias
                added = 1
              }
            }
        ' "$SHELL_RC" > "$temp_file" && mv "$temp_file" "$SHELL_RC"
    }
fi

# Select profile
echo "Collecting Workwarrior profiles..."
profiles=()
while IFS= read -r line; do
  profiles+=("$line")
done < <(find "$PROFILE_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)

if [[ ${#profiles[@]} -eq 0 ]]; then
  echo "Error: No profiles found in $PROFILE_DIR. Please create a profile first."
  exit 1
fi

echo "Select a profile to add new list(s):"
for i in "${!profiles[@]}"; do
  printf "   %d. %s\n" $((i+1)) "${profiles[$i]}"
done

read -p "Enter profile number or name: " profile_input

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
    if [[ "${p,,}" == "${profile_input,,}" ]]; then
      PROFILE="$p"
      break
    fi
  done
  if [[ -z "$PROFILE" ]]; then
    echo "Profile '$profile_input' not found."
    exit 1
  fi
fi

BASE="$PROFILE_DIR/$PROFILE"
LIST_DIR="$BASE/list"
mkdir -p "$LIST_DIR"

echo "Enter unique list names for '$PROFILE' (e.g., 'errands', 'projectX')."
echo "Leave blank to finish."

while true; do
  read -p "New List Name: " list_name
  list_name=$(echo "$list_name" | xargs)
  [[ -z "$list_name" ]] && break

  if ! [[ "$list_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Invalid name. Use only letters, numbers, hyphens, and underscores."
    continue
  fi

  list_file="$LIST_DIR/${PROFILE}_${list_name}.list"
  if [[ -f "$list_file" ]]; then
    echo "List '$list_file' already exists. Skipping file creation."
  else
    echo "# List: $list_name" > "$list_file"
    echo "✓ Created list: $list_file"
  fi

  ALIAS="alias list-$PROFILE-$list_name='python3 \"$HOME/ww/tools/list/list.py\" -t \"$LIST_DIR\" -l \"${PROFILE}_${list_name}.list\"'"
  add_alias_to_section "$ALIAS" "# -- Direct Aliases for List tool ---"
  echo "✓ Created alias: list-$PROFILE-$list_name"
done

echo
echo "✅ List creation complete for profile '$PROFILE'!"
echo "👉 Run: source $SHELL_RC to activate new aliases."
echo
