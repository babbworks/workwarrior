#!/usr/bin/env bash
# Service: configure-ledgers
# Category: custom
# Description: Interactive guide for configuring Hledger settings

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"
source "$SCRIPT_DIR/../../lib/config-utils.sh"

# ============================================================================
# CONFIGURATION
# ============================================================================

LEDGER_CONFIG=""
PROFILE_NAME=""
PROFILE_BASE=""

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

show_banner() {
  echo ""
  echo "============================================================"
  echo "         Hledger Configuration Guide"
  echo "============================================================"
  echo "Direct commands are also available:"
  echo "  ww ledger add <name> | list | remove <name> | rename <old> <new>"
  echo ""
}

check_active_profile() {
  if ! require_active_profile; then
    exit 1
  fi

  PROFILE_BASE="$WORKWARRIOR_BASE"
  PROFILE_NAME="$WARRIOR_PROFILE"
  LEDGER_CONFIG="$PROFILE_BASE/ledgers.yaml"

  if [[ ! -f "$LEDGER_CONFIG" ]]; then
    log_error "Ledger configuration not found: $LEDGER_CONFIG"
    exit 1
  fi
}

backup_ledger_config() {
  local ts
  ts=$(date "+%Y%m%d%H%M%S")
  local backup_file="${LEDGER_CONFIG}.bak.${ts}"
  cp "$LEDGER_CONFIG" "$backup_file"
  log_info "Backup saved: $backup_file"
}

list_ledgers() {
  echo "Current ledgers in profile '$PROFILE_NAME':"
  echo ""
  grep "^  [a-zA-Z0-9_-]\+:" "$LEDGER_CONFIG" | sed 's/^  /  • /' || echo "  (none)"
  echo ""
  echo "Default ledger:"
  local default_path
  default_path=$(grep "^  default:" "$LEDGER_CONFIG" | awk -F": " '{print $2}')
  if [[ -n "$default_path" ]]; then
    echo "  • $default_path"
  else
    echo "  (not set)"
  fi
}

get_ledger_path_by_name() {
  local name="$1"
  grep "^  ${name}:" "$LEDGER_CONFIG" | awk -F": " '{print $2}'
}

validate_ledger_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    log_error "Ledger name cannot be empty"
    return 1
  fi
  if [[ "$name" =~ [^a-zA-Z0-9_-] ]]; then
    log_error "Ledger name can only contain letters, numbers, hyphens, and underscores"
    return 1
  fi
  return 0
}

# ============================================================================
# CONFIGURATION SECTIONS
# ============================================================================

configure_ledgers() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Ledger Management"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  list_ledgers
  echo ""
  echo "  1. Add ledger"
  echo "  2. Set default ledger"
  echo "  3. Remove ledger"
  echo "  4. Back"
  echo ""
  read -p "Choose option [1-4]: " choice

  case "$choice" in
    1) add_new_ledger ;;
    2) set_default_ledger ;;
    3) remove_ledger ;;
    4) return 0 ;;
    *) log_error "Invalid choice" ;;
  esac
}

add_new_ledger() {
  echo ""
  read -p "Enter ledger name (e.g., personal, business, taxes): " ledger_name
  if ! validate_ledger_name "$ledger_name"; then
    return 1
  fi

  if grep -q "^  ${ledger_name}:" "$LEDGER_CONFIG"; then
    log_error "Ledger '$ledger_name' already exists"
    return 1
  fi

  local ledger_file="$PROFILE_BASE/ledgers/${ledger_name}.journal"
  echo ""
  echo "Ledger will be created at: $ledger_file"
  read -p "Continue? [y/n]: " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cancelled"
    return 0
  fi

  mkdir -p "$(dirname "$ledger_file")"
  if [[ ! -f "$ledger_file" ]]; then
    touch "$ledger_file"
    log_success "Created ledger file: $ledger_file"
  fi

  backup_ledger_config
  awk -v lname="$ledger_name" -v lpath="$ledger_file" '
    /^ledgers:/ { print; in_ledgers=1; next }
    in_ledgers && /^[^ ]/ { print "  " lname ": " lpath; in_ledgers=0 }
    { print }
    END { if (in_ledgers) print "  " lname ": " lpath }
  ' "$LEDGER_CONFIG" > "$LEDGER_CONFIG.tmp"
  mv "$LEDGER_CONFIG.tmp" "$LEDGER_CONFIG"

  log_success "Added ledger '$ledger_name' to configuration"
}

set_default_ledger() {
  echo ""
  list_ledgers
  echo ""
  read -p "Enter ledger name to set as default: " ledger_name
  if ! validate_ledger_name "$ledger_name"; then
    return 1
  fi

  local ledger_path
  ledger_path=$(get_ledger_path_by_name "$ledger_name")
  if [[ -z "$ledger_path" ]]; then
    log_error "Ledger not found: $ledger_name"
    return 1
  fi

  backup_ledger_config
  if ! sed -i.bak "s|^  default:.*|  default: $ledger_path|" "$LEDGER_CONFIG"; then
    log_error "Failed to update default ledger"
    return 1
  fi
  rm -f "$LEDGER_CONFIG.bak"
  log_success "Default ledger updated to: $ledger_path"
}

remove_ledger() {
  echo ""
  list_ledgers
  echo ""
  read -p "Enter ledger name to remove: " ledger_name
  if ! validate_ledger_name "$ledger_name"; then
    return 1
  fi

  if ! grep -q "^  ${ledger_name}:" "$LEDGER_CONFIG"; then
    log_error "Ledger not found: $ledger_name"
    return 1
  fi

  read -p "Remove ledger mapping '$ledger_name' from config? [y/n]: " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cancelled"
    return 0
  fi

  backup_ledger_config
  if ! sed -i.bak "/^  ${ledger_name}:/d" "$LEDGER_CONFIG"; then
    log_error "Failed to update ledger configuration"
    return 1
  fi
  rm -f "$LEDGER_CONFIG.bak"
  log_success "Removed ledger '$ledger_name' from configuration"
}

initialize_ledger() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Initialize Ledger"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  local default_ledger
  default_ledger=$(grep "^  default:" "$LEDGER_CONFIG" | awk -F": " '{print $2}')
  if [[ -z "$default_ledger" ]]; then
    log_error "Default ledger not configured"
    return 1
  fi

  if [[ ! -f "$default_ledger" ]]; then
    log_error "Ledger file not found: $default_ledger"
    return 1
  fi

  if [[ -s "$default_ledger" ]]; then
    echo "Ledger already has content:"
    echo "  $default_ledger"
    read -p "Append a starter template anyway? [y/n]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      log_info "Cancelled"
      return 0
    fi
  fi

  local current_date
  current_date=$(date "+%Y-%m-%d")

  cat >> "$default_ledger" << EOF

; Hledger Journal for profile: $PROFILE_NAME
; Created: $(date)

; Account declarations
account Assets:Checking
account Assets:Savings
account Expenses:Food
account Expenses:Transportation
account Expenses:Utilities
account Expenses:Entertainment
account Income:Salary
account Liabilities:CreditCard
account Equity:Opening Balances

; Opening entry
$current_date * Opening Balance
    Assets:Checking                 \$0.00
    Equity:Opening Balances

EOF

  log_success "Initialized ledger: $default_ledger"
}

run_hledger_add() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Hledger Add"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if ! command -v hledger &>/dev/null; then
    log_error "hledger is not installed or not in PATH"
    return 1
  fi

  local default_ledger
  default_ledger=$(grep "^  default:" "$LEDGER_CONFIG" | awk -F": " '{print $2}')
  if [[ -z "$default_ledger" ]]; then
    log_error "Default ledger not configured"
    return 1
  fi

  if [[ ! -f "$default_ledger" ]]; then
    log_error "Ledger file not found: $default_ledger"
    return 1
  fi

  hledger -f "$default_ledger" add
}

validate_ledger() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Ledger Validation"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if ! command -v hledger &>/dev/null; then
    log_error "hledger is not installed or not in PATH"
    return 1
  fi

  local default_ledger
  default_ledger=$(grep "^  default:" "$LEDGER_CONFIG" | awk -F": " '{print $2}')
  if [[ -z "$default_ledger" ]]; then
    log_error "Default ledger not configured"
    return 1
  fi

  if [[ ! -f "$default_ledger" ]]; then
    log_error "Ledger file not found: $default_ledger"
    return 1
  fi

  if hledger -f "$default_ledger" check; then
    log_success "Ledger validation: OK"
  else
    log_warning "Ledger validation reported issues"
  fi
}

quick_reports() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Quick Reports"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if ! command -v hledger &>/dev/null; then
    log_error "hledger is not installed or not in PATH"
    return 1
  fi

  local default_ledger
  default_ledger=$(grep "^  default:" "$LEDGER_CONFIG" | awk -F": " '{print $2}')
  if [[ -z "$default_ledger" ]]; then
    log_error "Default ledger not configured"
    return 1
  fi

  if [[ ! -f "$default_ledger" ]]; then
    log_error "Ledger file not found: $default_ledger"
    return 1
  fi

  echo "  1. balance"
  echo "  2. register"
  echo "  3. balancesheet"
  echo "  4. incomestatement"
  echo "  5. back"
  echo ""
  read -p "Choose report [1-5]: " report

  case "$report" in
    1) hledger -f "$default_ledger" balance ;;
    2) hledger -f "$default_ledger" register ;;
    3) hledger -f "$default_ledger" balancesheet ;;
    4) hledger -f "$default_ledger" incomestatement ;;
    5) return 0 ;;
    *) log_error "Invalid choice" ;;
  esac
}

# ============================================================================
# MAIN MENU
# ============================================================================

show_main_menu() {
  while true; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Configuration Menu - Profile: $PROFILE_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Manage ledgers (add/set/remove)"
    echo "  2. Initialize default ledger"
    echo "  3. Add transaction (hledger add)"
    echo "  4. Validate ledger (hledger check)"
    echo "  5. Quick reports"
    echo "  6. View ledgers.yaml"
    echo "  7. Exit"
    echo ""
    read -p "Choose option [1-7]: " choice

    case "$choice" in
      1) configure_ledgers ;;
      2) initialize_ledger ;;
      3) run_hledger_add ;;
      4) validate_ledger ;;
      5) quick_reports ;;
      6) cat "$LEDGER_CONFIG" ;;
      7)
        echo ""
        log_success "Configuration complete!"
        echo ""
        echo "Changes saved to: $LEDGER_CONFIG"
        echo ""
        exit 0
        ;;
      *)
        log_error "Invalid choice"
        ;;
    esac
  done
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  show_banner
  check_active_profile
  show_main_menu
}

main "$@"
