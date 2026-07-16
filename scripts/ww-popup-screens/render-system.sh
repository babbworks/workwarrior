# ww-popup-screens/render-system.sh — System screen renderer

render_system() {
  _init_profile

  emit_prompt "⚙️ System"
  emit_message "Configuration and status"
  emit_data "system"
  emit_hotkeys

  emit_row "👥  Groups" "nav:system_groups"
  emit_row "🤖  Models" "nav:system_models"
  emit_row "📡  Dependencies" "nav:system_deps"
  emit_row "🔧  Services" "nav:system_services"
  emit_sep
  emit_row "← Home" "nav:home"
}

render_system_groups() {
  emit_prompt "Groups"
  emit_data "system"
  emit_hotkeys

  local output
  output=$(ww group list 2>/dev/null)
  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no groups)"
  fi
  emit_sep
  emit_row "← Back" "nav:system"
}

render_system_models() {
  emit_prompt "Models"
  emit_data "system"
  emit_hotkeys

  local output
  output=$(ww model list 2>/dev/null)
  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no models configured)"
  fi
  emit_sep
  emit_row "← Back" "nav:system"
}

render_system_deps() {
  emit_prompt "Dependencies"
  emit_data "system"
  emit_hotkeys

  local output
  output=$(ww deps check 2>/dev/null)
  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(unable to check)"
  fi
  emit_sep
  emit_row "← Back" "nav:system"
}

render_system_services() {
  emit_prompt "Services"
  emit_data "system"
  emit_hotkeys

  local output
  output=$(ww service list 2>/dev/null)
  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    emit_label "(no services)"
  fi
  emit_sep
  emit_row "← Back" "nav:system"
}
