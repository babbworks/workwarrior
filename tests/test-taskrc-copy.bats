#!/usr/bin/env bats
# Unit Tests for TaskRC Configuration Copying
# Feature: workwarrior-profiles-and-services
# Task 3.2: Implement copy_taskrc_from_profile function
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
# Basic Functionality Tests
# ============================================================================

@test "copy_taskrc_from_profile: Copies .taskrc from source to destination" {
  local source_profile="test-source"
  local dest_profile="test-dest"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create .taskrc in source profile
  create_taskrc "$source_profile"
  
  # Copy .taskrc from source to destination
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify .taskrc exists in destination
  [ -f "$PROFILES_DIR/$dest_profile/.taskrc" ]
}

@test "copy_taskrc_from_profile: Updates data.location to destination path" {
  local source_profile="test-source-data"
  local dest_profile="test-dest-data"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create .taskrc in source profile
  create_taskrc "$source_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify data.location points to destination profile
  local expected_path="$PROFILES_DIR/$dest_profile/.task"
  grep -q "^data\.location=$expected_path$" "$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify it does NOT point to source profile
  ! grep -q "^data\.location=.*$source_profile" "$PROFILES_DIR/$dest_profile/.taskrc"
}

@test "copy_taskrc_from_profile: Updates hooks.location to destination path" {
  local source_profile="test-source-hooks"
  local dest_profile="test-dest-hooks"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create .taskrc in source profile
  create_taskrc "$source_profile"
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify hooks.location points to destination profile
  local expected_path="$PROFILES_DIR/$dest_profile/.task/hooks"
  grep -q "^hooks\.location=$expected_path$" "$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify it does NOT point to source profile
  ! grep -q "^hooks\.location=.*$source_profile" "$PROFILES_DIR/$dest_profile/.taskrc"
}

# ============================================================================
# Settings Preservation Tests (Requirements 6.6, 6.7, 6.8)
# ============================================================================

@test "copy_taskrc_from_profile: Preserves User Defined Attributes (UDAs)" {
  local source_profile="test-source-uda"
  local dest_profile="test-dest-uda"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create .taskrc in source with custom UDAs
  create_taskrc "$source_profile"
  cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Custom UDAs
uda.estimate.type=numeric
uda.estimate.label=Estimate
uda.estimate.values=1,2,3,5,8,13
uda.reviewed.type=date
uda.reviewed.label=Reviewed
uda.priority.values=H,M,L
EOF
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify UDAs are preserved in destination
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  grep -q "uda\.estimate\.type=numeric" "$dest_taskrc"
  grep -q "uda\.estimate\.label=Estimate" "$dest_taskrc"
  grep -q "uda\.estimate\.values=1,2,3,5,8,13" "$dest_taskrc"
  grep -q "uda\.reviewed\.type=date" "$dest_taskrc"
  grep -q "uda\.reviewed\.label=Reviewed" "$dest_taskrc"
  grep -q "uda\.priority\.values=H,M,L" "$dest_taskrc"
}

@test "copy_taskrc_from_profile: Preserves report configurations" {
  local source_profile="test-source-reports"
  local dest_profile="test-dest-reports"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create .taskrc in source with custom reports
  create_taskrc "$source_profile"
  cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Custom reports
report.myreport.description=My custom report
report.myreport.columns=id,project,priority,description
report.myreport.labels=ID,Proj,Pri,Desc
report.myreport.sort=priority-,project+
report.myreport.filter=status:pending

report.weekly.description=Weekly review
report.weekly.columns=id,entry.age,description
report.weekly.labels=ID,Age,Description
report.weekly.filter=entry.after:today-7days
EOF
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify reports are preserved in destination
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  grep -q "report\.myreport\.description=My custom report" "$dest_taskrc"
  grep -q "report\.myreport\.columns=id,project,priority,description" "$dest_taskrc"
  grep -q "report\.myreport\.labels=ID,Proj,Pri,Desc" "$dest_taskrc"
  grep -q "report\.myreport\.sort=priority-,project+" "$dest_taskrc"
  grep -q "report\.myreport\.filter=status:pending" "$dest_taskrc"
  grep -q "report\.weekly\.description=Weekly review" "$dest_taskrc"
  grep -q "report\.weekly\.columns=id,entry.age,description" "$dest_taskrc"
}

@test "copy_taskrc_from_profile: Preserves urgency coefficients" {
  local source_profile="test-source-urgency"
  local dest_profile="test-dest-urgency"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create .taskrc in source with custom urgency coefficients
  create_taskrc "$source_profile"
  cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Custom urgency coefficients
urgency.user.project.coefficient=10.0
urgency.user.tag.next.coefficient=20.0
urgency.uda.priority.H.coefficient=8.0
urgency.uda.priority.M.coefficient=5.0
urgency.uda.priority.L.coefficient=2.0
urgency.age.coefficient=3.0
urgency.annotations.coefficient=2.0
urgency.tags.coefficient=1.5
urgency.project.coefficient=2.0
urgency.active.coefficient=6.0
urgency.scheduled.coefficient=7.0
urgency.waiting.coefficient=-5.0
urgency.blocked.coefficient=-8.0
urgency.due.coefficient=15.0
EOF
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify urgency coefficients are preserved in destination
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  grep -q "urgency\.user\.project\.coefficient=10\.0" "$dest_taskrc"
  grep -q "urgency\.user\.tag\.next\.coefficient=20\.0" "$dest_taskrc"
  grep -q "urgency\.uda\.priority\.H\.coefficient=8\.0" "$dest_taskrc"
  grep -q "urgency\.uda\.priority\.M\.coefficient=5\.0" "$dest_taskrc"
  grep -q "urgency\.uda\.priority\.L\.coefficient=2\.0" "$dest_taskrc"
  grep -q "urgency\.age\.coefficient=3\.0" "$dest_taskrc"
  grep -q "urgency\.due\.coefficient=15\.0" "$dest_taskrc"
}

@test "copy_taskrc_from_profile: Preserves context definitions" {
  local source_profile="test-source-context"
  local dest_profile="test-dest-context"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create .taskrc in source with contexts
  create_taskrc "$source_profile"
  cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Context definitions
context.work=+work or +office
context.home=+home or +personal
context.urgent=priority:H or due.before:tomorrow
context.review=+review or status:pending
EOF
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify contexts are preserved in destination
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  grep -q "context\.work=+work or +office" "$dest_taskrc"
  grep -q "context\.home=+home or +personal" "$dest_taskrc"
  grep -q "context\.urgent=priority:H or due\.before:tomorrow" "$dest_taskrc"
  grep -q "context\.review=+review or status:pending" "$dest_taskrc"
}

@test "copy_taskrc_from_profile: Preserves color theme settings" {
  local source_profile="test-source-colors"
  local dest_profile="test-dest-colors"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create .taskrc in source with color settings
  create_taskrc "$source_profile"
  cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Color theme
include dark-256.theme
color.active=bold white on bright blue
color.due=white on red
color.overdue=bold white on red
EOF
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify color settings are preserved in destination
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  grep -q "include dark-256\.theme" "$dest_taskrc"
  grep -q "color\.active=bold white on bright blue" "$dest_taskrc"
  grep -q "color\.due=white on red" "$dest_taskrc"
  grep -q "color\.overdue=bold white on red" "$dest_taskrc"
}

@test "copy_taskrc_from_profile: Preserves all settings except paths" {
  local source_profile="test-source-all"
  local dest_profile="test-dest-all"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create .taskrc in source with various settings
  create_taskrc "$source_profile"
  cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Various settings
verbose=blank,footnote,label,new-id
confirmation=yes
recurrence.confirmation=yes
search.case.sensitive=no
default.command=next
dateformat=Y-M-D
dateformat.report=Y-M-D H:N
weekstart=monday
displayweeknumber=yes
due=7
EOF
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify all settings are preserved
  local dest_taskrc="$PROFILES_DIR/$dest_profile/.taskrc"
  grep -q "verbose=blank,footnote,label,new-id" "$dest_taskrc"
  grep -q "confirmation=yes" "$dest_taskrc"
  grep -q "recurrence\.confirmation=yes" "$dest_taskrc"
  grep -q "search\.case\.sensitive=no" "$dest_taskrc"
  grep -q "default\.command=next" "$dest_taskrc"
  grep -q "dateformat=Y-M-D" "$dest_taskrc"
  grep -q "weekstart=monday" "$dest_taskrc"
  grep -q "displayweeknumber=yes" "$dest_taskrc"
  grep -q "due=7" "$dest_taskrc"
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "copy_taskrc_from_profile: Fails if source profile doesn't exist" {
  local source_profile="nonexistent-source"
  local dest_profile="test-dest"
  
  # Create only destination profile
  create_profile_directories "$dest_profile"
  
  # Try to copy from nonexistent source
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "does not exist" ]]
}

@test "copy_taskrc_from_profile: Fails if source .taskrc doesn't exist" {
  local source_profile="test-source-no-taskrc"
  local dest_profile="test-dest"
  
  # Create both profiles but don't create .taskrc in source
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Try to copy nonexistent .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

@test "copy_taskrc_from_profile: Fails if destination profile doesn't exist" {
  local source_profile="test-source"
  local dest_profile="nonexistent-dest"
  
  # Create only source profile
  create_profile_directories "$source_profile"
  create_taskrc "$source_profile"
  
  # Try to copy to nonexistent destination
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "does not exist" ]]
}

@test "copy_taskrc_from_profile: Fails for invalid source profile name" {
  local source_profile="invalid name!"
  local dest_profile="test-dest"
  
  # Try to copy with invalid source name
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 1 ]
}

@test "copy_taskrc_from_profile: Fails for invalid destination profile name" {
  local source_profile="test-source"
  local dest_profile="invalid name!"
  
  # Try to copy with invalid destination name
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 1 ]
}

# ============================================================================
# Path Update Tests
# ============================================================================

@test "copy_taskrc_from_profile: Paths are absolute in destination" {
  local source_profile="test-source-abs"
  local dest_profile="test-dest-abs"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  create_taskrc "$source_profile"
  
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
}

@test "copy_taskrc_from_profile: No HOME variable in destination paths" {
  local source_profile="test-source-no-home"
  local dest_profile="test-dest-no-home"
  
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
}

# ============================================================================
# Multiple Copy Tests
# ============================================================================

@test "copy_taskrc_from_profile: Can copy from one source to multiple destinations" {
  local source_profile="test-source-multi"
  local dest1="test-dest-1"
  local dest2="test-dest-2"
  local dest3="test-dest-3"
  
  # Create source and destinations
  create_profile_directories "$source_profile"
  create_profile_directories "$dest1"
  create_profile_directories "$dest2"
  create_profile_directories "$dest3"
  
  # Create .taskrc in source with custom settings
  create_taskrc "$source_profile"
  cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Custom setting
uda.custom.type=string
uda.custom.label=Custom
EOF
  
  # Copy to all destinations
  copy_taskrc_from_profile "$source_profile" "$dest1"
  copy_taskrc_from_profile "$source_profile" "$dest2"
  copy_taskrc_from_profile "$source_profile" "$dest3"
  
  # Verify each destination has correct paths
  grep -q "^data\.location=$PROFILES_DIR/$dest1/.task$" "$PROFILES_DIR/$dest1/.taskrc"
  grep -q "^data\.location=$PROFILES_DIR/$dest2/.task$" "$PROFILES_DIR/$dest2/.taskrc"
  grep -q "^data\.location=$PROFILES_DIR/$dest3/.task$" "$PROFILES_DIR/$dest3/.taskrc"
  
  # Verify custom setting is in all destinations
  grep -q "uda\.custom\.type=string" "$PROFILES_DIR/$dest1/.taskrc"
  grep -q "uda\.custom\.type=string" "$PROFILES_DIR/$dest2/.taskrc"
  grep -q "uda\.custom\.type=string" "$PROFILES_DIR/$dest3/.taskrc"
}

@test "copy_taskrc_from_profile: Can chain copies (A -> B -> C)" {
  local profile_a="test-profile-a"
  local profile_b="test-profile-b"
  local profile_c="test-profile-c"
  
  # Create all profiles
  create_profile_directories "$profile_a"
  create_profile_directories "$profile_b"
  create_profile_directories "$profile_c"
  
  # Create .taskrc in A with custom setting
  create_taskrc "$profile_a"
  cat >> "$PROFILES_DIR/$profile_a/.taskrc" << 'EOF'

# Original setting
uda.original.type=string
uda.original.label=Original
EOF
  
  # Copy A -> B
  copy_taskrc_from_profile "$profile_a" "$profile_b"
  
  # Copy B -> C
  copy_taskrc_from_profile "$profile_b" "$profile_c"
  
  # Verify C has correct paths (not A's or B's)
  grep -q "^data\.location=$PROFILES_DIR/$profile_c/.task$" "$PROFILES_DIR/$profile_c/.taskrc"
  grep -q "^hooks\.location=$PROFILES_DIR/$profile_c/.task/hooks$" "$PROFILES_DIR/$profile_c/.taskrc"
  
  # Verify C has the original custom setting
  grep -q "uda\.original\.type=string" "$PROFILES_DIR/$profile_c/.taskrc"
  grep -q "uda\.original\.label=Original" "$PROFILES_DIR/$profile_c/.taskrc"
}

# ============================================================================
# Edge Cases
# ============================================================================

@test "copy_taskrc_from_profile: Works with profile names containing hyphens" {
  local source_profile="test-source-with-hyphens"
  local dest_profile="test-dest-with-hyphens"
  
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  create_taskrc "$source_profile"
  
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify paths are correct
  grep -q "^data\.location=$PROFILES_DIR/$dest_profile/.task$" "$PROFILES_DIR/$dest_profile/.taskrc"
}

@test "copy_taskrc_from_profile: Works with profile names containing underscores" {
  local source_profile="test_source_with_underscores"
  local dest_profile="test_dest_with_underscores"
  
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  create_taskrc "$source_profile"
  
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify paths are correct
  grep -q "^data\.location=$PROFILES_DIR/$dest_profile/.task$" "$PROFILES_DIR/$dest_profile/.taskrc"
}

@test "copy_taskrc_from_profile: Overwrites existing .taskrc in destination" {
  local source_profile="test-source-overwrite"
  local dest_profile="test-dest-overwrite"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create .taskrc in both
  create_taskrc "$source_profile"
  create_taskrc "$dest_profile"
  
  # Add custom setting to source
  cat >> "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'

# Source custom setting
uda.source.type=string
EOF
  
  # Add different custom setting to destination
  cat >> "$PROFILES_DIR/$dest_profile/.taskrc" << 'EOF'

# Dest custom setting (should be overwritten)
uda.dest.type=string
EOF
  
  # Copy from source to destination
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify destination has source's custom setting
  grep -q "uda\.source\.type=string" "$PROFILES_DIR/$dest_profile/.taskrc"
  
  # Verify destination's original setting is gone
  ! grep -q "uda\.dest\.type=string" "$PROFILES_DIR/$dest_profile/.taskrc"
}

@test "copy_taskrc_from_profile: Handles .taskrc without data.location" {
  local source_profile="test-source-no-data"
  local dest_profile="test-dest-no-data"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create minimal .taskrc without data.location
  cat > "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'
# Minimal taskrc without data.location
hooks=on
verbose=blank,footnote
EOF
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify data.location was added
  grep -q "^data\.location=$PROFILES_DIR/$dest_profile/.task$" "$PROFILES_DIR/$dest_profile/.taskrc"
}

@test "copy_taskrc_from_profile: Handles .taskrc without hooks.location" {
  local source_profile="test-source-no-hooks"
  local dest_profile="test-dest-no-hooks"
  
  # Create both profiles
  create_profile_directories "$source_profile"
  create_profile_directories "$dest_profile"
  
  # Create minimal .taskrc without hooks.location
  cat > "$PROFILES_DIR/$source_profile/.taskrc" << 'EOF'
# Minimal taskrc without hooks.location
data.location=/some/path/.task
hooks=on
EOF
  
  # Copy .taskrc
  run copy_taskrc_from_profile "$source_profile" "$dest_profile"
  [ "$status" -eq 0 ]
  
  # Verify hooks.location was added
  grep -q "^hooks\.location=$PROFILES_DIR/$dest_profile/.task/hooks$" "$PROFILES_DIR/$dest_profile/.taskrc"
}
