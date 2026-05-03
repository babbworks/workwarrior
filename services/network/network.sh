#!/usr/bin/env bash
# services/network/network.sh — ww network: connectivity checks
set -euo pipefail

show_help() {
  cat <<'EOF'
Network — connectivity status checks

Usage: ww network [subcommand]

Subcommands:
  status    Check internet, GitHub API, and Ollama (default)
  check     Alias for status; exits 1 if any check fails

Examples:
  ww network
  ww network status
  ww network check && echo "all clear"
EOF
}

_check_internet() {
  local start end ms ip
  start=$(date +%s%3N)
  if ip=$(curl -sf --max-time 5 https://httpbin.org/ip 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('origin','?'))" 2>/dev/null); then
    end=$(date +%s%3N)
    ms=$(( end - start ))
    printf "  %-10s %-6s  %s\n" "internet" "${ms}ms" "$ip"
    return 0
  else
    printf "  %-10s %-6s  %s\n" "internet" "FAIL" "unreachable"
    return 1
  fi
}

_check_github() {
  local start end ms
  start=$(date +%s%3N)
  if curl -sf --max-time 5 https://api.github.com >/dev/null 2>&1; then
    end=$(date +%s%3N)
    ms=$(( end - start ))
    printf "  %-10s %-6s\n" "github" "${ms}ms"
    return 0
  else
    printf "  %-10s %-6s\n" "github" "FAIL"
    return 1
  fi
}

_check_ollama() {
  local start end ms n
  start=$(date +%s%3N)
  if n=$(curl -sf --max-time 3 http://localhost:11434/api/tags 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('models',[])))" 2>/dev/null); then
    end=$(date +%s%3N)
    ms=$(( end - start ))
    printf "  %-10s %-6s  %s model(s)\n" "ollama" "${ms}ms" "$n"
    return 0
  else
    printf "  %-10s %-6s  %s\n" "ollama" "off" "not running"
    return 0  # not a failure — ollama is optional
  fi
}

cmd_status() {
  local fail=0
  echo "Network checks:"
  _check_internet || fail=1
  _check_github   || fail=1
  _check_ollama
  return $fail
}

main() {
  local sub="${1:-status}"
  shift 2>/dev/null || true
  case "$sub" in
    status|check) cmd_status ;;
    help|-h|--help) show_help ;;
    *)
      echo "network: unknown subcommand '$sub'" >&2
      show_help >&2
      exit 1
      ;;
  esac
}

main "$@"
