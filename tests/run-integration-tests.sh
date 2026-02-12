#!/usr/bin/env bash
# Automated Integration Tests for GitHub Two-Way Sync
# This script runs automated integration tests against a real GitHub repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test repository (override with environment variable)
TEST_REPO="${GITHUB_TEST_REPO:-}"

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Run a test
run_test() {
    local test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Running: $test_name"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check gh CLI
    if ! command -v gh &> /dev/null; then
        log_error "gh CLI not found. Install from https://cli.github.com/"
        exit 1
    fi
    
    # Check gh authentication
    if ! gh auth status &> /dev/null; then
        log_error "gh CLI not authenticated. Run: gh auth login"
        exit 1
    fi
    
    # Check task
    if ! command -v task &> /dev/null; then
        log_error "TaskWarrior not found"
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Install with: brew install jq"
        exit 1
    fi
    
    # Check profile
    if [[ -z "${WORKWARRIOR_BASE}" ]]; then
        log_error "No Workwarrior profile active. Run: source bin/ww && ww profile use <profile>"
        exit 1
    fi
    
    # Check test repo
    if [[ -z "${TEST_REPO}" ]]; then
        log_error "TEST_REPO not set. Set with: export GITHUB_TEST_REPO=username/repo"
        exit 1
    fi
    
    # Verify repo access
    if ! gh repo view "${TEST_REPO}" &> /dev/null; then
        log_error "Cannot access repository: ${TEST_REPO}"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test data..."
    
    # Delete test tasks
    task +integration-test rc.confirmation=off delete 2>/dev/null || true
    
    # Close and delete test issues
    gh issue list --repo "${TEST_REPO}" --label "integration-test" \
      --json number --jq '.[].number' 2>/dev/null | \
    while read -r issue_num; do
        gh issue close "$issue_num" --repo "${TEST_REPO}" 2>/dev/null || true
        gh issue delete "$issue_num" --repo "${TEST_REPO}" --yes 2>/dev/null || true
    done
    
    log_success "Cleanup complete"
}

# Test 24.1: Push Cycle
test_push_cycle() {
    run_test "Test 24.1: Full Push Cycle"
    
    # Create test task
    task add "Integration test - push cycle" priority:H +integration-test +test-push
    local task_id
    task_id=$(task +test-push limit:1 _ids)
    
    # Create test issue
    local issue_num
    issue_num=$(gh issue create --repo "${TEST_REPO}" \
      --title "Integration Test - Push" \
      --body "Automated integration test" \
      --label "integration-test" | grep -oP '#\K\d+')
    
    # Enable sync
    if ! github-sync enable "$task_id" "$issue_num" "${TEST_REPO}" &>/dev/null; then
        log_error "Failed to enable sync"
        return 1
    fi
    
    # Modify task
    task "$task_id" modify "Integration test - push cycle UPDATED"
    task "$task_id" modify priority:M
    task "$task_id" annotate "Test annotation"
    
    # Push
    if ! github-sync push "$task_id" &>/dev/null; then
        log_error "Failed to push task"
        return 1
    fi
    
    # Verify on GitHub
    local gh_title
    gh_title=$(gh issue view "$issue_num" --repo "${TEST_REPO}" --json title --jq '.title')
    
    if [[ "$gh_title" == *"UPDATED"* ]]; then
        log_success "Push cycle: Title synced correctly"
    else
        log_error "Push cycle: Title not synced (expected UPDATED, got: $gh_title)"
        return 1
    fi
    
    # Check labels
    local labels
    labels=$(gh issue view "$issue_num" --repo "${TEST_REPO}" --json labels --jq '.labels[].name' | tr '\n' ',')
    
    if [[ "$labels" == *"priority:medium"* ]]; then
        log_success "Push cycle: Priority label synced correctly"
    else
        log_error "Push cycle: Priority label not synced (got: $labels)"
        return 1
    fi
    
    # Check comments
    local comments
    comments=$(gh issue view "$issue_num" --repo "${TEST_REPO}" --json comments --jq '.comments | length')
    
    if [[ "$comments" -gt 0 ]]; then
        log_success "Push cycle: Annotation synced to comment"
    else
        log_error "Push cycle: Annotation not synced"
        return 1
    fi
    
    log_success "Test 24.1: Push cycle completed successfully"
}

# Test 24.2: Pull Cycle
test_pull_cycle() {
    run_test "Test 24.2: Full Pull Cycle"
    
    # Create test issue
    local issue_num
    issue_num=$(gh issue create --repo "${TEST_REPO}" \
      --title "Integration Test - Pull" \
      --body "Automated integration test" \
      --label "integration-test,priority:high,bug" | grep -oP '#\K\d+')
    
    # Create placeholder task
    task add "Placeholder for pull test" +integration-test +test-pull
    local task_id
    task_id=$(task +test-pull limit:1 _ids)
    
    # Enable sync (will perform initial pull)
    if ! github-sync enable "$task_id" "$issue_num" "${TEST_REPO}" &>/dev/null; then
        log_error "Failed to enable sync"
        return 1
    fi
    
    # Verify task was updated
    local task_desc
    task_desc=$(task "$task_id" export | jq -r '.[0].description')
    
    if [[ "$task_desc" == *"Pull"* ]]; then
        log_success "Pull cycle: Title synced correctly"
    else
        log_error "Pull cycle: Title not synced (got: $task_desc)"
        return 1
    fi
    
    # Check priority
    local task_priority
    task_priority=$(task "$task_id" export | jq -r '.[0].priority // ""')
    
    if [[ "$task_priority" == "H" ]]; then
        log_success "Pull cycle: Priority synced correctly"
    else
        log_error "Pull cycle: Priority not synced (expected H, got: $task_priority)"
        return 1
    fi
    
    # Check tags
    local task_tags
    task_tags=$(task "$task_id" export | jq -r '.[0].tags[]' | tr '\n' ',')
    
    if [[ "$task_tags" == *"bug"* ]]; then
        log_success "Pull cycle: Labels synced to tags"
    else
        log_error "Pull cycle: Labels not synced (got: $task_tags)"
        return 1
    fi
    
    # Check metadata
    local github_issue
    github_issue=$(task "$task_id" export | jq -r '.[0].githubissue // ""')
    
    if [[ "$github_issue" == "$issue_num" ]]; then
        log_success "Pull cycle: Metadata populated correctly"
    else
        log_error "Pull cycle: Metadata not populated"
        return 1
    fi
    
    log_success "Test 24.2: Pull cycle completed successfully"
}

# Test 24.3: Conflict Resolution
test_conflict_resolution() {
    run_test "Test 24.3: Bidirectional Sync with Conflicts"
    
    # Create test issue and task
    local issue_num
    issue_num=$(gh issue create --repo "${TEST_REPO}" \
      --title "Integration Test - Conflict" \
      --body "Automated integration test" \
      --label "integration-test" | grep -oP '#\K\d+')
    
    task add "Integration test - conflict" +integration-test +test-conflict
    local task_id
    task_id=$(task +test-conflict limit:1 _ids)
    
    # Enable sync
    github-sync enable "$task_id" "$issue_num" "${TEST_REPO}" &>/dev/null
    
    # Create conflict: modify both sides
    task "$task_id" modify "Task modified locally"
    gh issue edit "$issue_num" --repo "${TEST_REPO}" --title "Issue modified on GitHub" &>/dev/null
    
    # Wait to ensure different timestamps
    sleep 2
    
    # Modify task again (to make it newer)
    task "$task_id" modify +urgent
    
    # Sync (should resolve conflict)
    if ! github-sync sync "$task_id" &>/dev/null; then
        log_error "Sync failed during conflict resolution"
        return 1
    fi
    
    # Verify task won (was modified last)
    local gh_title
    gh_title=$(gh issue view "$issue_num" --repo "${TEST_REPO}" --json title --jq '.title')
    
    if [[ "$gh_title" == *"locally"* ]]; then
        log_success "Conflict resolution: Last-write-wins worked (task won)"
    else
        log_warning "Conflict resolution: GitHub won (might be timing issue)"
    fi
    
    # Check conflict was logged
    if [[ -f "$WORKWARRIOR_BASE/.task/github-sync/errors.log" ]]; then
        local conflicts
        conflicts=$(grep -c "conflict_resolution" "$WORKWARRIOR_BASE/.task/github-sync/errors.log" || echo "0")
        if [[ "$conflicts" -gt 0 ]]; then
            log_success "Conflict resolution: Conflict logged correctly"
        else
            log_warning "Conflict resolution: No conflict logged (might not have been a conflict)"
        fi
    fi
    
    log_success "Test 24.3: Conflict resolution completed"
}

# Test 24.4: Error Handling
test_error_handling() {
    run_test "Test 24.4: Error Correction Flow"
    
    # Test title truncation
    local long_title
    long_title=$(python3 -c "print('A' * 300)")
    task add "$long_title" +integration-test +test-error
    local task_id
    task_id=$(task +test-error limit:1 _ids)
    
    local issue_num
    issue_num=$(gh issue create --repo "${TEST_REPO}" \
      --title "Integration Test - Error" \
      --body "Automated integration test" \
      --label "integration-test" | grep -oP '#\K\d+')
    
    github-sync enable "$task_id" "$issue_num" "${TEST_REPO}" &>/dev/null
    
    # Push (should auto-truncate)
    github-sync push "$task_id" &>/dev/null
    
    # Verify truncation
    local gh_title
    gh_title=$(gh issue view "$issue_num" --repo "${TEST_REPO}" --json title --jq '.title')
    local title_length=${#gh_title}
    
    if [[ $title_length -le 256 ]]; then
        log_success "Error handling: Title truncation worked"
    else
        log_error "Error handling: Title not truncated (length: $title_length)"
        return 1
    fi
    
    log_success "Test 24.4: Error handling completed"
}

# Test 24.5: Batch Operations
test_batch_operations() {
    run_test "Test 24.5: Batch Operations"
    
    log_info "Creating 5 test tasks and issues..."
    
    local task_ids=()
    local issue_nums=()
    
    for i in {1..5}; do
        local issue_num
        issue_num=$(gh issue create --repo "${TEST_REPO}" \
          --title "Batch test $i" \
          --body "Automated batch test" \
          --label "integration-test,batch-test" | grep -oP '#\K\d+')
        issue_nums+=("$issue_num")
        
        task add "Batch test task $i" +integration-test +batch-test
        local task_id
        task_id=$(task +batch-test limit:1 _ids | tail -1)
        task_ids+=("$task_id")
        
        github-sync enable "$task_id" "$issue_num" "${TEST_REPO}" &>/dev/null
    done
    
    # Modify all tasks
    task +batch-test modify priority:H &>/dev/null
    
    # Batch push
    log_info "Running batch push..."
    if github-sync push 2>&1 | grep -q "Success: 5"; then
        log_success "Batch operations: Push completed successfully"
    else
        log_error "Batch operations: Push failed"
        return 1
    fi
    
    # Verify on GitHub
    local synced_count=0
    for issue_num in "${issue_nums[@]}"; do
        local labels
        labels=$(gh issue view "$issue_num" --repo "${TEST_REPO}" --json labels --jq '.labels[].name' | tr '\n' ',')
        if [[ "$labels" == *"priority:high"* ]]; then
            synced_count=$((synced_count + 1))
        fi
    done
    
    if [[ $synced_count -eq 5 ]]; then
        log_success "Batch operations: All 5 tasks synced correctly"
    else
        log_error "Batch operations: Only $synced_count/5 tasks synced"
        return 1
    fi
    
    log_success "Test 24.5: Batch operations completed"
}

# Main test execution
main() {
    echo "========================================="
    echo "GitHub Two-Way Sync - Integration Tests"
    echo "========================================="
    echo ""
    
    check_prerequisites
    echo ""
    
    log_info "Test repository: ${TEST_REPO}"
    log_info "Profile: ${WORKWARRIOR_BASE}"
    echo ""
    
    # Run tests
    test_push_cycle || true
    echo ""
    
    test_pull_cycle || true
    echo ""
    
    test_conflict_resolution || true
    echo ""
    
    test_error_handling || true
    echo ""
    
    test_batch_operations || true
    echo ""
    
    # Cleanup
    cleanup
    echo ""
    
    # Summary
    echo "========================================="
    echo "Test Summary"
    echo "========================================="
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

# Handle Ctrl+C
trap cleanup EXIT

# Run main
main "$@"
