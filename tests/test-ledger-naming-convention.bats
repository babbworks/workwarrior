#!/usr/bin/env bats
# Property 25: Ledger Naming Convention
# Feature: workwarrior-profiles-and-services

# Load test helpers
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Setup and teardown
setup() {
  # Create temporary test directory
  export TEST_WW_BASE="$BATS_TEST_TMPDIR/ww-test-$$"
  export PROFILES_DIR="$TEST_WW_BASE/profiles"
  mkdir -p "$PROFILES_DIR"
  
  # Source the libraries
  export WW_BASE="$TEST_WW_BASE"
  source "$(dirname "$BATS_TEST_DIRNAME")/lib/core-utils.sh"
  source "$(dirname "$BATS_TEST_DIRNAME")/lib/profile-manager.sh"
}

teardown() {
  # Clean up test directory
  if [[ -n "$TEST_WW_BASE" ]] && [[ -d "$TEST_WW_BASE" ]]; then
    rm -rf "$TEST_WW_BASE"
  fi
}

# Helper function to generate random alphanumeric string
random_alphanumeric() {
  local length="$1"
  LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# ============================================================================
# Property 25: Ledger Naming Convention Tests
# ============================================================================

@test "Property 25: Default ledger file is named after profile" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  profile_name="test-naming"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledger file is named <profile-name>.journal
  expected_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  assert [ -f "$expected_file" ]
}

@test "Property 25: Ledger filename matches profile name exactly" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  profile_name="my-work-profile"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify the filename matches exactly
  ledger_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  assert [ -f "$ledger_file" ]
  
  # Verify no other .journal files exist
  run find "$PROFILES_DIR/$profile_name/ledgers" -name "*.journal" -type f
  assert_success
  assert_equal "${#lines[@]}" "1"
  assert_equal "${lines[0]}" "$ledger_file"
}

@test "Property 25: Profile with hyphens has correctly named ledger" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  profile_name="test-with-many-hyphens"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledger file name includes all hyphens
  expected_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  assert [ -f "$expected_file" ]
  
  # Verify the basename matches
  run basename "$expected_file" .journal
  assert_equal "$output" "$profile_name"
}

@test "Property 25: Profile with underscores has correctly named ledger" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  profile_name="test_with_underscores"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledger file name includes all underscores
  expected_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  assert [ -f "$expected_file" ]
  
  # Verify the basename matches
  run basename "$expected_file" .journal
  assert_equal "$output" "$profile_name"
}

@test "Property 25: Profile with numbers has correctly named ledger" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  profile_name="project2024"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledger file name includes numbers
  expected_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  assert [ -f "$expected_file" ]
  
  # Verify the basename matches
  run basename "$expected_file" .journal
  assert_equal "$output" "$profile_name"
}

@test "Property 25: Mixed case profile has correctly named ledger" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  profile_name="MyWorkProfile"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledger file name preserves case
  expected_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  assert [ -f "$expected_file" ]
  
  # Verify the basename matches exactly (case-sensitive)
  run basename "$expected_file" .journal
  assert_equal "$output" "$profile_name"
}

# ============================================================================
# Property-Based Tests (10 iterations)
# ============================================================================

@test "Property 25: Random valid profile names have correctly named ledgers (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  for i in {1..10}; do
    # Generate random valid profile name
    profile_name="test-$(random_alphanumeric 10)"
    
    # Create profile directories
    create_profile_directories "$profile_name"
    
    # Create ledger configuration
    run create_ledger_config "$profile_name"
    assert_success
    
    # Verify ledger file is named <profile-name>.journal
    expected_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
    assert [ -f "$expected_file" ]
    
    # Verify the basename matches the profile name
    actual_basename=$(basename "$expected_file" .journal)
    assert_equal "$actual_basename" "$profile_name"
    
    # Verify ledgers.yaml references the correctly named file
    run grep "$profile_name.journal" "$PROFILES_DIR/$profile_name/ledgers.yaml"
    assert_success
  done
}

@test "Property 25: Ledger file extension is always .journal" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  for i in {1..10}; do
    profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile directories
    create_profile_directories "$profile_name"
    
    # Create ledger configuration
    run create_ledger_config "$profile_name"
    assert_success
    
    # Verify file has .journal extension
    ledger_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
    assert [ -f "$ledger_file" ]
    
    # Verify extension
    [[ "$ledger_file" == *.journal ]]
  done
}

@test "Property 25: Ledger file is in ledgers directory" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  for i in {1..10}; do
    profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile directories
    create_profile_directories "$profile_name"
    
    # Create ledger configuration
    run create_ledger_config "$profile_name"
    assert_success
    
    # Verify file is in ledgers directory
    ledger_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
    assert [ -f "$ledger_file" ]
    
    # Verify parent directory is named "ledgers"
    parent_dir=$(dirname "$ledger_file")
    run basename "$parent_dir"
    assert_equal "$output" "ledgers"
  done
}

# ============================================================================
# Consistency Tests
# ============================================================================

@test "Property 25: Multiple profiles have independently named ledgers" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  profile1="work-$(random_alphanumeric 5)"
  profile2="personal-$(random_alphanumeric 5)"
  profile3="project-$(random_alphanumeric 5)"
  
  # Create three profiles
  for profile in "$profile1" "$profile2" "$profile3"; do
    create_profile_directories "$profile"
    run create_ledger_config "$profile"
    assert_success
  done
  
  # Verify each has its own correctly named ledger
  assert [ -f "$PROFILES_DIR/$profile1/ledgers/$profile1.journal" ]
  assert [ -f "$PROFILES_DIR/$profile2/ledgers/$profile2.journal" ]
  assert [ -f "$PROFILES_DIR/$profile3/ledgers/$profile3.journal" ]
  
  # Verify names don't conflict
  assert [ "$profile1" != "$profile2" ]
  assert [ "$profile2" != "$profile3" ]
  assert [ "$profile1" != "$profile3" ]
}

@test "Property 25: Ledgers.yaml references correctly named ledger file" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  for i in {1..10}; do
    profile_name="test-$(random_alphanumeric 10)"
    
    # Create profile directories
    create_profile_directories "$profile_name"
    
    # Create ledger configuration
    run create_ledger_config "$profile_name"
    assert_success
    
    # Verify ledgers.yaml contains the correct filename
    ledger_config="$PROFILES_DIR/$profile_name/ledgers.yaml"
    expected_path="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
    
    run grep "default: $expected_path" "$ledger_config"
    assert_success
    
    # Verify the referenced file actually exists
    referenced_file=$(grep "default:" "$ledger_config" | awk '{print $2}')
    assert [ -f "$referenced_file" ]
    
    # Verify the referenced file basename matches profile name
    run basename "$referenced_file" .journal
    assert_equal "$output" "$profile_name"
  done
}

@test "Property 25: Single character profile names have correctly named ledgers" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  profile_name="x"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledger file is named x.journal
  expected_file="$PROFILES_DIR/$profile_name/ledgers/x.journal"
  assert [ -f "$expected_file" ]
}

@test "Property 25: Maximum length profile names (50 chars) have correctly named ledgers" {
  # Feature: workwarrior-profiles-and-services, Property 25: Ledger Naming Convention
  
  # Generate 50 character profile name
  profile_name=$(random_alphanumeric 50)
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledger file is named <50-char-name>.journal
  expected_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  assert [ -f "$expected_file" ]
  
  # Verify the basename is exactly 50 characters
  basename_without_ext=$(basename "$expected_file" .journal)
  assert_equal "${#basename_without_ext}" "50"
  assert_equal "$basename_without_ext" "$profile_name"
}
