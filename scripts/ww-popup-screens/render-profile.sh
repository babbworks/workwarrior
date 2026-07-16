# ww-popup-screens/render-profile.sh — Profile screen renderer

render_profile() {
  _init_profile
  local current="$_profile"

  emit_prompt "🔄 Profile"
  emit_message "Current: ${current:-none}"
  emit_data "profile"
  emit_hotkeys

  emit_row "ℹ️  Profile Info" "nav:profile_info" "info details"
  emit_row "➕  Create Profile" "nav:profile_create" "create new"

  emit_sep

  # List all profiles
  local profiles
  profiles=$(find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)

  if [[ -n "$profiles" ]]; then
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      if [[ "$p" == "$current" ]]; then
        emit_row_active "● ${p}" "noop"
      else
        emit_row "  ${p}" "act:profile_switch:${p}"
      fi
    done <<< "$profiles"
  else
    emit_label "(no profiles found)"
  fi

  emit_sep
  emit_row "← Home" "nav:home"
}

render_profile_info() {
  _init_profile

  emit_prompt "Profile Info"
  emit_data "profile"
  emit_hotkeys

  local output
  output=$(ww profile info "$_profile" 2>/dev/null)
  if [[ -n "$output" ]]; then
    emit_message "Profile: $_profile"
    while IFS= read -r line; do
      emit_label "$line"
    done <<< "$output"
  else
    # Manual info gathering
    emit_message "Profile: $_profile"
    emit_label "  Base: $_profile_base"
    emit_label "  Tasks: $(TASKRC="$(profile_taskrc)" TASKDATA="$(profile_taskdata)" task +READY count 2>/dev/null || echo 0) pending"
    local twstatus
    twstatus=$(TIMEWARRIORDB="$(profile_twdb)" timew 2>/dev/null | head -1)
    emit_label "  Timer: ${twstatus:-unavailable}"
    emit_label "  Lists: $(ls "$(profile_list_dir)" 2>/dev/null | tr '\n' ', ')"
    local lf; lf=$(profile_ledger_file)
    [[ -f "$lf" ]] && emit_label "  Ledger: $lf" || emit_label "  Ledger: (none)"
  fi

  emit_sep
  emit_row "← Back" "nav:profile"
}

render_profile_create() {
  emit_prompt "New Profile"
  emit_message "Type profile name (lowercase, no spaces)"
  emit_data "profile_create"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type name above and press Enter)"
  emit_sep
  emit_row "← Back" "nav:profile"
}
