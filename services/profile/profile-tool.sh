#!/usr/bin/env bash
# Profile Tool - View and manage profile metadata and statistics
# Usage: profile [command] [arguments]

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

WW_BASE="${WW_BASE:-$HOME/ww}"
PROFILE_META_TEMPLATE="$WW_BASE/config/profile-meta-template.yaml"

# Source libraries
if [[ -f "$WW_BASE/lib/core-utils.sh" ]]; then
  source "$WW_BASE/lib/core-utils.sh"
else
  log_info() { echo "info: $*"; }
  log_error() { echo "error: $*" >&2; }
  log_success() { echo "ok: $*"; }
  log_warning() { echo "warn: $*"; }
fi

if [[ -f "$WW_BASE/lib/profile-stats.sh" ]]; then
  source "$WW_BASE/lib/profile-stats.sh"
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

get_profile_dir() {
  local profile_name="${1:-$WARRIOR_PROFILE}"

  if [[ -z "$profile_name" ]]; then
    return 1
  fi

  local profile_dir="$WW_BASE/profiles/$profile_name"
  if [[ -d "$profile_dir" ]]; then
    echo "$profile_dir"
  else
    return 1
  fi
}

require_active_profile() {
  if [[ -z "$WARRIOR_PROFILE" ]]; then
    log_error "No active profile. Activate one with: p-<profile-name>"
    exit 1
  fi
}

get_profile_meta_file() {
  local profile_dir="$1"
  echo "$profile_dir/profile.yaml"
}

# ============================================================================
# METADATA FUNCTIONS
# ============================================================================

# Initialize metadata file from template
init_profile_meta() {
  local profile_dir="$1"
  local meta_file
  meta_file=$(get_profile_meta_file "$profile_dir")

  if [[ ! -f "$meta_file" ]]; then
    if [[ -f "$PROFILE_META_TEMPLATE" ]]; then
      cp "$PROFILE_META_TEMPLATE" "$meta_file"
    else
      # Create minimal metadata
      cat > "$meta_file" << EOF
# Profile Metadata
identity:
  display_name: ""
  description: ""
contact:
  name: ""
  email: ""
  phone: ""
organization:
  company: ""
  role: ""
  website: ""
notes: ""
custom: {}
created: "$(date -Iseconds)"
modified: "$(date -Iseconds)"
EOF
    fi
    # Set creation date
    update_meta_field "$meta_file" "created" "$(date -Iseconds)"
  fi

  echo "$meta_file"
}

# Simple YAML field getter (supports nested keys like identity.description)
get_meta_field() {
  local meta_file="$1"
  local key="$2"

  if [[ ! -f "$meta_file" ]]; then
    return 1
  fi

  # Handle nested keys
  if [[ "$key" == *.* ]]; then
    local parent="${key%%.*}"
    local child="${key#*.}"
    # Look for the key under its parent
    awk -v parent="$parent" -v child="$child" '
      $0 ~ "^" parent ":" { in_parent=1; next }
      in_parent && /^[a-z]/ { in_parent=0 }
      in_parent && $0 ~ "^  " child ":" {
        sub(/^  [^:]+:[[:space:]]*"?/, "")
        sub(/"?[[:space:]]*$/, "")
        print
        exit
      }
    ' "$meta_file"
  else
    # Top-level key
    awk -v key="$key" '
      $0 ~ "^" key ":" {
        sub(/^[^:]+:[[:space:]]*"?/, "")
        sub(/"?[[:space:]]*$/, "")
        print
        exit
      }
    ' "$meta_file"
  fi
}

# Simple YAML field setter
update_meta_field() {
  local meta_file="$1"
  local key="$2"
  local value="$3"

  if [[ ! -f "$meta_file" ]]; then
    return 1
  fi

  local temp_file="${meta_file}.tmp"

  # Handle nested keys
  if [[ "$key" == *.* ]]; then
    local parent="${key%%.*}"
    local child="${key#*.}"

    awk -v parent="$parent" -v child="$child" -v value="$value" '
      $0 ~ "^" parent ":" { in_parent=1; print; next }
      in_parent && /^[a-z]/ { in_parent=0 }
      in_parent && $0 ~ "^  " child ":" {
        print "  " child ": \"" value "\""
        next
      }
      { print }
    ' "$meta_file" > "$temp_file"
  else
    # Top-level key
    awk -v key="$key" -v value="$value" '
      $0 ~ "^" key ":" {
        print key ": \"" value "\""
        next
      }
      { print }
    ' "$meta_file" > "$temp_file"
  fi

  mv "$temp_file" "$meta_file"

  # Update modified timestamp
  if [[ "$key" != "modified" && "$key" != "created" ]]; then
    update_meta_field "$meta_file" "modified" "$(date -Iseconds)"
  fi
}

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

# Display profile card with metadata and activity summary
display_profile_card() {
  local profile_name="$1"
  local profile_dir
  profile_dir=$(get_profile_dir "$profile_name") || {
    log_error "Profile not found: $profile_name"
    exit 1
  }

  local meta_file
  meta_file=$(get_profile_meta_file "$profile_dir")

  # Get metadata (if exists)
  local display_name description contact_name contact_email
  local org_company org_role created

  if [[ -f "$meta_file" ]]; then
    display_name=$(get_meta_field "$meta_file" "identity.display_name")
    description=$(get_meta_field "$meta_file" "identity.description")
    contact_name=$(get_meta_field "$meta_file" "contact.name")
    contact_email=$(get_meta_field "$meta_file" "contact.email")
    org_company=$(get_meta_field "$meta_file" "organization.company")
    org_role=$(get_meta_field "$meta_file" "organization.role")
    created=$(get_meta_field "$meta_file" "created")
  fi

  # Get statistics
  get_profile_summary "$profile_dir"
  local last_activity
  last_activity=$(get_last_activity "$profile_dir")

  local width=60

  # Header
  echo ""
  printf '%*s\n' "$width" '' | tr ' ' '='
  printf "  PROFILE: %s\n" "${display_name:-$profile_name}"
  printf '%*s\n' "$width" '' | tr ' ' '-'

  # Description
  if [[ -n "$description" ]]; then
    echo "  $description"
    echo ""
  fi

  # Contact info
  if [[ -n "$contact_name" || -n "$contact_email" ]]; then
    local contact_line="  Contact: "
    [[ -n "$contact_name" ]] && contact_line+="$contact_name"
    [[ -n "$contact_email" ]] && contact_line+=" <$contact_email>"
    echo "$contact_line"
  fi

  # Organization
  if [[ -n "$org_company" || -n "$org_role" ]]; then
    local org_line="  Organization: "
    [[ -n "$org_company" ]] && org_line+="$org_company"
    [[ -n "$org_role" ]] && org_line+=" ($org_role)"
    echo "$org_line"
  fi

  # Created date
  if [[ -n "$created" ]]; then
    echo "  Created: ${created%%T*}"
  fi

  echo ""
  printf '%*s\n' "$width" '' | tr ' ' '-'
  echo "  ACTIVITY SUMMARY"
  echo ""

  # Task stats
  if [[ "$PROFILE_TASKS_TOTAL" -gt 0 ]]; then
    printf "  %-12s %s pending, %s completed\n" "Tasks" "$PROFILE_TASKS_PENDING" "$PROFILE_TASKS_COMPLETED"
  else
    printf "  %-12s no tasks\n" "Tasks"
  fi

  # Time stats
  if [[ "$PROFILE_TIME_ENTRIES" -gt 0 ]]; then
    printf "  %-12s %s hrs this week, %s hrs this month\n" "Time" "$PROFILE_TIME_WEEK" "$PROFILE_TIME_MONTH"
  else
    printf "  %-12s no time tracked\n" "Time"
  fi

  # Journal stats
  if [[ "$PROFILE_JOURNAL_TOTAL" -gt 0 ]]; then
    printf "  %-12s %s entries across %s journal(s)\n" "Journal" "$PROFILE_JOURNAL_TOTAL" "$PROFILE_JOURNAL_COUNT"
  else
    printf "  %-12s no entries\n" "Journal"
  fi

  # Ledger stats
  if [[ "$PROFILE_LEDGER_TXNS" -gt 0 ]]; then
    printf "  %-12s %s transactions, %s accounts\n" "Ledger" "$PROFILE_LEDGER_TXNS" "$PROFILE_LEDGER_ACCTS"
  else
    printf "  %-12s no transactions\n" "Ledger"
  fi

  echo ""

  # Last activity
  if [[ -n "$last_activity" ]]; then
    local activity_time="${last_activity%%|*}"
    local activity_source="${last_activity##*|}"
    local relative_time
    relative_time=$(format_relative_time "$activity_time")
    echo "  Last activity: $relative_time ($activity_source)"
  else
    echo "  Last activity: none"
  fi

  printf '%*s\n' "$width" '' | tr ' ' '='
  echo ""
}

# Display detailed statistics
display_profile_stats() {
  local profile_name="$1"
  local profile_dir
  profile_dir=$(get_profile_dir "$profile_name") || {
    log_error "Profile not found: $profile_name"
    exit 1
  }

  echo ""
  echo "Profile Statistics: $profile_name"
  echo "========================"
  echo ""

  # Task stats
  local task_stats
  task_stats=$(get_task_stats "$profile_dir")
  local pending completed waiting total projects
  pending=$(echo "$task_stats" | cut -d'|' -f1)
  completed=$(echo "$task_stats" | cut -d'|' -f2)
  waiting=$(echo "$task_stats" | cut -d'|' -f3)
  total=$(echo "$task_stats" | cut -d'|' -f4)
  projects=$(echo "$task_stats" | cut -d'|' -f5)

  echo "TASKS (TaskWarrior)"
  echo "  Status:     $pending pending, $waiting waiting, $completed completed"
  echo "  Projects:   $projects"
  echo "  Total:      $total tasks"
  echo ""

  # Time stats
  local time_stats
  time_stats=$(get_time_stats "$profile_dir")
  local total_hrs week_hrs month_hrs entries
  total_hrs=$(echo "$time_stats" | cut -d'|' -f1)
  week_hrs=$(echo "$time_stats" | cut -d'|' -f2)
  month_hrs=$(echo "$time_stats" | cut -d'|' -f3)
  entries=$(echo "$time_stats" | cut -d'|' -f4)

  echo "TIME (TimeWarrior)"
  echo "  This week:  $week_hrs hours"
  echo "  This month: $month_hrs hours"
  echo "  Total:      $total_hrs hours ($entries entries)"
  echo ""

  # Journal stats
  local journal_stats
  journal_stats=$(get_journal_stats "$profile_dir")
  local j_total j_count j_month
  j_total=$(echo "$journal_stats" | cut -d'|' -f1)
  j_count=$(echo "$journal_stats" | cut -d'|' -f2)
  j_month=$(echo "$journal_stats" | cut -d'|' -f3)

  echo "JOURNAL (JRNL)"
  echo "  Entries:    $j_total total"
  echo "  Journals:   $j_count"
  echo "  This month: $j_month entries"
  echo ""

  # Ledger stats
  local ledger_stats
  ledger_stats=$(get_ledger_stats "$profile_dir")
  local l_txns l_accts l_count
  l_txns=$(echo "$ledger_stats" | cut -d'|' -f1)
  l_accts=$(echo "$ledger_stats" | cut -d'|' -f2)
  l_count=$(echo "$ledger_stats" | cut -d'|' -f3)

  echo "LEDGER (Hledger)"
  echo "  Transactions: $l_txns"
  echo "  Accounts:     $l_accts"
  echo "  Ledgers:      $l_count"
  echo ""
}

# Display metadata
display_profile_meta() {
  local profile_name="$1"
  local profile_dir
  profile_dir=$(get_profile_dir "$profile_name") || {
    log_error "Profile not found: $profile_name"
    exit 1
  }

  local meta_file
  meta_file=$(get_profile_meta_file "$profile_dir")

  if [[ -f "$meta_file" ]]; then
    echo ""
    echo "Profile Metadata: $profile_name"
    echo "========================"
    echo ""
    # Filter out comments for cleaner display
    grep -v '^#' "$meta_file" | grep -v '^$'
    echo ""
  else
    echo ""
    echo "No metadata file found for profile: $profile_name"
    echo "Create one with: profile meta edit"
    echo ""
  fi
}

# ============================================================================
# META SUBCOMMAND
# ============================================================================

cmd_meta() {
  local action="${1:-show}"
  shift 2>/dev/null || true

  require_active_profile
  local profile_dir
  profile_dir=$(get_profile_dir "$WARRIOR_PROFILE")

  case "$action" in
    show|"")
      display_profile_meta "$WARRIOR_PROFILE"
      ;;
    edit)
      local meta_file
      meta_file=$(init_profile_meta "$profile_dir")
      ${EDITOR:-nano} "$meta_file"
      update_meta_field "$meta_file" "modified" "$(date -Iseconds)"
      log_success "Metadata updated"
      ;;
    set)
      local key="$1"
      local value="$2"
      if [[ -z "$key" || -z "$value" ]]; then
        log_error "Usage: profile meta set <key> <value>"
        log_info "Example: profile meta set identity.description 'My work profile'"
        exit 1
      fi
      local meta_file
      meta_file=$(init_profile_meta "$profile_dir")
      update_meta_field "$meta_file" "$key" "$value"
      log_success "Set $key = $value"
      ;;
    get)
      local key="$1"
      if [[ -z "$key" ]]; then
        log_error "Usage: profile meta get <key>"
        exit 1
      fi
      local meta_file
      meta_file=$(get_profile_meta_file "$profile_dir")
      if [[ -f "$meta_file" ]]; then
        get_meta_field "$meta_file" "$key"
      else
        log_error "No metadata file found"
        exit 1
      fi
      ;;
    *)
      log_error "Unknown meta action: $action"
      echo "Usage: profile meta [show|edit|set|get]"
      exit 1
      ;;
  esac
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
  cat << 'EOF'
Profile Tool - View and manage profile metadata and statistics

Usage: profile [command] [arguments]
       p [command] [arguments]

Commands:
  (none)              Show profile card (metadata + activity summary)
  info [name]         Show profile info (defaults to active profile)
  stats [name]        Show detailed statistics
  meta                Show metadata for active profile
  meta edit           Edit metadata interactively
  meta set <k> <v>    Set a metadata field
  meta get <key>      Get a metadata field value
  help                Show this help

Metadata Fields:
  identity.display_name    Human-readable profile name
  identity.description     What this profile is for
  contact.name             Contact person name
  contact.email            Contact email
  contact.phone            Contact phone
  organization.company     Organization name
  organization.role        Role/position
  organization.website     Website URL
  notes                    Free-form notes

Examples:
  profile                               Show active profile card
  profile info work                     Show info for 'work' profile
  profile stats                         Show detailed statistics
  profile meta edit                     Edit metadata interactively
  profile meta set identity.description "Client projects"
  profile meta get contact.email

Note: Most commands require an active profile.
Activate with: p-<profile-name>

EOF
}

# ============================================================================
# MAIN DISPATCHER
# ============================================================================

main() {
  local command="${1:-}"
  shift 2>/dev/null || true

  case "$command" in
    "")
      # Default: show profile card for active profile
      require_active_profile
      display_profile_card "$WARRIOR_PROFILE"
      ;;
    info)
      local profile_name="${1:-$WARRIOR_PROFILE}"
      if [[ -z "$profile_name" ]]; then
        log_error "No profile specified and no active profile"
        exit 1
      fi
      display_profile_card "$profile_name"
      ;;
    stats)
      local profile_name="${1:-$WARRIOR_PROFILE}"
      if [[ -z "$profile_name" ]]; then
        log_error "No profile specified and no active profile"
        exit 1
      fi
      display_profile_stats "$profile_name"
      ;;
    meta)
      cmd_meta "$@"
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      log_error "Unknown command: $command"
      echo "Run 'profile help' for usage"
      exit 1
      ;;
  esac
}

main "$@"
