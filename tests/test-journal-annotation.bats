#!/usr/bin/env bats
# tests/test-journal-annotation.bats — TASK-COMM-005
# Tests for lib/journal_scanner.py parse/annotate functions

SCANNER_PY="${BATS_TEST_DIRNAME}/../lib/journal_scanner.py"

setup() {
  JRNL_FILE="$(mktemp)"
  cat > "$JRNL_FILE" << 'EOF'
[2026-04-01 09:00] First entry
This is the body of the first entry.

[2026-04-02 14:30] Second entry
Body of the second entry.
More body text here.

[2026-04-03 10:15] Third entry
Third body.
EOF
}

teardown() {
  rm -f "$JRNL_FILE"
}

# ── Parse tests ───────────────────────────────────────────────────────────────

@test "parse: returns ok and entries array" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; assert len(d['entries'])>=3"
}

@test "parse: entries are in reverse chronological order" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
dates=[e['date'] for e in d['entries']]
assert dates == sorted(dates, reverse=True), 'not reverse order: '+str(dates)"
}

@test "parse: each entry has date, date_slug, body, annotations fields" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
for e in d['entries']:
    assert 'date' in e
    assert 'date_slug' in e
    assert 'body' in e
    assert 'annotations' in e"
}

@test "parse: date_slug converts colons and space" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
for e in d['entries']:
    assert ':' not in e['date_slug']
    assert ' ' not in e['date_slug']"
}

@test "parse: no annotations on fresh entries" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
for e in d['entries']: assert e['annotations']==[]"
}

@test "parse: empty file returns empty entries" {
  empty="$(mktemp)"
  run python3 "$SCANNER_PY" parse "$empty"
  rm -f "$empty"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['entries']==[]"
}

@test "parse: missing file returns empty entries gracefully" {
  run python3 "$SCANNER_PY" parse /tmp/nonexistent-journal-99999.txt
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['entries']==[]"
}

# ── get-entry tests ───────────────────────────────────────────────────────────

@test "get-entry: finds entry by slug" {
  run python3 "$SCANNER_PY" get-entry "$JRNL_FILE" 2026-04-02_14-30
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok']
assert d['entry']['date'] == '2026-04-02 14:30'"
}

@test "get-entry: returns error for unknown slug" {
  run python3 "$SCANNER_PY" get-entry "$JRNL_FILE" 2099-01-01_00-00
  [ "$status" -ne 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not d['ok']"
}

# ── Annotate tests ────────────────────────────────────────────────────────────

@test "annotate: appends annotation block to entry" {
  run python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2026-04-02_14-30 "This is an annotation"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
  grep -q "This is an annotation" "$JRNL_FILE"
  grep -q "^---$" "$JRNL_FILE"
}

@test "annotate: annotation format is ---\\n[ts] text" {
  python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2026-04-02_14-30 "test annotation"
  run grep -A2 "^---$" "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "^\[20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}\] test annotation"
}

@test "annotate: multiple annotations accumulate" {
  python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2026-04-02_14-30 "first annotation"
  python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2026-04-02_14-30 "second annotation"
  count=$(grep -c "^---$" "$JRNL_FILE")
  [ "$count" -eq 2 ]
}

@test "annotate: parse shows annotations after annotating" {
  python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2026-04-02_14-30 "parsed annotation"
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
for e in d['entries']:
    if e['date']=='2026-04-02 14:30':
        assert len(e['annotations'])==1
        assert 'parsed annotation' in e['annotations'][0]['text']"
}

@test "annotate: body text unchanged after annotation" {
  python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2026-04-02_14-30 "note"
  run python3 "$SCANNER_PY" get-entry "$JRNL_FILE" 2026-04-02_14-30
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
body=d['entry']['body']
assert 'Body of the second entry' in body"
}

@test "annotate: other entries unchanged after annotating one" {
  python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2026-04-02_14-30 "isolated note"
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
for e in d['entries']:
    if e['date'] in ('2026-04-01 09:00','2026-04-03 10:15'):
        assert e['annotations']==[], 'expected no annotations on '+e['date']"
}

@test "annotate: unknown entry returns error" {
  run python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2099-01-01_00-00 "ghost"
  [ "$status" -ne 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert not d['ok']"
}

@test "annotate: entry body not in annotations field" {
  python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2026-04-02_14-30 "clean split"
  run python3 "$SCANNER_PY" get-entry "$JRNL_FILE" 2026-04-02_14-30
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
body=d['entry']['body']
assert '---' not in body, 'separator leaked into body'"
}

# ── CLI shell wrapper tests ───────────────────────────────────────────────────

@test "shell: journal-scanner.sh parse works" {
  SCANNER_SH="${BATS_TEST_DIRNAME}/../lib/journal-scanner.sh"
  run bash "$SCANNER_SH" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
}

@test "shell: journal-scanner.sh annotate works" {
  SCANNER_SH="${BATS_TEST_DIRNAME}/../lib/journal-scanner.sh"
  run bash "$SCANNER_SH" annotate "$JRNL_FILE" 2026-04-03_10-15 "shell test annotation"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']"
  grep -q "shell test annotation" "$JRNL_FILE"
}
