#!/usr/bin/env bats
# ww timew extensions — help + list (no network / no nim build)
#
# Run: bats tests/test-timew-extensions.bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  export TEST_WW_BASE
  TEST_WW_BASE="$(mktemp -d)"
  # Minimal ww tree: ww needs lib/ so validate_profile_name and profile resolution work
  cp -a "${REPO_ROOT}/lib" "${TEST_WW_BASE}/lib"
  mkdir -p "${TEST_WW_BASE}/profiles/twtest/.timewarrior"
  echo 'data.location=.task' > "${TEST_WW_BASE}/profiles/twtest/.taskrc"
  mkdir -p "${TEST_WW_BASE}/profiles/twtest/.task"
}

teardown() {
  rm -rf "${TEST_WW_BASE}"
}

@test "timew: extensions help shows billable attribution" {
  run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE -u TIMEWARRIORDB \
    WW_BASE="${REPO_ROOT}" bash "${REPO_ROOT}/bin/ww" timew extensions help
  assert_success
  assert_output --partial "timew-billable"
  assert_output --partial "trev-dev"
}

@test "timew: extensions list with --profile shows empty extensions dir" {
  run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE -u TIMEWARRIORDB \
    WW_BASE="${TEST_WW_BASE}" bash "${REPO_ROOT}/bin/ww" --profile twtest timew extensions list
  assert_success
  assert_output --partial "TIMEWARRIORDB="
  assert_output --partial "no executable extensions"
}

@test "timew: extensions list --json returns array" {
  run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE -u TIMEWARRIORDB \
    WW_BASE="${TEST_WW_BASE}" bash "${REPO_ROOT}/bin/ww" --profile twtest --json timew extensions list
  assert_success
  assert_output --partial "["
  assert_output --partial "]"
}
