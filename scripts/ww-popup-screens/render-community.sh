# ww-popup-screens/render-community.sh — Community screen renderer (full functionality)

render_community() {
  _init_profile

  emit_prompt "🤝 Community"
  emit_message "Shared collections"
  emit_data "community"
  emit_hotkeys

  emit_row "➕  Create Collection" "nav:community_create" "create new collection"

  emit_sep

  local collections
  collections=$(ww community list 2>/dev/null)

  if [[ -n "$collections" ]]; then
    while IFS= read -r coll; do
      [[ -z "$coll" ]] && continue
      # Strip whitespace/formatting
      local name="${coll%%[[:space:]]*}"
      [[ -z "$name" ]] && name="$coll"
      emit_row "📁  ${coll}" "nav:community_show:${name}" "$coll"
    done <<< "$collections"
  else
    emit_label "(no collections — create one above)"
  fi

  emit_sep
  emit_row "← Home" "nav:home"
}

render_community_show() {
  local collection="$1"

  emit_prompt "🤝 ${collection}"
  emit_message "Collection: ${collection}  |  Type to add item"
  emit_data "community_show:${collection}"
  emit_allow_custom
  emit_hotkeys

  emit_row "➕  Add Item" "nav:community_add:${collection}" "add new item"

  emit_sep

  local items
  items=$(ww community show "$collection" 2>/dev/null)
  if [[ -n "$items" ]]; then
    while IFS= read -r item; do
      [[ -n "$item" ]] && emit_row "$item" "noop" "$item"
    done <<< "$items"
  else
    emit_label "(empty collection)"
  fi

  emit_sep
  emit_row "← Back" "nav:community"
}

render_community_create() {
  emit_prompt "New collection"
  emit_message "Type collection name and press Enter"
  emit_data "community_create"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type name above)"
  emit_sep
  emit_row "← Back" "nav:community"
}

render_community_add() {
  local collection="$1"

  emit_prompt "Add to ${collection}"
  emit_message "Type content to add to collection: ${collection}"
  emit_data "community_add:${collection}"
  emit_allow_custom
  emit_hotkeys
  emit_label "(type content above and press Enter)"
  emit_sep
  emit_row "← Back" "nav:community_show:${collection}"
}
