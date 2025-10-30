#!/usr/bin/env bash
set -e

PROFILE_DIR="$HOME/ww/profiles"
SHELL_RC="$HOME/.bashrc" # Assuming this is the correct shell configuration file

<<<<<<< HEAD

=======
# Function to add alias to bashrc
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
if ! declare -f add_alias_to_section > /dev/null; then
    add_alias_to_section() {
        local alias_line="$1"
        local section_marker="$2"
        local temp_file=$(mktemp)

<<<<<<< HEAD
        # Check if the alias already exists
        if grep -Fxq "$alias_line" "$SHELL_RC"; then
            echo "Alias already exists for: $(echo "$alias_line" | awk '{print $2}')" # Improved feedback
            return 0
        fi

        # Check if section marker exists
=======
        if grep -Fxq "$alias_line" "$SHELL_RC"; then
            echo "Alias already exists for: $(echo "$alias_line" | awk '{print $2}')"
            return 0
        fi

>>>>>>> b78e8d2 (updating for transfer to Lenovo)
        if ! grep -Fxq "$section_marker" "$SHELL_RC"; then
            echo "" >> "$SHELL_RC"
            echo "$section_marker" >> "$SHELL_RC"
        fi

<<<<<<< HEAD
        # Add alias after the section marker using awk
=======
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
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

<<<<<<< HEAD

echo "Collecting Workwarrior profiles..."
profiles=()
while IFS= read -r line; do
  profiles+=("$line")
done < <(find "$PROFILE_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)

if [[ ${#profiles[@]} -eq 0 ]]; then
  echo "Error: No profiles found in $PROFILE_DIR. Please create a profile first."
  exit 1
fi

echo "Select a profile to add new journal(s):"
for i in "${!profiles[@]}"; do
  printf "   %d. %s\n" $((i+1)) "${profiles[$i]}"
done

read -p "Enter profile number or name: " profile_input

# Determine selected profile
PROFILE=""
if [[ "$profile_input" =~ ^[0-9]+$ ]]; then
  idx=$((profile_input-1))
  if (( idx < 0 || idx >= ${#profiles[@]} )); then
    echo "Invalid selection. Please enter a number corresponding to a listed profile."
    exit 1
  fi
  PROFILE="${profiles[$idx]}"
else
  # Case-insensitive match for profile name
  for p in "${profiles[@]}"; do
    if [[ "${p,,}" == "${profile_input,,}" ]]; then # Added , to make it case-insensitive
      PROFILE="$p"
      break
    fi
  done
  if [[ -z "$PROFILE" ]]; then
    echo "Profile '$profile_input' not found. Please enter a valid profile name or number."
    exit 1
=======
# -------------------
# Profile selection
# -------------------
if [[ -n "${1:-}" ]]; then
  PROFILE="$1"
  echo "Using profile: $PROFILE"
else
  echo "Collecting Workwarrior profiles..."
  profiles=()
  while IFS= read -r line; do
    profiles+=("$line")
  done < <(find "$PROFILE_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)

  if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "Error: No profiles found in $PROFILE_DIR. Please create a profile first."
    exit 1
  fi

  echo "Select a profile to add new journal(s):"
  for i in "${!profiles[@]}"; do
    printf "   %d. %s\n" $((i+1)) "${profiles[$i]}"
  done

  read -p "Enter profile number or name: " profile_input

  PROFILE=""
  if [[ "$profile_input" =~ ^[0-9]+$ ]]; then
    idx=$((profile_input-1))
    if (( idx < 0 || idx >= ${#profiles[@]} )); then
      echo "Invalid selection. Please enter a valid number."
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
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
  fi
fi

BASE="$PROFILE_DIR/$PROFILE"
JOURNALS="$BASE/journals"
JRNL_CONFIG="$BASE/jrnl.yaml"

echo "Ensuring necessary directories exist for profile '$PROFILE'..."
mkdir -p "$JOURNALS"

<<<<<<< HEAD
# Ensure jrnl.yaml exists and has the journals: section.
# This block should create a basic jrnl.yaml if it's missing or empty.
if [[ ! -f "$JRNL_CONFIG" ]] || ! grep -qE "^journals:" "$JRNL_CONFIG"; then
  echo "Creating/initializing jrnl.yaml for profile '$PROFILE'..."
  # Create a temporary file with the base config if jrnl.yaml is missing or corrupt
  TEMP_JRNL_CONFIG_CONTENT=$(mktemp)
  cat > "$TEMP_JRNL_CONFIG_CONTENT" <<'EOF_JRNL'
=======
# -------------------
# Initialize jrnl.yaml if missing
# -------------------
if [[ ! -f "$JRNL_CONFIG" ]]; then
  cat > "$JRNL_CONFIG" <<'EOF'
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
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
<<<<<<< HEAD
EOF_JRNL
  # If the file exists but 'journals:' is missing, add it to the beginning
  if [[ -f "$JRNL_CONFIG" ]]; then
    mv "$JRNL_CONFIG" "$JRNL_CONFIG.bak" # Backup existing potentially malformed file
    cat "$TEMP_JRNL_CONFIG_CONTENT" > "$JRNL_CONFIG"
    cat "$JRNL_CONFIG.bak" | grep -vE "^(journals:|editor:|encrypt:|tagsymbols:|default_hour:|default_minute:|timeformat:|highlight:|linewrap:|template:|colors:)" >> "$JRNL_CONFIG"
    rm "$JRNL_CONFIG.bak"
  else
    mv "$TEMP_JRNL_CONFIG_CONTENT" "$JRNL_CONFIG"
  fi
  rm -f "$TEMP_JRNL_CONFIG_CONTENT" # Clean up temp file
fi


=======
EOF
  echo "Initialized new jrnl.yaml for profile '$PROFILE'."
fi

# -------------------
# Add journals
# -------------------
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
echo "Enter unique journal names for '$PROFILE' (e.g., 'work', 'personal', 'ideas')."
echo "Leave blank and press Enter to finish."
while true; do
  read -p "New Journal Name: " journal_name
  journal_name=$(echo "$journal_name" | xargs) # Trim whitespace
<<<<<<< HEAD

  [[ -z "$journal_name" ]] && break

  # Validate journal_name: Basic alphanumeric/hyphen/underscore check
  if ! [[ "$journal_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Warning: Journal name '$journal_name' contains invalid characters. Please use only letters, numbers, hyphens, and underscores. Skipping."
=======
  [[ -z "$journal_name" ]] && break

  # Validate journal name
  if ! [[ "$journal_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Invalid characters in journal name. Use letters, numbers, hyphens, or underscores."
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
    continue
  fi

  journal_file="$JOURNALS/$journal_name.txt"

<<<<<<< HEAD
  # Check if journal is already defined in jrnl.yaml or file exists
  if grep -qE "^[[:space:]]+${journal_name,,}:" "$JRNL_CONFIG"; then # Case-insensitive check
    echo "Journal '$journal_name' is already defined in $JRNL_CONFIG. Skipping file creation and alias update."
    continue
  fi
  if [[ -f "$journal_file" ]]; then
    echo "Journal file '$journal_name.txt' already exists at '$journal_file'. Adding to config if needed."
  fi

  # Create journal file if it doesn't exist
=======
  # Create journal file if missing
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
  if [[ ! -f "$journal_file" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M'): Welcome to your $journal_name journal for profile $PROFILE!" > "$journal_file"
  fi

<<<<<<< HEAD
  # Add/Update to jrnl.yaml
  # This awk command replaces existing entry or adds new one
  awk -v name="$journal_name" -v file="$journal_file" '
  BEGIN { FS=OFS="" }
  {
      if ($0 ~ "^[[:space:]]+" name ":") { # Found an existing entry for this journal
          print "  " name ": " file # Replace it
          found_and_updated = 1
      } else {
          print $0 # Print current line unchanged
      }
  }
  END {
      if (!found_and_updated) {
          print "  " name ": " file
      }
  }' "$JRNL_CONFIG" > "$JRNL_CONFIG.tmp" && mv "$JRNL_CONFIG.tmp" "$JRNL_CONFIG"

  # Add aliases using the add_alias_to_section function
  J_ALIAS="alias j-$journal_name='jrnl --config-file \"$JRNL_CONFIG\" --journal \"$journal_name\"'" # Quoted journal_name
  J_ALIAS_LONG="alias j-$PROFILE-$journal_name='jrnl --config-file \"$JRNL_CONFIG\" --journal \"$journal_name\"'" # Quoted journal_name
  
  add_alias_to_section "$J_ALIAS" "# -- Direct Alias for Journals ---"
  add_alias_to_section "$J_ALIAS_LONG" "# -- Direct Alias for Journals ---" # Use same section marker

  echo "✓ Journal '$journal_name' for profile '$PROFILE' configured and aliases updated."
done

echo "✅ Journal creation process complete for profile '$PROFILE'!"
echo "👉 Remember to 'source $SHELL_RC' in your terminal to load the new aliases."
echo "   (or simply open a new terminal window/tab)."
=======
  # -------------------
  # Update jrnl.yaml journals block
  # -------------------
  awk -v name="$journal_name" -v file="$journal_file" '
    BEGIN { in_journals=0; inserted=0 }
    /^journals:/ { print; in_journals=1; next }
    in_journals && /^[^[:space:]]/ { 
      if (!inserted) { print "  " name ": " file; inserted=1 }
      in_journals=0
    }
    in_journals {
      # Skip existing journal with same name
      if ($1 == name ":") { print "  " name ": " file; inserted=1; next }
      print
      next
    }
    { print }
    END {
      if (in_journals && !inserted) print "  " name ": " file
    }
  ' "$JRNL_CONFIG" > "$JRNL_CONFIG.tmp" && mv "$JRNL_CONFIG.tmp" "$JRNL_CONFIG"

  # -------------------
  # Add aliases
  # -------------------
  J_ALIAS="alias j-$journal_name='jrnl --config-file \"$JRNL_CONFIG\" --journal \"$journal_name\"'"
  J_ALIAS_LONG="alias j-$PROFILE-$journal_name='jrnl --config-file \"$JRNL_CONFIG\" --journal \"$journal_name\"'"
  
  add_alias_to_section "$J_ALIAS" "# -- Direct Alias for Journals ---"
  add_alias_to_section "$J_ALIAS_LONG" "# -- Direct Alias for Journals ---"

  echo "✓ Journal '$journal_name' configured for profile '$PROFILE'."
done

echo "✅ Journal creation complete for profile '$PROFILE'."
echo "👉 Remember to 'source $SHELL_RC' to load new aliases."
>>>>>>> b78e8d2 (updating for transfer to Lenovo)
