#!/usr/bin/env bash
# Test script for service discovery functions
# Tests: discover_services, get_service_path, service_exists
# Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5, 14.1, 14.2, 14.3, 14.4, 14.5

set -e

# Source the core utilities library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core-utils.sh"

# Test configuration
TEST_PROFILE="test-service-discovery-$$"
TEST_CATEGORY="test-category"
TEST_SERVICE="test-service.sh"
GLOBAL_SERVICE_DIR="$SERVICES_DIR/$TEST_CATEGORY"
PROFILE_SERVICE_DIR="$PROFILES_DIR/$TEST_PROFILE/services/$TEST_CATEGORY"

# Cleanup function
cleanup() {
  echo "🧹 Cleaning up test environment..."
  
  # Remove test profile
  if [[ -d "$PROFILES_DIR/$TEST_PROFILE" ]]; then
    rm -rf "$PROFILES_DIR/$TEST_PROFILE"
  fi
  
  # Remove test global service directory
  if [[ -d "$GLOBAL_SERVICE_DIR" ]]; then
    rm -rf "$GLOBAL_SERVICE_DIR"
  fi
  
  # Unset environment variables
  unset WORKWARRIOR_BASE
  
  echo "✓ Cleanup complete"
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
    echo "✓ PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "✗ FAIL: $message"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_success() {
  local message="$1"
  
  ((TESTS_RUN++))
  
  if [[ $? -eq 0 ]]; then
    echo "✓ PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "✗ FAIL: $message (command failed)"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_failure() {
  local message="$1"
  
  ((TESTS_RUN++))
  
  if [[ $? -ne 0 ]]; then
    echo "✓ PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "✗ FAIL: $message (command succeeded when it should have failed)"
    ((TESTS_FAILED++))
    return 1
  fi
}

assert_file_exists() {
  local file="$1"
  local message="$2"
  
  ((TESTS_RUN++))
  
  if [[ -f "$file" ]]; then
    echo "✓ PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "✗ FAIL: $message (file not found: $file)"
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
    echo "✓ PASS: $message"
    ((TESTS_PASSED++))
    return 0
  else
    echo "✗ FAIL: $message"
    echo "  Expected to find: '$needle'"
    echo "  In: '$haystack'"
    ((TESTS_FAILED++))
    return 1
  fi
}

# ============================================================================
# TEST SUITE
# ============================================================================

echo "========================================="
echo "Service Discovery Functions Test Suite"
echo "========================================="
echo ""

# Setup test environment
echo "🔧 Setting up test environment..."

# Create test profile directory structure
mkdir -p "$PROFILES_DIR/$TEST_PROFILE/services/$TEST_CATEGORY"
mkdir -p "$GLOBAL_SERVICE_DIR"

echo "✓ Test environment ready"
echo ""

# ============================================================================
# Test 1: discover_services with no services
# ============================================================================

echo "Test 1: discover_services with empty category"
result=$(discover_services "$TEST_CATEGORY")
assert_equals "" "$result" "Should return empty list when no services exist"
echo ""

# ============================================================================
# Test 2: discover_services with global service only
# ============================================================================

echo "Test 2: discover_services with global service"

# Create a global service
cat > "$GLOBAL_SERVICE_DIR/$TEST_SERVICE" << 'EOF'
#!/usr/bin/env bash
echo "Global test service"
EOF
chmod +x "$GLOBAL_SERVICE_DIR/$TEST_SERVICE"

result=$(discover_services "$TEST_CATEGORY")
assert_contains "$result" "$TEST_SERVICE" "Should discover global service"
echo ""

# ============================================================================
# Test 3: get_service_path for global service
# ============================================================================

echo "Test 3: get_service_path for global service"
result=$(get_service_path "$TEST_CATEGORY" "$TEST_SERVICE")
expected="$GLOBAL_SERVICE_DIR/$TEST_SERVICE"
assert_equals "$expected" "$result" "Should return path to global service"
echo ""

# ============================================================================
# Test 4: service_exists for global service
# ============================================================================

echo "Test 4: service_exists for global service"
service_exists "$TEST_CATEGORY" "$TEST_SERVICE"
assert_success "Should return true for existing global service"
echo ""

# ============================================================================
# Test 5: Profile-specific service override
# ============================================================================

echo "Test 5: Profile-specific service overrides global service"

# Activate test profile
export WORKWARRIOR_BASE="$PROFILES_DIR/$TEST_PROFILE"

# Create a profile-specific service with different content
cat > "$PROFILE_SERVICE_DIR/$TEST_SERVICE" << 'EOF'
#!/usr/bin/env bash
echo "Profile-specific test service"
EOF
chmod +x "$PROFILE_SERVICE_DIR/$TEST_SERVICE"

# Get service path - should return profile-specific version
result=$(get_service_path "$TEST_CATEGORY" "$TEST_SERVICE")
expected="$PROFILE_SERVICE_DIR/$TEST_SERVICE"
assert_equals "$expected" "$result" "Should return profile-specific service path"
echo ""

# ============================================================================
# Test 6: discover_services with profile active
# ============================================================================

echo "Test 6: discover_services with profile active"
result=$(discover_services "$TEST_CATEGORY")
# Should still only list the service once (profile version takes precedence)
service_count=$(echo "$result" | wc -l | tr -d ' ')
assert_equals "1" "$service_count" "Should list service only once when profile overrides global"
echo ""

# ============================================================================
# Test 7: Profile-specific service only
# ============================================================================

echo "Test 7: Profile-specific service without global version"

PROFILE_ONLY_SERVICE="profile-only.sh"
cat > "$PROFILE_SERVICE_DIR/$PROFILE_ONLY_SERVICE" << 'EOF'
#!/usr/bin/env bash
echo "Profile-only service"
EOF
chmod +x "$PROFILE_SERVICE_DIR/$PROFILE_ONLY_SERVICE"

result=$(discover_services "$TEST_CATEGORY")
assert_contains "$result" "$PROFILE_ONLY_SERVICE" "Should discover profile-specific service"

# Verify it's found by get_service_path
result=$(get_service_path "$TEST_CATEGORY" "$PROFILE_ONLY_SERVICE")
expected="$PROFILE_SERVICE_DIR/$PROFILE_ONLY_SERVICE"
assert_equals "$expected" "$result" "Should return path to profile-specific service"
echo ""

# ============================================================================
# Test 8: Service discovery without active profile
# ============================================================================

echo "Test 8: Service discovery without active profile"

# Deactivate profile
unset WORKWARRIOR_BASE

# Should only find global services now
result=$(get_service_path "$TEST_CATEGORY" "$TEST_SERVICE")
expected="$GLOBAL_SERVICE_DIR/$TEST_SERVICE"
assert_equals "$expected" "$result" "Should return global service when no profile active"

# Profile-only service should not be found
get_service_path "$TEST_CATEGORY" "$PROFILE_ONLY_SERVICE" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
  ((TESTS_RUN++))
  ((TESTS_PASSED++))
  echo "✓ PASS: Profile-only service not found when profile inactive"
else
  ((TESTS_RUN++))
  ((TESTS_FAILED++))
  echo "✗ FAIL: Profile-only service should not be found when profile inactive"
fi
echo ""

# ============================================================================
# Test 9: service_exists with non-existent service
# ============================================================================

echo "Test 9: service_exists with non-existent service"
service_exists "$TEST_CATEGORY" "non-existent-service.sh"
if [[ $? -ne 0 ]]; then
  ((TESTS_RUN++))
  ((TESTS_PASSED++))
  echo "✓ PASS: Returns false for non-existent service"
else
  ((TESTS_RUN++))
  ((TESTS_FAILED++))
  echo "✗ FAIL: Should return false for non-existent service"
fi
echo ""

# ============================================================================
# Test 10: discover_services with multiple services
# ============================================================================

echo "Test 10: discover_services with multiple services"

# Create additional global services
cat > "$GLOBAL_SERVICE_DIR/service-a.sh" << 'EOF'
#!/usr/bin/env bash
echo "Service A"
EOF
chmod +x "$GLOBAL_SERVICE_DIR/service-a.sh"

cat > "$GLOBAL_SERVICE_DIR/service-b.sh" << 'EOF'
#!/usr/bin/env bash
echo "Service B"
EOF
chmod +x "$GLOBAL_SERVICE_DIR/service-b.sh"

result=$(discover_services "$TEST_CATEGORY")
assert_contains "$result" "service-a.sh" "Should discover service-a.sh"
assert_contains "$result" "service-b.sh" "Should discover service-b.sh"
assert_contains "$result" "$TEST_SERVICE" "Should discover test-service.sh"

# Verify services are sorted
first_service=$(echo "$result" | head -n 1)
assert_equals "service-a.sh" "$first_service" "Services should be sorted alphabetically"
echo ""

# ============================================================================
# Test 11: Error handling - missing category
# ============================================================================

echo "Test 11: Error handling - missing category"
discover_services "" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
  ((TESTS_RUN++))
  ((TESTS_PASSED++))
  echo "✓ PASS: Returns error when category is missing"
else
  ((TESTS_RUN++))
  ((TESTS_FAILED++))
  echo "✗ FAIL: Should return error when category is missing"
fi
echo ""

# ============================================================================
# Test 12: Error handling - missing service name
# ============================================================================

echo "Test 12: Error handling - missing service name"
get_service_path "$TEST_CATEGORY" "" > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
  ((TESTS_RUN++))
  ((TESTS_PASSED++))
  echo "✓ PASS: Returns error when service name is missing"
else
  ((TESTS_RUN++))
  ((TESTS_FAILED++))
  echo "✗ FAIL: Should return error when service name is missing"
fi
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
  echo "✓ All tests passed!"
  exit 0
else
  echo "✗ Some tests failed"
  exit 1
fi
