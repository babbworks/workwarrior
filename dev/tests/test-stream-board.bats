#!/usr/bin/env bats
# test-stream-board.bats — TASK-STRM-004
#
# The board: who/what is currently punched in.
# Tests the open-set computation, actor resolution, filtering, and output formats.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export WW_BASE="${BATS_TEST_TMPDIR}/ww"
  mkdir -p "$WW_BASE/config" "$WW_BASE/stream"
  # Actors registry
  cat > "$WW_BASE/config/actors.yaml" <<'EOF'
schema: v1
id_scheme: solo
actors:
  human:marta.k7x2:
    kind: human
    display: Marta K
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
  human:op-03:
    kind: human
    display: Operator Three
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

# ── empty / no open punches ──────────────────────────────────────────────────

@test "board with no log -> 'Nobody is in', exit 0" {
  rm -f "$LOG"
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nobody is in"* ]]
}

@test "board with all closed intervals -> 'Nobody is in'" {
  local ts=$((NOW - 7200))
  _punch_in  "$ts"            "lathe-01" '{"actor":"human:marta.k7x2","proj":"line-a"}'
  _punch_out "$((ts + 3600))" "lathe-01" '{"actor":"human:marta.k7x2","proj":"line-a"}'
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nobody is in"* ]]
}

# ── open punches ─────────────────────────────────────────────────────────────

@test "board shows open punch (start without stop)" {
  local ts=$((NOW - 3600))
  _punch_in "$ts" "lathe-01" '{"actor":"human:marta.k7x2","proj":"line-a"}'
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  [[ "$output" == *"human:marta.k7x2"* ]]
  [[ "$output" == *"lathe-01"* ]]
  [[ "$output" == *"line-a"* ]]
}

@test "board resolves actor from ctx.actor" {
  local ts=$((NOW - 1800))
  _punch_in "$ts" "ledger-refactor" '{"actor":"agent:claude-07","proj":"ledger"}'
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent:claude-07"* ]]
}

@test "board applies v0 fallback (no actor key -> profile:prof)" {
  local ts=$((NOW - 1200))
  _punch_in "$ts" "old-task" '{"prof":"work","proj":"legacy"}'
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  [[ "$output" == *"profile:work"* ]]
}

@test "board applies v0 fallback with no prof -> profile:default" {
  local ts=$((NOW - 600))
  _punch_in "$ts" "mystery-task" '{}'
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  [[ "$output" == *"profile:default"* ]]
}

# ── columns ──────────────────────────────────────────────────────────────────

@test "board shows correct columns (ACTOR, OBJECT, PROJ, IN SINCE, DURATION)" {
  local ts=$((NOW - 3600))
  _punch_in "$ts" "lathe-01" '{"actor":"human:marta.k7x2","proj":"line-a"}'
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  [[ "$output" == *"ACTOR"* ]]
  [[ "$output" == *"OBJECT"* ]]
  [[ "$output" == *"PROJ"* ]]
  [[ "$output" == *"IN SINCE"* ]]
  [[ "$output" == *"DURATION"* ]]
}

# ── sorting ──────────────────────────────────────────────────────────────────

@test "board sorts longest-open first" {
  # Short open
  _punch_in "$((NOW - 600))"  "short-task" '{"actor":"agent:claude-07","proj":"p1"}'
  # Long open
  _punch_in "$((NOW - 7200))" "long-task"  '{"actor":"human:marta.k7x2","proj":"p2"}'
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  # long-task should appear before short-task
  local long_pos short_pos
  long_pos=$(echo "$output" | grep -n "long-task" | head -1 | cut -d: -f1)
  short_pos=$(echo "$output" | grep -n "short-task" | head -1 | cut -d: -f1)
  [ "$long_pos" -lt "$short_pos" ]
}

# ── filters ──────────────────────────────────────────────────────────────────

@test "--actor filter shows only matching actor" {
  _punch_in "$((NOW - 3600))" "lathe-01" '{"actor":"human:marta.k7x2","proj":"line-a"}'
  _punch_in "$((NOW - 1800))" "ledger"   '{"actor":"agent:claude-07","proj":"ledger"}'
  run bash "$STREAM" board --actor "human:marta.k7x2"
  [ "$status" -eq 0 ]
  [[ "$output" == *"human:marta.k7x2"* ]]
  [[ "$output" != *"agent:claude-07"* ]]
}

@test "--proj filter shows only matching project" {
  _punch_in "$((NOW - 3600))" "lathe-01" '{"actor":"human:marta.k7x2","proj":"line-a"}'
  _punch_in "$((NOW - 1800))" "ledger"   '{"actor":"agent:claude-07","proj":"ledger"}'
  run bash "$STREAM" board --proj "ledger"
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent:claude-07"* ]]
  [[ "$output" != *"human:marta.k7x2"* ]]
}

@test "--actor filter with no match -> 'Nobody is in'" {
  _punch_in "$((NOW - 3600))" "lathe-01" '{"actor":"human:marta.k7x2","proj":"line-a"}'
  run bash "$STREAM" board --actor "agent:nobody"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nobody is in"* ]]
}

# ── stale flag ───────────────────────────────────────────────────────────────

@test "--stale flags stale rows but does NOT close them" {
  # 5h old — should be stale with 4h threshold (14400s)
  _punch_in "$((NOW - 18000))" "stuck-task" '{"actor":"agent:claude-11","proj":"dev"}'
  # 30m old — should NOT be stale
  _punch_in "$((NOW - 1800))"  "fresh-task" '{"actor":"agent:claude-07","proj":"dev"}'
  run bash "$STREAM" board --stale 14400
  [ "$status" -eq 0 ]
  # stale marker on the old one
  [[ "$output" == *"stale"* ]]
  [[ "$output" == *"stuck-task"* ]]
  [[ "$output" == *"fresh-task"* ]]
}

@test "--stale does not modify the log file" {
  _punch_in "$((NOW - 18000))" "stuck-task" '{"actor":"agent:claude-11","proj":"dev"}'
  local before
  before=$(cat "$LOG")
  run bash "$STREAM" board --stale 14400
  [ "$status" -eq 0 ]
  local after
  after=$(cat "$LOG")
  [ "$before" = "$after" ]
}

# ── JSON format ──────────────────────────────────────────────────────────────

@test "--format json outputs valid JSON array with correct fields" {
  _punch_in "$((NOW - 3600))" "lathe-01" '{"actor":"human:marta.k7x2","proj":"line-a"}'
  run bash "$STREAM" board --format json
  [ "$status" -eq 0 ]
  # Must be valid JSON
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d, list); assert len(d) > 0"
  # Check fields
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
r = d[0]
assert 'actor' in r, 'missing actor'
assert 'object' in r, 'missing object'
assert 'proj' in r, 'missing proj'
assert 'since' in r, 'missing since'
assert 'duration_s' in r, 'missing duration_s'
assert 'stale' in r, 'missing stale'
assert r['actor'] == 'human:marta.k7x2'
assert r['object'] == 'lathe-01'
assert r['proj'] == 'line-a'
assert isinstance(r['since'], int)
assert isinstance(r['duration_s'], int)
assert isinstance(r['stale'], bool)
"
}

@test "--format json with --stale marks stale boolean correctly" {
  _punch_in "$((NOW - 18000))" "old-task" '{"actor":"agent:claude-11","proj":"dev"}'
  _punch_in "$((NOW - 600))"   "new-task" '{"actor":"agent:claude-07","proj":"dev"}'
  run bash "$STREAM" board --format json --stale 14400
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
stale_rows = [r for r in d if r['stale'] == True]
fresh_rows = [r for r in d if r['stale'] == False]
assert len(stale_rows) >= 1, 'expected at least one stale row'
assert len(fresh_rows) >= 1, 'expected at least one fresh row'
"
}

# ── multiple actors ──────────────────────────────────────────────────────────

@test "multiple concurrent actors shown correctly" {
  _punch_in "$((NOW - 3600))" "lathe-01"        '{"actor":"human:marta.k7x2","proj":"line-a"}'
  _punch_in "$((NOW - 2700))" "ledger-refactor" '{"actor":"agent:claude-07","proj":"ledger"}'
  _punch_in "$((NOW - 1800))" "struct-1b"       '{"actor":"agent:claude-11","proj":"dev"}'
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  [[ "$output" == *"human:marta.k7x2"* ]]
  [[ "$output" == *"agent:claude-07"* ]]
  [[ "$output" == *"agent:claude-11"* ]]
  [[ "$output" == *"lathe-01"* ]]
  [[ "$output" == *"ledger-refactor"* ]]
  [[ "$output" == *"struct-1b"* ]]
}

# ── scale test ───────────────────────────────────────────────────────────────

@test "40-actor scale test: create 40 starts, verify all appear" {
  for i in $(seq 1 40); do
    local ts=$((NOW - (i * 60)))
    _punch_in "$ts" "obj-$i" "{\"actor\":\"human:actor-$i\",\"proj\":\"scale-test\"}"
  done
  run bash "$STREAM" board --format json
  [ "$status" -eq 0 ]
  local count
  count=$(echo "$output" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  [ "$count" -eq 40 ]
}

# ── unknown actor ────────────────────────────────────────────────────────────

@test "actor not in registry: displays as-is, never dropped" {
  _punch_in "$((NOW - 1200))" "task-x" '{"actor":"human:unknown-person","proj":"secret"}'
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  [[ "$output" == *"human:unknown-person"* ]]
  [[ "$output" == *"task-x"* ]]
}

# ── read-only invariant ──────────────────────────────────────────────────────

@test "board is read-only: log file is not modified after board runs" {
  _punch_in "$((NOW - 3600))" "lathe-01" '{"actor":"human:marta.k7x2","proj":"line-a"}'
  local checksum_before
  checksum_before=$(md5sum "$LOG" | awk '{print $1}')
  run bash "$STREAM" board
  [ "$status" -eq 0 ]
  local checksum_after
  checksum_after=$(md5sum "$LOG" | awk '{print $1}')
  [ "$checksum_before" = "$checksum_after" ]
}

@test "board with --format json is read-only" {
  _punch_in "$((NOW - 3600))" "lathe-01" '{"actor":"human:marta.k7x2","proj":"line-a"}'
  local checksum_before
  checksum_before=$(md5sum "$LOG" | awk '{print $1}')
  run bash "$STREAM" board --format json --stale 14400
  [ "$status" -eq 0 ]
  local checksum_after
  checksum_after=$(md5sum "$LOG" | awk '{print $1}')
  [ "$checksum_before" = "$checksum_after" ]
}
