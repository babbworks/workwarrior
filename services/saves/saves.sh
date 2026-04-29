#!/usr/bin/env bash
# services/saves/saves.sh — ww saves: knowledge base / bookbuilder wrapper
set -euo pipefail

show_help() {
  cat <<'EOF'
Saves — knowledge base builder (powered by peers8862-bookbuilder)

Usage: ww saves <subcommand> [args]

Subcommands:
  status            Show saves installation and corpus status
  add <url|path>    Add a URL or file to the knowledge base
  search <query>    Search saved items
  inbox             List unprocessed inbox items
  run               Run the full pipeline (fetch/analyze/build)
  install           Install peers8862-bookbuilder via pipx

Examples:
  ww saves status
  ww saves add https://example.com/article
  ww saves search "taskwarrior hooks"
  ww saves run
EOF
}

_bb_check() {
  if ! command -v bookbuilder &>/dev/null; then
    echo "saves: bookbuilder not installed" >&2
    echo "Install with: ww saves install" >&2
    return 1
  fi
}

main() {
  local sub="${1:-status}"
  shift 2>/dev/null || true

  case "$sub" in
    status)
      if command -v bookbuilder &>/dev/null; then
        bookbuilder status "$@"
      else
        echo "saves: not installed (peers8862-bookbuilder)"
        echo "Install: ww saves install"
        exit 1
      fi
      ;;
    add)
      _bb_check || exit 1
      bookbuilder add "$@"
      ;;
    search)
      _bb_check || exit 1
      bookbuilder search "$@"
      ;;
    inbox)
      _bb_check || exit 1
      bookbuilder inbox "$@"
      ;;
    run)
      _bb_check || exit 1
      bookbuilder run "$@"
      ;;
    install)
      if command -v pipx &>/dev/null; then
        pipx install peers8862-bookbuilder
      else
        pip install peers8862-bookbuilder
      fi
      ;;
    help|-h|--help)
      show_help
      ;;
    *)
      echo "saves: unknown subcommand '$sub'" >&2
      show_help >&2
      exit 1
      ;;
  esac
}

main "$@"
