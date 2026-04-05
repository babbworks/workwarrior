#!/usr/bin/env bash
set -euo pipefail

CODEX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_git_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

if WW_ROOT="$(find_git_root "${CODEX_ROOT}")"; then
  :
else
  WW_ROOT="$(cd "${CODEX_ROOT}/../../.." && pwd)"
fi

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Missing file: $path"
}

timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}
