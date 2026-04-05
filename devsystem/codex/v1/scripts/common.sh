#!/usr/bin/env bash
set -euo pipefail

CODEX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WW_ROOT="$(cd "${CODEX_ROOT}/../.." && pwd)"

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

