#!/usr/bin/env bash
# check-artifacts.sh — Pre-merge hygiene check for tracked runtime artifacts.
#
# Exits non-zero if any known artifact categories are tracked by git.
# Run this before merging any branch to catch accidental artifact commits.
#
# Usage: bash system/scripts/check-artifacts.sh
#        (or ./system/scripts/check-artifacts.sh if executable)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ── Resolve the git repo root ──────────────────────────────────────────────────
GIT_ROOT="${WW_ROOT}"

VIOLATIONS=0
VIOLATION_LINES=()

# Record a violation with a descriptive label and the offending file path.
record_violation() {
  local category="$1"
  local path="$2"
  VIOLATION_LINES+=("  VIOLATION  [${category}]  ${path}")
  VIOLATIONS=$((VIOLATIONS + 1))
}

# Run git ls-files with one or more patterns and record every match.
check_tracked() {
  local category="$1"
  shift
  local patterns=("$@")
  local found
  # word-split intentional: patterns is an array of glob strings
  found="$(git -C "${GIT_ROOT}" ls-files "${patterns[@]}" 2>/dev/null || true)"
  if [[ -n "${found}" ]]; then
    while IFS= read -r tracked_path; do
      [[ -z "${tracked_path}" ]] && continue
      record_violation "${category}" "${tracked_path}"
    done <<< "${found}"
  fi
}

echo "Artifact Hygiene Check"
echo "  git root: ${GIT_ROOT}"
echo "─────────────────────────────────────"
echo ""

# ── Category: macOS metadata ───────────────────────────────────────────────────
check_tracked ".DS_Store" "*.DS_Store" "**/.DS_Store"

# ── Category: sqlite3 databases ───────────────────────────────────────────────
check_tracked "sqlite3" "*.sqlite3" "*.sqlite3-shm" "*.sqlite3-wal"

# ── Category: log files ───────────────────────────────────────────────────────
check_tracked "log" "*.log"

# ── Category: profile runtime data ────────────────────────────────────────────
# Explicit deep patterns that .gitignore must also cover.
check_tracked "profile-config" "profiles/*/.config/*"
check_tracked "profile-list"   "profiles/*/list/*"
check_tracked "profile-sqlite" "profiles/*/.task/taskchampion.sqlite3"
check_tracked "profile-sqlite" "profiles/*/.task/taskchampion.sqlite3-shm"
check_tracked "profile-sqlite" "profiles/*/.task/taskchampion.sqlite3-wal"
check_tracked "profile-sync"   "profiles/*/.task/github-sync/*"

# ── Category: function workspace task data ────────────────────────────────────
check_tracked "fn-sqlite" "functions/*/.task/taskchampion.sqlite3"
check_tracked "fn-sqlite" "functions/*/.task/taskchampion.sqlite3-shm"
check_tracked "fn-sqlite" "functions/*/.task/taskchampion.sqlite3-wal"

# ── Category: environment / secrets files ─────────────────────────────────────
check_tracked ".env" ".env" "**/.env" "*.env.local" "*.env.*.local"

# ── Report ────────────────────────────────────────────────────────────────────
if [[ "${VIOLATIONS}" -gt 0 ]]; then
  echo "Tracked artifacts found — these must be removed from git tracking:"
  echo ""
  for line in "${VIOLATION_LINES[@]}"; do
    echo "${line}"
  done
  echo ""
  echo "  To untrack without deleting:"
  echo "    git rm --cached <path>"
  echo ""
  echo "─────────────────────────────────────"
  echo "  ${VIOLATIONS} violation(s) found"
  echo "  Status: BLOCKED — resolve before merge"
  echo "─────────────────────────────────────"
  exit 1
else
  echo "  No tracked artifacts found."
  echo ""
  echo "─────────────────────────────────────"
  echo "  Status: ALL CLEAR"
  echo "─────────────────────────────────────"
  exit 0
fi
