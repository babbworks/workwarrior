#!/usr/bin/env bats
# Property-Based Tests for TaskRC Path Configuration
# Feature: workwarrior-profiles-and-services
# Property 15: TaskRC Path Configuration
# Validates: Requirements 6.1, 6.2, 6.3, 6.10

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
# Property 15: TaskRC Path Configuration
# For any created profile, the .taskrc file should have data.location and
# hooks.location set to absolute paths pointing to the profile's .task and
# .task/hooks directories respectively, and hooks should be enabled (hooks=on).
# ============================================================================

# Helper function to generate random alphanumeric string
random_alphanumeric() {
  local length="$1"
  tr -dc 'a-zA-Z0-9_-' < /dev/urandom | head -c "$length"
}

@test "Property 15: data.location points to absolute .task directory" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profile_name="test-data-location"
  
  # Create profile and .taskrc
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  local expected_path="$PROFILES_DIR/$profile_name/.task"
  
  # Verify data.location is set to absolute path
  grep -q "^data\.location=$expected_path$" "$taskrc"
}

@test "Property 15: hooks.location points to absolute .task/hooks directory" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profile_name="test-hooks-location"
  
  # Create profile and .taskrc
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  local expected_path="$PROFILES_DIR/$profile_name/.task/hooks"
  
  # Verify hooks.location is set to absolute path
  grep -q "^hooks\.location=$expected_path$" "$taskrc"
}

@test "Property 15: hooks are enabled (hooks=on)" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profile_name="test-hooks-enabled"
  
  # Create profile and .taskrc
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  
  # Verify hooks are enabled
  grep -q "^hooks=on$" "$taskrc"
}

@test "Property 15: All three settings present in .taskrc" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profile_name="test-all-settings"
  
  # Create profile and .taskrc
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  
  # Verify all required settings exist
  grep -q "^data\.location=" "$taskrc"
  grep -q "^hooks\.location=" "$taskrc"
  grep -q "^hooks=" "$taskrc"
}

@test "Property 15: Paths are absolute (start with /)" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profile_name="test-absolute-paths"
  
  # Create profile and .taskrc
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  
  # Extract paths
  local data_location=$(grep "^data\.location=" "$taskrc" | cut -d= -f2)
  local hooks_location=$(grep "^hooks\.location=" "$taskrc" | cut -d= -f2)
  
  # Verify paths are absolute (start with /)
  [[ "$data_location" == /* ]]
  [[ "$hooks_location" == /* ]]
}

@test "Property 15: Paths do not contain variables or tilde" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profile_name="test-no-variables"
  
  # Create profile and .taskrc
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  
  # Verify no $HOME, $PROFILES_DIR, or ~ in paths
  ! grep "^data\.location=.*\$" "$taskrc"
  ! grep "^data\.location=.*~" "$taskrc"
  ! grep "^hooks\.location=.*\$" "$taskrc"
  ! grep "^hooks\.location=.*~" "$taskrc"
}

@test "Property 15: data.location ends with /.task" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profile_name="test-data-suffix"
  
  # Create profile and .taskrc
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  local data_location=$(grep "^data\.location=" "$taskrc" | cut -d= -f2)
  
  # Verify path ends with /.task
  [[ "$data_location" == */.task ]]
}

@test "Property 15: hooks.location ends with /.task/hooks" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profile_name="test-hooks-suffix"
  
  # Create profile and .taskrc
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  local hooks_location=$(grep "^hooks\.location=" "$taskrc" | cut -d= -f2)
  
  # Verify path ends with /.task/hooks
  [[ "$hooks_location" == */.task/hooks ]]
}

# ============================================================================
# Property-Based Tests: Random Valid Profile Names (10 iterations)
# ============================================================================

@test "Property 15: Random valid profile names have correct paths (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  for i in {1..10}; do
    # Generate random profile name (length 5-30)
    local length=$((RANDOM % 26 + 5))
    local profile_name="test-$(random_alphanumeric "$length")"
    
    # Create profile and .taskrc
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    local expected_data="$PROFILES_DIR/$profile_name/.task"
    local expected_hooks="$PROFILES_DIR/$profile_name/.task/hooks"
    
    # Verify all three settings are correct
    grep -q "^data\.location=$expected_data$" "$taskrc"
    grep -q "^hooks\.location=$expected_hooks$" "$taskrc"
    grep -q "^hooks=on$" "$taskrc"
  done
}

@test "Property 15: Profile names with hyphens have correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profiles=("work-profile" "my-project-2024" "test-a-b-c" "profile-1-2-3")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    local expected_data="$PROFILES_DIR/$profile_name/.task"
    local expected_hooks="$PROFILES_DIR/$profile_name/.task/hooks"
    
    # Verify paths are correct
    grep -q "^data\.location=$expected_data$" "$taskrc"
    grep -q "^hooks\.location=$expected_hooks$" "$taskrc"
    grep -q "^hooks=on$" "$taskrc"
  done
}

@test "Property 15: Profile names with underscores have correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profiles=("work_profile" "my_project_2024" "test_a_b_c" "profile_1_2_3")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    local expected_data="$PROFILES_DIR/$profile_name/.task"
    local expected_hooks="$PROFILES_DIR/$profile_name/.task/hooks"
    
    # Verify paths are correct
    grep -q "^data\.location=$expected_data$" "$taskrc"
    grep -q "^hooks\.location=$expected_hooks$" "$taskrc"
    grep -q "^hooks=on$" "$taskrc"
  done
}

@test "Property 15: Mixed valid characters have correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profiles=("Work_Profile-2024" "my-project_v1" "Test-123_ABC" "a1-b2_c3-d4")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    local expected_data="$PROFILES_DIR/$profile_name/.task"
    local expected_hooks="$PROFILES_DIR/$profile_name/.task/hooks"
    
    # Verify paths are correct
    grep -q "^data\.location=$expected_data$" "$taskrc"
    grep -q "^hooks\.location=$expected_hooks$" "$taskrc"
    grep -q "^hooks=on$" "$taskrc"
  done
}

@test "Property 15: Numeric profile names have correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profiles=("123" "2024" "12345" "999")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    local expected_data="$PROFILES_DIR/$profile_name/.task"
    local expected_hooks="$PROFILES_DIR/$profile_name/.task/hooks"
    
    # Verify paths are correct
    grep -q "^data\.location=$expected_data$" "$taskrc"
    grep -q "^hooks\.location=$expected_hooks$" "$taskrc"
    grep -q "^hooks=on$" "$taskrc"
  done
}

@test "Property 15: Single character profile names have correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profiles=("a" "Z" "1" "_" "-")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    local expected_data="$PROFILES_DIR/$profile_name/.task"
    local expected_hooks="$PROFILES_DIR/$profile_name/.task/hooks"
    
    # Verify paths are correct
    grep -q "^data\.location=$expected_data$" "$taskrc"
    grep -q "^hooks\.location=$expected_hooks$" "$taskrc"
    grep -q "^hooks=on$" "$taskrc"
  done
}

@test "Property 15: Maximum length profile names (50 chars) have correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  # Generate exactly 50-character name
  local profile_name="a123456789b123456789c123456789d123456789e12345678"
  [ ${#profile_name} -eq 50 ]
  
  create_profile_directories "$profile_name"
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  local expected_data="$PROFILES_DIR/$profile_name/.task"
  local expected_hooks="$PROFILES_DIR/$profile_name/.task/hooks"
  
  # Verify paths are correct
  grep -q "^data\.location=$expected_data$" "$taskrc"
  grep -q "^hooks\.location=$expected_hooks$" "$taskrc"
  grep -q "^hooks=on$" "$taskrc"
}

# ============================================================================
# Edge Cases and Validation
# ============================================================================

@test "Property 15: Multiple profiles have independent correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profile1="test-multi-1"
  local profile2="test-multi-2"
  local profile3="test-multi-3"
  
  # Create multiple profiles
  create_profile_directories "$profile1"
  create_profile_directories "$profile2"
  create_profile_directories "$profile3"
  
  create_taskrc "$profile1"
  create_taskrc "$profile2"
  create_taskrc "$profile3"
  
  # Verify each has correct independent paths
  local taskrc1="$PROFILES_DIR/$profile1/.taskrc"
  local taskrc2="$PROFILES_DIR/$profile2/.taskrc"
  local taskrc3="$PROFILES_DIR/$profile3/.taskrc"
  
  # Profile 1
  grep -q "^data\.location=$PROFILES_DIR/$profile1/.task$" "$taskrc1"
  grep -q "^hooks\.location=$PROFILES_DIR/$profile1/.task/hooks$" "$taskrc1"
  grep -q "^hooks=on$" "$taskrc1"
  
  # Profile 2
  grep -q "^data\.location=$PROFILES_DIR/$profile2/.task$" "$taskrc2"
  grep -q "^hooks\.location=$PROFILES_DIR/$profile2/.task/hooks$" "$taskrc2"
  grep -q "^hooks=on$" "$taskrc2"
  
  # Profile 3
  grep -q "^data\.location=$PROFILES_DIR/$profile3/.task$" "$taskrc3"
  grep -q "^hooks\.location=$PROFILES_DIR/$profile3/.task/hooks$" "$taskrc3"
  grep -q "^hooks=on$" "$taskrc3"
}

@test "Property 15: Idempotent - recreating .taskrc maintains correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  local profile_name="test-idempotent"
  
  create_profile_directories "$profile_name"
  
  # Create .taskrc first time
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  # Create .taskrc second time
  run create_taskrc "$profile_name"
  [ "$status" -eq 0 ]
  
  local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
  local expected_data="$PROFILES_DIR/$profile_name/.task"
  local expected_hooks="$PROFILES_DIR/$profile_name/.task/hooks"
  
  # Verify paths are still correct
  grep -q "^data\.location=$expected_data$" "$taskrc"
  grep -q "^hooks\.location=$expected_hooks$" "$taskrc"
  grep -q "^hooks=on$" "$taskrc"
}
