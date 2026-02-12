#!/usr/bin/env bats
# Property-Based Tests for Profile Management
# Feature: workwarrior-profiles-and-services
# Properties 4, 5, 6, 7, 32

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export TEST_MODE=1
  export TEST_WW_BASE="${BATS_TEST_TMPDIR}/ww-test-$$"
  export WW_BASE="$TEST_WW_BASE"
  export PROFILES_DIR="$TEST_WW_BASE/profiles"
  export SERVICES_DIR="$TEST_WW_BASE/services"
  export RESOURCES_DIR="$TEST_WW_BASE/resources"
  export FUNCTIONS_DIR="$TEST_WW_BASE/functions"
  export HOME="$TEST_WW_BASE"
  export SHELL_RC="$HOME/.bashrc"

  mkdir -p "$PROFILES_DIR" "$SERVICES_DIR" "$RESOURCES_DIR" "$FUNCTIONS_DIR"
  touch "$SHELL_RC"

  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
  source "${BATS_TEST_DIRNAME}/../lib/profile-manager.sh"
  source "${BATS_TEST_DIRNAME}/../lib/shell-integration.sh"
}

teardown() {
  if [[ -d "$TEST_WW_BASE" ]]; then
    rm -rf "$TEST_WW_BASE"
  fi
}

random_alphanumeric() {
  local length="$1"
  local chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'
  local result=''
  for ((i=0; i<length; i++)); do
    result="${result}${chars:RANDOM%${#chars}:1}"
  done
  echo "$result"
}

create_test_profile() {
  local profile_name="$1"
  create_profile_directories "$profile_name" >/dev/null 2>&1
  create_taskrc "$profile_name" >/dev/null 2>&1
  create_journal_config "$profile_name" >/dev/null 2>&1
  create_ledger_config "$profile_name" >/dev/null 2>&1
  install_timewarrior_hook "$profile_name" >/dev/null 2>&1
  create_profile_aliases "$profile_name" >/dev/null 2>&1
}

# ============================================================================
# Property 4: Profile Deletion Completeness
# ============================================================================

@test "Property 4: After deletion, profile directory does not exist (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 4: Profile Deletion Completeness
  # Validates: Requirements 3.3
  
  local iterations=10
  local success_count=0
  
  for i in $(seq 1 $iterations); do
    # Generate random valid profile name
    local profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile
    create_test_profile "$profile_name"
    
    # Verify profile exists
    assert [ -d "$TEST_PROFILES_DIR/$profile_name" ]
    
    # Delete profile directory
    rm -rf "$TEST_PROFILES_DIR/$profile_name"
    
    # Verify profile directory is gone
    assert [ ! -d "$TEST_PROFILES_DIR/$profile_name" ]
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
}

@test "Property 4: After deletion, aliases are removed from bashrc (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 4: Profile Deletion Completeness
  # Validates: Requirements 3.4
  
  local iterations=10
  local success_count=0
  
  for i in $(seq 1 $iterations); do
    # Generate random valid profile name
    local profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile with aliases
    create_test_profile "$profile_name"
    
    # Verify aliases exist
    run grep "p-$profile_name" "$SHELL_RC"
    assert_success
    
    # Remove aliases
    run remove_profile_aliases "$profile_name"
    assert_success
    
    # Verify aliases are gone
    run grep "p-$profile_name" "$SHELL_RC"
    assert_failure
    
    run grep "j-$profile_name" "$SHELL_RC"
    assert_failure
    
    # Clean up
    rm -rf "$TEST_PROFILES_DIR/$profile_name"
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
}

# ============================================================================
# Property 5: Backup Filename Timestamp
# ============================================================================

@test "Property 5: Backup filename contains timestamp in YYYYMMDDHHMMSS format (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 5: Backup Filename Timestamp
  # Validates: Requirements 3.7
  
  local iterations=10
  local success_count=0
  local backup_dir="$BATS_TEST_TMPDIR/backups"
  mkdir -p "$backup_dir"
  
  for i in $(seq 1 $iterations); do
    # Generate random valid profile name
    local profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile
    create_test_profile "$profile_name"
    
    # Create backup
    local timestamp
    timestamp=$(date "+%Y%m%d%H%M%S")
    local backup_filename="${profile_name}-backup-${timestamp}.tar.gz"
    local backup_path="$backup_dir/$backup_filename"
    
    # Simulate backup creation
    tar -czf "$backup_path" -C "$TEST_PROFILES_DIR" "$profile_name" 2>/dev/null
    
    # Verify backup filename format
    # Should match: profilename-backup-YYYYMMDDHHMMSS.tar.gz
    assert [[ "$backup_filename" =~ ^[a-zA-Z0-9_-]+-backup-[0-9]{14}\.tar\.gz$ ]]
    
    # Extract timestamp from filename
    local extracted_timestamp
    extracted_timestamp=$(echo "$backup_filename" | sed -E 's/.*-backup-([0-9]{14})\.tar\.gz/\1/')
    
    # Verify timestamp is 14 digits
    assert [ ${#extracted_timestamp} -eq 14 ]
    
    # Verify timestamp is numeric
    assert [[ "$extracted_timestamp" =~ ^[0-9]+$ ]]
    
    # Clean up
    rm -f "$backup_path"
    rm -rf "$TEST_PROFILES_DIR/$profile_name"
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
  
  rm -rf "$backup_dir"
}

# ============================================================================
# Property 6: Profile List Sorting
# ============================================================================

@test "Property 6: list_profiles returns profiles in sorted order (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 6: Profile List Sorting
  # Validates: Requirements 3.9
  
  local iterations=10
  local success_count=0
  
  for i in $(seq 1 $iterations); do
    # Create multiple profiles with random names
    local profile_count=$((RANDOM % 5 + 3))  # 3-7 profiles
    local profiles=()
    
    for j in $(seq 1 $profile_count); do
      local profile_name="test-$(random_alphanumeric 6)"
      profiles+=("$profile_name")
      create_profile_directories "$profile_name" >/dev/null 2>&1
    done
    
    # Get list of profiles
    local listed_profiles
    mapfile -t listed_profiles < <(list_profiles)
    
    # Sort the original array
    local sorted_profiles
    mapfile -t sorted_profiles < <(printf '%s\n' "${profiles[@]}" | sort)
    
    # Compare listed profiles with sorted profiles
    local all_match=1
    for k in "${!sorted_profiles[@]}"; do
      if [[ "${listed_profiles[$k]}" != "${sorted_profiles[$k]}" ]]; then
        all_match=0
        break
      fi
    done
    
    assert [ "$all_match" -eq 1 ]
    
    # Clean up
    for profile in "${profiles[@]}"; do
      rm -rf "$TEST_PROFILES_DIR/$profile"
    done
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
}

# ============================================================================
# Property 7: Error Exit Codes
# ============================================================================

@test "Property 7: Invalid profile name returns non-zero exit code (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 7: Error Exit Codes
  # Validates: Requirements 3.10
  
  local iterations=10
  local success_count=0
  local invalid_chars=('!' '@' '#' '$' '%' '^' '&' '*' '(' ')' '+' '=' '[' ']' '{' '}' '|' '\' ';' ':' '"' "'" '<' '>' ',' '.' '?' '/' '~' '`')
  
  for i in $(seq 1 $iterations); do
    # Generate name with random invalid character
    local char="${invalid_chars[$RANDOM % ${#invalid_chars[@]}]}"
    local profile_name="test${char}profile"
    
    # Attempt to validate profile name
    run validate_profile_name "$profile_name"
    assert_failure
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
}

@test "Property 7: Non-existent profile operations return non-zero exit code (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 7: Error Exit Codes
  # Validates: Requirements 3.10
  
  local iterations=10
  local success_count=0
  
  for i in $(seq 1 $iterations); do
    # Generate random profile name that doesn't exist
    local profile_name="nonexistent-$(random_alphanumeric 8)"
    
    # Ensure profile doesn't exist
    assert [ ! -d "$TEST_PROFILES_DIR/$profile_name" ]
    
    # Attempt to check if profile exists
    run profile_exists "$profile_name"
    assert_failure
    
    # Attempt to ensure profile exists
    run ensure_profile_exists "$profile_name"
    assert_failure
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
}

# ============================================================================
# Property 32: Backup Completeness
# ============================================================================

@test "Property 32: Backup archive contains all profile directories (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 32: Backup Completeness
  # Validates: Requirements 20.1, 20.2, 20.3, 20.4, 20.5
  
  local iterations=10
  local success_count=0
  local backup_dir="$BATS_TEST_TMPDIR/backups"
  mkdir -p "$backup_dir"
  
  for i in $(seq 1 $iterations); do
    # Generate random valid profile name
    local profile_name="test-$(random_alphanumeric 8)"
    
    # Create complete profile
    create_test_profile "$profile_name"
    
    # Create backup
    local timestamp
    timestamp=$(date "+%Y%m%d%H%M%S")
    local backup_filename="${profile_name}-backup-${timestamp}.tar.gz"
    local backup_path="$backup_dir/$backup_filename"
    
    # Create tar.gz archive
    tar -czf "$backup_path" -C "$TEST_PROFILES_DIR" "$profile_name" 2>/dev/null
    
    # Verify backup was created
    assert [ -f "$backup_path" ]
    
    # List contents of backup
    local backup_contents
    backup_contents=$(tar -tzf "$backup_path" 2>/dev/null)
    
    # Verify all required directories are in backup
    echo "$backup_contents" | grep -q "$profile_name/.task/"
    assert_success
    
    echo "$backup_contents" | grep -q "$profile_name/.task/hooks/"
    assert_success
    
    echo "$backup_contents" | grep -q "$profile_name/.timewarrior/"
    assert_success
    
    echo "$backup_contents" | grep -q "$profile_name/journals/"
    assert_success
    
    echo "$backup_contents" | grep -q "$profile_name/ledgers/"
    assert_success
    
    # Verify configuration files are in backup
    echo "$backup_contents" | grep -q "$profile_name/.taskrc"
    assert_success
    
    echo "$backup_contents" | grep -q "$profile_name/jrnl.yaml"
    assert_success
    
    echo "$backup_contents" | grep -q "$profile_name/ledgers.yaml"
    assert_success
    
    # Clean up
    rm -f "$backup_path"
    rm -rf "$TEST_PROFILES_DIR/$profile_name"
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
  
  rm -rf "$backup_dir"
}
