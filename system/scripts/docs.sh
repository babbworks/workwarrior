#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

OVERVIEWS_DIR="${WW_ROOT}/docs/overviews"
SOURCE_MAP="${OVERVIEWS_DIR}/source-map.yaml"

[[ -d "${OVERVIEWS_DIR}" ]] || fail "docs/overviews/ not found at ${OVERVIEWS_DIR}"

# ── Helpers ───────────────────────────────────────────────────────────────────

# Resolve a fuzzy doc name to an absolute path.
# Accepts: full relative path, basename, or partial name.
# Returns the path or exits with a disambiguation list.
_resolve_doc() {
  local query="$1"

  # Exact relative path from overviews root
  local exact="${OVERVIEWS_DIR}/${query}"
  [[ -f "${exact}" ]] && echo "${exact}" && return 0
  # With .md extension
  [[ -f "${exact}.md" ]] && echo "${exact}.md" && return 0

  # Fuzzy: match on basename (without .md)
  local matches=()
  while IFS= read -r f; do
    base=$(basename "${f}" .md)
    if [[ "${base}" == *"${query}"* || "${f}" == *"${query}"* ]]; then
      matches+=("${f}")
    fi
  done < <(find "${OVERVIEWS_DIR}" -name "*.md" ! -name "source-map.yaml" | sort)

  if [[ "${#matches[@]}" -eq 0 ]]; then
    fail "No doc matching '${query}'. Run: wwctl docs list"
  elif [[ "${#matches[@]}" -eq 1 ]]; then
    echo "${matches[0]}"
  else
    echo "Multiple matches for '${query}':" >&2
    for m in "${matches[@]}"; do
      echo "  ${m#${OVERVIEWS_DIR}/}" >&2
    done
    exit 1
  fi
}

# Get staleness status for a doc (CURRENT / STALE / UNMAPPED)
_doc_status() {
  local doc_abs="$1"
  local doc_rel="${doc_abs#${WW_ROOT}/}"

  [[ ! -f "${SOURCE_MAP}" ]] && echo "UNMAPPED" && return 0

  # Find sources for this doc in source-map.yaml
  local sources_csv
  sources_csv=$(awk -v doc="${doc_rel}" '
    /^docs\// { cur=$0; gsub(/:$/, "", cur); sources=""; next }
    /^  sources:/ { next }
    /^    - / { src=$0; gsub(/^    - /, "", src); gsub(/ *$/, "", src);
                sources = (sources == "") ? src : sources "," src; next }
    /^$/ { if (cur == doc && sources != "") { print sources; exit } cur=""; sources="" }
    END  { if (cur == doc && sources != "") print sources }
  ' "${SOURCE_MAP}")

  [[ -z "${sources_csv}" ]] && echo "UNMAPPED" && return 0

  local doc_mtime
  doc_mtime=$(git -C "${WW_ROOT}" log -1 --format="%ct" -- "${doc_rel}" 2>/dev/null || echo "0")

  local latest_src_mtime=0
  IFS=',' read -ra src_list <<< "${sources_csv}"
  for src in "${src_list[@]}"; do
    local src_mtime
    src_mtime=$(git -C "${WW_ROOT}" log -1 --format="%ct" -- "${src}" 2>/dev/null || echo "0")
    [[ "${src_mtime}" -gt "${latest_src_mtime}" ]] && latest_src_mtime="${src_mtime}"
  done

  if [[ "${latest_src_mtime}" -gt "${doc_mtime}" ]]; then
    echo "STALE"
  else
    echo "CURRENT"
  fi
}

# ── Subcommands ───────────────────────────────────────────────────────────────

# Strip markdown formatting for clean terminal display
_strip_md() {
  sed \
    -e 's/^#{1,6} //' \
    -e 's/\*\*\([^*]*\)\*\*/\1/g' \
    -e 's/\*\([^*]*\)\*/\1/g' \
    -e 's/`\([^`]*\)`/\1/g' \
    -e 's/^```[a-z]*//' \
    -e 's/^```//' \
    -e 's/^> /  /' \
    -e 's/^- /  • /' \
    -e 's/^\* /  • /' \
    -e 's/^  - /    · /' \
    -e 's/\[\([^]]*\)\]([^)]*)/\1/g' \
    -e 's/^|/  |/'
}

cmd_docs_index() {
  local raw=0
  [[ "${1:-}" == "--raw" ]] && raw=1
  if [[ "${raw}" -eq 1 ]]; then
    cat "${OVERVIEWS_DIR}/INDEX.md"
  else
    _strip_md < "${OVERVIEWS_DIR}/INDEX.md" | less -R 2>/dev/null || _strip_md < "${OVERVIEWS_DIR}/INDEX.md"
  fi
}

cmd_docs_list() {
  echo "Overview Docs"
  echo "─────────────────────────────────────────────────────────────"
  while IFS= read -r f; do
    local rel="${f#${OVERVIEWS_DIR}/}"
    local status
    status=$(_doc_status "${f}")
    local status_tag
    case "${status}" in
      STALE)   status_tag="[STALE  ]" ;;
      CURRENT) status_tag="[current]" ;;
      *)       status_tag="[unmapped]" ;;
    esac
    printf "  %s  %s\n" "${status_tag}" "${rel}"
  done < <(find "${OVERVIEWS_DIR}" -name "*.md" ! -name "source-map.yaml" | sort)
}

cmd_docs_show() {
  local query="${1:-}"
  local raw=0
  [[ "${query}" == "--raw" ]] && raw=1 && query="${2:-}"
  [[ -z "${query}" ]] && { cmd_docs_index; return 0; }

  local doc_abs
  doc_abs=$(_resolve_doc "${query}")

  local rel="${doc_abs#${OVERVIEWS_DIR}/}"
  local status
  status=$(_doc_status "${doc_abs}")

  # Header line
  echo "── ${rel}  [${status}] ──────────────────────────────────────────"
  echo ""

  if [[ "${raw}" -eq 1 ]]; then
    cat "${doc_abs}"
  else
    _strip_md < "${doc_abs}" | less -R 2>/dev/null || _strip_md < "${doc_abs}"
  fi
}

cmd_docs_search() {
  local query="${1:-}"
  [[ -z "${query}" ]] && fail "Usage: wwctl docs search <term>"

  echo "Search: '${query}'"
  echo "─────────────────────────────────────────────────────────────"

  local found=0
  while IFS= read -r f; do
    local rel="${f#${OVERVIEWS_DIR}/}"
    # grep with 2 lines context, suppress errors for binary files
    local matches
    matches=$(grep -n -i -A2 -B1 "${query}" "${f}" 2>/dev/null || true)
    if [[ -n "${matches}" ]]; then
      echo ""
      echo "  ${rel}"
      echo "${matches}" | sed 's/^/    /'
      found=$((found + 1))
    fi
  done < <(find "${OVERVIEWS_DIR}" -name "*.md" ! -name "source-map.yaml" | sort)

  echo ""
  if [[ "${found}" -eq 0 ]]; then
    echo "  No matches found."
  else
    echo "  Found in ${found} doc(s)."
  fi
}

cmd_docs_changelog() {
  local query="${1:-}"
  [[ -z "${query}" ]] && fail "Usage: wwctl docs changelog <doc>"

  local doc_abs
  doc_abs=$(_resolve_doc "${query}")
  local rel="${doc_abs#${OVERVIEWS_DIR}/}"

  echo "Changelog: ${rel}"
  echo "─────────────────────────────────────────────────────────────"
  # Extract ## Changelog section to end of file
  awk '/^## Changelog/{found=1} found{print}' "${doc_abs}" | tail -n +2 | grep -v "^$" | head -20 || echo "  (no changelog entries)"
}

cmd_docs_update() {
  local query="${1:-}"
  local note="${2:-}"
  [[ -z "${query}" || -z "${note}" ]] && fail "Usage: wwctl docs update <doc> \"<note>\""

  local doc_abs
  doc_abs=$(_resolve_doc "${query}")
  local rel="${doc_abs#${OVERVIEWS_DIR}/}"
  local today
  today=$(date +"%Y-%m-%d")

  # Ensure ## Changelog section exists
  if ! grep -q "^## Changelog" "${doc_abs}"; then
    printf '\n## Changelog\n' >> "${doc_abs}"
  fi

  # Append entry
  printf '\n- %s — %s\n' "${today}" "${note}" >> "${doc_abs}"
  echo "Updated changelog: ${rel}"
  echo "  ${today} — ${note}"
}

cmd_docs_stale() {
  # Alias for docs-check formatted as a simple list
  echo "Stale Overview Docs"
  echo "─────────────────────────────────────────────────────────────"
  local count=0
  while IFS= read -r f; do
    local status
    status=$(_doc_status "${f}")
    if [[ "${status}" == "STALE" ]]; then
      echo "  ${f#${OVERVIEWS_DIR}/}"
      count=$((count + 1))
    fi
  done < <(find "${OVERVIEWS_DIR}" -name "*.md" ! -name "source-map.yaml" | sort)
  echo ""
  [[ "${count}" -eq 0 ]] && echo "  All docs current." || echo "  ${count} stale doc(s) — update before Gate C sign-off."
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

subcmd="${1:-index}"
shift || true

case "${subcmd}" in
  index|"")       cmd_docs_index "$@" ;;
  list|ls)        cmd_docs_list "$@" ;;
  show|view|cat)  cmd_docs_show "$@" ;;
  search|grep|find) cmd_docs_search "$@" ;;
  changelog|log)  cmd_docs_changelog "$@" ;;
  update)         cmd_docs_update "$@" ;;
  stale)          cmd_docs_stale "$@" ;;
  help|-h|--help)
    cat << 'EOF'
wwctl docs — Browse and manage technical overview docs

Usage: wwctl docs <subcommand> [args]

Subcommands:
  index                     Show INDEX.md (default, uses pager)
  list                      List all docs with staleness status [current/STALE]
  show <name>               Show a doc (fuzzy name match, uses pager)
  show --raw <name>         Show a doc without pager (pipeable)
  search <term>             Search across all docs with context
  changelog <name>          Show changelog section of a doc
  update <name> "<note>"    Append a changelog entry to a doc
  stale                     List only stale docs (shortcut for docs-check)

Name resolution:
  Accepts full relative path, basename, or partial name.
  "profile-manager" matches docs/overviews/lib/profile-manager.md
  "sync" shows disambiguation if multiple docs match

Examples:
  wwctl docs
  wwctl docs list
  wwctl docs show profile-manager
  wwctl docs show --raw sync-pull-push | grep "orphan"
  wwctl docs search "two-phase commit"
  wwctl docs changelog github-api
  wwctl docs update github-api "Added rate-limit detection (TASK-SYNC-003)"
  wwctl docs stale
EOF
    ;;
  *)
    # Treat unknown subcommand as a show query (convenience)
    cmd_docs_show "${subcmd}" "$@"
    ;;
esac
