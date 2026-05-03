#!/usr/bin/env bash
# Test script for Questions Service (Task 15)
# Tests: q function, template creation, template usage, handlers
# Validates: Requirements 12.1-12.10, 13.1-13.10

# Don't use set -e as we handle errors manually in tests

# Source the core utilities library and questions service
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core-utils.sh"
source "$SCRIPT_DIR/../services/questions/q.sh"

# Test configuration
TEST_PROFILE="test-questions-$$"
PROFILE_DIR="$PROFILES_DIR/$TEST_PROFILE"

# Cleanup function
cleanup() {
  echo ""
  echo "Cleaning up test environment..."

  # Remove test profile
  if [[ -d "$PROFILE_DIR" ]]; then
    rm -rf "$PROFILE_DIR"
  fi

  # Unset environment variables
  unset WORKWARRIOR_BASE

  echo "Cleanup complete"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  ((TESTS_RUN++))

  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "FAIL: $message"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_success() {
  local exit_code="$1"
  local message="$2"

  ((TESTS_RUN++))

  if [[ "$exit_code" -eq 0 ]]; then
    echo "PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "FAIL: $message (exit code: $exit_code)"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_failure() {
  local exit_code="$1"
  local message="$2"

  ((TESTS_RUN++))

  if [[ "$exit_code" -ne 0 ]]; then
    echo "PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "FAIL: $message (expected failure but succeeded)"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_file_exists() {
  local file="$1"
  local message="$2"

  ((TESTS_RUN++))

  if [[ -f "$file" ]]; then
    echo "PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "FAIL: $message (file not found: $file)"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  ((TESTS_RUN++))

  if echo "$haystack" | grep -q "$needle"; then
    echo "PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "FAIL: $message"
    echo "  Expected to find: '$needle'"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_function_exists() {
  local func_name="$1"
  local message="$2"

  ((TESTS_RUN++))

  # Use type instead of declare -F to avoid set -e issues
  if type "$func_name" &> /dev/null; then
    echo "PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "FAIL: $message (function not found: $func_name)"
    ((TESTS_FAILED++))
    return 0  # Return 0 to avoid exiting with set -e
  fi
}

# ============================================================================
# TEST SUITE
# ============================================================================

echo "========================================="
echo "Questions Service Test Suite (Task 15)"
echo "========================================="
echo ""

# Setup test environment
echo "Setting up test environment..."

# Create test profile directory structure
# Note: Don't pre-create services/questions - let q() create it to test directory creation
mkdir -p "$PROFILE_DIR"/{.task/hooks,.timewarrior,journals,ledgers,services}
export WORKWARRIOR_BASE="$PROFILE_DIR"

echo "Test profile: $TEST_PROFILE"
echo "Profile dir: $PROFILE_DIR"
echo ""

# ============================================================================
# Test 1: Core functions exist
# ============================================================================

echo "--- Test 1: Core functions exist ---"
assert_function_exists "q" "q function exists"
assert_function_exists "_q_create_template" "_q_create_template function exists"
assert_function_exists "_q_list_all_templates" "_q_list_all_templates function exists"
assert_function_exists "_q_list_service_templates" "_q_list_service_templates function exists"
assert_function_exists "_q_use_template" "_q_use_template function exists"
assert_function_exists "_q_prompt_questions" "_q_prompt_questions function exists"
assert_function_exists "_q_process_answers" "_q_process_answers function exists"
assert_function_exists "_q_edit_template" "_q_edit_template function exists"
assert_function_exists "_q_delete_template" "_q_delete_template function exists"
assert_function_exists "_q_find_template" "_q_find_template function exists"
echo ""

# ============================================================================
# Test 2: q with no arguments shows help
# ============================================================================

echo "--- Test 2: q shows help menu ---"
output=$(q 2>&1)
exit_code=$?
assert_success "$exit_code" "q returns success"
assert_contains "$output" "Questions Manager Service" "Help shows title"
assert_contains "$output" "task" "Help mentions task service"
assert_contains "$output" "journal" "Help mentions journal service"
assert_contains "$output" "Usage" "Help shows usage section"
echo ""

# ============================================================================
# Test 3: q creates directory structure
# ============================================================================

echo "--- Test 3: Directory structure creation ---"
# q should create directories when called
q > /dev/null 2>&1

((TESTS_RUN++))
if [ -d "$PROFILE_DIR/services/questions/templates/task" ]; then
  echo "PASS: Task templates dir exists"
  ((TESTS_PASSED++))
else
  echo "FAIL: Task templates dir not created"
  ((TESTS_FAILED++))
fi

((TESTS_RUN++))
if [ -d "$PROFILE_DIR/services/questions/templates/journal" ]; then
  echo "PASS: Journal templates dir exists"
  ((TESTS_PASSED++))
else
  echo "FAIL: Journal templates dir not created"
  ((TESTS_FAILED++))
fi

((TESTS_RUN++))
if [ -d "$PROFILE_DIR/services/questions/handlers" ]; then
  echo "PASS: Handlers dir exists"
  ((TESTS_PASSED++))
else
  echo "FAIL: Handlers dir not created"
  ((TESTS_FAILED++))
fi
echo ""

# ============================================================================
# Test 4: q without active profile fails
# ============================================================================

echo "--- Test 4: q fails without active profile ---"
saved_base="$WORKWARRIOR_BASE"
unset WORKWARRIOR_BASE
output=$(q 2>&1)
exit_code=$?
assert_failure "$exit_code" "q fails without active profile"
assert_contains "$output" "Error" "Error message shown"
export WORKWARRIOR_BASE="$saved_base"
echo ""

# ============================================================================
# Test 5: Template file creation (manual)
# ============================================================================

echo "--- Test 5: Template file creation ---"
template_dir="$PROFILE_DIR/services/questions/templates/journal"
mkdir -p "$template_dir"

# Create a test template manually
cat > "$template_dir/test-template.json" << 'EOF'
{
  "name": "Test Template",
  "description": "A test template for unit testing",
  "service": "journal",
  "questions": [
    {
      "id": "q1",
      "text": "What is the test question?",
      "type": "text",
      "required": true
    },
    {
      "id": "q2",
      "text": "Any additional notes?",
      "type": "text",
      "required": false
    }
  ],
  "output_format": {
    "title": "Test - {date}",
    "description": "Generated from test template",
    "tags": ["test", "journal"]
  }
}
EOF

assert_file_exists "$template_dir/test-template.json" "Template file created"
echo ""

# ============================================================================
# Test 6: q list shows templates
# ============================================================================

echo "--- Test 6: q list shows templates ---"
output=$(q list 2>&1)
exit_code=$?
assert_success "$exit_code" "q list succeeds"
assert_contains "$output" "test-template" "Template appears in list"
echo ""

# ============================================================================
# Test 7: q <service> lists service templates
# ============================================================================

echo "--- Test 7: q journal lists templates ---"
output=$(q journal 2>&1)
exit_code=$?
assert_success "$exit_code" "q journal succeeds"
assert_contains "$output" "test-template" "Template appears in service list"
echo ""

# ============================================================================
# Test 8: _q_find_template locates template
# ============================================================================

echo "--- Test 8: _q_find_template works ---"
result=$(_q_find_template "test-template")
exit_code=$?
assert_success "$exit_code" "_q_find_template succeeds"
assert_contains "$result" "test-template.json" "Returns correct path"
echo ""

# ============================================================================
# Test 9: Invalid service rejected
# ============================================================================

echo "--- Test 9: Invalid service rejected ---"
output=$(q invalid-service 2>&1)
exit_code=$?
assert_failure "$exit_code" "Invalid service rejected"
assert_contains "$output" "Unknown command" "Error message shown"
echo ""

# ============================================================================
# Test 10: Handler files exist
# ============================================================================

echo "--- Test 10: Handler files exist ---"
handlers_dir="$SCRIPT_DIR/../services/questions/handlers"
assert_file_exists "$handlers_dir/journal_handler.sh" "Journal handler exists"
assert_file_exists "$handlers_dir/task_handler.sh" "Task handler exists"
assert_file_exists "$handlers_dir/time_handler.sh" "Time handler exists"
assert_file_exists "$handlers_dir/list_handler.sh" "List handler exists"
assert_file_exists "$handlers_dir/ledger_handler.sh" "Ledger handler exists"
echo ""

# ============================================================================
# Test 11: Handler files are executable
# ============================================================================

echo "--- Test 11: Handler files are executable ---"
[ -x "$handlers_dir/journal_handler.sh" ] && echo "PASS: Journal handler executable" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
  (echo "FAIL: Journal handler not executable" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
[ -x "$handlers_dir/task_handler.sh" ] && echo "PASS: Task handler executable" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
  (echo "FAIL: Task handler not executable" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
[ -x "$handlers_dir/time_handler.sh" ] && echo "PASS: Time handler executable" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
  (echo "FAIL: Time handler not executable" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
[ -x "$handlers_dir/list_handler.sh" ] && echo "PASS: List handler executable" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
  (echo "FAIL: List handler not executable" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
[ -x "$handlers_dir/ledger_handler.sh" ] && echo "PASS: Ledger handler executable" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
  (echo "FAIL: Ledger handler not executable" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
echo ""

# ============================================================================
# Test 12: Handler syntax check
# ============================================================================

echo "--- Test 12: Handler syntax check ---"
bash -n "$handlers_dir/journal_handler.sh" && echo "PASS: Journal handler syntax OK" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
  (echo "FAIL: Journal handler syntax error" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
bash -n "$handlers_dir/task_handler.sh" && echo "PASS: Task handler syntax OK" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
  (echo "FAIL: Task handler syntax error" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
bash -n "$handlers_dir/time_handler.sh" && echo "PASS: Time handler syntax OK" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
  (echo "FAIL: Time handler syntax error" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
bash -n "$handlers_dir/list_handler.sh" && echo "PASS: List handler syntax OK" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
  (echo "FAIL: List handler syntax error" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
bash -n "$handlers_dir/ledger_handler.sh" && echo "PASS: Ledger handler syntax OK" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
  (echo "FAIL: Ledger handler syntax error" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
echo ""

# ============================================================================
# Test 13: Template JSON is valid
# ============================================================================

echo "--- Test 13: Template JSON validation ---"
if command -v python3 &> /dev/null; then
  python3 -c "import json; json.load(open('$template_dir/test-template.json'))" && \
    echo "PASS: Template JSON is valid" && ((TESTS_PASSED++)) && ((TESTS_RUN++)) || \
    (echo "FAIL: Template JSON is invalid" && ((TESTS_FAILED++)) && ((TESTS_RUN++)))
else
  echo "SKIP: python3 not available for JSON validation"
fi
echo ""

# ============================================================================
# Test 14: q edit with non-existent template shows error
# ============================================================================

echo "--- Test 14: q edit non-existent template ---"
output=$(q edit non-existent-template 2>&1)
exit_code=$?
assert_failure "$exit_code" "Edit non-existent fails"
assert_contains "$output" "not found" "Error message shown"
echo ""

# ============================================================================
# Test 15: q delete with non-existent template shows error
# ============================================================================

echo "--- Test 15: q delete non-existent template ---"
output=$(q delete non-existent-template 2>&1)
exit_code=$?
assert_failure "$exit_code" "Delete non-existent fails"
assert_contains "$output" "not found" "Error message shown"
echo ""

# ============================================================================
# Test 16: Create template for each service type
# ============================================================================

echo "--- Test 16: Templates for each service type ---"
for service in task time list ledger custom; do
  mkdir -p "$PROFILE_DIR/services/questions/templates/$service"
  cat > "$PROFILE_DIR/services/questions/templates/$service/test-$service.json" << EOF
{
  "name": "Test $service",
  "description": "Test template for $service",
  "service": "$service",
  "questions": [{"id": "q1", "text": "Test?", "type": "text", "required": true}],
  "output_format": {"title": "Test", "tags": ["$service"]}
}
EOF
done

# Verify all were created
for service in task journal time list ledger custom; do
  output=$(q $service 2>&1)
  if echo "$output" | grep -q "test-"; then
    echo "PASS: $service template listed"
    ((TESTS_PASSED++))
  else
    echo "FAIL: $service template not listed"
    ((TESTS_FAILED++))
  fi
  ((TESTS_RUN++))
done
echo ""

# ============================================================================
# TEST SUMMARY
# ============================================================================

echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo "All tests passed!"
  exit 0
else
  echo "Some tests failed"
  exit 1
fi
