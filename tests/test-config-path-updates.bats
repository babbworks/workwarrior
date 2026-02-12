#!/usr/bin/env bats
# Property-Based Tests for Configuration Path Updates
# Feature: workwarrior-profiles-and-services
# Property 29: Configuration Path Updates

setup() {
  export TEST_MODE=1
  export TEST_WW_BASE="${BATS_TEST_TMPDIR}/ww-test-$$"
  export WW_BASE="$TEST_WW_BASE"
  export PROFILES_DIR="$TEST_WW_BASE/profiles"
  export RESOURCES_DIR="$TEST_WW_BASE/resources"

  mkdir -p "$PROFILES_DIR"
  mkdir -p "$RESOURCES_DIR"

  source "${BATS_TEST_DIRNAME}/../lib/core-utils.sh"
  source "${BATS_TEST_DIRNAME}/../lib/config-utils.sh"
}

teardown() {
  if [[ -d "$TEST_WW_BASE" ]]; then
    rm -rf "$TEST_WW_BASE"
  fi
}

random_string() {
  local length="${1:-8}"
  LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

@test "Property 29: update_paths_in_config updates taskrc paths (10 iterations)" {
  for i in {1..10}; do
    local profile_old="old-$(random_string 6)"
    local profile_new="new-$(random_string 6)"
    local old_base="$PROFILES_DIR/$profile_old"
    local new_base="$PROFILES_DIR/$profile_new"

    mkdir -p "$old_base/.task/hooks"
    mkdir -p "$new_base/.task/hooks"

    local taskrc="$old_base/.taskrc"
    cat > "$taskrc" << EOF
data.location=$old_base/.task
hooks.location=$old_base/.task/hooks
hooks=1
EOF

    run update_paths_in_config "$taskrc" "$old_base" "$new_base"
    [ "$status" -eq 0 ]

    grep -q "^data\.location=$new_base/.task$" "$taskrc"
    grep -q "^hooks\.location=$new_base/.task/hooks$" "$taskrc"
  done
}

@test "Property 29: update_paths_in_config updates jrnl.yaml paths (10 iterations)" {
  for i in {1..10}; do
    local profile_old="old-$(random_string 6)"
    local profile_new="new-$(random_string 6)"
    local old_base="$PROFILES_DIR/$profile_old"
    local new_base="$PROFILES_DIR/$profile_new"

    mkdir -p "$old_base/journals"
    mkdir -p "$new_base/journals"

    local jrnl_config="$old_base/jrnl.yaml"
    cat > "$jrnl_config" << EOF
journals:
  default: $old_base/journals/$profile_old.txt
  work: $old_base/journals/work.txt
editor: nano
EOF

    run update_paths_in_config "$jrnl_config" "$old_base" "$new_base"
    [ "$status" -eq 0 ]

    grep -q "$new_base/journals/$profile_old.txt" "$jrnl_config"
    grep -q "$new_base/journals/work.txt" "$jrnl_config"
  done
}

@test "Property 29: update_paths_in_config updates ledgers.yaml paths (10 iterations)" {
  for i in {1..10}; do
    local profile_old="old-$(random_string 6)"
    local profile_new="new-$(random_string 6)"
    local old_base="$PROFILES_DIR/$profile_old"
    local new_base="$PROFILES_DIR/$profile_new"

    mkdir -p "$old_base/ledgers"
    mkdir -p "$new_base/ledgers"

    local ledger_config="$old_base/ledgers.yaml"
    cat > "$ledger_config" << EOF
ledgers:
  default: $old_base/ledgers/$profile_old.journal
EOF

    run update_paths_in_config "$ledger_config" "$old_base" "$new_base"
    [ "$status" -eq 0 ]

    grep -q "$new_base/ledgers/$profile_old.journal" "$ledger_config"
  done
}
