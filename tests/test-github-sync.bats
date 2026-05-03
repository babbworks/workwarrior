#!/usr/bin/env bats
# Tests for GitHub Sync Engine — API wrapper and change detection
# Validates: TASK-SYNC-001, TASK-SYNC-002 fix coverage
# Tests: check_gh_cli, github_get_issue, detect_task_changes, detect_github_changes

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export TEST_MODE=1
    export WW_BASE="${BATS_TEST_DIRNAME}/.."
    export WORKWARRIOR_BASE
    WORKWARRIOR_BASE="$(mktemp -d)"
    export PROFILES_DIR="${WORKWARRIOR_BASE}/profiles"

    # Create mock bin directory and prepend to PATH so we control gh
    export _WW_MOCK_BIN="${BATS_TEST_TMPDIR}/mock-bin-$$"
    mkdir -p "${_WW_MOCK_BIN}"
    export PATH="${_WW_MOCK_BIN}:${PATH}"

    # Default mock gh: not installed (command will be absent unless test adds it)
    source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
    source "${BATS_TEST_DIRNAME}/../lib/field-mapper.sh"
    source "${BATS_TEST_DIRNAME}/../lib/sync-detector.sh"
    source "${BATS_TEST_DIRNAME}/../lib/github-api.sh"
}

teardown() {
    rm -rf "${WORKWARRIOR_BASE}" "${_WW_MOCK_BIN}"
}

# Install a mock gh that exits with given code and optional output
_mock_gh() {
    local exit_code="${1:-1}"
    local stderr_msg="${2:-}"
    cat > "${_WW_MOCK_BIN}/gh" << EOF
#!/usr/bin/env bash
[[ -n "${stderr_msg}" ]] && echo "${stderr_msg}" >&2
exit ${exit_code}
EOF
    chmod +x "${_WW_MOCK_BIN}/gh"
}

# Install a mock gh that returns JSON issue data on success
_mock_gh_issue() {
    local json="${1}"
    cat > "${_WW_MOCK_BIN}/gh" << EOF
#!/usr/bin/env bash
# Mock: simulate "gh auth status" succeeding (no args check needed — just succeed)
echo '${json}'
exit 0
EOF
    chmod +x "${_WW_MOCK_BIN}/gh"
}

_valid_task_state() {
    echo '{"description":"Test task","status":"pending","priority":"M","tags":["work"],"annotations":[],"annotation_count":0}'
}

_valid_github_state() {
    echo '{"title":"Test issue","state":"OPEN","labels":[],"comments":[],"comment_count":0}'
}

# ============================================================================
# check_gh_cli
# ============================================================================

@test "check_gh_cli: fails when gh is not installed" {
    local no_gh_dir="${BATS_TEST_TMPDIR}/no-gh-$$"
    mkdir -p "${no_gh_dir}"
    # Temporarily replace PATH so gh is not found (keep /usr/bin and /bin for jq etc.)
    local saved_path="$PATH"
    export PATH="${no_gh_dir}:/usr/bin:/bin"
    run check_gh_cli
    export PATH="$saved_path"
    assert_failure
    assert_output --partial "gh CLI not found"
}

@test "check_gh_cli: fails when gh is installed but not authenticated" {
    # Mock gh that fails auth status
    _mock_gh 1 "not authenticated"
    run check_gh_cli
    assert_failure
}

@test "check_gh_cli: succeeds when gh is installed and authenticated" {
    # Mock gh that succeeds for all invocations (including auth status)
    _mock_gh 0 ""
    run check_gh_cli
    assert_success
}

# ============================================================================
# github_get_issue
# ============================================================================

@test "github_get_issue: fails with empty repo" {
    run github_get_issue "" "42"
    assert_failure
    assert_output --partial "repo required"
}

@test "github_get_issue: fails with empty issue_number" {
    run github_get_issue "owner/repo" ""
    assert_failure
    assert_output --partial "issue_number required"
}

@test "github_get_issue: fails when gh not authenticated" {
    _mock_gh 1 "not authenticated"
    run github_get_issue "owner/repo" "42"
    assert_failure
}

@test "github_get_issue: returns issue data on success" {
    local issue_json='{"number":42,"title":"Test","state":"OPEN","labels":[],"comments":[],"url":"https://github.com/o/r/issues/42"}'
    # Mock gh auth status (succeeds) and gh issue view (returns JSON)
    cat > "${_WW_MOCK_BIN}/gh" << 'EOF'
#!/usr/bin/env bash
# Both "gh auth status" and "gh issue view" succeed
echo '{"number":42,"title":"Test","state":"OPEN","labels":[],"comments":[],"url":"https://github.com/o/r/issues/42"}'
exit 0
EOF
    chmod +x "${_WW_MOCK_BIN}/gh"
    run github_get_issue "owner/repo" "42"
    assert_success
    assert_output --partial '"number":42'
}

# ============================================================================
# detect_task_changes — input validation (TASK-SYNC-002 fix coverage)
# ============================================================================

@test "detect_task_changes: fails with malformed current_state JSON" {
    run detect_task_changes "uuid-1" "NOT_VALID_JSON{{" "$(_valid_task_state)"
    assert_failure
    assert_output --partial "not valid JSON"
}

@test "detect_task_changes: fails with malformed last_state JSON" {
    run detect_task_changes "uuid-1" "$(_valid_task_state)" "{broken:json"
    assert_failure
    assert_output --partial "not valid JSON"
}

@test "detect_task_changes: fails with empty states" {
    run detect_task_changes "uuid-1" "" ""
    assert_failure
}

# ============================================================================
# detect_task_changes — change detection
# ============================================================================

@test "detect_task_changes: returns 1 (no changes) for identical states" {
    local state
    state=$(_valid_task_state)
    run detect_task_changes "uuid-1" "${state}" "${state}"
    assert_equal "1" "${status}"
}

@test "detect_task_changes: returns 0 when description changed" {
    local curr='{"description":"New description","status":"pending","priority":"M","tags":["work"],"annotations":[],"annotation_count":0}'
    local last='{"description":"Old description","status":"pending","priority":"M","tags":["work"],"annotations":[],"annotation_count":0}'
    run detect_task_changes "uuid-1" "${curr}" "${last}"
    assert_equal "0" "${status}"
    assert_output --partial "description"
}

@test "detect_task_changes: returns 0 when status changed" {
    local curr='{"description":"Task","status":"completed","priority":"M","tags":[],"annotations":[],"annotation_count":0}'
    local last='{"description":"Task","status":"pending","priority":"M","tags":[],"annotations":[],"annotation_count":0}'
    run detect_task_changes "uuid-1" "${curr}" "${last}"
    assert_equal "0" "${status}"
    assert_output --partial "status"
}

@test "detect_task_changes: returns 0 when tags changed" {
    local curr='{"description":"Task","status":"pending","priority":"M","tags":["work","urgent"],"annotations":[],"annotation_count":0}'
    local last='{"description":"Task","status":"pending","priority":"M","tags":["work"],"annotations":[],"annotation_count":0}'
    run detect_task_changes "uuid-1" "${curr}" "${last}"
    assert_equal "0" "${status}"
    assert_output --partial "tags"
}

@test "detect_task_changes: change output is valid JSON" {
    local curr='{"description":"New","status":"pending","priority":"M","tags":[],"annotations":[],"annotation_count":0}'
    local last='{"description":"Old","status":"pending","priority":"M","tags":[],"annotations":[],"annotation_count":0}'
    local changes
    changes=$(detect_task_changes "uuid-1" "${curr}" "${last}")
    run jq empty <<< "${changes}"
    assert_success
}

@test "detect_task_changes: tag order does not affect change detection" {
    # Same tags in different order — should be no change
    local curr='{"description":"Task","status":"pending","priority":"M","tags":["b","a"],"annotations":[],"annotation_count":0}'
    local last='{"description":"Task","status":"pending","priority":"M","tags":["a","b"],"annotations":[],"annotation_count":0}'
    run detect_task_changes "uuid-1" "${curr}" "${last}"
    assert_equal "1" "${status}"
}

# ============================================================================
# detect_github_changes — input validation
# ============================================================================

@test "detect_github_changes: fails with malformed current_state JSON" {
    run detect_github_changes "42" "NOT_VALID_JSON{{" "$(_valid_github_state)"
    assert_failure
    assert_output --partial "not valid JSON"
}

@test "detect_github_changes: fails with malformed last_state JSON" {
    run detect_github_changes "42" "$(_valid_github_state)" "{broken"
    assert_failure
    assert_output --partial "not valid JSON"
}

@test "detect_github_changes: returns 1 for identical states" {
    local state
    state=$(_valid_github_state)
    run detect_github_changes "42" "${state}" "${state}"
    assert_equal "1" "${status}"
}

@test "detect_github_changes: returns 0 when title changed" {
    local curr='{"title":"New Title","state":"OPEN","labels":[],"comments":[],"comment_count":0}'
    local last='{"title":"Old Title","state":"OPEN","labels":[],"comment_count":0}'
    run detect_github_changes "42" "${curr}" "${last}"
    assert_equal "0" "${status}"
    assert_output --partial "title"
}

@test "detect_github_changes: returns 0 when state changed" {
    local curr='{"title":"Issue","state":"CLOSED","labels":[],"comments":[],"comment_count":0}'
    local last='{"title":"Issue","state":"OPEN","labels":[],"comment_count":0}'
    run detect_github_changes "42" "${curr}" "${last}"
    assert_equal "0" "${status}"
    assert_output --partial "state"
}

# ============================================================================
# sync_preflight — TASK-SYNC-003
# ============================================================================

@test "sync_preflight: fails with [env-missing] when WORKWARRIOR_BASE unset" {
    source "${BATS_TEST_DIRNAME}/../services/custom/github-sync.sh" 2>/dev/null || true
    local saved="${WORKWARRIOR_BASE:-}"
    unset WORKWARRIOR_BASE
    run sync_preflight
    export WORKWARRIOR_BASE="${saved}"
    assert_failure
    assert_output --partial "[env-missing]"
}

@test "sync_preflight: fails with [not-installed] when jq missing" {
    source "${BATS_TEST_DIRNAME}/../services/custom/github-sync.sh" 2>/dev/null || true
    local no_jq_dir="${BATS_TEST_TMPDIR}/no-jq-$$"
    mkdir -p "${no_jq_dir}"
    _mock_gh 0 ""
    local saved_path="$PATH"
    export PATH="${no_jq_dir}:${_WW_MOCK_BIN}"
    run sync_preflight
    export PATH="${saved_path}"
    assert_failure
    assert_output --partial "[not-installed]"
}

@test "sync_preflight: fails with [not-installed] when gh missing" {
    source "${BATS_TEST_DIRNAME}/../services/custom/github-sync.sh" 2>/dev/null || true
    local no_gh_dir="${BATS_TEST_TMPDIR}/no-gh2-$$"
    mkdir -p "${no_gh_dir}"
    local saved_path="$PATH"
    export PATH="${no_gh_dir}:/usr/bin:/bin"
    run sync_preflight
    export PATH="${saved_path}"
    assert_failure
    assert_output --partial "[not-installed]"
}

@test "sync_preflight: fails with [not-authenticated] when gh not authed" {
    source "${BATS_TEST_DIRNAME}/../services/custom/github-sync.sh" 2>/dev/null || true
    _mock_gh 1 "not authenticated"
    run sync_preflight
    assert_failure
    assert_output --partial "[not-authenticated]"
}

@test "sync_preflight: succeeds when environment is valid" {
    source "${BATS_TEST_DIRNAME}/../services/custom/github-sync.sh" 2>/dev/null || true
    _mock_gh 0 ""
    run sync_preflight
    assert_success
}

# ============================================================================
# check_gh_cli — categorised error codes (TASK-SYNC-003)
# ============================================================================

@test "check_gh_cli: returns exit code 2 when gh not installed" {
    local no_gh_dir="${BATS_TEST_TMPDIR}/no-gh3-$$"
    mkdir -p "${no_gh_dir}"
    local saved_path="$PATH"
    export PATH="${no_gh_dir}:/usr/bin:/bin"
    run check_gh_cli
    export PATH="${saved_path}"
    assert_equal "2" "${status}"
    assert_output --partial "[not-installed]"
}

@test "check_gh_cli: returns exit code 3 when gh not authenticated" {
    _mock_gh 1 "not authenticated"
    run check_gh_cli
    assert_equal "3" "${status}"
    assert_output --partial "[not-authenticated]"
}

# ============================================================================
# github_get_issue — rate-limit detection (TASK-SYNC-003)
# ============================================================================

@test "github_get_issue: detects rate limit and emits [rate-limited] error" {
    cat > "${_WW_MOCK_BIN}/gh" << 'EOF'
#!/usr/bin/env bash
# auth status succeeds; issue view fails with rate limit
if [[ "$1" == "auth" ]]; then exit 0; fi
echo "error: HTTP 429: secondary rate limit exceeded" >&2
exit 1
EOF
    chmod +x "${_WW_MOCK_BIN}/gh"
    run github_get_issue "owner/repo" "42"
    assert_failure
    assert_output --partial "[rate-limited]"
}

@test "github_get_issue: emits [not-found] for deleted issue" {
    cat > "${_WW_MOCK_BIN}/gh" << 'EOF'
#!/usr/bin/env bash
# auth status succeeds; issue view returns not-found
if [[ "$1" == "auth" ]]; then exit 0; fi
echo "Could not resolve to an Issue" >&2
exit 1
EOF
    chmod +x "${_WW_MOCK_BIN}/gh"
    run github_get_issue "owner/repo" "99"
    assert_failure
    assert_output --partial "[not-found]"
}
