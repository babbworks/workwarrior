#!/usr/bin/env bats
# test-hledger-floor.bats — TASK-LED-013
#
# The floor exists because an hledger below it does not ERROR on -X/--value, it
# silently returns unconverted numbers. A wrong answer with no error is the worst
# possible failure mode for an accounting tool, so these tests assert the guard is
# loud, and that it is scoped to the surfaces that can actually be handed those flags.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source "${REPO_ROOT}/lib/hledger-version.sh"
}

# ── the floor itself ─────────────────────────────────────────────────────────

@test "floor is declared and is at least 1.52" {
  [ -n "$HLEDGER_MIN_VERSION" ]
  run hledger_version_gte "$HLEDGER_MIN_VERSION" "1.52"
  [ "$status" -eq 0 ]
}

@test "dependency-installer derives its floor from the single owner (no second copy)" {
  run grep -c 'MIN_VERSION_HLEDGER="1\.' "${REPO_ROOT}/lib/dependency-installer.sh"
  # The only assignment must be the derived one; a hardcoded literal is a regression.
  run bash -c "grep -E 'readonly MIN_VERSION_HLEDGER=' '${REPO_ROOT}/lib/dependency-installer.sh'"
  [[ "$output" == *'${HLEDGER_MIN_VERSION'* ]]
}

# ── version comparison: hledger's minor is an INTEGER, not a decimal ─────────
# 1.9 is OLDER than 1.52. A naive float compare gets this backwards and would let a
# 1.9 host through the floor.

@test "version_gte: 1.25 does NOT meet the 1.52 floor" {
  run hledger_version_gte "1.25" "1.52"
  [ "$status" -ne 0 ]
}

@test "version_gte: 1.9 does NOT meet the 1.52 floor (integer minor, not decimal)" {
  run hledger_version_gte "1.9" "1.52"
  [ "$status" -ne 0 ]
}

@test "version_gte: 1.52 meets the floor" {
  run hledger_version_gte "1.52" "1.52"
  [ "$status" -eq 0 ]
}

@test "version_gte: 1.52.1 meets the floor" {
  run hledger_version_gte "1.52.1" "1.52"
  [ "$status" -eq 0 ]
}

@test "version_gte: 2.0 meets the floor" {
  run hledger_version_gte "2.0" "1.52"
  [ "$status" -eq 0 ]
}

@test "version_gte: empty version never meets the floor" {
  run hledger_version_gte "" "1.52"
  [ "$status" -ne 0 ]
}

# ── the guard ────────────────────────────────────────────────────────────────

@test "guard FAILS with exit 2 when hledger is below the floor" {
  # Shadow hledger with a fake 1.25 — the version this repo's host actually ships.
  local fake="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "$fake"
  printf '#!/usr/bin/env bash\necho "hledger 1.25, linux-x86_64"\n' > "$fake/hledger"
  chmod +x "$fake/hledger"

  run env PATH="$fake:$PATH" WW_HLEDGER_FLOOR_OK= bash -c \
    "source '${REPO_ROOT}/lib/hledger-version.sh'; hledger_require_floor"
  [ "$status" -eq 2 ]
}

@test "guard failure message is ACTIONABLE (names the floor, the found version, the fix)" {
  local fake="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "$fake"
  printf '#!/usr/bin/env bash\necho "hledger 1.25, linux-x86_64"\n' > "$fake/hledger"
  chmod +x "$fake/hledger"

  run env PATH="$fake:$PATH" WW_HLEDGER_FLOOR_OK= bash -c \
    "source '${REPO_ROOT}/lib/hledger-version.sh'; hledger_require_floor 2>&1"
  [[ "$output" == *"1.52"* ]]
  [[ "$output" == *"1.25"* ]]
  [[ "$output" == *"ww deps install hledger"* ]]
}

@test "guard does NOT send apt users to a package manager that cannot satisfy the floor" {
  local fake="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "$fake"
  printf '#!/usr/bin/env bash\necho "hledger 1.25, linux-x86_64"\n' > "$fake/hledger"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake/apt"
  chmod +x "$fake/hledger" "$fake/apt"

  run env PATH="$fake:$PATH" WW_HLEDGER_FLOOR_OK= bash -c \
    "source '${REPO_ROOT}/lib/hledger-version.sh'; hledger_require_floor 2>&1"
  [[ "$output" == *"will NOT work"* ]]
}

@test "guard PASSES when hledger meets the floor" {
  local fake="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "$fake"
  printf '#!/usr/bin/env bash\necho "hledger 1.52.1, linux-x86_64"\n' > "$fake/hledger"
  chmod +x "$fake/hledger"

  run env PATH="$fake:$PATH" WW_HLEDGER_FLOOR_OK= bash -c \
    "source '${REPO_ROOT}/lib/hledger-version.sh'; hledger_require_floor"
  [ "$status" -eq 0 ]
}

@test "guard fires at most once per session (WW_HLEDGER_FLOOR_OK short-circuits)" {
  # Below-floor hledger, but the session already passed the check: must not re-fail.
  local fake="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "$fake"
  printf '#!/usr/bin/env bash\necho "hledger 1.25"\n' > "$fake/hledger"
  chmod +x "$fake/hledger"

  run env PATH="$fake:$PATH" WW_HLEDGER_FLOOR_OK=1 bash -c \
    "source '${REPO_ROOT}/lib/hledger-version.sh'; hledger_require_floor"
  [ "$status" -eq 0 ]
}

@test "guard reports absent hledger distinctly from below-floor hledger" {
  local empty="${BATS_TEST_TMPDIR}/empty"
  mkdir -p "$empty"
  # NOTE: /bin/bash by absolute path — an empty PATH means the shell itself is not
  # findable by name, which would exit 127 and mask the behaviour under test.
  run env PATH="$empty" WW_HLEDGER_FLOOR_OK= /bin/bash -c \
    "source '${REPO_ROOT}/lib/hledger-version.sh'; hledger_require_floor 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not installed"* ]]
}

# ── guard SCOPE: loud where it matters, silent where it does not ─────────────
# Basic commands (balance/register/print/stats/accounts) work fine on 1.25. Guarding
# them would break `ww profile stats` and exports for zero safety gain. The guard
# belongs only on the arbitrary-flag passthrough surfaces.

@test "guard is wired into the ww hledger passthrough" {
  run grep -A8 '^cmd_hledger_passthrough()' "${REPO_ROOT}/bin/ww"
  [[ "$output" == *"hledger_require_floor"* ]]
}

@test "guard is wired into the l shell function passthrough" {
  run grep -B6 'hledger -f "\$default_ledger" "\${args\[@\]}"' "${REPO_ROOT}/lib/shell-integration.sh"
  [[ "$output" == *"hledger_require_floor"* ]]
}

@test "guard is ABSENT from basic internal call sites (they work on 1.25)" {
  # profile-stats only ever runs stats/accounts/register — no valuation flags.
  run grep -c 'hledger_require_floor' "${REPO_ROOT}/lib/profile-stats.sh"
  [ "$output" -eq 0 ]
}

@test "bin/ww is absent-safe when lib/hledger-version.sh is missing" {
  # A stub must exist so an install without the lib does not hard-fail.
  run grep -A4 'lib/hledger-version.sh" \]\]; then' "${REPO_ROOT}/bin/ww"
  [[ "$output" == *"hledger_require_floor() { return 0; }"* ]]
}

# ── install routing ──────────────────────────────────────────────────────────

@test "Linux install command routes to the static build, NOT to apt" {
  run bash -c "source '${REPO_ROOT}/lib/dependency-installer.sh'; get_install_command hledger apt"
  [[ "$output" == "ww deps install hledger" ]]
}

@test "Linux upgrade command routes to the static build, NOT to apt --only-upgrade" {
  run bash -c "source '${REPO_ROOT}/lib/dependency-installer.sh'; get_upgrade_command hledger apt"
  [[ "$output" == "ww deps install hledger" ]]
}

@test "macOS (brew) keeps the normal package path" {
  run bash -c "source '${REPO_ROOT}/lib/dependency-installer.sh'; get_install_command hledger brew"
  [[ "$output" == "brew install hledger" ]]
}

@test "other tools are unaffected by the hledger special-case" {
  run bash -c "source '${REPO_ROOT}/lib/dependency-installer.sh'; get_install_command task apt"
  [[ "$output" == "sudo apt install taskwarrior" ]]
}

@test "deps help documents the hledger exception (Gate C: help matches behaviour)" {
  run grep -A2 'hledger is the exception' "${REPO_ROOT}/bin/ww"
  [[ "$output" == *"1.52"* ]]
}
