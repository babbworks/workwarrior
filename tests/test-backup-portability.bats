#!/usr/bin/env bats
# Property-Based Tests for Backup Portability
# Feature: workwarrior-profiles-and-services
# Property 33: Backup Portability

setup() {
  export TEST_MODE=1
  export TEST_WW_BASE="${BATS_TEST_TMPDIR}/ww-test-$$"
  export WW_BASE="$TEST_WW_BASE"
  export PROFILES_DIR="$TEST_WW_BASE/profiles"
  export RESOURCES_DIR="$TEST_WW_BASE/resources"

  mkdir -p "$PROFILES_DIR"
  mkdir -p "$RESOURCES_DIR"

  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
  source "${BATS_TEST_DIRNAME}/../lib/profile-manager.sh"
  source "${BATS_TEST_DIRNAME}/../lib/config-utils.sh"
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
  install_timewarrior_hook "$profile_name"
}

@test "Property 33: Backup archive is portable and restorable (5 iterations)" {
  for i in {1..5}; do
    local profile_name="portable-$i"
    create_profile_with_configs "$profile_name"

    local backup_dir="${BATS_TEST_TMPDIR}/backups"
    mkdir -p "$backup_dir"

    # Create backup using the management script
    run env WW_BASE="$TEST_WW_BASE" PROFILES_DIR="$PROFILES_DIR" \
      bash "${BATS_TEST_DIRNAME}/../scripts/manage-profiles.sh" backup "$profile_name" "$backup_dir"
    [ "$status" -eq 0 ]

    # Find backup file
    local backup_file
    backup_file=$(ls -1 "$backup_dir"/"${profile_name}"-backup-*.tar.gz | head -n1)
    [ -f "$backup_file" ]

    # Verify archive entries are relative (no absolute paths)
    ! tar -tzf "$backup_file" | grep -qE '^/'

    # Restore to a different base directory
    local restore_base="${BATS_TEST_TMPDIR}/restore-$i"
    mkdir -p "$restore_base"
    tar -xzf "$backup_file" -C "$restore_base"

    local restored_profile="$restore_base/$(basename "$PROFILES_DIR")/$profile_name"
    [ -d "$restored_profile" ]
    [ -f "$restored_profile/.taskrc" ]
    [ -f "$restored_profile/jrnl.yaml" ]
    [ -f "$restored_profile/ledgers.yaml" ]

    # Update paths in configs to new base (simulates portability)
    update_paths_in_config "$restored_profile/.taskrc" "$PROFILES_DIR/$profile_name" "$restored_profile"
    update_paths_in_config "$restored_profile/jrnl.yaml" "$PROFILES_DIR/$profile_name" "$restored_profile"
    update_paths_in_config "$restored_profile/ledgers.yaml" "$PROFILES_DIR/$profile_name" "$restored_profile"

    grep -q "$restored_profile/.task" "$restored_profile/.taskrc"
    grep -q "$restored_profile/journals" "$restored_profile/jrnl.yaml"
    grep -q "$restored_profile/ledgers" "$restored_profile/ledgers.yaml"
  done
}
