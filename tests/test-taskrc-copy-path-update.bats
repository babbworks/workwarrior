#!/usr/bin/env bats
# Property-Based Tests for TaskRC Copy Path Update
# Feature: workwarrior-profiles-and-services
# Property 16: TaskRC Copy Path Update
# Validates: Requirements 6.4, 6.5, 6.6, 6.7, 6.8

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

# ============================================================================
# Property 16: TaskRC Copy Path Update
# For any profile created by copying another profile's .taskrc, all path
# references (data.location, hooks.location) should be updated to point to
# the new profile's directories, while all other settings (UDAs, reports,
# urgency coefficients) should be preserved.
# ============================================================================

# Helper function to generate random alphanumeric string
random_alphanumeric() {
  local length="$1"
  tr -dc 'a-zA-Z0-9_-' < /dev/urandom | head -c "$length"
}

# Helper function to add custom settings to a .taskrc
add_custom_settings() {
  local taskrc="$1"
  
  cat >> "$taskrc" << 'EOF'

# Custom UDAs
uda.priority_score.type=numeric
uda.priority_score.label=Priority Score
uda.estimate.type=duration
uda.estimate.label=Estimate

# Custom report
report.custom.description=Custom report
report.custom.columns=id,description,priority_score
report.custom.labels=ID,Description,Score
report.custom.sort=priority_score-

# Urgency coefficients
urgency.uda.priority_score.coefficient=5.0
urgency.user.tag.urgent.coefficient=10.0
urgency.age.coefficient=2.0

# Context
context.work=+work
context.personal=-work

# Color theme
color.active=bold white on blue
color.due=red
EOF
}

@test "Property 16: Copied .taskrc updates data.location to new profile" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source"
  local dest_profile="test-dest"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  local expected_path="$PROFILES_DIR/$dest_profile/.task"
  
  # Verify data.location points to destination profile
  grep -q "^data\.location=$expected_path$" "$dest_taskrc"
}

@test "Property 16: Copied .taskrc updates hooks.location to new profile" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source-hooks"
  local dest_profile="test-dest-hooks"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  local expected_path="$PROFILES_DIR/$dest_profile/.task/hooks"
  
  # Verify hooks.location points to destination profile
  grep -q "^hooks\.location=$expected_path$" "$dest_taskrc"
}

@test "Property 16: Copied .taskrc does not contain source profile paths" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source-no-old-paths"
  local dest_profile="test-dest-no-old-paths"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify no references to source profile in paths
  ! grep "^data\.location=.*/$source_profile/" "$dest_taskrc"
  ! grep "^hooks\.location=.*/$source_profile/" "$dest_taskrc"
}

@test "Property 16: Custom UDAs are preserved when copying" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source-uda"
  local dest_profile="test-dest-uda"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Add custom UDAs to source
  local source_taskrc="$PROFILES_DIR/$source_profile/.taskrc"
  add_custom_settings "$source_taskrc"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify custom UDAs are preserved
  grep -q "^uda\.priority_score\.type=numeric$" "$dest_taskrc"
  grep -q "^uda\.priority_score\.label=Priority Score$" "$dest_taskrc"
  grep -q "^uda\.estimate\.type=duration$" "$dest_taskrc"
  grep -q "^uda\.estimate\.label=Estimate$" "$dest_taskrc"
}

@test "Property 16: Custom reports are preserved when copying" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source-report"
  local dest_profile="test-dest-report"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Add custom settings to source
  local source_taskrc="$PROFILES_DIR/$source_profile/.taskrc"
  add_custom_settings "$source_taskrc"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify custom report is preserved
  grep -q "^report\.custom\.description=Custom report$" "$dest_taskrc"
  grep -q "^report\.custom\.columns=id,description,priority_score$" "$dest_taskrc"
  grep -q "^report\.custom\.labels=ID,Description,Score$" "$dest_taskrc"
  grep -q "^report\.custom\.sort=priority_score-$" "$dest_taskrc"
}

@test "Property 16: Urgency coefficients are preserved when copying" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source-urgency"
  local dest_profile="test-dest-urgency"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Add custom settings to source
  local source_taskrc="$PROFILES_DIR/$source_profile/.taskrc"
  add_custom_settings "$source_taskrc"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify urgency coefficients are preserved
  grep -q "^urgency\.uda\.priority_score\.coefficient=5\.0$" "$dest_taskrc"
  grep -q "^urgency\.user\.tag\.urgent\.coefficient=10\.0$" "$dest_taskrc"
  grep -q "^urgency\.age\.coefficient=2\.0$" "$dest_taskrc"
}

@test "Property 16: Context definitions are preserved when copying" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source-context"
  local dest_profile="test-dest-context"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Add custom settings to source
  local source_taskrc="$PROFILES_DIR/$source_profile/.taskrc"
  add_custom_settings "$source_taskrc"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify context definitions are preserved
  grep -q "^context\.work=+work$" "$dest_taskrc"
  grep -q "^context\.personal=-work$" "$dest_taskrc"
}

@test "Property 16: Color settings are preserved when copying" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source-color"
  local dest_profile="test-dest-color"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Add custom settings to source
  local source_taskrc="$PROFILES_DIR/$source_profile/.taskrc"
  add_custom_settings "$source_taskrc"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify color settings are preserved
  grep -q "^color\.active=bold white on blue$" "$dest_taskrc"
  grep -q "^color\.due=red$" "$dest_taskrc"
}

@test "Property 16: All settings preserved while paths updated" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source-all"
  local dest_profile="test-dest-all"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Add custom settings to source
  local source_taskrc="$PROFILES_DIR/$source_profile/.taskrc"
  add_custom_settings "$source_taskrc"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify paths are updated
  grep -q "^data\.location=$PROFILES_DIR/$dest_profile/.task$" "$dest_taskrc"
  grep -q "^hooks\.location=$PROFILES_DIR/$dest_profile/.task/hooks$" "$dest_taskrc"
  
  # Verify all custom settings are preserved
  grep -q "^uda\.priority_score\.type=numeric$" "$dest_taskrc"
  grep -q "^report\.custom\.description=Custom report$" "$dest_taskrc"
  grep -q "^urgency\.uda\.priority_score\.coefficient=5\.0$" "$dest_taskrc"
  grep -q "^context\.work=+work$" "$dest_taskrc"
  grep -q "^color\.active=bold white on blue$" "$dest_taskrc"
}

# ============================================================================
# Property-Based Tests: Random Valid Profile Names (10 iterations)
# ============================================================================

@test "Property 16: Random profile names have correct path updates (10 iterations)" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  for i in {1..10}; do
    # Generate random profile names
    local source_length=$((RANDOM % 20 + 5))
    local dest_length=$((RANDOM % 20 + 5))
    local source_profile="src-$(random_alphanumeric "$source_length")"
    local dest_profile="dst-$(random_alphanumeric "$dest_length")"
    
    # Create source profile with .taskrc
    create_profile_directories "$source_profile"
    create_taskrc "$source_profile"
    
    # Add custom settings
    add_custom_settings "$PROFILES_DIR/$source_profile/.taskrc"
    
    # Create destination profile
    create_profile_directories "$dest_profile"
    
    # Copy .taskrc
    run copy_taskrc_from_profile "$source_profile" "$dest_profile"
    [ "$status" -eq 0 ]
    
    local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
    
    # Verify paths are updated to destination
    grep -q "^data\.location=$PROFILES_DIR/$dest_profile/.task$" "$dest_taskrc"
    grep -q "^hooks\.location=$PROFILES_DIR/$dest_profile/.task/hooks$" "$dest_taskrc"
    
    # Verify no source profile paths remain
    ! grep "^data\.location=.*/$source_profile/" "$dest_taskrc"
    ! grep "^hooks\.location=.*/$source_profile/" "$dest_taskrc"
    
    # Verify custom settings are preserved
    grep -q "^uda\.priority_score\.type=numeric$" "$dest_taskrc"
    grep -q "^report\.custom\.description=Custom report$" "$dest_taskrc"
  done
}

@test "Property 16: Profile names with hyphens copy correctly" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="work-profile-2024"
  local dest_profile="personal-profile-2024"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  add_custom_settings "$PROFILES_DIR/$source_profile/.taskrc"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify paths are updated
  grep -q "^data\.location=$PROFILES_DIR/$dest_profile/.task$" "$dest_taskrc"
  grep -q "^hooks\.location=$PROFILES_DIR/$dest_profile/.task/hooks$" "$dest_taskrc"
  
  # Verify settings preserved
  grep -q "^uda\.priority_score\.type=numeric$" "$dest_taskrc"
}

@test "Property 16: Profile names with underscores copy correctly" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="work_profile_2024"
  local dest_profile="personal_profile_2024"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  add_custom_settings "$PROFILES_DIR/$source_profile/.taskrc"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify paths are updated
  grep -q "^data\.location=$PROFILES_DIR/$dest_profile/.task$" "$dest_taskrc"
  grep -q "^hooks\.location=$PROFILES_DIR/$dest_profile/.task/hooks$" "$dest_taskrc"
  
  # Verify settings preserved
  grep -q "^uda\.priority_score\.type=numeric$" "$dest_taskrc"
}

@test "Property 16: Mixed valid characters copy correctly" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="Work_Profile-2024"
  local dest_profile="Personal-Profile_v2"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  add_custom_settings "$PROFILES_DIR/$source_profile/.taskrc"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify paths are updated
  grep -q "^data\.location=$PROFILES_DIR/$dest_profile/.task$" "$dest_taskrc"
  grep -q "^hooks\.location=$PROFILES_DIR/$dest_profile/.task/hooks$" "$dest_taskrc"
  
  # Verify settings preserved
  grep -q "^uda\.priority_score\.type=numeric$" "$dest_taskrc"
}

# ============================================================================
# Edge Cases and Multiple Copies
# ============================================================================

@test "Property 16: Copying from copied profile maintains settings" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local profile1="test-original"
  local profile2="test-copy1"
  local profile3="test-copy2"
  
  # Create original profile with custom settings
  create_profile_directories "$profile1"
  create_taskrc "$profile1"
  add_custom_settings "$PROFILES_DIR/$profile1/.taskrc"
  
  # Copy to profile2
  create_profile_directories "$profile2"
  copy_taskrc_from_profile "$profile1" "$profile2"
  
  # Copy from profile2 to profile3
  create_profile_directories "$profile3"
  run copy_taskrc_from_profile "$profile2" "$profile3"
  [ "$status" -eq 0 ]
  
  local taskrc3="$PROFILES_DIR/$profile3/.taskrc"
  
  # Verify profile3 has correct paths
  grep -q "^data\.location=$PROFILES_DIR/$profile3/.task$" "$taskrc3"
  grep -q "^hooks\.location=$PROFILES_DIR/$profile3/.task/hooks$" "$taskrc3"
  
  # Verify settings are still preserved
  grep -q "^uda\.priority_score\.type=numeric$" "$taskrc3"
  grep -q "^report\.custom\.description=Custom report$" "$taskrc3"
  grep -q "^urgency\.uda\.priority_score\.coefficient=5\.0$" "$taskrc3"
}

@test "Property 16: Multiple independent copies from same source" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source="test-source-multi"
  local dest1="test-dest-1"
  local dest2="test-dest-2"
  local dest3="test-dest-3"
  
  # Create source profile with custom settings
  create_profile_directories "$source"
  create_taskrc "$source"
  add_custom_settings "$PROFILES_DIR/$source/.taskrc"
  
  # Create multiple destination profiles
  create_profile_directories "$dest1"
  create_profile_directories "$dest2"
  create_profile_directories "$dest3"
  
  # Copy to all destinations
  copy_taskrc_from_profile "$source" "$dest1"
  copy_taskrc_from_profile "$source" "$dest2"
  copy_taskrc_from_profile "$source" "$dest3"
  
  # Verify each has correct independent paths
  local taskrc1="$PROFILES_DIR/$dest1/.taskrc"
  local taskrc2="$PROFILES_DIR/$dest2/.taskrc"
  local taskrc3="$PROFILES_DIR/$dest3/.taskrc"
  
  # Dest1 paths
  grep -q "^data\.location=$PROFILES_DIR/$dest1/.task$" "$taskrc1"
  grep -q "^hooks\.location=$PROFILES_DIR/$dest1/.task/hooks$" "$taskrc1"
  grep -q "^uda\.priority_score\.type=numeric$" "$taskrc1"
  
  # Dest2 paths
  grep -q "^data\.location=$PROFILES_DIR/$dest2/.task$" "$taskrc2"
  grep -q "^hooks\.location=$PROFILES_DIR/$dest2/.task/hooks$" "$taskrc2"
  grep -q "^uda\.priority_score\.type=numeric$" "$taskrc2"
  
  # Dest3 paths
  grep -q "^data\.location=$PROFILES_DIR/$dest3/.task$" "$taskrc3"
  grep -q "^hooks\.location=$PROFILES_DIR/$dest3/.task/hooks$" "$taskrc3"
  grep -q "^uda\.priority_score\.type=numeric$" "$taskrc3"
}

@test "Property 16: Hooks setting is preserved from source" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source-hooks-preserve"
  local dest_profile="test-dest-hooks-preserve"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Verify source has hooks=on
  local source_taskrc="$PROFILES_DIR/$source_profile/.taskrc"
  grep -q "^hooks=on$" "$source_taskrc"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify hooks setting is preserved
  grep -q "^hooks=" "$dest_taskrc"
}

@test "Property 16: Absolute paths maintained (no relative paths)" {
  # Feature: workwarrior-profiles-and-services, Property 16: TaskRC Copy Path Update
  
  local source_profile="test-source-absolute"
  local dest_profile="test-dest-absolute"
  
  # Create source profile with .taskrc
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Create destination profile
  create_profile_directories "$dest_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Extract paths
  local data_location=$(grep "^data\.location=" "$dest_taskrc" | cut -d= -f2)
  local hooks_location=$(grep "^hooks\.location=" "$dest_taskrc" | cut -d= -f2)
  
  # Verify paths are absolute (start with /)
  [[ "$data_location" == /* ]]
  [[ "$hooks_location" == /* ]]
  
  # Verify no variables or tilde
  ! grep "^data\.location=.*\$" "$dest_taskrc"
  ! grep "^data\.location=.*~" "$dest_taskrc"
  ! grep "^hooks\.location=.*\$" "$dest_taskrc"
  ! grep "^hooks\.location=.*~" "$dest_taskrc"
}
