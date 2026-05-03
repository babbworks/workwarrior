#!/usr/bin/env bats
# Unit Tests for TaskRC Configuration Creation
# Feature: workwarrior-profiles-and-services
# Task 3.1: Implement create_taskrc function
# Validates: Requirements 6.1, 6.2, 6.3, 6.9, 6.10

# Load the libraries
setup() {
  # Set up test environment BEFORE sourcing libraries (PROFILES_DIR is readonly)
  export TEST_MODE=1
  export TEST_PROFILES_DIR="${BATS_TEST_DIRNAME}/../test-profiles"
  export PROFILES_DIR="$TEST_PROFILES_DIR"
  export WW_BASE="${BATS_TEST_DIRNAME}/.."
  
  # Source the libraries
  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
  source "${BATS_TEST_DIRNAME}/../lib/profile-manager.sh"
  
  # Create test profiles directory
  mkdir -p "$TEST_PROFILES_DIR"
}

teardown() {
  # Clean up test profiles
  if [[ -d "$TEST_PROFILES_DIR" ]]; then
    rm -rf "$TEST_PROFILES_DIR"
  fi
}

# ============================================================================
# Basic Functionality Tests
# ============================================================================

@test "create_taskrc: Creates .taskrc file in profile directory" {
  local profile_name="test-taskrc-basic"
  
  # Create profile directory structure first
  create_profile_directories "$profile_name"
  
  # Create .taskrc
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify .taskrc exists
  [ -f "$PROFILES_DIR/$profile_name/.taskrc" ]
}

@test "create_taskrc: Sets data.location to absolute path" {
  local profile_name="test-taskrc-data"
  
  # Create profile directory structure
  create_profile_directories "$profile_name"
  
  # Create .taskrc
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify data.location is set to absolute path
  local expected_path="$PROFILES_DIR/$profile_name/.task"
  grep -q "^data\.location=$expected_path$" "$PROFILES_DIR/$profile_name/.taskrc"
}

@test "create_taskrc: Sets hooks.location to absolute path" {
  local profile_name="test-taskrc-hooks"
  
  # Create profile directory structure
  create_profile_directories "$profile_name"
  
  # Create .taskrc
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify hooks.location is set to absolute path
  local expected_path="$PROFILES_DIR/$profile_name/.task/hooks"
  grep -q "^hooks\.location=$expected_path$" "$PROFILES_DIR/$profile_name/.taskrc"
}

@test "create_taskrc: Enables hooks (hooks=on)" {
  local profile_name="test-taskrc-hooks-enabled"
  
  # Create profile directory structure
  create_profile_directories "$profile_name"
  
  # Create .taskrc
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify hooks are enabled
  grep -q "^hooks=on$" "$PROFILES_DIR/$profile_name/.taskrc"
}

@test "create_taskrc: Fails for invalid profile name" {
  local profile_name="invalid name with spaces"
  
  # Try to create .taskrc with invalid name
  run create_taskrc "$profile_name"
  [ "$status" -eq 1 ]
}

@test "create_taskrc: Fails if profile directory doesn't exist" {
  local profile_name="nonexistent-profile"
  
  # Try to create .taskrc without creating profile directory first
  run create_taskrc "$profile_name"
  [ "$status" -eq 1 ]
}

# ============================================================================
# Template Loading Tests
# ============================================================================

@test "create_taskrc: Uses template from DEFAULT_TASKRC if available" {
  local profile_name="test-taskrc-template"
  
  # Create profile directory structure
  create_profile_directories "$profile_name"
  
  # Create .taskrc
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # If DEFAULT_TASKRC exists, verify some content was copied
  if [[ -f "$DEFAULT_TASKRC" ]]; then
    # Check for UDAs or other template content
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    [ -f "$taskrc" ]
    # File should have more than just the minimal config
    local line_count=$(wc -l < "$taskrc")
    [ "$line_count" -gt 10 ]
  fi
}

@test "create_taskrc: Creates minimal default if no template exists" {
  local profile_name="test-taskrc-minimal"
  
  # Create profile directory structure
  create_profile_directories "$profile_name"
  
  # Temporarily hide template by renaming DEFAULT_TASKRC
  local template_backup=""
  if [[ -f "$DEFAULT_TASKRC" ]]; then
    template_backup="$DEFAULT_TASKRC.backup"
    mv "$DEFAULT_TASKRC" "$template_backup"
  fi
  
  # Create .taskrc
  run create_taskrc "$profile_name"
  local status_code="$status"
  
  # Restore template if it was backed up
  if [[ -n "$template_backup" && -f "$template_backup" ]]; then
    mv "$template_backup" "$DEFAULT_TASKRC"
  fi
  
  [ "$status_code" -eq 0 ]
  
  # Verify minimal .taskrc was created
  [ -f "$PROFILES_DIR/$profile_name/.taskrc" ]
}

# ============================================================================
# Path Validation Tests
# ============================================================================

@test "create_taskrc: All paths are absolute (no relative paths)" {
  local profile_name="test-taskrc-absolute"
  
  # Create profile directory structure
  create_profile_directories "$profile_name"
  
  # Create .taskrc
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  
  # Extract data.location value
  local data_location=$(grep "^data\.location=" "$taskrc" | cut -d= -f2)
  # Should start with / (absolute path)
  [[ "$data_location" == /* ]]
  
  # Extract hooks.location value
  local hooks_location=$(grep "^hooks\.location=" "$taskrc" | cut -d= -f2)
  # Should start with / (absolute path)
  [[ "$hooks_location" == /* ]]
}

@test "create_taskrc: Paths do not contain HOME variable" {
  local profile_name="test-taskrc-no-home-var"
  
  # Create profile directory structure
  create_profile_directories "$profile_name"
  
  # Create .taskrc
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  
  # Verify no $HOME or ~ in paths
  ! grep "^data\.location=.*\$HOME" "$taskrc"
  ! grep "^data\.location=.*~" "$taskrc"
  ! grep "^hooks\.location=.*\$HOME" "$taskrc"
  ! grep "^hooks\.location=.*~" "$taskrc"
}

# ============================================================================
# Configuration Validation Tests
# ============================================================================

@test "create_taskrc: Required settings are present" {
  local profile_name="test-taskrc-required"
  
  # Create profile directory structure
  create_profile_directories "$profile_name"
  
  # Create .taskrc
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  
  # Verify all required settings exist
  grep -q "^data\.location=" "$taskrc"
  grep -q "^hooks\.location=" "$taskrc"
  grep -q "^hooks=" "$taskrc"
}

@test "create_taskrc: TimeWarrior UDA is present" {
  local profile_name="test-taskrc-uda"
  
  # Create profile directory structure
  create_profile_directories "$profile_name"
  
  # Create .taskrc
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  
  # Verify TimeWarrior UDA exists (either from template or minimal default)
  grep -q "uda\.timetracked" "$taskrc"
}

# ============================================================================
# Multiple Profiles Tests
# ============================================================================

@test "create_taskrc: Multiple profiles have independent configurations" {
  local profile1="test-taskrc-multi-1"
  local profile2="test-taskrc-multi-2"
  local profile3="test-taskrc-multi-3"
  
  # Create multiple profiles
  create_profile_directories "$profile1"
  create_profile_directories "$profile2"
  create_profile_directories "$profile3"
  
  # Create .taskrc for each
  create_taskrc "$profile1"
  create_taskrc "$profile2"
  create_taskrc "$profile3"
  
  # Verify each has correct paths
  local taskrc1="$PROFILES_DIR/$profile1/.taskrc"
  local taskrc2="$PROFILES_DIR/$profile2/.taskrc"
  local taskrc3="$PROFILES_DIR/$profile3/.taskrc"
  
  # Profile 1 paths
  grep -q "^data\.location=$PROFILES_DIR/$profile1/.task$" "$taskrc1"
  grep -q "^hooks\.location=$PROFILES_DIR/$profile1/.task/hooks$" "$taskrc1"
  
  # Profile 2 paths
  grep -q "^data\.location=$PROFILES_DIR/$profile2/.task$" "$taskrc2"
  grep -q "^hooks\.location=$PROFILES_DIR/$profile2/.task/hooks$" "$taskrc2"
  
  # Profile 3 paths
  grep -q "^data\.location=$PROFILES_DIR/$profile3/.task$" "$taskrc3"
  grep -q "^hooks\.location=$PROFILES_DIR/$profile3/.task/hooks$" "$taskrc3"
}

# ============================================================================
# Edge Cases
# ============================================================================

@test "create_taskrc: Works with profile names containing hyphens" {
  local profile_name="test-profile-with-hyphens"
  
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify paths are correct
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  grep -q "^data\.location=$PROFILES_DIR/$profile_name/.task$" "$taskrc"
}

@test "create_taskrc: Works with profile names containing underscores" {
  local profile_name="test_profile_with_underscores"
  
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify paths are correct
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  grep -q "^data\.location=$PROFILES_DIR/$profile_name/.task$" "$taskrc"
}

@test "create_taskrc: Works with numeric profile names" {
  local profile_name="12345"
  
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify paths are correct
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  grep -q "^data\.location=$PROFILES_DIR/$profile_name/.task$" "$taskrc"
}

@test "create_taskrc: Idempotent - can be called multiple times" {
  local profile_name="test-taskrc-idempotent"
  
  create_profile_directories "$profile_name"
  
  # Create .taskrc first time
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # Create .taskrc second time (should overwrite)
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify .taskrc still exists and is valid
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  [ -f "$taskrc" ]
  grep -q "^data\.location=" "$taskrc"
  grep -q "^hooks\.location=" "$taskrc"
  grep -q "^hooks=" "$taskrc"
}
