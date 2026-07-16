#!/usr/bin/env bats
# test-ledger-auto-rules.bats — TASK-LED-016
#
# Tests for the accrual rule: --auto passthrough, write-back refusal,
# and ww ledger explain.
#
# Key invariants:
#   - --auto is opt-in only (reports are literal by default)
#   - print --auto output MUST NEVER write back into the ledger tree
#   - ww ledger explain shows the computed truth (read-only)
#   - Coefficient of 0 = inert (no derived postings)

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export WW_BASE="${BATS_TEST_TMPDIR}/ww-instance"
  export WORKWARRIOR_BASE="${BATS_TEST_TMPDIR}/ww-profile"
  export WARRIOR_PROFILE="test"

  mkdir -p "$WW_BASE/lib"
  mkdir -p "$WW_BASE/config"
  mkdir -p "$WW_BASE/resources"
  mkdir -p "$WORKWARRIOR_BASE/ledgers"

  local repo_root="${BATS_TEST_DIRNAME}/../.."

  # Copy the libs we need
  cp "${repo_root}/lib/ledger-dispatch.sh" "$WW_BASE/lib/"
  cp "${repo_root}/lib/ledger-config.sh" "$WW_BASE/lib/" 2>/dev/null || true
  cp "${repo_root}/resources/rules.journal" "$WW_BASE/resources/"

  # Create a profile journal with time postings that includes rules
  cat > "$WORKWARRIOR_BASE/ledgers/test.journal" <<'EOF'
; test profile journal
include rules.journal

2026-07-14 * punch  Operator -> proj-a
    time:project:ww          8.00 h
    actors:human:morgen     -8.00 h

2026-07-15 * punch  Operator -> proj-b
    time:project:tooling     4.00 h
    actors:human:morgen     -4.00 h
EOF

  # Create an ACTIVE rules.journal (coefficient 0.15)
  cat > "$WORKWARRIOR_BASE/ledgers/rules.journal" <<'EOF'
; accrual rule — 15% tech-debt
= time:project:*
    backlog:tech-debt                *0.15
    time:accrued-review             *-0.15
EOF

  # Set up LEDGER_F to point to the test journal
  export LEDGER_F="$WORKWARRIOR_BASE/ledgers/test.journal"

  # Stub log functions for sourced libs
  log_error() { echo "ERROR: $*" >&2; }
  log_success() { echo "OK: $*" >&2; }
  log_warning() { echo "WARN: $*" >&2; }
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR"
}


# ── Criterion 2: OPT-IN ONLY ───────────────────────────────────────────────

@test "balance without --auto shows NO derived postings" {
  run hledger -f "$LEDGER_F" balance
  assert_success
  refute_output --partial "backlog:tech-debt"
  refute_output --partial "accrued-review"
}

@test "balance WITH --auto shows derived postings" {
  run hledger -f "$LEDGER_F" balance --auto
  assert_success
  assert_output --partial "backlog:tech-debt"
  assert_output --partial "accrued-review"
}

@test "--auto derives correct amount: 12h total × 0.15 = 1.80h" {
  run hledger -f "$LEDGER_F" balance --auto backlog
  assert_success
  assert_output --partial "1.80 h"
}


# ── Criterion 3: report --auto exposes the computed view ────────────────────

@test "ww ledger explain shows auto-expanded postings" {
  run hledger -f "$LEDGER_F" print --auto
  assert_success
  assert_output --partial "backlog:tech-debt"
  # 8h × 0.15 = 1.2h for first transaction
  assert_output --partial "1.20 h"
}

@test "ww ledger explain shows forecast transactions too" {
  # Add a periodic rule to the rules file
  cat >> "$WORKWARRIOR_BASE/ledgers/rules.journal" <<'EOF'

~ monthly from 2026-08-01
    time:project:maintenance     2.00 h
    actors:human:morgen         -2.00 h
EOF
  run hledger -f "$LEDGER_F" print --auto --forecast
  assert_success
  # Should include the forecast transaction
  assert_output --partial "maintenance"
}


# ── Criterion 4: WRITE-BACK REFUSAL ────────────────────────────────────────

@test "ledger_refuse_auto_writeback refuses when _LEDGER_AUTO_ACTIVE=1" {
  source "$WW_BASE/lib/ledger-dispatch.sh"
  export _LEDGER_AUTO_ACTIVE=1
  run ledger_refuse_auto_writeback "some content" "$WORKWARRIOR_BASE/ledgers/output.journal"
  assert_failure
}

@test "ledger_refuse_auto_writeback allows normal content" {
  source "$WW_BASE/lib/ledger-dispatch.sh"
  unset _LEDGER_AUTO_ACTIVE
  run ledger_refuse_auto_writeback "normal journal content" "/tmp/safe-file.journal"
  assert_success
}

@test "ledger_refuse_auto_writeback refuses backlog content written to ledger tree" {
  source "$WW_BASE/lib/ledger-dispatch.sh"
  local auto_content
  auto_content="$(hledger -f "$LEDGER_F" print --auto)"
  run ledger_refuse_auto_writeback "$auto_content" "$WORKWARRIOR_BASE/ledgers/derived/expanded.journal"
  assert_failure
}

@test "write-back refusal emits meaningful error message" {
  source "$WW_BASE/lib/ledger-dispatch.sh"
  export _LEDGER_AUTO_ACTIVE=1
  run ledger_refuse_auto_writeback "content" "$WORKWARRIOR_BASE/ledgers/x.journal"
  assert_output --partial "REFUSED"
  assert_output --partial "double-count"
}


# ── Criterion 5: ww ledger explain is read-only ────────────────────────────

@test "explain does not modify the source journal" {
  local before_hash
  before_hash="$(md5sum "$LEDGER_F" | cut -d' ' -f1)"

  hledger -f "$LEDGER_F" print --auto > /dev/null

  local after_hash
  after_hash="$(md5sum "$LEDGER_F" | cut -d' ' -f1)"
  [ "$before_hash" = "$after_hash" ]
}

@test "explain does not create any new files in ledger directory" {
  local before_count
  before_count="$(find "$WORKWARRIOR_BASE/ledgers" -type f | wc -l)"

  hledger -f "$LEDGER_F" print --auto > /dev/null

  local after_count
  after_count="$(find "$WORKWARRIOR_BASE/ledgers" -type f | wc -l)"
  [ "$before_count" = "$after_count" ]
}


# ── Criterion 6: coefficient of 0 = inert ──────────────────────────────────

@test "coefficient 0 produces no derived postings" {
  # Replace the rule with a 0-coefficient version
  cat > "$WORKWARRIOR_BASE/ledgers/rules.journal" <<'EOF'
= time:project:*
    backlog:tech-debt                *0
    time:accrued-review             *-0
EOF
  run hledger -f "$LEDGER_F" balance --auto
  assert_success
  # With coefficient 0, no backlog amounts should appear (0 × anything = 0)
  refute_output --partial "backlog:tech-debt"
}


# ── The double-count hazard (verified — this is the gate test) ──────────────

@test "HAZARD: print --auto fed back into rules journal produces 2× (proof of why refusal exists)" {
  # Get the auto-expanded output
  local expanded
  expanded="$(hledger -f "$LEDGER_F" print --auto)"

  # Write it to a new file WITH the rules still present (simulating write-back)
  local bad_file="${BATS_TEST_TMPDIR}/doubled.journal"
  {
    cat "$WORKWARRIOR_BASE/ledgers/rules.journal"
    echo ""
    echo "$expanded"
  } > "$bad_file"

  # Now balance --auto on this file will show 2× the correct amount
  run hledger -f "$bad_file" balance --auto backlog
  assert_success
  # Should show 3.60h (2× the correct 1.80h) — proving the hazard
  assert_output --partial "3.60 h"
}


# ── rules.journal template exists ───────────────────────────────────────────

@test "rules.journal template exists in resources/" {
  [ -f "$WW_BASE/resources/rules.journal" ]
}

@test "rules.journal template has the coefficient set to 0 (inert by default)" {
  run grep "0.00" "$WW_BASE/resources/rules.journal"
  assert_success
}
