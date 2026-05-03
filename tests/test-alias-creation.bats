#!/usr/bin/env bats
# Property 8: Complete Alias Creation
# Property 9: Alias Section Organization
# Property 10: Alias Idempotence
# Property 26: Ledger Alias Creation
# Feature: workwarrior-profiles-and-services

# Load test helpers
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Setup and teardown
setup() {
  # Create temporary test directory
  export TEST_WW_BASE="$BATS_TEST_TMPDIR/ww-test-$$"
  export PROFILES_DIR="$TEST_WW_BASE/profiles"
  export HOME="$BATS_TEST_TMPDIR/home-$$"
  mkdir -p "$PROFILES_DIR"
  mkdir -p "$HOME"
  
  # Create test .bashrc
  export SHELL_CONFIG="$HOME/.bashrc"
  touch "$SHELL_CONFIG"
  
  # Source the libraries
  export WW_BASE="$TEST_WW_BASE"
  source "$(dirname "$BATS_TEST_DIRNAME")/lib/core-utils.sh"
  source "$(dirname "$BATS_TEST_DIRNAME")/lib/profile-manager.sh"
  source "$(dirname "$BATS_TEST_DIRNAME")/lib/shell-integration.sh"
}

teardown() {
  # Clean up test directory
  if [[ -n "$TEST_WW_BASE" ]] && [[ -d "$TEST_WW_BASE" ]]; then
    rm -rf "$TEST_WW_BASE"
  fi
  if [[ -n "$HOME" ]] && [[ -d "$HOME" ]]; then
    rm -rf "$HOME"
  fi
}

# Helper function to generate random alphanumeric string
random_alphanumeric() {
  local length="$1"
  LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# ============================================================================
# Property 8: Complete Alias Creation Tests
# ============================================================================

@test "Property 8: p-<profile-name> alias is created" {
  # Feature: workwarrior-profiles-and-services, Property 8: Complete Alias Creation
  
  profile_name="test-profile"
  
  # Create profile with all configs
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  
  # Create aliases
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Verify p-<profile-name> alias exists
  run grep "^alias p-${profile_name}=" "$SHELL_CONFIG"
  assert_success
}

@test "Property 8: <profile-name> shorthand alias is created" {
  # Feature: workwarrior-profiles-and-services, Property 8: Complete Alias Creation
  
  profile_name="test-shorthand"
  
  # Create profile with all configs
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  
  # Create aliases
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Verify shorthand alias exists
  run grep "^alias ${profile_name}=" "$SHELL_CONFIG"
  assert_success
}

@test "Property 8: j-<profile-name> alias is created" {
  # Feature: workwarrior-profiles-and-services, Property 8: Complete Alias Creation
  
  profile_name="test-journal-alias"
  
  # Create profile with all configs
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  
  # Create aliases
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Verify j-<profile-name> alias exists
  run grep "^alias j-${profile_name}=" "$SHELL_CONFIG"
  assert_success
}

@test "Property 8: l-<profile-name> alias is created for default ledger" {
  # Feature: workwarrior-profiles-and-services, Property 8: Complete Alias Creation
  
  profile_name="test-ledger-alias"
  
  # Create profile with all configs
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  
  # Create aliases
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Verify l-<profile-name> alias exists
  run grep "^alias l-${profile_name}=" "$SHELL_CONFIG"
  assert_success
}

@test "Property 8: All four aliases created for profile (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 8: Complete Alias Creation
  
  for i in {1..10}; do
    profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile with all configs
    create_profile_directories "$profile_name"
    create_journal_config "$profile_name"
    create_ledger_config "$profile_name"
    
    # Create aliases
    run create_profile_aliases "$profile_name"
    assert_success
    
    # Verify all four aliases exist
    run grep -c "^alias p-${profile_name}=" "$SHELL_CONFIG"
    assert_success
    assert [ "$output" -eq 1 ]
    
    run grep -c "^alias ${profile_name}=" "$SHELL_CONFIG"
    assert_success
    assert [ "$output" -eq 1 ]
    
    run grep -c "^alias j-${profile_name}=" "$SHELL_CONFIG"
    assert_success
    assert [ "$output" -eq 1 ]
    
    run grep -c "^alias l-${profile_name}=" "$SHELL_CONFIG"
    assert_success
    assert [ "$output" -eq 1 ]
  done
}

# ============================================================================
# Property 9: Alias Section Organization Tests
# ============================================================================

@test "Property 9: Profile aliases appear after profile section marker" {
  # Feature: workwarrior-profiles-and-services, Property 9: Alias Section Organization
  
  profile_name="test-section"
  
  # Create profile with all configs
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  
  # Create aliases
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Verify section marker exists
  run grep "^# -- Workwarrior Profile Aliases ---$" "$SHELL_CONFIG"
  assert_success
  
  # Verify p-alias appears after section marker
  local marker_line=$(grep -n "^# -- Workwarrior Profile Aliases ---$" "$SHELL_CONFIG" | cut -d: -f1)
  local alias_line=$(grep -n "^alias p-${profile_name}=" "$SHELL_CONFIG" | cut -d: -f1)
  
  assert [ "$alias_line" -gt "$marker_line" ]
}

@test "Property 9: Journal aliases appear after journal section marker" {
  # Feature: workwarrior-profiles-and-services, Property 9: Alias Section Organization
  
  profile_name="test-journal-section"
  
  # Create profile with all configs
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  
  # Create aliases
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Verify section marker exists
  run grep "^# -- Direct Alias for Journals ---$" "$SHELL_CONFIG"
  assert_success
  
  # Verify j-alias appears after section marker
  local marker_line=$(grep -n "^# -- Direct Alias for Journals ---$" "$SHELL_CONFIG" | cut -d: -f1)
  local alias_line=$(grep -n "^alias j-${profile_name}=" "$SHELL_CONFIG" | cut -d: -f1)
  
  assert [ "$alias_line" -gt "$marker_line" ]
}

@test "Property 9: Ledger aliases appear after ledger section marker" {
  # Feature: workwarrior-profiles-and-services, Property 9: Alias Section Organization
  
  profile_name="test-ledger-section"
  
  # Create profile with all configs
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  
  # Create aliases
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Verify section marker exists
  run grep "^# -- Direct Aliases for Hledger ---$" "$SHELL_CONFIG"
  assert_success
  
  # Verify l-alias appears after section marker
  local marker_line=$(grep -n "^# -- Direct Aliases for Hledger ---$" "$SHELL_CONFIG" | cut -d: -f1)
  local alias_line=$(grep -n "^alias l-${profile_name}=" "$SHELL_CONFIG" | cut -d: -f1)
  
  assert [ "$alias_line" -gt "$marker_line" ]
}

# ============================================================================
# Property 10: Alias Idempotence Tests
# ============================================================================

@test "Property 10: Creating profile twice results in single alias" {
  # Feature: workwarrior-profiles-and-services, Property 10: Alias Idempotence
  
  profile_name="test-idempotent"
  
  # Create profile with all configs
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  
  # Create aliases first time
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Create aliases second time
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Verify each alias appears exactly once
  run grep -c "^alias p-${profile_name}=" "$SHELL_CONFIG"
  assert_success
  assert_equal "$output" "1"
  
  run grep -c "^alias ${profile_name}=" "$SHELL_CONFIG"
  assert_success
  assert_equal "$output" "1"
  
  run grep -c "^alias j-${profile_name}=" "$SHELL_CONFIG"
  assert_success
  assert_equal "$output" "1"
  
  run grep -c "^alias l-${profile_name}=" "$SHELL_CONFIG"
  assert_success
  assert_equal "$output" "1"
}

@test "Property 10: Multiple alias creation calls are idempotent (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 10: Alias Idempotence
  
  for i in {1..10}; do
    profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile with all configs
    create_profile_directories "$profile_name"
    create_journal_config "$profile_name"
    create_ledger_config "$profile_name"
    
    # Create aliases multiple times
    for j in {1..5}; do
      run create_profile_aliases "$profile_name"
      assert_success
    done
    
    # Verify each alias appears exactly once
    run grep -c "^alias p-${profile_name}=" "$SHELL_CONFIG"
    assert_success
    assert_equal "$output" "1"
    
    run grep -c "^alias ${profile_name}=" "$SHELL_CONFIG"
    assert_success
    assert_equal "$output" "1"
  done
}

# ============================================================================
# Property 26: Ledger Alias Creation Tests
# ============================================================================

@test "Property 26: Default ledger creates l-<profile-name> alias" {
  # Feature: workwarrior-profiles-and-services, Property 26: Ledger Alias Creation
  
  profile_name="test-default-ledger"
  
  # Create profile with ledger config
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  
  # Create aliases
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Verify l-<profile-name> alias exists
  run grep "^alias l-${profile_name}=" "$SHELL_CONFIG"
  assert_success
}

@test "Property 26: Ledger alias points to correct file" {
  # Feature: workwarrior-profiles-and-services, Property 26: Ledger Alias Creation
  
  profile_name="test-ledger-path"
  
  # Create profile with ledger config
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  
  # Create aliases
  run create_profile_aliases "$profile_name"
  assert_success
  
  # Verify alias points to correct ledger file
  expected_path="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
  run grep "alias l-${profile_name}='hledger -f ${expected_path}'" "$SHELL_CONFIG"
  assert_success
}

@test "Property 26: Multiple profiles have independent ledger aliases (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 26: Ledger Alias Creation
  
  for i in {1..10}; do
    profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile with ledger config
    create_profile_directories "$profile_name"
    create_journal_config "$profile_name"
    create_ledger_config "$profile_name"
    
    # Create aliases
    run create_profile_aliases "$profile_name"
    assert_success
    
    # Verify ledger alias exists
    run grep "^alias l-${profile_name}=" "$SHELL_CONFIG"
    assert_success
    
    # Verify alias points to correct file
    expected_path="$PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
    run grep "alias l-${profile_name}='hledger -f ${expected_path}'" "$SHELL_CONFIG"
    assert_success
  done
}

# ============================================================================
# Edge Cases
# ============================================================================

@test "Alias creation fails for non-existent profile" {
  profile_name="nonexistent"
  
  # Try to create aliases without creating profile
  run create_profile_aliases "$profile_name"
  assert_failure
}

@test "Alias removal works correctly" {
  profile_name="test-removal"
  
  # Create profile and aliases
  create_profile_directories "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
  create_profile_aliases "$profile_name"
  
  # Verify aliases exist
  run grep "^alias p-${profile_name}=" "$SHELL_CONFIG"
  assert_success
  
  # Remove aliases
  run remove_profile_aliases "$profile_name"
  assert_success
  
  # Verify aliases are gone
  run grep "^alias p-${profile_name}=" "$SHELL_CONFIG"
  assert_failure
  
  run grep "^alias j-${profile_name}=" "$SHELL_CONFIG"
  assert_failure
  
  run grep "^alias l-${profile_name}=" "$SHELL_CONFIG"
  assert_failure
}
