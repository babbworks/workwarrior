#!/usr/bin/env bats

setup() {
  WW_SOURCE="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export WW_BASE="$WW_SOURCE"
  export HOME="$BATS_TEST_TMPDIR/home"
  export WW_CONFIG_HOME="$HOME/.config/ww"
  mkdir -p "$HOME"
}

@test "scoped operational capability discovery is headless" {
  run python3 "$WW_SOURCE/services/operations/cli.py" capabilities
  [ "$status" -eq 0 ]
  [[ "$output" == *'ww-operations-capabilities/v1'* ]]
}

@test "operations help declares explicit store and scope" {
  run bash "$WW_SOURCE/services/operations/operations.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *'--store'* ]]
  [[ "$output" == *'--scope-file'* ]]
}

@test "operational lifecycle and stream invariants hold in isolated fixtures" {
  run env PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$WW_SOURCE/dev/tests" -p 'test_*operations.py'
  [ "$status" -eq 0 ]
}

@test "mathematical lens contracts pass worked examples and invariant checks" {
  run env PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$WW_SOURCE/dev/tests" -p test_lens_mathematics.py
  [ "$status" -eq 0 ]
}

@test "native executable dispatcher exposes scoped operations" {
  [ -x "$WW_SOURCE/bin/ww" ]
  run "$WW_SOURCE/bin/ww" operations capabilities
  [ "$status" -eq 0 ]
  [[ "$output" == *'ww-operations-capabilities/v1'* ]]
}
