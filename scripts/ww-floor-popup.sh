#!/usr/bin/env bash
# ww-floor-popup.sh — primary popup interface for Workwarrior v2.1
#
# Launches rofi in script mode for instant screen transitions.
# The rofi process stays alive; ww-popup-script.sh is called
# on every user interaction (selection, typed input, hotkey).
#
# Usage:
#   ./ww-floor-popup.sh          # launch popup
#   ./ww-floor-popup.sh --dmenu  # fallback to dmenu mode (legacy)
#
# Keybindings inside the popup:
#   Alt+w   — Complete task / Finish item / Clock out (done)
#   Alt+e   — Edit / Open action menu
#   Alt+r   — Return to home screen
#   Alt+t   — Start timer for selected task
#   Alt+j   — (reserved)
#   Alt+k   — (reserved)
#   Alt+l   — (reserved)
#   Esc     — Close popup
#
# Requires: rofi (1.7+)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POPUP_SCRIPT="${SCRIPT_DIR}/ww-popup-script.sh"

# --- Verify dependencies ---
if ! command -v rofi &>/dev/null; then
  echo "ERROR: rofi is required. Install with: sudo apt install rofi" >&2
  exit 1
fi

if [[ ! -x "$POPUP_SCRIPT" ]]; then
  echo "ERROR: ww-popup-script.sh not found or not executable at: $POPUP_SCRIPT" >&2
  exit 1
fi

# --- Legacy dmenu fallback ---
if [[ "${1:-}" == "--dmenu" ]]; then
  # Source old shared.sh and run dmenu-style
  source "${SCRIPT_DIR}/ww-popup-screens/shared.sh"
  for f in "${SCRIPT_DIR}/ww-popup-screens/"*.sh; do
    [[ "$(basename "$f")" == "shared.sh" || "$(basename "$f")" == "shared-v2.sh" ]] && continue
    [[ "$(basename "$f")" == render-* ]] && continue
    source "$f"
  done
  screen_home
  exit $?
fi

# --- Launch rofi in script mode ---
rofi \
  -show ww \
  -modi "ww:${POPUP_SCRIPT}" \
  -no-config \
  -no-plugins \
  -theme-str '
    * {
      background-color: #1e1e2e;
      text-color: #cdd6f4;
      font: "monospace 12";
    }
    window {
      width: 50%;
      location: center;
      anchor: center;
      border: 2px solid;
      border-color: #89b4fa;
      border-radius: 0px;
      transparency: "disabled";
    }
    mainbox {
      padding: 8px;
      spacing: 4px;
    }
    inputbar {
      padding: 4px 8px;
      children: [prompt, textbox-prompt-colon, entry];
    }
    prompt { text-color: #89b4fa; }
    textbox-prompt-colon { str: ": "; text-color: #6c7086; }
    entry { text-color: #cdd6f4; }
    message {
      padding: 6px 8px;
      border: 1px solid;
      border-color: #313244;
      text-color: #bac2de;
    }
    textbox {
      text-color: #bac2de;
    }
    listview {
      lines: 15;
      fixed-height: true;
      scrollbar: false;
      spacing: 0px;
      padding: 4px 0;
    }
    element {
      padding: 4px 8px;
      spacing: 8px;
    }
    element normal.normal {
      background-color: #1e1e2e;
      text-color: #cdd6f4;
    }
    element normal.urgent {
      background-color: #1e1e2e;
      text-color: #f38ba8;
    }
    element normal.active {
      background-color: #1e1e2e;
      text-color: #89b4fa;
    }
    element selected.normal {
      background-color: #45475a;
      text-color: #ffffff;
    }
    element selected.urgent {
      background-color: #45475a;
      text-color: #f38ba8;
    }
    element selected.active {
      background-color: #45475a;
      text-color: #89dceb;
    }
    element-text {
      text-color: inherit;
      highlight: bold #89b4fa;
    }
  ' \
  -kb-custom-1 "Alt+w" \
  -kb-custom-2 "Alt+e" \
  -kb-custom-3 "Alt+t" \
  -kb-custom-4 "Alt+r" \
  -kb-cancel "Escape" \
  -matching fuzzy \
  -i

exit 0
