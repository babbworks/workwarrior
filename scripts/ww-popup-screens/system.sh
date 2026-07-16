# ww-popup-screens/system.sh — System & admin screen

screen_system() {
  popup_require_profile || return

  local ctx
  ctx="$(popup_context_bar)"

  local menu="👥  Groups
🤖  Models
📦  Dependencies
🔧  Services"

  local choice
  choice=$(echo "$menu" | popup_select "⚙️ System" "$ctx") || return

  case "$choice" in
    *"Groups"*)
      _system_groups
      screen_system; return
      ;;
    *"Models"*)
      _system_models
      screen_system; return
      ;;
    *"Dependencies"*)
      _system_deps
      screen_system; return
      ;;
    *"Services"*)
      _system_services
      screen_system; return
      ;;
    *)
      screen_system; return
      ;;
  esac
}

_system_groups() {
  local output
  output=$(ww group list 2>&1) || output="(no groups)"
  popup_display "Groups" "" "$output" || true
}

_system_models() {
  local output
  output=$(ww model list 2>&1) || output="(no models configured)"
  popup_display "Models" "" "$output" || true
}

_system_deps() {
  local output
  output=$(ww deps check 2>&1) || output="(deps check unavailable)"
  popup_display "Dependencies" "" "$output" || true
}

_system_services() {
  local service_list
  service_list=$(ww service list 2>&1) || service_list="(no services)"

  local selected
  selected=$(echo "$service_list" | popup_select "Services") || return
  [[ -z "$selected" ]] && return

  # Show info for selected service
  local info
  info=$(ww service info "$selected" 2>&1) || info="(no info available)"
  popup_display "$selected" "" "$info" || true
}
