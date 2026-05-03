#!/usr/bin/env bats
# Feature: workwarrior-profiles-and-services
# Property 23: Journal Addition
# Tests for adding new journals to existing profiles

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
  TEST_PROFILE="test-add-j-$(date +%s)-$$"
}

teardown() {
  # Clean up test profile
  if [[ -d "$PROFILES_DIR/$TEST_PROFILE" ]]; then
    rm -rf "$PROFILES_DIR/$TEST_PROFILE"
  fi
}

# ============================================================================
# Property 23: Journal Addition Tests
# ============================================================================

@test "Property 23: Adding journal creates journal file" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal
  run add_journal_to_profile "$TEST_PROFILE" "work-log"
  assert_success
  
  # Verify journal file exists
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/work-log.txt" ]
}

@test "Property 23: Adding journal updates jrnl.yaml" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal
  run add_journal_to_profile "$TEST_PROFILE" "work-log"
  assert_success
  
  # Verify jrnl.yaml updated
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  work-log:" "$jrnl_config"
  assert_success
}

@test "Property 23: New journal file has welcome entry" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal
  add_journal_to_profile "$TEST_PROFILE" "work-log"
  
  # Verify welcome entry
  local journal_file="$PROFILES_DIR/$TEST_PROFILE/journals/work-log.txt"
  run grep "Welcome" "$journal_file"
  assert_success
}

@test "Property 23: New journal file has timestamp" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal
  add_journal_to_profile "$TEST_PROFILE" "work-log"
  
  # Verify timestamp format [YYYY-MM-DD HH:MM]
  local journal_file="$PROFILES_DIR/$TEST_PROFILE/journals/work-log.txt"
  run grep -E '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}\]' "$journal_file"
  assert_success
}

@test "Property 23: Journal entry in config has absolute path" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal
  add_journal_to_profile "$TEST_PROFILE" "work-log"
  
  # Verify absolute path
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  work-log: /" "$jrnl_config"
  assert_success
}

@test "Property 23: Can add multiple journals sequentially" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add multiple journals
  run add_journal_to_profile "$TEST_PROFILE" "work-log"
  assert_success
  
  run add_journal_to_profile "$TEST_PROFILE" "personal"
  assert_success
  
  run add_journal_to_profile "$TEST_PROFILE" "ideas"
  assert_success
  
  # Verify all exist
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/work-log.txt" ]
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/personal.txt" ]
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/ideas.txt" ]
  
  # Verify all in config
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  work-log:" "$jrnl_config"
  assert_success
  run grep "^  personal:" "$jrnl_config"
  assert_success
  run grep "^  ideas:" "$jrnl_config"
  assert_success
}

@test "Property 23: Adding journal preserves existing journals" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add first journal
  add_journal_to_profile "$TEST_PROFILE" "work-log"
  
  # Add second journal
  add_journal_to_profile "$TEST_PROFILE" "personal"
  
  # Verify both exist in config
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  work-log:" "$jrnl_config"
  assert_success
  run grep "^  personal:" "$jrnl_config"
  assert_success
  
  # Verify default journal still exists
  run grep "^  default:" "$jrnl_config"
  assert_success
}

@test "Property 23: Adding journal preserves config settings" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal
  add_journal_to_profile "$TEST_PROFILE" "work-log"
  
  # Verify config settings preserved
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^editor:" "$jrnl_config"
  assert_success
  run grep "^timeformat:" "$jrnl_config"
  assert_success
  run grep "^encrypt:" "$jrnl_config"
  assert_success
  run grep "^colors:" "$jrnl_config"
  assert_success
}

# ============================================================================
# Property 23: Random Journal Names (10 iterations)
# ============================================================================

@test "Property 23: Random valid journal names can be added (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  for i in {1..10}; do
    # Generate random valid journal name
    local journal_name="j-$(head /dev/urandom | tr -dc 'a-z0-9-' | head -c 8)"
    
    # Add journal
    run add_journal_to_profile "$TEST_PROFILE" "$journal_name"
    assert_success
    
    # Verify file created
    assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/$journal_name.txt" ]
    
    # Verify in config
    local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
    run grep "^  $journal_name:" "$jrnl_config"
    assert_success
  done
}

# ============================================================================
# Property 23: Edge Cases
# ============================================================================

@test "Property 23: Journal names with hyphens work correctly" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal with hyphens
  run add_journal_to_profile "$TEST_PROFILE" "work-log-2024"
  assert_success
  
  # Verify
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/work-log-2024.txt" ]
  
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  work-log-2024:" "$jrnl_config"
  assert_success
}

@test "Property 23: Journal names with underscores work correctly" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal with underscores
  run add_journal_to_profile "$TEST_PROFILE" "work_log_2024"
  assert_success
  
  # Verify
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/work_log_2024.txt" ]
  
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  work_log_2024:" "$jrnl_config"
  assert_success
}

@test "Property 23: Journal names with numbers work correctly" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add journal with numbers
  run add_journal_to_profile "$TEST_PROFILE" "log2024"
  assert_success
  
  # Verify
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/log2024.txt" ]
  
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  log2024:" "$jrnl_config"
  assert_success
}

@test "Property 23: Single character journal names work" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Add single character journal
  run add_journal_to_profile "$TEST_PROFILE" "x"
  assert_success
  
  # Verify
  assert [ -f "$PROFILES_DIR/$TEST_PROFILE/journals/x.txt" ]
  
  local jrnl_config="$PROFILES_DIR/$TEST_PROFILE/jrnl.yaml"
  run grep "^  x:" "$jrnl_config"
  assert_success
}

# ============================================================================
# Property 23: Error Handling
# ============================================================================

@test "Property 23: Cannot add duplicate journal name" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
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

@test "Property 23: Invalid journal names are rejected" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
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

@test "Property 23: Empty journal name is rejected" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile and journal config
  create_profile_directories "$TEST_PROFILE"
  create_journal_config "$TEST_PROFILE"
  
  # Try empty name
  run add_journal_to_profile "$TEST_PROFILE" ""
  assert_failure
}

@test "Property 23: Adding to non-existent profile fails" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Try to add journal to non-existent profile
  run add_journal_to_profile "nonexistent-profile" "work-log"
  assert_failure
}

@test "Property 23: Adding without jrnl.yaml fails" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create profile directories but not journal config
  create_profile_directories "$TEST_PROFILE"
  
  # Try to add journal
  run add_journal_to_profile "$TEST_PROFILE" "work-log"
  assert_failure
}

@test "Property 23: Invalid profile name is rejected" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Try with invalid profile name
  run add_journal_to_profile "invalid@profile" "work-log"
  assert_failure
}

# ============================================================================
# Property 23: Integration Tests
# ============================================================================

@test "Property 23: Added journals work across multiple profiles" {
  # Feature: workwarrior-profiles-and-services, Property 23: Journal Addition
  
  # Create two profiles
  local profile1="test-p1-$(date +%s)"
  local profile2="test-p2-$(date +%s)"
  
  create_profile_directories "$profile1"
  create_journal_config "$profile1"
  
  create_profile_directories "$profile2"
  create_journal_config "$profile2"
  
  # Add same journal name to both profiles
  add_journal_to_profile "$profile1" "work-log"
  add_journal_to_profile "$profile2" "work-log"
  
  # Verify both exist independently
  assert [ -f "$PROFILES_DIR/$profile1/journals/work-log.txt" ]
  assert [ -f "$PROFILES_DIR/$profile2/journals/work-log.txt" ]
  
  # Verify configs are independent
  local config1="$PROFILES_DIR/$profile1/jrnl.yaml"
  local config2="$PROFILES_DIR/$profile2/jrnl.yaml"
  
  run grep "$profile1" "$config1"
  assert_success
  run grep "$profile2" "$config1"
  assert_failure
  
  run grep "$profile2" "$config2"
  assert_success
  run grep "$profile1" "$config2"
  assert_failure
  
  # Clean up
  rm -rf "$PROFILES_DIR/$profile1"
  rm -rf "$PROFILES_DIR/$profile2"
}
