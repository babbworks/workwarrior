#!/usr/bin/env bash
# Foundation Component Tests
# Tests for State Manager, GitHub API, and TaskWarrior API wrappers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Source the components
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

source "${PROJECT_ROOT}/lib/github-sync-state.sh"
source "${PROJECT_ROOT}/lib/github-api.sh"
source "${PROJECT_ROOT}/lib/taskwarrior-api.sh"

# Test helper functions
test_start() {
    echo -e "\n${YELLOW}Testing: $1${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Check prerequisites
check_prerequisites() {
    echo -e "\n${YELLOW}=== Checking Prerequisites ===${NC}"
    
    # Check if profile is active
    if [[ -z "${WORKWARRIOR_BASE}" ]]; then
        echo -e "${RED}Error: No profile active. Please activate a profile first.${NC}"
        echo "Run: source bin/ww && p-<profile-name> (or use_task_profile <profile-name>)"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Profile active: ${WORKWARRIOR_BASE}"
    
    # Check for jq
    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: jq not found. Please install jq.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} jq installed"
    
    # Check for gh CLI
    if ! command -v gh &>/dev/null; then
        echo -e "${YELLOW}Warning: gh CLI not found. GitHub API tests will be skipped.${NC}"
        echo "Install with: brew install gh"
        GH_AVAILABLE=false
    else
        echo -e "${GREEN}✓${NC} gh CLI installed"
        
        # Check gh authentication
        if ! gh auth status &>/dev/null; then
            echo -e "${YELLOW}Warning: gh CLI not authenticated. GitHub API tests will be skipped.${NC}"
            echo "Authenticate with: gh auth login"
            GH_AVAILABLE=false
        else
            echo -e "${GREEN}✓${NC} gh CLI authenticated"
            GH_AVAILABLE=true
        fi
    fi
    
    # Check for task
    if ! command -v task &>/dev/null; then
        echo -e "${RED}Error: TaskWarrior not found.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} TaskWarrior installed"
    
    # Add GitHub sync UDAs if not present
    echo -e "\n${YELLOW}Checking GitHub sync UDAs...${NC}"
    local taskrc="${WORKWARRIOR_BASE}/.taskrc"
    if ! grep -q "uda.githubissue.type" "${taskrc}" 2>/dev/null; then
        echo -e "${YELLOW}Adding GitHub sync UDAs to .taskrc...${NC}"
        cat >> "${taskrc}" << 'EOF'

# GitHub sync UDAs
uda.githubissue.type=numeric
uda.githubissue.label=GitHub Issue

uda.githuburl.type=string
uda.githuburl.label=GitHub URL

uda.githubrepo.type=string
uda.githubrepo.label=GitHub Repo

uda.githubauthor.type=string
uda.githubauthor.label=GitHub Author

uda.githubsync.type=string
uda.githubsync.label=Sync Enabled
uda.githubsync.values=enabled,disabled
uda.githubsync.default=disabled
EOF
        echo -e "${GREEN}✓${NC} GitHub sync UDAs added"
    else
        echo -e "${GREEN}✓${NC} GitHub sync UDAs already present"
    fi
}

# Test State Manager
test_state_manager() {
    echo -e "\n${YELLOW}=== Testing State Manager ===${NC}"
    
    # Test 1: Initialize state database
    test_start "init_state_database()"
    if init_state_database; then
        if [[ -f "${WORKWARRIOR_BASE}/.task/github-sync/state.json" ]]; then
            test_pass "State database created"
        else
            test_fail "State database file not found"
        fi
    else
        test_fail "Failed to initialize state database"
    fi
    
    # Test 2: Save sync state
    test_start "save_sync_state()"
    local test_uuid="test-uuid-12345"
    local task_data='{"description":"Test task","status":"pending","priority":"H","tags":["test"],"annotations":[],"modified":"2024-01-15T10:00:00Z"}'
    local github_data='{"number":123,"title":"Test task","state":"OPEN","labels":[{"name":"test"}],"comments":[],"updatedAt":"2024-01-15T10:00:00Z","url":"https://github.com/test/repo/issues/123","repository":{"nameWithOwner":"test/repo"}}'
    
    if save_sync_state "${test_uuid}" "${task_data}" "${github_data}"; then
        test_pass "Sync state saved"
    else
        test_fail "Failed to save sync state"
    fi
    
    # Test 3: Get sync state
    test_start "get_sync_state()"
    local state
    state=$(get_sync_state "${test_uuid}")
    if [[ -n "${state}" ]]; then
        test_pass "Sync state retrieved"
    else
        test_fail "Failed to retrieve sync state"
    fi
    
    # Test 4: Check if task is synced
    test_start "is_task_synced()"
    if is_task_synced "${test_uuid}"; then
        test_pass "Task sync status checked"
    else
        test_fail "Failed to check task sync status"
    fi
    
    # Test 5: Get all synced tasks
    test_start "get_all_synced_tasks()"
    local synced_tasks
    synced_tasks=$(get_all_synced_tasks)
    if echo "${synced_tasks}" | grep -q "${test_uuid}"; then
        test_pass "All synced tasks retrieved"
    else
        test_fail "Failed to retrieve all synced tasks"
    fi
    
    # Test 6: Remove sync state
    test_start "remove_sync_state()"
    if remove_sync_state "${test_uuid}"; then
        if ! is_task_synced "${test_uuid}"; then
            test_pass "Sync state removed"
        else
            test_fail "Sync state still exists after removal"
        fi
    else
        test_fail "Failed to remove sync state"
    fi
}

# Test GitHub API Wrapper
test_github_api() {
    echo -e "\n${YELLOW}=== Testing GitHub API Wrapper ===${NC}"
    
    if [[ "${GH_AVAILABLE}" != "true" ]]; then
        echo -e "${YELLOW}Skipping GitHub API tests (gh CLI not available)${NC}"
        return
    fi
    
    # Test 1: Check gh CLI
    test_start "check_gh_cli()"
    if check_gh_cli; then
        test_pass "gh CLI check passed"
    else
        test_fail "gh CLI check failed"
    fi
    
    echo -e "\n${YELLOW}Note: Additional GitHub API tests require a test repository.${NC}"
    echo "To test manually, run:"
    echo "  source lib/github-api.sh"
    echo "  github_get_issue 'owner/repo' 123"
    echo "  github_update_issue 'owner/repo' 123 'New title' 'OPEN'"
    echo "  github_update_labels 'owner/repo' 123 'bug,feature' ''"
    echo "  github_add_comment 'owner/repo' 123 'Test comment'"
    echo "  github_ensure_label 'owner/repo' 'test-label'"
}

# Test TaskWarrior API Wrapper
test_taskwarrior_api() {
    echo -e "\n${YELLOW}=== Testing TaskWarrior API Wrapper ===${NC}"
    
    # Create a test task
    echo -e "\n${YELLOW}Creating test task...${NC}"
    local test_task_output
    test_task_output=$(task add "Test task for GitHub sync" priority:H +test 2>&1)
    local test_task_id
    test_task_id=$(echo "${test_task_output}" | grep -o 'Created task [0-9]*' | grep -o '[0-9]*')
    
    if [[ -z "${test_task_id}" ]]; then
        echo -e "${RED}Failed to create test task${NC}"
        return
    fi
    
    echo -e "${GREEN}✓${NC} Created test task ID: ${test_task_id}"
    
    # Get task UUID - use the ID directly with task command
    local test_uuid
    test_uuid=$(task _get "${test_task_id}.uuid" 2>/dev/null)
    
    if [[ -z "${test_uuid}" ]]; then
        echo -e "${RED}Failed to get task UUID${NC}"
        task "${test_task_id}" delete 2>&1 >/dev/null
        return
    fi
    
    echo -e "${GREEN}✓${NC} Task UUID: ${test_uuid}"
    
    # Test 1: Get task
    test_start "tw_get_task()"
    local task_data
    task_data=$(tw_get_task "${test_uuid}")
    if [[ -n "${task_data}" ]]; then
        test_pass "Task retrieved"
    else
        test_fail "Failed to retrieve task"
    fi
    
    # Test 2: Check if task exists
    test_start "tw_task_exists()"
    if tw_task_exists "${test_uuid}"; then
        test_pass "Task existence checked"
    else
        test_fail "Failed to check task existence"
    fi
    
    # Test 3: Update task field
    test_start "tw_update_task()"
    if tw_update_task "${test_uuid}" "githubissue" "999" 2>&1 | grep -q "Modified"; then
        test_pass "Task field updated"
    else
        # Try without checking output
        if tw_update_task "${test_uuid}" "githubissue" "999" 2>/dev/null; then
            test_pass "Task field updated"
        else
            test_fail "Failed to update task field"
        fi
    fi
    
    # Test 4: Get task by issue
    test_start "tw_get_task_by_issue()"
    local found_uuid
    found_uuid=$(tw_get_task_by_issue "999" 2>/dev/null)
    if [[ "${found_uuid}" == "${test_uuid}" ]]; then
        test_pass "Task found by issue number"
    else
        test_fail "Failed to find task by issue number (got: ${found_uuid})"
    fi
    
    # Test 5: Add annotation
    test_start "tw_add_annotation()"
    if tw_add_annotation "${test_uuid}" "Test annotation from sync test"; then
        test_pass "Annotation added"
    else
        test_fail "Failed to add annotation"
    fi
    
    # Test 6: Get field value
    test_start "tw_get_field()"
    local priority
    priority=$(tw_get_field "${test_uuid}" "priority")
    if [[ "${priority}" == "H" ]]; then
        test_pass "Field value retrieved"
    else
        test_fail "Failed to retrieve field value (got: ${priority})"
    fi
    
    # Cleanup: Delete test task
    echo -e "\n${YELLOW}Cleaning up test task...${NC}"
    task "${test_uuid}" delete rc.confirmation=off 2>&1 >/dev/null && echo -e "${GREEN}✓${NC} Test task deleted"
}

# Print summary
print_summary() {
    echo -e "\n${YELLOW}=== Test Summary ===${NC}"
    echo "Tests run: ${TESTS_RUN}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
        exit 1
    else
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Main execution
main() {
    echo -e "${YELLOW}=== GitHub Two-Way Sync Foundation Tests ===${NC}"
    
    check_prerequisites
    test_state_manager
    test_github_api
    test_taskwarrior_api
    print_summary
}

main "$@"
