#!/usr/bin/env bash
# Workwarrior Shortcode Registry Library
# Manages shortcut definitions and display

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly WW_DEFAULT_SHORTCUTS="${WW_BASE:-$HOME/ww}/config/shortcuts.yaml"
readonly WW_USER_SHORTCUTS="${WW_BASE:-$HOME/ww}/config/shortcuts.user.yaml"

# ============================================================================
# YAML PARSING (Simple key-value extraction)
# ============================================================================

# Parse shortcut entries from YAML file
# Returns: shortcut|name|category|description|command|requires_profile
parse_shortcuts_yaml() {
  local yaml_file="$1"

  [[ ! -f "$yaml_file" ]] && return 1

  local current_shortcut=""
  local name="" category="" description="" command="" requires_profile=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Check for new shortcut entry (2-space indent followed by key:)
    if [[ "$line" =~ ^[[:space:]]{2}([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
      # Output previous entry if exists
      if [[ -n "$current_shortcut" ]]; then
        echo "${current_shortcut}|${name}|${category}|${description}|${command}|${requires_profile}"
      fi
      current_shortcut="${BASH_REMATCH[1]}"
      name="" category="" description="" command="" requires_profile=""
    # Parse properties (4-space indent)
    elif [[ "$line" =~ ^[[:space:]]{4}name:[[:space:]]*\"(.*)\" ]]; then
      name="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]{4}category:[[:space:]]*(.+) ]]; then
      category="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]{4}description:[[:space:]]*\"(.*)\" ]]; then
      description="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]{4}command:[[:space:]]*\"(.*)\" ]]; then
      command="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^[[:space:]]{4}requires_profile:[[:space:]]*(.+) ]]; then
      requires_profile="${BASH_REMATCH[1]}"
    fi
  done < "$yaml_file"

  # Output last entry
  if [[ -n "$current_shortcut" ]]; then
    echo "${current_shortcut}|${name}|${category}|${description}|${command}|${requires_profile}"
  fi
}

# ============================================================================
# REGISTRY FUNCTIONS
# ============================================================================

# Load all shortcuts (defaults + user overrides)
# Populates global arrays: SHORTCUT_KEYS, SHORTCUT_NAMES, etc.
load_shortcuts() {
  declare -gA SHORTCUT_NAME
  declare -gA SHORTCUT_CATEGORY
  declare -gA SHORTCUT_DESC
  declare -gA SHORTCUT_CMD
  declare -gA SHORTCUT_PROFILE
  declare -ga SHORTCUT_KEYS=()

  local entry shortcut name category desc cmd profile

  # Load defaults
  if [[ -f "$WW_DEFAULT_SHORTCUTS" ]]; then
    while IFS='|' read -r shortcut name category desc cmd profile; do
      [[ -z "$shortcut" ]] && continue
      SHORTCUT_KEYS+=("$shortcut")
      SHORTCUT_NAME["$shortcut"]="$name"
      SHORTCUT_CATEGORY["$shortcut"]="$category"
      SHORTCUT_DESC["$shortcut"]="$desc"
      SHORTCUT_CMD["$shortcut"]="$cmd"
      SHORTCUT_PROFILE["$shortcut"]="$profile"
    done < <(parse_shortcuts_yaml "$WW_DEFAULT_SHORTCUTS")
  fi

  # Load user overrides (replaces matching keys)
  if [[ -f "$WW_USER_SHORTCUTS" ]]; then
    while IFS='|' read -r shortcut name category desc cmd profile; do
      [[ -z "$shortcut" ]] && continue
      # Add to keys if new
      if [[ -z "${SHORTCUT_NAME[$shortcut]}" ]]; then
        SHORTCUT_KEYS+=("$shortcut")
      fi
      SHORTCUT_NAME["$shortcut"]="$name"
      SHORTCUT_CATEGORY["$shortcut"]="$category"
      SHORTCUT_DESC["$shortcut"]="$desc"
      SHORTCUT_CMD["$shortcut"]="$cmd"
      SHORTCUT_PROFILE["$shortcut"]="$profile"
    done < <(parse_shortcuts_yaml "$WW_USER_SHORTCUTS")
  fi
}

# Get shortcuts by category
get_shortcuts_by_category() {
  local target_category="$1"
  local shortcut

  for shortcut in "${SHORTCUT_KEYS[@]}"; do
    if [[ "${SHORTCUT_CATEGORY[$shortcut]}" == "$target_category" ]]; then
      echo "$shortcut"
    fi
  done
}

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

# Display shortcuts in a formatted table
display_shortcuts() {
  local show_category="${1:-all}"  # all, profile, function, service, global

  load_shortcuts

  echo ""
  echo "Workwarrior Shortcuts"
  echo "====================="
  echo ""

  # Column widths
  local col_short=8
  local col_name=22
  local col_desc=25

  # Header
  printf "  %-${col_short}s %-${col_name}s %s\n" "Short" "Tool" "Description"
  printf "  %-${col_short}s %-${col_name}s %s\n" "-----" "----" "-----------"

  local categories=()
  if [[ "$show_category" == "all" ]]; then
    categories=("profile" "function" "service" "global")
  else
    categories=("$show_category")
  fi

  for category in "${categories[@]}"; do
    local has_items=false

    for shortcut in "${SHORTCUT_KEYS[@]}"; do
      if [[ "${SHORTCUT_CATEGORY[$shortcut]}" == "$category" ]]; then
        if [[ "$has_items" == false ]]; then
          echo ""
          case "$category" in
            profile)  echo "  Profile Tools (require active profile):" ;;
            function) echo "  Profile Functions:" ;;
            service)  echo "  Services:" ;;
            global)   echo "  Global Commands:" ;;
          esac
          has_items=true
        fi

        local profile_marker=""
        if [[ "${SHORTCUT_PROFILE[$shortcut]}" == "true" ]]; then
          profile_marker="*"
        fi

        local short_label="${shortcut}${profile_marker}"
        printf "    %-${col_short}s %-${col_name}s %s\n" \
          "$short_label" \
          "${SHORTCUT_NAME[$shortcut]}" \
          "${SHORTCUT_DESC[$shortcut]}"
      fi
    done
  done

  echo ""
  echo "  * = requires active profile (use p-<name> to activate)"
  echo ""
}

# Display compact shortcuts list (for installation finale)
display_shortcuts_compact() {
  load_shortcuts

  echo ""
  echo "Quick Reference - Shortcuts"
  echo "---------------------------"
  echo ""

  local shortcut
  for shortcut in "${SHORTCUT_KEYS[@]}"; do
    local profile_note=""
    if [[ "${SHORTCUT_PROFILE[$shortcut]}" == "true" ]]; then
      profile_note=" (profile)"
    fi
    printf "  %-6s  %s%s\n" "$shortcut" "${SHORTCUT_NAME[$shortcut]}" "$profile_note"
  done
  echo ""
}

# Display single shortcut info
display_shortcut_info() {
  local key="$1"

  load_shortcuts

  if [[ -z "${SHORTCUT_NAME[$key]}" ]]; then
    echo "Unknown shortcut: $key"
    return 1
  fi

  echo ""
  echo "Shortcut: $key"
  echo "  Name:        ${SHORTCUT_NAME[$key]}"
  echo "  Category:    ${SHORTCUT_CATEGORY[$key]}"
  echo "  Description: ${SHORTCUT_DESC[$key]}"
  echo "  Command:     ${SHORTCUT_CMD[$key]}"
  echo "  Profile:     ${SHORTCUT_PROFILE[$key]}"
  echo ""
}

# ============================================================================
# USER OVERRIDE MANAGEMENT
# ============================================================================

# Add or update user override
add_user_shortcut() {
  local key="$1"
  local name="$2"
  local category="$3"
  local description="$4"
  local command="$5"
  local requires_profile="${6:-false}"

  local user_file="$WW_USER_SHORTCUTS"

  # Create user shortcuts file if doesn't exist
  if [[ ! -f "$user_file" ]]; then
    mkdir -p "$(dirname "$user_file")"
    cat > "$user_file" << 'EOF'
# Workwarrior User Shortcut Overrides
# Add your custom shortcuts here
# These override defaults from shortcuts.yaml

shortcuts:
EOF
  fi

  # If shortcut already exists, remove it first (upsert behavior)
  if grep -q "^  ${key}:[[:space:]]*$" "$user_file"; then
    remove_user_shortcut "$key" "silent"
  fi

  # Append new shortcut
  cat >> "$user_file" << EOF
  ${key}:
    name: "${name}"
    category: ${category}
    description: "${description}"
    command: "${command}"
    requires_profile: ${requires_profile}
EOF

  echo "Added user shortcut: $key"
}

# Remove user override (restores default)
remove_user_shortcut() {
  local key="$1"
  local mode="${2:-}"
  local user_file="$WW_USER_SHORTCUTS"

  if [[ ! -f "$user_file" ]]; then
    echo "No user shortcuts file exists"
    return 1
  fi

  local tmp_file="${user_file}.tmp"
  if ! awk -v key="$key" '
    BEGIN { in_block=0; removed=0 }
    $0 ~ "^  " key ":[[:space:]]*$" { in_block=1; removed=1; next }
    in_block && $0 ~ "^  [A-Za-z0-9_-]+:[[:space:]]*$" { in_block=0 }
    in_block { next }
    { print }
    END { if (!removed) exit 2 }
  ' "$user_file" > "$tmp_file"; then
    local status=$?
    rm -f "$tmp_file"
    if [[ "$status" -eq 2 ]]; then
      if [[ "$mode" != "silent" ]]; then
        echo "Shortcut not found in user overrides: $key"
      fi
      return 1
    fi
    echo "Failed to update user shortcuts file: $user_file"
    return 1
  fi

  if ! mv "$tmp_file" "$user_file"; then
    echo "Failed to save updated user shortcuts file: $user_file"
    rm -f "$tmp_file"
    return 1
  fi

  if [[ "$mode" != "silent" ]]; then
    echo "Removed user shortcut: $key"
  fi
}

# ============================================================================
# MAIN (for direct execution testing)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    list|"")
      display_shortcuts "${2:-all}"
      ;;
    compact)
      display_shortcuts_compact
      ;;
    info)
      display_shortcut_info "$2"
      ;;
    *)
      echo "Usage: shortcode-registry.sh [list|compact|info <key>]"
      ;;
  esac
fi
