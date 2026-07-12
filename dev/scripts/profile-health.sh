#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

PROFILE_NAME="${1:-}"

# Resolve profile
if [[ -n "${PROFILE_NAME}" ]]; then
  PROFILE_BASE="${WW_ROOT}/profiles/${PROFILE_NAME}"
  [[ -d "${PROFILE_BASE}" ]] || fail "Profile '${PROFILE_NAME}' not found"
elif [[ -n "${WARRIOR_PROFILE:-}" && -d "${WORKWARRIOR_BASE:-}" ]]; then
  PROFILE_NAME="${WARRIOR_PROFILE}"
  PROFILE_BASE="${WORKWARRIOR_BASE}"
else
  # Try last profile
  LAST="${WW_ROOT}/.state/last_profile"
  [[ -f "${LAST}" ]] || fail "No active profile and no profile specified. Usage: wwctl profile-health [<name>]"
  PROFILE_NAME=$(cat "${LAST}")
  PROFILE_BASE="${WW_ROOT}/profiles/${PROFILE_NAME}"
  [[ -d "${PROFILE_BASE}" ]] || fail "Last profile '${PROFILE_NAME}' directory not found"
fi

WARN_COUNT=0
FAIL_COUNT_P=0

_ok()   { printf "  OK    %s\n" "$*"; }
_warn() { printf "  WARN  %s\n" "$*"; WARN_COUNT=$((WARN_COUNT+1)); }
_fail() { printf "  FAIL  %s\n" "$*"; FAIL_COUNT_P=$((FAIL_COUNT_P+1)); }
_info() { printf "        %s\n" "$*"; }

echo "wwctl profile-health: ${PROFILE_NAME}"
echo "base: ${PROFILE_BASE}"
echo "─────────────────────────────────────────────────────────────"

# ── TaskWarrior ────────────────────────────────────────────────────────────────
echo ""
echo "TaskWarrior"
TASKRC="${PROFILE_BASE}/.taskrc"
TASKDATA="${PROFILE_BASE}/.task"

if [[ ! -f "${TASKRC}" ]]; then
  _fail ".taskrc missing"
elif [[ ! -d "${TASKDATA}" ]]; then
  _fail ".task/ directory missing"
else
  _ok ".taskrc and .task/ present"
  # Task counts
  PENDING=$(TASKRC="${TASKRC}" TASKDATA="${TASKDATA}" task status:pending count 2>/dev/null || echo "?")
  OVERDUE=$(TASKRC="${TASKRC}" TASKDATA="${TASKDATA}" task status:pending due.before:now count 2>/dev/null || echo "0")
  ACTIVE=$(TASKRC="${TASKRC}" TASKDATA="${TASKDATA}" task status:pending +ACTIVE count 2>/dev/null || echo "0")
  _info "pending: ${PENDING}  overdue: ${OVERDUE}  active: ${ACTIVE}"
  [[ "${OVERDUE}" != "?" && "${OVERDUE}" -gt 10 ]] && _warn "${OVERDUE} overdue tasks"
  [[ "${ACTIVE}" != "?" && "${ACTIVE}" -gt 3 ]] && _warn "${ACTIVE} tasks currently active (started)"
fi

# ── TimeWarrior ────────────────────────────────────────────────────────────────
echo ""
echo "TimeWarrior"
TIMEWDB="${PROFILE_BASE}/.timewarrior"

if [[ ! -d "${TIMEWDB}" ]]; then
  _warn ".timewarrior/ directory missing"
else
  _ok ".timewarrior/ present"
  # Check for open tracking session
  OPEN=$(TIMEWARRIORDB="${TIMEWDB}" timew get dom.active 2>/dev/null || echo "0")
  if [[ "${OPEN}" == "1" ]]; then
    OPEN_TAG=$(TIMEWARRIORDB="${TIMEWDB}" timew get dom.active.tag.1 2>/dev/null || echo "unknown")
    _warn "Open tracking session: ${OPEN_TAG} (run: timew stop)"
  else
    _ok "No open tracking session"
  fi
  # Last entry
  LAST_T=$(TIMEWARRIORDB="${TIMEWDB}" timew summary :ids 2>/dev/null | tail -2 | head -1 | awk '{print $1}' || echo "none")
  _info "last entry: ${LAST_T}"
fi

# ── GitHub Sync ────────────────────────────────────────────────────────────────
echo ""
echo "GitHub Sync"
SYNC_DIR="${TASKDATA}/github-sync"

if [[ ! -d "${SYNC_DIR}" ]]; then
  _info "No GitHub sync state (not configured)"
else
  SYNCED=$(find "${SYNC_DIR}" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
  _ok "${SYNCED} synced task(s)"
  # Check for orphaned state files (task UUID no longer exists)
  ORPHANED=0
  for state_file in "${SYNC_DIR}"/*.json; do
    [[ -f "${state_file}" ]] || continue
    uuid=$(basename "${state_file}" .json)
    exists=$(TASKRC="${TASKRC}" TASKDATA="${TASKDATA}" task _get "${uuid}.uuid" 2>/dev/null || echo "")
    [[ -z "${exists}" ]] && ORPHANED=$((ORPHANED+1))
  done
  [[ "${ORPHANED}" -gt 0 ]] && _warn "${ORPHANED} orphaned sync state file(s) — run: ww issues sync" || _ok "No orphaned sync state"
  # Last sync log entry
  SYNC_LOG="${SYNC_DIR}/sync.log"
  if [[ -f "${SYNC_LOG}" ]]; then
    LAST_SYNC=$(tail -1 "${SYNC_LOG}" | awk '{print $1, $2}' || echo "unknown")
    _info "last sync: ${LAST_SYNC}"
  fi
fi

# ── Journals ───────────────────────────────────────────────────────────────────
echo ""
echo "Journals"
JRNL_YAML="${PROFILE_BASE}/jrnl.yaml"

if [[ ! -f "${JRNL_YAML}" ]]; then
  _warn "jrnl.yaml missing"
else
  J_COUNT=$(grep -c "^  [a-zA-Z]" "${JRNL_YAML}" 2>/dev/null || echo "0")
  _ok "${J_COUNT} journal(s) configured"
  # Last entry across all journals
  LAST_J="none"
  while IFS= read -r jfile; do
    [[ -f "${jfile}" ]] || continue
    entry=$(tail -5 "${jfile}" | grep -E "^\[" | tail -1 | cut -c2-11 || true)
    [[ -n "${entry}" && "${entry}" > "${LAST_J}" ]] && LAST_J="${entry}"
  done < <(grep -E "^\s+journal:" "${JRNL_YAML}" | awk '{print $2}' 2>/dev/null || true)
  _info "last entry: ${LAST_J}"
fi

# ── Ledger ─────────────────────────────────────────────────────────────────────
echo ""
echo "Ledger"
LEDGER_YAML="${PROFILE_BASE}/ledgers.yaml"

if [[ ! -f "${LEDGER_YAML}" ]]; then
  _warn "ledgers.yaml missing"
else
  L_COUNT=$(grep -c "^  [a-zA-Z]" "${LEDGER_YAML}" 2>/dev/null || echo "0")
  _ok "${L_COUNT} ledger(s) configured"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────────────────────────────"
echo "  warnings: ${WARN_COUNT}  failures: ${FAIL_COUNT_P}"
if [[ "${FAIL_COUNT_P}" -gt 0 ]]; then
  echo "  Status: UNHEALTHY"
  exit 1
elif [[ "${WARN_COUNT}" -gt 0 ]]; then
  echo "  Status: WARNINGS"
else
  echo "  Status: HEALTHY"
fi
