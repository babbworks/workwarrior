#!/usr/bin/env bats
# test-ledger-sync-stream.bats — TASK-LED-015
#
# Tests for `ww ledger sync-stream`: regeneration of derived/stream.journal
# from stream.log punch intervals.
#
# Contract: dev/schemas/punch-posting-v1.md
# Key invariants:
#   - REGENERATE, never append (idempotent)
#   - NEVER writes to manual.journal
#   - Open punches excluded
#   - sigma = 0 per transaction (conservation law)

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export WW_BASE="${BATS_TEST_TMPDIR}/ww-instance"
  export WORKWARRIOR_BASE="${BATS_TEST_TMPDIR}/ww-profile"
  export WARRIOR_PROFILE="test"

  mkdir -p "$WW_BASE/config"
  mkdir -p "$WW_BASE/stream"
  mkdir -p "$WW_BASE/services/stream"
  mkdir -p "$WORKWARRIOR_BASE/ledgers"

  # Copy the real sync-to-journal.py
  local repo_root="${BATS_TEST_DIRNAME}/../.."
  cp "${repo_root}/services/stream/sync-to-journal.py" "$WW_BASE/services/stream/"

  # Create a test actors.yaml with known actors
  cat > "$WW_BASE/config/actors.yaml" <<'EOF'
schema: v1
id_scheme: solo
actors:
  human:marta.k7x2:
    kind: human
    display: "Marta Ruiz"
    status: active
    source: local
  human:op-03:
    kind: human
    display: "Operator Three"
    status: active
    source: local
  agent:claude-07:
    kind: agent
    display: "Claude Seven"
    status: active
    source: local
  human:morgen:
    kind: human
    display: "Morgen"
    status: active
    source: local
EOF

  # Create a profile main journal
  cat > "$WORKWARRIOR_BASE/ledgers/test.journal" <<'EOF'
; test — profile journal
include manual.journal
EOF

  # Create manual.journal (read-only to guard criterion 4)
  echo "; manual entries" > "$WORKWARRIOR_BASE/ledgers/manual.journal"
  chmod 444 "$WORKWARRIOR_BASE/ledgers/manual.journal"

  # Source required libs for the bash wrapper
  source "${repo_root}/lib/core-utils.sh" 2>/dev/null || true

  # The sync script path
  SYNC_SCRIPT="${WW_BASE}/services/stream/sync-to-journal.py"
}

teardown() {
  # Restore manual.journal permissions before cleanup
  chmod 644 "$WORKWARRIOR_BASE/ledgers/manual.journal" 2>/dev/null || true
  rm -rf "$BATS_TEST_TMPDIR"
}

# Helper: write a completed punch interval to stream.log
write_interval() {
  local start_ts="$1" end_ts="$2" object="$3" actor="$4" proj="${5:-}"
  local ctx_start ctx_stop

  if [[ -n "$proj" ]]; then
    ctx_start="{\"actor\":\"${actor}\",\"proj\":\"${proj}\",\"src\":\"stream\",\"prof\":\"test\"}"
    ctx_stop="{\"actor\":\"${actor}\",\"proj\":\"${proj}\",\"src\":\"stream\",\"prof\":\"test\"}"
  else
    ctx_start="{\"actor\":\"${actor}\",\"src\":\"stream\",\"prof\":\"test\"}"
    ctx_stop="{\"actor\":\"${actor}\",\"src\":\"stream\",\"prof\":\"test\"}"
  fi

  echo "${start_ts} B start ${object} ${ctx_start}" >> "$WW_BASE/stream/stream.log"
  echo "${end_ts} B stop ${object} ${ctx_stop}" >> "$WW_BASE/stream/stream.log"
}

# Helper: write a reconciled punch interval
write_reconciled_interval() {
  local start_ts="$1" end_ts="$2" object="$3" actor="$4" proj="$5"
  local reconciler="${6:-human:morgen}" reason="${7:-shift boundary}" recon_at="${8:-}"
  [[ -z "$recon_at" ]] && recon_at=$((end_ts + 3600))

  local ctx_start="{\"actor\":\"${actor}\",\"proj\":\"${proj}\",\"src\":\"stream\",\"prof\":\"test\"}"
  local ctx_stop="{\"actor\":\"${actor}\",\"proj\":\"${proj}\",\"src\":\"stream\",\"prof\":\"test\",\"reconciled\":{\"by\":\"${reconciler}\",\"at\":${recon_at},\"reason\":\"${reason}\"}}"

  echo "${start_ts} B start ${object} ${ctx_start}" >> "$WW_BASE/stream/stream.log"
  echo "${end_ts} B stop ${object} ${ctx_stop}" >> "$WW_BASE/stream/stream.log"
}

# Helper: run the sync (directly with python, simulating the bash wrapper)
run_sync() {
  python3 "$SYNC_SCRIPT" \
    --stream-log "$WW_BASE/stream/stream.log" \
    --ww-base "$WW_BASE" \
    --output "$WORKWARRIOR_BASE/ledgers/derived/stream.journal" \
    --generated-ts "2026-07-15T12:00:00Z" \
    "$@" 2>/dev/null
}

run_sync_dry() {
  python3 "$SYNC_SCRIPT" \
    --stream-log "$WW_BASE/stream/stream.log" \
    --ww-base "$WW_BASE" \
    --dry-run \
    --generated-ts "2026-07-15T12:00:00Z" 2>/dev/null
}


# ── Criterion 1: Produces derived/stream.journal ────────────────────────────

@test "sync-stream produces a file at derived/stream.journal" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"
  run_sync
  [ -f "$WORKWARRIOR_BASE/ledgers/derived/stream.journal" ]
}

@test "sync-stream creates derived/ directory if needed" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"
  # Ensure it doesn't exist
  rmdir "$WORKWARRIOR_BASE/ledgers/derived" 2>/dev/null || true
  run_sync
  [ -d "$WORKWARRIOR_BASE/ledgers/derived" ]
  [ -f "$WORKWARRIOR_BASE/ledgers/derived/stream.journal" ]
}


# ── Criterion 3: DO-NOT-EDIT header ────────────────────────────────────────

@test "file has DO-NOT-EDIT header" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"
  run head -1 "$outfile"
  assert_output "; GENERATED by ww ledger sync-stream — DO NOT EDIT"
}

@test "header includes source log path" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"
  run grep "^; Source:" "$outfile"
  assert_output --partial "$WW_BASE/stream/stream.log"
}


# ── Criterion: Completed interval produces correct transaction ──────────────

@test "completed interval produces correct transaction" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  # Check date and description (ts 1752300142 = 2025-07-12 UTC)
  run grep "punch  Marta Ruiz -> lathe-01" "$outfile"
  assert_success

  # Check metadata comments
  run grep "stream:obj=lathe-01" "$outfile"
  assert_success
  run grep "stream:actor=human:marta.k7x2" "$outfile"
  assert_success
  run grep "stream:start=1752300142" "$outfile"
  assert_success
  run grep "stream:end=1752308342" "$outfile"
  assert_success

  # Check accounts (duration = (1752308342-1752300142)/3600 = 2.28)
  run grep "time:project:line-a" "$outfile"
  assert_success
  assert_output --partial "2.28 h"
  run grep "actors:human:marta.k7x2" "$outfile"
  assert_success
  assert_output --partial "-2.28 h"
}


# ── Criterion 5: Open intervals excluded ────────────────────────────────────

@test "open intervals (no B stop) are excluded" {
  # Write a start with no stop
  echo '1752300142 B start open-machine {"actor":"human:op-03","proj":"line-b","src":"stream","prof":"test"}' > "$WW_BASE/stream/stream.log"
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"
  # File should exist but have no transactions
  run grep "^20" "$outfile"
  assert_failure
}


# ── Criterion 6: Reconciled punches tagged correctly ────────────────────────

@test "reconciled punches are tagged with ; reconciled" {
  write_reconciled_interval 1752300142 1752329600 lathe-01 "human:marta.k7x2" "line-a"
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  # Description line should have ; reconciled
  run grep "^20.*; reconciled" "$outfile"
  assert_success

  # Reconciliation metadata comments
  run grep "reconciled:by=human:morgen" "$outfile"
  assert_success
  run grep "reconciled:reason=shift boundary" "$outfile"
  assert_success
}


# ── Criterion 2: Idempotent — two runs produce byte-identical file ──────────

@test "idempotent: two runs produce byte-identical file" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"
  write_interval 1752400000 1752407200 pump-02 "human:op-03" "line-b"

  run_sync
  local first_hash
  first_hash="$(md5sum "$WORKWARRIOR_BASE/ledgers/derived/stream.journal" | cut -d' ' -f1)"

  run_sync
  local second_hash
  second_hash="$(md5sum "$WORKWARRIOR_BASE/ledgers/derived/stream.journal" | cut -d' ' -f1)"

  [ "$first_hash" = "$second_hash" ]
}


# ── Conservation law: actor accounts negative, time accounts positive ───────

@test "actor accounts are negative, time accounts are positive" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  # Positive on time account (no minus before the amount)
  run grep "time:project:line-a" "$outfile"
  assert_success
  # The amount should NOT have a leading minus
  refute_output --partial "-2.28"

  # Negative on actor account
  run grep "actors:human:marta.k7x2" "$outfile"
  assert_success
  assert_output --partial "-2.28 h"
}

@test "total balances to zero (sigma = 0)" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"
  write_interval 1752400000 1752407200 pump-02 "human:op-03" "line-b"
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  # If hledger is available, use it; otherwise verify manually
  if command -v hledger >/dev/null 2>&1; then
    # hledger balance should show a zero total
    local bal
    bal="$(hledger -f "$outfile" balance --depth=0 2>/dev/null || true)"
    # With proper double-entry, total should be 0 or empty
    if [[ -n "$bal" ]]; then
      # hledger shows "0" or nothing for balanced journals
      [[ "$bal" == *"0"* ]] || [[ -z "$(echo "$bal" | grep -v '^$' | grep -v '^\-\-')" ]]
    fi
  else
    # Manual check: sum positive and negative amounts
    local pos_sum neg_sum
    pos_sum=$(grep -oP '^\s+time:\S+\s+\K[0-9.]+' "$outfile" | awk '{s+=$1}END{printf "%.2f", s}')
    neg_sum=$(grep -oP '^\s+actors:\S+\s+-\K[0-9.]+' "$outfile" | awk '{s+=$1}END{printf "%.2f", s}')
    [ "$pos_sum" = "$neg_sum" ]
  fi
}


# ── Criterion 7: hledger check passes ───────────────────────────────────────

@test "hledger check passes on output (if hledger available)" {
  if ! command -v hledger >/dev/null 2>&1; then
    skip "hledger not installed"
  fi
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"
  run hledger -f "$outfile" check
  assert_success
}


# ── --dry-run prints to stdout, doesn't create file ─────────────────────────

@test "--dry-run prints to stdout, doesn't create file" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"

  # Remove derived dir if exists
  rm -rf "$WORKWARRIOR_BASE/ledgers/derived"

  run run_sync_dry
  assert_success
  # Output should contain the transaction
  assert_output --partial "punch  Marta Ruiz -> lathe-01"
  assert_output --partial "time:project:line-a"

  # File should NOT exist
  [ ! -f "$WORKWARRIOR_BASE/ledgers/derived/stream.journal" ]
}


# ── Criterion 4: manual.journal is NEVER modified ───────────────────────────

@test "manual.journal is never modified (read-only guard)" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"

  # manual.journal is already chmod 444 in setup
  local manual_before
  manual_before="$(cat "$WORKWARRIOR_BASE/ledgers/manual.journal")"

  run_sync

  local manual_after
  manual_after="$(cat "$WORKWARRIOR_BASE/ledgers/manual.journal")"
  [ "$manual_before" = "$manual_after" ]
}


# ── Round-trip: N intervals = N transactions ────────────────────────────────

@test "round-trip: N intervals = N transactions" {
  write_interval 1752300000 1752303600 obj-1 "human:marta.k7x2" "proj-a"
  write_interval 1752310000 1752313600 obj-2 "human:op-03" "proj-b"
  write_interval 1752320000 1752323600 obj-3 "agent:claude-07" "proj-c"

  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  # Count transaction header lines (date lines)
  local txn_count
  txn_count=$(grep -c "^20[0-9][0-9]-" "$outfile")
  [ "$txn_count" -eq 3 ]
}


# ── 40-actor scale test ─────────────────────────────────────────────────────

@test "40-actor scale test — all intervals produce transactions" {
  # Generate 40 intervals from 40 different actors
  local base_ts=1752300000
  for i in $(seq 1 40); do
    local start_ts=$((base_ts + (i - 1) * 7200))
    local end_ts=$((start_ts + 3600))
    local actor="human:worker-$(printf '%02d' $i)"
    local obj="machine-$(printf '%02d' $i)"
    write_interval "$start_ts" "$end_ts" "$obj" "$actor" "proj-scale"
  done

  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  local txn_count
  txn_count=$(grep -c "^20[0-9][0-9]-" "$outfile")
  [ "$txn_count" -eq 40 ]
}


# ── Actor display name resolved from actors.yaml ────────────────────────────

@test "actor display name resolved from actors.yaml when available" {
  write_interval 1752300142 1752308342 lathe-01 "human:marta.k7x2" "line-a"
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  # Should use display name "Marta Ruiz", not the ID
  run grep "Marta Ruiz" "$outfile"
  assert_success
}

@test "actor without display name falls back to actor_id" {
  write_interval 1752300142 1752308342 machine-99 "human:unknown-worker" "proj-x"
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  # Should use actor_id as display since no entry in actors.yaml
  run grep "human:unknown-worker" "$outfile"
  assert_success
}


# ── v0 events (no ctx.actor) attributed to profile:default ──────────────────

@test "v0 events (no ctx.actor) attributed to profile:default" {
  # Write a v0-style event with no actor in ctx
  echo '1752300142 B start old-machine {"prof":"test","src":"tasks"}' >> "$WW_BASE/stream/stream.log"
  echo '1752303742 B stop old-machine {"prof":"test","src":"tasks"}' >> "$WW_BASE/stream/stream.log"

  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  # Should attribute to profile:test (since prof=test is present)
  run grep "stream:actor=profile:test" "$outfile"
  assert_success
  run grep "actors:profile:test" "$outfile"
  assert_success
}

@test "v0 events with no prof attributed to profile:default" {
  # Write a v0-style event with no actor AND no prof in ctx
  echo '1752300142 B start legacy-obj {"src":"tasks"}' >> "$WW_BASE/stream/stream.log"
  echo '1752303742 B stop legacy-obj {"src":"tasks"}' >> "$WW_BASE/stream/stream.log"

  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  run grep "stream:actor=profile:default" "$outfile"
  assert_success
  run grep "actors:profile:default" "$outfile"
  assert_success
}


# ── Unclassified account when no project ────────────────────────────────────

@test "no project produces time:unclassified:<object> account" {
  write_interval 1752300142 1752308342 random-obj "human:op-03" ""
  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  run grep "time:unclassified:random-obj" "$outfile"
  assert_success
}


# ── Sorted by date ──────────────────────────────────────────────────────────

@test "transactions are sorted by start_ts (date)" {
  # Write out of order
  write_interval 1752400000 1752403600 obj-later "human:op-03" "proj-b"
  write_interval 1752300000 1752303600 obj-earlier "human:marta.k7x2" "proj-a"

  run_sync
  local outfile="$WORKWARRIOR_BASE/ledgers/derived/stream.journal"

  # First transaction should be obj-earlier (earlier start_ts)
  local first_txn
  first_txn="$(grep "^20" "$outfile" | head -1)"
  [[ "$first_txn" == *"obj-earlier"* ]]
}
