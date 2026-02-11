#!/usr/bin/env bats
# Property-Based Tests for Profile Name Validation
# Feature: workwarrior-profiles-and-services
# Property 2: Profile Name Validation
# Validates: Requirements 2.2

# Load the core utilities library
setup() {
  # Source the core utilities
  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
  
  # Set up test environment
  export TEST_MODE=1
}

# ============================================================================
# Property 2: Profile Name Validation
# For any string containing characters outside [a-zA-Z0-9_-], 
# the Profile_Manager should reject it as an invalid profile name and return an error.
# ============================================================================

@test "Property 2: Empty profile name is rejected" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  run validate_profile_name ""
  [ "$status" -eq 1 ]
  [[ "$output" =~ "cannot be empty" ]]
}

@test "Property 2: Profile name with spaces is rejected" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  run validate_profile_name "my profile"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "letters, numbers, hyphens, and underscores" ]]
}

@test "Property 2: Profile name with special characters is rejected" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  # Test various special characters
  local invalid_chars=('!' '@' '#' '$' '%' '^' '&' '*' '(' ')' '+' '=' '[' ']' '{' '}' '|' '\' ';' ':' '"' "'" '<' '>' ',' '.' '?' '/' '~' '`')
  
  for char in "${invalid_chars[@]}"; do
    run validate_profile_name "test${char}profile"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "letters, numbers, hyphens, and underscores" ]]
  done
}

@test "Property 2: Profile name exceeding 50 characters is rejected" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  # Generate a 51-character name
  local long_name="a123456789b123456789c123456789d123456789e123456789f"
  [ ${#long_name} -eq 51 ]
  
  run validate_profile_name "$long_name"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "cannot exceed 50 characters" ]]
}

@test "Property 2: Valid profile names with letters only are accepted" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  # Test various valid names
  local valid_names=("work" "personal" "MyProfile" "UPPERCASE" "lowercase" "MixedCase")
  
  for name in "${valid_names[@]}"; do
    run validate_profile_name "$name"
    [ "$status" -eq 0 ]
  done
}

@test "Property 2: Valid profile names with numbers are accepted" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  local valid_names=("work1" "profile2" "test123" "123test" "a1b2c3")
  
  for name in "${valid_names[@]}"; do
    run validate_profile_name "$name"
    [ "$status" -eq 0 ]
  done
}

@test "Property 2: Valid profile names with hyphens are accepted" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  local valid_names=("work-profile" "my-project" "test-123" "a-b-c" "profile-1")
  
  for name in "${valid_names[@]}"; do
    run validate_profile_name "$name"
    [ "$status" -eq 0 ]
  done
}

@test "Property 2: Valid profile names with underscores are accepted" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  local valid_names=("work_profile" "my_project" "test_123" "a_b_c" "profile_1")
  
  for name in "${valid_names[@]}"; do
    run validate_profile_name "$name"
    [ "$status" -eq 0 ]
  done
}

@test "Property 2: Valid profile names with mixed valid characters are accepted" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  local valid_names=("work-profile_1" "my_project-2" "test-123_abc" "a1-b2_c3" "Profile_Name-123")
  
  for name in "${valid_names[@]}"; do
    run validate_profile_name "$name"
    [ "$status" -eq 0 ]
  done
}

@test "Property 2: Profile name exactly 50 characters is accepted" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  # Generate exactly 50-character name
  local name_50="a123456789b123456789c123456789d123456789e12345678"
  [ ${#name_50} -eq 50 ]
  
  run validate_profile_name "$name_50"
  [ "$status" -eq 0 ]
}

@test "Property 2: Profile name with single character is accepted" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  run validate_profile_name "a"
  [ "$status" -eq 0 ]
  
  run validate_profile_name "1"
  [ "$status" -eq 0 ]
  
  run validate_profile_name "_"
  [ "$status" -eq 0 ]
  
  run validate_profile_name "-"
  [ "$status" -eq 0 ]
}

# ============================================================================
# Property-Based Test: Random Valid Names
# Generate random valid profile names and verify they are accepted
# ============================================================================

# Helper function to generate random alphanumeric string
random_alphanumeric() {
  local length="$1"
  tr -dc 'a-zA-Z0-9_-' < /dev/urandom | head -c "$length"
}

@test "Property 2: Random valid profile names are accepted (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  for i in {1..10}; do
    # Generate random length between 1 and 50
    local length=$((RANDOM % 50 + 1))
    local name=$(random_alphanumeric "$length")
    
    # Ensure we generated something
    if [[ -n "$name" ]]; then
      run validate_profile_name "$name"
      [ "$status" -eq 0 ]
    fi
  done
}

# ============================================================================
# Property-Based Test: Random Invalid Names
# Generate random invalid profile names and verify they are rejected
# ============================================================================

@test "Property 2: Random invalid profile names with special chars are rejected (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  local special_chars=('!' '@' '#' '$' '%' '^' '&' '*' '(' ')' '+' '=' ' ' '.' ',' '/')
  
  for i in {1..10}; do
    # Generate a valid base name
    local base=$(random_alphanumeric 10)
    
    # Insert a random special character
    local char="${special_chars[$RANDOM % ${#special_chars[@]}]}"
    local invalid_name="${base}${char}test"
    
    run validate_profile_name "$invalid_name"
    [ "$status" -eq 1 ]
  done
}

@test "Property 2: Random names exceeding 50 characters are rejected (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 2: Profile Name Validation
  
  for i in {1..10}; do
    # Generate random length between 51 and 100
    local length=$((RANDOM % 50 + 51))
    local name=$(random_alphanumeric "$length")
    
    # Verify length is > 50
    [ ${#name} -gt 50 ]
    
    run validate_profile_name "$name"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "cannot exceed 50 characters" ]]
  done
}
