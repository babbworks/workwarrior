#!/usr/bin/env bash
# lib/journal-scanner.sh — parse and annotate jrnl-format journal files
# Wrapper around lib/journal_scanner.py
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER_PY="$SCRIPT_DIR/journal_scanner.py"

usage() {
  cat << 'EOF'
Usage:
  journal-scanner.sh parse <journal_file>
      Parse all entries; print JSON {ok, entries:[{date,date_slug,body,annotations}]}

  journal-scanner.sh get-entry <journal_file> <date_slug>
      Get single entry by date_slug (YYYY-MM-DD_HH-MM); print JSON {ok, entry}

  journal-scanner.sh annotate <journal_file> <date_slug> "<text>"
      Append annotation block to named entry; print JSON {ok, ts, annotation}

Exit codes: 0 success, 1 error
EOF
}

cmd="${1:-}"
case "$cmd" in
  ""|help|-h|--help) usage ;;
  parse|get-entry|annotate) python3 "$SCANNER_PY" "$@" ;;
  *) echo "{\"ok\":false,\"error\":\"unknown cmd: $cmd\"}" >&2; exit 1 ;;
esac
