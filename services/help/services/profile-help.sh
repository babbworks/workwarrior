#!/usr/bin/env bash
# TEMPLATE — Workwarrior SERVICE Help Menu
# Copy this and rename for each service (e.g., profile-help.sh)

printf "\n%.0s" {1..50}   # prints 50 blank lines

SERVICE_NAME="SERVICE_NAME_HERE"      # Replace with the short service name
SERVICE_DESCRIPTION="Brief description of what this service does."
SERVICE_ACTIONS=(
  "View current state"
  "Perform main action 1"
  "Perform main action 2"
)
SERVICE_EXAMPLES=(
  "service command1 → Explanation of command1"
  "service command2 → Explanation of command2"
)
SERVICE_TIPS=(
  "Tip 1 for using this service effectively"
  "Tip 2 for advanced usage"
)

# Header
echo "╔════════════════════════════════════════════════════════╗"
printf "║%s%-54s║\n" " " "WORKWARRIOR ${SERVICE_NAME^^}"
echo "╚════════════════════════════════════════════════════════╝"
echo

# Description
echo "$SERVICE_DESCRIPTION"
echo

# Actions
echo "You can use it to:"
for action in "${SERVICE_ACTIONS[@]}"; do
  printf "  %-3s %s\n" "•" "$action"
done
echo

# Example usage
echo "Example usage inside Workwarrior:"
for example in "${SERVICE_EXAMPLES[@]}"; do
  printf "  %-25s %s\n" "${example%%→*}" "→ ${example#*→}"
done
echo

# Tips
echo "Tips:"
for tip in "${SERVICE_TIPS[@]}"; do
  printf "  %-3s %s\n" "•" "$tip"
done
echo

# Footer
echo "╔════════════════════════════════════════════════════════╗"
printf "║%s%-54s║\n" " " "End of ${SERVICE_NAME^^} Help"
echo "╚════════════════════════════════════════════════════════╝"
