# ww-popup-screens/lists.sh — Lists screen using list.py

screen_lists() {
  popup_require_profile || return

  local list_dir list_name profile
  list_dir="$(popup_list_dir)"
  list_name="$(popup_current_list)"
  profile="$(popup_active_profile)"

  # Get items from current list (with notes visible)
  local items
  items=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -n 2>/dev/null) || items=""

  local ctx
  ctx="$(popup_context_bar)"

  local menu="➕  Add Item
📋  Switch List
📄  New List
${SEP}"

  if [[ -n "$items" ]]; then
    menu="${menu}
${items}"
  else
    menu="${menu}
(no items)"
  fi

  local choice
  choice=$(echo "$menu" | popup_select "📝 ${list_name}" "$ctx") || return

  popup_is_sep "$choice" && { screen_lists; return; }

  case "$choice" in
    *"Add Item"*)
      local text
      text=$(popup_input "Add to ${list_name}") || { screen_lists; return; }
      [[ -z "$text" ]] && { screen_lists; return; }
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -q "$text" 2>/dev/null
      popup_notify "Added to ${list_name}"
      screen_lists; return
      ;;
    *"Switch List"*)
      local lists new_list
      lists=$(python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --show-lists --profile-name "$profile" 2>/dev/null)
      new_list=$(echo "$lists" | popup_select "Switch list") || { screen_lists; return; }
      [[ -z "$new_list" ]] && { screen_lists; return; }
      # Extract just the list name (first word)
      new_list=$(echo "$new_list" | awk '{print $1}')
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --profile-name "$profile" switch "$new_list" 2>/dev/null
      popup_notify "Switched to: $new_list"
      screen_lists; return
      ;;
    *"New List"*)
      local new_name
      new_name=$(popup_input "New list name") || { screen_lists; return; }
      [[ -z "$new_name" ]] && { screen_lists; return; }
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" --profile-name "$profile" new "$new_name" 2>/dev/null
      popup_notify "Created list: $new_name"
      screen_lists; return
      ;;
    "(no items)")
      screen_lists; return
      ;;
    *)
      # Item selected — extract prefix (first token before " - ")
      local prefix
      prefix=$(echo "$choice" | awk '{print $1}')
      [[ -z "$prefix" ]] && { screen_lists; return; }
      _lists_item_action "$prefix" "$choice"
      screen_lists; return
      ;;
  esac
}

_lists_item_action() {
  local prefix="$1" full_text="$2"

  # Extract the item text (after "prefix - ")
  local item_text
  item_text=$(echo "$full_text" | sed "s/^[^ ]* - //")

  # Check if item has a note (contains " // ")
  local has_note=""
  [[ "$item_text" == *" // "* ]] && has_note="yes"

  local actions="✅  Done
✏️  Edit
📝  Add/Update Note
🗑️  Remove"

  [[ -n "$has_note" ]] && actions="✅  Done
✏️  Edit
📝  Add/Update Note
👁️  View Note
🗑️  Remove"

  local choice
  choice=$(echo "$actions" | popup_select "Item: ${item_text:0:40}" "") || return

  local list_dir list_name
  list_dir="$(popup_list_dir)"
  list_name="$(popup_current_list)"

  case "$choice" in
    *"Done"*)
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -f "$prefix" 2>/dev/null
      popup_notify "Item done"
      ;;
    *"Edit"*)
      local new_text
      new_text=$(popup_input "Edit item" "$item_text") || return
      [[ -z "$new_text" ]] && return
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -e "$prefix" "$new_text" 2>/dev/null
      popup_notify "Item updated"
      ;;
    *"Add/Update Note"*)
      local note
      note=$(popup_input "Note for item") || return
      [[ -z "$note" ]] && return
      # Append note: "original text // note"
      local base_text
      base_text="${item_text%% // *}"
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -e "$prefix" "${base_text} // ${note}" 2>/dev/null
      popup_notify "Note added"
      ;;
    *"View Note"*)
      local note_text
      note_text="${item_text##* // }"
      popup_display "Note" "" "$note_text" || true
      ;;
    *"Remove"*)
      popup_confirm "Remove this item?" "$item_text" || return
      python3 "$LIST_PY" -t "$list_dir" -l "$list_name" -r "$prefix" 2>/dev/null
      popup_notify "Item removed"
      ;;
  esac
}
