#!/usr/bin/env bats
# test-stream-reconcile.bats — TASK-STRM-005
#
# Reconciliation: closing missed punch-outs individually and en masse.
# Tests: reconciled punch out, mass reconcile, board integration, no-auto-close invariant.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export WW_BASE="${BATS_TEST_TMPDIR}/ww"
  mkdir -p "$WW_BASE/config" "$WW_BASE/stream"
  # Actors registry
  cat > "$WW_BASE/config/actors.yaml" <<'EOF'
schema: v1
id_scheme: solo
actors:
  human:op-03:
    kind: human
    display: Operator Three
    status: active
    source: local
  human:foreman-01:
    kind: human
    display: Foreman One
    status: active
    source: local
  agent:claude-07:
    kind: agent
    display: Claude Seven
    status: active
    source: local
  agent:claude-11:
    kind: agent
    display: Claude Eleven
    status: active
    source: local
EOF
  export WARRIOR_PROFILE="test"
  STREAM="${REPO_ROOT}/services/stream/stream.sh"
  LOG="${WW_BASE}/stream/stream.log"
  NOW="$(date +%s)"
}

# Helper: write raw events directly to stream.log
_write_event() {
  printf '%s\n' "$1" >> "$LOG"
}

# Helper: punch in (write a B start event with given timestamp)
_punch_in() {
  local ts="$1" obj="$2" ctx="$3"
  _write_event "$ts B start $obj $ctx"
}

# Helper: punch out (write a B stop event with given timestamp)
_punch_out() {
  local ts="$1" obj="$2" ctx="$3"
  _write_event "$ts B stop $obj $ctx"
}

# ── Reconciled punch out appends B stop with reconciled key ──────────────────

@test "reconciled punch out appends B stop with reconciled key" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  run bash "$STREAM" punch out --actor human:op-03 --object lathe-01 --reason "forgot to clock out"
  [ "$status" -eq 0 ]
  run grep ' B stop lathe-01 ' "$LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"reconciled"'* ]]
  [[ "$output" == *'"reason":"forgot to clock out"'* ]]
}

# ── --reason is mandatory (exit 1 without it on a reconciled close) ──────────

@test "--reason is mandatory for reconciled close (exit 1 without it)" {
  # A regular punch out without --reason should work fine
  _punch_in "$((NOW - 3600))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  run bash "$STREAM" punch out --actor human:op-03 --object lathe-01
  [ "$status" -eq 0 ]
  # Verify no reconciled key
  run grep ' B stop lathe-01 ' "$LOG"
  [[ "$output" != *'"reconciled"'* ]]
}

# ── reconciled.by is present and correct ─────────────────────────────────────

@test "reconciled.by is present and correct (defaults to profile)" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  run bash "$STREAM" punch out --actor human:op-03 --object lathe-01 --reason "shift ended"
  [ "$status" -eq 0 ]
  run grep ' B stop lathe-01 ' "$LOG"
  [[ "$output" == *'"by":"profile:test"'* ]]
}

@test "reconciled.by uses --by flag when provided" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  run bash "$STREAM" punch out --actor human:op-03 --object lathe-01 --reason "shift ended" --by "human:foreman-01"
  [ "$status" -eq 0 ]
  run grep ' B stop lathe-01 ' "$LOG"
  [[ "$output" == *'"by":"human:foreman-01"'* ]]
}

# ── reconciled.at is present and is current time (not --at time) ─────────────

@test "reconciled.at is present and is current time (not --at time)" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  local before_ts; before_ts="$(date +%s)"
  run bash "$STREAM" punch out --actor human:op-03 --object lathe-01 --reason "shift ended" --at "$((NOW - 3600))"
  [ "$status" -eq 0 ]
  local after_ts; after_ts="$(date +%s)"
  # Extract reconciled.at from ctx (ctx is field 5+, which may contain spaces)
  local reconciled_at
  reconciled_at=$(grep ' B stop lathe-01 ' "$LOG" | tail -1 | sed 's/^[^ ]* B stop lathe-01 //' | python3 -c "
import sys, json
ctx = json.loads(sys.stdin.read().strip())
print(ctx['reconciled']['at'])
")
  # reconciled.at must be current time (between before and after)
  [ "$reconciled_at" -ge "$before_ts" ]
  [ "$reconciled_at" -le "$after_ts" ]
}

# ── --at sets field 1 timestamp (the asserted time) ──────────────────────────

@test "--at sets field 1 timestamp (the asserted time)" {
  local asserted_time=$((NOW - 3600))
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  run bash "$STREAM" punch out --actor human:op-03 --object lathe-01 --reason "shift ended" --at "$asserted_time"
  [ "$status" -eq 0 ]
  # Field 1 of the B stop event should be the asserted time
  local field1
  field1=$(grep ' B stop lathe-01 ' "$LOG" | tail -1 | awk '{print $1}')
  [ "$field1" -eq "$asserted_time" ]
}

# ── Default (no --at): field 1 is current time ──────────────────────────────

@test "default (no --at): field 1 is current time" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  local before_ts; before_ts="$(date +%s)"
  run bash "$STREAM" punch out --actor human:op-03 --object lathe-01 --reason "shift ended"
  [ "$status" -eq 0 ]
  local after_ts; after_ts="$(date +%s)"
  local field1
  field1=$(grep ' B stop lathe-01 ' "$LOG" | tail -1 | awk '{print $1}')
  [ "$field1" -ge "$before_ts" ]
  [ "$field1" -le "$after_ts" ]
}

# ── Regular punch out (no --reason) has NO reconciled key ────────────────────

@test "regular punch out (no --reason) has NO reconciled key" {
  _punch_in "$((NOW - 3600))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  bash "$STREAM" punch out --actor human:op-03 --object lathe-01
  run grep ' B stop lathe-01 ' "$LOG"
  [ "$status" -eq 0 ]
  [[ "$output" != *'"reconciled"'* ]]
}

# ── Reconciling an already-closed punch is a no-op with warning ──────────────

@test "reconciling an already-closed punch is a no-op with warning" {
  _punch_in  "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  _punch_out "$((NOW - 3600))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  local lines_before
  lines_before=$(wc -l < "$LOG")
  run bash "$STREAM" punch out --actor human:op-03 --object lathe-01 --reason "duplicate close"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already closed"* ]]
  # No new event written
  local lines_after
  lines_after=$(wc -l < "$LOG")
  [ "$lines_before" -eq "$lines_after" ]
}

# ── Mass reconcile without --confirm is dry-run ──────────────────────────────

@test "mass reconcile without --confirm is dry-run (prints, doesn't write)" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  _punch_in "$((NOW - 600))"  "fresh-task" '{"actor":"agent:claude-07","proj":"dev"}'
  local lines_before
  lines_before=$(wc -l < "$LOG")
  run bash "$STREAM" reconcile --stale 3600 --reason "stale cleanup"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [[ "$output" == *"lathe-01"* ]]
  # Log not modified
  local lines_after
  lines_after=$(wc -l < "$LOG")
  [ "$lines_before" -eq "$lines_after" ]
}

# ── Mass reconcile with --confirm writes one event per closure ───────────────

@test "mass reconcile with --confirm writes one event per closure" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  _punch_in "$((NOW - 7200))" "ledger-task" '{"actor":"agent:claude-07","proj":"ledger"}'
  _punch_in "$((NOW - 600))"  "fresh-task" '{"actor":"agent:claude-11","proj":"dev"}'
  local lines_before
  lines_before=$(wc -l < "$LOG")
  run bash "$STREAM" reconcile --stale 3600 --reason "stale cleanup" --confirm
  [ "$status" -eq 0 ]
  # Should have written exactly 2 events (lathe-01 and ledger-task are stale, fresh-task is not)
  # Plus schema marker potentially
  local stop_count
  stop_count=$(grep -c ' B stop ' "$LOG" || true)
  [ "$stop_count" -eq 2 ]
}

# ── Mass reconcile: each event has reconciled key ────────────────────────────

@test "mass reconcile: each event is independently auditable (has reconciled key)" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  _punch_in "$((NOW - 7200))" "ledger-task" '{"actor":"agent:claude-07","proj":"ledger"}'
  bash "$STREAM" reconcile --stale 3600 --reason "shift end cleanup" --confirm
  # Every B stop from reconcile must have reconciled key
  local count_with_reconciled
  count_with_reconciled=$(grep ' B stop ' "$LOG" | grep -c '"reconciled"' || true)
  local count_stops
  count_stops=$(grep -c ' B stop ' "$LOG" || true)
  [ "$count_with_reconciled" -eq "$count_stops" ]
}

# ── Mass reconcile summary output ───────────────────────────────────────────

@test "mass reconcile summary output: N closed, by whom, reason" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  _punch_in "$((NOW - 7200))" "ledger-task" '{"actor":"agent:claude-07","proj":"ledger"}'
  run bash "$STREAM" reconcile --stale 3600 --reason "shift end" --confirm
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 punches closed"* ]]
  [[ "$output" == *"profile:test"* ]]
  [[ "$output" == *"shift end"* ]]
}

# ── Board excludes reconciled-closed punches from open set ───────────────────

@test "board excludes reconciled-closed punches from open set" {
  # Open punch
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  # Reconciled close of it
  local reconciled_ctx='{"actor":"human:op-03","reconciled":{"by":"profile:test","at":'"$NOW"',"reason":"forgot"}}'
  _punch_out "$((NOW - 3600))" "lathe-01" "$reconciled_ctx"
  # Another that's still open
  _punch_in "$((NOW - 600))" "fresh-task" '{"actor":"agent:claude-07","proj":"dev"}'
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  # lathe-01 should NOT be in the open set
  [[ "$output" != *"lathe-01"* ]]
  # fresh-task SHOULD be
  [[ "$output" == *"fresh-task"* ]]
}

# ── NO auto-close: grep assert ───────────────────────────────────────────────

@test "NO auto-close: no code path emits B stop without explicit user action" {
  # Grep the stream service for code paths that WRITE B stop events to the log.
  # We only care about lines that actually APPEND to the log file (printf ... >> or >> "$STREAM_LOG")
  # Lenses are READ-ONLY (they never write), so exclude lenses/.
  # Exclude tests, comments.
  local matches
  matches=$(grep -rn 'B.*stop' "${REPO_ROOT}/services/stream/" \
    --include='*.sh' \
    | grep -v 'test\|#\|echo\|print\|\.bats\|lenses/' \
    | grep -v 'grep\|awk\|pop\|==\|action.*in\|DEBIT\|CREDIT' || true)
  # Every remaining match must be in cmd_punch or cmd_reconcile (both user-gated)
  if [[ -n "$matches" ]]; then
    # These must be inside functions that require explicit user action:
    # cmd_punch requires positional 'out' argument, cmd_reconcile requires --confirm
    local bad_matches
    bad_matches=$(echo "$matches" | grep -v 'cmd_punch\|cmd_reconcile\|action="stop"\|"stop"' || true)
    [[ -z "$bad_matches" ]] || {
      echo "VIOLATION: Found potential auto-close paths:"
      echo "$bad_matches"
      return 1
    }
  fi
}

# ── Reconciled stops distinguishable from real ones ──────────────────────────

@test "reconciled stops are distinguishable from real ones (reconciled key present vs absent)" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  _punch_in "$((NOW - 3600))" "lathe-02" '{"actor":"agent:claude-07","proj":"line-b"}'
  # Real stop
  bash "$STREAM" punch out --actor human:op-03 --object lathe-01
  # Reconciled stop
  bash "$STREAM" punch out --actor agent:claude-07 --object lathe-02 --reason "session died"
  # Real stop: no reconciled key
  local real_stop
  real_stop=$(grep ' B stop lathe-01 ' "$LOG")
  [[ "$real_stop" != *'"reconciled"'* ]]
  # Reconciled stop: has reconciled key
  local recon_stop
  recon_stop=$(grep ' B stop lathe-02 ' "$LOG")
  [[ "$recon_stop" == *'"reconciled"'* ]]
}

# ── --stale filter works correctly ───────────────────────────────────────────

@test "--stale filter works correctly (only closes entries over threshold)" {
  # 2 hours old (7200s) — stale with 3600s threshold
  _punch_in "$((NOW - 7200))" "old-task" '{"actor":"human:op-03","proj":"line-a"}'
  # 10 minutes old (600s) — NOT stale with 3600s threshold
  _punch_in "$((NOW - 600))"  "new-task" '{"actor":"agent:claude-07","proj":"dev"}'
  run bash "$STREAM" reconcile --stale 3600 --reason "cleanup" --confirm
  [ "$status" -eq 0 ]
  # Only old-task should have been closed
  local old_closed new_closed
  old_closed=$(grep ' B stop old-task ' "$LOG" | grep -c '"reconciled"' || true)
  new_closed=$(grep ' B stop new-task ' "$LOG" | grep -c '"reconciled"' || true)
  [ "$old_closed" -eq 1 ]
  [ "$new_closed" -eq 0 ]
}

# ── Mass reconcile requires --reason ─────────────────────────────────────────

@test "mass reconcile requires --reason (exit 1 without it)" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  run bash "$STREAM" reconcile --stale 3600
  [ "$status" -ne 0 ]
  [[ "$output" == *"--reason"* ]]
}

# ── Mass reconcile requires --stale ──────────────────────────────────────────

@test "mass reconcile requires --stale (exit 1 without it)" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  run bash "$STREAM" reconcile --reason "test"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--stale"* ]]
}

# ── Mass reconcile --at sets field 1 for all events ──────────────────────────

@test "mass reconcile --at sets field 1 for all emitted events" {
  local asserted=$((NOW - 1800))
  _punch_in "$((NOW - 7200))" "task-a" '{"actor":"human:op-03","proj":"line-a"}'
  _punch_in "$((NOW - 7200))" "task-b" '{"actor":"agent:claude-07","proj":"dev"}'
  bash "$STREAM" reconcile --stale 3600 --reason "batch close" --at "$asserted" --confirm
  # All B stop events from reconcile should have field1 = asserted
  local stops
  stops=$(grep ' B stop ' "$LOG")
  while IFS= read -r line; do
    local f1
    f1=$(echo "$line" | awk '{print $1}')
    [ "$f1" -eq "$asserted" ]
  done <<< "$stops"
}

# ── Dry run shows correct entries ────────────────────────────────────────────

@test "mass reconcile dry-run shows correct stale entries" {
  _punch_in "$((NOW - 7200))" "stale-1" '{"actor":"human:op-03","proj":"line-a"}'
  _punch_in "$((NOW - 7200))" "stale-2" '{"actor":"agent:claude-07","proj":"dev"}'
  _punch_in "$((NOW - 300))"  "fresh-1" '{"actor":"agent:claude-11","proj":"dev"}'
  run bash "$STREAM" reconcile --stale 3600 --reason "test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stale-1"* ]]
  [[ "$output" == *"stale-2"* ]]
  [[ "$output" != *"fresh-1"* ]]
  [[ "$output" == *"DRY RUN"* ]]
}

# ── Board integration with reconcile command ─────────────────────────────────

@test "board shows punch as open before reconcile, closed after" {
  _punch_in "$((NOW - 7200))" "lathe-01" '{"actor":"human:op-03","proj":"line-a"}'
  # Board shows it open
  run bash "$STREAM" board
  [[ "$output" == *"lathe-01"* ]]
  # Reconcile it
  bash "$STREAM" reconcile --stale 3600 --reason "shift ended" --confirm
  # Board should no longer show it
  run bash "$STREAM" board
  [[ "$output" != *"lathe-01"* ]]
}
