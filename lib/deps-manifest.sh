#!/usr/bin/env bash
# lib/deps-manifest.sh — the SINGLE owner of config/dependencies.yaml.
#
# No other code path may parse that file. This is the same rule the ledgers.yaml audit
# produced (decisions.md 2026-07-11): five independent parsers for one file gave us a
# schema forked three ways. Do not repeat it.
#
# Contract: dev/schemas/dependencies-v1.md
#
# SOURCED library: no `set -euo pipefail`, no `exit`, return codes only.

if [[ -n "${_WW_DEPS_MANIFEST_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_WW_DEPS_MANIFEST_LOADED=1

# Resolve the manifest. Repo layout and installed layout both put it in config/.
deps_manifest_path() {
  local base="${WW_BASE:-${WORKWARRIOR_BASE:-}}"
  local candidates=(
    "${WW_DEPS_MANIFEST:-}"
    "${base}/config/dependencies.yaml"
    "$(dirname "${BASH_SOURCE[0]}")/../config/dependencies.yaml"
  )
  local c
  for c in "${candidates[@]}"; do
    [[ -n "$c" && -f "$c" ]] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

# Query the manifest. A malformed manifest is a FATAL error, never a silent default:
# guessing a version floor is exactly how you end up below one without knowing.
#   _deps_query <python-expression-over-`m`>
_deps_query() {
  local expr="$1" path
  path="$(deps_manifest_path)" || {
    echo "deps: config/dependencies.yaml not found" >&2
    return 2
  }
  python3 -c "
import sys, yaml
try:
    with open('$path') as f:
        m = yaml.safe_load(f) or {}
except Exception as e:
    sys.stderr.write('deps: malformed manifest: %s\n' % e)
    sys.exit(2)
if not isinstance(m.get('tools'), dict):
    sys.stderr.write('deps: manifest has no tools: map\n')
    sys.exit(2)
try:
    v = $expr
except Exception:
    sys.exit(1)
if v is None:
    sys.exit(1)
print(v)
" 2>&1
}

# ── tool facts ───────────────────────────────────────────────────────────────

deps_tools() { _deps_query "'\n'.join(m['tools'].keys())"; }

deps_min_version() { _deps_query "m['tools']['${1}']['min_version']"; }
deps_pinned()      { _deps_query "m['tools']['${1}']['pinned']"; }
deps_strategy()    { _deps_query "m['tools']['${1}'].get('strategy','package')"; }
deps_display()     { _deps_query "m['tools']['${1}'].get('display','${1}')"; }
deps_floor_reason(){ _deps_query "m['tools']['${1}'].get('floor_reason','')"; }

# hard | advisory. Only `hard` refuses to run.
deps_enforcement() { _deps_query "m['tools']['${1}'].get('enforcement','advisory')"; }

deps_is_hard() { [[ "$(deps_enforcement "$1" 2>/dev/null)" == "hard" ]]; }

# Package name for a tool under a package manager, or the literal 'unsupported'.
deps_package() {
  _deps_query "m['tools']['${1}'].get('package_managers',{}).get('${2}','unsupported')"
}

# ── platform + assets (F1: this is why the matrix is DATA, not shell literals) ─

# Canonical platform key. Never guess: an unknown platform returns empty and callers
# MUST treat that as unsupported rather than constructing a URL.
deps_platform() {
  local os arch
  os="$(uname -s)"; arch="$(uname -m)"
  case "$os:$arch" in
    Linux:x86_64)   echo "linux-x64" ;;
    Linux:aarch64)  echo "linux-arm64" ;;
    Linux:arm64)    echo "linux-arm64" ;;
    Darwin:arm64)   echo "mac-arm64" ;;
    Darwin:x86_64)  echo "mac-x64" ;;
    *)              return 1 ;;
  esac
}

# Asset file for tool+platform. Returns 1 if the platform is marked `unsupported` —
# upstream genuinely does not build it, and fabricating a URL produces a 404 with a
# misleading error (verifier F1).
deps_asset_file() {
  _deps_query "(lambda a: None if a in (None,'unsupported') else a['file'])(m['tools']['${1}'].get('assets',{}).get('${2}'))"
}

deps_asset_sha256() {
  _deps_query "(lambda a: None if a in (None,'unsupported') else a['sha256'])(m['tools']['${1}'].get('assets',{}).get('${2}'))"
}

deps_asset_url() {
  local tool="$1" platform="$2" file version tmpl
  file="$(deps_asset_file "$tool" "$platform")" || return 1
  version="$(deps_pinned "$tool")" || return 1
  tmpl="$(_deps_query "m['tools']['${tool}']['release_url']")" || return 1
  tmpl="${tmpl//\{version\}/$version}"
  tmpl="${tmpl//\{file\}/$file}"
  printf '%s\n' "$tmpl"
}

deps_install_to() {
  local raw
  raw="$(_deps_query "m['tools']['${1}'].get('install_to','~/.local/bin')")" || return 1
  printf '%s\n' "${raw/#\~/$HOME}"
}

# ── version comparison ───────────────────────────────────────────────────────
# sort -V, because hledger's minor is an INTEGER: 1.9 is OLDER than 1.52. A naive
# float compare gets this backwards and lets a 1.9 host through the floor.
deps_version_gte() {
  local have="${1:-}" want="${2:-}"
  [[ -z "$have" || "$have" == "not_installed" ]] && return 1
  local lowest
  lowest="$(printf '%s\n%s\n' "$have" "$want" | sort -V | head -1)"
  [[ "$lowest" == "$want" ]]
}

# Installed version of a tool, by probing the binary. THIS FORKS — callers on a hot
# path must read the state stamp instead (lib/deps-state.sh).
deps_probe_version() {
  local tool="$1"
  command -v "$tool" >/dev/null 2>&1 || return 1
  "$tool" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# ── the static installer (F1, F2, F4 all live or die here) ───────────────────

deps_install_static() {
  local tool="$1"
  local platform file url sha target tmp got

  if ! command -v curl >/dev/null 2>&1; then
    echo "deps: curl is required to install ${tool} and was not found." >&2   # F4
    return 2
  fi

  if ! platform="$(deps_platform)"; then
    echo "deps: unrecognised platform $(uname -s)/$(uname -m)." >&2
    echo "Install ${tool} >= $(deps_min_version "$tool") manually." >&2
    return 2
  fi

  # F1: an unsupported platform says so. It does NOT invent a download URL.
  if ! file="$(deps_asset_file "$tool" "$platform")"; then
    echo "deps: upstream ships no ${tool} static build for ${platform}." >&2
    echo "Build from source or install >= $(deps_min_version "$tool") by hand." >&2
    return 2
  fi

  url="$(deps_asset_url "$tool" "$platform")"   || return 2
  sha="$(deps_asset_sha256 "$tool" "$platform")" || return 2
  target="$(deps_install_to "$tool")"            || return 2

  tmp="$(mktemp -d)" || return 2

  echo "Downloading ${tool} $(deps_pinned "$tool") (${platform}, official static build)..."
  if ! curl -fsSL -o "${tmp}/${file}" "$url"; then
    echo "deps: download failed: $url" >&2
    rm -rf "$tmp"; return 2
  fi

  # F2: verify BEFORE we make it executable and put it on the user's PATH.
  local got_sha
  got_sha="$(sha256sum "${tmp}/${file}" 2>/dev/null | cut -d' ' -f1)"
  if [[ "$got_sha" != "$sha" ]]; then
    {
      echo "deps: CHECKSUM MISMATCH — refusing to install."
      echo "  expected: $sha"
      echo "  got:      ${got_sha:-<none>}"
      echo "  url:      $url"
      echo "  The artifact does not match the pin in config/dependencies.yaml."
    } >&2
    rm -rf "$tmp"; return 2
  fi

  if ! tar xzf "${tmp}/${file}" -C "$tmp" || [[ ! -f "${tmp}/${tool}" ]]; then
    echo "deps: archive did not contain a '${tool}' binary." >&2
    rm -rf "$tmp"; return 2
  fi

  mkdir -p "$target" || { rm -rf "$tmp"; return 2; }
  install -m 0755 "${tmp}/${tool}" "${target}/${tool}" || { rm -rf "$tmp"; return 2; }
  rm -rf "$tmp"

  # Verify what we installed rather than assuming the download was right.
  got="$("${target}/${tool}" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
  if ! deps_version_gte "${got:-0}" "$(deps_min_version "$tool")"; then
    echo "deps: installed binary reports '${got:-unknown}', below the floor." >&2
    return 2
  fi

  echo "Installed ${tool} ${got} -> ${target}/${tool}"

  # Never silently shadow a package-manager binary. Tell the truth about PATH order.
  local first
  first="$(command -v "$tool" 2>/dev/null)"
  if [[ "$first" != "${target}/${tool}" ]]; then
    {
      echo ""
      echo "  WARNING: '${first:-none}' still comes first on your PATH."
      echo "  The version workwarrior will run is: $(deps_probe_version "$tool")"
      echo "  Put ${target} ahead of it in PATH, or remove the older package."
      echo ""
    } >&2
    return 1
  fi
  return 0
}
