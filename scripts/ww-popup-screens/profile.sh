# ww-popup-screens/profile.sh — Profile switching screen

screen_profile() {
  local current
  current="$(popup_active_profile)"

  # Scan profiles directory
  local profiles
  profiles=$(find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)

  if [[ -z "$profiles" ]]; then
    popup_notify "No profiles found in ${PROFILES_DIR}"
    return
  fi

  # Build menu with active marker
  local menu=""
  while IFS= read -r p; do
    if [[ "$p" == "$current" ]]; then
      menu="${menu}✓  ${p} (active)\n"
    else
      menu="${menu}   ${p}\n"
    fi
  done <<< "$profiles"

  local formatted
  formatted=$(printf "%b" "$menu")

  local choice
  choice=$(echo "$formatted" | popup_select "🔄 Profile" "Current: ${current:-none}") || return

  # Extract profile name (strip marker and whitespace)
  local selected
  selected=$(echo "$choice" | sed 's/^[✓ ]*//' | sed 's/ (active)$//' | tr -d '[:space:]')

  [[ -z "$selected" ]] && return

  if [[ "$selected" == "$current" ]]; then
    popup_notify "Already on profile: $selected"
    return
  fi

  # Write to state file
  echo "$selected" > "${STATE_DIR}/last-profile"
  popup_notify "Switched to profile: $selected"
}
