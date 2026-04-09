#!/usr/bin/env bash
# services/browser/browser.sh — Workwarrior browser service entry point
#
# Usage: browser.sh [start] [--port N] [--no-open]
#        browser.sh stop
#        browser.sh status
#        browser.sh --help
#
# Called by cmd_browser() in bin/ww. May also be invoked directly.

set -euo pipefail

# ============================================================================
# DEFAULTS
# ============================================================================

BROWSER_DEFAULT_PORT=7777
BROWSER_SERVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WW_BASE="${WW_BASE:-$HOME/ww}"
STATE_DIR="${WW_BASE}/.state"

# ============================================================================
# HELP
# ============================================================================

_browser_usage() {
  cat << 'EOF'
Usage:
  ww browser [start] [--port N] [--no-open]
  ww browser stop
  ww browser status
  ww browser --help

Actions:
  start (default)  Start the browser HTTP server
  stop             Stop a running browser server
  status           Show whether the server is running

Flags:
  --port N         Listen on port N instead of 7777
  --no-open        Do not open browser tab on start

Examples:
  ww browser                        Start on default port 7777
  ww browser --port 8080            Start on port 8080
  ww browser --no-open              Start without opening a browser tab
  ww browser stop                   Stop the running server
  ww browser status                 Check server status
EOF
}

# ============================================================================
# STATUS HELPERS
# ============================================================================

_browser_pid_file() {
  echo "${STATE_DIR}/browser.pid"
}

_browser_port_file() {
  echo "${STATE_DIR}/browser.port"
}

_browser_read_pid() {
  local pid_file
  pid_file="$(_browser_pid_file)"
  if [[ -f "$pid_file" ]]; then
    cat "$pid_file"
  else
    echo ""
  fi
}

_browser_read_port() {
  local port_file
  port_file="$(_browser_port_file)"
  if [[ -f "$port_file" ]]; then
    cat "$port_file"
  else
    echo ""
  fi
}

_browser_is_running() {
  local pid
  pid="$(_browser_read_pid)"
  if [[ -z "$pid" ]]; then
    return 1
  fi
  if kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  # Stale PID files — clean them up
  rm -f "$(_browser_pid_file)" "$(_browser_port_file)"
  return 1
}

# ============================================================================
# SUBCOMMANDS
# ============================================================================

_browser_status() {
  if _browser_is_running; then
    local pid port
    pid="$(_browser_read_pid)"
    port="$(_browser_read_port)"
    echo "running on http://localhost:${port}  (pid ${pid})"
    return 0
  else
    echo "not running"
    return 0
  fi
}

_browser_stop() {
  if ! _browser_is_running; then
    echo "browser server is not running"
    return 0
  fi
  local pid
  pid="$(_browser_read_pid)"
  echo "Stopping browser server (pid ${pid}) …"
  kill "$pid" 2>/dev/null || true

  # Wait up to 5 seconds for clean shutdown
  local waited=0
  while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 50 ]]; do
    sleep 0.1
    waited=$(( waited + 1 ))
  done

  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
  fi

  rm -f "$(_browser_pid_file)" "$(_browser_port_file)"
  echo "browser server stopped"
}

_browser_start() {
  local port="${1:-$BROWSER_DEFAULT_PORT}"
  local no_open="${2:-0}"

  if ! command -v python3 &>/dev/null; then
    echo "error: python3 not found" >&2
    echo "Install Python 3: https://www.python.org/downloads/" >&2
    exit 1
  fi

  if [[ ! -f "${BROWSER_SERVICE_DIR}/server.py" ]]; then
    echo "error: server.py not found at ${BROWSER_SERVICE_DIR}/server.py" >&2
    exit 2
  fi

  # Ensure state dir exists
  mkdir -p "${STATE_DIR}"

  # Start server in background
  python3 "${BROWSER_SERVICE_DIR}/server.py" \
    --port "${port}" \
    --ww-base "${WW_BASE}" \
    &

  local server_pid=$!

  # Wait for /health to respond (up to 10 seconds)
  local waited=0
  local healthy=0
  while [[ $waited -lt 100 ]]; do
    if curl -sf "http://localhost:${port}/health" &>/dev/null; then
      healthy=1
      break
    fi
    # Check if process died
    if ! kill -0 "$server_pid" 2>/dev/null; then
      echo "error: browser server failed to start (process exited)" >&2
      exit 1
    fi
    sleep 0.1
    waited=$(( waited + 1 ))
  done

  if [[ $healthy -eq 0 ]]; then
    echo "error: browser server did not respond within 10 seconds" >&2
    kill "$server_pid" 2>/dev/null || true
    exit 1
  fi

  echo "Workwarrior browser running at http://localhost:${port} — Ctrl-C or 'ww browser stop' to quit"

  if [[ "$no_open" -eq 0 ]]; then
    if command -v open &>/dev/null; then
      # macOS
      open "http://localhost:${port}" 2>/dev/null || true
    elif command -v xdg-open &>/dev/null; then
      # Linux
      xdg-open "http://localhost:${port}" 2>/dev/null || true
    fi
  fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  local subcommand=""
  local port="${BROWSER_DEFAULT_PORT}"
  local no_open=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      start|stop|status)
        subcommand="$1"
        shift
        ;;
      --port)
        if [[ -z "${2:-}" ]]; then
          echo "error: --port requires a port number" >&2
          exit 1
        fi
        port="$2"
        shift 2
        ;;
      --port=*)
        port="${1#--port=}"
        shift
        ;;
      --no-open)
        no_open=1
        shift
        ;;
      --help|-h|help)
        _browser_usage
        exit 0
        ;;
      *)
        echo "error: unknown argument: $1" >&2
        _browser_usage >&2
        exit 1
        ;;
    esac
  done

  # Default subcommand is start
  subcommand="${subcommand:-start}"

  case "$subcommand" in
    start)
      _browser_start "$port" "$no_open"
      ;;
    stop)
      _browser_stop
      ;;
    status)
      _browser_status
      ;;
    *)
      echo "error: unknown subcommand: $subcommand" >&2
      _browser_usage >&2
      exit 1
      ;;
  esac
}

main "$@"
