#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

STRUCTURAL_PASS=0
STRUCTURAL_FAIL=0
ROLLOUT_PASS=0
ROLLOUT_FAIL=0
HYGIENE_PASS=0
HYGIENE_FAIL=0

track_check() {
  local category="$1"
  local description="$2"
  local cmd="$3"
  local fail_before="${FAIL_COUNT}"
  local pass_before="${PASS_COUNT}"

  check "${description}" "${cmd}"
  local rc=0
  if [[ "${FAIL_COUNT}" -gt "${fail_before}" ]]; then
    rc=1
  elif [[ "${PASS_COUNT}" -gt "${pass_before}" ]]; then
    rc=0
  fi

  case "${category}" in
    structural)
      if [[ "${rc}" -eq 0 ]]; then STRUCTURAL_PASS=$((STRUCTURAL_PASS + 1)); else STRUCTURAL_FAIL=$((STRUCTURAL_FAIL + 1)); fi
      ;;
    rollout)
      if [[ "${rc}" -eq 0 ]]; then ROLLOUT_PASS=$((ROLLOUT_PASS + 1)); else ROLLOUT_FAIL=$((ROLLOUT_FAIL + 1)); fi
      ;;
    hygiene)
      if [[ "${rc}" -eq 0 ]]; then HYGIENE_PASS=$((HYGIENE_PASS + 1)); else HYGIENE_FAIL=$((HYGIENE_FAIL + 1)); fi
      ;;
  esac
}

echo "Phase 1 Gate Verification"
echo "workwarrior root: ${WW_ROOT}"
echo "devsystem root:   ${CODEX_ROOT}"
echo "─────────────────────────────────────"

# ── Context Files ──────────────────────────────────────────────────────────────
echo ""
echo "Context Files"
track_check rollout "Root CLAUDE.md deployed to project" "[[ -f '${WW_ROOT}/CLAUDE.md' ]]"
track_check rollout "services/CLAUDE.md deployed to project" "[[ -f '${WW_ROOT}/services/CLAUDE.md' ]]"
track_check rollout "Root CLAUDE.md has shell scripting standards" "grep -q 'set -euo pipefail' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"
track_check rollout "Root CLAUDE.md has fragility markers" "grep -q 'HIGH FRAGILITY' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"
track_check rollout "Root CLAUDE.md has testing section" "grep -q 'Testing Requirements' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"
track_check rollout "Root CLAUDE.md references TASKS.md" "grep -q 'TASKS.md' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"

# ── Task Board ─────────────────────────────────────────────────────────────────
echo ""
echo "Canonical Task Board"
track_check rollout "TASKS.md exists at project root" "[[ -f '${WW_ROOT}/TASKS.md' ]]"
track_check rollout "pending/ has no new files (archive-only)" "[[ \$(find '${WW_ROOT}/pending' -newer '${WW_ROOT}/pending/IMPLEMENTATION_STATUS.md' -type f 2>/dev/null | wc -l) -eq 0 ]]"

# ── Explorer Outputs ───────────────────────────────────────────────────────────
echo ""
echo "Explorer Audit Outputs"
track_check rollout "Explorer A report exists (audits or outputs)" "[[ -n \"\$(ls '${CODEX_ROOT}/outputs/'*explorer-a* 2>/dev/null)\" || -n \"\$(ls '${CODEX_ROOT}/audits/'*explorer-a* 2>/dev/null)\" ]]"
track_check rollout "Explorer B report exists (audits or outputs)" "[[ -n \"\$(ls '${CODEX_ROOT}/outputs/'*explorer-b* 2>/dev/null)\" || -n \"\$(ls '${CODEX_ROOT}/audits/'*explorer-b* 2>/dev/null)\" ]]"

# ── Fragility ──────────────────────────────────────────────────────────────────
echo ""
echo "Fragility Documentation"
track_check structural "Fragility register exists" "[[ -f '${CODEX_ROOT}/fragility-register.md' ]]"
track_check rollout "Root CLAUDE.md names fragility files" "grep -q 'lib/github' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"
track_check rollout "Root CLAUDE.md names serialized files" "grep -q 'bin/ww' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"

# ── Test Baseline ──────────────────────────────────────────────────────────────
echo ""
echo "Test Baseline"
track_check structural "test-baseline.yaml exists" "[[ -f '${CODEX_ROOT}/config/test-baseline.yaml' ]]"
track_check structural "select-tests.sh exists and is executable" "[[ -x '${CODEX_ROOT}/scripts/select-tests.sh' ]]"
track_check rollout "Root CLAUDE.md has test baseline by change type" "grep -q 'change type' '${WW_ROOT}/CLAUDE.md' 2>/dev/null || grep -q 'Change type' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"

# ── Repository Hygiene ─────────────────────────────────────────────────────────
echo ""
echo "Repository Hygiene"
track_check hygiene "No .DS_Store tracked in git" "[[ \$(git -C '${WW_ROOT}' ls-files '*.DS_Store' 2>/dev/null | wc -l) -eq 0 ]]"
track_check hygiene "No sqlite3 files tracked in git" "[[ \$(git -C '${WW_ROOT}' ls-files '*.sqlite3' 2>/dev/null | wc -l) -eq 0 ]]"
track_check hygiene ".gitignore exists" "[[ -f '${WW_ROOT}/.gitignore' ]]"
track_check hygiene ".gitignore covers DS_Store" "grep -q 'DS_Store' '${WW_ROOT}/.gitignore' 2>/dev/null"

echo ""
echo "Category Summary"
echo "  structural: ${STRUCTURAL_PASS} passed / ${STRUCTURAL_FAIL} failed"
echo "  rollout:    ${ROLLOUT_PASS} passed / ${ROLLOUT_FAIL} failed"
echo "  hygiene:    ${HYGIENE_PASS} passed / ${HYGIENE_FAIL} failed"

echo ""
echo "Next Actions"
if [[ "${ROLLOUT_FAIL}" -gt 0 ]]; then
  echo "  rollout: deploy project-level files (CLAUDE.md, services/CLAUDE.md, TASKS.md) and run Explorer audits."
fi
if [[ "${HYGIENE_FAIL}" -gt 0 ]]; then
  echo "  hygiene: run artifact cleanup task and tighten .gitignore."
fi
if [[ "${STRUCTURAL_FAIL}" -gt 0 ]]; then
  echo "  structural: fix system config/docs/scripts before Phase 1 completion."
fi

print_summary

[[ "${FAIL_COUNT}" -eq 0 ]]
