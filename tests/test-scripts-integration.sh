#!/usr/bin/env bash
# Integration test for profile creation and management scripts
# Tests the main user-facing scripts work correctly together

set -e

# Setup test environment
export TEST_MODE=1
export TEST_PROFILES_DIR="./test-profiles-scripts"
export WW_BASE="./test-ww-scripts"
export PROFILES_DIR="$TEST_PROFILES_DIR"
export SERVICES_DIR="$WW_BASE/services"
export RESOURCES_DIR="$WW_BASE/resources"
export FUNCTIONS_DIR="$WW_BASE/functions"
export SHELL_RC="./test-bashrc-scripts"

# Clean up any previous test runs
rm -rf "$TEST_PROFILES_DIR" "$WW_BASE" "$SHELL_RC"

# Create base directories
mkdir -p "$TEST_PROFILES_DIR"
mkdir -p "$SERVICES_DIR/profile"
mkdir -p "$RESOURCES_DIR/config-files"
mkdir -p "$FUNCTIONS_DIR/tasks/default-taskrc"
mkdir -p "$FUNCTIONS_DIR/ledgers/defaultaccounts"
touch "$SHELL_RC"

# Create a simple on-modify.timewarrior hook template
cat > "$SERVICES_DIR/profile/on-modify.timewarrior" << 'EOF'
#!/usr/bin/env python3
import json
import sys
old = json.loads(sys.stdin.readline())
new = json.loads(sys.stdin.readline())
print(json.dumps(new))
EOF

echo "═══════════════════════════════════════════════════════════════"
echo "Integration Test: Profile Creation and Management Scripts"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Test 1: Create a profile using create-ww-profile.sh
echo "Test 1: Creating profile with create-ww-profile.sh..."
if ./scripts/create-ww-profile.sh test-profile --non-interactive > /dev/null 2>&1; then
  echo "✓ Profile created successfully"
else
  echo "✗ Failed to create profile"
  exit 1
fi

# Verify profile directory exists
if [[ -d "$TEST_PROFILES_DIR/test-profile" ]]; then
  echo "✓ Profile directory exists"
else
  echo "✗ Profile directory not found"
  exit 1
fi

# Verify configuration files exist
if [[ -f "$TEST_PROFILES_DIR/test-profile/.taskrc" ]]; then
  echo "✓ .taskrc exists"
else
  echo "✗ .taskrc not found"
  exit 1
fi

if [[ -f "$TEST_PROFILES_DIR/test-profile/jrnl.yaml" ]]; then
  echo "✓ jrnl.yaml exists"
else
  echo "✗ jrnl.yaml not found"
  exit 1
fi

if [[ -f "$TEST_PROFILES_DIR/test-profile/ledgers.yaml" ]]; then
  echo "✓ ledgers.yaml exists"
else
  echo "✗ ledgers.yaml not found"
  exit 1
fi

# Verify hook is installed
if [[ -f "$TEST_PROFILES_DIR/test-profile/.task/hooks/on-modify.timewarrior" ]]; then
  echo "✓ TimeWarrior hook installed"
else
  echo "✗ TimeWarrior hook not found"
  exit 1
fi

# Verify hook is executable
if [[ -x "$TEST_PROFILES_DIR/test-profile/.task/hooks/on-modify.timewarrior" ]]; then
  echo "✓ Hook is executable"
else
  echo "✗ Hook is not executable"
  exit 1
fi

echo ""

# Test 2: List profiles using manage-profiles.sh
echo "Test 2: Listing profiles with manage-profiles.sh..."
if ./scripts/manage-profiles.sh list > /dev/null 2>&1; then
  echo "✓ List command executed successfully"
else
  echo "✗ List command failed"
  exit 1
fi

# Verify profile appears in list
if ./scripts/manage-profiles.sh list 2>&1 | grep -q "test-profile"; then
  echo "✓ Profile appears in list"
else
  echo "✗ Profile not found in list"
  exit 1
fi

echo ""

# Test 3: Get profile info using manage-profiles.sh
echo "Test 3: Getting profile info with manage-profiles.sh..."
if ./scripts/manage-profiles.sh info test-profile > /dev/null 2>&1; then
  echo "✓ Info command executed successfully"
else
  echo "✗ Info command failed"
  exit 1
fi

# Verify info contains profile name
if ./scripts/manage-profiles.sh info test-profile 2>&1 | grep -q "test-profile"; then
  echo "✓ Info contains profile name"
else
  echo "✗ Info missing profile name"
  exit 1
fi

echo ""

# Test 4: Backup profile using manage-profiles.sh
echo "Test 4: Backing up profile with manage-profiles.sh..."
if ./scripts/manage-profiles.sh backup test-profile "$BATS_TEST_TMPDIR" > /dev/null 2>&1; then
  echo "✓ Backup command executed successfully"
else
  echo "✗ Backup command failed"
  exit 1
fi

# Verify backup file was created
backup_file=$(find . -name "test-profile-backup-*.tar.gz" -type f 2>/dev/null | head -1)
if [[ -n "$backup_file" ]]; then
  echo "✓ Backup file created: $(basename "$backup_file")"
  
  # Verify backup contains profile data
  if tar -tzf "$backup_file" 2>/dev/null | grep -q "test-profile/.taskrc"; then
    echo "✓ Backup contains profile data"
  else
    echo "✗ Backup missing profile data"
    exit 1
  fi
  
  # Clean up backup file
  rm -f "$backup_file"
else
  echo "✗ Backup file not found"
  exit 1
fi

echo ""

# Test 5: Create second profile to test sorting
echo "Test 5: Creating second profile for sorting test..."
if ./scripts/create-ww-profile.sh another-profile --non-interactive > /dev/null 2>&1; then
  echo "✓ Second profile created"
else
  echo "✗ Failed to create second profile"
  exit 1
fi

# Verify profiles are listed in sorted order
profile_list=$(./scripts/manage-profiles.sh list 2>&1 | grep "^  •" | sed 's/^  • //')
first_profile=$(echo "$profile_list" | head -1)
second_profile=$(echo "$profile_list" | tail -1)

if [[ "$first_profile" == "another-profile" ]] && [[ "$second_profile" == "test-profile" ]]; then
  echo "✓ Profiles listed in sorted order"
else
  echo "✗ Profiles not sorted correctly"
  echo "  Expected: another-profile, test-profile"
  echo "  Got: $first_profile, $second_profile"
  exit 1
fi

echo ""

# Test 6: Delete profile using manage-profiles.sh
echo "Test 6: Deleting profile with manage-profiles.sh..."
# Note: This would require interactive confirmation, so we'll just verify the function exists
if ./scripts/manage-profiles.sh help 2>&1 | grep -q "delete"; then
  echo "✓ Delete command is available"
else
  echo "✗ Delete command not found in help"
  exit 1
fi

echo ""

# Test 7: Verify help command
echo "Test 7: Verifying help command..."
if ./scripts/create-ww-profile.sh --help > /dev/null 2>&1; then
  echo "✓ create-ww-profile.sh help works"
else
  echo "✗ create-ww-profile.sh help failed"
  exit 1
fi

if ./scripts/manage-profiles.sh help > /dev/null 2>&1; then
  echo "✓ manage-profiles.sh help works"
else
  echo "✗ manage-profiles.sh help failed"
  exit 1
fi

echo ""

# Clean up test environment
echo "Cleaning up test environment..."
rm -rf "$TEST_PROFILES_DIR"
rm -rf "$WW_BASE"
rm -f "$SHELL_RC"
rm -f test-profile-backup-*.tar.gz
echo "✓ Cleanup complete"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "All Integration Tests Passed!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  ✓ Profile creation script works"
echo "  ✓ Profile management script works"
echo "  ✓ List command works and sorts profiles"
echo "  ✓ Info command works"
echo "  ✓ Backup command works and creates valid archives"
echo "  ✓ Help commands work"
echo "  ✓ All configuration files are created correctly"
echo "  ✓ TimeWarrior hook is installed and executable"
echo ""

exit 0
