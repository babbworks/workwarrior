#!/usr/bin/env bash
# check-regression.sh — THE regression gate (TASK-TEST-004).
#
# decisions.md (2026-07-10): "the green exit code lies; only a failing-test-NAME-set diff
# exposes it." That is correct, and it is why this script exists: the suite has ~60 known
# failures, so exit codes carry no information. What carries information is WHICH tests
# fail.
#
# Until 2026-07-13 this could not be done, because the baseline DIFFERED FROM ITSELF
# (identical code, consecutive runs: 60 then 64 failures) — shared mutable state and
# racing browser servers. That is fixed; the set is now stable across three consecutive
# runs, and captured in dev/tests/known-failures.txt.
#
# Exit 0 = no new failures. Exit 1 = REGRESSION (a test fails that is not in the baseline).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASELINE="${REPO_ROOT}/dev/tests/known-failures.txt"
SUITE="${1:-${REPO_ROOT}/dev/tests/}"

[[ -f "$BASELINE" ]] || { echo "No baseline at $BASELINE" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Running $SUITE ..."
# The suite has known failures, so a non-zero exit here is expected and not the signal.
bats "$SUITE" 2>&1 | grep '^not ok' | sed 's/^not ok [0-9]* //' | sort > "${tmp}/current" || true

grep -v '^#' "$BASELINE" | grep -v '^[[:space:]]*$' | sort > "${tmp}/baseline"

# NEW failures: failing now, not in the baseline. This is the only thing that blocks.
comm -13 "${tmp}/baseline" "${tmp}/current" > "${tmp}/new"
# FIXED: in the baseline, passing now. Not a failure — but the baseline must be updated,
# or it will slowly rot back into meaninglessness.
comm -23 "${tmp}/baseline" "${tmp}/current" > "${tmp}/fixed"

echo ""
echo "  baseline failures: $(wc -l < "${tmp}/baseline" | tr -d ' ')"
echo "  current failures:  $(wc -l < "${tmp}/current" | tr -d ' ')"
echo ""

rc=0

if [[ -s "${tmp}/new" ]]; then
  echo "REGRESSION — these tests fail and are NOT in the baseline:"
  sed 's/^/    /' "${tmp}/new"
  echo ""
  echo "  Do NOT add them to known-failures.txt to make this pass."
  echo "  Either the change broke them, or the test is flaky — fix whichever it is."
  rc=1
fi

if [[ -s "${tmp}/fixed" ]]; then
  echo "FIXED — these were in the baseline and now pass:"
  sed 's/^/    /' "${tmp}/fixed"
  echo ""
  echo "  Good. Remove them from dev/tests/known-failures.txt so the baseline stays honest."
fi

if [[ $rc -eq 0 && ! -s "${tmp}/fixed" ]]; then
  echo "No new failures. Failing set matches the baseline exactly."
fi

exit $rc
