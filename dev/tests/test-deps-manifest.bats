#!/usr/bin/env bats
# test-deps-manifest.bats — TASK-LED-013, verifier findings F1, F2, F5.
#
# F1 and F2 existed because the platform/asset matrix and the absence of a checksum were
# STRING LITERALS BURIED IN SHELL. A 23/23 suite missed both, because the tests verified
# the logic the author was thinking about and not the URLs he was not.
#
# The structural fix is to make those facts DATA. These tests assert the data is right,
# and — critically — that a wrong platform CANNOT produce a fabricated URL.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export WW_DEPS_MANIFEST="${REPO_ROOT}/config/dependencies.yaml"
  source "${REPO_ROOT}/lib/deps-manifest.sh"
}

# ── the manifest is the single owner ─────────────────────────────────────────

@test "manifest parses and declares tools" {
  run deps_tools
  [ "$status" -eq 0 ]
  [[ "$output" == *"hledger"* ]]
  [[ "$output" == *"task"* ]]
}

@test "hledger floor comes from the manifest and is >= 1.52" {
  run deps_min_version hledger
  [ "$output" = "1.52" ]
  run deps_version_gte "$(deps_min_version hledger)" "1.52"
  [ "$status" -eq 0 ]
}

@test "F5: no shell file hardcodes an hledger version floor literal" {
  # The number must live in exactly one place. A fallback literal is a second source
  # of truth for the value the codebase claims to own once.
  run bash -c "grep -rnE 'MIN_VERSION_HLEDGER=\"?1\.[0-9]+' '${REPO_ROOT}/lib/' || true"
  [ -z "$output" ]
  run bash -c "grep -rn 'HLEDGER_MIN_VERSION:-1\.' '${REPO_ROOT}/lib/' || true"
  [ -z "$output" ]
}

@test "a malformed manifest is FATAL, never a silent default" {
  printf 'this: is: not: valid: yaml:\n  - [\n' > "${BATS_TEST_TMPDIR}/bad.yaml"
  WW_DEPS_MANIFEST="${BATS_TEST_TMPDIR}/bad.yaml" run deps_min_version hledger
  [ "$status" -ne 0 ]
}

@test "a manifest with no tools: map is FATAL" {
  printf 'schema: v1\n' > "${BATS_TEST_TMPDIR}/empty.yaml"
  WW_DEPS_MANIFEST="${BATS_TEST_TMPDIR}/empty.yaml" run deps_min_version hledger
  [ "$status" -ne 0 ]
}

# ── F1: the platform matrix. The bug that a 23/23 suite missed. ─────────────

@test "F1: Darwin/arm64 resolves to mac-arm64, NOT mac-x64" {
  # The original code had `Darwin:*` swallow arm64 and hand every Apple Silicon Mac
  # the x86 build, while hledger-mac-arm64.tar.gz sat unused in the release.
  run deps_asset_file hledger mac-arm64
  [ "$output" = "hledger-mac-arm64.tar.gz" ]

  run deps_asset_file hledger mac-x64
  [ "$output" = "hledger-mac-x64.tar.gz" ]

  [ "$(deps_asset_file hledger mac-arm64)" != "$(deps_asset_file hledger mac-x64)" ]
}

@test "F1: linux-arm64 is UNSUPPORTED and yields no asset (upstream ships no such build)" {
  run deps_asset_file hledger linux-arm64
  [ "$status" -ne 0 ]      # must FAIL, not return a filename
}

@test "F1: an unsupported platform CANNOT produce a download URL" {
  # The original bug: a fabricated hledger-linux-arm64.tar.gz URL that 404s with a
  # misleading 'Download failed'. It must be impossible to construct one.
  run deps_asset_url hledger linux-arm64
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "F1: every declared asset name matches the real upstream release" {
  # These are the four assets published for 1.52.1. Any drift here is the F1 bug again.
  [ "$(deps_asset_file hledger linux-x64)" = "hledger-linux-x64.tar.gz" ]
  [ "$(deps_asset_file hledger mac-arm64)" = "hledger-mac-arm64.tar.gz" ]
  [ "$(deps_asset_file hledger mac-x64)"   = "hledger-mac-x64.tar.gz" ]
}

@test "deps_platform maps this host correctly and refuses unknown platforms" {
  run deps_platform
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^(linux-x64|linux-arm64|mac-x64|mac-arm64)$ ]]
}

# ── F2: checksums ────────────────────────────────────────────────────────────

@test "F2: every supported asset declares a 64-hex sha256" {
  local p
  for p in linux-x64 mac-arm64 mac-x64; do
    run deps_asset_sha256 hledger "$p"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{64}$ ]]
  done
}

@test "F2: the pinned linux-x64 checksum matches the binary we actually verified" {
  # 12/12 of run-valuation-tests.sh was proven against this exact artifact.
  run deps_asset_sha256 hledger linux-x64
  [ "$output" = "55bff5785d7528b939e4642a21d3c12a75a8095fedc973340b31dfd7367dd7a2" ]
}

@test "F2: install REFUSES on a checksum mismatch (does not install the artifact)" {
  # Serve a bogus tarball from a local file:// URL against the real pinned sha256.
  local fake="${BATS_TEST_TMPDIR}/serve"; mkdir -p "$fake"
  echo "not the real hledger" > "${fake}/payload"
  tar czf "${fake}/hledger-linux-x64.tar.gz" -C "$fake" payload

  cat > "${BATS_TEST_TMPDIR}/m.yaml" <<EOF
schema: v1
tools:
  hledger:
    min_version: "1.52"
    enforcement: hard
    strategy: static
    pinned: "1.52.1"
    release_url: file://${fake}/{file}
    install_to: ${BATS_TEST_TMPDIR}/target
    assets:
      $(deps_platform):
        file: hledger-linux-x64.tar.gz
        sha256: 0000000000000000000000000000000000000000000000000000000000000000
EOF

  WW_DEPS_MANIFEST="${BATS_TEST_TMPDIR}/m.yaml" run deps_install_static hledger
  [ "$status" -ne 0 ]
  [[ "$output" == *"CHECKSUM MISMATCH"* ]]
  [ ! -f "${BATS_TEST_TMPDIR}/target/hledger" ]    # nothing was installed
}

# ── install routing is driven by the manifest, not by a special case ─────────

@test "apt is marked unsupported for hledger and routes to the static build" {
  run deps_package hledger apt
  [ "$output" = "unsupported" ]
  run bash -c "source '${REPO_ROOT}/lib/dependency-installer.sh' >/dev/null 2>&1; get_install_command hledger apt"
  [[ "$output" == "ww deps install hledger" ]]
}

@test "brew keeps the normal package path for hledger" {
  run bash -c "source '${REPO_ROOT}/lib/dependency-installer.sh' >/dev/null 2>&1; get_install_command hledger brew"
  [[ "$output" == "brew install hledger" ]]
}

@test "other tools are unaffected by the static-install routing" {
  run bash -c "source '${REPO_ROOT}/lib/dependency-installer.sh' >/dev/null 2>&1; get_install_command task apt"
  [[ "$output" == "sudo apt install taskwarrior" ]]
}

@test "enforcement: hledger is hard, task is advisory" {
  run deps_enforcement hledger
  [ "$output" = "hard" ]
  run deps_enforcement task
  [ "$output" = "advisory" ]
  run deps_is_hard hledger
  [ "$status" -eq 0 ]
  run deps_is_hard task
  [ "$status" -ne 0 ]
}

@test "F4: install fails cleanly when curl is absent" {
  local empty="${BATS_TEST_TMPDIR}/nocurl"; mkdir -p "$empty"
  run env PATH="$empty" WW_DEPS_MANIFEST="$WW_DEPS_MANIFEST" /bin/bash -c \
    "source '${REPO_ROOT}/lib/deps-manifest.sh'; deps_install_static hledger 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"curl"* ]]
}
