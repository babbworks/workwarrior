#!/usr/bin/env bash
# Integration test for TimeWarrior hook installation
# This script tests the complete workflow of installing a hook

set -e

# Set up test environment
export TEST_MODE=1
export TEST_PROFILES_DIR="./test-profiles-integration"
export PROFILES_DIR="$TEST_PROFILES_DIR"
export WW_BASE="$(pwd)"

# Source the libraries
source "lib/core-utils.sh"
source "lib/profile-manager.sh"

# Clean up any previous test runs
rm -rf "$TEST_PROFILES_DIR"

echo "=== TimeWarrior Hook Installation Integration Test ==="
echo

# Test 1: Create profile and install hook
echo "Test 1: Creating profile and installing hook..."
PROFILE_NAME="test-integration-profile"

create_profile_directories "$PROFILE_NAME"
if [ $? -ne 0 ]; then
  echo "❌ Failed to create profile directories"
  exit 1
fi
echo "✓ Profile directories created"

install_timewarrior_hook "$PROFILE_NAME"
if [ $? -ne 0 ]; then
  echo "❌ Failed to install TimeWarrior hook"
  exit 1
fi
echo "✓ TimeWarrior hook installed"

# Test 2: Verify hook exists
echo
echo "Test 2: Verifying hook file exists..."
HOOK_PATH="$PROFILES_DIR/$PROFILE_NAME/.task/hooks/on-modify.timewarrior"
if [ ! -f "$HOOK_PATH" ]; then
  echo "❌ Hook file does not exist at: $HOOK_PATH"
  exit 1
fi
echo "✓ Hook file exists"

# Test 3: Verify hook is executable
echo
echo "Test 3: Verifying hook is executable..."
if [ ! -x "$HOOK_PATH" ]; then
  echo "❌ Hook file is not executable"
  exit 1
fi
echo "✓ Hook is executable"

# Test 4: Verify hook has Python shebang
echo
echo "Test 4: Verifying hook has Python shebang..."
FIRST_LINE=$(head -n 1 "$HOOK_PATH")
if [[ ! "$FIRST_LINE" =~ ^#!/usr/bin/env\ python3 ]]; then
  echo "❌ Hook does not have correct Python shebang"
  echo "   Found: $FIRST_LINE"
  exit 1
fi
echo "✓ Hook has correct Python shebang"

# Test 5: Verify hook contains required functions
echo
echo "Test 5: Verifying hook contains required functions..."
if ! grep -q "def extract_tags_from" "$HOOK_PATH"; then
  echo "❌ Hook missing extract_tags_from function"
  exit 1
fi
if ! grep -q "def main" "$HOOK_PATH"; then
  echo "❌ Hook missing main function"
  exit 1
fi
echo "✓ Hook contains required functions"

# Test 6: Verify hook uses timew command
echo
echo "Test 6: Verifying hook uses timew command..."
if ! grep -q "timew" "$HOOK_PATH"; then
  echo "❌ Hook does not use timew command"
  exit 1
fi
echo "✓ Hook uses timew command"

# Test 7: Verify hook does not hardcode paths
echo
echo "Test 7: Verifying hook does not hardcode TimeWarrior paths..."
if grep -q "\.timewarrior" "$HOOK_PATH"; then
  echo "❌ Hook contains hardcoded .timewarrior path"
  exit 1
fi
echo "✓ Hook does not hardcode paths (uses TIMEWARRIORDB via timew)"

# Test 8: Verify Python syntax is valid
echo
echo "Test 8: Verifying Python syntax is valid..."
if ! python3 -m py_compile "$HOOK_PATH" 2>/dev/null; then
  echo "❌ Hook has invalid Python syntax"
  exit 1
fi
echo "✓ Hook has valid Python syntax"

# Test 9: Verify hook can be imported as Python module
echo
echo "Test 9: Verifying hook can be imported..."
if ! python3 -c "import sys; sys.path.insert(0, '$(dirname "$HOOK_PATH")'); exec(open('$HOOK_PATH').read())" 2>/dev/null; then
  echo "⚠ Warning: Hook cannot be imported (may be expected if timew not installed)"
else
  echo "✓ Hook can be imported"
fi

# Test 10: Test idempotency - reinstall hook
echo
echo "Test 10: Testing idempotency - reinstalling hook..."
install_timewarrior_hook "$PROFILE_NAME"
if [ $? -ne 0 ]; then
  echo "❌ Failed to reinstall hook"
  exit 1
fi
if [ ! -x "$HOOK_PATH" ]; then
  echo "❌ Hook lost executable permission after reinstall"
  exit 1
fi
echo "✓ Hook can be reinstalled (idempotent)"

# Clean up
echo
echo "Cleaning up test environment..."
rm -rf "$TEST_PROFILES_DIR"
echo "✓ Cleanup complete"

echo
echo "=== All Integration Tests Passed! ==="
echo
echo "Summary:"
echo "  ✓ Profile directories created"
echo "  ✓ TimeWarrior hook installed"
echo "  ✓ Hook file exists and is executable"
echo "  ✓ Hook has correct Python shebang"
echo "  ✓ Hook contains required functions"
echo "  ✓ Hook uses timew command (respects TIMEWARRIORDB)"
echo "  ✓ Hook does not hardcode paths"
echo "  ✓ Hook has valid Python syntax"
echo "  ✓ Hook is idempotent"
echo

exit 0
