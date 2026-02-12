#!/usr/bin/env bats
# Property-Based Tests for Environment Variable Atomic Update
# Feature: workwarrior-profiles-and-services
# Property 31: Environment Variable Atomic Update

setup() {
  export TEST_MODE=1
  export TEST_WW_BASE="${BATS_TEST_TMPDIR}/ww-test-$$"
  export WW_BASE="$TEST_WW_BASE"
  export PROFILES_DIR="$TEST_WW_BASE/profiles"

  mkdir -p "$PROFILES_DIR"

  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
  source "${BATS_TEST_DIRNAME}/../lib/profile-manager.sh"
  source "${BATS_TEST_DIRNAME}/../lib/shell-integration.sh"
}

teardown() {
  if [[ -d "$TEST_WW_BASE" ]]; then
    rm -rf "$TEST_WW_BASE"
  fi
}

create_profile_minimal() {
  local profile_name="$1"
  create_profile_directories "$profile_name"
  create_taskrc "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
}

@test "Property 31: Switching profiles updates all env vars together" {
  local profile_a="alpha"
  local profile_b="beta"

  create_profile_minimal "$profile_a"
  create_profile_minimal "$profile_b"

  use_task_profile "$profile_a"
  [[ "$WORKWARRIOR_BASE" == "$PROFILES_DIR/$profile_a" ]]
  [[ "$TASKRC" == "$PROFILES_DIR/$profile_a/.taskrc" ]]
  [[ "$TASKDATA" == "$PROFILES_DIR/$profile_a/.task" ]]
  [[ "$TIMEWARRIORDB" == "$PROFILES_DIR/$profile_a/.timewarrior" ]]
  [[ "$WARRIOR_PROFILE" == "$profile_a" ]]

  use_task_profile "$profile_b"
  [[ "$WORKWARRIOR_BASE" == "$PROFILES_DIR/$profile_b" ]]
  [[ "$TASKRC" == "$PROFILES_DIR/$profile_b/.taskrc" ]]
  [[ "$TASKDATA" == "$PROFILES_DIR/$profile_b/.task" ]]
  [[ "$TIMEWARRIORDB" == "$PROFILES_DIR/$profile_b/.timewarrior" ]]
  [[ "$WARRIOR_PROFILE" == "$profile_b" ]]

  # Ensure no env vars still point to profile A
  ! echo "$WORKWARRIOR_BASE $TASKRC $TASKDATA $TIMEWARRIORDB $WARRIOR_PROFILE" | grep -q "$profile_a"
}
