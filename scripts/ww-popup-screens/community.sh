# ww-popup-screens/community.sh — Community collections screen

screen_community() {
  popup_require_profile || return

  local ctx
  ctx="$(popup_context_bar)"

  local menu="📋  List Collections
➕  Create Collection
📤  Add to Collection"

  local choice
  choice=$(echo "$menu" | popup_select "🤝 Community" "$ctx") || return

  case "$choice" in
    *"List Collections"*)
      _community_list
      screen_community; return
      ;;
    *"Create Collection"*)
      _community_create
      screen_community; return
      ;;
    *"Add to Collection"*)
      _community_add
      screen_community; return
      ;;
    *)
      screen_community; return
      ;;
  esac
}

_community_list() {
  local collections
  collections=$(ww community list 2>&1) || collections="(no collections)"

  if [[ -z "$collections" || "$collections" == *"no collections"* ]]; then
    popup_notify "No collections found"
    return
  fi

  local selected
  selected=$(echo "$collections" | popup_select "Collections") || return
  [[ -z "$selected" ]] && return

  # Show items in selected collection
  local items
  items=$(ww community show "$selected" 2>&1) || items="(empty)"
  popup_display "$selected" "" "$items" || true
}

_community_create() {
  local name
  name=$(popup_input "Collection name") || return
  [[ -z "$name" ]] && return
  ww community create "$name" 2>/dev/null
  popup_notify "Collection created: $name"
}

_community_add() {
  # Pick a collection first
  local collections
  collections=$(ww community list 2>&1) || collections=""
  if [[ -z "$collections" ]]; then
    popup_notify "No collections — create one first"
    return
  fi

  local collection
  collection=$(echo "$collections" | popup_select "Add to which collection?") || return
  [[ -z "$collection" ]] && return

  local content
  content=$(popup_input "Content to add") || return
  [[ -z "$content" ]] && return

  ww community add "$collection" "$content" 2>/dev/null
  popup_notify "Added to ${collection}"
}
