#!/usr/bin/env bats
# TASK-LED-010: the `l` shell function routes through lib/ledger-dispatch.sh
# (reserved words + hledger passthrough + -L selector + bare->balance).

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export WW_BASE="$(cd "$(dirname "$(dirname "$BATS_TEST_DIRNAME")")" && pwd)"
  export WORKWARRIOR_BASE="$BATS_TEST_TMPDIR/base"
  export WARRIOR_PROFILE="testp"
  mkdir -p "$WORKWARRIOR_BASE/ledgers"
  source "$WW_BASE/lib/shell-integration.sh"
}

seed() {
  printf '2026-01-01 x\n    a:main     \$1\n    c:d\n' > "$WORKWARRIOR_BASE/ledgers/ww.journal"
  printf '2026-01-01 y\n    a:disney   \$5\n    c:d\n' > "$WORKWARRIOR_BASE/ledgers/disney.journal"
  export LEDGER_F="$WORKWARRIOR_BASE/ledgers/ww.journal"
  cat > "$WORKWARRIOR_BASE/ledgers.yaml" <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  disney: $WORKWARRIOR_BASE/ledgers/disney.journal
EOF
}

@test "l passes through to hledger on the default ledger" {
  command -v hledger >/dev/null || skip "hledger not installed"
  seed
  run l accounts
  assert_success
  [[ "$output" == *"a:main"* ]]
}

@test "l -L selects a named ledger" {
  command -v hledger >/dev/null || skip "hledger not installed"
  seed
  run l -L disney accounts
  assert_success
  [[ "$output" == *"a:disney"* ]]
  [[ "$output" != *"a:main"* ]]
}

@test "bare l shows a balance overview (not hledger's command list)" {
  command -v hledger >/dev/null || skip "hledger not installed"
  seed
  run l
  assert_success
  [[ "$output" == *"a:main"* ]]
}
