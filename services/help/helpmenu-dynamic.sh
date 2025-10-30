#!/usr/bin/env bash
# Workwarrior Dynamic Help Menu
# Uses ~/ww/services/index.json to list and launch services

WW_HOME="$HOME/ww"
INDEX_FILE="$WW_HOME/services/index.json"
QUESTIONS_DIR="$WW_HOME/services/help/questions"

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required. Install it first (brew install jq on macOS)."
    exit 1
fi

while true; do
    clear
    echo "M:$HOSTNAME U:$USER ($(uname -s) $(uname -r) $(uname -m))"
    echo
    echo "WORKWARRIOR (WW) Help Menu"
    echo "Project: https://github.com/babbworks/workwarrior"
    echo "========================================================="
    echo

    # --- Question Words ---
    echo "Question Words (conduits to knowledge):"
    i=1
    for f in "$QUESTIONS_DIR"/*.sh; do
        fname=$(basename "$f" .sh)
        [[ "$fname" == "menu" ]] && continue
        display_name="${fname%%-*}"
        echo "  $i) $display_name"
        ((i++))
    done

    echo
    # --- Services from Registry ---
    if [[ -f "$INDEX_FILE" ]]; then
        echo "Services (A-Z):"
        mapfile -t services < <(jq -r 'sort_by(.shortname) | .[].shortname' "$INDEX_FILE")
        for s in "${services[@]}"; do
            name=$(jq -r ".[] | select(.shortname==\"$s\") | .name" "$INDEX_FILE")
            printf "  %s - %s\n" "$s" "$name"
        done
    else
        echo "No services registered yet."
    fi

    echo
    echo "  q) Quit Help"
    echo "========================================================="
    read -p "Choose option (number, service name, or alias): " choice

    # --- Question Word by Number ---
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        target=$(ls "$QUESTIONS_DIR"/*.sh | grep -v menu.sh | sed -n "${choice}p")
        if [[ -n "$target" ]]; then
            "$target"
        else
            echo "Invalid number."
            read -p "Press Enter to continue..."
        fi

    # --- Service by Shortname ---
    elif [[ -n "$choice" ]]; then
        # Check registry
        script_path=$(jq -r ".[] | select(.shortname==\"$choice\") | .script" "$INDEX_FILE")
        if [[ -n "$script_path" && -f "$script_path" ]]; then
            "$script_path"
        else
            echo "Invalid choice."
            read -p "Press Enter to continue..."
        fi

    # --- Quit ---
    elif [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        break

    # --- Invalid ---
    else
        echo "Invalid input."
        read -p "Press Enter to continue..."
    fi
done
