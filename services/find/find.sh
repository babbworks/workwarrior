#!/usr/bin/env bash
# Service: find
# Category: find
# Description: Search across profiles and data types (journals, ledgers, lists)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required for the find service" >&2
  exit 1
fi

python3 "$SCRIPT_DIR/find.py" "$@"
