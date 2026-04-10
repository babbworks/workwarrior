#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

TASKS_MD="${WW_ROOT}/system/TASKS.md"
UNTRACKED=0
TRACKED=0
ORPHANED=0

echo "wwctl todo-scan"
echo "project: ${WW_ROOT}"
echo "─────────────────────────────────────────────────────────────"

# Scan production paths for TODO markers
while IFS=: read -r file line content; do
  [[ -z "${file}" ]] && continue

  # Extract the marker type
  marker=$(echo "${content}" | grep -oE '\b(TODO|FIXME|HACK|XXX|PLACEHOLDER)\b' | head -1)

  # Check if a TASK-ID is referenced in the same line
  task_ref=$(echo "${content}" | grep -oE 'TASK-[A-Z0-9-]+' | head -1)

  rel_file="${file#${WW_ROOT}/}"

  if [[ -n "${task_ref}" ]]; then
    # Has a task reference — check if that task exists and its status
    card="${WW_ROOT}/system/tasks/cards/${task_ref}.md"
    if [[ -f "${card}" ]]; then
      status=$(grep "^Status:" "${card}" 2>/dev/null | awk '{print $2}' || echo "unknown")
      if [[ "${status}" == "complete" || "${status}" == "closed" ]]; then
        printf "  ORPHANED  %s:%s  [%s → %s is %s]\n" "${rel_file}" "${line}" "${marker}" "${task_ref}" "${status}"
        ORPHANED=$((ORPHANED + 1))
      else
        printf "  TRACKED   %s:%s  [%s → %s (%s)]\n" "${rel_file}" "${line}" "${marker}" "${task_ref}" "${status}"
        TRACKED=$((TRACKED + 1))
      fi
    else
      printf "  TRACKED   %s:%s  [%s → %s (card not found)]\n" "${rel_file}" "${line}" "${marker}" "${task_ref}"
      TRACKED=$((TRACKED + 1))
    fi
  else
    printf "  UNTRACKED %s:%s  %s\n" "${rel_file}" "${line}" "$(echo "${content}" | sed 's/^ *//')"
    UNTRACKED=$((UNTRACKED + 1))
  fi

done < <(grep -rn --include="*.sh" --include="*.py" --include="*.js" --include="*.ts" \
  -E '\b(TODO|FIXME|HACK|XXX|PLACEHOLDER)\b' \
  "${WW_ROOT}/lib" "${WW_ROOT}/services" "${WW_ROOT}/bin" 2>/dev/null || true)

echo "─────────────────────────────────────────────────────────────"
echo "  tracked: ${TRACKED}  untracked: ${UNTRACKED}  orphaned: ${ORPHANED}"

if [[ "${UNTRACKED}" -gt 0 ]]; then
  echo "  Status: GATE E VIOLATION — create task cards for untracked items"
  exit 1
elif [[ "${ORPHANED}" -gt 0 ]]; then
  echo "  Status: ORPHANED — remove TODO comments for completed tasks"
  exit 1
else
  echo "  Status: CLEAN"
fi
