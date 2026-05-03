#!/usr/bin/env bash
# Service: extensions
# Category: extensions
# Description: Manage external tool extensions registries

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat << EOF
Extensions Service

Usage: ww extensions <domain> <action> [arguments]

Domains:
  taskwarrior   Taskwarrior extensions registry

Examples:
  ww extensions taskwarrior refresh
  ww extensions taskwarrior list --status active
  ww extensions taskwarrior search vim
  ww extensions taskwarrior info taskwiki
EOF
}

main() {
  local domain="${1:-}"
  shift 2>/dev/null || true

  case "$domain" in
    taskwarrior)
      if ! command -v python3 &>/dev/null; then
        echo "Error: python3 is required" >&2
        exit 1
      fi
      python3 "$SCRIPT_DIR/taskwarrior.py" "$@"
      ;;
    ""|help|-h|--help)
      show_help
      ;;
    *)
      echo "Unknown domain: $domain" >&2
      show_help
      exit 1
      ;;
  esac
}

main "$@"
