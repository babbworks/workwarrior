#!/usr/bin/env bats
# Property-Based Tests for Profile Directory Structure Creation
# Feature: workwarrior-profiles-and-services
# Property 1: Complete Directory Structure Creation
# Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.9, 1.10

# Load the libraries
setup() {
  # Source the libraries
  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
  source "${BATS_TEST_DIRNAME}/../lib/profile-manager.sh"
  
  # Set up test environment
  export TEST_MODE=1
  export TEST_PROFILES_DIR="${BATS_TEST_DIRNAME}/../test-profiles"
  export PROFILES_DIR="$TEST_PROFILES_DIR"
  
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
# Property 1: Complete Directory Structure Creation
# For any valid profile name, when a profile is created, the Profile_Manager
# should create all required directories (.task, .task/hooks, .timewarrior,
# journals, ledgers) within the profile base directory, and all parent
# directories should exist.
# ============================================================================

@test "Property 1: Profile base directory is created" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  local profile_name="test-profile"
  
  run create_profile_directories "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify base directory exists
  [ -d "$PROFILES_DIR/$profile_name" ]
}

@test "Property 1: All required subdirectories are created" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  local profile_name="test-complete"
  
  run create_profile_directories "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify all required directories exist
  [ -d "$PROFILES_DIR/$profile_name/.task" ]
  [ -d "$PROFILES_DIR/$profile_name/.task/hooks" ]
  [ -d "$PROFILES_DIR/$profile_name/.timewarrior" ]
  [ -d "$PROFILES_DIR/$profile_name/journals" ]
  [ -d "$PROFILES_DIR/$profile_name/ledgers" ]
}

@test "Property 1: Parent directories are created automatically" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  # Remove profiles directory to test parent creation
  rm -rf "$PROFILES_DIR"
  
  local profile_name="test-parent"
  
  run create_profile_directories "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify parent and all subdirectories exist
  [ -d "$PROFILES_DIR" ]
  [ -d "$PROFILES_DIR/$profile_name" ]
  [ -d "$PROFILES_DIR/$profile_name/.task" ]
}

@test "Property 1: Multiple profiles can be created independently" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  local profile1="test-profile-1"
  local profile2="test-profile-2"
  local profile3="test-profile-3"
  
  # Create multiple profiles
  run create_profile_directories "$profile1"
  [ "$status" -eq 0 ]
  
  run create_profile_directories "$profile2"
  [ "$status" -eq 0 ]
  
  run create_profile_directories "$profile3"
  [ "$status" -eq 0 ]
  
  # Verify all profiles exist independently
  [ -d "$PROFILES_DIR/$profile1" ]
  [ -d "$PROFILES_DIR/$profile2" ]
  [ -d "$PROFILES_DIR/$profile3" ]
  
  # Verify each has complete structure
  [ -d "$PROFILES_DIR/$profile1/.task/hooks" ]
  [ -d "$PROFILES_DIR/$profile2/.task/hooks" ]
  [ -d "$PROFILES_DIR/$profile3/.task/hooks" ]
}

@test "Property 1: Creating existing profile succeeds (idempotent)" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  local profile_name="test-idempotent"
  
  # Create profile first time
  run create_profile_directories "$profile_name"
  [ "$status" -eq 0 ]
  
  # Create same profile again
  run create_profile_directories "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify structure still exists
  [ -d "$PROFILES_DIR/$profile_name/.task/hooks" ]
  [ -d "$PROFILES_DIR/$profile_name/.timewarrior" ]
  [ -d "$PROFILES_DIR/$profile_name/journals" ]
  [ -d "$PROFILES_DIR/$profile_name/ledgers" ]
}

@test "Property 1: Invalid profile name fails gracefully" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  # Try to create profile with invalid name
  run create_profile_directories "invalid name with spaces"
  [ "$status" -eq 1 ]
  
  # Verify no directory was created
  [ ! -d "$PROFILES_DIR/invalid name with spaces" ]
}

# ============================================================================
# Property-Based Test: Random Valid Profile Names
# Generate random valid profile names and verify complete structure creation
# ============================================================================

# Helper function to generate random alphanumeric string
random_alphanumeric() {
  local length="$1"
  tr -dc 'a-zA-Z0-9_-' < /dev/urandom | head -c "$length" || true
}

@test "Property 1: Random valid profile names create complete structure (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  for i in {1..10}; do
    # Generate random profile name (length 5-30)
    local length=$((RANDOM % 26 + 5))
    local profile_name="test-$(random_alphanumeric "$length")"
    
    # Create profile
    run create_profile_directories "$profile_name"
    [ "$status" -eq 0 ]
    
    # Verify complete directory structure
    [ -d "$PROFILES_DIR/$profile_name" ]
    [ -d "$PROFILES_DIR/$profile_name/.task" ]
    [ -d "$PROFILES_DIR/$profile_name/.task/hooks" ]
    [ -d "$PROFILES_DIR/$profile_name/.timewarrior" ]
    [ -d "$PROFILES_DIR/$profile_name/journals" ]
    [ -d "$PROFILES_DIR/$profile_name/ledgers" ]
  done
}

@test "Property 1: Profile names with hyphens create correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  local profiles=("work-profile" "my-project-2024" "test-a-b-c" "profile-1-2-3")
  
  for profile_name in "${profiles[@]}"; do
    run create_profile_directories "$profile_name"
    [ "$status" -eq 0 ]
    
    # Verify structure
    [ -d "$PROFILES_DIR/$profile_name/.task/hooks" ]
    [ -d "$PROFILES_DIR/$profile_name/.timewarrior" ]
    [ -d "$PROFILES_DIR/$profile_name/journals" ]
    [ -d "$PROFILES_DIR/$profile_name/ledgers" ]
  done
}

@test "Property 1: Profile names with underscores create correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  local profiles=("work_profile" "my_project_2024" "test_a_b_c" "profile_1_2_3")
  
  for profile_name in "${profiles[@]}"; do
    run create_profile_directories "$profile_name"
    [ "$status" -eq 0 ]
    
    # Verify structure
    [ -d "$PROFILES_DIR/$profile_name/.task/hooks" ]
    [ -d "$PROFILES_DIR/$profile_name/.timewarrior" ]
    [ -d "$PROFILES_DIR/$profile_name/journals" ]
    [ -d "$PROFILES_DIR/$profile_name/ledgers" ]
  done
}

@test "Property 1: Mixed valid characters create correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  local profiles=("Work_Profile-2024" "my-project_v1" "Test-123_ABC" "a1-b2_c3-d4")
  
  for profile_name in "${profiles[@]}"; do
    run create_profile_directories "$profile_name"
    [ "$status" -eq 0 ]
    
    # Verify complete structure
    [ -d "$PROFILES_DIR/$profile_name" ]
    [ -d "$PROFILES_DIR/$profile_name/.task" ]
    [ -d "$PROFILES_DIR/$profile_name/.task/hooks" ]
    [ -d "$PROFILES_DIR/$profile_name/.timewarrior" ]
    [ -d "$PROFILES_DIR/$profile_name/journals" ]
    [ -d "$PROFILES_DIR/$profile_name/ledgers" ]
  done
}

@test "Property 1: Numeric profile names create correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  local profiles=("123" "2024" "12345" "999")
  
  for profile_name in "${profiles[@]}"; do
    run create_profile_directories "$profile_name"
    [ "$status" -eq 0 ]
    
    # Verify structure
    [ -d "$PROFILES_DIR/$profile_name/.task/hooks" ]
    [ -d "$PROFILES_DIR/$profile_name/.timewarrior" ]
    [ -d "$PROFILES_DIR/$profile_name/journals" ]
    [ -d "$PROFILES_DIR/$profile_name/ledgers" ]
  done
}

@test "Property 1: Single character profile names create correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  local profiles=("a" "Z" "1" "_" "-")
  
  for profile_name in "${profiles[@]}"; do
    run create_profile_directories "$profile_name"
    [ "$status" -eq 0 ]
    
    # Verify structure
    [ -d "$PROFILES_DIR/$profile_name/.task/hooks" ]
    [ -d "$PROFILES_DIR/$profile_name/.timewarrior" ]
    [ -d "$PROFILES_DIR/$profile_name/journals" ]
    [ -d "$PROFILES_DIR/$profile_name/ledgers" ]
  done
}

@test "Property 1: Maximum length profile names (50 chars) create correct paths" {
  # Feature: workwarrior-profiles-and-services, Property 1: Complete Directory Structure Creation
  
  # Generate exactly 50-character name
  local profile_name="a123456789b123456789c123456789d123456789e12345678"
  [ ${#profile_name} -eq 50 ]
  
  run create_profile_directories "$profile_name"
  [ "$status" -eq 0 ]
  
  # Verify complete structure
  [ -d "$PROFILES_DIR/$profile_name" ]
  [ -d "$PROFILES_DIR/$profile_name/.task" ]
  [ -d "$PROFILES_DIR/$profile_name/.task/hooks" ]
  [ -d "$PROFILES_DIR/$profile_name/.timewarrior" ]
  [ -d "$PROFILES_DIR/$profile_name/journals" ]
  [ -d "$PROFILES_DIR/$profile_name/ledgers" ]
}
