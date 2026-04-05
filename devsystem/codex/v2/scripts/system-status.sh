#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

echo "Codex Devsystem Status"
echo "root: ${CODEX_ROOT}"
echo "workwarrior: ${WW_ROOT}"
echo

for f in \
  "${CODEX_ROOT}/CLAUDE.md" \
  "${CODEX_ROOT}/TASKS.md" \
  "${CODEX_ROOT}/config/gates.yaml" \
  "${CODEX_ROOT}/config/roles.yaml" \
  "${CODEX_ROOT}/config/test-baseline.yaml"; do
  if [[ -f "${f}" ]]; then
    echo "OK: ${f}"
  else
    echo "MISSING: ${f}"
  fi
done

echo
echo "Task cards:"
find "${CODEX_ROOT}/tasks/cards" -type f -name "*.md" | sort || true

