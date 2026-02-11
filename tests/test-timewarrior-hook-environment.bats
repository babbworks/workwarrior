#!/usr/bin/env bats
# Property-Based Tests for TimeWarrior Hook Environment Variable Usage
# Feature: workwarrior-profiles-and-services
# Property 18: Hook Environment Variable Usage
# Validates: Requirements 7.10

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
# Property 18: Hook Environment Variable Usage
# For any execution of the on-modify.timewarrior hook, it should use the
# TIMEWARRIORDB environment variable to determine the TimeWarrior data location.
# ============================================================================

# Helper function to generate random alphanumeric string
random_alphanumeric() {
  local length="$1"
  tr -dc 'a-zA-Z0-9_-' < /dev/urandom | head -c "$length"
}

@test "Property 18: Hook uses timew command (which respects TIMEWARRIORDB)" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-env-timew"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook uses timew command (which respects TIMEWARRIORDB env var)
  grep -q "timew" "$hook_path"
}

@test "Property 18: Hook does not hardcode TimeWarrior data paths" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-no-hardcode"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook does not contain hardcoded paths to .timewarrior
  # The hook should use 'timew' command which respects TIMEWARRIORDB
  ! grep -q "\.timewarrior" "$hook_path"
}

@test "Property 18: Hook uses subprocess.call with timew" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-subprocess"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook uses subprocess.call with timew
  # This ensures timew is called as a subprocess which inherits TIMEWARRIORDB
  grep -q "subprocess.call.*timew" "$hook_path"
}

@test "Property 18: Hook calls timew start with tags" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-timew-start"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook calls timew start
  grep -q "'timew'.*'start'" "$hook_path" || grep -q '"timew".*"start"' "$hook_path"
}

@test "Property 18: Hook calls timew stop" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-timew-stop"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook calls timew stop
  grep -q "'timew'.*'stop'" "$hook_path" || grep -q '"timew".*"stop"' "$hook_path"
}

@test "Property 18: Hook does not set TIMEWARRIORDB internally" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-no-internal-set"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook does not set TIMEWARRIORDB (should rely on environment)
  ! grep -q "TIMEWARRIORDB.*=" "$hook_path"
}

# ============================================================================
# Property-Based Tests: Random Valid Profile Names (10 iterations)
# ============================================================================

@test "Property 18: Random profiles have hooks that use timew (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  for i in {1..10}; do
    # Generate random profile name (length 5-30)
    local length=$((RANDOM % 26 + 5))
    local profile_name="test-$(random_alphanumeric "$length")"
    
    # Create profile directories
    create_profile_directories "$profile_name"
    
    # Install hook
    run install_timewarrior_hook "$profile_name"
    [ "$status" -eq 0 ]
    
    local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
    
    # Verify hook uses timew command
    grep -q "timew" "$hook_path"
    
    # Verify hook does not hardcode paths
    ! grep -q "\.timewarrior" "$hook_path"
  done
}

@test "Property 18: Profile names with hyphens have hooks that use timew" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profiles=("work-profile" "my-project-2024" "test-a-b-c" "profile-1-2-3")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    
    run install_timewarrior_hook "$profile_name"
    [ "$status" -eq 0 ]
    
    local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
    
    # Verify hook uses timew command
    grep -q "timew" "$hook_path"
    
    # Verify hook does not hardcode paths
    ! grep -q "\.timewarrior" "$hook_path"
  done
}

@test "Property 18: Profile names with underscores have hooks that use timew" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profiles=("work_profile" "my_project_2024" "test_a_b_c" "profile_1_2_3")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    
    run install_timewarrior_hook "$profile_name"
    [ "$status" -eq 0 ]
    
    local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
    
    # Verify hook uses timew command
    grep -q "timew" "$hook_path"
    
    # Verify hook does not hardcode paths
    ! grep -q "\.timewarrior" "$hook_path"
  done
}

@test "Property 18: Mixed valid characters have hooks that use timew" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profiles=("Work_Profile-2024" "my-project_v1" "Test-123_ABC" "a1-b2_c3-d4")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    
    run install_timewarrior_hook "$profile_name"
    [ "$status" -eq 0 ]
    
    local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
    
    # Verify hook uses timew command
    grep -q "timew" "$hook_path"
    
    # Verify hook does not hardcode paths
    ! grep -q "\.timewarrior" "$hook_path"
  done
}

# ============================================================================
# Integration Tests: Verify Hook Behavior with TIMEWARRIORDB
# ============================================================================

@test "Property 18: Hook can be executed with Python interpreter" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-python-exec"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook can be compiled by Python (syntax check)
  run python3 -m py_compile "$hook_path"
  [ "$status" -eq 0 ]
}

@test "Property 18: Hook imports required modules" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-imports"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook imports required modules for subprocess execution
  grep -q "import subprocess" "$hook_path"
  grep -q "import json" "$hook_path"
  grep -q "import sys" "$hook_path"
}

@test "Property 18: Hook reads from stdin and writes to stdout" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-stdio"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook reads from stdin
  grep -q "sys.stdin" "$hook_path"
  
  # Verify hook writes to stdout (prints JSON)
  grep -q "print.*json" "$hook_path"
}

@test "Property 18: Hook processes task JSON data" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-json-processing"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook processes JSON data
  grep -q "json.loads" "$hook_path"
  grep -q "json.dumps" "$hook_path"
}

@test "Property 18: Multiple profiles have independent hooks using timew" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile1="test-multi-env-1"
  local profile2="test-multi-env-2"
  local profile3="test-multi-env-3"
  
  # Create multiple profiles
  create_profile_directories "$profile1"
  create_profile_directories "$profile2"
  create_profile_directories "$profile3"
  
  # Install hooks
  install_timewarrior_hook "$profile1"
  install_timewarrior_hook "$profile2"
  install_timewarrior_hook "$profile3"
  
  # Verify each hook uses timew
  local hook1="$PROFILES_DIR/$profile1/.task/hooks/on-modify.timewarrior"
  local hook2="$PROFILES_DIR/$profile2/.task/hooks/on-modify.timewarrior"
  local hook3="$PROFILES_DIR/$profile3/.task/hooks/on-modify.timewarrior"
  
  grep -q "timew" "$hook1"
  grep -q "timew" "$hook2"
  grep -q "timew" "$hook3"
  
  # Verify none hardcode paths
  ! grep -q "\.timewarrior" "$hook1"
  ! grep -q "\.timewarrior" "$hook2"
  ! grep -q "\.timewarrior" "$hook3"
}

@test "Property 18: Hook respects environment by using timew command" {
  # Feature: workwarrior-profiles-and-services, Property 18: Hook Environment Variable Usage
  
  local profile_name="test-env-respect"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # The hook should use 'timew' command which automatically respects
  # the TIMEWARRIORDB environment variable set by the shell
  # Verify the hook calls timew without any path manipulation
  grep -q "subprocess.call.*'timew'" "$hook_path" || grep -q 'subprocess.call.*"timew"' "$hook_path"
  
  # Verify no os.environ manipulation of TIMEWARRIORDB
  ! grep -q "os.environ.*TIMEWARRIORDB" "$hook_path"
}
