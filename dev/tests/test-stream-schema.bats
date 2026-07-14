#!/usr/bin/env bats
# test-stream-schema.bats — TASK-STRM-001
#
# The schema version is an EVENT, not a header: the log is parsed positionally into exactly 5
# fields, so a comment line would be garbage. `<ts> S schema v1 {...}` is a valid event, dated,
# greppable, and living in the log's own history. In an append-only system, even the version is
# an append.
#
# ABSENCE OF AN `S schema` EVENT MEANS v0. That is why the marker must be written BEFORE any
# v1-only ctx key: a v1 key in an unmarked log would be undetectable.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export WW_BASE="${BATS_TEST_TMPDIR}/ww"
  mkdir -p "$WW_BASE"
  STREAM="${REPO_ROOT}/services/stream/stream.sh"
  LOG="${WW_BASE}/stream/stream.log"
}

@test "a fresh log gets stamped v1 on the first write" {
  run bash "$STREAM" emit T add task-1 '{"prof":"work"}'
  [ "$status" -eq 0 ]
  run grep -c ' S schema v1 ' "$LOG"
  [ "$output" -eq 1 ]
}

@test "the marker is written BEFORE the event it precedes" {
  bash "$STREAM" emit T add task-1 '{"prof":"work"}'
  # The schema line must not come after the first domain event, or a v1 key could land in a
  # log that still reads as v0.
  local marker_line event_line
  marker_line=$(grep -n ' S schema ' "$LOG" | cut -d: -f1)
  event_line=$(grep -n ' T add task-1' "$LOG" | cut -d: -f1)
  [ "$marker_line" -lt "$event_line" ]
}

@test "IDEMPOTENT: many writes produce exactly ONE schema marker" {
  bash "$STREAM" emit T add task-1 '{"prof":"work"}'
  bash "$STREAM" emit T add task-2 '{"prof":"work"}'
  bash "$STREAM" emit B start lathe '{"prof":"work"}'
  run grep -c ' S schema v1 ' "$LOG"
  [ "$output" -eq 1 ]
}

@test "status reports the version FROM THE LOG, not from the build constant" {
  # A constant cannot know the version of a file written by some other build.
  mkdir -p "$(dirname "$LOG")"
  printf '1752300000 T add task-x {"prof":"work"}\n' > "$LOG"   # a v0 log: no S schema event
  run bash "$STREAM" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Schema:         v0"* ]]
}

@test "an unmarked log reads as v0 (absence IS the v0 marker)" {
  mkdir -p "$(dirname "$LOG")"
  printf '1752300000 T add task-x {"prof":"work"}\n' > "$LOG"
  run bash -c "source '${REPO_ROOT}/services/stream/stream.sh' 2>/dev/null; true" || true
  run bash "$STREAM" status
  [[ "$output" == *"v0"* ]]
}

@test "a v0 log is UPGRADED in place, and its history is NOT rewritten" {
  mkdir -p "$(dirname "$LOG")"
  printf '1752300000 T add task-x {"prof":"work"}\n' > "$LOG"
  bash "$STREAM" emit T add task-y '{"prof":"work"}'

  # the marker landed...
  run grep -c ' S schema v1 ' "$LOG"
  [ "$output" -eq 1 ]
  # ...it records what it came FROM...
  run grep ' S schema v1 ' "$LOG"
  [[ "$output" == *'"prev":"v0"'* ]]
  # ...and the pre-existing v0 event is UNTOUCHED. The log is append-only.
  run grep -c '^1752300000 T add task-x {"prof":"work"}$' "$LOG"
  [ "$output" -eq 1 ]
}

@test "the schema marker is a valid 5-field event (the encoding is FROZEN)" {
  bash "$STREAM" emit T add task-1 '{"prof":"work"}'
  # 4 whitespace-delimited fields, then the JSON remainder.
  run bash -c "grep ' S schema ' '$LOG' | awk '{print NF>=5 ? \"ok\" : \"bad\"}'"
  [ "$output" = "ok" ]
  run bash -c "grep ' S schema ' '$LOG' | awk '{print \$2, \$3}'"
  [ "$output" = "S schema" ]
}

@test "cmd_emit's 5-field encoding line was NOT modified (criterion 6)" {
  run grep -c "printf '%s %s %s %s %s" "${REPO_ROOT}/services/stream/stream.sh"
  [ "$output" -ge 1 ]
}

# ── criterion 5: the marker must be INERT to every lens ──────────────────────

@test "CRITERION 5: all 8 lenses render IDENTICALLY with the schema marker present" {
  # This failed on the first attempt, and the contract was wrong: only bundy (op B) and frick
  # (op F) filter by op code. burroughs, hollerith, pacioli, felt, dey and cooper render or
  # COUNT every event — so a synthetic S event would have appeared as ACTIVITY THAT NEVER
  # HAPPENED, skewing the density signals.
  #
  # Fixed at ONE point: replay_load already excluded `H` (the legacy header), because the log's
  # own metadata is not an event the lenses analyse. `S` is the same category.
  local base="${BATS_TEST_TMPDIR}/base.log" marked="${BATS_TEST_TMPDIR}/marked.log"
  cat > "$base" <<'EOF'
1752300000 B start lathe-01 {"prof":"work","proj":"line-a"}
1752300100 T add task-aaa {"prof":"work"}
1752303600 B stop lathe-01 {"prof":"work","proj":"line-a"}
1752303700 F done task-aaa {"prof":"work"}
EOF
  { cat "$base"; echo '1752303800 S schema v1 {"schema":"v1","prev":"v0"}'; } | sort -n > "$marked"

  export SCRIPT_DIR="${REPO_ROOT}/services/stream"
  source "${REPO_ROOT}/services/stream/lib/replay.sh"

  local L a b
  for L in burroughs bundy hollerith pacioli frick felt dey cooper; do
    STREAM_LOG="$base"   a="$(replay_load 0 9999999999 | bash -c "source '${SCRIPT_DIR}/lenses/${L}.sh'; lens_run" 2>&1)"
    STREAM_LOG="$marked" b="$(replay_load 0 9999999999 | bash -c "source '${SCRIPT_DIR}/lenses/${L}.sh'; lens_run" 2>&1)"
    [ "$a" = "$b" ] || { echo "lens $L DIFFERS with the schema marker present"; return 1; }
  done
}

@test "system events stay IN the log — they are excluded from lenses, not deleted" {
  bash "$STREAM" emit T add task-1 '{"prof":"work"}'
  run grep -c ' S schema v1 ' "$LOG"
  [ "$output" -eq 1 ]     # still there. The log is the record; the lens is a projection.
}
