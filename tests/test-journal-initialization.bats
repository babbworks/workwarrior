#!/usr/bin/env bats
# Feature: workwarrior-profiles-and-services
# Property 19: Journal System Initialization
# Tests for journal configuration creation and initialization

# Load test helpers
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Setup and teardown
setup() {
  # Source the libraries
  export WW_BASE="${BATS_TEST_TMPDIR}/ww"
  export PROFILES_DIR="$WW_BASE/profiles"
  export CONFIG_TEMPLATES_DIR="$WW_BASE/resources/config-files"
  export DEFAULT_TASKRC="$WW_BASE/functions/tasks/default-taskrc/.taskrc"
  
  # Create necessary directories
  mkdir -p "$PROFILES_DIR"
  mkdir -p "$CONFIG_TEMPLATES_DIR"
  mkdir -p "$(dirname "$DEFAULT_TASKRC")"
  
  # Source the libraries
  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
  source "${BATS_TEST_DIRNAME}/../lib/profile-manager.sh"
  
  # Generate unique test profile name
  TEST_PROFILE="test-journal-$(date +%s)-$$"
}

teardown() {
  # Clean up test profile
  if [[ -d "$PROFILES_DIR/$TEST_PROFILE" ]]; then
    rm -rf "$PROFILES_DIR/$TEST_PROFILE"
  fi
}

# ============================================================================
# Property 19: Journal System Initialization Tests
# ============================================================================

@test "Property 19: Default journal file is created" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify default journal file exists
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/$TEST_PROFILE.txt" ]
}

@test "Property 19: Default journal has welcome entry" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify welcome entry exists
  local journal_file="$PROFILES_DIR/$TEST_PROFILE/journals/$TEST_PROFILE.txt"
  assert [ -f "$journal_file" ]
  run cat "$journal_file"
  assert_output --partial "Welcome"
}

@test "Property 19: Default journal has timestamp" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify timestamp format [YYYY-MM-DD HH:MM]
  local journal_file="$PROFILES_DIR/$TEST_PROFILE/journals/$TEST_PROFILE.txt"
  assert [ -f "$journal_file" ]
  run grep -E '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}\]' "$journal_file"
  assert_success
}

@test "Property 19: jrnl.yaml is created" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify jrnl.yaml exists
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml" ]
}

@test "Property 19: jrnl.yaml has default journal configured" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify default journal is configured
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  assert [ -f "$jrnl_config" ]
  run grep "^journals:" "$jrnl_config"
  assert_success
  run grep "^  default:" "$jrnl_config"
  assert_success
}

@test "Property 19: jrnl.yaml has editor setting" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify editor setting
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^editor:" "$jrnl_config"
  assert_success
}

@test "Property 19: jrnl.yaml has timeformat setting" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify timeformat setting
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^timeformat:" "$jrnl_config"
  assert_success
}

@test "Property 19: jrnl.yaml has encryption setting" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify encryption setting
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^encrypt:" "$jrnl_config"
  assert_success
}

@test "Property 19: jrnl.yaml has display options (highlight, linewrap)" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify display options
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^highlight:" "$jrnl_config"
  assert_success
  run grep "^linewrap:" "$jrnl_config"
  assert_success
}

@test "Property 19: jrnl.yaml has colors section" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify colors section
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^colors:" "$jrnl_config"
  assert_success
}

@test "Property 19: Default journal path is absolute" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify absolute path
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  default: /" "$jrnl_config"
  assert_success
}

# ============================================================================
# Property 19: Random Profile Names (10 iterations)
# ============================================================================

@test "Property 19: Random valid profile names create journal config (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  for i in {1..10}; do
    # Generate random valid profile name
    local profile_name="test-j-$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 8)"
    
    # Create profile directories
    create_profile_directories "$profile_name"
    
    # Create journal config
    run create_journal_config "$profile_name"
    assert_success
    
    # Verify journal file and config exist
    assert [ -f "$PROFILES_DIR/$profile_name/journals/$profile_name.txt" ]
    assert [ -f "$PROFILES_DIR/$profile_name/jrnl.yaml" ]
    
    # Verify welcome entry
    run grep "Welcome" "$PROFILES_DIR/$profile_name/journals/$profile_name.txt"
    assert_success
    
    # Verify default journal in config
    run grep "^  default:" "$PROFILES_DIR/$profile_name/jrnl.yaml"
    assert_success
    
    # Clean up
    rm -rf "$PROFILES_DIR/$profile_name"
  done
}

# ============================================================================
# Property 19: Edge Cases
# ============================================================================

@test "Property 19: Profile names with hyphens create correct journal paths" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  local profile_name="test-with-hyphens"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create journal config
  run create_journal_config "$profile_name"
  assert_success
  
  # Verify paths
  assert [ -f "$PROFILES_DIR/$profile_name/journals/$profile_name.txt" ]
  assert [ -f "$PROFILES_DIR/$profile_name/jrnl.yaml" ]
  
  # Clean up
  rm -rf "$PROFILES_DIR/$profile_name"
}

@test "Property 19: Profile names with underscores create correct journal paths" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  local profile_name="test_with_underscores"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create journal config
  run create_journal_config "$profile_name"
  assert_success
  
  # Verify paths
  assert [ -f "$PROFILES_DIR/$profile_name/journals/$profile_name.txt" ]
  assert [ -f "$PROFILES_DIR/$profile_name/jrnl.yaml" ]
  
  # Clean up
  rm -rf "$PROFILES_DIR/$profile_name"
}

@test "Property 19: Numeric profile names create correct journal paths" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  local profile_name="12345"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create journal config
  run create_journal_config "$profile_name"
  assert_success
  
  # Verify paths
  assert [ -f "$PROFILES_DIR/$profile_name/journals/$profile_name.txt" ]
  assert [ -f "$PROFILES_DIR/$profile_name/jrnl.yaml" ]
  
  # Clean up
  rm -rf "$PROFILES_DIR/$profile_name"
}

@test "Property 19: Single character profile names create correct journal paths" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  local profile_name="x"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create journal config
  run create_journal_config "$profile_name"
  assert_success
  
  # Verify paths
  assert [ -f "$PROFILES_DIR/$profile_name/journals/$profile_name.txt" ]
  assert [ -f "$PROFILES_DIR/$profile_name/jrnl.yaml" ]
  
  # Clean up
  rm -rf "$PROFILES_DIR/$profile_name"
}

@test "Property 19: Maximum length profile names (50 chars) create correct journal paths" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  local profile_name="test12345678901234567890123456789012345678901234"
  
  # Create profile directories
  create_profile_directories "$profile_name"
  
  # Create journal config
  run create_journal_config "$profile_name"
  assert_success
  
  # Verify paths
  assert [ -f "$PROFILES_DIR/$profile_name/journals/$profile_name.txt" ]
  assert [ -f "$PROFILES_DIR/$profile_name/jrnl.yaml" ]
  
  # Clean up
  rm -rf "$PROFILES_DIR/$profile_name"
}

# ============================================================================
# Property 19: Error Handling
# ============================================================================

@test "Property 19: Fails gracefully for non-existent profile" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  local profile_name="nonexistent-profile"
  
  # Try to create journal config without creating profile first
  run create_journal_config "$profile_name"
  assert_failure
}

@test "Property 19: Fails gracefully for invalid profile name" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Try with invalid characters
  run create_journal_config "invalid@profile"
  assert_failure
}

@test "Property 19: Idempotent - can be called multiple times" {
  # Feature: workwarrior-profiles-and-services, Property 19: Journal System Initialization
  
  # Create profile directories
  create_profile_directories "$TEST_PROFILE"
  
  # Create journal config first time
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Create journal config second time (should succeed and overwrite)
  run create_journal_config "$TEST_PROFILE"
  assert_success
  
  # Verify files still exist
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/$TEST_PROFILE.txt" ]
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml" ]
}
