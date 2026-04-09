#!/usr/bin/env bats
# tests/test-browser.bats — Workwarrior browser service test suite
#
# Covers: --help, status (not running), /health, status (running), POST /cmd,
#         POST /cmd disallowed, POST /profile valid, POST /profile invalid,
#         GET /events content-type, ww browser stop, port conflict.
#
# Run:  bats tests/test-browser.bats
# Requires: python3, curl

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Port used for the primary test server. Chosen to avoid collisions with the
# default 7777 while tests run alongside a real server.
TEST_PORT=17777
TEST_PORT2=17778

_wait_for_health() {
  # Wait up to 10 seconds for /health to return HTTP 200.
  local port="${1:-$TEST_PORT}"
  local waited=0
  while [[ $waited -lt 100 ]]; do
    if curl -sf "http://localhost:${port}/health" &>/dev/null; then
      return 0
    fi
    sleep 0.1
    waited=$(( waited + 1 ))
  done
  return 1
}

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

setup() {
  export WW_BASE="${BATS_TEST_DIRNAME}/.."
  # Use a private temp dir for state files so tests do not pollute real state
  export TEST_STATE_DIR
  TEST_STATE_DIR="$(mktemp -d)"
  export TEST_WW_BASE="${TEST_STATE_DIR}/ww"
  mkdir -p "${TEST_WW_BASE}/.state"
  mkdir -p "${TEST_WW_BASE}/profiles/testprofile"
  mkdir -p "${TEST_WW_BASE}/bin"
  # Provide a minimal ww stub so POST /cmd can resolve the binary
  cp "${WW_BASE}/bin/ww" "${TEST_WW_BASE}/bin/ww"
  chmod +x "${TEST_WW_BASE}/bin/ww"
}

teardown() {
  # Stop any server that may still be running on TEST_PORT
  local pid_file="${TEST_WW_BASE}/.state/browser.pid"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 0.3
    fi
    rm -f "$pid_file" "${TEST_WW_BASE}/.state/browser.port"
  fi
  # Also kill any stray server on TEST_PORT2 (port-conflict test)
  local pid2_file="${TEST_WW_BASE}/.state/browser2.pid"
  if [[ -f "$pid2_file" ]]; then
    local pid2
    pid2="$(cat "$pid2_file" 2>/dev/null || true)"
    if [[ -n "$pid2" ]] && kill -0 "$pid2" 2>/dev/null; then
      kill "$pid2" 2>/dev/null || true
    fi
    rm -f "$pid2_file"
  fi
  rm -rf "${TEST_STATE_DIR}"
}

# Start the browser server in the background and wait for /health.
# Uses TEST_WW_BASE so state files do not pollute the real ww base.
_start_server() {
  local port="${1:-$TEST_PORT}"
  WW_BASE="${TEST_WW_BASE}" \
    python3 "${WW_BASE}/services/browser/server.py" \
      --port "${port}" \
      --no-open \
      --ww-base "${TEST_WW_BASE}" \
      &
  _wait_for_health "${port}"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# 1. --help exits 0 and contains "Usage"
@test "browser --help exits 0 and contains Usage" {
  run bash "${WW_BASE}/services/browser/browser.sh" --help
  assert_success
  assert_output --partial "Usage"
}

# 2. status when not running prints "not running"
@test "browser status when not running prints 'not running'" {
  run bash "${WW_BASE}/services/browser/browser.sh" \
    --port "${TEST_PORT}" status
  # Note: browser.sh reads state from WW_BASE, so we need to set it
  # Rerun with correct WW_BASE
  run env WW_BASE="${TEST_WW_BASE}" \
    bash "${WW_BASE}/services/browser/browser.sh" status
  assert_success
  assert_output --partial "not running"
}

# 3. /health returns {"status":"ok",...}
@test "GET /health returns status ok JSON" {
  _start_server "${TEST_PORT}"
  run curl -sf "http://localhost:${TEST_PORT}/health"
  assert_success
  # Python's json.dumps uses spaces after colons; match the key/value pair loosely
  assert_output --partial '"status"'
  assert_output --partial '"ok"'
  assert_output --partial '"version"'
  assert_output --partial '1.0.0'
}

# 4. status when running prints "running"
@test "browser status when running prints 'running'" {
  _start_server "${TEST_PORT}"
  run env WW_BASE="${TEST_WW_BASE}" \
    bash "${WW_BASE}/services/browser/browser.sh" status
  assert_success
  assert_output --partial "running on http://localhost:${TEST_PORT}"
}

# 5. POST /cmd with valid subcommand returns ok:true
@test "POST /cmd with valid subcommand returns ok:true" {
  _start_server "${TEST_PORT}"
  run curl -sf \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"cmd":"version"}' \
    "http://localhost:${TEST_PORT}/cmd"
  assert_success
  # Python json.dumps uses spaces; match key and value separately
  assert_output --partial '"ok"'
  assert_output --partial 'true'
  assert_output --partial '"exit_code"'
}

# 6. POST /cmd with disallowed command returns 400
@test "POST /cmd with disallowed command returns 400" {
  _start_server "${TEST_PORT}"
  run curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"cmd":"rm -rf /"}' \
    "http://localhost:${TEST_PORT}/cmd"
  assert_output "400"
}

# 7. POST /profile with valid profile returns ok:true
@test "POST /profile with valid profile returns ok:true" {
  _start_server "${TEST_PORT}"
  run curl -sf \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"profile":"testprofile"}' \
    "http://localhost:${TEST_PORT}/profile"
  assert_success
  # Python json.dumps uses spaces; match key/values separately
  assert_output --partial '"ok"'
  assert_output --partial 'true'
  assert_output --partial '"profile"'
  assert_output --partial 'testprofile'
}

# 8. POST /profile with invalid profile returns 400
@test "POST /profile with invalid profile returns 400" {
  _start_server "${TEST_PORT}"
  run curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"profile":"no-such-profile-xyz"}' \
    "http://localhost:${TEST_PORT}/profile"
  assert_output "400"
}

# 9. GET /events returns content-type text/event-stream
@test "GET /events returns Content-Type text/event-stream" {
  _start_server "${TEST_PORT}"
  # Use -v and --max-time 2 to capture response headers without hanging.
  # -I sends HEAD which the server rejects; use GET (-G / no method flag) instead.
  # curl -v writes headers to stderr; redirect both streams for assert_output.
  run bash -c "curl -sf --max-time 2 -v 'http://localhost:${TEST_PORT}/events' 2>&1 || true"
  assert_output --partial "text/event-stream"
}

# 10. ww browser stop stops server
@test "ww browser stop stops the server" {
  _start_server "${TEST_PORT}"
  # Confirm it is running
  run curl -sf "http://localhost:${TEST_PORT}/health"
  assert_success

  # Stop it
  run env WW_BASE="${TEST_WW_BASE}" \
    bash "${WW_BASE}/services/browser/browser.sh" stop
  assert_success
  assert_output --partial "stopped"

  # Confirm it no longer responds
  sleep 0.5
  run curl -sf --max-time 2 "http://localhost:${TEST_PORT}/health" || true
  # curl should fail (non-zero) since server is down
  [ "$status" -ne 0 ] || [ -z "$output" ]
}

# 11. Port conflict exits 1 with error message
@test "starting server on occupied port exits 1 with error" {
  _start_server "${TEST_PORT}"

  # Try to start a second server on the same port — must fail with exit code 1
  run python3 "${WW_BASE}/services/browser/server.py" \
    --port "${TEST_PORT}" \
    --ww-base "${TEST_WW_BASE}"
  assert_failure
  assert_output --partial "already in use"
}

# ── Wave 2: static file serving ─────────────────────────────────────────────

# 12. GET / returns 200 with text/html content-type
@test "GET / returns 200 with text/html content-type" {
  _start_server "${TEST_PORT}"
  run curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/
  [ "$output" = "200" ]
}

# 13. GET / body contains workwarrior
@test "GET / body contains workwarrior" {
  _start_server "${TEST_PORT}"
  run curl -s http://localhost:${TEST_PORT}/
  echo "$output" | grep -qi "workwarrior"
}

# 14. GET /style.css returns 200 with text/css content-type
@test "GET /style.css returns 200 with text/css content-type" {
  _start_server "${TEST_PORT}"
  run curl -s -o /dev/null -w "%{content_type}" http://localhost:${TEST_PORT}/style.css
  [[ "$output" == *"text/css"* ]]
}

# 15. GET /app.js returns 200 with application/javascript content-type
@test "GET /app.js returns 200 with application/javascript content-type" {
  _start_server "${TEST_PORT}"
  run curl -s -o /dev/null -w "%{content_type}" http://localhost:${TEST_PORT}/app.js
  [[ "$output" == *"javascript"* ]]
}

# 16. GET /nonexistent returns 404
@test "GET /nonexistent returns 404" {
  _start_server "${TEST_PORT}"
  run curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/nonexistent
  [ "$output" = "404" ]
}
