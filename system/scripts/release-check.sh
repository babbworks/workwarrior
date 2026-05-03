#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

echo "wwctl release-check"
echo "project: ${WW_ROOT}"
echo "time:    $(timestamp)"
echo "─────────────────────────────────────────────────────────────"

# ── Open tasks in dispatch queue ───────────────────────────────────────────────
echo ""
echo "Task Board"
TASKS_MD="${WW_ROOT}/system/TASKS.md"
if [[ -f "${TASKS_MD}" ]]; then
  PENDING=$(grep -c "| pending |" "${TASKS_MD}" 2>/dev/null || echo "0")
  IN_PROG=$(grep -c "| in-progress |" "${TASKS_MD}" 2>/dev/null || echo "0")
  BLOCKED=$(grep -c "| blocked |" "${TASKS_MD}" 2>/dev/null || echo "0")
  IN_REV=$(grep -c "| in-review |" "${TASKS_MD}" 2>/dev/null || echo "0")
  check "No in-progress tasks" "[[ ${IN_PROG} -eq 0 ]]"
  check "No blocked tasks" "[[ ${BLOCKED} -eq 0 ]]"
  check "No in-review tasks" "[[ ${IN_REV} -eq 0 ]]"
  echo "  (${PENDING} pending tasks remain in backlog — expected)"
else
  check "TASKS.md exists" "[[ -f '${TASKS_MD}' ]]"
fi

# ── Gate E: untracked TODOs ────────────────────────────────────────────────────
echo ""
echo "Gate E — TODOs"
UNTRACKED=$(bash "${SCRIPT_DIR}/todo-scan.sh" 2>/dev/null | grep -c "^  UNTRACKED" || true)
check "No untracked TODOs in production paths" "[[ ${UNTRACKED} -eq 0 ]]"

# ── Docs current ──────────────────────────────────────────────────────────────
echo ""
echo "Gate C — Docs"
SOURCE_MAP="${WW_ROOT}/docs/overviews/source-map.yaml"
if [[ -f "${SOURCE_MAP}" ]]; then
  STALE=$(bash "${SCRIPT_DIR}/docs-check.sh" 2>/dev/null | grep -c "^  STALE" || true)
  check "No stale overview docs" "[[ ${STALE} -eq 0 ]]"
else
  check "source-map.yaml exists" "[[ -f '${SOURCE_MAP}' ]]"
fi

# ── Artifact hygiene ───────────────────────────────────────────────────────────
echo ""
echo "Artifact Hygiene"
check "No .DS_Store tracked" "[[ \$(git -C '${WW_ROOT}' ls-files '*.DS_Store' 2>/dev/null | wc -l) -eq 0 ]]"
check "No .sqlite3 tracked" "[[ \$(git -C '${WW_ROOT}' ls-files '*.sqlite3' 2>/dev/null | wc -l) -eq 0 ]]"
check ".gitignore exists" "[[ -f '${WW_ROOT}/.gitignore' ]]"
check "git status clean" "[[ -z \"\$(git -C '${WW_ROOT}' status --porcelain 2>/dev/null)\" ]]"

# ── BATS baseline ──────────────────────────────────────────────────────────────
echo ""
echo "Test Baseline"
if command -v bats &>/dev/null; then
  FAIL_T=$(cd "${WW_ROOT}" && bats tests/ --tap 2>/dev/null | grep -c "^not ok" || true)
  KNOWN=19
  check "BATS failures within baseline (${FAIL_T} <= ${KNOWN})" "[[ ${FAIL_T} -le ${KNOWN} ]]"
else
  warn "bats not installed — skipping"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
print_summary

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  echo ""
  echo "  Gate D NOT satisfied — resolve failures before release claim"
  exit 1
else
  echo ""
  echo "  Gate D SATISFIED — release checklist complete"
  echo "  Sign off: $(timestamp) — $(git -C "${WW_ROOT}" config user.name 2>/dev/null || echo 'unknown')"
fi
