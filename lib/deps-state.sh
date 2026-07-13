#!/usr/bin/env bash
# lib/deps-state.sh — the toolchain state stamp. The `apt update` model.
#
# THE PROBLEM (verifier F3): the runtime floor guard originally probed `hledger
# --version` on every call. It tried to memoise with an exported flag, but `ww` is a
# FRESH PROCESS each invocation and exports flow parent->child, never sibling->sibling.
# So the memo never fired and every single `ww hledger ...` forked a subprocess.
#
# THE MODEL: you do not re-verify your package versions on every command — you verify
# them when you ask. `ww deps check` is the `apt update` moment: it probes the real
# binaries and writes this stamp. The runtime guard then does a CHEAP FILE READ and
# forks nothing.
#
# The stamp is also the artifact that makes a fleet legible: it is per-instance state,
# so a warrior spanning instances can answer "which of my instances are below the
# hledger floor?" — a question nothing could answer before (TASK-DEPS-001).
#
# SOURCED library: no `set -euo pipefail`, no `exit`, return codes only.

if [[ -n "${_WW_DEPS_STATE_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_WW_DEPS_STATE_LOADED=1

# shellcheck source=./deps-manifest.sh
source "$(dirname "${BASH_SOURCE[0]}")/deps-manifest.sh" 2>/dev/null || true

# Per-instance. .state/ is runtime state and is gitignored.
deps_state_path() {
  local base="${WW_BASE:-${WORKWARRIOR_BASE:-$HOME/ww}}"
  printf '%s\n' "${WW_DEPS_STATE:-${base}/.state/deps.json}"
}

# The stamp is invalidated when the MANIFEST changes — otherwise raising a floor in
# config/dependencies.yaml would leave every existing host stamped "ok" against the
# old one.
_deps_manifest_fingerprint() {
  local p
  p="$(deps_manifest_path)" || { echo "none"; return 0; }
  sha256sum "$p" 2>/dev/null | cut -d' ' -f1 || echo "none"
}

# Probe every tool in the manifest and write the stamp. This FORKS — once, here, on
# purpose. It is the only place a version probe is allowed on a non-hot path.
deps_state_refresh() {
  local path fp tools tool ver min status
  path="$(deps_state_path)"
  fp="$(_deps_manifest_fingerprint)"
  mkdir -p "$(dirname "$path")" || return 2

  tools="$(deps_tools)" || return 2

  local entries=""
  while IFS= read -r tool; do
    [[ -n "$tool" ]] || continue
    ver="$(deps_probe_version "$tool" 2>/dev/null)" || ver=""
    min="$(deps_min_version "$tool" 2>/dev/null)" || min=""
    if [[ -z "$ver" ]]; then
      status="missing"
    elif deps_version_gte "$ver" "$min"; then
      status="ok"
    else
      status="below_floor"
    fi
    # `|| true`: a MISSING tool makes `command -v` return 1, and a failing command
    # substitution inside an assignment fails the assignment — which aborts this
    # function under `set -e`. Refreshing the stamp must never break BECAUSE a tool is
    # absent; recording that it is absent is the entire job.
    local where; where="$(command -v "$tool" 2>/dev/null || true)"
    entries+="${tool}|${ver}|${min}|${status}|${where}"$'\n'
  done <<< "$tools"

  printf '%s' "$entries" | python3 -c "
import sys, json, time
tools = {}
for line in sys.stdin.read().splitlines():
    if not line.strip():
        continue
    parts = line.split('|')
    while len(parts) < 5:
        parts.append('')
    name, ver, mn, st, path = parts[:5]
    tools[name] = {'version': ver, 'min': mn, 'status': st, 'path': path}
json.dump({
    'schema': 'v1',
    'checked_at': int(time.time()),
    'manifest': '${fp}',
    'tools': tools,
}, open('${path}', 'w'), indent=2)
" || return 2

  return 0
}

# Is the stamp present AND still describing the current manifest?
deps_state_fresh() {
  local path fp
  path="$(deps_state_path)"
  [[ -f "$path" ]] || return 1
  fp="$(_deps_manifest_fingerprint)"
  python3 -c "
import json, sys
try:
    s = json.load(open('${path}'))
except Exception:
    sys.exit(1)
sys.exit(0 if s.get('manifest') == '${fp}' else 1)
" 2>/dev/null
}

# Read a field for a tool out of the stamp. NO FORK of the tool itself.
#   deps_state_get <tool> <version|min|status|path>
deps_state_get() {
  local tool="$1" field="$2" path
  path="$(deps_state_path)"
  [[ -f "$path" ]] || return 1
  python3 -c "
import json, sys
try:
    s = json.load(open('${path}'))
except Exception:
    sys.exit(1)
t = s.get('tools', {}).get('${tool}')
if not t or t.get('${field}') in (None, ''):
    sys.exit(1)
print(t['${field}'])
" 2>/dev/null
}

# ── THE RUNTIME GUARD ────────────────────────────────────────────────────────
#
# Reads the stamp. Forks nothing when the stamp is fresh. Self-heals (one probe, ever)
# when the stamp is absent or the manifest has changed.
#
# Fails LOUDLY on a `hard` floor. Never silently degrades: an hledger below the floor
# does not error on --value, it returns unconverted numbers, and a wrong answer with no
# error is the worst thing an accounting tool can produce.
#
# Returns 0 satisfied, 2 below floor / missing.
deps_require_floor() {
  local tool="${1:-}"
  [[ -n "$tool" ]] || return 0

  # Advisory tools never block.
  deps_is_hard "$tool" || return 0

  # Self-heal: no stamp, or the manifest moved under it. One probe, then stamped.
  if ! deps_state_fresh; then
    deps_state_refresh >/dev/null 2>&1 || true
  fi

  local status
  status="$(deps_state_get "$tool" status 2>/dev/null)"

  case "$status" in
    ok) return 0 ;;
    "")
      # Stamp unreadable even after a refresh attempt — fall back to a live probe
      # rather than passing a tool we know nothing about.
      local ver; ver="$(deps_probe_version "$tool" 2>/dev/null)"
      if [[ -n "$ver" ]] && deps_version_gte "$ver" "$(deps_min_version "$tool")"; then
        return 0
      fi
      _deps_floor_error "$tool" "${ver:-}"
      return 2
      ;;
    *)
      _deps_floor_error "$tool" "$(deps_state_get "$tool" version 2>/dev/null)"
      return 2
      ;;
  esac
}

_deps_floor_error() {
  local tool="${1:-}" have="${2:-}" min reason
  min="$(deps_min_version "$tool" 2>/dev/null)"
  reason="$(deps_floor_reason "$tool" 2>/dev/null)"
  {
    echo ""
    echo "  ${tool} version floor not met"
    echo "  ──────────────────────────────────────────────────────────────"
    echo "  Required: >= ${min}    Found: ${have:-not installed}"
    echo ""
    [[ -n "$reason" ]] && { echo "  ${reason}"; echo ""; }
    echo "  Fix:  ww deps install ${tool}"
    echo ""
    if [[ "$(deps_package "$tool" apt 2>/dev/null)" == "unsupported" ]] \
       && command -v apt >/dev/null 2>&1; then
      echo "  Note: 'apt install ${tool}' will NOT work — the packaged version is"
      echo "        below the floor. Use the command above."
      echo ""
    fi
    echo "  (Already fixed it? Run 'ww deps check' to refresh the toolchain stamp.)"
    echo ""
  } >&2
}
