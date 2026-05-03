#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export TEST_HOME="${BATS_TEST_TMPDIR}/home-$$"
  export HOME="$TEST_HOME"
  export WW_BASE="${BATS_TEST_DIRNAME}/.."
  export WW_CONFIG_HOME="$TEST_HOME/.config/ww"
  export WW_REGISTRY_DIR="$WW_CONFIG_HOME/registry"
  mkdir -p "$HOME" "$WW_REGISTRY_DIR"
  touch "$HOME/.bashrc"
}

@test "ww config set updates runtime policy" {
  run "$WW_BASE/bin/ww" config set resume-last off
  assert_success

  run "$WW_BASE/bin/ww" config show
  assert_success
  assert_output --partial "resume_last=off"
}

@test "instance list hides hidden by default" {
  "$WW_BASE/bin/ww" instance register vis "$WW_BASE" visible >/dev/null
  "$WW_BASE/bin/ww" instance register hid "$WW_BASE" hidden >/dev/null

  run "$WW_BASE/bin/ww" instance list
  assert_success
  assert_output --partial "vis"
  refute_output --partial "hid"

  run "$WW_BASE/bin/ww" instance list --all
  assert_success
  assert_output --partial "hid"
}

@test "instance aliases sync writes shell aliases" {
  "$WW_BASE/bin/ww" instance register test "$WW_BASE" visible >/dev/null

  run "$WW_BASE/bin/ww" instance aliases sync
  assert_success

  run grep -F "alias test='ww test'" "$HOME/.bashrc"
  assert_success

  run grep -F "alias test_unlock='ww unlock test'" "$HOME/.bashrc"
  assert_success
}

@test "non-hardened instance does not require unlock" {
  "$WW_BASE/bin/ww" instance register plaini "$WW_BASE" visible multi >/dev/null
  run "$WW_BASE/bin/ww" unlock plaini
  assert_success
  assert_output --partial "does not require unlock"
}
