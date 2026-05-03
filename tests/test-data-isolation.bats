#!/usr/bin/env bats
# Property-Based Tests for Data Isolation and Integrity
# Feature: workwarrior-profiles-and-services
# Property 30: Data Isolation

setup() {
  export TEST_MODE=1
  export TEST_WW_BASE="${BATS_TEST_TMPDIR}/ww-test-$$"
  export WW_BASE="$TEST_WW_BASE"
  export PROFILES_DIR="$TEST_WW_BASE/profiles"
  export SERVICES_DIR="$TEST_WW_BASE/services"
  export RESOURCES_DIR="$TEST_WW_BASE/resources"

  mkdir -p "$PROFILES_DIR"
  mkdir -p "$SERVICES_DIR"
  mkdir -p "$RESOURCES_DIR"

  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
  source "${BATS_TEST_DIRNAME}/../lib/profile-manager.sh"
  source "${BATS_TEST_DIRNAME}/../lib/shell-integration.sh"

  export STUB_BIN="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "$STUB_BIN"

  export JRNL_LOG="${BATS_TEST_TMPDIR}/jrnl.log"
  export HLEDGER_LOG="${BATS_TEST_TMPDIR}/hledger.log"

  cat > "$STUB_BIN/jrnl" << 'EOF'
#!/usr/bin/env bash
echo "jrnl $*" >> "$JRNL_LOG"
exit 0
EOF

  cat > "$STUB_BIN/hledger" << 'EOF'
#!/usr/bin/env bash
echo "hledger $*" >> "$HLEDGER_LOG"
exit 0
EOF

  chmod +x "$STUB_BIN/jrnl" "$STUB_BIN/hledger"
  export PATH="$STUB_BIN:$PATH"
}

teardown() {
  if [[ -d "$TEST_WW_BASE" ]]; then
    rm -rf "$TEST_WW_BASE"
  fi
}

create_profile_with_configs() {
  local profile_name="$1"
  create_profile_directories "$profile_name"
  create_taskrc "$profile_name"
  create_journal_config "$profile_name"
  create_ledger_config "$profile_name"
}

@test "Property 30: Active profile operations use only that profile's paths" {
  local profile_a="alpha"
  local profile_b="beta"

  create_profile_with_configs "$profile_a"
  create_profile_with_configs "$profile_b"

  # Activate profile A
  use_task_profile "$profile_a"
  [ "$WARRIOR_PROFILE" = "$profile_a" ]
  [[ "$WORKWARRIOR_BASE" == "$PROFILES_DIR/$profile_a" ]]
  [[ "$TASKRC" == "$PROFILES_DIR/$profile_a/.taskrc" ]]
  [[ "$TASKDATA" == "$PROFILES_DIR/$profile_a/.task" ]]
  [[ "$TIMEWARRIORDB" == "$PROFILES_DIR/$profile_a/.timewarrior" ]]

  # Invoke jrnl and hledger via global functions
  j "test entry"
  l balance

  # Verify commands used profile A paths
  grep -q "--config-file $PROFILES_DIR/$profile_a/jrnl.yaml" "$JRNL_LOG"
  grep -q "-f $PROFILES_DIR/$profile_a/ledgers/$profile_a.journal" "$HLEDGER_LOG"
  ! grep -q "$PROFILES_DIR/$profile_b" "$JRNL_LOG"
  ! grep -q "$PROFILES_DIR/$profile_b" "$HLEDGER_LOG"

  # Switch to profile B and repeat
  use_task_profile "$profile_b"
  j "another entry"
  l balance

  grep -q "--config-file $PROFILES_DIR/$profile_b/jrnl.yaml" "$JRNL_LOG"
  grep -q "-f $PROFILES_DIR/$profile_b/ledgers/$profile_b.journal" "$HLEDGER_LOG"
}
