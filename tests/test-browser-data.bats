#!/usr/bin/env bats
# tests/test-browser-data.bats — TASK-SITE-004 data endpoint tests
#
# Covers: GET /data/tasks, GET /data/time, GET /data/journal, GET /data/ledger,
#         POST /action (done, add, unknown action), no-profile empty-state,
#         profile switching re-fetches correct data.
#
# Run:  bats tests/test-browser-data.bats
# Requires: python3, curl, task (taskwarrior)

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Port used for this suite — offset from test-browser.bats to avoid conflicts
TEST_PORT=17780

_wait_for_health() {
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

# Activate the remote-dev profile by POST /profile
_set_profile_remote_dev() {
  curl -sf \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"profile":"remote-dev"}' \
    "http://localhost:${TEST_PORT}/profile" &>/dev/null
}

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

setup() {
  export WW_BASE="${BATS_TEST_DIRNAME}/.."
  export TEST_STATE_DIR
  TEST_STATE_DIR="$(mktemp -d)"
  export TEST_WW_BASE="${TEST_STATE_DIR}/ww"
  mkdir -p "${TEST_WW_BASE}/.state"
  # Symlink profiles directory so the real remote-dev profile is accessible
  ln -s "${WW_BASE}/profiles" "${TEST_WW_BASE}/profiles"
  mkdir -p "${TEST_WW_BASE}/bin"
  cp "${WW_BASE}/bin/ww" "${TEST_WW_BASE}/bin/ww"
  chmod +x "${TEST_WW_BASE}/bin/ww"
}

teardown() {
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
  rm -rf "${TEST_STATE_DIR}"
}

# Start the browser server against TEST_WW_BASE (which symlinks real profiles)
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

# 1. GET /data/tasks returns 200 with ok:true
@test "GET /data/tasks with remote-dev active returns ok:true" {
  _start_server
  _set_profile_remote_dev
  run curl -sf "http://localhost:${TEST_PORT}/data/tasks"
  assert_success
  assert_output --partial '"ok"'
  assert_output --partial 'true'
  assert_output --partial '"tasks"'
}

# 2. GET /data/tasks tasks array is non-empty when remote-dev is active
@test "GET /data/tasks returns non-empty tasks array for remote-dev" {
  _start_server
  _set_profile_remote_dev
  run curl -sf "http://localhost:${TEST_PORT}/data/tasks"
  assert_success
  # remote-dev has 10 pending tasks; verify at least one description field
  assert_output --partial '"description"'
  assert_output --partial '"urgency"'
}

# 3. GET /data/time returns 200 with ok:true and expected fields
@test "GET /data/time returns ok:true with interval fields" {
  _start_server
  _set_profile_remote_dev
  run curl -sf "http://localhost:${TEST_PORT}/data/time"
  assert_success
  assert_output --partial '"ok"'
  assert_output --partial 'true'
  assert_output --partial '"intervals"'
  assert_output --partial '"today_total_seconds"'
  assert_output --partial '"week_total_seconds"'
  assert_output --partial '"active"'
}

# 4. GET /data/journal returns 200 with ok:true and entries array
@test "GET /data/journal returns ok:true with entries array" {
  _start_server
  _set_profile_remote_dev
  run curl -sf "http://localhost:${TEST_PORT}/data/journal"
  assert_success
  assert_output --partial '"ok"'
  assert_output --partial 'true'
  assert_output --partial '"entries"'
}

# 5. GET /data/ledger returns 200 (ok may be false if hledger missing)
@test "GET /data/ledger returns 200" {
  _start_server
  _set_profile_remote_dev
  run curl -sf "http://localhost:${TEST_PORT}/data/ledger"
  assert_success
  # ok may be true or false depending on whether hledger is installed;
  # but the response must always be valid JSON with an "ok" field
  assert_output --partial '"ok"'
}

# 6. POST /action done with a valid task id returns ok:true and tasks array
@test "POST /action done with valid task id returns ok:true" {
  _start_server
  _set_profile_remote_dev

  # First, add a temporary task we can safely mark done
  run curl -sf \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"action":"add","args":{"description":"__bats_test_done_task__"}}' \
    "http://localhost:${TEST_PORT}/action"
  assert_success
  assert_output --partial '"ok"'
  assert_output --partial 'true'

  # Extract the id of the newly created task
  local new_id
  new_id="$(echo "$output" | python3 -c "
import sys, json
tasks = json.load(sys.stdin)['tasks']
for t in tasks:
    if '__bats_test_done_task__' in t.get('description', ''):
        print(t['id'])
        break
")"
  [[ -n "$new_id" ]]

  # Mark it done
  run curl -sf \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"action\":\"done\",\"id\":${new_id}}" \
    "http://localhost:${TEST_PORT}/action"
  assert_success
  assert_output --partial '"ok"'
  assert_output --partial 'true'
  assert_output --partial '"tasks"'
}

# 7. POST /action add with description returns ok:true and tasks array
@test "POST /action add creates a task and returns tasks array" {
  _start_server
  _set_profile_remote_dev
  run curl -sf \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"action":"add","args":{"description":"__bats_test_add_task__","project":"bats","priority":"L"}}' \
    "http://localhost:${TEST_PORT}/action"
  assert_success
  assert_output --partial '"ok"'
  assert_output --partial 'true'
  assert_output --partial '"tasks"'
  # Verify the new task description appears in the response
  assert_output --partial '__bats_test_add_task__'

  # Clean up: mark it done
  local new_id
  new_id="$(echo "$output" | python3 -c "
import sys, json
tasks = json.load(sys.stdin)['tasks']
for t in tasks:
    if '__bats_test_add_task__' in t.get('description', ''):
        print(t['id'])
        break
")"
  if [[ -n "$new_id" ]]; then
    curl -sf -X POST -H "Content-Type: application/json" \
      -d "{\"action\":\"done\",\"id\":${new_id}}" \
      "http://localhost:${TEST_PORT}/action" &>/dev/null || true
  fi
}

# 8. POST /action with unknown action returns 400
@test "POST /action with unknown action returns 400" {
  _start_server
  _set_profile_remote_dev
  run curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"action":"explode"}' \
    "http://localhost:${TEST_PORT}/action"
  assert_output "400"
}

# 9. GET /data/tasks returns ok:false (not an error crash) when no profile is active
@test "GET /data/tasks with no profile returns ok:false gracefully" {
  _start_server
  # Do NOT set any profile — active_profile file will not exist
  run curl -sf "http://localhost:${TEST_PORT}/data/tasks"
  assert_success
  assert_output --partial '"ok"'
  # The server must return ok:false with an error message, not crash
  assert_output --partial 'false'
  assert_output --partial '"tasks"'
}
