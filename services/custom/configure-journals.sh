#!/usr/bin/env bash
# Service: configure-journals
# Category: custom
# Description: Interactive guide for configuring JRNL settings

set -e

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/core-utils.sh"

# ============================================================================
# CONFIGURATION
# ============================================================================

JRNL_CONFIG=""
PROFILE_NAME=""
PROFILE_BASE=""

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

show_banner() {
  echo ""
  echo "============================================================"
  echo "         JRNL Configuration Guide"
  echo "============================================================"
  echo ""
}

check_active_profile() {
  if [[ -z "$WORKWARRIOR_BASE" ]]; then
    log_error "No active profile. Activate a profile first with: p-<profile-name>"
    exit 1
  fi
  
  PROFILE_BASE="$WORKWARRIOR_BASE"
  PROFILE_NAME="$WARRIOR_PROFILE"
  JRNL_CONFIG="$PROFILE_BASE/jrnl.yaml"
  
  if [[ ! -f "$JRNL_CONFIG" ]]; then
    log_error "JRNL configuration not found: $JRNL_CONFIG"
    exit 1
  fi
}

show_journal_management_info() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Managing Journals"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "There are two ways to manage journals in your profile:"
  echo ""
  echo "1. Command-line (Recommended):"
  echo "   ww journal add <journal-name>     # Add new journal"
  echo "   ww journal list                   # List all journals"
  echo "   ww journal remove <journal-name>  # Remove journal"
  echo ""
  echo "   Note: These commands are planned but not yet implemented."
  echo "   See OUTSTANDING.md for status."
  echo ""
  echo "2. This configuration tool:"
  echo "   • Guided prompts for adding/editing journals"
  echo "   • Validates paths and settings"
  echo "   • Updates jrnl.yaml automatically"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  read -p "Press Enter to continue with configuration..."
  echo ""
}

# ============================================================================
# CONFIGURATION SECTIONS
# ============================================================================

configure_journals() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Journal Management"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Current journals in profile '$PROFILE_NAME':"
  echo ""
  
  # List current journals
  grep -A 100 "^journals:" "$JRNL_CONFIG" | grep "^  " | grep -v "^  default:" | sed 's/:.*//' | sed 's/^  /  • /' || echo "  (none)"
  
  echo ""
  read -p "Would you like to add a new journal? [y/n]: " add_journal
  
  if [[ "$add_journal" == "y" || "$add_journal" == "Y" ]]; then
    add_new_journal
  fi
}

add_new_journal() {
  echo ""
  read -p "Enter journal name (e.g., work-log, personal, ideas): " journal_name
  
  # Validate journal name
  if [[ -z "$journal_name" ]]; then
    log_error "Journal name cannot be empty"
    return 1
  fi
  
  if [[ "$journal_name" =~ [^a-zA-Z0-9_-] ]]; then
    log_error "Journal name can only contain letters, numbers, hyphens, and underscores"
    return 1
  fi
  
  # Check if journal already exists
  if grep -q "^  $journal_name:" "$JRNL_CONFIG"; then
    log_error "Journal '$journal_name' already exists"
    return 1
  fi
  
  # Set journal file path
  local journal_file="$PROFILE_BASE/journals/${journal_name}.txt"
  
  echo ""
  echo "Journal will be created at: $journal_file"
  read -p "Continue? [y/n]: " confirm
  
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cancelled"
    return 0
  fi
  
  # Create journal file
  if [[ ! -f "$journal_file" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M'): Welcome to your $journal_name journal!" > "$journal_file"
    log_success "Created journal file: $journal_file"
  fi
  
  # Add to jrnl.yaml
  # Find the journals section and add new entry
  awk -v jname="$journal_name" -v jpath="$journal_file" '
    /^journals:/ { print; in_journals=1; next }
    in_journals && /^[^ ]/ { print "  " jname ": " jpath; in_journals=0 }
    { print }
    END { if (in_journals) print "  " jname ": " jpath }
  ' "$JRNL_CONFIG" > "$JRNL_CONFIG.tmp"
  
  mv "$JRNL_CONFIG.tmp" "$JRNL_CONFIG"
  
  log_success "Added journal '$journal_name' to configuration"
  echo ""
  echo "You can now use: j $journal_name \"Your entry here\""
}

configure_editor() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  External Editor"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  local current_editor
  current_editor=$(grep "^editor:" "$JRNL_CONFIG" | sed "s/editor: //; s/'//g; s/\"//g")
  
  if [[ -z "$current_editor" ]]; then
    echo "Current editor: (none - using built-in prompt)"
  else
    echo "Current editor: $current_editor"
  fi
  
  echo ""
  echo "Available editors:"
  echo "  1. nano       - Simple, beginner-friendly"
  echo "  2. vim        - Powerful, modal editor"
  echo "  3. code       - Visual Studio Code (requires: code --wait)"
  echo "  4. subl       - Sublime Text (requires: subl -w)"
  echo "  5. emacs      - Extensible editor"
  echo "  6. none       - Use built-in prompt"
  echo "  7. custom     - Enter custom command"
  echo ""
  
  read -p "Choose editor [1-7, or Enter to keep current]: " editor_choice
  
  case "$editor_choice" in
    1) new_editor="nano" ;;
    2) new_editor="vim" ;;
    3) new_editor="code --wait" ;;
    4) new_editor="subl -w" ;;
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
  
  # Update config
  sed -i.bak "s|^editor:.*|editor: '$new_editor'|" "$JRNL_CONFIG"
  log_success "Editor updated to: $new_editor"
}

configure_colors() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Color Scheme"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo "Current colors:"
  grep -A 4 "^colors:" "$JRNL_CONFIG" | grep "^  " | sed 's/^  /  /'
  
  echo ""
  read -p "Would you like to customize colors? [y/n]: " customize
  
  if [[ "$customize" != "y" && "$customize" != "Y" ]]; then
    return 0
  fi
  
  echo ""
  echo "Available colors:"
  echo "  BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE, NONE"
  echo ""
  
  for element in body date tags title; do
    read -p "Color for $element (or Enter to keep current): " color
    if [[ -n "$color" ]]; then
      color=$(echo "$color" | tr '[:lower:]' '[:upper:]')
      sed -i.bak "s|^  $element:.*|  $element: $color|" "$JRNL_CONFIG"
      log_success "Updated $element color to: $color"
    fi
  done
}

configure_tagsymbols() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Tag Symbols"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  local current_tags
  current_tags=$(grep "^tagsymbols:" "$JRNL_CONFIG" | sed "s/tagsymbols: //; s/'//g")
  
  echo "Current tag symbols: $current_tags"
  echo ""
  echo "Common options:"
  echo "  @       - Single @ symbol"
  echo "  #       - Single # symbol (requires quoting in shell)"
  echo "  @#      - Both @ and # symbols"
  echo "  +       - Plus symbol"
  echo ""
  echo "Note: Using # requires quoting entries in shell:"
  echo '  jrnl "My entry with #tag"'
  echo ""
  
  read -p "Enter tag symbols (or Enter to keep current): " new_tags
  
  if [[ -n "$new_tags" ]]; then
    sed -i.bak "s|^tagsymbols:.*|tagsymbols: '$new_tags'|" "$JRNL_CONFIG"
    log_success "Tag symbols updated to: $new_tags"
  fi
}

configure_default_time() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Default Time"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  local current_hour current_minute
  current_hour=$(grep "^default_hour:" "$JRNL_CONFIG" | awk '{print $2}')
  current_minute=$(grep "^default_minute:" "$JRNL_CONFIG" | awk '{print $2}')
  
  echo "Current default time: $current_hour:$(printf "%02d" $current_minute)"
  echo ""
  echo "This time is used when you create entries without specifying a time."
  echo ""
  
  read -p "Enter default hour (0-23, or Enter to keep current): " new_hour
  if [[ -n "$new_hour" ]]; then
    if [[ "$new_hour" =~ ^[0-9]+$ ]] && (( new_hour >= 0 && new_hour <= 23 )); then
      sed -i.bak "s|^default_hour:.*|default_hour: $new_hour|" "$JRNL_CONFIG"
      log_success "Default hour updated to: $new_hour"
    else
      log_error "Invalid hour (must be 0-23)"
    fi
  fi
  
  read -p "Enter default minute (0-59, or Enter to keep current): " new_minute
  if [[ -n "$new_minute" ]]; then
    if [[ "$new_minute" =~ ^[0-9]+$ ]] && (( new_minute >= 0 && new_minute <= 59 )); then
      sed -i.bak "s|^default_minute:.*|default_minute: $new_minute|" "$JRNL_CONFIG"
      log_success "Default minute updated to: $new_minute"
    else
      log_error "Invalid minute (must be 0-59)"
    fi
  fi
}

configure_display_settings() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Display Settings"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Highlight
  local current_highlight
  current_highlight=$(grep "^highlight:" "$JRNL_CONFIG" | awk '{print $2}')
  echo "Highlight tags: $current_highlight"
  read -p "Enable tag highlighting? [y/n, or Enter to keep current]: " highlight
  if [[ "$highlight" == "y" || "$highlight" == "Y" ]]; then
    sed -i.bak "s|^highlight:.*|highlight: true|" "$JRNL_CONFIG"
    log_success "Tag highlighting enabled"
  elif [[ "$highlight" == "n" || "$highlight" == "N" ]]; then
    sed -i.bak "s|^highlight:.*|highlight: false|" "$JRNL_CONFIG"
    log_success "Tag highlighting disabled"
  fi
  
  # Linewrap
  local current_wrap
  current_wrap=$(grep "^linewrap:" "$JRNL_CONFIG" | awk '{print $2}')
  echo ""
  echo "Current line wrap: $current_wrap"
  read -p "Enter line wrap width (number or 'false' to disable, or Enter to keep): " wrap
  if [[ -n "$wrap" ]]; then
    sed -i.bak "s|^linewrap:.*|linewrap: $wrap|" "$JRNL_CONFIG"
    log_success "Line wrap updated to: $wrap"
  fi
  
  # Indent character
  local current_indent
  current_indent=$(grep "^indent_character:" "$JRNL_CONFIG" | sed "s/indent_character: //; s/'//g")
  echo ""
  echo "Current indent character: '$current_indent'"
  read -p "Enter indent character (or Enter to keep current): " indent
  if [[ -n "$indent" ]]; then
    sed -i.bak "s|^indent_character:.*|indent_character: '$indent'|" "$JRNL_CONFIG"
    log_success "Indent character updated to: '$indent'"
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
    echo "  1. Manage journals (add/list)"
    echo "  2. Configure external editor"
    echo "  3. Configure colors"
    echo "  4. Configure tag symbols"
    echo "  5. Configure default time"
    echo "  6. Configure display settings"
    echo "  7. View current configuration"
    echo "  8. Exit"
    echo ""
    read -p "Choose option [1-8]: " choice
    
    case "$choice" in
      1) configure_journals ;;
      2) configure_editor ;;
      3) configure_colors ;;
      4) configure_tagsymbols ;;
      5) configure_default_time ;;
      6) configure_display_settings ;;
      7) cat "$JRNL_CONFIG" ;;
      8)
        echo ""
        log_success "Configuration complete!"
        echo ""
        echo "Changes saved to: $JRNL_CONFIG"
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
  show_journal_management_info
  show_main_menu
}

main "$@"
