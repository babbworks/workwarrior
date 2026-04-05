#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ROLE="${1:-}"
TOPIC="${2:-}"
TASK_FILE="${3:-}"

[[ -n "${ROLE}" && -n "${TOPIC}" && -n "${TASK_FILE}" ]] || \
  fail "Usage: dispatch-worktree.sh <role> <topic> <task-card-path>"

[[ -f "${TASK_FILE}" ]] || fail "Task card not found: ${TASK_FILE}"

BRANCH="agent/${ROLE}/${TOPIC}"
WORKTREE_DIR="${WW_ROOT}/.worktrees/${ROLE}-${TOPIC}"

mkdir -p "${WW_ROOT}/.worktrees"

if git -C "${WW_ROOT}" rev-parse --verify "${BRANCH}" >/dev/null 2>&1; then
  git -C "${WW_ROOT}" worktree add "${WORKTREE_DIR}" "${BRANCH}"
else
  git -C "${WW_ROOT}" worktree add -b "${BRANCH}" "${WORKTREE_DIR}"
fi

echo "Dispatched:"
echo "  branch:   ${BRANCH}"
echo "  worktree: ${WORKTREE_DIR}"
echo "  task:     ${TASK_FILE}"

