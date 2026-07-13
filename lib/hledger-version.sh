#!/usr/bin/env bash
# lib/hledger-version.sh — hledger's floor, as a thin shim over the toolchain manifest.
#
# The facts (floor, pin, per-platform assets, checksums) live in config/dependencies.yaml
# and are read by lib/deps-manifest.sh. They used to live here as string literals, and
# that produced two real bugs a 23/23 suite missed: a fabricated download URL for a
# platform upstream does not build for, and an x86 binary served to every Apple Silicon
# Mac (verifier F1). Facts that are DATA get reviewed; facts buried in shell do not.
#
# This file exists only so the two call sites already wired to `hledger_require_floor`
# (bin/ww cmd_hledger_passthrough, lib/shell-integration.sh `l`) keep a stable name.
#
# SOURCED library: no `set -euo pipefail`, no `exit`, return codes only.

if [[ -n "${_WW_HLEDGER_VERSION_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_WW_HLEDGER_VERSION_LOADED=1

_wwhv_dir="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=./deps-manifest.sh
source "${_wwhv_dir}/deps-manifest.sh" 2>/dev/null || true
# shellcheck source=./deps-state.sh
source "${_wwhv_dir}/deps-state.sh" 2>/dev/null || true

# The floor, from the manifest. Exposed for callers that want the number.
hledger_min_version() { deps_min_version hledger; }

# Installed version (FORKS — do not call on a hot path; the guard reads the stamp).
hledger_installed_version() { deps_probe_version hledger; }

hledger_version_gte() { deps_version_gte "$@"; }

hledger_meets_floor() {
  local have
  have="$(deps_probe_version hledger)" || return 1
  deps_version_gte "$have" "$(deps_min_version hledger)"
}

# The runtime guard. Reads the toolchain stamp; forks nothing when it is fresh.
hledger_require_floor() { deps_require_floor hledger; }

# Fetch + checksum-verify + install the official static build.
hledger_install_static() {
  deps_install_static hledger
  local rc=$?
  # An install changes the truth the stamp describes — restamp immediately, so the
  # user is not told to run `ww deps check` right after we just fixed it for them.
  [[ $rc -eq 0 ]] && deps_state_refresh >/dev/null 2>&1
  return $rc
}
