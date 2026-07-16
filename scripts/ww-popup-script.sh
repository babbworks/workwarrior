#!/usr/bin/env bash
# ww-popup-script.sh — rofi-script mode entry point
#
# Called by rofi repeatedly. Rofi stays alive as a single process;
# this script is invoked on every user interaction.
#
# Environment set by rofi:
#   ROFI_RETV: 0=initial, 1=selected, 2=custom text, 10-28=kb-custom
#   ROFI_INFO: info field of selected row
#   ROFI_DATA: state from previous invocation
#
# Output protocol:
#   \0key\x1fvalue\n  — header options (prompt, message, etc.)
#   item text\0key\x1fvalue\n — row with metadata

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCREENS_DIR="${SCRIPT_DIR}/ww-popup-screens"

# Source shared helpers (paths, state, formatters)
source "${SCREENS_DIR}/shared-v2.sh"

# Source all screen renderers
for _f in "${SCREENS_DIR}"/render-*.sh; do
  [[ -f "$_f" ]] && source "$_f"
done

# --- State parsing ---
# ROFI_DATA carries our screen state as: "screen:arg1:arg2"
STATE="${ROFI_DATA:-home}"
SCREEN="${STATE%%:*}"
SCREEN_ARG="${STATE#*:}"
[[ "$SCREEN_ARG" == "$STATE" ]] && SCREEN_ARG=""

# --- Routing ---
case "${ROFI_RETV:-0}" in
  0)
    # Initial call — render the current screen
    render_screen "$SCREEN" "$SCREEN_ARG"
    ;;
  1)
    # User selected an entry from the list
    handle_selection "$ROFI_INFO" "$1" "$SCREEN" "$SCREEN_ARG"
    ;;
  2)
    # User typed custom text (not from list)
    handle_custom_input "$1" "$SCREEN" "$SCREEN_ARG"
    ;;
  10)
    # kb-custom-1 (Alt+w): Done / Complete / Clock Out
    handle_kb_done "$ROFI_INFO" "$1" "$SCREEN"
    ;;
  11)
    # kb-custom-2 (Alt+e): Edit / Modify
    handle_kb_edit "$ROFI_INFO" "$1" "$SCREEN"
    ;;
  12)
    # kb-custom-3 (Alt+t): Start timer for selection
    handle_kb_timer "$ROFI_INFO" "$1" "$SCREEN"
    ;;
  13)
    # kb-custom-4 (Alt+r): Back to home
    render_screen "home" ""
    ;;
  *)
    # Unknown — render home
    render_screen "home" ""
    ;;
esac
