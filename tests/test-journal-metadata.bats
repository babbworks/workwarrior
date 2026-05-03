#!/usr/bin/env bats
# tests/test-journal-metadata.bats — TASK-COMM-006
# Tests for @project/@tags/@priority metadata markers in journal_scanner.py

SCANNER_PY="${BATS_TEST_DIRNAME}/../lib/journal_scanner.py"

setup() {
  JRNL_FILE="$(mktemp)"
  cat > "$JRNL_FILE" << 'EOF'
[2026-04-01 09:00] First entry
Body text. @project:planning @tags:newent,research @priority:H

[2026-04-02 14:30] Second entry
Just a body. No metadata.

[2026-04-03 10:15] Third entry
Another body. @project:planning @tags:shipped @priority:M

[2026-04-04 08:00] Fourth entry
Fourth body. @tags:research
EOF
}

teardown() {
  rm -f "$JRNL_FILE"
}

# ── parse_metadata unit tests ─────────────────────────────────────────────────

@test "parse-metadata: extracts project from body" {
  run python3 "$SCANNER_PY" parse-metadata "$JRNL_FILE" "@project:planning"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['ok']
assert d['metadata']['project'] == 'planning'"
}

@test "parse-metadata: extracts tags as list" {
  run python3 "$SCANNER_PY" parse-metadata "$JRNL_FILE" "@tags:foo,bar"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert 'foo' in d['metadata']['tags']
assert 'bar' in d['metadata']['tags']"
}

@test "parse-metadata: extracts priority" {
  run python3 "$SCANNER_PY" parse-metadata "$JRNL_FILE" "@priority:H"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['metadata']['priority'] == 'H'"
}

@test "parse-metadata: empty string returns empty metadata" {
  run python3 "$SCANNER_PY" parse-metadata "$JRNL_FILE" "no markers here"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['metadata']['project'] == ''
assert d['metadata']['tags'] == []
assert d['metadata']['priority'] == ''"
}

# ── parse includes metadata fields ───────────────────────────────────────────

@test "parse: each entry has project, tags, priority fields" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
for e in d['entries']:
    assert 'project' in e, 'missing project'
    assert 'tags' in e, 'missing tags'
    assert 'priority' in e, 'missing priority'"
}

@test "parse: first entry has correct metadata" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
for e in d['entries']:
    if e['date'] == '2026-04-01 09:00':
        assert e['project'] == 'planning', 'wrong project: '+e['project']
        assert 'newent' in e['tags'], 'missing newent tag'
        assert 'research' in e['tags'], 'missing research tag'
        assert e['priority'] == 'H', 'wrong priority: '+e['priority']"
}

@test "parse: entry without metadata has empty fields" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
for e in d['entries']:
    if e['date'] == '2026-04-02 14:30':
        assert e['project'] == '', 'expected empty project'
        assert e['tags'] == [], 'expected empty tags'
        assert e['priority'] == '', 'expected empty priority'"
}

# ── filter: --tag ─────────────────────────────────────────────────────────────

@test "filter: --tag returns only entries with that tag" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE" --tag research
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
entries = d['entries']
assert len(entries) == 2, 'expected 2, got '+str(len(entries))
for e in entries:
    assert 'research' in e['tags'], 'tag missing on '+e['date']"
}

@test "filter: --project returns only entries in that project" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE" --project planning
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
entries = d['entries']
assert len(entries) == 2, 'expected 2, got '+str(len(entries))
for e in entries:
    assert e['project'] == 'planning', 'wrong project on '+e['date']"
}

@test "filter: --priority returns only entries with that priority" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE" --priority H
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
entries = d['entries']
assert len(entries) == 1, 'expected 1, got '+str(len(entries))
assert entries[0]['priority'] == 'H'"
}

@test "filter: combined --tag and --project is ANDed" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE" --tag research --project planning
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
entries = d['entries']
assert len(entries) == 1, 'expected 1, got '+str(len(entries))
e = entries[0]
assert 'research' in e['tags']
assert e['project'] == 'planning'"
}

@test "filter: unknown tag returns empty entries" {
  run python3 "$SCANNER_PY" parse "$JRNL_FILE" --tag nonexistent
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert d['entries'] == []"
}

# ── retroactive metadata edit (AC4) ──────────────────────────────────────────

@test "retroactive: annotation metadata overrides body metadata" {
  # Entry starts with @project:planning; annotate with updated project
  python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2026-04-01_09-00 "@project:updated @tags:shifted"
  run python3 "$SCANNER_PY" parse "$JRNL_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
for e in d['entries']:
    if e['date'] == '2026-04-01 09:00':
        assert e['project'] == 'updated', 'expected updated, got '+e['project']
        assert 'shifted' in e['tags'], 'expected shifted tag'"
}

@test "retroactive: filter reflects updated annotation metadata" {
  python3 "$SCANNER_PY" annotate "$JRNL_FILE" 2026-04-01_09-00 "@project:newproject"
  run python3 "$SCANNER_PY" parse "$JRNL_FILE" --project newproject
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import json,sys; d=json.load(sys.stdin)
assert len(d['entries']) == 1
assert d['entries'][0]['date'] == '2026-04-01 09:00'"
}
