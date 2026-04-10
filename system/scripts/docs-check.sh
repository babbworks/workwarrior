#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

SOURCE_MAP="${WW_ROOT}/docs/overviews/source-map.yaml"

[[ -f "${SOURCE_MAP}" ]] || fail "source-map.yaml not found at ${SOURCE_MAP}"

STALE=0
CURRENT=0
UNMAPPED=0

# Get last git commit timestamp (unix epoch) for a file, or 0 if untracked
_git_mtime() {
  local f="$1"
  git -C "${WW_ROOT}" log -1 --format="%ct" -- "${f}" 2>/dev/null || echo "0"
}

# Parse source-map.yaml with awk — no yq dependency
# Outputs: doc_path|source1,source2,...
_parse_source_map() {
  awk '
    /^docs\// { doc=$0; gsub(/:$/, "", doc); sources=""; next }
    /^  sources:/ { next }
    /^    - / { src=$0; gsub(/^    - /, "", src); gsub(/ *$/, "", src);
                sources = (sources == "") ? src : sources "," src; next }
    /^$/ { if (doc != "" && sources != "") print doc "|" sources; doc=""; sources="" }
    END  { if (doc != "" && sources != "") print doc "|" sources }
  ' "${SOURCE_MAP}"
}

echo "wwctl docs-check"
echo "source-map: ${SOURCE_MAP}"
echo "project:    ${WW_ROOT}"
echo "─────────────────────────────────────────────────────────────"

while IFS='|' read -r doc sources_csv; do
  doc_abs="${WW_ROOT}/${doc}"

  if [[ ! -f "${doc_abs}" ]]; then
    printf "  MISSING  %s\n" "${doc}"
    UNMAPPED=$((UNMAPPED + 1))
    continue
  fi

  # Last commit time of the doc itself
  doc_mtime=$(_git_mtime "${doc}")

  # Latest commit time across all source files
  latest_src_mtime=0
  latest_src=""
  IFS=',' read -ra src_list <<< "${sources_csv}"
  for src in "${src_list[@]}"; do
    src_mtime=$(_git_mtime "${src}")
    if [[ "${src_mtime}" -gt "${latest_src_mtime}" ]]; then
      latest_src_mtime="${src_mtime}"
      latest_src="${src}"
    fi
  done

  if [[ "${latest_src_mtime}" -eq 0 && "${doc_mtime}" -eq 0 ]]; then
    printf "  UNMAPPED %s\n" "${doc}"
    UNMAPPED=$((UNMAPPED + 1))
  elif [[ "${latest_src_mtime}" -gt "${doc_mtime}" ]]; then
    src_date=$(git -C "${WW_ROOT}" log -1 --format="%ci" -- "${latest_src}" 2>/dev/null | cut -c1-10)
    doc_date=$(git -C "${WW_ROOT}" log -1 --format="%ci" -- "${doc}" 2>/dev/null | cut -c1-10)
    printf "  STALE    %s\n" "${doc}"
    printf "           source: %s (%s) > doc (%s)\n" "${latest_src}" "${src_date}" "${doc_date:-untracked}"
    STALE=$((STALE + 1))
  else
    printf "  CURRENT  %s\n" "${doc}"
    CURRENT=$((CURRENT + 1))
  fi
done < <(_parse_source_map)

echo "─────────────────────────────────────────────────────────────"
echo "  current: ${CURRENT}  stale: ${STALE}  unmapped/missing: ${UNMAPPED}"

if [[ "${STALE}" -gt 0 ]]; then
  echo "  Status: STALE DOCS — update before marking task complete (Gate C)"
  exit 1
else
  echo "  Status: ALL CURRENT"
fi
