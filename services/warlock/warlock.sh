#!/usr/bin/env bash
# services/warlock/warlock.sh — ww browser warlock service
#
# Adopts jonestristand/task-warlock (Next.js 15, MIT) as a sibling web UI.
# Called by cmd_browser_warlock() in bin/ww.
#
# Upstream: https://github.com/jonestristand/task-warlock
# Author:   jonestristand · MIT License
# Wiring:   No source patches. TASKRC/TASKDATA passed as env vars at launch;
#           execa() in the upstream API layer inherits them automatically.

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

WARLOCK_DEFAULT_PORT=5001
WARLOCK_GIT_TAG="v0.3.0"
WARLOCK_UPSTREAM="https://github.com/jonestristand/task-warlock"
WARLOCK_AUTHOR="jonestristand"
WARLOCK_LICENSE="MIT"

WW_BASE="${WW_BASE:-$HOME/ww}"
WARLOCK_DIR="${WW_BASE}/tools/warlock"
WARLOCK_SOURCE="${WARLOCK_DIR}/source"
WARLOCK_CONFIG="${WARLOCK_DIR}/.ww-config"
WARLOCK_SETTINGS="${WARLOCK_DIR}/settings"
WARLOCK_PID_FILE="${WARLOCK_DIR}/server.pid"
WARLOCK_PATCHES_DOC="${WARLOCK_DIR}/WW-PATCHES.md"

# ---------------------------------------------------------------------------
# Logging (mirrors lib/logging.sh style without sourcing it)
# ---------------------------------------------------------------------------

_wlog_info()    { echo "  ${1}" >&2; }
_wlog_success() { echo "  ✓ ${1}" >&2; }
_wlog_warn()    { echo "  ⚠ ${1}" >&2; }
_wlog_error()   { echo "  ✗ ${1}" >&2; }
_wlog_step()    { echo "" >&2; echo "── ${1}" >&2; }

# ---------------------------------------------------------------------------
# Config helpers
# ---------------------------------------------------------------------------

_config_get() {
  local key="$1"
  [[ -f "$WARLOCK_CONFIG" ]] || return 1
  grep "^${key}=" "$WARLOCK_CONFIG" | cut -d= -f2-
}

_config_set() {
  local key="$1" val="$2"
  mkdir -p "$WARLOCK_DIR"
  if [[ -f "$WARLOCK_CONFIG" ]] && grep -q "^${key}=" "$WARLOCK_CONFIG"; then
    sed -i '' "s|^${key}=.*|${key}=${val}|" "$WARLOCK_CONFIG"
  else
    echo "${key}=${val}" >> "$WARLOCK_CONFIG"
  fi
}

# ---------------------------------------------------------------------------
# PID file helpers
# ---------------------------------------------------------------------------

_pid_write() {
  local pid="$1" profile="$2" port="$3"
  mkdir -p "$WARLOCK_DIR"
  echo "${pid} ${profile} ${port}" > "$WARLOCK_PID_FILE"
}

_pid_read() {
  [[ -f "$WARLOCK_PID_FILE" ]] || return 1
  read -r _PID _PROFILE _PORT < "$WARLOCK_PID_FILE"
}

_pid_alive() {
  _pid_read 2>/dev/null || return 1
  kill -0 "$_PID" 2>/dev/null
}

_pid_clear() {
  rm -f "$WARLOCK_PID_FILE"
}

# ---------------------------------------------------------------------------
# Profile resolution
# ---------------------------------------------------------------------------

# Resolve TASKRC and TASKDATA for a given profile name.
# Sets WARLOCK_TASKRC and WARLOCK_TASKDATA.
_resolve_profile() {
  local profile="$1"
  local base="${WW_BASE}"

  local taskrc="${base}/profiles/${profile}/.taskrc"
  local taskdata="${base}/profiles/${profile}/.task"

  if [[ ! -f "$taskrc" ]]; then
    _wlog_error "Profile '${profile}' not found (no .taskrc at ${taskrc})"
    return 1
  fi

  WARLOCK_TASKRC="$taskrc"
  WARLOCK_TASKDATA="$taskdata"
}

# List available profiles (directories with a .taskrc)
_list_profiles() {
  local profiles_dir="${WW_BASE}/profiles"
  [[ -d "$profiles_dir" ]] || return 0
  for d in "${profiles_dir}"/*/; do
    local name
    name="$(basename "$d")"
    [[ -f "${d}.taskrc" ]] && echo "$name"
  done
}

# Prompt user to confirm or select a profile. Sets WARLOCK_PROFILE.
_prompt_profile() {
  local active="${WARRIOR_PROFILE:-}"

  if [[ -n "$active" ]]; then
    printf "\nLaunch warlock for profile '%s'? [Y/n] " "$active" >&2
    local answer
    read -r answer </dev/tty
    answer="${answer:-Y}"
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      WARLOCK_PROFILE="$active"
      return 0
    fi
  fi

  # No active profile, or user declined — show list
  local profiles=()
  while IFS= read -r p; do profiles+=("$p"); done < <(_list_profiles)

  if [[ ${#profiles[@]} -eq 0 ]]; then
    _wlog_error "No profiles found in ${WW_BASE}/profiles/"
    return 1
  fi

  echo "" >&2
  echo "Available profiles:" >&2
  local i=1
  for p in "${profiles[@]}"; do
    printf "  [%d] %s\n" "$i" "$p" >&2
    i=$(( i + 1 ))
  done

  printf "\nProfile to serve [name or number]: " >&2
  local choice
  read -r choice </dev/tty

  # Accept number or name
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#profiles[@]} )); then
    WARLOCK_PROFILE="${profiles[$(( choice - 1 ))]}"
  else
    # Validate name
    local found=0
    for p in "${profiles[@]}"; do
      [[ "$p" == "$choice" ]] && { found=1; break; }
    done
    if [[ "$found" -eq 0 ]]; then
      _wlog_error "Profile '${choice}' not found"
      return 1
    fi
    WARLOCK_PROFILE="$choice"
  fi
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

_check_node() {
  command -v node &>/dev/null || { _wlog_error "node not found — install Node.js 22+"; return 1; }
  command -v npm  &>/dev/null || { _wlog_error "npm not found — install Node.js 22+"; return 1; }
  local ver
  ver="$(node --version 2>/dev/null | sed 's/v//')"
  local major="${ver%%.*}"
  if (( major < 22 )); then
    _wlog_error "Node.js ${ver} found — version 22+ required"
    _wlog_info  "Install: brew install node  OR  nvm install 22"
    return 1
  fi
  _wlog_success "Node.js ${ver} OK"
}

_check_docker() {
  command -v docker &>/dev/null || { _wlog_error "docker not found — install Docker Desktop"; return 1; }
  docker info &>/dev/null 2>&1 || { _wlog_error "Docker daemon not running — start Docker Desktop"; return 1; }
  _wlog_success "Docker OK"
}

_check_git() {
  command -v git &>/dev/null || { _wlog_error "git not found — required to clone warlock"; return 1; }
}

# ---------------------------------------------------------------------------
# WW-PATCHES.md generation
# ---------------------------------------------------------------------------

_generate_patches_doc() {
  local method="$1" port="$2" tag="$3" date="$4"
  mkdir -p "$WARLOCK_DIR"

  cat > "$WARLOCK_PATCHES_DOC" << EOF
# ww modifications to task-warlock
# Generated by: ww browser warlock install
# Install date: ${date}
# Tag: ${tag}

Upstream: ${WARLOCK_UPSTREAM}
Author:   ${WARLOCK_AUTHOR}
License:  ${WARLOCK_LICENSE}

## Profile isolation approach

task-warlock's API layer (src/lib/taskwarrior-cli.ts) calls the TaskWarrior
CLI as a subprocess via execa(). The execa library inherits the Node.js
process environment. ww launches the warlock server with TASKRC and TASKDATA
set to the active profile's paths; all downstream task CLI calls inherit them.

No source files were modified. This file documents the wiring, not a patch.

npm launch:
  TASKRC="<path>" TASKDATA="<path>" npm run dev -- --port ${port}

docker launch:
  docker run -p ${port}:3000 \\
    -v "<TASKDATA>":/home/nextjs/.task \\
    -v "${WARLOCK_SETTINGS}":/home/nextjs/.taskwarlock \\
    taskwarlock:${tag}

## If a future upstream change requires source patching

If a future task-warlock update changes the execa() calls to use a hardcoded
data path, the required patch is in src/lib/taskwarrior-cli.ts:

  Add to each execa('task', args) call:
    { env: { ...process.env, TASKRC: process.env.TASKRC, TASKDATA: process.env.TASKDATA } }

  Example:
    const { stdout } = await execa('task', args, {
      env: { ...process.env, TASKRC: process.env.TASKRC ?? '', TASKDATA: process.env.TASKDATA ?? '' }
    });

Document any such change here and update the installed copy of this file.
EOF
  _wlog_success "WW-PATCHES.md written"
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

_warlock_install() {
  local force="" preset_method=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)        force="--force"; shift ;;
      --method)       preset_method="$2"; shift 2 ;;
      --method=*)     preset_method="${1#--method=}"; shift ;;
      *)              shift ;;
    esac
  done

  _wlog_step "Warlock install — task-warlock by ${WARLOCK_AUTHOR} (${WARLOCK_LICENSE})"

  # Already installed?
  local existing_method existing_tag existing_date
  existing_method="$(_config_get method 2>/dev/null || true)"
  existing_tag="$(_config_get tag 2>/dev/null || true)"
  existing_date="$(_config_get installed 2>/dev/null || true)"

  if [[ -n "$existing_method" && "$force" != "--force" ]]; then
    echo "" >&2
    echo "  Warlock already installed:" >&2
    echo "    method:  ${existing_method}" >&2
    echo "    version: ${existing_tag}" >&2
    echo "    date:    ${existing_date}" >&2
    echo "" >&2
    printf "  [1] Reinstall / update to latest tag (%s)\n" "$WARLOCK_GIT_TAG" >&2
    printf "  [2] Switch method (%s → %s)\n" \
      "$existing_method" "$( [[ "$existing_method" == "npm" ]] && echo "docker" || echo "npm" )" >&2
    printf "  [q] Cancel\n" >&2
    printf "\n  Choice: " >&2
    local answer
    read -r answer </dev/tty
    case "$answer" in
      1) : ;;
      2) existing_method="$( [[ "$existing_method" == "npm" ]] && echo "docker" || echo "npm" )" ;;
      *) _wlog_info "Cancelled"; return 0 ;;
    esac
  fi

  # Pre-flight disclosure
  echo "" >&2
  echo "  Warlock is a Next.js web UI for TaskWarrior." >&2
  echo "  Upstream: ${WARLOCK_UPSTREAM}" >&2
  echo "" >&2
  echo "  This will:" >&2
  echo "    • Clone tag ${WARLOCK_GIT_TAG} to ${WARLOCK_SOURCE}  (~15MB)" >&2
  echo "    • Install dependencies:" >&2
  echo "        npm method:    npm install in source/  (~200MB node_modules)" >&2
  echo "        docker method: docker build             (~500MB image)" >&2
  echo "    • NOT touch any profile data (read-only access at runtime)" >&2
  echo "" >&2

  # Method selection
  local method="${preset_method:-$existing_method}"
  if [[ -z "$method" ]]; then
    printf "  Choose install method:\n" >&2
    printf "    [1] npm    (requires Node.js 22+)\n" >&2
    printf "    [2] docker (requires Docker Desktop)\n" >&2
    printf "    [q] quit\n" >&2
    printf "\n  Your choice: " >&2
    local choice
    read -r choice </dev/tty
    case "$choice" in
      1) method="npm" ;;
      2) method="docker" ;;
      *) _wlog_info "Cancelled"; return 0 ;;
    esac
  fi

  # Dependency check
  _wlog_step "Checking dependencies"
  _check_git
  if [[ "$method" == "npm" ]]; then
    _check_node
  else
    _check_docker
  fi

  # Clone
  _wlog_step "Cloning task-warlock ${WARLOCK_GIT_TAG}"
  if [[ -d "$WARLOCK_SOURCE" ]]; then
    _wlog_info "Removing existing clone..."
    rm -rf "$WARLOCK_SOURCE"
  fi
  mkdir -p "$WARLOCK_DIR"
  git clone --branch "$WARLOCK_GIT_TAG" --depth 1 "$WARLOCK_UPSTREAM" "$WARLOCK_SOURCE"
  _wlog_success "Cloned to ${WARLOCK_SOURCE}"

  # Install dependencies
  local port
  port="${WARLOCK_DEFAULT_PORT}"
  if [[ "$method" == "npm" ]]; then
    _wlog_step "Installing npm dependencies"
    (cd "$WARLOCK_SOURCE" && npm install)
    _wlog_success "npm install complete"
  else
    _wlog_step "Building Docker image taskwarlock:${WARLOCK_GIT_TAG}"
    (cd "$WARLOCK_SOURCE" && docker build -t "taskwarlock:${WARLOCK_GIT_TAG}" .)
    _wlog_success "Docker image built"
  fi

  # Generate WW-PATCHES.md
  local today
  today="$(date +%Y-%m-%d)"
  _generate_patches_doc "$method" "$port" "$WARLOCK_GIT_TAG" "$today"

  # Write config
  mkdir -p "$WARLOCK_DIR" "$WARLOCK_SETTINGS"
  # Write fresh config
  cat > "$WARLOCK_CONFIG" << EOF
method=${method}
tag=${WARLOCK_GIT_TAG}
port=${port}
installed=${today}
EOF
  _wlog_success "Config written to ${WARLOCK_CONFIG}"

  echo "" >&2
  _wlog_success "Warlock installed (${method}, ${WARLOCK_GIT_TAG})"
  echo "" >&2
  echo "  Run:  ww browser warlock" >&2
  echo "  Help: ww browser warlock help" >&2
}

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------

_warlock_start() {
  local port_arg="${1:-}"
  local port

  # Check installed
  if [[ ! -f "$WARLOCK_CONFIG" ]]; then
    _wlog_error "Warlock not installed — run: ww browser warlock install"
    return 1
  fi

  local method tag
  method="$(_config_get method)"
  tag="$(_config_get tag)"
  port="$(_config_get port)"
  [[ -n "$port_arg" ]] && port="$port_arg"
  port="${port:-$WARLOCK_DEFAULT_PORT}"

  # Already running?
  if _pid_alive 2>/dev/null; then
    _pid_read
    echo "" >&2
    _wlog_warn "Warlock already running (profile: ${_PROFILE}, port: ${_PORT}, pid: ${_PID})"
    printf "  Restart with a different profile? [y/N] " >&2
    local answer
    read -r answer </dev/tty
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      _warlock_stop_quiet
    else
      _wlog_info "Use 'ww browser warlock stop' to stop it."
      return 0
    fi
  fi

  # Profile selection
  WARLOCK_PROFILE=""
  _prompt_profile

  local taskrc taskdata
  _resolve_profile "$WARLOCK_PROFILE"
  taskrc="$WARLOCK_TASKRC"
  taskdata="$WARLOCK_TASKDATA"

  _wlog_step "Starting warlock (${method}, tag ${tag}, port ${port})"
  _wlog_info  "Profile:  ${WARLOCK_PROFILE}"
  _wlog_info  "TASKRC:   ${taskrc}"
  _wlog_info  "Port:     ${port}"

  local pid
  if [[ "$method" == "npm" ]]; then
    if [[ ! -d "${WARLOCK_SOURCE}/node_modules" ]]; then
      _wlog_error "node_modules not found — run: ww browser warlock install"
      return 1
    fi
    TASKRC="$taskrc" TASKDATA="$taskdata" \
      npm --prefix "$WARLOCK_SOURCE" run dev -- --port "$port" \
      > "${WARLOCK_DIR}/server.log" 2>&1 &
    pid=$!
  else
    docker run -d --rm \
      --name "ww-warlock-${WARLOCK_PROFILE}" \
      -p "${port}:3000" \
      -v "${taskdata}:/home/nextjs/.task" \
      -v "${WARLOCK_SETTINGS}:/home/nextjs/.taskwarlock" \
      "taskwarlock:${tag}" \
      > "${WARLOCK_DIR}/server.log" 2>&1 &
    pid=$!
  fi

  _pid_write "$pid" "$WARLOCK_PROFILE" "$port"
  _wlog_success "Warlock started (pid ${pid})"

  # Wait until the server responds before opening the browser (Next.js compile can take 10-120s)
  local url="http://localhost:${port}"
  _wlog_info "Waiting for server to be ready…"
  local waited=0
  while [[ $waited -lt 180 ]]; do
    if curl -sf "${url}" -o /dev/null 2>/dev/null; then
      break
    fi
    sleep 2
    waited=$(( waited + 2 ))
  done

  if command -v open &>/dev/null; then
    open "$url" &
  fi
  echo "" >&2
  echo "  Open: ${url}" >&2
  echo "  Stop: ww browser warlock stop" >&2
}

_warlock_stop_quiet() {
  _pid_read 2>/dev/null || return 0
  kill "$_PID" 2>/dev/null || true
  _pid_clear
}

# ---------------------------------------------------------------------------
# Stop
# ---------------------------------------------------------------------------

_warlock_stop() {
  if ! _pid_alive 2>/dev/null; then
    _wlog_info "Warlock is not running"
    _pid_clear
    return 0
  fi
  _pid_read
  _wlog_info "Stopping warlock (pid ${_PID}, profile ${_PROFILE}, port ${_PORT})..."
  kill "$_PID" 2>/dev/null || true
  sleep 1
  if kill -0 "$_PID" 2>/dev/null; then
    kill -9 "$_PID" 2>/dev/null || true
  fi
  _pid_clear
  _wlog_success "Warlock stopped"
}

# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------

_warlock_status() {
  local method tag port installed
  method="$(_config_get method 2>/dev/null || echo "—")"
  tag="$(_config_get tag 2>/dev/null || echo "—")"
  port="$(_config_get port 2>/dev/null || echo "${WARLOCK_DEFAULT_PORT}")"
  installed="$(_config_get installed 2>/dev/null || echo "—")"

  echo "" >&2
  if [[ "$method" == "—" ]]; then
    echo "  Warlock: not installed" >&2
    echo "  Run:     ww browser warlock install" >&2
    return 0
  fi

  echo "  Installation:" >&2
  echo "    method:    ${method}" >&2
  echo "    version:   ${tag}" >&2
  echo "    port:      ${port}" >&2
  echo "    installed: ${installed}" >&2
  echo "    path:      ${WARLOCK_SOURCE}" >&2

  echo "" >&2
  if _pid_alive 2>/dev/null; then
    _pid_read
    echo "  Status: RUNNING" >&2
    echo "    pid:     ${_PID}" >&2
    echo "    profile: ${_PROFILE}" >&2
    echo "    url:     http://localhost:${_PORT}" >&2
  else
    echo "  Status: stopped" >&2
    _pid_clear
  fi
  echo "" >&2
}

# JSON status for server.py /data/warlock/status endpoint
_warlock_status_json() {
  local method tag port installed running pid profile running_port
  method="$(_config_get method 2>/dev/null || echo "")"
  tag="$(_config_get tag 2>/dev/null || echo "")"
  port="$(_config_get port 2>/dev/null || echo "${WARLOCK_DEFAULT_PORT}")"
  installed="$(_config_get installed 2>/dev/null || echo "")"

  if _pid_alive 2>/dev/null; then
    _pid_read
    running="true"
    pid="$_PID"
    profile="$_PROFILE"
    running_port="$_PORT"
  else
    _pid_clear
    running="false"
    pid=""
    profile=""
    running_port=""
  fi

  printf '{"installed":%s,"method":"%s","tag":"%s","port":%s,"installed_date":"%s","running":%s,"pid":"%s","profile":"%s","running_port":"%s","upstream":"%s","attribution":"%s %s"}' \
    "$( [[ -n "$method" ]] && echo "true" || echo "false" )" \
    "$method" "$tag" "${running_port:-$port}" "$installed" \
    "$running" "$pid" "$profile" "${running_port:-}" \
    "$WARLOCK_UPSTREAM" "$WARLOCK_AUTHOR" "$WARLOCK_LICENSE"
}

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_warlock_help() {
  cat << EOF

warlock — task-warlock web UI for TaskWarrior

  Powered by task-warlock · ${WARLOCK_AUTHOR} · ${WARLOCK_LICENSE}
  ${WARLOCK_UPSTREAM}

Usage:
  ww browser warlock [install|start|stop|status|reinstall|help]
  ww web              (synonym via shortcuts)

Subcommands:
  install     Clone task-warlock and install deps (npm or docker)
  start       Launch server for a chosen profile (default action)
  stop        Stop running warlock instance
  status      Show installation and running state
  reinstall   Re-run install (update tag or switch method)
  help        Show this help

Options:
  --port N           Override default port (${WARLOCK_DEFAULT_PORT})
  --method npm|docker  Skip install method prompt (non-interactive)

Profile:
  Serves a single profile's task data. Profile is selected at launch —
  confirm the active profile or pick from the list.

Port:
  Default ${WARLOCK_DEFAULT_PORT}. ww browser runs on 7777. Ports are independent.

Notes:
  Warlock supports: list, add, edit, complete, restore, filter, 14 themes,
  contexts, sync. It does NOT support: annotations, UDA editing, dependencies,
  delete, or TimeWarrior. These gaps are by design in the upstream tool.

  Patch documentation: ${WARLOCK_DIR}/WW-PATCHES.md
  Integration docs:    docs/taskwarrior-extensions/task-warlock-integration.md

EOF
}

# ---------------------------------------------------------------------------
# Main dispatcher
# ---------------------------------------------------------------------------

main() {
  local subcommand="${1:-start}"
  shift 2>/dev/null || true

  local port_override="" method_override=""
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port)       port_override="$2"; shift 2 ;;
      --force)      args+=("--force"); shift ;;
      --method)     method_override="$2"; args+=("--method" "$2"); shift 2 ;;
      --method=*)   method_override="${1#--method=}"; args+=("$1"); shift ;;
      *)            args+=("$1"); shift ;;
    esac
  done

  case "$subcommand" in
    install)
      _warlock_install "${args[@]:-}"
      ;;
    start|"")
      _warlock_start "${port_override}"
      ;;
    stop)
      _warlock_stop
      ;;
    status)
      _warlock_status
      ;;
    status-json)
      _warlock_status_json
      ;;
    reinstall)
      _warlock_install "--force"
      ;;
    help|--help|-h)
      _warlock_help
      ;;
    *)
      _wlog_error "Unknown subcommand: ${subcommand}"
      echo "  Run: ww browser warlock help" >&2
      exit 1
      ;;
  esac
}

main "$@"
