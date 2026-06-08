#!/usr/bin/env bash
set -euo pipefail

WW_BASE="${WW_BASE:-$HOME/ww}"

source "$WW_BASE/lib/core-utils.sh" 2>/dev/null || {
  log_error()   { echo "[error] $*" >&2; }
  log_info()    { echo "[info]  $*"; }
  log_success() { echo "[ok]    $*"; }
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_servers_taskrc() {
  # Return the active profile's .taskrc path, or empty string if none
  if [[ -n "${TASKRC:-}" && -f "$TASKRC" ]]; then
    echo "$TASKRC"
  elif [[ -n "${WORKWARRIOR_BASE:-}" && -f "$WORKWARRIOR_BASE/.taskrc" ]]; then
    echo "$WORKWARRIOR_BASE/.taskrc"
  else
    echo ""
  fi
}

_servers_read_taskrc_key() {
  local taskrc="$1" key="$2"
  grep -E "^${key}=" "$taskrc" 2>/dev/null | head -1 | cut -d= -f2- | xargs 2>/dev/null || echo ""
}

_servers_write_taskrc_key() {
  local taskrc="$1" key="$2" value="$3"
  # Remove existing key then append
  local tmp
  tmp=$(mktemp)
  grep -v "^${key}=" "$taskrc" > "$tmp" || true
  echo "${key}=${value}" >> "$tmp"
  mv "$tmp" "$taskrc"
}

_servers_remove_taskrc_key() {
  local taskrc="$1" key="$2"
  local tmp
  tmp=$(mktemp)
  grep -v "^${key}=" "$taskrc" > "$tmp" || true
  mv "$tmp" "$taskrc"
}

_servers_backlog_count() {
  local taskrc="$1"
  local taskdata
  taskdata=$(grep -E "^data.location=" "$taskrc" 2>/dev/null | head -1 | cut -d= -f2- | xargs 2>/dev/null || echo "")
  if [[ -z "$taskdata" && -n "${WORKWARRIOR_BASE:-}" ]]; then
    taskdata="$WORKWARRIOR_BASE/.task"
  fi
  local backlog="$taskdata/backlog.data"
  if [[ -f "$backlog" ]]; then
    grep -c . "$backlog" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

_cmd_status() {
  local taskrc
  taskrc=$(_servers_taskrc)
  if [[ -z "$taskrc" ]]; then
    echo "[servers] no active profile — run: p-<profile-name>"
    return 1
  fi

  local server_url client_id has_secret backlog_count
  server_url=$(_servers_read_taskrc_key "$taskrc" "sync.server.url")
  client_id=$(_servers_read_taskrc_key  "$taskrc" "sync.server.client_id")
  local secret_raw
  secret_raw=$(_servers_read_taskrc_key "$taskrc" "sync.encryption_secret")
  has_secret="no"
  [[ -n "$secret_raw" ]] && has_secret="yes"
  backlog_count=$(_servers_backlog_count "$taskrc")

  echo "Servers · TaskChampion Sync"
  echo "  profile     : ${WARRIOR_PROFILE:-<none>}"
  if [[ -n "$server_url" ]]; then
    echo "  server url  : $server_url"
    echo "  client id   : ${client_id:-<not set>}"
    echo "  secret      : $has_secret"
    echo "  backlog     : $backlog_count pending operation(s)"
    echo "  status      : configured"
  else
    echo "  status      : not configured"
    echo "  hint        : run 'ww server setup' to configure"
  fi
}

_cmd_setup() {
  require_active_profile || return 1
  local taskrc
  taskrc=$(_servers_taskrc)

  local server_url="" client_id="" secret=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --url)    server_url="$2"; shift 2 ;;
      --id)     client_id="$2";  shift 2 ;;
      --secret) secret="$2";     shift 2 ;;
      *) echo "[error] unknown flag: $1" >&2; return 1 ;;
    esac
  done

  # Interactive prompts for missing values
  if [[ -z "$server_url" ]]; then
    local existing
    existing=$(_servers_read_taskrc_key "$taskrc" "sync.server.url")
    printf "Server URL [%s]: " "${existing:-https://sync.taskchampion.net/v1}"
    read -r server_url
    [[ -z "$server_url" ]] && server_url="${existing:-https://sync.taskchampion.net/v1}"
  fi

  if [[ -z "$client_id" ]]; then
    local existing
    existing=$(_servers_read_taskrc_key "$taskrc" "sync.server.client_id")
    if [[ -z "$existing" ]]; then
      existing=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || uuidgen 2>/dev/null || echo "")
    fi
    printf "Client ID  [%s]: " "$existing"
    read -r client_id
    [[ -z "$client_id" ]] && client_id="$existing"
  fi

  if [[ -z "$secret" ]]; then
    local existing
    existing=$(_servers_read_taskrc_key "$taskrc" "sync.encryption_secret")
    printf "Encryption secret (leave blank to keep existing, '-' to remove): "
    read -r -s secret
    echo
    if [[ "$secret" == "-" ]]; then
      secret=""
    elif [[ -z "$secret" ]]; then
      secret="$existing"
    fi
  fi

  _servers_write_taskrc_key "$taskrc" "sync.server.url" "$server_url"
  _servers_write_taskrc_key "$taskrc" "sync.server.client_id" "$client_id"
  if [[ -n "$secret" ]]; then
    _servers_write_taskrc_key "$taskrc" "sync.encryption_secret" "$secret"
  else
    _servers_remove_taskrc_key "$taskrc" "sync.encryption_secret"
  fi

  log_success "Sync configured for profile '${WARRIOR_PROFILE:-}'"
  echo "  url      : $server_url"
  echo "  client   : $client_id"
  echo "  secret   : $([ -n "$secret" ] && echo 'set' || echo 'none')"
  echo ""
  echo "Run 'ww server sync' to perform the first sync."
}

_cmd_sync() {
  require_active_profile || return 1
  local taskrc
  taskrc=$(_servers_taskrc)

  local server_url
  server_url=$(_servers_read_taskrc_key "$taskrc" "sync.server.url")
  if [[ -z "$server_url" ]]; then
    echo "[error] sync not configured — run 'ww server setup' first" >&2
    return 1
  fi

  echo "Syncing tasks for profile '${WARRIOR_PROFILE:-}'…"
  TASKRC="$taskrc" task sync
}

_cmd_enable() {
  require_active_profile || return 1
  local taskrc
  taskrc=$(_servers_taskrc)

  local server_url
  server_url=$(_servers_read_taskrc_key "$taskrc" "sync.server.url")
  if [[ -z "$server_url" ]]; then
    echo "[error] sync not configured — run 'ww server setup' first" >&2
    return 1
  fi

  # Install a launchd plist (macOS) or cron job (Linux) for periodic sync
  local interval="${1:-300}"  # default 5 minutes
  if [[ "$(uname)" == "Darwin" ]]; then
    local plist_label="net.workwarrior.sync.${WARRIOR_PROFILE:-default}"
    local plist_path="$HOME/Library/LaunchAgents/${plist_label}.plist"
    local ww_bin
    ww_bin=$(command -v ww 2>/dev/null || echo "$WW_BASE/bin/ww")
    cat > "$plist_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${plist_label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${ww_bin}</string>
    <string>server</string>
    <string>sync</string>
  </array>
  <key>StartInterval</key><integer>${interval}</integer>
  <key>EnvironmentVariables</key>
  <dict>
    <key>WARRIOR_PROFILE</key><string>${WARRIOR_PROFILE:-}</string>
    <key>WORKWARRIOR_BASE</key><string>${WORKWARRIOR_BASE:-}</string>
    <key>TASKRC</key><string>${taskrc}</string>
    <key>WW_BASE</key><string>${WW_BASE}</string>
  </dict>
  <key>StandardOutPath</key><string>${WORKWARRIOR_BASE:-$HOME/ww}/logs/sync.log</string>
  <key>StandardErrorPath</key><string>${WORKWARRIOR_BASE:-$HOME/ww}/logs/sync-error.log</string>
</dict>
</plist>
EOF
    mkdir -p "${WORKWARRIOR_BASE:-$HOME/ww}/logs"
    launchctl load "$plist_path" 2>/dev/null || true
    log_success "Auto-sync enabled every ${interval}s (launchd: ${plist_label})"
    echo "  plist: $plist_path"
  else
    echo "[info] Auto-sync via cron — add to crontab manually:"
    echo "  */${interval} * * * * WARRIOR_PROFILE=${WARRIOR_PROFILE:-} WORKWARRIOR_BASE=${WORKWARRIOR_BASE:-} TASKRC=${taskrc} WW_BASE=${WW_BASE} ww server sync >> ~/ww-sync.log 2>&1"
  fi
}

_cmd_disable() {
  require_active_profile || return 1
  if [[ "$(uname)" == "Darwin" ]]; then
    local plist_label="net.workwarrior.sync.${WARRIOR_PROFILE:-default}"
    local plist_path="$HOME/Library/LaunchAgents/${plist_label}.plist"
    if [[ -f "$plist_path" ]]; then
      launchctl unload "$plist_path" 2>/dev/null || true
      rm -f "$plist_path"
      log_success "Auto-sync disabled for profile '${WARRIOR_PROFILE:-}'"
    else
      echo "[info] No auto-sync agent found for profile '${WARRIOR_PROFILE:-}'"
    fi
  else
    echo "[info] Remove the cron entry manually to disable auto-sync"
  fi
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------

show_help() {
  cat << 'EOF'
Servers — TaskChampion sync management

USAGE
  ww server <subcommand> [options]

SUBCOMMANDS
  status                       Show sync configuration and backlog for active profile
  setup [--url URL] [--id ID] [--secret SECRET]
                               Configure TaskChampion sync server (interactive if flags omitted)
  sync                         Run task sync now
  enable [interval-seconds]    Install periodic auto-sync (default: 300s)
  disable                      Remove auto-sync agent
  help                         Show this help

TASKRC KEYS MANAGED
  sync.server.url              TaskChampion server URL
  sync.server.client_id        Per-profile client UUID
  sync.encryption_secret       Optional end-to-end encryption key

EXAMPLES
  ww server status
  ww server setup
  ww server setup --url https://sync.example.com/v1 --id <uuid>
  ww server sync
  ww server enable 600
  ww server disable

NOTES
  TaskChampion sync is built into TaskWarrior 3.x — no external tool required.
  Each profile syncs independently via its own client_id.
  Requires an active profile: p-<profile-name>
EOF
}

subcommand="${1:-}"
shift 2>/dev/null || true

case "$subcommand" in
  ""|help|--help|-h) show_help ;;
  status)            _cmd_status "$@" ;;
  setup)             _cmd_setup "$@" ;;
  sync)              _cmd_sync "$@" ;;
  enable)            _cmd_enable "$@" ;;
  disable)           _cmd_disable "$@" ;;
  *)
    echo "[error] unknown subcommand: $subcommand" >&2
    echo "Run 'ww server help' for usage." >&2
    exit 1
    ;;
esac
