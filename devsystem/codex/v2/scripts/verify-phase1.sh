#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

PASS=0
FAIL=0

check() {
  local description="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "PASS: ${description}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: ${description}"
    FAIL=$((FAIL + 1))
  fi
}

check "Root CLAUDE exists" "[[ -f \"${WW_ROOT}/CLAUDE.md\" || -f \"${CODEX_ROOT}/CLAUDE.md\" ]]"
check "services/CLAUDE exists" "[[ -f \"${WW_ROOT}/services/CLAUDE.md\" ]]"
check "Explorer A report exists" "ls \"${CODEX_ROOT}/audits\"/*explorer-a* >/dev/null 2>&1 || ls \"${CODEX_ROOT}/outputs\"/*explorer-a* >/dev/null 2>&1"
check "Explorer B report exists" "ls \"${CODEX_ROOT}/audits\"/*explorer-b* >/dev/null 2>&1 || ls \"${CODEX_ROOT}/outputs\"/*explorer-b* >/dev/null 2>&1"
check "Canonical TASKS exists" "[[ -f \"${WW_ROOT}/TASKS.md\" || -f \"${CODEX_ROOT}/TASKS.md\" ]]"
check "Phase 1 checklist exists" "[[ -f \"${CODEX_ROOT}/config/phase1-checklist.txt\" ]]"

echo "-----"
echo "Summary: ${PASS} passed / ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
