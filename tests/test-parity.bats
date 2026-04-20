#!/usr/bin/env bats
# Gate C — system/scripts/check-parity.sh (TASK-QUAL-002)

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "parity: check-parity.sh exits 0 against repo CSSOT" {
  run bash "${BATS_TEST_DIRNAME}/../system/scripts/check-parity.sh"
  assert_success
  assert_output --partial "check-parity: OK"
}
