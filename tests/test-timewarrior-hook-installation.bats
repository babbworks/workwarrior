#!/usr/bin/env bats
# Property-Based Tests for TimeWarrior Hook Installation
# Feature: workwarrior-profiles-and-services
# Property 17: TimeWarrior Hook Installation
# Validates: Requirements 7.1, 7.2, 7.3, 7.4

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
# Property 17: TimeWarrior Hook Installation
# For any created profile, the on-modify.timewarrior hook should exist at
# .task/hooks/on-modify.timewarrior and be executable (have execute permissions).
# ============================================================================

# Helper function to generate random alphanumeric string
random_alphanumeric() {
  local length="$1"
  tr -dc 'a-zA-Z0-9_-' < /dev/urandom | head -c "$length"
}

@test "Property 17: Hook file exists after installation" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile_name="test-hook-exists"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook file exists
  [ -f "$hook_path" ]
}

@test "Property 17: Hook is executable" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile_name="test-hook-executable"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook is executable
  [ -x "$hook_path" ]
}

@test "Property 17: Hook has Python shebang" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile_name="test-hook-shebang"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook has Python shebang
  head -n 1 "$hook_path" | grep -q "^#!/usr/bin/env python3"
}

@test "Property 17: Hook contains required functions" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile_name="test-hook-functions"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook contains required functions
  grep -q "def extract_tags_from" "$hook_path"
  grep -q "def main" "$hook_path"
  grep -q "if __name__" "$hook_path"
}

@test "Property 17: Hook uses timew command" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile_name="test-hook-timew"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook uses timew command
  grep -q "timew" "$hook_path"
}

@test "Property 17: Hook handles start and stop events" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile_name="test-hook-events"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Install hook
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook handles start and stop
  grep -q "start" "$hook_path"
  grep -q "stop" "$hook_path"
}

# ============================================================================
# Property-Based Tests: Random Valid Profile Names (10 iterations)
# ============================================================================

@test "Property 17: Random valid profile names get executable hook (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
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
    
    # Verify hook exists and is executable
    [ -f "$hook_path" ]
    [ -x "$hook_path" ]
  done
}

@test "Property 17: Profile names with hyphens get executable hook" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profiles=("work-profile" "my-project-2024" "test-a-b-c" "profile-1-2-3")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    
    run install_timewarrior_hook "$profile_name"
    [ "$status" -eq 0 ]
    
    local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
    
    # Verify hook exists and is executable
    [ -f "$hook_path" ]
    [ -x "$hook_path" ]
  done
}

@test "Property 17: Profile names with underscores get executable hook" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profiles=("work_profile" "my_project_2024" "test_a_b_c" "profile_1_2_3")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    
    run install_timewarrior_hook "$profile_name"
    [ "$status" -eq 0 ]
    
    local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
    
    # Verify hook exists and is executable
    [ -f "$hook_path" ]
    [ -x "$hook_path" ]
  done
}

@test "Property 17: Mixed valid characters get executable hook" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profiles=("Work_Profile-2024" "my-project_v1" "Test-123_ABC" "a1-b2_c3-d4")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    
    run install_timewarrior_hook "$profile_name"
    [ "$status" -eq 0 ]
    
    local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
    
    # Verify hook exists and is executable
    [ -f "$hook_path" ]
    [ -x "$hook_path" ]
  done
}

@test "Property 17: Numeric profile names get executable hook" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profiles=("123" "2024" "12345" "999")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    
    run install_timewarrior_hook "$profile_name"
    [ "$status" -eq 0 ]
    
    local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
    
    # Verify hook exists and is executable
    [ -f "$hook_path" ]
    [ -x "$hook_path" ]
  done
}

@test "Property 17: Single character profile names get executable hook" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profiles=("a" "Z" "1" "_" "-")
  
  for profile_name in "${profiles[@]}"; do
    create_profile_directories "$profile_name"
    
    run install_timewarrior_hook "$profile_name"
    [ "$status" -eq 0 ]
    
    local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
    
    # Verify hook exists and is executable
    [ -f "$hook_path" ]
    [ -x "$hook_path" ]
  done
}

@test "Property 17: Maximum length profile names (50 chars) get executable hook" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  # Generate exactly 50-character name
  local profile_name="a123456789b123456789c123456789d123456789e12345678"
  [ ${#profile_name} -eq 50 ]
  
  create_profile_directories "$profile_name"
  
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook exists and is executable
  [ -f "$hook_path" ]
  [ -x "$hook_path" ]
}

# ============================================================================
# Edge Cases and Validation
# ============================================================================

@test "Property 17: Multiple profiles have independent hooks" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile1="test-multi-1"
  local profile2="test-multi-2"
  local profile3="test-multi-3"
  
  # Create multiple profiles
  create_profile_directories "$profile1"
  create_profile_directories "$profile2"
  create_profile_directories "$profile3"
  
  # Install hooks
  install_timewarrior_hook "$profile1"
  install_timewarrior_hook "$profile2"
  install_timewarrior_hook "$profile3"
  
  # Verify each has independent hook
  local hook1="$PROFILES_DIR/$profile1/.task/hooks/on-modify.timewarrior"
  local hook2="$PROFILES_DIR/$profile2/.task/hooks/on-modify.timewarrior"
  local hook3="$PROFILES_DIR/$profile3/.task/hooks/on-modify.timewarrior"
  
  [ -f "$hook1" ]
  [ -x "$hook1" ]
  
  [ -f "$hook2" ]
  [ -x "$hook2" ]
  
  [ -f "$hook3" ]
  [ -x "$hook3" ]
}

@test "Property 17: Idempotent - reinstalling hook maintains executable status" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile_name="test-idempotent"
  
  create_profile_directories "$profile_name"
  
  # Install hook first time
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  # Install hook second time
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify hook is still executable
  [ -f "$hook_path" ]
  [ -x "$hook_path" ]
}

@test "Property 17: Hook installation fails for non-existent profile" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile_name="non-existent-profile"
  
  # Try to install hook without creating profile
  run install_timewarrior_hook "$profile_name"
  [ "$status" -ne 0 ]
}

@test "Property 17: Hook installation fails for invalid profile name" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  # Try to install hook with invalid name
  run install_timewarrior_hook "invalid@profile"
  [ "$status" -ne 0 ]
}

@test "Property 17: Hook file size is reasonable (not empty, not too large)" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile_name="test-hook-size"
  
  create_profile_directories "$profile_name"
  
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Get file size in bytes
  local file_size=$(wc -c < "$hook_path")
  
  # Verify file is not empty (> 0 bytes)
  [ "$file_size" -gt 0 ]
  
  # Verify file is not unreasonably large (< 100KB)
  [ "$file_size" -lt 102400 ]
}

@test "Property 17: Hook is valid Python syntax" {
  # Feature: workwarrior-profiles-and-services, Property 17: TimeWarrior Hook Installation
  
  local profile_name="test-hook-syntax"
  
  create_profile_directories "$profile_name"
  
  run install_timewarrior_hook "$profile_name"
  [ "$status" -eq 0 ]
  
  local hook_path="$PROFILES_DIR/$profile_name/.task/hooks/on-modify.timewarrior"
  
  # Verify Python syntax is valid (compile check)
  run python3 -m py_compile "$hook_path"
  [ "$status" -eq 0 ]
}
