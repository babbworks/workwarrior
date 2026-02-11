#!/usr/bin/env bats
# Property-Based Tests for Default Configuration Initialization
# Feature: workwarrior-profiles-and-services
# Property 3: Default Configuration Initialization
# Validates: Requirements 2.9, 2.10

# Load test helpers
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

# Source the libraries
setup() {
  export TEST_MODE=1
  export TEST_PROFILES_DIR="$BATS_TEST_TMPDIR/profiles"
  export WW_BASE="$BATS_TEST_TMPDIR/ww"
  export PROFILES_DIR="$TEST_PROFILES_DIR"
  export SERVICES_DIR="$WW_BASE/services"
  export RESOURCES_DIR="$WW_BASE/resources"
  export FUNCTIONS_DIR="$WW_BASE/functions"
  export SHELL_RC="$BATS_TEST_TMPDIR/.bashrc"
  
  # Create base directories
  mkdir -p "$TEST_PROFILES_DIR"
  mkdir -p "$SERVICES_DIR"
  mkdir -p "$RESOURCES_DIR"
  mkdir -p "$FUNCTIONS_DIR"
  touch "$SHELL_RC"
  
  # Source libraries
  source "$(pwd)/lib/core-utils.sh"
  source "$(pwd)/lib/profile-manager.sh"
  source "$(pwd)/lib/shell-integration.sh"
}

teardown() {
  # Clean up test directories
  rm -rf "$BATS_TEST_TMPDIR/profiles"
  rm -rf "$BATS_TEST_TMPDIR/ww"
  rm -f "$BATS_TEST_TMPDIR/.bashrc"
}

# Helper function to generate random alphanumeric string
random_alphanumeric() {
  local length="$1"
  LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Helper function to check if file contains text
file_contains() {
  local file="$1"
  local text="$2"
  grep -q "$text" "$file"
}

# ============================================================================
# Property 3: Default Configuration Initialization
# ============================================================================

@test "Property 3: Default configuration files are created with valid content (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 3: Default Configuration Initialization
  # Validates: Requirements 2.9, 2.10
  
  local iterations=10
  local success_count=0
  
  for i in $(seq 1 $iterations); do
    # Generate random valid profile name
    local profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile directories
    run create_profile_directories "$profile_name"
    assert_success
    
    # Create default TaskRC
    run create_taskrc "$profile_name"
    assert_success
    
    # Verify .taskrc exists and has required settings
    local taskrc="$TEST_PROFILES_DIR/$profile_name/.taskrc"
    assert [ -f "$taskrc" ]
    
    # Check data.location is set
    run grep "^data\.location=" "$taskrc"
    assert_success
    
    # Check hooks.location is set
    run grep "^hooks\.location=" "$taskrc"
    assert_success
    
    # Check hooks are enabled
    run grep "^hooks=" "$taskrc"
    assert_success
    
    # Create default journal configuration
    run create_journal_config "$profile_name"
    assert_success
    
    # Verify jrnl.yaml exists
    local jrnl_config="$TEST_PROFILES_DIR/$profile_name/jrnl.yaml"
    assert [ -f "$jrnl_config" ]
    
    # Check journals section exists
    run grep "^journals:" "$jrnl_config"
    assert_success
    
    # Check default journal is configured
    run grep "^  default:" "$jrnl_config"
    assert_success
    
    # Check editor is set
    run grep "^editor:" "$jrnl_config"
    assert_success
    
    # Check timeformat is set
    run grep "^timeformat:" "$jrnl_config"
    assert_success
    
    # Verify default journal file exists
    local default_journal="$TEST_PROFILES_DIR/$profile_name/journals/$profile_name.txt"
    assert [ -f "$default_journal" ]
    
    # Check journal has welcome entry
    run file_contains "$default_journal" "Welcome"
    assert_success
    
    # Check journal has timestamp
    run file_contains "$default_journal" "["
    assert_success
    
    # Create default ledger configuration
    run create_ledger_config "$profile_name"
    assert_success
    
    # Verify ledgers.yaml exists
    local ledger_config="$TEST_PROFILES_DIR/$profile_name/ledgers.yaml"
    assert [ -f "$ledger_config" ]
    
    # Check ledgers section exists
    run grep "^ledgers:" "$ledger_config"
    assert_success
    
    # Check default ledger is configured
    run grep "^  default:" "$ledger_config"
    assert_success
    
    # Verify default ledger file exists
    local default_ledger="$TEST_PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
    assert [ -f "$default_ledger" ]
    
    # Check ledger has account declarations
    run file_contains "$default_ledger" "account"
    assert_success
    
    # Check ledger has opening entry
    run file_contains "$default_ledger" "Opening Balance"
    assert_success
    
    # Clean up
    rm -rf "$TEST_PROFILES_DIR/$profile_name"
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
}

@test "Property 3: Default journal file has timestamp and welcome entry (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 3: Default Configuration Initialization
  # Validates: Requirements 2.10
  
  local iterations=10
  local success_count=0
  
  for i in $(seq 1 $iterations); do
    # Generate random valid profile name
    local profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile directories
    run create_profile_directories "$profile_name"
    assert_success
    
    # Create default journal configuration
    run create_journal_config "$profile_name"
    assert_success
    
    # Verify default journal file exists
    local default_journal="$TEST_PROFILES_DIR/$profile_name/journals/$profile_name.txt"
    assert [ -f "$default_journal" ]
    
    # Check journal has timestamp in format [YYYY-MM-DD HH:MM]
    run grep -E '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}\]' "$default_journal"
    assert_success
    
    # Check journal has welcome entry
    run file_contains "$default_journal" "Welcome to your journal"
    assert_success
    
    # Check journal mentions profile name
    run file_contains "$default_journal" "$profile_name"
    assert_success
    
    # Clean up
    rm -rf "$TEST_PROFILES_DIR/$profile_name"
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
}

@test "Property 3: Default ledger file has account declarations and opening entry (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 3: Default Configuration Initialization
  # Validates: Requirements 2.10
  
  local iterations=10
  local success_count=0
  
  for i in $(seq 1 $iterations); do
    # Generate random valid profile name
    local profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile directories
    run create_profile_directories "$profile_name"
    assert_success
    
    # Create default ledger configuration
    run create_ledger_config "$profile_name"
    assert_success
    
    # Verify default ledger file exists
    local default_ledger="$TEST_PROFILES_DIR/$profile_name/ledgers/$profile_name.journal"
    assert [ -f "$default_ledger" ]
    
    # Check ledger has account declarations
    run grep "^account" "$default_ledger"
    assert_success
    
    # Check ledger has at least one Assets account
    run grep "account Assets:" "$default_ledger"
    assert_success
    
    # Check ledger has opening entry with date
    run grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}.*Opening Balance' "$default_ledger"
    assert_success
    
    # Check ledger has Equity:Opening Balances account
    run file_contains "$default_ledger" "Equity:Opening Balances"
    assert_success
    
    # Clean up
    rm -rf "$TEST_PROFILES_DIR/$profile_name"
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
}

@test "Property 3: Configuration files use absolute paths (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 3: Default Configuration Initialization
  # Validates: Requirements 2.9
  
  local iterations=10
  local success_count=0
  
  for i in $(seq 1 $iterations); do
    # Generate random valid profile name
    local profile_name="test-$(random_alphanumeric 8)"
    
    # Create profile directories
    run create_profile_directories "$profile_name"
    assert_success
    
    # Create configurations
    run create_taskrc "$profile_name"
    assert_success
    
    run create_journal_config "$profile_name"
    assert_success
    
    run create_ledger_config "$profile_name"
    assert_success
    
    # Check .taskrc uses absolute paths
    local taskrc="$TEST_PROFILES_DIR/$profile_name/.taskrc"
    local data_location=$(grep "^data\.location=" "$taskrc" | cut -d= -f2)
    local hooks_location=$(grep "^hooks\.location=" "$taskrc" | cut -d= -f2)
    
    # Paths should start with / (absolute)
    assert [ "${data_location:0:1}" = "/" ]
    assert [ "${hooks_location:0:1}" = "/" ]
    
    # Check jrnl.yaml uses absolute paths
    local jrnl_config="$TEST_PROFILES_DIR/$profile_name/jrnl.yaml"
    local default_journal=$(grep "^  default:" "$jrnl_config" | awk '{print $2}')
    
    # Path should start with / (absolute)
    assert [ "${default_journal:0:1}" = "/" ]
    
    # Check ledgers.yaml uses absolute paths
    local ledger_config="$TEST_PROFILES_DIR/$profile_name/ledgers.yaml"
    local default_ledger=$(grep "^  default:" "$ledger_config" | awk '{print $2}')
    
    # Path should start with / (absolute)
    assert [ "${default_ledger:0:1}" = "/" ]
    
    # Clean up
    rm -rf "$TEST_PROFILES_DIR/$profile_name"
    
    ((success_count++))
  done
  
  # All iterations should succeed
  assert [ "$success_count" -eq "$iterations" ]
}
