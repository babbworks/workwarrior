# ww-popup-screens/render-lists.sh — Lists screen renderer (rofi-script mode)

render_lists() {
  _init_profile
  local list_dir list_name profile
  list_dir="$(profile_list_dir)"
  list_name="$(profile_current_list)"
  profile="$(profile_name)"

  emit_prompt "📝 ${list_name}"
  emit_message "List: ${list_name}  |  Alt+W:done  Alt+E:edit  (type to add)"
  emit_data "lists"
  emit_allow_custom
  emit_hotkeys

  # Actions
  emit_row "📋  Switch List" "nav:list_picker"
  emit_row "📄  New List" "nav:list_new"

  emit_sep

  # Get items (with notes visible)
  local items
  items=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -n 2>/dev/null)

  if [[ -n "$items" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local prefix="${line%% - *}"
      local text="${line#* - }"
      emit_row "$line" "pick:list_item:${prefix}" "$text"
    done <<< "$items"
  else
    emit_label "(empty list — type to add items)"
  fi

  emit_sep
  emit_row "← Home" "nav:home"
}

render_list_action() {
  local prefix="$1"
  _init_profile
  local list_dir list_name
  list_dir="$(profile_list_dir)"
  list_name="$(profile_current_list)"

  # Get the item text
  local item_line item_text
  item_line=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" 2>/dev/null | grep "^${prefix} - ")
  item_text="${item_line#* - }"

  emit_prompt "Item"
  emit_message "${item_text:-${prefix}}"
  emit_data "list_action:${prefix}"
  emit_hotkeys

  emit_row "✅  Done (finish)" "act:list_finish:${prefix}"
  emit_row "✏️  Edit" "nav:list_edit:${prefix}"
  emit_row "📝  Add/Update Note" "nav:list_note:${prefix}"
  emit_row "🗑️  Remove" "act:list_remove:${prefix}"
  emit_sep
  emit_row "← Back to List" "nav:lists"
}

render_list_picker() {
  _init_profile
  local list_dir list_name profile
  list_dir="$(profile_list_dir)"
  list_name="$(profile_current_list)"
  profile="$(profile_name)"

  emit_prompt "Switch List"
  emit_message "Current: ${list_name}"
  emit_data "lists"
  emit_hotkeys

  local lists
  lists=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --show-lists --profile-name "$profile" 2>/dev/null)
  if [[ -n "$lists" ]]; then
    while IFS= read -r lname; do
      [[ -z "$lname" ]] && continue
      local name_only="${lname%% *}"
      if [[ "$name_only" == "$list_name" ]]; then
        emit_row_active "● ${lname}" "noop"
      else
        emit_row "  ${lname}" "act:list_switch:${name_only}"
      fi
    done <<< "$lists"
  fi

  emit_sep
  emit_row "← Back to List" "nav:lists"
}

render_list_new() {
  emit_prompt "New list"
  emit_message "Type a name for the new list"
  emit_data "list_new"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type list name above and press Enter)"
  emit_sep
  emit_row "← Back" "nav:lists"
}

render_list_edit() {
  local prefix="$1"
  _init_profile
  local list_dir list_name
  list_dir="$(profile_list_dir)"
  list_name="$(profile_current_list)"

  local item_line item_text
  item_line=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" 2>/dev/null | grep "^${prefix} - ")
  item_text="${item_line#* - }"

  emit_prompt "Edit"
  emit_message "Current: ${item_text}"
  emit_data "list_edit:${prefix}"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type replacement text above and press Enter)"
  emit_sep
  emit_row "← Cancel" "nav:lists"
}

render_list_note() {
  local prefix="$1"
  _init_profile
  local list_dir list_name
  list_dir="$(profile_list_dir)"
  list_name="$(profile_current_list)"

  local item_line item_text
  item_line=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" 2>/dev/null | grep "^${prefix} - ")
  item_text="${item_line#* - }"

  emit_prompt "Note"
  emit_message "Adding note to: ${item_text%% // *}"
  emit_data "list_note:${prefix}"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type note text above and press Enter)"
  emit_sep
  emit_row "← Cancel" "nav:lists"
}
