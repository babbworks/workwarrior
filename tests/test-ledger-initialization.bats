#!/usr/bin/env bats
# Property 24: Ledger System Initialization
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
# Property 24: Ledger System Initialization Tests
# ============================================================================

@test "Property 24: Default ledger file exists after initialization" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="test-ledger-init"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify default ledger file exists
  assert [ -f "$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal" ]
}

@test "Property 24: Default ledger has account declarations" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="test-ledger-accounts"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledger file contains account declarations
  ledger_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  assert [ -f "$ledger_file" ]
  
  # Check for account declarations (should have at least one)
  run grep -c "^account " "$ledger_file"
  assert_success
  assert [ "$output" -gt 0 ]
}

@test "Property 24: Default ledger has opening entry" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="test-ledger-opening"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledger file contains opening entry
  ledger_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  assert [ -f "$ledger_file" ]
  
  # Check for opening entry (should have a transaction with date)
  run grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}" "$ledger_file"
  assert_success
}

@test "Property 24: ledgers.yaml exists after initialization" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="test-ledger-yaml"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledgers.yaml exists
  assert [ -f "$PROFILES_DIR/$profile_name/ledgers.yaml" ]
}

@test "Property 24: ledgers.yaml has default ledger configured" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="test-ledger-yaml-default"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledgers.yaml contains default ledger entry
  ledger_config="$PROFILES_DIR/$profile_name/ledgers.yaml"
  assert [ -f "$ledger_config" ]
  
  run grep "^  default:" "$ledger_config"
  assert_success
}

@test "Property 24: ledgers.yaml points to correct ledger file" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="test-ledger-yaml-path"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledgers.yaml points to the correct file
  ledger_config="$PROFILES_DIR/$profile_name/ledgers.yaml"
  expected_path="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  
  run grep "default: $expected_path" "$ledger_config"
  assert_success
}

# ============================================================================
# Property-Based Tests (10 iterations)
# ============================================================================

@test "Property 24: Random valid profile names initialize ledger system (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  for i in {1..10}; do
    # Generate random valid profile name
    profile_name="test-$(random_alphanumeric 10)"
    
    # Create profile directories
    create_profile_directories "$profile_name"
    
    # Create ledger configuration
    run create_ledger_config "$profile_name"
    assert_success
    
    # Verify ledger file exists
    assert [ -f "$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal" ]
    
    # Verify ledgers.yaml exists
    assert [ -f "$PROFILES_DIR/$profile_name/ledgers.yaml" ]
    
    # Verify ledger has account declarations
    ledger_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
    run grep -c "^account " "$ledger_file"
    assert_success
    assert [ "$output" -gt 0 ]
    
    # Verify ledger has opening entry
    run grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}" "$ledger_file"
    assert_success
    
    # Verify ledgers.yaml has default entry
    run grep "^  default:" "$PROFILES_DIR/$profile_name/ledgers.yaml"
    assert_success
  done
}

@test "Property 24: Profile names with hyphens initialize ledger correctly" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="test-with-hyphens-$(random_alphanumeric 5)"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify all components exist
  assert [ -f "$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal" ]
  assert [ -f "$PROFILES_DIR/$profile_name/ledgers.yaml" ]
}

@test "Property 24: Profile names with underscores initialize ledger correctly" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="test_with_underscores_$(random_alphanumeric 5)"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify all components exist
  assert [ -f "$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal" ]
  assert [ -f "$PROFILES_DIR/$profile_name/ledgers.yaml" ]
}

@test "Property 24: Mixed valid characters initialize ledger correctly" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="Test-Mix_123-$(random_alphanumeric 5)"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify all components exist
  assert [ -f "$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal" ]
  assert [ -f "$PROFILES_DIR/$profile_name/ledgers.yaml" ]
}

# ============================================================================
# Edge Cases and Error Handling
# ============================================================================

@test "Property 24: Ledger initialization fails for non-existent profile" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="nonexistent-profile"
  
  # Try to create ledger config without creating profile first
  run create_ledger_config "$profile_name"
  assert_failure
}

@test "Property 24: Ledger initialization fails for invalid profile name" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="invalid@profile"
  
  # Try to create ledger config with invalid name
  run create_ledger_config "$profile_name"
  assert_failure
}

@test "Property 24: Multiple profiles have independent ledger systems" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile1="test-ledger-1-$(random_alphanumeric 5)"
  profile2="test-ledger-2-$(random_alphanumeric 5)"
  profile3="test-ledger-3-$(random_alphanumeric 5)"
  
  # Create three profiles with ledger configs
  for profile in "$profile1" "$profile2" "$profile3"; do
    create_profile_directories "$profile"
    run create_ledger_config "$profile"
    assert_success
  done
  
  # Verify each has its own ledger file
  assert [ -f "$PROFILES_DIR/$profile1/ledgers/$profile1.journal" ]
  assert [ -f "$PROFILES_DIR/$profile2/ledgers/$profile2.journal" ]
  assert [ -f "$PROFILES_DIR/$profile3/ledgers/$profile3.journal" ]
  
  # Verify each has its own ledgers.yaml
  assert [ -f "$PROFILES_DIR/$profile1/ledgers.yaml" ]
  assert [ -f "$PROFILES_DIR/$profile2/ledgers.yaml" ]
  assert [ -f "$PROFILES_DIR/$profile3/ledgers.yaml" ]
  
  # Verify each ledgers.yaml points to its own ledger
  run grep "$profile1.journal" "$PROFILES_DIR/$profile1/ledgers.yaml"
  assert_success
  
  run grep "$profile2.journal" "$PROFILES_DIR/$profile2/ledgers.yaml"
  assert_success
  
  run grep "$profile3.journal" "$PROFILES_DIR/$profile3/ledgers.yaml"
  assert_success
}

@test "Property 24: Ledger file is valid hledger format" {
  # Feature: workwarrior-profiles-and-services, Property 24: Ledger System Initialization
  
  profile_name="test-ledger-valid"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create ledger configuration
  run create_ledger_config "$profile_name"
  assert_success
  
  # Verify ledger file has proper structure
  ledger_file="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  
  # Should have account declarations
  run grep "^account " "$ledger_file"
  assert_success
  
  # Should have a transaction with proper format (date, description, postings)
  run grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2} \*" "$ledger_file"
  assert_success
  
  # Should have indented postings (4 spaces)
  run grep "^    " "$ledger_file"
  assert_success
}
