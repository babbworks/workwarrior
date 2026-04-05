#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TASK_ID="${1:-}"
GOAL="${2:-}"

[[ -n "${TASK_ID}" ]] || fail "Usage: new-task.sh <TASK-ID> \"goal sentence\""
[[ -n "${GOAL}" ]] || fail "Usage: new-task.sh <TASK-ID> \"goal sentence\""

TEMPLATE="${CODEX_ROOT}/templates/task-card.md"
CARDS_DIR="${CODEX_ROOT}/tasks/cards"
TASK_FILE="${CARDS_DIR}/${TASK_ID}.md"
TASKS_INDEX="${WW_ROOT}/TASKS.md"

require_file "${TEMPLATE}"
[[ ! -f "${TASK_FILE}" ]] || fail "Task card already exists: ${TASK_FILE}"

# Generate task card from template
sed \
  -e "s/TASK-XXX/${TASK_ID}/g" \
  -e "s/\[Title — verb phrase, specific\]/${GOAL}/g" \
  -e "s/\[One sentence.*\]/${GOAL}/g" \
  "${TEMPLATE}" > "${TASK_FILE}"

echo "Created: ${TASK_FILE}"

# Append to TASKS.md index if it exists
if [[ -f "${TASKS_INDEX}" ]]; then
  # Find the Active Tasks section and append there
  if grep -q "^## Active Tasks" "${TASKS_INDEX}"; then
    # Add a brief index entry under Active Tasks
    # Find the line number of Active Tasks header
    INSERT_LINE="$(grep -n "^## Active Tasks" "${TASKS_INDEX}" | head -1 | cut -d: -f1)"
    INSERT_LINE=$((INSERT_LINE + 2))
    TMP="$(mktemp)"
    awk -v line="${INSERT_LINE}" -v entry="- [${TASK_ID}](devsystem/claude/v2/tasks/cards/${TASK_ID}.md): ${GOAL}" \
      'NR==line {print entry} {print}' "${TASKS_INDEX}" > "${TMP}"
    mv "${TMP}" "${TASKS_INDEX}"
    echo "Indexed in: ${TASKS_INDEX}"
  else
    warn "TASKS.md found but no '## Active Tasks' section — card created but not indexed"
  fi
else
  warn "No TASKS.md at ${TASKS_INDEX} — card created but not indexed"
fi

echo ""
echo "Next: fill in the task card fields, then dispatch:"
echo "  bin/wwctl dispatch <role> <topic> tasks/cards/${TASK_ID}.md"
