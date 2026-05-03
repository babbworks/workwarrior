#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ROLE="${1:-}"
TOPIC="${2:-}"
TASK_FILE="${3:-}"

[[ -n "${ROLE}" ]] || fail "Usage: dispatch-worktree.sh <role> <topic> <task-card-path>"
[[ -n "${TOPIC}" ]] || fail "Usage: dispatch-worktree.sh <role> <topic> <task-card-path>"
[[ -n "${TASK_FILE}" ]] || fail "Usage: dispatch-worktree.sh <role> <topic> <task-card-path>"
[[ -f "${TASK_FILE}" ]] || fail "Task card not found: ${TASK_FILE}"

# Validate role is known
VALID_ROLES="orchestrator builder verifier explorer docs"
if ! echo "${VALID_ROLES}" | grep -qw "${ROLE}"; then
  fail "Unknown role '${ROLE}'. Valid roles: ${VALID_ROLES}"
fi

# Enforce branch naming convention: agent/<role>/<topic>
BRANCH="agent/${ROLE}/${TOPIC}"
WORKTREE_DIR="${WW_ROOT}/.worktrees/${ROLE}-${TOPIC}"

# Check for SERIALIZED files in task write scope — warn if parallel worktrees exist
SERIALIZED_FILES="${CODEX_ROOT}/config/serialization-paths.txt"
if [[ -f "${SERIALIZED_FILES}" ]]; then
  while IFS= read -r pattern; do
    [[ -z "${pattern}" ]] && continue
    if grep -q "${pattern}" "${TASK_FILE}" 2>/dev/null; then
      # Check if any other worktree is active
      ACTIVE_WORKTREES="$(git -C "${WW_ROOT}" worktree list 2>/dev/null | grep -v "^\[" | grep -v "(bare)" | wc -l)"
      if [[ "${ACTIVE_WORKTREES}" -gt 1 ]]; then
        warn "Serialized file '${pattern}' is in task scope AND other worktrees are active."
        warn "Confirm no other active task touches '${pattern}' before proceeding."
        echo ""
        echo "Active worktrees:"
        git -C "${WW_ROOT}" worktree list
        echo ""
        read -r -p "Confirm this write set is disjoint [y/N]: " confirm
        [[ "${confirm}" =~ ^[Yy]$ ]] || fail "Dispatch cancelled by user."
      fi
    fi
  done < "${SERIALIZED_FILES}"
fi

mkdir -p "${WW_ROOT}/.worktrees"

if git -C "${WW_ROOT}" rev-parse --verify "${BRANCH}" >/dev/null 2>&1; then
  git -C "${WW_ROOT}" worktree add "${WORKTREE_DIR}" "${BRANCH}"
else
  git -C "${WW_ROOT}" worktree add -b "${BRANCH}" "${WORKTREE_DIR}"
fi

echo ""
echo "Worktree dispatched"
echo "  role:     ${ROLE}"
echo "  branch:   ${BRANCH}"
echo "  worktree: ${WORKTREE_DIR}"
echo "  task:     ${TASK_FILE}"
echo ""
echo "Agent prompt prefix available at:"
echo "  ${CODEX_ROOT}/roles/${ROLE}.md"
echo ""
echo "To remove worktree when done:"
echo "  git -C '${WW_ROOT}' worktree remove '${WORKTREE_DIR}'"
