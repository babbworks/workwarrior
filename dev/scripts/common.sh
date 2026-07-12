#!/usr/bin/env bash
set -euo pipefail

CODEX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_git_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

if WW_ROOT="$(find_git_root "${CODEX_ROOT}")"; then
  :
else
  WW_ROOT="$(cd "${CODEX_ROOT}/../.." && pwd)"
fi

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

warn() {
  echo "WARN: $*" >&2
}

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || fail "Missing required file: ${path}"
}

require_dir() {
  local path="$1"
  [[ -d "${path}" ]] || fail "Missing required directory: ${path}"
}

timestamp() {
  date +"%Y-%m-%dT%H:%M:%S"
}

# Print a labelled PASS/FAIL line and update counters
# Usage: check_result "description" <exit-code>
PASS_COUNT=0
FAIL_COUNT=0

check() {
  local description="$1"
  local cmd="$2"
  if eval "${cmd}" >/dev/null 2>&1; then
    echo "  PASS  ${description}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL  ${description}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

print_summary() {
  echo ""
  echo "─────────────────────────────────────"
  echo "  ${PASS_COUNT} passed  /  ${FAIL_COUNT} failed"
  if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo "  Status: ALL CLEAR"
  else
    echo "  Status: BLOCKED — resolve failures before proceeding"
  fi
  echo "─────────────────────────────────────"
}
