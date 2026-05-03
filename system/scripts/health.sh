#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

WARN_COUNT=0
FAIL_COUNT_H=0

_section() { echo ""; echo "── $* ──────────────────────────────────────────────────"; }
_pass()  { printf "  PASS  %s\n" "$*"; }
_warn()  { printf "  WARN  %s\n" "$*"; WARN_COUNT=$((WARN_COUNT+1)); }
_fail()  { printf "  FAIL  %s\n" "$*"; FAIL_COUNT_H=$((FAIL_COUNT_H+1)); }

echo "wwctl health"
echo "project: ${WW_ROOT}"
echo "time:    $(timestamp)"

# ── BATS baseline ──────────────────────────────────────────────────────────────
_section "Test Baseline"
if command -v bats &>/dev/null; then
  RESULT=$(cd "${WW_ROOT}" && bats tests/ --tap 2>/dev/null | tail -1 || true)
  PASS_T=$(cd "${WW_ROOT}" && bats tests/ --tap 2>/dev/null | grep -c "^ok" || true)
  FAIL_T=$(cd "${WW_ROOT}" && bats tests/ --tap 2>/dev/null | grep -c "^not ok" || true)
  KNOWN_FAIL=19
  if [[ "${FAIL_T}" -le "${KNOWN_FAIL}" ]]; then
    _pass "${PASS_T} passing / ${FAIL_T} failing (baseline: ${KNOWN_FAIL})"
  else
    _fail "${FAIL_T} failing — exceeds baseline of ${KNOWN_FAIL} (${PASS_T} passing)"
  fi
else
  _warn "bats not installed — skipping test baseline check"
fi

# ── Gate E: untracked TODOs ────────────────────────────────────────────────────
_section "Gate E — Untracked TODOs"
TODOS=$(git -C "${WW_ROOT}" diff HEAD 2>/dev/null | grep -E '^\+.*\b(TODO|FIXME|HACK|XXX|PLACEHOLDER)\b' | grep -v '^+++' || true)
if [[ -z "${TODOS}" ]]; then
  _pass "No new untracked TODOs in uncommitted changes"
else
  _warn "Untracked TODOs found in uncommitted changes:"
  echo "${TODOS}" | sed 's/^/    /'
fi

# Full scan of production paths
PROD_TODOS=$(grep -rn --include="*.sh" --include="*.py" \
  -E '\b(TODO|FIXME|HACK|XXX|PLACEHOLDER)\b' \
  "${WW_ROOT}/lib" "${WW_ROOT}/services" "${WW_ROOT}/bin" 2>/dev/null \
  | grep -v "TASK-" | wc -l | tr -d ' ')
if [[ "${PROD_TODOS}" -gt 0 ]]; then
  _warn "${PROD_TODOS} TODO/FIXME markers in production paths (run: wwctl todo-scan)"
else
  _pass "No untracked TODO markers in production paths"
fi

# ── Artifact hygiene ───────────────────────────────────────────────────────────
_section "Artifact Hygiene"
DS=$(git -C "${WW_ROOT}" ls-files '*.DS_Store' 2>/dev/null | wc -l | tr -d ' ')
SQ=$(git -C "${WW_ROOT}" ls-files '*.sqlite3' 2>/dev/null | wc -l | tr -d ' ')
[[ "${DS}" -eq 0 ]] && _pass "No .DS_Store tracked" || _fail "${DS} .DS_Store file(s) tracked in git"
[[ "${SQ}" -eq 0 ]] && _pass "No .sqlite3 tracked" || _fail "${SQ} .sqlite3 file(s) tracked in git"

# ── Docs staleness ─────────────────────────────────────────────────────────────
_section "Overview Docs"
SOURCE_MAP="${WW_ROOT}/docs/overviews/source-map.yaml"
if [[ -f "${SOURCE_MAP}" ]]; then
  STALE_COUNT=$(bash "${SCRIPT_DIR}/docs-check.sh" 2>/dev/null | grep -c "^  STALE" || true)
  if [[ "${STALE_COUNT}" -eq 0 ]]; then
    _pass "All overview docs current"
  else
    _warn "${STALE_COUNT} overview doc(s) stale (run: wwctl docs-check)"
  fi
else
  _warn "source-map.yaml not found — docs staleness unknown"
fi

# ── Active worktrees ───────────────────────────────────────────────────────────
_section "Active Worktrees"
TREES=$(git -C "${WW_ROOT}" worktree list 2>/dev/null | grep "agent/" || true)
if [[ -z "${TREES}" ]]; then
  _pass "No active agent worktrees"
else
  NOW=$(date +%s)
  while IFS= read -r line; do
    path=$(echo "${line}" | awk '{print $1}')
    branch=$(echo "${line}" | grep -o '\[.*\]' | tr -d '[]')
    # Age from directory mtime
    if [[ -d "${path}" ]]; then
      mtime=$(stat -f "%m" "${path}" 2>/dev/null || stat -c "%Y" "${path}" 2>/dev/null || echo "${NOW}")
      age=$(( (NOW - mtime) / 86400 ))
      dirty=$(git -C "${path}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      dirty_flag=""
      [[ "${dirty}" -gt 0 ]] && dirty_flag=" [${dirty} uncommitted]"
      if [[ "${age}" -gt 7 ]]; then
        _warn "${branch} — ${age}d old${dirty_flag}"
      else
        _pass "${branch} — ${age}d old${dirty_flag}"
      fi
    fi
  done <<< "${TREES}"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────────────────────────────"
echo "  warnings: ${WARN_COUNT}  failures: ${FAIL_COUNT_H}"
if [[ "${FAIL_COUNT_H}" -gt 0 ]]; then
  echo "  Status: UNHEALTHY — resolve failures"
  exit 1
elif [[ "${WARN_COUNT}" -gt 0 ]]; then
  echo "  Status: WARNINGS — review before proceeding"
else
  echo "  Status: HEALTHY"
fi
