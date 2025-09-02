#!/usr/bin/env bash
set -e

# --- Configuration ---
PROFILE_DIR="$HOME/ww/profiles"
SHELL_RC="$HOME/.bashrc"

# --- Globals ---
SELECTED_PROFILE=""
PROFILE_BASE=""
TASKRC_FILE=""

UDA_NAMES=()
UDA_ALIASES=()
UDA_TYPES=()
UDA_VALUES=()

NEW_UDA_NAME=""
NEW_UDA_ALIAS=""
NEW_UDA_TYPE=""
NEW_UDA_VALUES=""

# --- Helper Functions ---

list_profiles() {
  find "$PROFILE_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort
}

select_profile() {
  echo "--- Workwarrior UDA Manager ---"
  echo

  local profiles_array=()
  while IFS= read -r line; do
    profiles_array+=("$line")
  done < <(list_profiles)

  if [ ${#profiles_array[@]} -eq 0 ]; then
    echo "No profiles found in '$PROFILE_DIR'." >&2
    return 1
  fi

  echo "Available profiles:"
  local i=0
  while [ $i -lt ${#profiles_array[@]} ]; do
    echo "  $((i+1)). ${profiles_array[$i]}"
    i=$((i + 1))
  done

  read -p "Enter profile number or name: " profile_input
  local selected_profile=""

  if echo "$profile_input" | grep -qE '^[0-9]+$'; then
    local idx=$((profile_input - 1))
    if [ $idx -ge 0 ] && [ $idx -lt ${#profiles_array[@]} ]; then
      selected_profile="${profiles_array[$idx]}"
    fi
  else
    local i=0
    while [ $i -lt ${#profiles_array[@]} ]; do
      if [ "${profiles_array[$i],,}" = "${profile_input,,}" ]; then
        selected_profile="${profiles_array[$i]}"
        break
      fi
      i=$((i + 1))
    done
  fi

  if [ -z "$selected_profile" ]; then
    echo "Invalid selection." >&2
    return 1
  fi

  SELECTED_PROFILE="$selected_profile"
  PROFILE_BASE="$PROFILE_DIR/$SELECTED_PROFILE"
  TASKRC_FILE="$PROFILE_BASE/.taskrc"

  if [ ! -f "$TASKRC_FILE" ]; then
    echo ".taskrc not found in profile directory." >&2
    return 1
  fi

  return 0
}

get_udas() {
  UDA_NAMES=()
  UDA_ALIASES=()
  UDA_TYPES=()
  UDA_VALUES=()

  local uda_list
  uda_list=$(grep -E '^uda\.[^.]+\.type=' "$TASKRC_FILE" | awk -F. '{print $2}' | sort -u)

  local uda
  for uda in $uda_list; do
    UDA_NAMES+=("$uda")

    # Get properties, fallback if empty
    local type
    type=$(TASKRC="$TASKRC_FILE" task _get rc.uda."$uda".type 2>/dev/null || echo "string")
    local alias
    alias=$(TASKRC="$TASKRC_FILE" task _get rc.uda."$uda".label 2>/dev/null || echo "")
    local values
    values=$(TASKRC="$TASKRC_FILE" task _get rc.uda."$uda".values 2>/dev/null || echo "")

    UDA_TYPES+=("$type")
    UDA_ALIASES+=("$alias")
    UDA_VALUES+=("$values")
  done
}

display_udas() {
  if [ ${#UDA_NAMES[@]} -eq 0 ]; then
    echo "No UDAs defined."
    return
  fi

  local cols=3
  local count=${#UDA_NAMES[@]}
  local i=0

  while [ $i -lt $count ]; do
    local row=""
    local j=0
    while [ $j -lt $cols ] && [ $i -lt $count ]; do
      row="$row$(printf "%2d. %-20s" $((i+1)) "${UDA_NAMES[$i]}")"
      i=$((i + 1))
      j=$((j + 1))
    done
    echo "$row"
  done
}

prompt_for_uda_properties() {
  local current_name="$1"
  local current_alias="$2"
  local current_type="$3"
  local current_values="$4"

  echo

  read -p "UDA Name (current: '$current_name'): " input_name
  NEW_UDA_NAME="${input_name:-$current_name}"
  if [ -z "$NEW_UDA_NAME" ]; then
    echo "UDA Name cannot be empty." >&2
    return 1
  fi

  read -p "UDA Alias (current: '${current_alias:-$NEW_UDA_NAME}'): " input_alias
  NEW_UDA_ALIAS="${input_alias:-${current_alias:-$NEW_UDA_NAME}}"

  local allowed_types="string numeric date duration boolean"
  read -p "UDA Type (current: '${current_type:-string}', options: $allowed_types): " input_type
  NEW_UDA_TYPE="${input_type:-${current_type:-string}}"
  echo " $allowed_types " | grep -q " $NEW_UDA_TYPE "
  if [ $? -ne 0 ]; then
    echo "Invalid UDA Type: '$NEW_UDA_TYPE'" >&2
    return 1
  fi

  read -p "Allowed Values (current: '$current_values', comma-separated, leave blank for any): " input_values
  NEW_UDA_VALUES="${input_values:-$current_values}"

  return 0
}

apply_uda_changes() {
  local original_name="$1"
  local new_name="$2"
  local new_alias="$3"
  local new_type="$4"
  local new_values="$5"
  local action="$6"

  if [ "$action" = "delete" ]; then
    echo "Deleting UDA '$original_name'..."
    TASKRC="$TASKRC_FILE" task config uda."$original_name".type ""
    TASKRC="$TASKRC_FILE" task config uda."$original_name".label ""
    TASKRC="$TASKRC_FILE" task config uda."$original_name".values ""
    echo "✓ UDA '$original_name' deleted."
    return 0
  fi

  if [ "$original_name" != "$new_name" ] && [ -n "$original_name" ]; then
    TASKRC="$TASKRC_FILE" task config uda."$original_name".type ""
    TASKRC="$TASKRC_FILE" task config uda."$original_name".label ""
    TASKRC="$TASKRC_FILE" task config uda."$original_name".values ""
  fi

  TASKRC="$TASKRC_FILE" task config uda."$new_name".type "$new_type"
  TASKRC="$TASKRC_FILE" task config uda."$new_name".label "$new_alias"
  TASKRC="$TASKRC_FILE" task config uda."$new_name".values "$new_values"

  echo "✓ UDA '$new_name' properties updated/added."
}

group_udas() {
  echo "--- Group UDAs ---"
  read -p "Enter group name: " group_name
  group_name=$(echo "$group_name" | tr -d '[:space:]')
  if [ -z "$group_name" ]; then
    echo "Group name cannot be empty."
    return
  fi

  display_udas
  read -p "Enter UDA numbers to add to group (space-separated): " idx_input
  set -- $idx_input
  local uda_list=""
  for idx in "$@"; do
    if echo "$idx" | grep -qE '^[0-9]+$'; then
      local zero_idx=$((idx - 1))
      if [ $zero_idx -ge 0 ] && [ $zero_idx -lt ${#UDA_NAMES[@]} ]; then
        if [ -z "$uda_list" ]; then
          uda_list="${UDA_NAMES[$zero_idx]}"
        else
          uda_list="$uda_list,${UDA_NAMES[$zero_idx]}"
        fi
      else
        echo "Warning: index $idx out of range, skipping."
      fi
    fi
  done

  if [ -z "$uda_list" ]; then
    echo "No valid UDAs selected."
    return
  fi

  local group_file="$PROFILE_BASE/.uda-groups"

  if grep -q "^$group_name:" "$group_file" 2>/dev/null; then
    # Replace existing group line
    if sed --version >/dev/null 2>&1; then
      sed -i "/^$group_name:/c\\
$group_name: $uda_list
" "$group_file"
    else
      sed -i.bak "/^$group_name:/c\\
$group_name: $uda_list
" "$group_file"
    fi
  else
    echo "$group_name: $uda_list" >> "$group_file"
  fi

  echo "✓ Group '$group_name' saved with UDAs: $uda_list"
}

# --- Main loop ---

if ! select_profile; then
  exit 1
fi

while true; do
  get_udas
  echo
  echo "--- UDAs for profile '$SELECTED_PROFILE' ---"
  display_udas
  echo
  echo "Options:"
  echo "  A - Add UDA"
  echo "  E - Edit UDA"
  echo "  D - Delete UDA"
  echo "  G - Group UDAs"
  echo "  Q - Quit"
  echo

  read -p "Enter choice: " choice
  choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

  case "$choice" in
    a)
      echo "--- Add New UDA ---"
      if prompt_for_uda_properties "" "" "" ""; then
        apply_uda_changes "" "$NEW_UDA_NAME" "$NEW_UDA_ALIAS" "$NEW_UDA_TYPE" "$NEW_UDA_VALUES"
      else
        echo "UDA addition aborted or invalid input."
      fi
      ;;
    e)
      if [ ${#UDA_NAMES[@]} -eq 0 ]; then
        echo "No UDAs to edit."
        continue
      fi
      read -p "Enter UDA number to edit: " num
      if ! echo "$num" | grep -qE '^[0-9]+$'; then
        echo "Invalid input."
        continue
      fi
      num=$((num - 1))
      if [ $num -lt 0 ] || [ $num -ge ${#UDA_NAMES[@]} ]; then
        echo "UDA number out of range."
        continue
      fi
      u_name="${UDA_NAMES[$num]}"
      u_alias="${UDA_ALIASES[$num]}"
      u_type="${UDA_TYPES[$num]}"
      u_values="${UDA_VALUES[$num]}"
      echo "--- Editing UDA '$u_name' ---"
      if prompt_for_uda_properties "$u_name" "$u_alias" "$u_type" "$u_values"; then
        apply_uda_changes "$u_name" "$NEW_UDA_NAME" "$NEW_UDA_ALIAS" "$NEW_UDA_TYPE" "$NEW_UDA_VALUES"
      else
        echo "UDA edit aborted or invalid input."
      fi
      ;;
    d)
      if [ ${#UDA_NAMES[@]} -eq 0 ]; then
        echo "No UDAs to delete."
        continue
      fi
      read -p "Enter UDA number to delete: " num
      if ! echo "$num" | grep -qE '^[0-9]+$'; then
        echo "Invalid input."
        continue
      fi
      num=$((num - 1))
      if [ $num -lt 0 ] || [ $num -ge ${#UDA_NAMES[@]} ]; then
        echo "UDA number out of range."
        continue
      fi
      u_name="${UDA_NAMES[$num]}"
      read -p "Are you sure you want to delete UDA '$u_name'? (y/N): " confirm
      confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
      if [ "$confirm" = "y" ]; then
        apply_uda_changes "$u_name" "" "" "" "" "delete"
      else
        echo "Deletion aborted."
      fi
      ;;
    g)
      group_udas
      ;;
    q)
      echo "Exiting. Remember to 'source $SHELL_RC' if needed."
      exit 0
      ;;
    *)
      echo "Invalid option."
      ;;
  esac
done
