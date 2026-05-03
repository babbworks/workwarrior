#!/usr/bin/env bash
# Export Service - Export profile data in multiple formats
# Usage: export [type] [options]

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

WW_BASE="${WW_BASE:-$HOME/ww}"
EXPORT_DIR="${WW_BASE}/exports"

# Source libraries
if [[ -f "$WW_BASE/lib/core-utils.sh" ]]; then
  source "$WW_BASE/lib/core-utils.sh"
else
  log_info() { echo "info: $*"; }
  log_error() { echo "error: $*" >&2; }
  log_success() { echo "ok: $*"; }
  log_warning() { echo "warn: $*"; }
fi

if [[ -f "$WW_BASE/lib/export-utils.sh" ]]; then
  source "$WW_BASE/lib/export-utils.sh"
else
  log_error "Export utilities library not found"
  exit 1
fi

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

EXPORT_TYPE=""
EXPORT_FORMAT="json"
OUTPUT_PATH=""
PROFILE_NAME=""
DATE_FROM=""
DATE_TO=""

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      tasks|time|journal|ledger|all|backup)
        EXPORT_TYPE="$1"
        shift
        # Check if next arg is a format
        if [[ "${1:-}" =~ ^(json|csv|markdown|md)$ ]]; then
          EXPORT_FORMAT="$1"
          [[ "$EXPORT_FORMAT" == "md" ]] && EXPORT_FORMAT="markdown"
          shift
        fi
        ;;
      -f|--format)
        EXPORT_FORMAT="$2"
        [[ "$EXPORT_FORMAT" == "md" ]] && EXPORT_FORMAT="markdown"
        shift 2
        ;;
      -o|--output)
        OUTPUT_PATH="$2"
        shift 2
        ;;
      -p|--profile)
        PROFILE_NAME="$2"
        shift 2
        ;;
      --from)
        DATE_FROM="$2"
        shift 2
        ;;
      --to)
        DATE_TO="$2"
        shift 2
        ;;
      -h|--help|help)
        show_help
        exit 0
        ;;
      *)
        log_error "Unknown argument: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

require_profile() {
  if [[ -z "$PROFILE_NAME" ]]; then
    PROFILE_NAME="$WARRIOR_PROFILE"
  fi

  if [[ -z "$PROFILE_NAME" ]]; then
    log_error "No profile specified and no active profile"
    log_info "Use: export --profile <name> or activate a profile with p-<name>"
    exit 1
  fi

  local profile_dir="$WW_BASE/profiles/$PROFILE_NAME"
  if [[ ! -d "$profile_dir" ]]; then
    log_error "Profile not found: $PROFILE_NAME"
    exit 1
  fi

  echo "$profile_dir"
}

validate_format() {
  case "$EXPORT_FORMAT" in
    json|csv|markdown) ;;
    *)
      log_error "Invalid format: $EXPORT_FORMAT"
      log_info "Supported formats: json, csv, markdown"
      exit 1
      ;;
  esac
}

get_date_filter() {
  local filter=""
  if [[ -n "$DATE_FROM" ]]; then
    filter+="from:$DATE_FROM "
  fi
  if [[ -n "$DATE_TO" ]]; then
    filter+="to:$DATE_TO "
  fi
  echo "$filter"
}

# ============================================================================
# EXPORT COMMANDS
# ============================================================================

do_export_tasks() {
  local profile_dir="$1"
  local output_file
  output_file=$(get_export_path "$PROFILE_NAME" "tasks" "$EXPORT_FORMAT" "$OUTPUT_PATH")

  log_info "Exporting tasks as $EXPORT_FORMAT..."

  local result
  case "$EXPORT_FORMAT" in
    json)
      result=$(export_tasks_json "$profile_dir" "$output_file")
      ;;
    csv)
      result=$(export_tasks_csv "$profile_dir" "$output_file")
      ;;
    markdown)
      result=$(export_tasks_markdown "$profile_dir" "$output_file")
      ;;
  esac

  if [[ -f "$result" ]]; then
    log_success "Exported to: $result"
  else
    log_error "Export failed"
    exit 1
  fi
}

do_export_time() {
  local profile_dir="$1"
  local output_file
  output_file=$(get_export_path "$PROFILE_NAME" "time" "$EXPORT_FORMAT" "$OUTPUT_PATH")
  local filter
  filter=$(get_date_filter)

  log_info "Exporting time entries as $EXPORT_FORMAT..."

  local result
  case "$EXPORT_FORMAT" in
    json)
      result=$(export_time_json "$profile_dir" "$output_file" "$filter")
      ;;
    csv)
      result=$(export_time_csv "$profile_dir" "$output_file" "$filter")
      ;;
    markdown)
      result=$(export_time_markdown "$profile_dir" "$output_file" "$filter")
      ;;
  esac

  if [[ -f "$result" ]]; then
    log_success "Exported to: $result"
  else
    log_error "Export failed"
    exit 1
  fi
}

do_export_journal() {
  local profile_dir="$1"
  local output_file
  output_file=$(get_export_path "$PROFILE_NAME" "journal" "$EXPORT_FORMAT" "$OUTPUT_PATH")

  log_info "Exporting journal entries as $EXPORT_FORMAT..."

  local result
  case "$EXPORT_FORMAT" in
    json)
      result=$(export_journal_json "$profile_dir" "$output_file")
      ;;
    csv)
      result=$(export_journal_csv "$profile_dir" "$output_file")
      ;;
    markdown)
      result=$(export_journal_markdown "$profile_dir" "$output_file")
      ;;
  esac

  if [[ -f "$result" ]]; then
    log_success "Exported to: $result"
  else
    log_error "Export failed"
    exit 1
  fi
}

do_export_ledger() {
  local profile_dir="$1"
  local output_file
  output_file=$(get_export_path "$PROFILE_NAME" "ledger" "$EXPORT_FORMAT" "$OUTPUT_PATH")

  log_info "Exporting ledger data as $EXPORT_FORMAT..."

  local result
  case "$EXPORT_FORMAT" in
    json)
      result=$(export_ledger_json "$profile_dir" "$output_file")
      ;;
    csv)
      result=$(export_ledger_csv "$profile_dir" "$output_file")
      ;;
    markdown)
      result=$(export_ledger_markdown "$profile_dir" "$output_file")
      ;;
  esac

  if [[ -f "$result" ]]; then
    log_success "Exported to: $result"
  else
    log_error "Export failed"
    exit 1
  fi
}

do_export_all() {
  local profile_dir="$1"

  if [[ "$EXPORT_FORMAT" == "json" ]]; then
    local output_file
    output_file=$(get_export_path "$PROFILE_NAME" "all" "json" "$OUTPUT_PATH")

    log_info "Exporting all data as JSON..."

    local result
    result=$(export_all_json "$profile_dir" "$output_file")

    if [[ -f "$result" ]]; then
      log_success "Exported to: $result"
    else
      log_error "Export failed"
      exit 1
    fi
  else
    # For CSV/Markdown, export each type separately
    log_info "Exporting all data as $EXPORT_FORMAT (multiple files)..."

    local base_output="$OUTPUT_PATH"

    OUTPUT_PATH="${base_output:-}"
    [[ -n "$base_output" ]] && OUTPUT_PATH="${base_output%.*}_tasks.${EXPORT_FORMAT}"
    do_export_tasks "$profile_dir"

    OUTPUT_PATH="${base_output:-}"
    [[ -n "$base_output" ]] && OUTPUT_PATH="${base_output%.*}_time.${EXPORT_FORMAT}"
    do_export_time "$profile_dir"

    OUTPUT_PATH="${base_output:-}"
    [[ -n "$base_output" ]] && OUTPUT_PATH="${base_output%.*}_journal.${EXPORT_FORMAT}"
    do_export_journal "$profile_dir"

    OUTPUT_PATH="${base_output:-}"
    [[ -n "$base_output" ]] && OUTPUT_PATH="${base_output%.*}_ledger.${EXPORT_FORMAT}"
    do_export_ledger "$profile_dir"

    log_success "All exports complete"
  fi
}

do_export_backup() {
  local profile_dir="$1"
  local output_file
  output_file=$(get_export_path "$PROFILE_NAME" "backup" "tar.gz" "$OUTPUT_PATH")

  log_info "Creating full backup of profile: $PROFILE_NAME..."

  local result
  result=$(export_profile_backup "$profile_dir" "$output_file")

  if [[ -f "$result" ]]; then
    local size
    size=$(du -h "$result" | cut -f1)
    log_success "Backup created: $result ($size)"
  else
    log_error "Backup failed"
    exit 1
  fi
}

# ============================================================================
# INTERACTIVE MODE
# ============================================================================

interactive_export() {
  echo ""
  echo "Export Profile Data"
  echo "==================="
  echo ""

  # Select profile
  if [[ -z "$PROFILE_NAME" ]]; then
    PROFILE_NAME="$WARRIOR_PROFILE"
  fi

  if [[ -z "$PROFILE_NAME" ]]; then
    echo "Available profiles:"
    local profiles=()
    for dir in "$WW_BASE/profiles/"*/; do
      if [[ -d "$dir" ]]; then
        local name
        name=$(basename "$dir")
        profiles+=("$name")
        echo "  - $name"
      fi
    done
    echo ""
    read -p "Enter profile name: " PROFILE_NAME

    if [[ -z "$PROFILE_NAME" ]]; then
      log_error "No profile selected"
      exit 1
    fi
  fi

  echo "Profile: $PROFILE_NAME"
  echo ""

  # Select type
  echo "What would you like to export?"
  echo "  1. tasks     - TaskWarrior tasks"
  echo "  2. time      - TimeWarrior time entries"
  echo "  3. journal   - JRNL journal entries"
  echo "  4. ledger    - Hledger transactions"
  echo "  5. all       - All data combined"
  echo "  6. backup    - Full profile backup (tar.gz)"
  echo ""
  read -p "Enter choice (1-6 or name): " type_choice

  case "$type_choice" in
    1|tasks) EXPORT_TYPE="tasks" ;;
    2|time) EXPORT_TYPE="time" ;;
    3|journal) EXPORT_TYPE="journal" ;;
    4|ledger) EXPORT_TYPE="ledger" ;;
    5|all) EXPORT_TYPE="all" ;;
    6|backup) EXPORT_TYPE="backup" ;;
    *)
      log_error "Invalid choice"
      exit 1
      ;;
  esac

  # Select format (unless backup)
  if [[ "$EXPORT_TYPE" != "backup" ]]; then
    echo ""
    echo "Select format:"
    echo "  1. json      - JSON (structured, parseable)"
    echo "  2. csv       - CSV (spreadsheet compatible)"
    echo "  3. markdown  - Markdown (human readable)"
    echo ""
    read -p "Enter choice (1-3 or name) [json]: " format_choice

    case "$format_choice" in
      1|json|"") EXPORT_FORMAT="json" ;;
      2|csv) EXPORT_FORMAT="csv" ;;
      3|markdown|md) EXPORT_FORMAT="markdown" ;;
      *)
        log_error "Invalid format"
        exit 1
        ;;
    esac
  fi

  echo ""

  # Execute export
  run_export
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

run_export() {
  local profile_dir
  profile_dir=$(require_profile)

  validate_format

  case "$EXPORT_TYPE" in
    tasks)
      do_export_tasks "$profile_dir"
      ;;
    time)
      do_export_time "$profile_dir"
      ;;
    journal)
      do_export_journal "$profile_dir"
      ;;
    ledger)
      do_export_ledger "$profile_dir"
      ;;
    all)
      do_export_all "$profile_dir"
      ;;
    backup)
      do_export_backup "$profile_dir"
      ;;
    *)
      log_error "Unknown export type: $EXPORT_TYPE"
      exit 1
      ;;
  esac
}

show_help() {
  cat << 'EOF'
Export Service - Export profile data in multiple formats

Usage: export [type] [format] [options]
       ww export [type] [format] [options]

Types:
  tasks       Export TaskWarrior tasks
  time        Export TimeWarrior time entries
  journal     Export JRNL journal entries
  ledger      Export Hledger transactions
  all         Export all profile data
  backup      Create full profile backup (tar.gz)

Formats:
  json        JSON format (default)
  csv         CSV format (spreadsheet compatible)
  markdown    Markdown format (human readable)

Options:
  -f, --format <fmt>     Output format (json, csv, markdown)
  -o, --output <path>    Output file path
  -p, --profile <name>   Profile to export (default: active profile)
  --from <date>          Filter: start date (YYYY-MM-DD)
  --to <date>            Filter: end date (YYYY-MM-DD)
  -h, --help             Show this help

Examples:
  export                           Interactive mode
  export tasks                     Export tasks as JSON
  export tasks csv                 Export tasks as CSV
  export time markdown             Export time as Markdown
  export all json                  Export all data as JSON
  export backup                    Create full backup
  export tasks -o /tmp/tasks.json  Export to specific file
  export time --from 2024-01-01    Export time from date
  export -p work tasks             Export from specific profile

Output:
  Default: ~/ww/exports/<profile>/<timestamp>_<type>.<format>

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  parse_arguments "$@"

  # Create exports directory
  mkdir -p "$EXPORT_DIR"

  if [[ -z "$EXPORT_TYPE" ]]; then
    # Interactive mode
    interactive_export
  else
    # Direct export
    run_export
  fi
}

main "$@"
