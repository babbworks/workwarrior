#!/usr/bin/env bash
# Dynamic Workwarrior Help Menu (debug-proof)

QUESTIONS_DIR="$HOME/ww/services/help/questions"
SERVICES_DIR="$HOME/ww/services/help/services"

while true; do
  clear
  echo "M:$HOSTNAME U:$USER ($(uname -s) $(uname -r) $(uname -m))"
  echo
  echo "WORKWARRIOR (WW) is released under Apache 2.0 License."
  echo "Project: https://github.com/babbworks/workwarrior"
  echo
  echo "========================================================="
  echo "HELP: Take Action, Access Information, Learn."
  echo "========================================================="
  echo
  echo "This tool does not interact with the Internet."
  echo "Workwarrior Guide: https://workwarrior.org/guide"
  echo
  echo " Question Words (conduits to knowledge):"

  # Display questions with numbers
  i=1
  for f in "$QUESTIONS_DIR"/*.sh; do
    fname=$(basename "$f" .sh)
    [[ "$fname" == "menu" ]] && continue
    display_name="${fname%%-*}"
    echo "  $i) $display_name"
    i=$((i+1))
  done

  echo
  echo " Services (A–Z):"

  # Build service map (uppercase keys for case-insensitivity)
  declare -A service_map
  for s in "$SERVICES_DIR"/*.sh; do
    sname=$(basename "$s" .sh)
    display_name="${sname%%-*}"
    upper_display=$(echo "$display_name" | tr '[:lower:]' '[:upper:]')
    service_map["$upper_display"]="$s"
    echo "  $upper_display"
  done

  echo
  echo "  q) Quit Help"
  echo "========================================================="

  read -p "Choose option (number, service name, or alias): " choice
  choice_upper=$(echo "$choice" | tr '[:lower:]' '[:upper:]')

  # Handle question words by number
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    target=$(ls "$QUESTIONS_DIR"/*.sh | grep -v menu.sh | sed -n "${choice}p")
    if [[ -n "$target" ]]; then
      "$target"
    else
      echo "Invalid number."
    fi
    echo
    read -p "Press Enter to return to the menu..."

  # Handle services by short name (case-insensitive)
  elif [[ -n "${service_map[$choice_upper]}" ]]; then
    "${service_map[$choice_upper]}"
    echo
    read -p "Press Enter to return to the menu..."

  # Handle delete alias X
  elif [[ "$choice_upper" == "X" && -f "$SERVICES_DIR/xdelete.sh" ]]; then
    "$SERVICES_DIR/xdelete.sh"
    echo
    read -p "Press Enter to return to the menu..."

  # Quit
  elif [[ "$choice_upper" == "Q" ]]; then
    break

  # Invalid input
  else
    echo "Invalid choice."
    read -p "Press Enter to continue..."
  fi
done
