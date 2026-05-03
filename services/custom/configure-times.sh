#!/usr/bin/env bash
# Service: configure-times
# Category: custom
# Description: Interactive guide for configuring TimeWarrior settings

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"

# ============================================================================
# CONFIGURATION
# ============================================================================

TIMEW_CONFIG=""
PROFILE_NAME=""
PROFILE_BASE=""

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

show_banner() {
  echo ""
  echo "============================================================"
  echo "         TimeWarrior Configuration Guide"
  echo "============================================================"
  echo ""
}

check_active_profile() {
  if [[ -z "${WORKWARRIOR_BASE:-}" ]]; then
    log_error "No active profile. Activate a profile first with: p-<profile-name>"
    exit 1
  fi
  
  PROFILE_BASE="$WORKWARRIOR_BASE"
  PROFILE_NAME="$WARRIOR_PROFILE"
  TIMEW_CONFIG="$PROFILE_BASE/.timewarrior/timewarrior.cfg"
  
  # Create config file if it doesn't exist
  if [[ ! -f "$TIMEW_CONFIG" ]]; then
    mkdir -p "$(dirname "$TIMEW_CONFIG")"
    touch "$TIMEW_CONFIG"
    log_info "Created TimeWarrior configuration: $TIMEW_CONFIG"
  fi
}

# ============================================================================
# CONFIGURATION SECTIONS
# ============================================================================

configure_basic_settings() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Basic Settings"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Confirmation
  local current_confirm
  current_confirm=$(grep "^confirmation" "$TIMEW_CONFIG" | awk '{print $3}' || echo "on")
  echo "Current confirmation prompts: ${current_confirm:-on}"
  echo ""
  echo "Confirmation prompts ask before performing destructive operations."
  echo ""
  read -p "Enable confirmation prompts? [y/n, or Enter to keep current]: " confirm
  
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    if grep -q "^confirmation" "$TIMEW_CONFIG"; then
      sed -i.bak "s|^confirmation.*|confirmation = on|" "$TIMEW_CONFIG"
    else
      echo "confirmation = on" >> "$TIMEW_CONFIG"
    fi
    log_success "Confirmation prompts enabled"
  elif [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
    if grep -q "^confirmation" "$TIMEW_CONFIG"; then
      sed -i.bak "s|^confirmation.*|confirmation = off|" "$TIMEW_CONFIG"
    else
      echo "confirmation = off" >> "$TIMEW_CONFIG"
    fi
    log_success "Confirmation prompts disabled"
  fi
  
  # Verbose
  echo ""
  local current_verbose
  current_verbose=$(grep "^verbose" "$TIMEW_CONFIG" | awk '{print $3}' || echo "on")
  echo "Current verbose mode: ${current_verbose:-on}"
  echo ""
  echo "Verbose mode provides feedback for operations."
  echo ""
  read -p "Enable verbose mode? [y/n, or Enter to keep current]: " verbose
  
  if [[ "$verbose" == "y" || "$verbose" == "Y" ]]; then
    if grep -q "^verbose" "$TIMEW_CONFIG"; then
      sed -i.bak "s|^verbose.*|verbose = on|" "$TIMEW_CONFIG"
    else
      echo "verbose = on" >> "$TIMEW_CONFIG"
    fi
    log_success "Verbose mode enabled"
  elif [[ "$verbose" == "n" || "$verbose" == "N" ]]; then
    if grep -q "^verbose" "$TIMEW_CONFIG"; then
      sed -i.bak "s|^verbose.*|verbose = off|" "$TIMEW_CONFIG"
    else
      echo "verbose = off" >> "$TIMEW_CONFIG"
    fi
    log_success "Verbose mode disabled"
  fi
}

configure_work_week() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Work Week Exclusions"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo "Work week exclusions define when you're NOT working."
  echo "This helps TimeWarrior automatically exclude non-working hours."
  echo ""
  echo "Current exclusions:"
  if grep -q "^define exclusions:" "$TIMEW_CONFIG"; then
    grep -A 10 "^define exclusions:" "$TIMEW_CONFIG" | grep "^  " || echo "  (none defined)"
  else
    echo "  (none defined)"
  fi
  
  echo ""
  echo "Would you like to configure work week exclusions?"
  echo "  1. Standard work week (9am-5pm, Mon-Fri, 30min lunch)"
  echo "  2. Custom work week"
  echo "  3. Clear all exclusions"
  echo "  4. Keep current settings"
  echo ""
  read -p "Choose option [1-4]: " choice
  
  case "$choice" in
    1)
      # Remove existing exclusions
      sed -i.bak '/^define exclusions:/,/^$/d' "$TIMEW_CONFIG"
      
      # Add standard work week
      cat >> "$TIMEW_CONFIG" << 'EOF'

define exclusions:
  monday    = <9:00 12:30-13:00 >17:00
  tuesday   = <9:00 12:30-13:00 >17:00
  wednesday = <9:00 12:30-13:00 >17:00
  thursday  = <9:00 12:30-13:00 >17:00
  friday    = <9:00 12:30-13:00 >17:00
  saturday  = >0:00
  sunday    = >0:00

EOF
      log_success "Standard work week configured (9am-5pm, Mon-Fri, 30min lunch at 12:30pm)"
      ;;
    2)
      configure_custom_work_week
      ;;
    3)
      sed -i.bak '/^define exclusions:/,/^$/d' "$TIMEW_CONFIG"
      log_success "All exclusions cleared"
      ;;
    4|"")
      log_info "Keeping current settings"
      ;;
    *)
      log_error "Invalid choice"
      ;;
  esac
}

configure_custom_work_week() {
  echo ""
  echo "Custom Work Week Configuration"
  echo ""
  echo "Format: <HH:MM means before this time"
  echo "        >HH:MM means after this time"
  echo "        HH:MM-HH:MM means between these times"
  echo ""
  echo "Example: <9:00 12:30-13:00 >17:00"
  echo "  (exclude before 9am, lunch 12:30-1pm, after 5pm)"
  echo ""
  
  # Remove existing exclusions
  sed -i.bak '/^define exclusions:/,/^$/d' "$TIMEW_CONFIG"
  
  echo "" >> "$TIMEW_CONFIG"
  echo "define exclusions:" >> "$TIMEW_CONFIG"
  
  for day in monday tuesday wednesday thursday friday saturday sunday; do
    read -p "Exclusions for $day (or Enter for none): " exclusions
    if [[ -n "$exclusions" ]]; then
      echo "  $day = $exclusions" >> "$TIMEW_CONFIG"
    fi
  done
  
  echo "" >> "$TIMEW_CONFIG"
  log_success "Custom work week configured"
}

configure_reports() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Report Settings"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo "Report settings control how time tracking reports are displayed."
  echo ""
  echo "Common settings:"
  echo "  • Cell size (minutes per character)"
  echo "  • Show holidays"
  echo "  • Show totals"
  echo "  • Show summary"
  echo ""
  
  # Cell size
  local current_cell
  current_cell=$(grep "reports.day.cell" "$TIMEW_CONFIG" | awk '{print $3}' || echo "15")
  echo "Current cell size: ${current_cell:-15} minutes"
  echo ""
  echo "Cell size determines how many minutes each character represents."
  echo "Common values: 15, 20, 30, 60"
  echo ""
  read -p "Enter cell size in minutes (or Enter to keep current): " cell
  
  if [[ -n "$cell" ]]; then
    if grep -q "reports.day.cell" "$TIMEW_CONFIG"; then
      sed -i.bak "s|reports.day.cell.*|reports.day.cell = $cell|" "$TIMEW_CONFIG"
    else
      echo "reports.day.cell = $cell" >> "$TIMEW_CONFIG"
    fi
    log_success "Cell size updated to: $cell minutes"
  fi
  
  # Holidays
  echo ""
  local current_holidays
  current_holidays=$(grep "reports.day.holidays" "$TIMEW_CONFIG" | awk '{print $3}' || echo "no")
  echo "Current holiday display: ${current_holidays:-no}"
  read -p "Show holidays in reports? [y/n, or Enter to keep current]: " holidays
  
  if [[ "$holidays" == "y" || "$holidays" == "Y" ]]; then
    if grep -q "reports.day.holidays" "$TIMEW_CONFIG"; then
      sed -i.bak "s|reports.day.holidays.*|reports.day.holidays = yes|" "$TIMEW_CONFIG"
    else
      echo "reports.day.holidays = yes" >> "$TIMEW_CONFIG"
    fi
    log_success "Holiday display enabled"
  elif [[ "$holidays" == "n" || "$holidays" == "N" ]]; then
    if grep -q "reports.day.holidays" "$TIMEW_CONFIG"; then
      sed -i.bak "s|reports.day.holidays.*|reports.day.holidays = no|" "$TIMEW_CONFIG"
    else
      echo "reports.day.holidays = no" >> "$TIMEW_CONFIG"
    fi
    log_success "Holiday display disabled"
  fi
}

configure_theme() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Color Theme"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo "TimeWarrior uses colors to highlight different elements in reports."
  echo ""
  echo "Current theme:"
  if grep -q "^define theme:" "$TIMEW_CONFIG"; then
    grep -A 10 "^define theme:" "$TIMEW_CONFIG" | grep "^  " || echo "  (using defaults)"
  else
    echo "  (using defaults)"
  fi
  
  echo ""
  echo "Theme configuration:"
  echo "  1. Use default theme"
  echo "  2. Disable colors"
  echo "  3. Custom theme (advanced)"
  echo "  4. Keep current settings"
  echo ""
  read -p "Choose option [1-4]: " choice
  
  case "$choice" in
    1)
      sed -i.bak '/^define theme:/,/^$/d' "$TIMEW_CONFIG"
      log_success "Using default theme"
      ;;
    2)
      if grep -q "^color" "$TIMEW_CONFIG"; then
        sed -i.bak "s|^color.*|color = off|" "$TIMEW_CONFIG"
      else
        echo "color = off" >> "$TIMEW_CONFIG"
      fi
      log_success "Colors disabled"
      ;;
    3)
      echo ""
      echo "For custom themes, edit $TIMEW_CONFIG manually."
      echo "See: timew help theme"
      log_info "Theme configuration unchanged"
      ;;
    4|"")
      log_info "Keeping current settings"
      ;;
    *)
      log_error "Invalid choice"
      ;;
  esac
}

configure_debug() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Debug Settings"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  local current_debug
  current_debug=$(grep "^debug" "$TIMEW_CONFIG" | awk '{print $3}' || echo "off")
  echo "Current debug mode: ${current_debug:-off}"
  echo ""
  echo "Debug mode shows diagnostic information."
  echo "Useful for troubleshooting, but not for general use."
  echo ""
  read -p "Enable debug mode? [y/n, or Enter to keep current]: " debug
  
  if [[ "$debug" == "y" || "$debug" == "Y" ]]; then
    if grep -q "^debug" "$TIMEW_CONFIG"; then
      sed -i.bak "s|^debug.*|debug = on|" "$TIMEW_CONFIG"
    else
      echo "debug = on" >> "$TIMEW_CONFIG"
    fi
    log_success "Debug mode enabled"
  elif [[ "$debug" == "n" || "$debug" == "N" ]]; then
    if grep -q "^debug" "$TIMEW_CONFIG"; then
      sed -i.bak "s|^debug.*|debug = off|" "$TIMEW_CONFIG"
    else
      echo "debug = off" >> "$TIMEW_CONFIG"
    fi
    log_success "Debug mode disabled"
  fi
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
    echo "  1. Configure basic settings (confirmation, verbose)"
    echo "  2. Configure work week exclusions"
    echo "  3. Configure report settings"
    echo "  4. Configure color theme"
    echo "  5. Configure debug settings"
    echo "  6. View current configuration"
    echo "  7. Test configuration (timew show)"
    echo "  8. Exit"
    echo ""
    read -p "Choose option [1-8]: " choice
    
    case "$choice" in
      1) configure_basic_settings ;;
      2) configure_work_week ;;
      3) configure_reports ;;
      4) configure_theme ;;
      5) configure_debug ;;
      6) cat "$TIMEW_CONFIG" ;;
      7) timew show ;;
      8)
        echo ""
        log_success "Configuration complete!"
        echo ""
        echo "Changes saved to: $TIMEW_CONFIG"
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
