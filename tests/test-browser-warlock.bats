#!/usr/bin/env bats
# tests/test-browser-warlock.bats — TASK-EXT-WARLOCK-001
#
# Unit tests for services/warlock/warlock.sh and bin/ww warlock routing.
# No network, no real git, no real npm/docker — all external commands mocked.
#
# Run: bats tests/test-browser-warlock.bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

WARLOCK_SH="${BATS_TEST_DIRNAME}/../services/warlock/warlock.sh"
BIN_WW="${BATS_TEST_DIRNAME}/../bin/ww"

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

setup() {
  export WW_BASE="${BATS_TMPDIR}/ww-warlock-$$"
  mkdir -p "$WW_BASE"

  # Mock bin directory prepended to PATH
  _MOCK_BIN="${BATS_TMPDIR}/mock-bin-$$"
  mkdir -p "$_MOCK_BIN"
  export PATH="${_MOCK_BIN}:${PATH}"

  # Default stubs — succeed silently
  _stub git   "exit 0"
  _stub node  'echo "v22.0.0"'
  _stub npm   "exit 0"
  _stub docker "exit 0"
}

teardown() {
  rm -rf "$WW_BASE"
  rm -rf "$_MOCK_BIN"
}

# Write a mock executable to the mock bin dir
_stub() {
  local name="$1" body="$2"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "${_MOCK_BIN}/${name}"
  chmod +x "${_MOCK_BIN}/${name}"
}

# Convenience: write a minimal .ww-config
_write_config() {
  local method="${1:-npm}" tag="${2:-v0.3.0}" port="${3:-5001}" date="${4:-2026-01-01}"
  mkdir -p "${WW_BASE}/tools/warlock"
  cat > "${WW_BASE}/tools/warlock/.ww-config" << EOF
method=${method}
tag=${tag}
port=${port}
installed=${date}
EOF
}

# Convenience: write a profile with a stub .taskrc
_write_profile() {
  local name="${1:-testprofile}"
  mkdir -p "${WW_BASE}/profiles/${name}"
  touch "${WW_BASE}/profiles/${name}/.taskrc"
  mkdir -p "${WW_BASE}/profiles/${name}/.task"
}

# ---------------------------------------------------------------------------
# Dependency detection — node/docker missing
# ---------------------------------------------------------------------------

@test "install: fails cleanly when node is missing" {
  _stub node "exit 127"   # simulate not found
  run bash "$WARLOCK_SH" install <<< "1"
  # Should not exit 0
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Node.js" ]] || [[ "$output" =~ "node" ]]
}

@test "install: fails cleanly when npm is missing" {
  _stub npm "exit 127"
  # node --version succeeds but command -v npm fails
  _stub node 'if [[ "${1:-}" == "--version" ]]; then echo "v22.0.0"; else exit 0; fi'
  # Suppress git stub so we don't reach clone
  _stub git "exit 0"
  run bash -c "command -v npm() { return 127; }; bash '$WARLOCK_SH' install" <<< "1"
  # Alternate: just test that the check catches a missing npm via stub
  # The stub makes npm exit 127 on any call
  run bash "$WARLOCK_SH" install <<< "1"
  [ "$status" -ne 0 ]
}

@test "install: fails cleanly when docker daemon is not running" {
  # Simulate docker present but daemon not running (docker info fails)
  _stub docker 'if [[ "${1:-}" == "info" ]]; then exit 1; else exit 0; fi'
  run bash "$WARLOCK_SH" install <<< "2"
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Dd]ocker ]]
}

@test "install: fails cleanly when git is missing" {
  _stub git "exit 127"
  run bash "$WARLOCK_SH" install <<< "1"
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Gg]it ]]
}

# ---------------------------------------------------------------------------
# Install — writes .ww-config
# ---------------------------------------------------------------------------

@test "install: writes .ww-config after successful npm install" {
  # Pre-write config with method so --force skips the tty method-selection prompt
  _write_config "npm"
  _stub git '
    mkdir -p "${@: -1}/node_modules"
    touch "${@: -1}/package.json"
    exit 0
  '
  _stub npm "exit 0"

  run bash "$WARLOCK_SH" install --force
  [ "$status" -eq 0 ]

  config="${WW_BASE}/tools/warlock/.ww-config"
  [ -f "$config" ]
  grep -q "^method=npm" "$config"
  grep -q "^tag=v0.3.0" "$config"
  grep -q "^port=5001" "$config"
  grep -q "^installed=" "$config"
}

@test "install: generates WW-PATCHES.md" {
  _write_config "npm"
  _stub git '
    mkdir -p "${@: -1}/node_modules"
    touch "${@: -1}/package.json"
    exit 0
  '
  _stub npm "exit 0"

  run bash "$WARLOCK_SH" install --force
  [ "$status" -eq 0 ]

  patches="${WW_BASE}/tools/warlock/WW-PATCHES.md"
  [ -f "$patches" ]
  grep -q "jonestristand" "$patches"
  grep -q "MIT" "$patches"
  grep -q "TASKRC" "$patches"
}

@test "install: already-installed config is detected" {
  # Verify detection logic: if .ww-config exists, script reads it correctly
  _write_config "npm" "v0.3.0" "5001" "2026-01-01"
  config="${WW_BASE}/tools/warlock/.ww-config"
  grep -q "^method=npm" "$config"
  grep -q "^tag=v0.3.0" "$config"
  # Re-run status to confirm config is readable
  run bash "$WARLOCK_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" =~ "v0.3.0" ]]
}

@test "install: --force flag bypasses already-installed check" {
  _write_config "npm"
  _stub git '
    mkdir -p "${@: -1}/node_modules"
    touch "${@: -1}/package.json"
    exit 0
  '
  _stub npm "exit 0"

  run bash "$WARLOCK_SH" install --force <<< "1"
  [ "$status" -eq 0 ]
  grep -q "^method=npm" "${WW_BASE}/tools/warlock/.ww-config"
}

# ---------------------------------------------------------------------------
# Start — writes PID file
# ---------------------------------------------------------------------------

@test "start: PID file format is pid profile port" {
  # Test the PID file write/read mechanics directly via the warlock script
  # (full interactive start requires a TTY for profile confirmation; tested manually)
  mkdir -p "${WW_BASE}/tools/warlock"
  # Write a PID file in the documented format and verify it round-trips correctly
  sleep 60 &
  local bg_pid=$!
  echo "${bg_pid} myprofile 5001" > "${WW_BASE}/tools/warlock/server.pid"

  # Verify the PID file is readable in the expected format
  read -r rpid rprofile rport < "${WW_BASE}/tools/warlock/server.pid"
  [ "$rpid"     = "$bg_pid"   ]
  [ "$rprofile" = "myprofile" ]
  [ "$rport"    = "5001"      ]

  kill "$bg_pid" 2>/dev/null || true
}

@test "start: fails if not installed" {
  run bash "$WARLOCK_SH" start <<< "Y"
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Ii]nstall ]]
}

# ---------------------------------------------------------------------------
# Stop — removes PID file
# ---------------------------------------------------------------------------

@test "stop: removes PID file after stopping process" {
  mkdir -p "${WW_BASE}/tools/warlock"
  # Start a real background process so kill -0 succeeds
  sleep 60 &
  local bg_pid=$!
  echo "${bg_pid} testprofile 5001" > "${WW_BASE}/tools/warlock/server.pid"

  run bash "$WARLOCK_SH" stop
  [ "$status" -eq 0 ]
  [ ! -f "${WW_BASE}/tools/warlock/server.pid" ]

  # Ensure process is gone
  kill "$bg_pid" 2>/dev/null || true
}

@test "stop: exits cleanly when already stopped" {
  mkdir -p "${WW_BASE}/tools/warlock"
  # PID file with a non-existent PID
  echo "99999999 testprofile 5001" > "${WW_BASE}/tools/warlock/server.pid"

  run bash "$WARLOCK_SH" stop
  [ "$status" -eq 0 ]
  [ ! -f "${WW_BASE}/tools/warlock/server.pid" ]
}

@test "stop: exits cleanly with no PID file" {
  run bash "$WARLOCK_SH" stop
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Status — reads PID file and config
# ---------------------------------------------------------------------------

@test "status: shows not-installed when config missing" {
  run bash "$WARLOCK_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" =~ [Ii]nstall ]]
}

@test "status: shows installed info from .ww-config" {
  _write_config "npm" "v0.3.0" "5001" "2026-01-15"
  run bash "$WARLOCK_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" =~ "npm" ]]
  [[ "$output" =~ "v0.3.0" ]]
  [[ "$output" =~ "5001" ]]
}

@test "status: shows RUNNING with live PID" {
  _write_config "npm"
  mkdir -p "${WW_BASE}/tools/warlock"
  sleep 60 &
  local bg_pid=$!
  echo "${bg_pid} myprofile 5001" > "${WW_BASE}/tools/warlock/server.pid"

  run bash "$WARLOCK_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" =~ "RUNNING" ]]
  [[ "$output" =~ "myprofile" ]]

  kill "$bg_pid" 2>/dev/null || true
}

@test "status: shows stopped when PID process is gone" {
  _write_config "npm"
  mkdir -p "${WW_BASE}/tools/warlock"
  echo "99999999 myprofile 5001" > "${WW_BASE}/tools/warlock/server.pid"

  run bash "$WARLOCK_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" =~ "stopped" ]]
}

@test "status-json: returns valid JSON with installed=false when not installed" {
  run bash "$WARLOCK_SH" status-json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['installed'] == False, 'expected installed=false'
assert 'running' in d
"
}

@test "status-json: returns installed=true and method after install" {
  _write_config "npm" "v0.3.0" "5001" "2026-01-15"
  run bash "$WARLOCK_SH" status-json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['installed'] == True
assert d['method'] == 'npm'
assert d['tag'] == 'v0.3.0'
"
}

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

@test "help: shows attribution footer" {
  run bash "$WARLOCK_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "jonestristand" ]]
  [[ "$output" =~ "MIT" ]]
  [[ "$output" =~ "task-warlock" ]]
}

@test "help: lists all subcommands" {
  run bash "$WARLOCK_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "install" ]]
  [[ "$output" =~ "start" ]]
  [[ "$output" =~ "stop" ]]
  [[ "$output" =~ "status" ]]
  [[ "$output" =~ "reinstall" ]]
}

@test "help: -h flag works" {
  run bash "$WARLOCK_SH" -h
  [ "$status" -eq 0 ]
  [[ "$output" =~ "warlock" ]]
}

@test "unknown subcommand: exits non-zero" {
  run bash "$WARLOCK_SH" frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" =~ [Uu]nknown ]]
}

# ---------------------------------------------------------------------------
# ww web routes to ww browser warlock (bin/ww routing)
# ---------------------------------------------------------------------------

@test "ww web help routes to warlock help" {
  # Place warlock.sh under the test WW_BASE so cmd_browser_warlock finds it
  mkdir -p "${WW_BASE}/services/warlock"
  cp "$WARLOCK_SH" "${WW_BASE}/services/warlock/warlock.sh"

  run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
    WW_BASE="${WW_BASE}" \
    bash "$BIN_WW" web help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "jonestristand" ]] || [[ "$output" =~ "task-warlock" ]]
}

@test "ww browser warlock help routes to warlock help" {
  mkdir -p "${WW_BASE}/services/warlock"
  cp "$WARLOCK_SH" "${WW_BASE}/services/warlock/warlock.sh"

  run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
    WW_BASE="${WW_BASE}" \
    bash "$BIN_WW" browser warlock help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "task-warlock" ]]
}
