#!/usr/bin/env bats
# test-stream-timew-hook.bats — TASK-STRM-006
#
# Tests the timew stream hook: B start/stop events emitted by the timew() shell wrapper
# with dedup-parity to adapt_timew (same object hash for same interval).
#
# Criterion 5 (the whole card): hook-emitted events are IDENTICAL in (ts, op, action, object)
# to what adapt_timew produces for the same interval. Running ingest after the hook produces
# ZERO new events.
#
# Criterion 6: hook failure never breaks timew (fail-soft).

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export WW_BASE="${BATS_TEST_TMPDIR}/ww"
  mkdir -p "$WW_BASE/stream" "$WW_BASE/config"
  # Actors registry
  cat > "$WW_BASE/config/actors.yaml" <<'EOF'
schema: v1
id_scheme: solo
actors: {}
EOF
  export WARRIOR_PROFILE="test"
  export STREAM_LOG="${WW_BASE}/stream/stream.log"

  # Source the hook helper directly for unit testing
  HOOK="${REPO_ROOT}/services/stream/hooks/timew-stream-hook.sh"
  ADAPTERS="${REPO_ROOT}/services/stream/lib/adapters.sh"
  STREAM="${REPO_ROOT}/services/stream/stream.sh"

  # Create a mock timew that returns controlled interval data
  MOCK_DIR="${BATS_TEST_TMPDIR}/mock"
  mkdir -p "$MOCK_DIR"
  export PATH="${MOCK_DIR}:${PATH}"
}

# Helper: create a mock timew binary that returns known interval JSON
_mock_timew_active() {
  local start="${1:-20260715T120000Z}" tags_json="${2:-[\"work\",\"coding\"]}"
  cat > "${MOCK_DIR}/timew" <<MOCK
#!/usr/bin/env bash
if [[ "\$1" == "export" ]]; then
  echo '[{"start":"${start}","tags":${tags_json}}]'
elif [[ "\$1" == "start" || "\$1" == "stop" || "\$1" == "continue" ]]; then
  echo "Tracking \$*"
  exit 0
else
  exit 0
fi
MOCK
  chmod +x "${MOCK_DIR}/timew"
}

_mock_timew_stopped() {
  local start="${1:-20260715T120000Z}" end="${2:-20260715T130000Z}" tags_json="${3:-[\"work\",\"coding\"]}"
  cat > "${MOCK_DIR}/timew" <<MOCK
#!/usr/bin/env bash
if [[ "\$1" == "export" ]]; then
  echo '[{"start":"${start}","end":"${end}","tags":${tags_json}}]'
elif [[ "\$1" == "start" || "\$1" == "stop" || "\$1" == "continue" ]]; then
  echo "Tracking \$*"
  exit 0
else
  exit 0
fi
MOCK
  chmod +x "${MOCK_DIR}/timew"
}

# Helper: compute expected object hash the same way adapt_timew does
_expected_obj_hash() {
  local start="$1" tags_json="$2"
  python3 -c "
import hashlib, json, sys
start = sys.argv[1]
tags = json.loads(sys.argv[2])
payload = start + '|' + json.dumps(tags)
print(hashlib.sha256(payload.encode()).hexdigest()[:12])
" "$start" "$tags_json"
}

# ── Object hash parity ───────────────────────────────────────────────────────

@test "obj hash: _stream_timew_obj_hash matches adapt_timew h12 computation" {
  source "$HOOK"
  local start="20260715T120000Z"
  local tags='["work","coding"]'
  local hook_hash
  hook_hash="$(_stream_timew_obj_hash "$start" "$tags")"
  local expected
  expected="$(_expected_obj_hash "$start" "$tags")"
  [ "$hook_hash" = "$expected" ]
  [ ${#hook_hash} -eq 12 ]
}

@test "obj hash: empty tags produce consistent hash" {
  source "$HOOK"
  local start="20260715T090000Z"
  local tags='[]'
  local hook_hash
  hook_hash="$(_stream_timew_obj_hash "$start" "$tags")"
  local expected
  expected="$(_expected_obj_hash "$start" "$tags")"
  [ "$hook_hash" = "$expected" ]
}

@test "obj hash: tags with special characters produce consistent hash" {
  source "$HOOK"
  local start="20260710T143000Z"
  local tags='["project:alpha","urgent","meeting/standup"]'
  local hook_hash
  hook_hash="$(_stream_timew_obj_hash "$start" "$tags")"
  local expected
  expected="$(_expected_obj_hash "$start" "$tags")"
  [ "$hook_hash" = "$expected" ]
}

# ── first_project extraction ─────────────────────────────────────────────────

@test "first_project: extracts first non-UUID tag" {
  source "$HOOK"
  local proj
  proj="$(_stream_timew_first_project '["work","coding"]')"
  [ "$proj" = "work" ]
}

@test "first_project: skips UUID tags" {
  source "$HOOK"
  local proj
  proj="$(_stream_timew_first_project '["a1b2c3d4-e5f6-7890-abcd-ef1234567890","realproject"]')"
  [ "$proj" = "realproject" ]
}

@test "first_project: returns empty for no tags" {
  source "$HOOK"
  local proj
  proj="$(_stream_timew_first_project '[]')"
  [ "$proj" = "" ]
}

# ── emit_start ───────────────────────────────────────────────────────────────

@test "emit_start: writes B start event to stream.log" {
  _mock_timew_active "20260715T120000Z" '["work","coding"]'
  source "$HOOK"
  _stream_timew_emit_start "${BATS_TEST_TMPDIR}/fake-twdb" "test"
  [ -f "$STREAM_LOG" ]
  run grep 'B start' "$STREAM_LOG"
  assert_success
}

@test "emit_start: ts matches timew start timestamp" {
  _mock_timew_active "20260715T120000Z" '["work"]'
  source "$HOOK"
  _stream_timew_emit_start "${BATS_TEST_TMPDIR}/fake-twdb" "test"
  # 20260715T120000Z in UTC = ?
  local expected_ts
  expected_ts="$(python3 -c "
from datetime import datetime, timezone
dt = datetime.strptime('20260715T120000', '%Y%m%dT%H%M%S').replace(tzinfo=timezone.utc)
print(int(dt.timestamp()))
")"
  local actual_ts
  actual_ts="$(awk '{print $1}' "$STREAM_LOG" | head -1)"
  [ "$actual_ts" = "$expected_ts" ]
}

@test "emit_start: object hash matches adapt_timew for same interval" {
  local start="20260715T120000Z"
  local tags='["work","coding"]'
  _mock_timew_active "$start" "$tags"
  source "$HOOK"
  _stream_timew_emit_start "${BATS_TEST_TMPDIR}/fake-twdb" "test"
  local expected_obj
  expected_obj="$(_expected_obj_hash "$start" "$tags")"
  run grep "$expected_obj" "$STREAM_LOG"
  assert_success
}

@test "emit_start: ctx contains src=timew and actor=profile:PROF" {
  _mock_timew_active "20260715T120000Z" '["work"]'
  source "$HOOK"
  _stream_timew_emit_start "${BATS_TEST_TMPDIR}/fake-twdb" "myprof"
  local line
  line="$(cat "$STREAM_LOG")"
  [[ "$line" == *'"src":"timew"'* ]]
  [[ "$line" == *'"actor":"profile:myprof"'* ]]
  [[ "$line" == *'"prof":"myprof"'* ]]
}

# ── emit_stop ────────────────────────────────────────────────────────────────

@test "emit_stop: writes B stop event to stream.log" {
  _mock_timew_stopped "20260715T120000Z" "20260715T130000Z" '["work"]'
  source "$HOOK"
  _stream_timew_emit_stop "${BATS_TEST_TMPDIR}/fake-twdb" "test"
  [ -f "$STREAM_LOG" ]
  run grep 'B stop' "$STREAM_LOG"
  assert_success
}

@test "emit_stop: ts matches timew end timestamp" {
  _mock_timew_stopped "20260715T120000Z" "20260715T130000Z" '["work"]'
  source "$HOOK"
  _stream_timew_emit_stop "${BATS_TEST_TMPDIR}/fake-twdb" "test"
  local expected_ts
  expected_ts="$(python3 -c "
from datetime import datetime, timezone
dt = datetime.strptime('20260715T130000', '%Y%m%dT%H%M%S').replace(tzinfo=timezone.utc)
print(int(dt.timestamp()))
")"
  local actual_ts
  actual_ts="$(awk '{print $1}' "$STREAM_LOG" | head -1)"
  [ "$actual_ts" = "$expected_ts" ]
}

@test "emit_stop: object hash uses START time (same identity as start event)" {
  local start="20260715T120000Z"
  local end="20260715T130000Z"
  local tags='["work","coding"]'
  _mock_timew_stopped "$start" "$end" "$tags"
  source "$HOOK"
  _stream_timew_emit_stop "${BATS_TEST_TMPDIR}/fake-twdb" "test"
  # Object must be hash of START + tags, not END + tags
  local expected_obj
  expected_obj="$(_expected_obj_hash "$start" "$tags")"
  run grep "$expected_obj" "$STREAM_LOG"
  assert_success
}

# ── CRITERION 5: dedup parity ────────────────────────────────────────────────

@test "DEDUP PARITY: hook start event deduplicates against adapt_timew start event" {
  local start="20260715T120000Z"
  local end="20260715T130000Z"
  local tags='["work","coding"]'

  # 1) Emit via hook (start)
  _mock_timew_active "$start" "$tags"
  source "$HOOK"
  _stream_timew_emit_start "${BATS_TEST_TMPDIR}/fake-twdb" "test"

  local count_after_hook
  count_after_hook="$(wc -l < "$STREAM_LOG" | tr -d ' ')"
  [ "$count_after_hook" -eq 1 ]

  # 2) Run adapt_timew for the same interval (completed) — pipe through dedup
  _mock_timew_stopped "$start" "$end" "$tags"
  export TIMEWARRIORDB="${BATS_TEST_TMPDIR}/fake-twdb"
  local new_events
  new_events="$(source "$ADAPTERS" && adapt_timew | grep 'B start' | bash -c "
    source '$ADAPTERS'
    _dedup_events '$STREAM_LOG'
  " | wc -l | tr -d ' ')"
  # The start event from adapt_timew must be deduped (same ts, op, action, object)
  [ "$new_events" -eq 0 ]
}

@test "DEDUP PARITY: hook stop event deduplicates against adapt_timew stop event" {
  local start="20260715T120000Z"
  local end="20260715T130000Z"
  local tags='["work","coding"]'

  # 1) Emit via hook (stop)
  _mock_timew_stopped "$start" "$end" "$tags"
  source "$HOOK"
  _stream_timew_emit_stop "${BATS_TEST_TMPDIR}/fake-twdb" "test"

  local count_after_hook
  count_after_hook="$(wc -l < "$STREAM_LOG" | tr -d ' ')"
  [ "$count_after_hook" -eq 1 ]

  # 2) Run adapt_timew — the stop event must dedup
  export TIMEWARRIORDB="${BATS_TEST_TMPDIR}/fake-twdb"
  local new_events
  new_events="$(source "$ADAPTERS" && adapt_timew | grep 'B stop' | bash -c "
    source '$ADAPTERS'
    _dedup_events '$STREAM_LOG'
  " | wc -l | tr -d ' ')"
  [ "$new_events" -eq 0 ]
}

# ── CRITERION 6: fail soft ───────────────────────────────────────────────────

@test "FAIL SOFT: emit_start returns 0 when timew is not found" {
  # Remove mock timew — command not found
  rm -f "${MOCK_DIR}/timew"
  source "$HOOK"
  run _stream_timew_emit_start "/nonexistent/path" "test"
  assert_success
  # No event written
  [ ! -f "$STREAM_LOG" ] || [ "$(wc -l < "$STREAM_LOG" | tr -d ' ')" -eq 0 ]
}

@test "FAIL SOFT: emit_stop returns 0 when stream dir does not exist" {
  export WW_BASE="/nonexistent/path"
  export STREAM_LOG="/nonexistent/path/stream/stream.log"
  _mock_timew_stopped "20260715T120000Z" "20260715T130000Z" '["work"]'
  source "$HOOK"
  run _stream_timew_emit_stop "${BATS_TEST_TMPDIR}/fake-twdb" "test"
  assert_success
}

@test "FAIL SOFT: emit_start returns 0 when python3 is not available" {
  # Create a mock python3 that fails
  cat > "${MOCK_DIR}/python3" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
  chmod +x "${MOCK_DIR}/python3"
  _mock_timew_active "20260715T120000Z" '["work"]'
  # Re-source with broken python3 in PATH
  unset _WW_STREAM_TIMEW_HOOK_LOADED
  source "$HOOK"
  run _stream_timew_emit_start "${BATS_TEST_TMPDIR}/fake-twdb" "test"
  assert_success
  # Remove broken python3 mock
  rm -f "${MOCK_DIR}/python3"
}

# ── 5-field encoding ─────────────────────────────────────────────────────────

@test "5-field encoding: hook events have exactly 5 space-separated positional fields" {
  _mock_timew_active "20260715T120000Z" '["work","coding"]'
  source "$HOOK"
  _stream_timew_emit_start "${BATS_TEST_TMPDIR}/fake-twdb" "test"
  # Field count: ts op action object ctx (ctx is JSON with spaces possible, so NF >= 5)
  local bad_lines
  bad_lines="$(awk 'NF < 5' "$STREAM_LOG" | wc -l | tr -d ' ')"
  [ "$bad_lines" -eq 0 ]
}

@test "5-field encoding: first 4 fields are positional, 5th is valid JSON" {
  _mock_timew_stopped "20260715T120000Z" "20260715T130000Z" '["work"]'
  source "$HOOK"
  _stream_timew_emit_stop "${BATS_TEST_TMPDIR}/fake-twdb" "test"
  local ctx_json
  ctx_json="$(awk '{$1=""; $2=""; $3=""; $4=""; print}' "$STREAM_LOG" | sed 's/^[[:space:]]*//')"
  # Validate JSON
  run python3 -c "import json,sys; json.loads(sys.argv[1])" "$ctx_json"
  assert_success
}
