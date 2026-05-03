#!/usr/bin/env bats
# tests/test-community-cli.bats — TASK-COMM-002
# Tests for services/community/community.sh CLI and community_store.py
# Requires: python3, bats, no network

COMM_SH="${BATS_TEST_DIRNAME}/../services/community/community.sh"
STORE_PY="${BATS_TEST_DIRNAME}/../services/community/community_store.py"

setup() {
  export WW_BASE="${BATS_TEST_TMPDIR}/ww-comm-$$"
  export WARRIOR_PROFILE="testprofile"
  export WW_OUTPUT_MODE="compact"
  mkdir -p "$WW_BASE"
}

teardown() {
  rm -rf "$WW_BASE"
}

# ── Store (Python) direct tests ──────────────────────────────────────────────

@test "store: list returns empty communities" {
  run python3 "$STORE_PY" list "$WW_BASE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; assert d['communities']==[]"
}

@test "store: create community" {
  run python3 "$STORE_PY" create "$WW_BASE" alpha
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "store: create duplicate returns error" {
  python3 "$STORE_PY" create "$WW_BASE" alpha >/dev/null
  run python3 "$STORE_PY" create "$WW_BASE" alpha
  [ "$status" -ne 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not d['ok']"
}

@test "store: list shows created community" {
  python3 "$STORE_PY" create "$WW_BASE" alpha >/dev/null
  run python3 "$STORE_PY" list "$WW_BASE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); names=[c['name'] for c in d['communities']]; assert 'alpha' in names"
}

@test "store: show unknown community returns error" {
  run python3 "$STORE_PY" show "$WW_BASE" nosuchcomm
  [ "$status" -ne 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not d['ok']"
}

@test "store: add-entry and show" {
  python3 "$STORE_PY" create "$WW_BASE" alpha >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"test task","status":"pending"}' > "$tmp"
  run python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.abc-123 "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; assert d['entry_id']>0"
}

@test "store: add-entry duplicate returns error" {
  python3 "$STORE_PY" create "$WW_BASE" alpha >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"test task"}' > "$tmp"
  python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.abc-123 "$tmp" >/dev/null
  run python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.abc-123 "$tmp"
  rm -f "$tmp"
  [ "$status" -ne 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not d['ok']"
}

@test "store: remove-entry removes entry" {
  python3 "$STORE_PY" create "$WW_BASE" alpha >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"removable task"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.del-456 "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  run python3 "$STORE_PY" remove-entry "$WW_BASE" alpha "$eid"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
  show_out="$(python3 "$STORE_PY" show "$WW_BASE" alpha)"
  echo "$show_out" | python3 -c "import json,sys; d=json.load(sys.stdin); ids=[e['id'] for e in d['entries']]; assert int('$eid') not in ids"
}

@test "store: remove-entry wrong community returns error" {
  python3 "$STORE_PY" create "$WW_BASE" alpha >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"task"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.xyz-789 "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  python3 "$STORE_PY" create "$WW_BASE" beta >/dev/null
  run python3 "$STORE_PY" remove-entry "$WW_BASE" beta "$eid"
  [ "$status" -ne 0 ]
}

# ── Bash CLI tests ────────────────────────────────────────────────────────────

@test "cli: help shows usage" {
  run bash "$COMM_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "cli: --help flag shows usage" {
  run bash "$COMM_SH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "cli: list --help shows subcommand help" {
  run bash "$COMM_SH" list --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"list"* ]]
}

@test "cli: create --help shows subcommand help" {
  run bash "$COMM_SH" create --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"create"* ]]
}

@test "cli: add --help shows subcommand help" {
  run bash "$COMM_SH" add --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"task"* ]]
}

@test "cli: show --help shows subcommand help" {
  run bash "$COMM_SH" show --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"show"* ]]
}

@test "cli: remove --help shows subcommand help" {
  run bash "$COMM_SH" remove --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"remove"* ]]
}

@test "cli: export --help shows subcommand help" {
  run bash "$COMM_SH" export --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"export"* ]]
}

@test "cli: list with no communities" {
  run bash "$COMM_SH" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Communities"* ]]
}

@test "cli: create community" {
  run bash "$COMM_SH" create alpha
  [ "$status" -eq 0 ]
  [[ "$output" == *"alpha"* ]]
}

@test "cli: create invalid name exits 1" {
  run bash "$COMM_SH" create "bad name!"
  [ "$status" -eq 1 ]
}

@test "cli: show unknown community exits 1" {
  run bash "$COMM_SH" show nosuchcomm
  [ "$status" -eq 1 ]
}

@test "cli: remove requires name and entry-id" {
  run bash "$COMM_SH" remove
  [ "$status" -eq 1 ]
}

@test "cli: remove non-integer entry-id exits 1" {
  run bash "$COMM_SH" remove alpha notanumber
  [ "$status" -eq 1 ]
}

@test "cli: export returns error (warrior not yet available)" {
  run bash "$COMM_SH" export alpha
  [ "$status" -eq 1 ]
  [[ "$output" == *"warrior"* || "$output" == *"COMM-009"* ]]
}

@test "cli: unknown action exits 1" {
  run bash "$COMM_SH" frobnicate
  [ "$status" -eq 1 ]
}

@test "cli: list --json returns valid JSON" {
  WW_OUTPUT_MODE=json run bash "$COMM_SH" list
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'communities' in d"
}

@test "cli: create then list shows community" {
  bash "$COMM_SH" create mycomm >/dev/null
  run bash "$COMM_SH" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"mycomm"* ]]
}

@test "cli: remove entry end-to-end" {
  bash "$COMM_SH" create alpha >/dev/null
  tmp="$(mktemp)"
  echo '{"description":"e2e task"}' > "$tmp"
  add_out="$(python3 "$STORE_PY" add-entry "$WW_BASE" alpha testprofile.task.e2e-000 "$tmp")"
  rm -f "$tmp"
  eid="$(echo "$add_out" | python3 -c "import json,sys; print(json.load(sys.stdin)['entry_id'])")"
  run bash "$COMM_SH" remove alpha "$eid"
  [ "$status" -eq 0 ]
  show_out="$(bash "$COMM_SH" show alpha)"
  [[ "$show_out" != *"e2e-000"* ]]
}
