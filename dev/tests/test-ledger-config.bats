#!/usr/bin/env bats
# TASK-LED-004: lib/ledger-config.sh — single owner of the ledgers.yaml contract.
# Schema: jrnl-style hybrid (see logs/decisions.md 2026-07-11).

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export WORKWARRIOR_BASE="$BATS_TEST_TMPDIR/base"
  mkdir -p "$WORKWARRIOR_BASE/ledgers"
  source "${BATS_TEST_DIRNAME}/../../lib/core-utils.sh"
  source "${BATS_TEST_DIRNAME}/../../lib/ledger-config.sh"
}

teardown() {
  [[ -n "${WORKWARRIOR_BASE:-}" && -d "$WORKWARRIOR_BASE" ]] && rm -rf "$WORKWARRIOR_BASE"
}

# Write a ledgers.yaml fixture from stdin (expands $WORKWARRIOR_BASE in the heredoc).
write_cfg() { cat > "$WORKWARRIOR_BASE/ledgers.yaml"; }

# ---------------------------------------------------------------------------
# ledger_cfg_path
# ---------------------------------------------------------------------------

@test "ledger_cfg_path echoes the active profile's ledgers.yaml" {
  run ledger_cfg_path
  assert_success
  assert_output "$WORKWARRIOR_BASE/ledgers.yaml"
}

# ---------------------------------------------------------------------------
# ledger_cfg_names
# ---------------------------------------------------------------------------

@test "ledger_cfg_names lists names excluding the reserved 'default'" {
  write_cfg <<EOF
ledgers:
  business: $WORKWARRIOR_BASE/ledgers/business.journal
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  scratch: $WORKWARRIOR_BASE/ledgers/scratch.journal
EOF
  run ledger_cfg_names
  assert_success
  [[ "$output" == *business* ]]
  [[ "$output" == *scratch* ]]
  [[ "$output" != *default* ]]
}

@test "ledger_cfg_names excludes hidden entries by default" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  secret:
    journal: $WORKWARRIOR_BASE/ledgers/secret.journal
    hidden: true
  business: $WORKWARRIOR_BASE/ledgers/business.journal
EOF
  run ledger_cfg_names
  assert_success
  [[ "$output" == *business* ]]
  [[ "$output" != *secret* ]]
}

@test "ledger_cfg_names --include-hidden includes hidden entries" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  secret:
    journal: $WORKWARRIOR_BASE/ledgers/secret.journal
    hidden: true
EOF
  run ledger_cfg_names --include-hidden
  assert_success
  [[ "$output" == *secret* ]]
}

# ---------------------------------------------------------------------------
# ledger_cfg_resolve  (string / map-journal / legacy-path forms)
# ---------------------------------------------------------------------------

@test "ledger_cfg_resolve returns the path for a string entry" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  scratch: $WORKWARRIOR_BASE/ledgers/scratch.journal
EOF
  run ledger_cfg_resolve scratch
  assert_success
  assert_output "$WORKWARRIOR_BASE/ledgers/scratch.journal"
}

@test "ledger_cfg_resolve returns journal: for a map entry" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  business:
    journal: $WORKWARRIOR_BASE/ledgers/business.journal
    commodity: USD
EOF
  run ledger_cfg_resolve business
  assert_success
  assert_output "$WORKWARRIOR_BASE/ledgers/business.journal"
}

@test "ledger_cfg_resolve reads a legacy path: entry (value on stdout)" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  legacy:
    path: $WORKWARRIOR_BASE/ledgers/legacy.journal
EOF
  local out
  out="$(ledger_cfg_resolve legacy 2>/dev/null)"
  assert_equal "$out" "$WORKWARRIOR_BASE/ledgers/legacy.journal"
}

@test "ledger_cfg_resolve warns (stderr) when reading a legacy path: entry" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  legacy:
    path: $WORKWARRIOR_BASE/ledgers/legacy.journal
EOF
  local err
  err="$(ledger_cfg_resolve legacy 2>&1 1>/dev/null)"
  [[ "$err" == *deprecated* ]]
}

@test "ledger_cfg_resolve returns 2 for an unknown name" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ledger_cfg_resolve nope
  assert_equal "$status" 2
}

# ---------------------------------------------------------------------------
# ledger_cfg_default_path  (by key, never by position)
# ---------------------------------------------------------------------------

@test "ledger_cfg_default_path resolves the 'default' key, not the first entry" {
  write_cfg <<EOF
ledgers:
  business: $WORKWARRIOR_BASE/ledgers/business.journal
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ledger_cfg_default_path
  assert_success
  assert_output "$WORKWARRIOR_BASE/ledgers/ww.journal"
}

# ---------------------------------------------------------------------------
# ledger_cfg_get_field / ledger_cfg_exists
# ---------------------------------------------------------------------------

@test "ledger_cfg_get_field returns a map field" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  business:
    journal: $WORKWARRIOR_BASE/ledgers/business.journal
    commodity: USD
EOF
  run ledger_cfg_get_field business commodity
  assert_success
  assert_output "USD"
}

@test "ledger_cfg_get_field is empty for a string entry" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  scratch: $WORKWARRIOR_BASE/ledgers/scratch.journal
EOF
  run ledger_cfg_get_field scratch commodity
  assert_success
  assert_output ""
}

@test "ledger_cfg_exists returns 0 for present, 1 for absent" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  scratch: $WORKWARRIOR_BASE/ledgers/scratch.journal
EOF
  run ledger_cfg_exists scratch
  assert_success
  run ledger_cfg_exists ghost
  assert_failure
}

# ---------------------------------------------------------------------------
# ledger_cfg_add  (emit-form policy + validation)
# ---------------------------------------------------------------------------

@test "ledger_cfg_add without metadata emits string form" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ledger_cfg_add scratch "$WORKWARRIOR_BASE/ledgers/scratch.journal"
  assert_success
  # inline string form: "  scratch: /path" on one line
  run grep -E "^  scratch: $WORKWARRIOR_BASE/ledgers/scratch.journal$" "$WORKWARRIOR_BASE/ledgers.yaml"
  assert_success
}

@test "ledger_cfg_add with --commodity emits map form using journal: (never path:)" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ledger_cfg_add business "$WORKWARRIOR_BASE/ledgers/business.journal" --commodity USD
  assert_success
  run grep -E "^    journal: " "$WORKWARRIOR_BASE/ledgers.yaml"
  assert_success
  run grep -E "commodity: USD" "$WORKWARRIOR_BASE/ledgers.yaml"
  assert_success
  run grep -E "path:" "$WORKWARRIOR_BASE/ledgers.yaml"
  assert_failure
}

@test "ledger_cfg_add rejects an invalid name" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ledger_cfg_add "bad name!" "$WORKWARRIOR_BASE/ledgers/x.journal"
  assert_failure
}

@test "ledger_cfg_add rejects an invalid role" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ledger_cfg_add sub "$WORKWARRIOR_BASE/ledgers/sub.journal" --role bogus
  assert_failure
}

# ---------------------------------------------------------------------------
# ledger_cfg_remove  (guards)
# ---------------------------------------------------------------------------

@test "ledger_cfg_remove refuses the reserved 'default'" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ledger_cfg_remove default
  assert_failure
  run grep -E "^  default:" "$WORKWARRIOR_BASE/ledgers.yaml"
  assert_success
}

@test "ledger_cfg_remove refuses an entry whose path equals default's path" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  primary: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ledger_cfg_remove primary
  assert_failure
}

@test "ledger_cfg_remove removes a normal entry" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  scratch: $WORKWARRIOR_BASE/ledgers/scratch.journal
EOF
  run ledger_cfg_remove scratch
  assert_success
  run ledger_cfg_exists scratch
  assert_failure
}

# ---------------------------------------------------------------------------
# ledger_cfg_rename
# ---------------------------------------------------------------------------

@test "ledger_cfg_rename refuses the reserved 'default'" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
EOF
  run ledger_cfg_rename default other
  assert_failure
}

@test "ledger_cfg_rename renames the key and preserves the path" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  business: $WORKWARRIOR_BASE/ledgers/business.journal
EOF
  run ledger_cfg_rename business biz
  assert_success
  run ledger_cfg_exists business
  assert_failure
  run ledger_cfg_resolve biz
  assert_success
  assert_output "$WORKWARRIOR_BASE/ledgers/business.journal"
}

# ---------------------------------------------------------------------------
# ledger_cfg_set_default / ledger_cfg_set_field
# ---------------------------------------------------------------------------

@test "ledger_cfg_set_default points default at a named ledger's path" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  business: $WORKWARRIOR_BASE/ledgers/business.journal
EOF
  run ledger_cfg_set_default business
  assert_success
  run ledger_cfg_default_path
  assert_output "$WORKWARRIOR_BASE/ledgers/business.journal"
}

@test "ledger_cfg_set_field upgrades a string entry to map form" {
  write_cfg <<EOF
ledgers:
  default: $WORKWARRIOR_BASE/ledgers/ww.journal
  business: $WORKWARRIOR_BASE/ledgers/business.journal
EOF
  run ledger_cfg_set_field business commodity USD
  assert_success
  run ledger_cfg_get_field business commodity
  assert_output "USD"
  # path preserved through the upgrade
  run ledger_cfg_resolve business
  assert_output "$WORKWARRIOR_BASE/ledgers/business.journal"
}
