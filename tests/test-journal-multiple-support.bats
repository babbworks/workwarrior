#!/usr/bin/env bats
# Feature: workwarrior-profiles-and-services
# Property 20: Multiple Journals Support
# Tests for multiple named journal entries in jrnl.yaml

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
  TEST_PROFILE="test-multi-j-$(date +%s)-$$"
}

teardown() {
  # Clean up test profile
  if [[ -d "$PROFILES_DIR/$TEST_PROFILE" ]]; then
    rm -rf "$PROFILES_DIR/$TEST_PROFILE"
  fi
}

# ============================================================================
# Property 20: Multiple Journals Support Tests
# ============================================================================

@test "Property 20: jrnl.yaml supports multiple journal entries" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add multiple journals
  run add_journal_to_profile "$TEST_PROFILE" "work-log"
  assert_success
  
  run add_journal_to_profile "$TEST_PROFILE" "personal"
  assert_success
  
  # Verify all journals are in config
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  default:" "$jrnl_config"
  assert_success
  run grep "^  work-log:" "$jrnl_config"
  assert_success
  run grep "^  personal:" "$jrnl_config"
  assert_success
}

@test "Property 20: Each journal maps to absolute file path" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journals
  add_journal_to_profile "$TEST_PROFILE" "work-log"
  add_journal_to_profile "$TEST_PROFILE" "personal"
  
  # Verify absolute paths
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  default: /" "$jrnl_config"
  assert_success
  run grep "^  work-log: /" "$jrnl_config"
  assert_success
  run grep "^  personal: /" "$jrnl_config"
  assert_success
}

@test "Property 20: Journal names are unique within profile" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal
  run add_journal_to_profile "$TEST_PROFILE" "work-log"
  assert_success
  
  # Try to add same journal again
  run add_journal_to_profile "$TEST_PROFILE" "work-log"
  assert_failure
  assert_output --partial "already exists"
}

@test "Property 20: Multiple journals have separate files" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journals
  add_journal_to_profile "$TEST_PROFILE" "work-log"
  add_journal_to_profile "$TEST_PROFILE" "personal"
  
  # Verify separate files exist
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/$TEST_PROFILE.txt" ]
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/work-log.txt" ]
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/personal.txt" ]
}

@test "Property 20: Can add many journals to one profile" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add 5 journals
  for i in {1..5}; do
    run add_journal_to_profile "$TEST_PROFILE" "journal-$i"
    assert_success
  done
  
  # Verify all are in config
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  for i in {1..5}; do
    run grep "^  journal-$i:" "$jrnl_config"
    assert_success
  done
}

@test "Property 20: Journal names with hyphens are supported" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal with hyphens
  run add_journal_to_profile "$TEST_PROFILE" "work-log-2024"
  assert_success
  
  # Verify in config
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  work-log-2024:" "$jrnl_config"
  assert_success
}

@test "Property 20: Journal names with underscores are supported" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal with underscores
  run add_journal_to_profile "$TEST_PROFILE" "work_log_2024"
  assert_success
  
  # Verify in config
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  work_log_2024:" "$jrnl_config"
  assert_success
}

@test "Property 20: Journal names with numbers are supported" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal with numbers
  run add_journal_to_profile "$TEST_PROFILE" "log2024"
  assert_success
  
  # Verify in config
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  log2024:" "$jrnl_config"
  assert_success
}

# ============================================================================
# Property 20: Random Journal Names (10 iterations)
# ============================================================================

@test "Property 20: Random valid journal names are supported (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  for i in {1..10}; do
    # Generate random valid journal name
    local journal_name="j-$(head /dev/urandom | tr -dc 'a-z0-9-' | head -c 8)"
    
    # Add journal
    run add_journal_to_profile "$TEST_PROFILE" "$journal_name"
    assert_success
    
    # Verify in config
    local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
    run grep "^  $journal_name:" "$jrnl_config"
    assert_success
    
    # Verify file exists
    assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/$journal_name.txt" ]
  done
}

# ============================================================================
# Property 20: Copy Journal Configuration
# ============================================================================

@test "Property 20: Copying journal config preserves multiple journals" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create source profile
  local source_profile="test-source-$(date +%s)"
  create_profile_directories "$source_profile"
  create_journal_config "$source_profile"
  
  # Add multiple journals to source
  add_journal_to_profile "$source_profile" "work-log"
  add_journal_to_profile "$source_profile" "personal"
  
  # Create destination profile
  local dest_profile="test-dest-$(date +%s)"
  create_profile_directories "$dest_profile"
  
  # Copy journal config
  run copy_journal_from_profile "$source_profile" "$dest_profile"
  assert_success
  
  # Verify all journals are in destination config
  local dest_config="$PROFILES_DIR/$dest_profile/jrnl.yaml"
  run grep "^  default:" "$dest_config"
  assert_success
  run grep "^  work-log:" "$dest_config"
  assert_success
  run grep "^  personal:" "$dest_config"
  assert_success
  
  # Verify paths point to destination profile
  run grep "$dest_profile" "$dest_config"
  assert_success
  
  # Clean up
  rm -rf "$PROFILES_DIR/$source_profile"
  rm -rf "$PROFILES_DIR/$dest_profile"
}

@test "Property 20: Copied journals have updated paths" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create source profile
  local source_profile="test-source-$(date +%s)"
  create_profile_directories "$source_profile"
  create_journal_config "$source_profile"
  add_journal_to_profile "$source_profile" "work-log"
  
  # Create destination profile
  local dest_profile="test-dest-$(date +%s)"
  create_profile_directories "$dest_profile"
  
  # Copy journal config
  copy_journal_from_profile "$source_profile" "$dest_profile"
  
  # Verify paths don't contain source profile name
  local dest_config="$PROFILES_DIR/$dest_profile/jrnl.yaml"
  run grep "$source_profile" "$dest_config"
  assert_failure
  
  # Verify paths contain destination profile name
  run grep "$dest_profile" "$dest_config"
  assert_success
  
  # Clean up
  rm -rf "$PROFILES_DIR/$source_profile"
  rm -rf "$PROFILES_DIR/$dest_profile"
}

# ============================================================================
# Property 20: Error Handling
# ============================================================================

@test "Property 20: Invalid journal names are rejected" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Try invalid characters
  run add_journal_to_profile "$TEST_PROFILE" "invalid@journal"
  assert_failure
  
  run add_journal_to_profile "$TEST_PROFILE" "invalid journal"
  assert_failure
  
  run add_journal_to_profile "$TEST_PROFILE" "invalid/journal"
  assert_failure
}

@test "Property 20: Empty journal name is rejected" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Try empty name
  run add_journal_to_profile "$TEST_PROFILE" ""
  assert_failure
}

@test "Property 20: Adding journal to non-existent profile fails" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Try to add journal to non-existent profile
  run add_journal_to_profile "nonexistent-profile" "work-log"
  assert_failure
}

@test "Property 20: Adding journal without jrnl.yaml fails" {
  # Feature: workwarrior-profiles-and-services, Property 20: Multiple Journals Support
  
  # Create profile directories but not journal config
  create_profile_directories "$TEST_PROFILE"
  
  # Try to add journal
  run add_journal_to_profile "$TEST_PROFILE" "work-log"
  assert_failure
}
