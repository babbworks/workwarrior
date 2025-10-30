#!/usr/bin/env bash
# Generic auto-discovered submenu
# Save as: $HOME/ww/services/help/questions/who.sh
# Replace "who" with the word for each file.

WORD="where"
SUB_DIR="$HOME/ww/services/help/questions/$WORD"

while true; do
  clear
  echo "========================================================="
  echo "   Workwarrior Help: ${WORD^^}"
  echo "========================================================="
  echo

  if compgen -G "$SUB_DIR/*.sh" > /dev/null; then
    i=1
    for f in "$SUB_DIR"/*.sh; do
      fname=$(basename "$f" .sh)
      echo "  $i) $fname"
      i=$((i+1))
    done
  else
    echo "  (No topics found yet under $WORD/)"
  fi

  echo
  echo "  b) Back to Main Menu"
  echo "========================================================="

  read -p "Choose option: " choice

  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    target=$(ls "$SUB_DIR"/*.sh 2>/dev/null | sed -n "${choice}p")
    [[ -n "$target" ]] && "$target"
  elif [[ "$choice" == "b" ]]; then
    break
  fi
done
