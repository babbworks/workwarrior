#!/usr/bin/env bash
set -e

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
MAGENTA="\033[35m"
RESET="\033[0m"
BOLD="\033[1m"

pause() {
    read -rp "${CYAN}Press Enter to continue...${RESET}"
}

print_box() {
    local title="$1"
    shift
    local items=("$@")
    local width=0

    # Determine box width
    for item in "${items[@]}"; do
        (( ${#item} > width )) && width=${#item}
    done
    (( ${#title} > width )) && width=${#title}
    width=$((width + 4)) # padding

    # Top border
    echo "${MAGENTA}+$(printf '%*s' "$width" '' | tr ' ' '-')+${RESET}"
    # Title
    printf "${MAGENTA}| ${BOLD}%s${RESET}%*s |\n" "$title" $((width - ${#title} - 2)) ""
    # Separator
    echo "${MAGENTA}+$(printf '%*s' "$width" '' | tr ' ' '-')+${RESET}"
    # Items
    for item in "${items[@]}"; do
        printf "${MAGENTA}| ${YELLOW}%s${RESET}%*s |\n" "$item" $((width - ${#item} - 2)) ""
    done
    # Bottom border
    echo "${MAGENTA}+$(printf '%*s' "$width" '' | tr ' ' '-')+${RESET}"
}

clear
echo -e "${BOLD}📖 Welcome to the Workwarrior Profile Story!${RESET}"
pause

echo -e "\nIn Workwarrior, a ${GREEN}profile${RESET} is your personal workspace."
echo -e "Each profile keeps your tasks, journals, ledgers, and todos separate and organized."
pause

# Lists
list_items=("Work List: Taskwarrior tasks (alias: Work)"
            "Plain List: Simple TODO list (alias: List)"
            "Time List: Timewarrior tracking (alias: Time)")
print_box "📋 LISTS" "${list_items[@]}"
pause

# Books
book_items=("Notebook: Jrnl journal (alias: Notebook/journal)"
            "Workbook: Hledger ledger (alias: Workbook/ledger)")
print_box "📚 BOOKS" "${book_items[@]}"
pause

echo -e "\nEach profile keeps files in its own directories:"
echo -e "  - Work List: ${BLUE}Taskwarrior${RESET}"
echo -e "  - Plain List: ${BLUE}TODO text file${RESET}"
echo -e "  - Time List: ${BLUE}Timewarrior database${RESET}"
echo -e "  - Notebook: ${BLUE}jrnl.yaml + default journal${RESET}"
echo -e "  - Workbook: ${BLUE}Hledger journal file${RESET}"
pause

echo -e "\nAliases make it quick to access your tools:"
echo -e "  ${GREEN}Work${RESET}    -> Taskwarrior (Work List)"
echo -e "  ${GREEN}List${RESET}    -> Simple TODO list"
echo -e "  ${GREEN}Time${RESET}    -> Timewarrior database"
echo -e "  ${GREEN}Notebook/journal${RESET} -> Jrnl notebook"
echo -e "  ${GREEN}Workbook/ledger${RESET}  -> Hledger ledger"
pause

echo -e "\nActivating a profile sets up environment variables and makes these commands work immediately."
echo -e "Use: ${BOLD}use_task_profile <profile-name>${RESET}"
pause

echo -e "\n💡 Quick tip: You can create multiple profiles. Switching profiles updates all lists and books automatically."
pause

echo -e "${BOLD}And that's the story of Workwarrior profiles!${RESET}"
echo -e "Lists for actions. Books for records. Profiles to keep everything organized."
pause

echo -e "\n📌 Now you know how your Workwarrior profile works. Use it wisely!"
echo
