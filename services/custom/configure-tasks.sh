#!/usr/bin/env bash
# Service: configure-tasks
# Category: custom
# Description: Interactive guide for configuring TaskWarrior settings

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"

# ============================================================================
# CONFIGURATION
# ============================================================================

TASKRC=""
PROFILE_NAME=""
PROFILE_BASE=""

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

show_banner() {
  echo ""
  echo "============================================================"
  echo "         TaskWarrior Configuration Guide"
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
  TASKRC="$PROFILE_BASE/.taskrc"
  
  if [[ ! -f "$TASKRC" ]]; then
    log_error "TaskWarrior configuration not found: $TASKRC"
    exit 1
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
  
  # Editor
  local current_editor
  current_editor=$(grep "^editor=" "$TASKRC" | cut -d= -f2 || echo "")
  
  if [[ -z "$current_editor" ]]; then
    echo "Current editor: (system default)"
  else
    echo "Current editor: $current_editor"
  fi
  
  echo ""
  echo "Available editors:"
  echo "  1. nano       - Simple, beginner-friendly"
  echo "  2. vim        - Powerful, modal editor"
  echo "  3. code       - Visual Studio Code"
  echo "  4. subl       - Sublime Text"
  echo "  5. emacs      - Extensible editor"
  echo "  6. default    - Use system default"
  echo "  7. custom     - Enter custom command"
  echo ""
  
  read -p "Choose editor [1-7, or Enter to keep current]: " editor_choice
  
  case "$editor_choice" in
    1) new_editor="nano" ;;
    2) new_editor="vim" ;;
    3) new_editor="code" ;;
    4) new_editor="subl" ;;
    5) new_editor="emacs" ;;
    6) new_editor="" ;;
    7)
      read -p "Enter custom editor command: " new_editor
      ;;
    "")
      log_info "Keeping current editor"
      return 0
      ;;
    *)
      log_error "Invalid choice"
      return 1
      ;;
  esac
  
  # Update or add editor setting
  if grep -q "^editor=" "$TASKRC"; then
    sed -i.bak "s|^editor=.*|editor=$new_editor|" "$TASKRC"
  else
    echo "editor=$new_editor" >> "$TASKRC"
  fi
  log_success "Editor updated to: ${new_editor:-system default}"
  
  # Confirmation
  echo ""
  local current_confirm
  current_confirm=$(grep "^confirmation=" "$TASKRC" | cut -d= -f2 || echo "yes")
  echo "Current confirmation prompts: ${current_confirm:-yes}"
  read -p "Enable confirmation prompts? [y/n, or Enter to keep current]: " confirm
  
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    if grep -q "^confirmation=" "$TASKRC"; then
      sed -i.bak "s|^confirmation=.*|confirmation=yes|" "$TASKRC"
    else
      echo "confirmation=yes" >> "$TASKRC"
    fi
    log_success "Confirmation prompts enabled"
  elif [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
    if grep -q "^confirmation=" "$TASKRC"; then
      sed -i.bak "s|^confirmation=.*|confirmation=no|" "$TASKRC"
    else
      echo "confirmation=no" >> "$TASKRC"
    fi
    log_success "Confirmation prompts disabled"
  fi
}

configure_display_settings() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Display Settings"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Verbose
  local current_verbose
  current_verbose=$(grep "^verbose=" "$TASKRC" | cut -d= -f2 || echo "")
  echo "Current verbose settings: ${current_verbose:-default}"
  echo ""
  echo "Verbose options control what information TaskWarrior displays."
  echo "Common values: blank,footnote,label,new-id,affected,edit,special,project,sync"
  echo ""
  read -p "Enter verbose settings (or Enter to keep current): " new_verbose
  
  if [[ -n "$new_verbose" ]]; then
    if grep -q "^verbose=" "$TASKRC"; then
      sed -i.bak "s|^verbose=.*|verbose=$new_verbose|" "$TASKRC"
    else
      echo "verbose=$new_verbose" >> "$TASKRC"
    fi
    log_success "Verbose settings updated"
  fi
  
  # Date format
  echo ""
  local current_dateformat
  current_dateformat=$(grep "^dateformat=" "$TASKRC" | cut -d= -f2 || echo "")
  echo "Current date format: ${current_dateformat:-Y-M-D}"
  echo ""
  echo "Common formats:"
  echo "  Y-M-D           - 2024-02-11"
  echo "  M/D/Y           - 02/11/2024"
  echo "  D.M.Y           - 11.02.2024"
  echo "  a D b Y         - Sun 11 Feb 2024"
  echo ""
  read -p "Enter date format (or Enter to keep current): " new_dateformat
  
  if [[ -n "$new_dateformat" ]]; then
    if grep -q "^dateformat=" "$TASKRC"; then
      sed -i.bak "s|^dateformat=.*|dateformat=$new_dateformat|" "$TASKRC"
    else
      echo "dateformat=$new_dateformat" >> "$TASKRC"
    fi
    log_success "Date format updated"
  fi
}

configure_color_theme() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Color Theme"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo "Current theme:"
  grep "^include.*theme" "$TASKRC" | sed 's/^#/  (disabled) /' | sed 's/^include/  (active)   include/' || echo "  (none)"
  
  echo ""
  echo "Available themes:"
  echo "  1. light-16.theme"
  echo "  2. light-256.theme"
  echo "  3. dark-16.theme"
  echo "  4. dark-256.theme"
  echo "  5. dark-red-256.theme"
  echo "  6. dark-green-256.theme"
  echo "  7. dark-blue-256.theme"
  echo "  8. solarized-dark-256.theme"
  echo "  9. solarized-light-256.theme"
  echo "  10. no-color.theme"
  echo "  11. Keep current"
  echo ""
  
  read -p "Choose theme [1-11]: " theme_choice
  
  local theme_file=""
  case "$theme_choice" in
    1) theme_file="light-16.theme" ;;
    2) theme_file="light-256.theme" ;;
    3) theme_file="dark-16.theme" ;;
    4) theme_file="dark-256.theme" ;;
    5) theme_file="dark-red-256.theme" ;;
    6) theme_file="dark-green-256.theme" ;;
    7) theme_file="dark-blue-256.theme" ;;
    8) theme_file="solarized-dark-256.theme" ;;
    9) theme_file="solarized-light-256.theme" ;;
    10) theme_file="no-color.theme" ;;
    11|"")
      log_info "Keeping current theme"
      return 0
      ;;
    *)
      log_error "Invalid choice"
      return 1
      ;;
  esac
  
  # Comment out all theme includes
  sed -i.bak 's/^include.*theme/#&/' "$TASKRC"
  
  # Uncomment or add the selected theme
  if grep -q "^#include $theme_file" "$TASKRC"; then
    sed -i.bak "s|^#include $theme_file|include $theme_file|" "$TASKRC"
  else
    # Add after the theme section
    awk -v theme="include $theme_file" '
      /^# Color theme/ { print; print theme; next }
      { print }
    ' "$TASKRC" > "$TASKRC.tmp"
    mv "$TASKRC.tmp" "$TASKRC"
  fi
  
  log_success "Theme updated to: $theme_file"
}

configure_urgency() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Urgency Coefficients"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo "Urgency coefficients control task priority calculation."
  echo "Higher values = more urgent. Default values shown."
  echo ""
  
  # Show current urgency settings
  echo "Current urgency settings:"
  grep "^urgency\." "$TASKRC" | head -10 || echo "  (using defaults)"
  
  echo ""
  read -p "Would you like to customize urgency coefficients? [y/n]: " customize
  
  if [[ "$customize" != "y" && "$customize" != "Y" ]]; then
    return 0
  fi
  
  echo ""
  echo "Common urgency settings:"
  echo ""
  
  # Priority
  read -p "Priority coefficient (default 6.0): " priority_coef
  if [[ -n "$priority_coef" ]]; then
    if grep -q "^urgency.user.priority.coefficient=" "$TASKRC"; then
      sed -i.bak "s|^urgency.user.priority.coefficient=.*|urgency.user.priority.coefficient=$priority_coef|" "$TASKRC"
    else
      echo "urgency.user.priority.coefficient=$priority_coef" >> "$TASKRC"
    fi
  fi
  
  # Age
  read -p "Age coefficient (default 2.0): " age_coef
  if [[ -n "$age_coef" ]]; then
    if grep -q "^urgency.age.coefficient=" "$TASKRC"; then
      sed -i.bak "s|^urgency.age.coefficient=.*|urgency.age.coefficient=$age_coef|" "$TASKRC"
    else
      echo "urgency.age.coefficient=$age_coef" >> "$TASKRC"
    fi
  fi
  
  # Tags
  read -p "Tags coefficient (default 1.0): " tags_coef
  if [[ -n "$tags_coef" ]]; then
    if grep -q "^urgency.tags.coefficient=" "$TASKRC"; then
      sed -i.bak "s|^urgency.tags.coefficient=.*|urgency.tags.coefficient=$tags_coef|" "$TASKRC"
    else
      echo "urgency.tags.coefficient=$tags_coef" >> "$TASKRC"
    fi
  fi
  
  log_success "Urgency coefficients updated"
}

manage_udas() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  User Defined Attributes (UDAs)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo "Current UDAs:"
  grep "^uda\." "$TASKRC" | grep "\.type=" | sed 's/^uda\./  /' | sed 's/\.type=/ : /' || echo "  (none)"
  
  echo ""
  echo "UDA Management:"
  echo "  1. Add new UDA"
  echo "  2. List all UDAs"
  echo "  3. Remove UDA"
  echo "  4. Back to main menu"
  echo ""
  
  read -p "Choose option [1-4]: " uda_choice
  
  case "$uda_choice" in
    1)
      add_new_uda
      ;;
    2)
      list_udas
      read -p "Press Enter to continue..."
      ;;
    3)
      remove_uda
      ;;
    4|"")
      return 0
      ;;
    *)
      log_error "Invalid choice"
      ;;
  esac
}

add_new_uda() {
  echo ""
  read -p "Enter UDA name (e.g., estimate, client, priority): " uda_name
  
  if [[ -z "$uda_name" ]]; then
    log_error "UDA name cannot be empty"
    return 1
  fi
  
  # Check if UDA already exists
  if grep -q "^uda\.${uda_name}\.type=" "$TASKRC"; then
    log_error "UDA '$uda_name' already exists"
    return 1
  fi
  
  echo ""
  echo "UDA types:"
  echo "  1. string   - Text value"
  echo "  2. numeric  - Number value"
  echo "  3. date     - Date value"
  echo "  4. duration - Time duration"
  echo ""
  
  read -p "Choose type [1-4]: " type_choice
  
  local uda_type=""
  case "$type_choice" in
    1) uda_type="string" ;;
    2) uda_type="numeric" ;;
    3) uda_type="date" ;;
    4) uda_type="duration" ;;
    *)
      log_error "Invalid type"
      return 1
      ;;
  esac
  
  read -p "Enter UDA label (display name): " uda_label
  if [[ -z "$uda_label" ]]; then
    uda_label="$uda_name"
  fi
  
  # Add UDA to taskrc
  echo "" >> "$TASKRC"
  echo "uda.$uda_name.type=$uda_type" >> "$TASKRC"
  echo "uda.$uda_name.label=$uda_label" >> "$TASKRC"
  
  log_success "Added UDA: $uda_name ($uda_type)"
  echo ""
  echo "You can now use: task add ... $uda_name:value"
}

list_udas() {
  echo ""
  echo "All User Defined Attributes:"
  echo ""
  
  grep "^uda\." "$TASKRC" | grep "\.type=" | while read -r line; do
    local uda_name
    uda_name=$(echo "$line" | sed 's/^uda\.//' | sed 's/\.type=.*//')
    local uda_type
    uda_type=$(echo "$line" | sed 's/.*\.type=//')
    local uda_label
    uda_label=$(grep "^uda\.${uda_name}\.label=" "$TASKRC" | sed 's/.*=//')
    
    echo "  $uda_name"
    echo "    Type: $uda_type"
    echo "    Label: $uda_label"
    echo ""
  done
}

remove_uda() {
  echo ""
  read -p "Enter UDA name to remove: " uda_name
  
  if [[ -z "$uda_name" ]]; then
    log_error "UDA name cannot be empty"
    return 1
  fi
  
  # Check if UDA exists
  if ! grep -q "^uda\.${uda_name}\." "$TASKRC"; then
    log_error "UDA '$uda_name' not found"
    return 1
  fi
  
  read -p "Are you sure you want to remove UDA '$uda_name'? [y/n]: " confirm
  
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cancelled"
    return 0
  fi
  
  # Remove all lines related to this UDA
  sed -i.bak "/^uda\.${uda_name}\./d" "$TASKRC"
  
  log_success "Removed UDA: $uda_name"
}

configure_reports() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Report Configuration"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo "Report configuration allows you to customize task list views."
  echo ""
  echo "Current custom reports:"
  grep "^report\." "$TASKRC" | grep "\.description=" | sed 's/^report\./  /' | sed 's/\.description=/ : /' || echo "  (none)"
  
  echo ""
  echo "This is an advanced feature. For detailed report configuration,"
  echo "please refer to TaskWarrior documentation or edit .taskrc directly."
  echo ""
  
  read -p "Press Enter to continue..."
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
    echo "  1. Configure basic settings (editor, confirmation)"
    echo "  2. Configure display settings (verbose, date format)"
    echo "  3. Configure color theme"
    echo "  4. Configure urgency coefficients"
    echo "  5. Manage User Defined Attributes (UDAs)"
    echo "  6. Configure reports"
    echo "  7. View current configuration"
    echo "  8. Exit"
    echo ""
    read -p "Choose option [1-8]: " choice
    
    case "$choice" in
      1) configure_basic_settings ;;
      2) configure_display_settings ;;
      3) configure_color_theme ;;
      4) configure_urgency ;;
      5) manage_udas ;;
      6) configure_reports ;;
      7) cat "$TASKRC" | less ;;
      8)
        echo ""
        log_success "Configuration complete!"
        echo ""
        echo "Changes saved to: $TASKRC"
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
