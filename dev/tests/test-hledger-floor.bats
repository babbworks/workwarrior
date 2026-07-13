#!/usr/bin/env bats
# test-hledger-floor.bats — TASK-LED-013.
#
# This suite covers hledger's floor as WIRED INTO THE PRODUCT: the shim, the guard's
# placement, and its deliberate scope. The manifest data lives in test-deps-manifest.bats;
# the no-fork stamp behaviour lives in test-deps-state.bats.
#
# HISTORY (do not re-add): an earlier version of this suite asserted that an exported
# WW_HLEDGER_FLOOR_OK short-circuited the guard "once per session". That mechanism was
# WRONG — `ww` is a fresh process per invocation and exports flow parent->child, never
# sibling->sibling, so it never fired and every call forked `hledger --version`
# (verifier F3). Those assertions were deleted because the behaviour they protected was
# the bug. The replacement is the state stamp.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export WW_DEPS_MANIFEST="${REPO_ROOT}/config/dependencies.yaml"
  export WW_DEPS_STATE="${BATS_TEST_TMPDIR}/deps.json"
  source "${REPO_ROOT}/lib/hledger-version.sh"
}

# ── the shim resolves the floor from the manifest ────────────────────────────

@test "hledger floor resolves through the shim and is >= 1.52" {
  run hledger_min_version
  [ "$output" = "1.52" ]
}

# ── version comparison: hledger's minor is an INTEGER, not a decimal ─────────
# 1.9 is OLDER than 1.52. A naive float compare gets this backwards and would wave a
# 1.9 host straight through the floor. This is the difference between a floor and a
# decoration.

@test "1.25 does NOT meet the floor" {
  run hledger_version_gte "1.25" "1.52"
  [ "$status" -ne 0 ]
}

@test "1.9 does NOT meet the floor (integer minor, not decimal)" {
  run hledger_version_gte "1.9" "1.52"
  [ "$status" -ne 0 ]
}

@test "1.52 meets the floor" {
  run hledger_version_gte "1.52" "1.52"
  [ "$status" -eq 0 ]
}

@test "1.52.1 meets the floor" {
  run hledger_version_gte "1.52.1" "1.52"
  [ "$status" -eq 0 ]
}

@test "2.0 meets the floor" {
  run hledger_version_gte "2.0" "1.52"
  [ "$status" -eq 0 ]
}

@test "an empty version never meets the floor" {
  run hledger_version_gte "" "1.52"
  [ "$status" -ne 0 ]
}

# ── the guard, through the shim ──────────────────────────────────────────────

@test "guard FAILS with exit 2 when hledger is below the floor" {
  local fake="${BATS_TEST_TMPDIR}/bin"; mkdir -p "$fake"
  printf '#!/usr/bin/env bash\necho "hledger 1.25, linux-x86_64"\n' > "$fake/hledger"
  chmod +x "$fake/hledger"

  PATH="${fake}:$PATH" run hledger_require_floor
  [ "$status" -eq 2 ]
}

@test "guard PASSES when hledger meets the floor" {
  local fake="${BATS_TEST_TMPDIR}/bin"; mkdir -p "$fake"
  printf '#!/usr/bin/env bash\necho "hledger 1.52.1, linux-x86_64"\n' > "$fake/hledger"
  chmod +x "$fake/hledger"

  PATH="${fake}:$PATH" run hledger_require_floor
  [ "$status" -eq 0 ]
}

@test "guard message is ACTIONABLE (floor, found version, the fix, how to re-stamp)" {
  local fake="${BATS_TEST_TMPDIR}/bin"; mkdir -p "$fake"
  printf '#!/usr/bin/env bash\necho "hledger 1.25, linux-x86_64"\n' > "$fake/hledger"
  chmod +x "$fake/hledger"

  run env PATH="${fake}:$PATH" WW_DEPS_MANIFEST="$WW_DEPS_MANIFEST" \
      WW_DEPS_STATE="$WW_DEPS_STATE" bash -c \
      "source '${REPO_ROOT}/lib/hledger-version.sh'; hledger_require_floor 2>&1"
  [[ "$output" == *"1.52"* ]]
  [[ "$output" == *"1.25"* ]]
  [[ "$output" == *"ww deps install hledger"* ]]
}

@test "guard does NOT send apt users to a package manager that cannot satisfy the floor" {
  local fake="${BATS_TEST_TMPDIR}/bin"; mkdir -p "$fake"
  printf '#!/usr/bin/env bash\necho "hledger 1.25, linux-x86_64"\n' > "$fake/hledger"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake/apt"
  chmod +x "$fake/hledger" "$fake/apt"

  run env PATH="${fake}:$PATH" WW_DEPS_MANIFEST="$WW_DEPS_MANIFEST" \
      WW_DEPS_STATE="$WW_DEPS_STATE" bash -c \
      "source '${REPO_ROOT}/lib/hledger-version.sh'; hledger_require_floor 2>&1"
  [[ "$output" == *"will NOT work"* ]]
}

# ── GUARD SCOPE: loud where it matters, silent where it does not ─────────────
#
# ~14 call sites use hledger, but almost all run BASIC commands (balance, register,
# print, stats, accounts) that work correctly on 1.25. A blanket guard would break
# `ww profile stats` and exports on older hosts for ZERO safety gain. The guard belongs
# only on the ARBITRARY-FLAG passthroughs, where a user can actually hand hledger
# -X / --value and get silently unconverted numbers back.

@test "guard is wired into the `ww hledger` passthrough" {
  run grep -A8 '^cmd_hledger_passthrough()' "${REPO_ROOT}/bin/ww"
  [[ "$output" == *"hledger_require_floor"* ]]
}

@test "guard is wired into the `l` shell function passthrough" {
  run grep -B6 'hledger -f "\$default_ledger" "\${args\[@\]}"' "${REPO_ROOT}/lib/shell-integration.sh"
  [[ "$output" == *"hledger_require_floor"* ]]
}

@test "guard is ABSENT from basic internal call sites (they work fine on 1.25)" {
  run grep -c 'hledger_require_floor' "${REPO_ROOT}/lib/profile-stats.sh"
  [ "$output" -eq 0 ]
  run grep -c 'hledger_require_floor' "${REPO_ROOT}/lib/export-utils.sh"
  [ "$output" -eq 0 ]
}

@test "bin/ww is absent-safe when the floor libs are missing" {
  run grep -A5 'lib/hledger-version.sh" \]\]; then' "${REPO_ROOT}/bin/ww"
  [[ "$output" == *"hledger_require_floor() { return 0; }"* ]]
}

# ── Gate C: help matches behaviour ───────────────────────────────────────────

@test "deps help documents the hledger exception and the floor" {
  run grep -A3 'hledger is the exception' "${REPO_ROOT}/bin/ww"
  [[ "$output" == *"1.52"* ]]
}
