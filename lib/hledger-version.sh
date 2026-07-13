#!/usr/bin/env bash
# lib/hledger-version.sh — the single owner of the hledger version floor.
#
# WHY A FLOOR (TASK-LED-013): workwarrior's ledger is not a finance feature — it is a
# general systems-accounting engine (dev/docs/ledger-systems-accounting.md). Every
# capability that thesis rests on — unit conversion (-X), time-aware valuation
# (--value=then|DATE|now), the attention queue (balance -X att -S), roi, the fuller
# check suite — was verified against hledger 1.52.1 and is weak or ABSENT on older
# builds. Debian 12 ships 1.25, which cannot do any of it.
#
# Evidence: dev/reports/ledger-hledger/hledger-1.52-verification.md (16 capabilities)
#           dev/reports/ledger-hledger/tests/run-valuation-tests.sh (12/12 on 1.52.1)
#
# NOTE: distro packages CANNOT reach this floor. Debian 12 bookworm's only candidate
# is 1.25-2+b5. That is not a lag to wait out — it is why the static-binary path below
# exists.
#
# SOURCED library: no `set -euo pipefail`, no `exit`, return codes only.
# Consumers: lib/dependency-installer.sh (install-time), bin/ww (runtime guard),
#            lib/ledger-dispatch.sh (after TASK-LED-012 lands — it MUST source this,
#            not reimplement the floor).

# Re-source guard: this file is sourced by several callers in one shell.
if [[ -n "${_WW_HLEDGER_VERSION_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_WW_HLEDGER_VERSION_LOADED=1

# ── THE FLOOR ────────────────────────────────────────────────────────────────
# Single source of truth. Everything else derives from this.
HLEDGER_MIN_VERSION="1.52"

# Pinned release used by the static installer. Bump deliberately, with a re-run of
# dev/reports/ledger-hledger/tests/run-valuation-tests.sh against the new binary.
HLEDGER_PINNED_VERSION="1.52.1"
HLEDGER_RELEASE_URL_BASE="https://github.com/simonmichael/hledger/releases/download"

# ── QUERY ────────────────────────────────────────────────────────────────────

# Installed hledger version, or empty if not on PATH.
#   hledger_installed_version  ->  "1.25" | ""
hledger_installed_version() {
  command -v hledger >/dev/null 2>&1 || return 1
  hledger --version 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' \
    | head -1
}

# Compare two versions: 0 if $1 >= $2. sort -V gives correct hledger semantics
# (1.9 < 1.52, because the minor component is an integer, not a decimal).
hledger_version_gte() {
  local have="${1:-}" want="${2:-}"
  [[ -z "$have" ]] && return 1
  local lowest
  lowest="$(printf '%s\n%s\n' "$have" "$want" | sort -V | head -1)"
  [[ "$lowest" == "$want" ]]
}

# Does the installed hledger meet the floor?
hledger_meets_floor() {
  local have
  have="$(hledger_installed_version)" || return 1
  hledger_version_gte "$have" "$HLEDGER_MIN_VERSION"
}

# ── THE RUNTIME GUARD ────────────────────────────────────────────────────────
#
# Fails LOUDLY and EARLY. It must NEVER silently degrade: a report computed by a
# too-old hledger is not "slightly worse", it is a wrong answer with no error — the
# valuation flags simply do not exist, and balances come back unconverted.
#
# Fires at most once per shell session (no per-command `hledger --version` fork).
# Returns 0 if satisfied, 2 (system error) if not.
hledger_require_floor() {
  # Already checked and passed in this session.
  [[ "${WW_HLEDGER_FLOOR_OK:-}" == "1" ]] && return 0

  local have
  if ! have="$(hledger_installed_version)"; then
    _hledger_floor_error "hledger is not installed or not on PATH." ""
    return 2
  fi

  if hledger_version_gte "$have" "$HLEDGER_MIN_VERSION"; then
    export WW_HLEDGER_FLOOR_OK=1
    return 0
  fi

  _hledger_floor_error "hledger $have is below the required minimum $HLEDGER_MIN_VERSION." "$have"
  return 2
}

# Actionable failure message. The user must be told exactly what to do — and, on
# Debian/Ubuntu, must NOT be sent to a package manager that cannot satisfy the floor.
_hledger_floor_error() {
  local msg="${1:-}" have="${2:-}"
  {
    echo ""
    echo "  hledger version floor not met"
    echo "  ──────────────────────────────────────────────────────────────"
    echo "  $msg"
    echo ""
    echo "  Required: >= ${HLEDGER_MIN_VERSION}    Found: ${have:-none}"
    echo ""
    echo "  Workwarrior's ledger needs unit conversion (-X), time-aware valuation"
    echo "  (--value), and the attention queue. Older builds do not have them, and"
    echo "  would return wrong answers rather than errors."
    echo ""
    echo "  Fix:  ww deps install hledger        (installs the official static build)"
    echo ""
    if command -v apt >/dev/null 2>&1; then
      echo "  Note: 'apt install hledger' will NOT work — Debian/Ubuntu ship 1.25,"
      echo "        which is below the floor. Use the command above."
      echo ""
    fi
  } >&2
}

# ── THE STATIC INSTALLER ─────────────────────────────────────────────────────
#
# Distro packages cannot reach the floor, so we fetch the official static binary.
# It goes in ~/.local/bin — we NEVER overwrite a package-manager-owned /usr/bin/hledger.
# If an older apt-managed hledger still shadows ours on PATH, we say so plainly rather
# than silently "fixing" the user's PATH.
#
#   hledger_install_static [target_dir]
hledger_install_static() {
  local target_dir="${1:-$HOME/.local/bin}"
  local os arch tarball url tmp
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os:$arch" in
    Linux:x86_64)  tarball="hledger-linux-x64.tar.gz" ;;
    Linux:aarch64) tarball="hledger-linux-arm64.tar.gz" ;;
    Darwin:*)      tarball="hledger-mac-x64.tar.gz" ;;
    *)
      echo "hledger static build unavailable for ${os}/${arch}." >&2
      echo "Build from source or install >= ${HLEDGER_MIN_VERSION} manually." >&2
      return 2
      ;;
  esac

  url="${HLEDGER_RELEASE_URL_BASE}/${HLEDGER_PINNED_VERSION}/${tarball}"
  tmp="$(mktemp -d)" || return 2

  echo "Downloading hledger ${HLEDGER_PINNED_VERSION} (official static build)..."
  if ! curl -fsSL -o "${tmp}/${tarball}" "$url"; then
    echo "Download failed: $url" >&2
    rm -rf "$tmp"
    return 2
  fi

  if ! tar xzf "${tmp}/${tarball}" -C "$tmp"; then
    echo "Extract failed: ${tmp}/${tarball}" >&2
    rm -rf "$tmp"
    return 2
  fi

  if [[ ! -f "${tmp}/hledger" ]]; then
    echo "Archive did not contain an 'hledger' binary." >&2
    rm -rf "$tmp"
    return 2
  fi

  mkdir -p "$target_dir" || { rm -rf "$tmp"; return 2; }
  install -m 0755 "${tmp}/hledger" "${target_dir}/hledger" || { rm -rf "$tmp"; return 2; }
  rm -rf "$tmp"

  # Verify what we actually installed, rather than assuming the download was right.
  local got
  got="$("${target_dir}/hledger" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
  if ! hledger_version_gte "${got:-0}" "$HLEDGER_MIN_VERSION"; then
    echo "Installed binary reports '${got:-unknown}', which does not meet the floor ${HLEDGER_MIN_VERSION}." >&2
    return 2
  fi

  echo "Installed hledger ${got} -> ${target_dir}/hledger"

  # Do not silently shadow. Tell the truth about PATH order.
  local first
  first="$(command -v hledger 2>/dev/null)"
  if [[ "$first" != "${target_dir}/hledger" ]]; then
    {
      echo ""
      echo "  WARNING: '${first:-none}' still comes first on your PATH."
      echo "  The version workwarrior will actually run is: $(hledger_installed_version)"
      echo "  Put ${target_dir} ahead of it in PATH, or remove the older package"
      echo "  (e.g. 'sudo apt remove hledger')."
      echo ""
    } >&2
    return 1
  fi

  return 0
}
