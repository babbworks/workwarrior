#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

echo "Workwarrior Dev System — Status"
echo "  devsystem: ${CODEX_ROOT}"
echo "  project:   ${WW_ROOT}"
echo "  time:      $(timestamp)"
echo ""

# ── Core Files ─────────────────────────────────────────────────────────────────
echo "Core Files"
for f in \
  "${CODEX_ROOT}/CLAUDE.md" \
  "${CODEX_ROOT}/services-CLAUDE.md" \
  "${CODEX_ROOT}/fragility-register.md" \
  "${CODEX_ROOT}/config/gates.yaml" \
  "${CODEX_ROOT}/config/roles.yaml" \
  "${CODEX_ROOT}/config/test-baseline.yaml"; do
  if [[ -f "${f}" ]]; then
    printf "  OK      %s\n" "$(basename "${f}")"
  else
    printf "  MISSING %s\n" "${f}"
  fi
done

# ── Deployed to Project ────────────────────────────────────────────────────────
echo ""
echo "Deployed to Project"
for f in \
  "${WW_ROOT}/CLAUDE.md" \
  "${WW_ROOT}/services/CLAUDE.md" \
  "${WW_ROOT}/TASKS.md"; do
  if [[ -f "${f}" ]]; then
    printf "  DEPLOYED  %s\n" "${f#${WW_ROOT}/}"
  else
    printf "  NOT YET   %s\n" "${f#${WW_ROOT}/}"
  fi
done

# ── Task Cards ─────────────────────────────────────────────────────────────────
echo ""
echo "Task Cards"
CARDS_DIR="${CODEX_ROOT}/tasks/cards"
ALL_CARDS="$(find "${CARDS_DIR}" -name "TASK-*.md" 2>/dev/null | sort)"
if [[ -z "${ALL_CARDS}" ]]; then
  echo "  (none)"
else
  while IFS= read -r card; do
    STATUS="$(grep "^Status:" "${card}" 2>/dev/null | awk '{print $2}' || echo "unknown")"
    GOAL="$(grep "^Goal:" "${card}" 2>/dev/null | sed 's/^Goal: *//' | cut -c1-60 || echo "")"
    printf "  %-12s %-12s %s\n" "$(basename "${card}" .md)" "[${STATUS}]" "${GOAL}"
  done <<< "${ALL_CARDS}"
fi

# ── Explorer Outputs ───────────────────────────────────────────────────────────
echo ""
echo "Audit Outputs"
AUDITS="$(find "${CODEX_ROOT}/audits" -name "*.md" 2>/dev/null | sort)"
if [[ -z "${AUDITS}" ]]; then
  echo "  (none — Explorer A and B not yet run)"
else
  while IFS= read -r f; do
    printf "  %s\n" "$(basename "${f}")"
  done <<< "${AUDITS}"
fi

# ── Active Worktrees ───────────────────────────────────────────────────────────
echo ""
echo "Active Worktrees"
WORKTREES="$(git -C "${WW_ROOT}" worktree list 2>/dev/null | grep "agent/" || true)"
if [[ -z "${WORKTREES}" ]]; then
  echo "  (none)"
else
  echo "${WORKTREES}" | sed 's/^/  /'
fi

# ── Phase 1 Quick Check ────────────────────────────────────────────────────────
echo ""
echo "Phase 1 Quick Check (run 'wwctl verify-phase1' for full report)"
[[ -f "${WW_ROOT}/CLAUDE.md" ]] && echo "  OK  Root CLAUDE.md deployed" || echo "  --  Root CLAUDE.md not yet deployed"
[[ -f "${WW_ROOT}/services/CLAUDE.md" ]] && echo "  OK  services/CLAUDE.md deployed" || echo "  --  services/CLAUDE.md not yet deployed"
[[ -n "$(find "${CODEX_ROOT}/audits" -name "*explorer-a*" 2>/dev/null)" ]] && echo "  OK  Explorer A complete" || echo "  --  Explorer A pending"
[[ -n "$(find "${CODEX_ROOT}/audits" -name "*explorer-b*" 2>/dev/null)" ]] && echo "  OK  Explorer B complete" || echo "  --  Explorer B pending"
[[ -f "${WW_ROOT}/TASKS.md" ]] && echo "  OK  TASKS.md deployed" || echo "  --  TASKS.md not yet deployed"
