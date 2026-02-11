#!/usr/bin/env bash
# Manual test for service discovery functions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core-utils.sh"

echo "=== Service Discovery Manual Test ==="
echo ""

# Test 1: Create test directories
echo "Test 1: Creating test directories..."
TEST_CATEGORY="test-cat"
mkdir -p "$SERVICES_DIR/$TEST_CATEGORY"
echo "Created: $SERVICES_DIR/$TEST_CATEGORY"

# Test 2: Create a test service
echo ""
echo "Test 2: Creating test service..."
TEST_SERVICE="$SERVICES_DIR/$TEST_CATEGORY/test-service.sh"
echo '#!/bin/bash' > "$TEST_SERVICE"
echo 'echo "Test service"' >> "$TEST_SERVICE"
chmod +x "$TEST_SERVICE"
echo "Created: $TEST_SERVICE"

# Test 3: Discover services
echo ""
echo "Test 3: Discovering services..."
echo "Running: discover_services \"$TEST_CATEGORY\""
discover_services "$TEST_CATEGORY"

# Test 4: Get service path
echo ""
echo "Test 4: Getting service path..."
echo "Running: get_service_path \"$TEST_CATEGORY\" \"test-service.sh\""
SERVICE_PATH=$(get_service_path "$TEST_CATEGORY" "test-service.sh")
echo "Result: $SERVICE_PATH"

# Test 5: Check service exists
echo ""
echo "Test 5: Checking if service exists..."
if service_exists "$TEST_CATEGORY" "test-service.sh"; then
  echo "✓ Service exists"
else
  echo "✗ Service does not exist"
fi

# Test 6: Check non-existent service
echo ""
echo "Test 6: Checking non-existent service..."
if service_exists "$TEST_CATEGORY" "non-existent.sh"; then
  echo "✗ Should not exist"
else
  echo "✓ Correctly reports non-existent"
fi

# Cleanup
echo ""
echo "Cleaning up..."
rm -rf "$SERVICES_DIR/$TEST_CATEGORY"
echo "✓ Cleanup complete"

echo ""
echo "=== All manual tests completed ==="
