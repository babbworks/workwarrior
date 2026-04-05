#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

echo "Phase 1 Gate Verification"
echo "workwarrior root: ${WW_ROOT}"
echo "devsystem root:   ${CODEX_ROOT}"
echo "─────────────────────────────────────"

# ── Context Files ──────────────────────────────────────────────────────────────
echo ""
echo "Context Files"
check "Root CLAUDE.md deployed to project" "[[ -f '${WW_ROOT}/CLAUDE.md' ]]"
check "services/CLAUDE.md deployed to project" "[[ -f '${WW_ROOT}/services/CLAUDE.md' ]]"
check "Root CLAUDE.md has shell scripting standards" "grep -q 'set -euo pipefail' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"
check "Root CLAUDE.md has fragility markers" "grep -q 'HIGH FRAGILITY' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"
check "Root CLAUDE.md has testing section" "grep -q 'Testing Requirements' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"
check "Root CLAUDE.md references TASKS.md" "grep -q 'TASKS.md' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"

# ── Task Board ─────────────────────────────────────────────────────────────────
echo ""
echo "Canonical Task Board"
check "TASKS.md exists at project root" "[[ -f '${WW_ROOT}/TASKS.md' ]]"
check "pending/ has no new files (archive-only)" "[[ \$(find '${WW_ROOT}/pending' -newer '${WW_ROOT}/pending/IMPLEMENTATION_STATUS.md' -type f 2>/dev/null | wc -l) -eq 0 ]]"

# ── Explorer Outputs ───────────────────────────────────────────────────────────
echo ""
echo "Explorer Audit Outputs"
check "Explorer A report exists" "[[ -n \"\$(ls '${CODEX_ROOT}/audits/'*explorer-a* 2>/dev/null)\" ]]"
check "Explorer B report exists" "[[ -n \"\$(ls '${CODEX_ROOT}/audits/'*explorer-b* 2>/dev/null)\" ]]"

# ── Fragility ──────────────────────────────────────────────────────────────────
echo ""
echo "Fragility Documentation"
check "Fragility register exists" "[[ -f '${CODEX_ROOT}/fragility-register.md' ]]"
check "Root CLAUDE.md names fragility files" "grep -q 'lib/github' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"
check "Root CLAUDE.md names serialized files" "grep -q 'bin/ww' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"

# ── Test Baseline ──────────────────────────────────────────────────────────────
echo ""
echo "Test Baseline"
check "test-baseline.yaml exists" "[[ -f '${CODEX_ROOT}/config/test-baseline.yaml' ]]"
check "Root CLAUDE.md has test baseline by change type" "grep -q 'change type' '${WW_ROOT}/CLAUDE.md' 2>/dev/null || grep -q 'Change type' '${WW_ROOT}/CLAUDE.md' 2>/dev/null"

# ── Repository Hygiene ─────────────────────────────────────────────────────────
echo ""
echo "Repository Hygiene"
check "No .DS_Store tracked in git" "[[ \$(git -C '${WW_ROOT}' ls-files '*.DS_Store' 2>/dev/null | wc -l) -eq 0 ]]"
check "No sqlite3 files tracked in git" "[[ \$(git -C '${WW_ROOT}' ls-files '*.sqlite3' 2>/dev/null | wc -l) -eq 0 ]]"
check ".gitignore exists" "[[ -f '${WW_ROOT}/.gitignore' ]]"
check ".gitignore covers DS_Store" "grep -q 'DS_Store' '${WW_ROOT}/.gitignore' 2>/dev/null"

print_summary

[[ "${FAIL_COUNT}" -eq 0 ]]
