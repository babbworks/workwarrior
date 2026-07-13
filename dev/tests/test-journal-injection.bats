#!/usr/bin/env bats
# test-journal-injection.bats — TASK-JRN-001
#
# `ww journal write --journal <name>` interpolated the user's value straight into PYTHON
# SOURCE via an unquoted heredoc. Arbitrary Python then ran as the user. Reproduced
# 2026-07-13 with a harmless marker; the file was written.
#
# The audit's sharpest finding is why it survived: the 5 dedicated journal suites were
# 88/88 GREEN while the hole was open. Eighty-eight tests protecting the paths nobody was
# worried about. This suite protects the path someone WAS worried about.
#
# Two layers of defence, both tested:
#   1. STRUCTURAL — no `python3 - <<DELIM` in bin/ww may use an unquoted delimiter. This is
#      a grep gate: the bug cannot silently return via a new call site.
#   2. BEHAVIOURAL — the exact proven payload, plus variants, must not execute.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  BIN_WW="${REPO_ROOT}/bin/ww"
  MARKER="${BATS_TEST_TMPDIR}/PWNED"
  rm -f "$MARKER"
}

# ── Layer 1: the pattern cannot return ───────────────────────────────────────

@test "STRUCTURAL: bin/ww has NO unquoted python heredocs (<<EOF expands into program text)" {
  # An unquoted delimiter is expanded by the SHELL before python sees it, so any ${var}
  # inside becomes part of the program. A quoted delimiter (<<'EOF') is inert.
  run grep -nE "python3 .*<<[A-Za-z_]" "$BIN_WW"
  [ "$status" -ne 0 ]   # grep finds nothing = no vulnerable heredocs
  [ -z "$output" ]
}

@test "STRUCTURAL: bin/ww still uses quoted python heredocs (we did not just delete them)" {
  run bash -c "grep -cE \"python3 .*<<'\" '$BIN_WW'"
  [ "$output" -ge 5 ]
}

# ── Layer 2: the payloads ────────────────────────────────────────────────────
#
# We exercise the CONSTRUCT rather than the full `ww journal write` command, because the
# latter needs an active profile. The construct is copied verbatim from the fixed call
# site: a value crossing the shell->python boundary via argv, inside a quoted heredoc.

_resolve_with() {
  # Mirrors the fixed bin/ww journal-resolution boundary exactly.
  local val="$1"
  python3 - "$val" <<'PYEOF' 2>/dev/null
import sys, os
journal_name = sys.argv[1] if len(sys.argv) > 1 else ""
print(journal_name)
PYEOF
}

@test "the EXACT proven exploit does not execute" {
  # This payload wrote a file through the old code. It must now be inert data.
  local payload="x\"; open(\"${MARKER}\",\"w\").write(\"pwned\"); y=\""
  run _resolve_with "$payload"
  [ ! -f "$MARKER" ]                    # nothing executed
  [[ "$output" == *'open('* ]]          # and it came back as a literal STRING
}

@test "a double quote is data, not a string terminator" {
  run _resolve_with 'work"name'
  [ ! -f "$MARKER" ]
  [ "$output" = 'work"name' ]
}

@test "a single quote is data" {
  run _resolve_with "work'name"
  [ ! -f "$MARKER" ]
  [ "$output" = "work'name" ]
}

@test "triple quotes are data (the scanner payload used ''' to escape a literal)" {
  run _resolve_with "a'''b"
  [ ! -f "$MARKER" ]
  [ "$output" = "a'''b" ]
}

@test "a semicolon does not start a new python statement" {
  run _resolve_with 'work; import os'
  [ ! -f "$MARKER" ]
  [ "$output" = 'work; import os' ]
}

@test "command substitution is not evaluated" {
  run _resolve_with 'work$(touch '"${MARKER}"')'
  [ ! -f "$MARKER" ]
}

@test "backticks are not evaluated" {
  run _resolve_with 'work`touch '"${MARKER}"'`'
  [ ! -f "$MARKER" ]
}

@test "a newline cannot inject a statement" {
  run _resolve_with "work
import os"
  [ ! -f "$MARKER" ]
}

@test "an empty journal name is handled, not crashed on" {
  run _resolve_with ""
  [ "$status" -eq 0 ]
}

# ── the JSON payload path (site ~3561): journal CONTENT is user data ─────────

@test "scanner JSON crosses via the environment, not interpolated into the program" {
  # A journal entry whose body contains ''' escaped the triple-quoted literal.
  local evil='{"entries":[{"date":"2026-01-01","body":"'"'"''"'"''"'"' + __import__(\"os\").system(\"touch '"${MARKER}"'\") + '"'"''"'"''"'"'","project":"","tags":[],"priority":""}]}'
  run env WW_SCAN_JSON="$evil" python3 - <<'PYEOF'
import json, os
d = json.loads(os.environ.get("WW_SCAN_JSON", "{}"))
for e in d.get("entries", []):
    print(e["body"][:40])
PYEOF
  [ ! -f "$MARKER" ]
}
