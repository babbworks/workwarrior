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
# preflight_check — TASK-SYNC-003 pre-flight validation
#
# preflight_check lives in services/custom/github-sync.sh (a service, not a lib).
# To keep the test isolated from sourcing the full service dependency chain,
# each test invokes preflight_check via a bash subprocess that sources only the
# function definition extracted inline. This avoids set -euo pipefail propagation
# from the service file into the BATS runner context.
# ============================================================================

# Helper: run preflight_check in a fresh bash subprocess with full PATH control.
# This avoids sourcing the full service file (which carries set -euo pipefail).
# Args: --mock-gh <exit_code>  install a mock gh that exits with <exit_code>
#       --no-gh                do not install gh at all (tests not-installed path)
#       --no-jq                do not install jq at all (tests not-installed path)
#       --unset-base           run without WORKWARRIOR_BASE set
#
# All other system binaries (sed, grep, etc.) are accessible via /usr/bin:/bin.
_run_preflight_check() {
    local mock_gh_exit=0
    local include_gh=true
    local include_jq=true
    local set_base=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mock-gh)   mock_gh_exit="$2"; shift 2 ;;
            --no-gh)     include_gh=false; shift ;;
            --no-jq)     include_jq=false; shift ;;
            --unset-base) set_base=false; shift ;;
            *)            shift ;;
        esac
    done

    local tmp_bin
    tmp_bin="$(mktemp -d)"

    if [[ "${include_gh}" == "true" ]]; then
        cat > "${tmp_bin}/gh" << GHEOF
#!/usr/bin/env bash
exit ${mock_gh_exit}
GHEOF
        chmod +x "${tmp_bin}/gh"
    fi

    # Provide a real jq via symlink to the system binary if available
    if [[ "${include_jq}" == "true" ]]; then
        local real_jq
        real_jq=$(command -v jq 2>/dev/null || true)
        if [[ -n "${real_jq}" ]]; then
            ln -s "${real_jq}" "${tmp_bin}/jq"
        fi
    fi
    # When --no-jq: jq is not placed in tmp_bin, so PATH will not find it
    # (tmp_bin is the only directory in PATH that we control)

    local base_val=""
    if [[ "${set_base}" == "true" ]]; then
        base_val="${WORKWARRIOR_BASE}"
    fi

    # Extract just the preflight_check function body — avoids sourcing the full
    # service file and propagating its set -euo pipefail into BATS.
    local func_body
    func_body=$(sed -n '/^preflight_check()/,/^}/p' \
        "${BATS_TEST_DIRNAME}/../services/custom/github-sync.sh")

    run bash -c "
        export PATH='${tmp_bin}:/usr/bin:/bin'
        export WORKWARRIOR_BASE='${base_val}'
        ${func_body}
        preflight_check
    "

    rm -rf "${tmp_bin}"
}

@test "preflight_check: fails with category env-missing when WORKWARRIOR_BASE is unset" {
    _run_preflight_check --unset-base
    assert_failure
    assert_output --partial "env-missing"
    assert_output --partial "WORKWARRIOR_BASE"
}

@test "preflight_check: fails with category not-installed when jq is absent" {
    _run_preflight_check --no-jq
    assert_failure
    assert_output --partial "not-installed"
    assert_output --partial "jq"
}

@test "preflight_check: fails with category not-installed when gh is absent" {
    _run_preflight_check --no-gh
    assert_failure
    assert_output --partial "not-installed"
    assert_output --partial "gh"
}

@test "preflight_check: fails with category not-authenticated when gh auth fails" {
    _run_preflight_check --mock-gh 1
    assert_failure
    assert_output --partial "not-authenticated"
    assert_output --partial "gh auth login"
}

@test "preflight_check: succeeds when all dependencies present and gh authenticated" {
    _run_preflight_check --mock-gh 0
    assert_success
}

# ============================================================================
# _check_rate_limit — TASK-SYNC-003 rate-limit detection
# ============================================================================

@test "_check_rate_limit: detects 'API rate limit exceeded' string" {
    run _check_rate_limit "API rate limit exceeded for this resource"
    assert_success
    assert_output --partial "rate limit"
}

@test "_check_rate_limit: detects HTTP 429 in error output" {
    run _check_rate_limit "HTTP 429 Too Many Requests"
    assert_success
    assert_output --partial "rate limit"
}

@test "_check_rate_limit: returns non-zero (not rate-limited) for generic errors" {
    run _check_rate_limit "Could not resolve to an Issue"
    assert_failure
}

@test "_check_rate_limit: returns non-zero for empty error output" {
    run _check_rate_limit ""
    assert_failure
}

# ============================================================================
# _sync_tags_to_task — TASK-SYNC-005 GitHub label → TaskWarrior tag sync
#
# Each test runs _sync_tags_to_task in a subprocess with mocked tw API functions
# so the full sync-pull.sh dependency chain is not sourced. SYSTEM_TAGS is
# extracted from field-mapper.sh so the exclusion logic mirrors production.
# ============================================================================

# Helper: run _sync_tags_to_task in a fresh bash subprocess.
# Args: current_tags_json  new_tags_json  [tw_update_exit_code]
_run_sync_tags() {
    local current_tags="${1:-[]}"
    local new_tags="${2:-[]}"
    local update_exit="${3:-0}"

    local func_body sys_tags_line
    func_body=$(sed -n '/^_sync_tags_to_task()/,/^}/p' \
        "${BATS_TEST_DIRNAME}/../lib/sync-pull.sh")
    sys_tags_line=$(grep '^SYSTEM_TAGS=' \
        "${BATS_TEST_DIRNAME}/../lib/field-mapper.sh")

    run bash -c "
        ${sys_tags_line}
        tw_get_field() { echo '${current_tags}'; }
        tw_update_task_fields() {
            shift  # skip task_uuid
            for arg in \"\$@\"; do echo \"ARG:\${arg}\"; done
            return ${update_exit}
        }
        ${func_body}
        _sync_tags_to_task 'test-uuid-1234' '${new_tags}'
    "
}

@test "_sync_tags_to_task: maps GitHub labels to tags on task with no existing tags" {
    _run_sync_tags '[]' '["bug","feature"]'
    assert_success
    assert_output --partial "ARG:+bug"
    assert_output --partial "ARG:+feature"
}

@test "_sync_tags_to_task: preserves system tags when replacing non-system tags" {
    _run_sync_tags '["ACTIVE","bug"]' '["feature"]'
    assert_success
    assert_output --partial "ARG:-bug"
    assert_output --partial "ARG:+feature"
    refute_output --partial "ARG:-ACTIVE"
}

@test "_sync_tags_to_task: empty label set removes non-system tags only" {
    _run_sync_tags '["bug","ACTIVE"]' '[]'
    assert_success
    assert_output --partial "ARG:-bug"
    refute_output --partial "ARG:-ACTIVE"
}

@test "_sync_tags_to_task: deduplicates labels before applying tag changes" {
    _run_sync_tags '[]' '["bug","bug"]'
    assert_success
    assert_output "ARG:+bug"
}

@test "_sync_tags_to_task: no-op when current tags already match label set" {
    _run_sync_tags '["bug"]' '["bug"]'
    assert_success
    refute_output --partial "ARG:"
}

@test "_sync_tags_to_task: returns failure when tw_update_task_fields fails" {
    _run_sync_tags '[]' '["bug"]' 1
    assert_failure
}
