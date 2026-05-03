#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Default: last merge commit to HEAD
RANGE="${1:-}"
if [[ -z "${RANGE}" ]]; then
  MERGE=$(git -C "${WW_ROOT}" log --merges --format="%H" -1 2>/dev/null || true)
  if [[ -n "${MERGE}" ]]; then
    RANGE="${MERGE}..HEAD"
  else
    RANGE="HEAD~1..HEAD"
  fi
fi

echo "wwctl diff-summary"
echo "range:   ${RANGE}"
echo "project: ${WW_ROOT}"
echo "─────────────────────────────────────────────────────────────"

# ── Changed source files ───────────────────────────────────────────────────────
echo ""
echo "Changed Files"
CHANGED=$(git -C "${WW_ROOT}" diff --name-only "${RANGE}" 2>/dev/null || true)
if [[ -z "${CHANGED}" ]]; then
  echo "  (none)"
else
  echo "${CHANGED}" | sed 's/^/  /'
fi

# ── Affected task cards (by write scope) ───────────────────────────────────────
echo ""
echo "Potentially Affected Task Cards"
CARDS_DIR="${WW_ROOT}/system/tasks/cards"
FOUND_CARDS=0
while IFS= read -r src; do
  [[ -z "${src}" ]] && continue
  while IFS= read -r card; do
    if grep -q "${src}" "${card}" 2>/dev/null; then
      STATUS=$(grep "^Status:" "${card}" 2>/dev/null | awk '{print $2}' || echo "?")
      printf "  %-40s [%s]  %s\n" "$(basename "${card}" .md)" "${STATUS}" "${src}"
      FOUND_CARDS=$((FOUND_CARDS+1))
    fi
  done < <(find "${CARDS_DIR}" -name "TASK-*.md" 2>/dev/null)
done <<< "${CHANGED}"
[[ "${FOUND_CARDS}" -eq 0 ]] && echo "  (none matched)"

# ── Stale overview docs ────────────────────────────────────────────────────────
echo ""
echo "Overview Docs to Review"
SOURCE_MAP="${WW_ROOT}/docs/overviews/source-map.yaml"
if [[ -f "${SOURCE_MAP}" ]]; then
  STALE_DOCS=0
  while IFS= read -r src; do
    [[ -z "${src}" ]] && continue
    # Find docs that list this source file
    while IFS='|' read -r doc sources_csv; do
      if echo "${sources_csv}" | tr ',' '\n' | grep -qxF "${src}"; then
        printf "  %s  (source: %s)\n" "${doc}" "${src}"
        STALE_DOCS=$((STALE_DOCS+1))
      fi
    done < <(awk '
      /^docs\// { doc=$0; gsub(/:$/, "", doc); sources=""; next }
      /^  sources:/ { next }
      /^    - / { src=$0; gsub(/^    - /, "", src); gsub(/ *$/, "", src);
                  sources = (sources == "") ? src : sources "," src; next }
      /^$/ { if (doc != "" && sources != "") print doc "|" sources; doc=""; sources="" }
      END  { if (doc != "" && sources != "") print doc "|" sources }
    ' "${SOURCE_MAP}")
  done <<< "${CHANGED}"
  [[ "${STALE_DOCS}" -eq 0 ]] && echo "  (none)"
else
  echo "  (source-map.yaml not found)"
fi

# ── Required tests ─────────────────────────────────────────────────────────────
echo ""
echo "Required Tests"
# Detect change types from changed files
TYPES=()
echo "${CHANGED}" | grep -q "^lib/" && TYPES+=("lib")
echo "${CHANGED}" | grep -q "^services/" && TYPES+=("service")
echo "${CHANGED}" | grep -q "^bin/ww$" && TYPES+=("bin_ww")
echo "${CHANGED}" | grep -q "shell-integration" && TYPES+=("shell_integration")
echo "${CHANGED}" | grep -qE "github-sync|sync-pull|sync-push|sync-bidirectional|github-api|sync-detector|conflict-resolver|annotation-sync|field-mapper" && TYPES+=("github_sync")

if [[ "${#TYPES[@]}" -gt 0 ]]; then
  bash "${SCRIPT_DIR}/select-tests.sh" "${TYPES[@]}"
else
  echo "  No production code changes detected — no specific test suite required"
fi
