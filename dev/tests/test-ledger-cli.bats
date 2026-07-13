#!/usr/bin/env bats
# TASK-LED-005: runtime ledger CLI consumers repointed at lib/ledger-config.sh.
# e2e via bin/ww and the questions ledger handler.

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export WW_BASE="$(cd "$(dirname "$(dirname "$BATS_TEST_DIRNAME")")" && pwd)"
  export WORKWARRIOR_BASE="$BATS_TEST_TMPDIR/base"
  export WARRIOR_PROFILE="testp"
  mkdir -p "$WORKWARRIOR_BASE/ledgers"
  touch "$WORKWARRIOR_BASE/ledgers/ww.journal"
}

ww() { bash "$WW_BASE/bin/ww" "$@"; }
write_cfg() { cat > "$WORKWARRIOR_BASE/ledgers.yaml"; }

# ---------------------------------------------------------------------------
# cmd_ledger list  → ledger_cfg_names (hidden exclusion)
# ---------------------------------------------------------------------------

@test "ww ledger list excludes hidden ledgers" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  secret:
    journal: $WORKWARRIOR_BASE/ledgers/secret.journal
    hidden: true
  business: $WORKWARRIOR_BASE/ledgers/business.journal
EOF
  run ww ledger list
  assert_success
  [[ "$output" == *business* ]]
  [[ "$output" != *secret* ]]
}

@test "ww ledger list still shows a normal named ledger" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  business: $WORKWARRIOR_BASE/ledgers/business.journal
EOF
  run ww ledger list
  assert_success
  [[ "$output" == *business* ]]
  [[ "$output" != *default* ]]
}

# ---------------------------------------------------------------------------
# resource create ledger  → ledger_cfg_add (writes journal:, never path:)
# ---------------------------------------------------------------------------

@test "ww resource create ledger writes journal:/inline, never path:" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ww resource create ledger foo
  assert_success
  run grep -c 'path:' "$WORKWARRIOR_BASE/ledgers.yaml"
  assert_output "0"
}

@test "ww resource create ledger registers a resolvable entry" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ww resource create ledger biz
  assert_success
  run ww ledger list
  [[ "$output" == *biz* ]]
}

# ---------------------------------------------------------------------------
# ledger_handler.sh  → default resolved by reserved key, not values()[0]  (F4)
# ---------------------------------------------------------------------------

@test "ledger_handler resolves the reserved 'default' key, not the first entry" {
  command -v hledger >/dev/null || skip "hledger not installed"
  # 'business' is deliberately listed BEFORE 'default'
  write_cfg <<EOF
ledgers:
  business: $WORKWARRIOR_BASE/ledgers/business.journal
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  touch "$WORKWARRIOR_BASE/ledgers/business.journal"
  local tpl="$BATS_TEST_TMPDIR/tpl.json" ans="$BATS_TEST_TMPDIR/ans.json"
  cat > "$tpl" <<'JSON'
{"questions":[{"id":"q1","text":"Description"},{"id":"q2","text":"Amount"}]}
JSON
  cat > "$ans" <<'JSON'
{"answers":{"q1":"coffeemarker","q2":"3.50"}}
JSON
  run bash "$WW_BASE/services/questions/handlers/ledger_handler.sh" "$tpl" "$ans"
  assert_success
  # Transaction must land in default's file (ww.journal), not the first entry.
  run grep -c 'coffeemarker' "$WORKWARRIOR_BASE/ledgers/ww.journal"
  assert_output "1"
  run grep -c 'coffeemarker' "$WORKWARRIOR_BASE/ledgers/business.journal"
  assert_output "0"
}

# ---------------------------------------------------------------------------
# cmd_hledger_passthrough  → uses LEDGER_F, not a hard-coded default.journal (F1)
# ---------------------------------------------------------------------------

@test "ww hledger uses LEDGER_F when no -f is given" {
  command -v hledger >/dev/null || skip "hledger not installed"
  local j="$WORKWARRIOR_BASE/ledgers/ww.journal"
  printf '2026-01-01 seed\n    a:b   \$1\n    c:d\n' > "$j"
  export LEDGER_F="$j"
  run ww hledger files
  assert_success
  [[ "$output" == *"$j"* ]]
}

# ---------------------------------------------------------------------------
# LED-007: manual verbs set-default / check / report + doc reconcile (F5, F6)
# ---------------------------------------------------------------------------

@test "ww ledger set-default repoints the reserved default key" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  business: $WORKWARRIOR_BASE/ledgers/business.journal
EOF
  run ww ledger set-default business
  assert_success
  run grep -E "^  default: $WORKWARRIOR_BASE/ledgers/business.journal\$" "$WORKWARRIOR_BASE/ledgers.yaml"
  assert_success
}

@test "ww ledger set-default errors on an unknown ledger" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ww ledger set-default ghost
  assert_failure
}

@test "ww ledger check validates the default ledger" {
  command -v hledger >/dev/null || skip "hledger not installed"
  local j="$WORKWARRIOR_BASE/ledgers/ww.journal"
  printf '2026-01-01 seed\n    a:b   \$1\n    c:d\n' > "$j"
  export LEDGER_F="$j"
  run ww ledger check
  assert_success
}

@test "ww ledger new creates and registers a ledger (renamed from add)" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ww ledger new biz
  assert_success
  run ww ledger list
  [[ "$output" == *biz* ]]
}

@test "ww ledger remove unregisters a ledger and deletes its file" {
  local biz="$WORKWARRIOR_BASE/ledgers/biz.journal"
  touch "$biz"
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  biz: $biz
EOF
  run ww ledger remove biz
  assert_success
  run ww ledger list
  [[ "$output" != *biz* ]]
  [ ! -f "$biz" ]
}

@test "ww ledger rename changes the registry key" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  biz: $WORKWARRIOR_BASE/ledgers/biz.journal
EOF
  run ww ledger rename biz corp
  assert_success
  run ww ledger list
  [[ "$output" == *corp* ]]
  [[ "$output" != *biz* ]]
}

@test "ww ledger passes an unknown verb through to hledger (accounts)" {
  command -v hledger >/dev/null || skip "hledger not installed"
  local j="$WORKWARRIOR_BASE/ledgers/ww.journal"
  printf '2026-01-01 seed\n    a:b   \$1\n    c:d\n' > "$j"
  export LEDGER_F="$j"
  run ww ledger accounts
  assert_success
  [[ "$output" == *"a:b"* ]]
}

@test "ww ledger bal passes through to hledger balance" {
  command -v hledger >/dev/null || skip "hledger not installed"
  local j="$WORKWARRIOR_BASE/ledgers/ww.journal"
  printf '2026-01-01 seed\n    a:b   \$1\n    c:d\n' > "$j"
  export LEDGER_F="$j"
  run ww ledger bal
  assert_success
  [[ "$output" == *"a:b"* ]]
}

@test "bare ww ledger shows a balance overview" {
  command -v hledger >/dev/null || skip "hledger not installed"
  local j="$WORKWARRIOR_BASE/ledgers/ww.journal"
  printf '2026-01-01 seed\n    a:b   \$1\n    c:d\n' > "$j"
  export LEDGER_F="$j"
  run ww ledger
  assert_success
  [[ "$output" == *"a:b"* ]]
}

@test "ww ledger help lists management verbs (new, set-default)" {
  run ww ledger help
  assert_success
  [[ "$output" == *"new <name>"* ]]
  [[ "$output" == *set-default* ]]
  [[ "$output" != *"add <name>"* ]]
}

@test "command-syntax.yaml lists ledger management verbs, not add/check/report (F6)" {
  local f="$WW_BASE/dev/config/command-syntax.yaml"
  for v in new remove rename list set-default task inventory; do
    grep -q "ww ledger $v" "$f"
  done
  ! grep -q "ww ledger add " "$f"
  ! grep -q "ww ledger check" "$f"
  ! grep -q "ww ledger report" "$f"
}

@test "ww ledger -L selects a named ledger for passthrough" {
  command -v hledger >/dev/null || skip "hledger not installed"
  local wwj="$WORKWARRIOR_BASE/ledgers/ww.journal"
  local dj="$WORKWARRIOR_BASE/ledgers/disney.journal"
  printf '2026-01-01 x\n    a:main     \$1\n    c:d\n' > "$wwj"
  printf '2026-01-01 y\n    a:disney   \$5\n    c:d\n' > "$dj"
  export LEDGER_F="$wwj"
  write_cfg <<EOF
ledgers:
  default: $wwj
  disney: $dj
EOF
  run ww ledger -L disney accounts
  assert_success
  [[ "$output" == *"a:disney"* ]]
  [[ "$output" != *"a:main"* ]]
}

@test "ww ledger --ledger= form also selects a named ledger" {
  command -v hledger >/dev/null || skip "hledger not installed"
  local dj="$WORKWARRIOR_BASE/ledgers/disney.journal"
  printf '2026-01-01 y\n    a:disney   \$5\n    c:d\n' > "$dj"
  export LEDGER_F="$WORKWARRIOR_BASE/ledgers/ww.journal"
  printf '2026-01-01 x\n    a:main   \$1\n    c:d\n' > "$LEDGER_F"
  write_cfg <<EOF
ledgers:
  default: $LEDGER_F
  disney: $dj
EOF
  run ww ledger --ledger=disney accounts
  assert_success
  [[ "$output" == *"a:disney"* ]]
}

@test "ww ledger -L errors on an unknown ledger" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ww ledger -L ghost bal
  assert_failure
}

@test "ledger inventory reads ledgers.yaml, incl. non-guessable filenames (F3)" {
  command -v hledger >/dev/null || skip "hledger not installed"
  local base="$BATS_TEST_TMPDIR/inv"
  local pdir="$base/profiles/alpha"
  mkdir -p "$pdir/ledgers"
  printf '2026-01-01 x\n    assets:main   \$1\n    equity:opening\n' > "$pdir/ledgers/alpha.journal"
  # Registered ONLY in ledgers.yaml, under a filename that is NOT <profile>.journal:
  printf '2026-01-01 y\n    assets:bizcash   \$5\n    equity:opening\n' > "$pdir/ledgers/biz-2026.journal"
  cat > "$pdir/ledgers.yaml" <<EOF
ledgers:
  default: $pdir/ledgers/alpha.journal
  biz:
    journal: $pdir/ledgers/biz-2026.journal
EOF
  run env WW_BASE="$base" bash "$WW_BASE/scripts/build-ledger-inventory.sh" --print
  assert_success
  [[ "$output" == *"assets:bizcash"* ]]
}

@test "ww hledger falls back to the schema default when LEDGER_F is unset" {
  command -v hledger >/dev/null || skip "hledger not installed"
  local j="$WORKWARRIOR_BASE/ledgers/ww.journal"
  printf '2026-01-01 seed\n    a:b   \$1\n    c:d\n' > "$j"
  unset LEDGER_F
  cat > "$WORKWARRIOR_BASE/ledgers.yaml" <<EOF
ledgers:
  default: $j
EOF
  run ww hledger files
  assert_success
  [[ "$output" == *"$j"* ]]
}
