#!/usr/bin/env bats
# Tests for GitHub Sync State Manager (lib/github-sync-state.sh)
# Validates: TASK-SYNC-001, TASK-SYNC-002 fix coverage
# Tests: init_state_database, save_sync_state, get_sync_state, remove_sync_state

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export TEST_MODE=1
    export WORKWARRIOR_BASE
    WORKWARRIOR_BASE="$(mktemp -d)"
    export WW_BASE="${BATS_TEST_DIRNAME}/.."
    export PROFILES_DIR="${WORKWARRIOR_BASE}/profiles"

    source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
    source "${BATS_TEST_DIRNAME}/../lib/github-sync-state.sh"
}

teardown() {
    chmod -R u+w "${WORKWARRIOR_BASE}" 2>/dev/null || true
    rm -rf "${WORKWARRIOR_BASE}"
}

_state_file() {
    echo "${WORKWARRIOR_BASE}/.task/github-sync/state.json"
}

_valid_task_data() {
    echo '{"description":"Test task","status":"pending","priority":"M","tags":["work"],"annotations":[],"modified":"20241201T120000Z"}'
}

_valid_github_data() {
    echo '{"title":"Test Issue","state":"OPEN","number":42,"url":"https://github.com/owner/repo/issues/42","repository":{"nameWithOwner":"owner/repo"},"labels":[],"comments":[],"updatedAt":"2024-12-01T12:00:00Z"}'
}

# ============================================================================
# init_state_database
# ============================================================================

@test "init_state_database: creates state.json when missing" {
    run init_state_database
    assert_success
    assert [ -f "$(_state_file)" ]
}

@test "init_state_database: state.json is valid JSON" {
    run init_state_database
    assert_success
    run jq empty "$(_state_file)"
    assert_success
}

@test "init_state_database: initialises to empty object" {
    init_state_database
    run jq -r 'keys | length' "$(_state_file)"
    assert_output "0"
}

@test "init_state_database: recovers from corrupted state.json" {
    mkdir -p "${WORKWARRIOR_BASE}/.task/github-sync"
    echo "NOT { VALID JSON {{{{" > "$(_state_file)"
    run init_state_database
    assert_success
    run jq empty "$(_state_file)"
    assert_success
}

@test "init_state_database: fails without WORKWARRIOR_BASE" {
    local saved="${WORKWARRIOR_BASE}"
    unset WORKWARRIOR_BASE
    run init_state_database
    assert_failure
    export WORKWARRIOR_BASE="${saved}"
}

@test "init_state_database: idempotent — safe to call multiple times" {
    init_state_database
    init_state_database
    run jq empty "$(_state_file)"
    assert_success
}

# ============================================================================
# save_sync_state
# ============================================================================

@test "save_sync_state: writes entry to state.json" {
    run save_sync_state "uuid-abc" "$(_valid_task_data)" "$(_valid_github_data)"
    assert_success
    run jq -e '."uuid-abc"' "$(_state_file)"
    assert_success
}

@test "save_sync_state: saved state contains github_issue field" {
    save_sync_state "uuid-abc" "$(_valid_task_data)" "$(_valid_github_data)"
    run jq -r '."uuid-abc".github_issue' "$(_state_file)"
    assert_output "42"
}

@test "save_sync_state: saved state contains last_task_state.description" {
    save_sync_state "uuid-abc" "$(_valid_task_data)" "$(_valid_github_data)"
    run jq -r '."uuid-abc".last_task_state.description' "$(_state_file)"
    assert_output "Test task"
}

@test "save_sync_state: fails with empty uuid" {
    run save_sync_state "" "$(_valid_task_data)" "$(_valid_github_data)"
    assert_failure
}

@test "save_sync_state: fails with empty task_data" {
    run save_sync_state "uuid-abc" "" "$(_valid_github_data)"
    assert_failure
}

@test "save_sync_state: fails with empty github_data" {
    run save_sync_state "uuid-abc" "$(_valid_task_data)" ""
    assert_failure
}

@test "save_sync_state: multiple saves produce valid JSON" {
    save_sync_state "uuid-1" "$(_valid_task_data)" "$(_valid_github_data)"
    save_sync_state "uuid-2" "$(_valid_task_data)" "$(_valid_github_data)"
    save_sync_state "uuid-3" "$(_valid_task_data)" "$(_valid_github_data)"
    run jq empty "$(_state_file)"
    assert_success
    run jq -e '."uuid-1" and ."uuid-2" and ."uuid-3"' "$(_state_file)"
    assert_success
}

@test "save_sync_state: state.json unchanged when mv fails (Bug SYNC-002 fix)" {
    # Populate state with a known entry
    save_sync_state "existing-uuid" "$(_valid_task_data)" "$(_valid_github_data)"
    local original_content
    original_content=$(cat "$(_state_file)")

    # Make the state directory read-only so mv of .tmp → state.json fails
    chmod 555 "$(dirname "$(_state_file)")"

    run save_sync_state "new-uuid" "$(_valid_task_data)" "$(_valid_github_data)"

    # Restore permissions before assertions (needed for teardown)
    chmod 755 "$(dirname "$(_state_file)")"

    # The operation must have failed
    assert_failure

    # The original state.json must be intact
    local current_content
    current_content=$(cat "$(_state_file)")
    assert_equal "${original_content}" "${current_content}"
}

# ============================================================================
# get_sync_state
# ============================================================================

@test "get_sync_state: returns state for known UUID" {
    save_sync_state "uuid-known" "$(_valid_task_data)" "$(_valid_github_data)"
    run get_sync_state "uuid-known"
    assert_success
}

@test "get_sync_state: output is valid JSON" {
    save_sync_state "uuid-json" "$(_valid_task_data)" "$(_valid_github_data)"
    get_sync_state "uuid-json" | jq empty
}

@test "get_sync_state: fails for unknown UUID" {
    init_state_database
    run get_sync_state "no-such-uuid"
    assert_failure
}

@test "get_sync_state: fails with empty uuid" {
    run get_sync_state ""
    assert_failure
}

# ============================================================================
# remove_sync_state
# ============================================================================

@test "remove_sync_state: removes entry from state.json" {
    save_sync_state "uuid-del" "$(_valid_task_data)" "$(_valid_github_data)"
    run remove_sync_state "uuid-del"
    assert_success
    run jq -e '."uuid-del"' "$(_state_file)"
    assert_failure
}

@test "remove_sync_state: succeeds when UUID not present" {
    init_state_database
    run remove_sync_state "nonexistent-uuid"
    assert_success
}

@test "remove_sync_state: does not remove other entries" {
    save_sync_state "uuid-keep" "$(_valid_task_data)" "$(_valid_github_data)"
    save_sync_state "uuid-del" "$(_valid_task_data)" "$(_valid_github_data)"
    remove_sync_state "uuid-del"
    run jq -e '."uuid-keep"' "$(_state_file)"
    assert_success
}
