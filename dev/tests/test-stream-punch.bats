#!/usr/bin/env bats
# test-stream-punch.bats — TASK-STRM-003
#
# Punch verbs: `ww stream punch in|out --actor <id> --object <obj>`
# --actor flag on cmd_emit
# Back-compat: positional emit unchanged
# Encoding: 5-field invariant preserved

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export WW_BASE="${BATS_TEST_TMPDIR}/ww"
  mkdir -p "$WW_BASE/config"
  # Create a minimal actors.yaml with a known actor for tests
  cat > "$WW_BASE/config/actors.yaml" <<'EOF'
schema: v1
id_scheme: solo
actors:
  human:op-03:
    kind: human
    display: Operator Three
    status: active
    source: local
  agent:claude-07:
    kind: agent
    display: Claude Seven
    status: active
    source: local
  machine:lathe-01:
    kind: machine
    display: Lathe One
    status: active
    source: local
EOF
  export WARRIOR_PROFILE="test"
  STREAM="${REPO_ROOT}/services/stream/stream.sh"
  LOG="${WW_BASE}/stream/stream.log"
}

# ── punch in ─────────────────────────────────────────────────────────────────

@test "punch in writes B start event with actor in ctx" {
  run bash "$STREAM" punch in --actor human:op-03 --object lathe-01
  [ "$status" -eq 0 ]
  # Check the log has a B start event
  run grep ' B start lathe-01 ' "$LOG"
  [ "$status" -eq 0 ]
  # Check actor is in the ctx JSON
  [[ "$output" == *'"actor":"human:op-03"'* ]]
}

@test "punch out writes B stop event with actor in ctx" {
  run bash "$STREAM" punch out --actor human:op-03 --object lathe-01
  [ "$status" -eq 0 ]
  run grep ' B stop lathe-01 ' "$LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"actor":"human:op-03"'* ]]
}

@test "punch in includes src:stream in ctx" {
  bash "$STREAM" punch in --actor human:op-03 --object lathe-01
  run grep ' B start lathe-01 ' "$LOG"
  [[ "$output" == *'"src":"stream"'* ]]
}

@test "punch in includes prof in ctx" {
  bash "$STREAM" punch in --actor human:op-03 --object lathe-01
  run grep ' B start lathe-01 ' "$LOG"
  [[ "$output" == *'"prof":"test"'* ]]
}

# ── validation ───────────────────────────────────────────────────────────────

@test "punch rejects missing direction" {
  run bash "$STREAM" punch
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "punch rejects invalid direction" {
  run bash "$STREAM" punch sideways --actor human:op-03 --object lathe-01
  [ "$status" -ne 0 ]
  [[ "$output" == *"in' or 'out"* ]]
}

@test "punch validates actor format — rejects invalid ID" {
  run bash "$STREAM" punch in --actor "badformat" --object lathe-01
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid actor ID"* ]]
}

@test "punch validates actor format — rejects profile: prefix" {
  run bash "$STREAM" punch in --actor "profile:work" --object lathe-01
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid actor ID"* ]]
}

@test "punch validates actor exists in registry — rejects unknown" {
  run bash "$STREAM" punch in --actor "human:unknown-person" --object lathe-01
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown actor"* ]]
}

@test "punch requires --actor flag" {
  run bash "$STREAM" punch in --object lathe-01
  [ "$status" -ne 0 ]
  [[ "$output" == *"--actor required"* ]]
}

@test "punch requires --object flag" {
  run bash "$STREAM" punch in --actor human:op-03
  [ "$status" -ne 0 ]
  [[ "$output" == *"--object required"* ]]
}

# ── optional flags ───────────────────────────────────────────────────────────

@test "punch with --proj includes proj in ctx" {
  bash "$STREAM" punch in --actor human:op-03 --object lathe-01 --proj line-a
  run grep ' B start lathe-01 ' "$LOG"
  [[ "$output" == *'"proj":"line-a"'* ]]
}

@test "punch with --tags includes tags in ctx" {
  bash "$STREAM" punch in --actor human:op-03 --object lathe-01 --tags urgent priority
  run grep ' B start lathe-01 ' "$LOG"
  [[ "$output" == *'"tags":["urgent","priority"]'* ]]
}

# ── --actor flag on cmd_emit ─────────────────────────────────────────────────

@test "--actor flag on emit injects actor into ctx" {
  run bash "$STREAM" emit --actor human:op-03 T add task-1 '{"prof":"work"}'
  [ "$status" -eq 0 ]
  run grep ' T add task-1 ' "$LOG"
  [[ "$output" == *'"actor":"human:op-03"'* ]]
}

@test "--actor flag on emit rejects invalid ID" {
  run bash "$STREAM" emit --actor "bad-id" T add task-1 '{"prof":"work"}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid --actor ID"* ]]
}

@test "positional emit still works unchanged (back-compat)" {
  run bash "$STREAM" emit T add task-2 '{"prof":"work"}'
  [ "$status" -eq 0 ]
  run grep ' T add task-2 ' "$LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *'{"prof":"work"}'* ]]
}

# ── encoding invariant ───────────────────────────────────────────────────────

@test "the 5-field encoding is preserved — punch events have exactly 4 ws-delimited fields before JSON" {
  bash "$STREAM" punch in --actor human:op-03 --object lathe-01
  # Every non-system, non-header line must have at least 5 fields (ts op action obj ctx)
  # The ctx is a JSON blob which may contain spaces, so we check the first 4 fields are ws-delimited
  run bash -c "grep ' B start lathe-01 ' '$LOG' | awk '{if(NF>=5) print \"ok\"; else print \"bad\"}'"
  [ "$output" = "ok" ]
}

@test "the 5-field encoding is preserved — emit with --actor has exactly 4 ws-delimited fields before JSON" {
  bash "$STREAM" emit --actor human:op-03 T add task-x '{"prof":"work"}'
  run bash -c "grep ' T add task-x ' '$LOG' | awk '{if(NF>=5) print \"ok\"; else print \"bad\"}'"
  [ "$output" = "ok" ]
}
