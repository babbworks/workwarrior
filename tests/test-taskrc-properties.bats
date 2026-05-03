#!/usr/bin/env bats
# Property-Based Tests for TaskRC Configuration
# Feature: workwarrior-profiles-and-services
# Properties 15 & 16: TaskRC Path Configuration and Copy Path Update

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

# Helper function to generate random alphanumeric string
random_alphanumeric() {
  local length="$1"
  local chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'
  local result=''
  for ((i=0; i<length; i++)); do
    result="${result}${chars:RANDOM%${#chars}:1}"
  done
  echo "$result"
}

# ============================================================================
# Property 15: TaskRC Path Configuration
# **Validates: Requirements 6.1, 6.2, 6.3, 6.10**
#
# For any created profile, the .taskrc file should have data.location and
# hooks.location set to absolute paths pointing to the profile's .task and
# .task/hooks directories respectively, and hooks should be enabled (hooks=1).
# ============================================================================

@test "Property 15: Created .taskrc has correct data.location (50 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  for i in {1..50}; do
    # Generate random profile name
    local length=$((RANDOM % 26 + 5))
    local profile_name="test-$(random_alphanumeric "$length")"
    
    # Create profile and .taskrc
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    # Verify data.location is set to absolute path
    local expected_path="$PROFILES_DIR/$profile_name/.task"
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    
    # Check data.location exists and points to correct path
    grep -q "^data\.location=$expected_path$" "$taskrc"
    
    # Verify path is absolute (starts with /)
    local data_location=$(grep "^data\.location=" "$taskrc" | cut -d= -f2)
    [[ "$data_location" == /* ]]
  done
}

@test "Property 15: Created .taskrc has correct hooks.location (50 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  for i in {1..50}; do
    # Generate random profile name
    local length=$((RANDOM % 26 + 5))
    local profile_name="test-$(random_alphanumeric "$length")"
    
    # Create profile and .taskrc
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    # Verify hooks.location is set to absolute path
    local expected_path="$PROFILES_DIR/$profile_name/.task/hooks"
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    
    # Check hooks.location exists and points to correct path
    grep -q "^hooks\.location=$expected_path$" "$taskrc"
    
    # Verify path is absolute (starts with /)
    local hooks_location=$(grep "^hooks\.location=" "$taskrc" | cut -d= -f2)
    [[ "$hooks_location" == /* ]]
  done
}

@test "Property 15: Created .taskrc has hooks enabled (50 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  for i in {1..50}; do
    # Generate random profile name
    local length=$((RANDOM % 26 + 5))
    local profile_name="test-$(random_alphanumeric "$length")"
    
    # Create profile and .taskrc
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    
    # Verify hooks are enabled (hooks=on or hooks=1)
    grep -qE "^hooks=(on|1)$" "$taskrc"
  done
}

@test "Property 15: All three required settings present (100 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  for i in {1..100}; do
    # Generate random profile name
    local length=$((RANDOM % 26 + 5))
    local profile_name="test-$(random_alphanumeric "$length")"
    
    # Create profile and .taskrc
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    local expected_data="$PROFILES_DIR/$profile_name/.task"
    local expected_hooks="$PROFILES_DIR/$profile_name/.task/hooks"
    
    # Verify all three required settings
    grep -q "^data\.location=$expected_data$" "$taskrc"
    grep -q "^hooks\.location=$expected_hooks$" "$taskrc"
    grep -qE "^hooks=(on|1)$" "$taskrc"
  done
}

@test "Property 15: Paths are absolute with no variables (50 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  for i in {1..50}; do
    # Generate random profile name
    local length=$((RANDOM % 26 + 5))
    local profile_name="test-$(random_alphanumeric "$length")"
    
    # Create profile and .taskrc
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    
    # Verify no $HOME or ~ in paths
    ! grep "^data\.location=.*\$HOME" "$taskrc"
    ! grep "^data\.location=.*~" "$taskrc"
    ! grep "^hooks\.location=.*\$HOME" "$taskrc"
    ! grep "^hooks\.location=.*~" "$taskrc"
    
    # Verify paths start with /
    local data_location=$(grep "^data\.location=" "$taskrc" | cut -d= -f2)
    local hooks_location=$(grep "^hooks\.location=" "$taskrc" | cut -d= -f2)
    [[ "$data_location" == /* ]]
    [[ "$hooks_location" == /* ]]
  done
}

@test "Property 15: Works with various valid profile name patterns" {
  # Feature: workwarrior-profiles-and-services, Property 15: TaskRC Path Configuration
  
  # Test different name patterns
  local patterns=(
    "simple"
    "with-hyphens-123"
    "with_underscores_456"
    "MixedCase_And-Hyphens"
    "123numeric"
    "a"
    "_"
    "-"
    "a1b2c3d4e5f6g7h8i9j0"
  )
  
  for profile_name in "${patterns[@]}"; do
    # Create profile and .taskrc
    create_profile_directories "$profile_name"
    run create_taskrc "$profile_name"
    [ "$status" -eq 0 ]
    
    local taskrc="$PROFILES_DIR/$profile_name/.taskrc"
    local expected_data="$PROFILES_DIR/$profile_name/.task"
    local expected_hooks="$PROFILES_DIR/$profile_name/.task/hooks"
    
    # Verify all required settings
    grep -q "^data\.location=$expected_data$" "$taskrc"
    grep -q "^hooks\.location=$expected_hooks$" "$taskrc"
    grep -qE "^hooks=(on|1)$" "$taskrc"
  done
}

# ============================================================================
# Property 16: TaskRC Copy Path Update
# **Validates: Requirements 6.4, 6.5, 6.6, 6.7, 6.8**
#
# For any profile created by copying another profile's .taskrc, all path
# references (data.location, hooks.location) should be updated to point to
# the new profile's directories, while all other settings (UDAs, reports,
# urgency coefficients) should be preserved.
# ============================================================================

@test "Property 16: Copied .taskrc updates data.location (50 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  for i in {1..50}; do
    # Generate random profile names
    local length1=$((RANDOM % 26 + 5))
    local length2=$((RANDOM % 26 + 5))
    local source_profile="src-$(random_alphanumeric "$length1")"
    local dest_profile="dst-$(random_alphanumeric "$length2")"
    
    # Create both profiles
    create_profile_directories "$source_profile"
    create_profile_directories "$dest_profile"
    create_taskrc "$source_profile"
    
    # Copy .taskrc
    run copy_taskrc_from_profile "$source_profile" "$dest_profile"
    [ "$status" -eq 0 ]
    
    local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
    local expected_path="$PROFILES_DIR/$dest_profile/.task"
    
    # Verify data.location points to destination profile
    grep -q "^data\.location=$expected_path$" "$dest_taskrc"
    
    # Verify it does NOT point to source profile
    ! grep -q "^data\.location=.*$source_profile" "$dest_taskrc"
  done
}

@test "Property 16: Copied .taskrc updates hooks.location (50 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  for i in {1..50}; do
    # Generate random profile names
    local length1=$((RANDOM % 26 + 5))
    local length2=$((RANDOM % 26 + 5))
    local source_profile="src-$(random_alphanumeric "$length1")"
    local dest_profile="dst-$(random_alphanumeric "$length2")"
    
    # Create both profiles
    create_profile_directories "$source_profile"
    create_profile_directories "$dest_profile"
    create_taskrc "$source_profile"
    
    # Copy .taskrc
    run copy_taskrc_from_profile "$source_profile" "$dest_profile"
    [ "$status" -eq 0 ]
    
    local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
    local expected_path="$PROFILES_DIR/$dest_profile/.task/hooks"
    
    # Verify hooks.location points to destination profile
    grep -q "^hooks\.location=$expected_path$" "$dest_taskrc"
    
    # Verify it does NOT point to source profile
    ! grep -q "^hooks\.location=.*$source_profile" "$dest_taskrc"
  done
}

@test "Property 16: Copied .taskrc preserves UDAs (50 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  for i in {1..50}; do
    # Generate random profile names
    local length1=$((RANDOM % 26 + 5))
    local length2=$((RANDOM % 26 + 5))
    local source_profile="src-$(random_alphanumeric "$length1")"
    local dest_profile="dst-$(random_alphanumeric "$length2")"
    
    # Create both profiles
    create_profile_directories "$source_profile"
    create_profile_directories "$dest_profile"
    create_taskrc "$source_profile"
    
    # Add custom UDAs to source
    cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Custom UDAs for testing
uda.estimate.type=numeric
uda.estimate.label=Estimate
uda.reviewed.type=date
uda.reviewed.label=Reviewed
EOF
    
    # Copy .taskrc
    run copy_taskrc_from_profile "$source_profile" "$dest_profile"
    [ "$status" -eq 0 ]
    
    local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
    
    # Verify UDAs are preserved
    grep -q "uda\.estimate\.type=numeric" "$dest_taskrc"
    grep -q "uda\.estimate\.label=Estimate" "$dest_taskrc"
    grep -q "uda\.reviewed\.type=date" "$dest_taskrc"
    grep -q "uda\.reviewed\.label=Reviewed" "$dest_taskrc"
  done
}

@test "Property 16: Copied .taskrc preserves report configurations (50 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  for i in {1..50}; do
    # Generate random profile names
    local length1=$((RANDOM % 26 + 5))
    local length2=$((RANDOM % 26 + 5))
    local source_profile="src-$(random_alphanumeric "$length1")"
    local dest_profile="dst-$(random_alphanumeric "$length2")"
    
    # Create both profiles
    create_profile_directories "$source_profile"
    create_profile_directories "$dest_profile"
    create_taskrc "$source_profile"
    
    # Add custom report to source
    cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Custom report for testing
report.myreport.description=My custom report
report.myreport.columns=id,project,priority,description
report.myreport.labels=ID,Proj,Pri,Desc
report.myreport.sort=priority-,project+
EOF
    
    # Copy .taskrc
    run copy_taskrc_from_profile "$source_profile" "$dest_profile"
    [ "$status" -eq 0 ]
    
    local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
    
    # Verify report is preserved
    grep -q "report\.myreport\.description=My custom report" "$dest_taskrc"
    grep -q "report\.myreport\.columns=id,project,priority,description" "$dest_taskrc"
    grep -q "report\.myreport\.labels=ID,Proj,Pri,Desc" "$dest_taskrc"
    grep -q "report\.myreport\.sort=priority-,project+" "$dest_taskrc"
  done
}

@test "Property 16: Copied .taskrc preserves urgency coefficients (50 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  for i in {1..50}; do
    # Generate random profile names
    local length1=$((RANDOM % 26 + 5))
    local length2=$((RANDOM % 26 + 5))
    local source_profile="src-$(random_alphanumeric "$length1")"
    local dest_profile="dst-$(random_alphanumeric "$length2")"
    
    # Create both profiles
    create_profile_directories "$source_profile"
    create_profile_directories "$dest_profile"
    create_taskrc "$source_profile"
    
    # Add custom urgency coefficients to source
    cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Custom urgency coefficients for testing
urgency.user.project.coefficient=10.0
urgency.user.tag.next.coefficient=20.0
urgency.age.coefficient=3.0
urgency.due.coefficient=15.0
EOF
    
    # Copy .taskrc
    run copy_taskrc_from_profile "$source_profile" "$dest_profile"
    [ "$status" -eq 0 ]
    
    local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
    
    # Verify urgency coefficients are preserved
    grep -q "urgency\.user\.project\.coefficient=10\.0" "$dest_taskrc"
    grep -q "urgency\.user\.tag\.next\.coefficient=20\.0" "$dest_taskrc"
    grep -q "urgency\.age\.coefficient=3\.0" "$dest_taskrc"
    grep -q "urgency\.due\.coefficient=15\.0" "$dest_taskrc"
  done
}

@test "Property 16: Paths updated but all other settings preserved (100 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  for i in {1..100}; do
    # Generate random profile names
    local length1=$((RANDOM % 26 + 5))
    local length2=$((RANDOM % 26 + 5))
    local source_profile="src-$(random_alphanumeric "$length1")"
    local dest_profile="dst-$(random_alphanumeric "$length2")"
    
    # Create both profiles
    create_profile_directories "$source_profile"
    create_profile_directories "$dest_profile"
    create_taskrc "$source_profile"
    
    # Add various settings to source
    cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Various settings to preserve
uda.custom.type=string
uda.custom.label=Custom
report.test.description=Test report
report.test.columns=id,description
urgency.user.tag.important.coefficient=5.0
context.work=+work
verbose=blank,footnote
confirmation=yes
dateformat=Y-M-D
EOF
    
    # Copy .taskrc
    run copy_taskrc_from_profile "$source_profile" "$dest_profile"
    [ "$status" -eq 0 ]
    
    local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
    
    # Verify paths are updated
    grep -q "^data\.location=$PROFILES_DIR/$dest_profile/.task$" "$dest_taskrc"
    grep -q "^hooks\.location=$PROFILES_DIR/$dest_profile/.task/hooks$" "$dest_taskrc"
    
    # Verify paths do NOT point to source
    ! grep -q "^data\.location=.*$source_profile" "$dest_taskrc"
    ! grep -q "^hooks\.location=.*$source_profile" "$dest_taskrc"
    
    # Verify all other settings are preserved
    grep -q "uda\.custom\.type=string" "$dest_taskrc"
    grep -q "uda\.custom\.label=Custom" "$dest_taskrc"
    grep -q "report\.test\.description=Test report" "$dest_taskrc"
    grep -q "report\.test\.columns=id,description" "$dest_taskrc"
    grep -q "urgency\.user\.tag\.important\.coefficient=5\.0" "$dest_taskrc"
    grep -q "context\.work=+work" "$dest_taskrc"
    grep -q "verbose=blank,footnote" "$dest_taskrc"
    grep -q "confirmation=yes" "$dest_taskrc"
    grep -q "dateformat=Y-M-D" "$dest_taskrc"
  done
}

@test "Property 16: Chain copies preserve settings (A -> B -> C)" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  for i in {1..20}; do
    # Generate random profile names
    local length1=$((RANDOM % 15 + 5))
    local length2=$((RANDOM % 15 + 5))
    local length3=$((RANDOM % 15 + 5))
    local profile_a="a-$(random_alphanumeric "$length1")"
    local profile_b="b-$(random_alphanumeric "$length2")"
    local profile_c="c-$(random_alphanumeric "$length3")"
    
    # Create all profiles
    create_profile_directories "$profile_a"
    create_profile_directories "$profile_b"
    create_profile_directories "$profile_c"
    create_taskrc "$profile_a"
    
    # Add custom settings to A
    cat >> "$PROFILES_DIR/$profile_a/.taskrc" << 'EOF'

# Original settings
uda.original.type=string
uda.original.label=Original
urgency.user.tag.test.coefficient=7.5
EOF
    
    # Copy A -> B
    copy_taskrc_from_profile "$profile_a" "$profile_b"
    
    # Copy B -> C
    copy_taskrc_from_profile "$profile_b" "$profile_c"
    
    local taskrc_c="$PROFILES_DIR/$profile_c/.taskrc"
    
    # Verify C has correct paths (not A's or B's)
    grep -q "^data\.location=$PROFILES_DIR/$profile_c/.task$" "$taskrc_c"
    grep -q "^hooks\.location=$PROFILES_DIR/$profile_c/.task/hooks$" "$taskrc_c"
    ! grep -q "$profile_a" "$taskrc_c"
    ! grep -q "$profile_b" "$taskrc_c"
    
    # Verify C has the original custom settings
    grep -q "uda\.original\.type=string" "$taskrc_c"
    grep -q "uda\.original\.label=Original" "$taskrc_c"
    grep -q "urgency\.user\.tag\.test\.coefficient=7\.5" "$taskrc_c"
  done
}

@test "Property 16: Multiple destinations from one source have independent paths" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  for i in {1..20}; do
    # Generate random profile names
    local source="src-$(random_alphanumeric 10)"
    local dest1="dst1-$(random_alphanumeric 10)"
    local dest2="dst2-$(random_alphanumeric 10)"
    local dest3="dst3-$(random_alphanumeric 10)"
    
    # Create source and destinations
    create_profile_directories "$source"
    create_profile_directories "$dest1"
    create_profile_directories "$dest2"
    create_profile_directories "$dest3"
    create_taskrc "$source"
    
    # Add custom setting to source
    cat >> "$PROFILES_DIR/$source/.taskrc" << 'EOF'

# Shared setting
uda.shared.type=string
EOF
    
    # Copy to all destinations
    copy_taskrc_from_profile "$source" "$dest1"
    copy_taskrc_from_profile "$source" "$dest2"
    copy_taskrc_from_profile "$source" "$dest3"
    
    # Verify each destination has correct independent paths
    grep -q "^data\.location=$PROFILES_DIR/$dest1/.task$" "$PROFILES_DIR/$dest1/.taskrc"
    grep -q "^data\.location=$PROFILES_DIR/$dest2/.task$" "$PROFILES_DIR/$dest2/.taskrc"
    grep -q "^data\.location=$PROFILES_DIR/$dest3/.task$" "$PROFILES_DIR/$dest3/.taskrc"
    
    grep -q "^hooks\.location=$PROFILES_DIR/$dest1/.task/hooks$" "$PROFILES_DIR/$dest1/.taskrc"
    grep -q "^hooks\.location=$PROFILES_DIR/$dest2/.task/hooks$" "$PROFILES_DIR/$dest2/.taskrc"
    grep -q "^hooks\.location=$PROFILES_DIR/$dest3/.task/hooks$" "$PROFILES_DIR/$dest3/.taskrc"
    
    # Verify shared setting is in all destinations
    grep -q "uda\.shared\.type=string" "$PROFILES_DIR/$dest1/.taskrc"
    grep -q "uda\.shared\.type=string" "$PROFILES_DIR/$dest2/.taskrc"
    grep -q "uda\.shared\.type=string" "$PROFILES_DIR/$dest3/.taskrc"
  done
}

@test "Property 16: Copied paths are absolute with no variables (50 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  for i in {1..50}; do
    # Generate random profile names
    local length1=$((RANDOM % 26 + 5))
    local length2=$((RANDOM % 26 + 5))
    local source_profile="src-$(random_alphanumeric "$length1")"
    local dest_profile="dst-$(random_alphanumeric "$length2")"
    
    # Create both profiles
    create_profile_directories "$source_profile"
    create_profile_directories "$dest_profile"
    create_taskrc "$source_profile"
    
    # Copy .taskrc
    run copy_taskrc_from_profile "$source_profile" "$dest_profile"
    [ "$status" -eq 0 ]
    
    local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
    
    # Verify no $HOME or ~ in paths
    ! grep "^data\.location=.*\$HOME" "$dest_taskrc"
    ! grep "^data\.location=.*~" "$dest_taskrc"
    ! grep "^hooks\.location=.*\$HOME" "$dest_taskrc"
    ! grep "^hooks\.location=.*~" "$dest_taskrc"
    
    # Verify paths are absolute (start with /)
    local data_location=$(grep "^data\.location=" "$dest_taskrc" | cut -d= -f2)
    local hooks_location=$(grep "^hooks\.location=" "$dest_taskrc" | cut -d= -f2)
    [[ "$data_location" == /* ]]
    [[ "$hooks_location" == /* ]]
  done
}
