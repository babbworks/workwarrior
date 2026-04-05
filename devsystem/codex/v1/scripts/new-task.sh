#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TASK_ID="${1:-}"
GOAL="${2:-}"

[[ -n "${TASK_ID}" ]] || fail "Usage: new-task.sh <TASK-ID> <goal>"
[[ -n "${GOAL}" ]] || fail "Usage: new-task.sh <TASK-ID> <goal>"

TEMPLATE="${CODEX_ROOT}/templates/task-card.md"
TASK_FILE="${CODEX_ROOT}/tasks/cards/${TASK_ID}.md"

require_file "${TEMPLATE}"
[[ ! -f "${TASK_FILE}" ]] || fail "Task already exists: ${TASK_FILE}"

sed \
  -e "s/TASK-XXX/${TASK_ID}/g" \
  -e "s/\[Title\]/${GOAL}/g" \
  -e "s/\[one sentence\]/${GOAL}/g" \
  "${TEMPLATE}" > "${TASK_FILE}"

echo "Created task card: ${TASK_FILE}"

