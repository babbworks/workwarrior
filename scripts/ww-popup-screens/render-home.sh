# ww-popup-screens/render-home.sh — Home screen renderer (rofi-script mode)

render_home() {
  _init_profile

  local ctx
  ctx="$(build_context_bar)"

  emit_prompt "ww"
  emit_message "$ctx"
  emit_data "home"
  emit_allow_custom
  emit_hotkeys

  # Daily actions
  emit_row "🕐  Clock In / Out" "nav:clock" "clock time timer punch"
  emit_row "📋  My Tasks" "nav:tasks" "tasks todo work"
  emit_row "📝  My Lists" "nav:lists" "lists items notes"
  emit_row "🔍  Search" "nav:search" "search find query"

  emit_sep

  # Data & browse
  emit_row "📓  Journal" "nav:journal" "journal diary entries"
  emit_row "💰  Ledger" "nav:ledger" "ledger money expenses accounting"
  emit_row "👥  Board (Who's In)" "nav:board" "board stream who active"
  emit_row "📊  Reports" "nav:reports" "reports summary stats"
  emit_row "🤝  Community" "nav:community" "community shared collections"

  emit_sep

  # System & config
  emit_row "🔄  Switch Profile" "nav:profile" "profile switch user"
  emit_row "🔗  GitHub Sync" "nav:sync" "github sync issues push pull"
  emit_row "⚙️  System" "nav:system" "system config settings groups models"
}
