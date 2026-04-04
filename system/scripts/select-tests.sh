#!/usr/bin/env bash
# select-tests.sh — Map change type(s) to required test commands
#
# Usage:
#   select-tests.sh <type>               Print required test commands (list mode)
#   select-tests.sh <type> --run         Print and execute; exit non-zero if any automated test fails
#   select-tests.sh <type1> <type2> ...  Union of multiple change types (deduplicated)
#
# Change types: lib | service | profile | shell_integration | bin_ww | github_sync
#
# NOTE: Keep change types in sync with config/test-baseline.yaml.
#       Adding a new type here requires adding it there too, and vice versa.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

USAGE="Usage: select-tests.sh <change-type> [<change-type2> ...] [--run]
Change types: lib | service | profile | shell_integration | bin_ww | github_sync"

# ── Argument parsing ─────────────────────────────────────────────────────────

RUN_MODE=0
TYPES=()

for arg in "$@"; do
  case "$arg" in
    --run) RUN_MODE=1 ;;
    --help|-h) echo "$USAGE"; exit 0 ;;
    lib|service|profile|shell_integration|bin_ww|github_sync) TYPES+=("$arg") ;;
    *) fail "Unknown argument: $arg"$'\n'"$USAGE" ;;
  esac
done

if (( ${#TYPES[@]} == 0 )); then
  fail "At least one change type is required."$'\n'"$USAGE"
fi

# ── Test command definitions ──────────────────────────────────────────────────
# Returns newline-separated test commands for a given change type.
# Prefix "manual:" marks commands that require human execution (not auto-run).

get_tests_for_type() {
  local type="$1"
  case "$type" in
    lib)
      echo "bats tests/"
      ;;
    service)
      echo "bats tests/test-service-discovery.bats"
      echo "bash tests/test-service-discovery.sh"
      echo "bats tests/"
      ;;
    profile)
      echo "bats tests/test-directory-structure.bats"
      echo "bats tests/test-backup-portability.bats"
      echo "bash tests/test-scripts-integration.sh"
      echo "bats tests/"
      ;;
    shell_integration)
      echo "bats tests/test-shell-functions.bats"
      echo "bats tests/test-alias-creation.bats"
      echo "bats tests/"
      ;;
    bin_ww)
      echo "bats tests/"
      echo "manual: ww help"
      echo "manual: ww profile list"
      ;;
    github_sync)
      echo "bash tests/run-integration-tests.sh"
      echo "bats tests/"
      ;;
  esac
}

# ── Build deduplicated ordered test list ──────────────────────────────────────

declare -A seen
ORDERED=()

for type in "${TYPES[@]}"; do
  while IFS= read -r cmd; do
    if [[ -z "${seen[$cmd]+set}" ]]; then
      seen["$cmd"]=1
      ORDERED+=("$cmd")
    fi
  done < <(get_tests_for_type "$type")
done

# ── List mode: print and exit ─────────────────────────────────────────────────

if (( RUN_MODE == 0 )); then
  echo "Required tests for change type(s): ${TYPES[*]}"
  echo ""
  for cmd in "${ORDERED[@]}"; do
    if [[ "$cmd" == manual:* ]]; then
      echo "  [MANUAL] ${cmd#manual: }"
    else
      echo "  $cmd"
    fi
  done
  echo ""
  exit 0
fi

# ── Run mode: execute automated tests, print manual reminders ────────────────

echo "Running required tests for change type(s): ${TYPES[*]}"
echo "Working directory: ${WW_ROOT}"
echo ""

PASS_COUNT=0
FAIL_COUNT=0
MANUAL=()

for cmd in "${ORDERED[@]}"; do
  if [[ "$cmd" == manual:* ]]; then
    MANUAL+=("${cmd#manual: }")
    continue
  fi

  echo "▶ $cmd"
  # Run from WW_ROOT so test paths resolve correctly
  if (cd "${WW_ROOT}" && eval "$cmd"); then
    echo "  ✓ passed"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  ✗ FAILED"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  echo ""
done

# ── Summary ───────────────────────────────────────────────────────────────────

echo "─────────────────────────────────────"
echo "  Automated: ${PASS_COUNT} passed / ${FAIL_COUNT} failed"

if (( ${#MANUAL[@]} > 0 )); then
  echo ""
  echo "  Manual steps required before sign-off:"
  for m in "${MANUAL[@]}"; do
    echo "    [ ] $m"
  done
fi

echo "─────────────────────────────────────"

if (( FAIL_COUNT > 0 )); then
  echo ""
  echo "  BLOCKED — resolve test failures before Verifier sign-off"
  exit 1
fi

echo ""
echo "  All automated tests passed."
if (( ${#MANUAL[@]} > 0 )); then
  echo "  Complete manual steps above before sign-off."
fi
exit 0
