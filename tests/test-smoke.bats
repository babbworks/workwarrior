#!/usr/bin/env bats
# Smoke tests — run these FIRST before any targeted or full suite.
# Catches: sourcing failures, missing dependencies, set -e traps on empty grep,
# task config confirmation prompts, log_error signature mismatches.
# If anything here fails, stop immediately — deeper tests will produce noise.
#
# Run:  bats tests/test-smoke.bats
# Time: < 5 seconds

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export WW_BASE="${BATS_TEST_DIRNAME}/.."
    export WORKWARRIOR_BASE
    WORKWARRIOR_BASE="$(mktemp -d)"
    export WARRIOR_PROFILE="smoke"
    cat > "${WORKWARRIOR_BASE}/.taskrc" << 'EOF'
data.location=.task
EOF
}

teardown() {
    rm -rf "${WORKWARRIOR_BASE}"
}

# ── Lib sourcing ───────────────────────────────────────────────────────────────

@test "smoke: lib/core-utils.sh sources without error" {
    run bash -c "source '${WW_BASE}/lib/core-utils.sh'"
    assert_success
}

@test "smoke: lib/sync-permissions.sh sources without error" {
    run bash -c "WW_BASE='${WW_BASE}' source '${WW_BASE}/lib/sync-permissions.sh'"
    assert_success
}

@test "smoke: core-utils.sh log_error accepts a single string arg" {
    run bash -c "
        source '${WW_BASE}/lib/core-utils.sh'
        log_error 'test error message'
    "
    # Should exit non-zero but NOT crash with 'unbound variable'
    refute_output --partial "unbound variable"
    refute_output --partial "parameter null or not set"
}

@test "smoke: profile-uda.sh --help exits 0" {
    run bash "${WW_BASE}/services/profile/subservices/profile-uda.sh" help
    assert_success
    assert_output --partial "Usage"
}

@test "smoke: profile-uda.sh sources without crashing on empty profile" {
    # list with no UDAs defined should exit 0, not crash
    run bash "${WW_BASE}/services/profile/subservices/profile-uda.sh" list
    assert_success
    assert_output --partial "No UDAs defined"
}

# ── set -e grep trap ───────────────────────────────────────────────────────────

@test "smoke: grep no-match does not abort set -euo pipefail script" {
    run bash -c "
        set -euo pipefail
        result=\$(grep 'NOMATCH' '${WORKWARRIOR_BASE}/.taskrc' || true)
        echo \"exit ok: '\${result}'\"
    "
    assert_success
    assert_output --partial "exit ok"
}

@test "smoke: pipeline with grep no-match safe with pipefail + || true" {
    run bash -c "
        set -euo pipefail
        result=\$(echo '' | grep 'NOMATCH' | head -1 || true)
        echo \"ok: '\${result}'\"
    "
    assert_success
}

# ── task config confirmation ───────────────────────────────────────────────────

@test "smoke: task config with rc.confirmation=no does not prompt" {
    # Verify the flag suppresses interactive confirmation
    run bash -c "
        TASKRC='${WORKWARRIOR_BASE}/.taskrc' \
          task rc.confirmation=no config uda.smoketest.type string
    "
    assert_success
    assert_output --partial "modified"
    # Must NOT contain the interactive prompt text
    refute_output --partial "yes/no"
}

@test "smoke: task config value readable back via grep" {
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" \
        task rc.confirmation=no config uda.readback.type numeric >/dev/null
    run bash -c "
        grep -E '^uda\\.readback\\.type=' '${WORKWARRIOR_BASE}/.taskrc' | cut -d= -f2
    "
    assert_output "numeric"
}

# ── sync-permissions round-trip ────────────────────────────────────────────────

@test "smoke: sync-permissions write→read round-trip" {
    run bash -c "
        source '${WW_BASE}/lib/sync-permissions.sh'
        sp_set_permissions '${WORKWARRIOR_BASE}' 'goals' 'nosync,noai'
        sp_get_permissions '${WORKWARRIOR_BASE}' 'goals'
    "
    assert_success
    assert_output --partial "nosync"
    assert_output --partial "noai"
}

# ── bin/ww routing ─────────────────────────────────────────────────────────────

@test "smoke: bin/ww profile help exits 0" {
    run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE WW_BASE="${WW_BASE}" \
        bash "${WW_BASE}/bin/ww" profile help
    assert_success
    assert_output --partial "uda"
}

@test "smoke: bin/ww issues uda defaults to list (ww-native surface)" {
    run env -u WARRIOR_PROFILE WORKWARRIOR_BASE="${WORKWARRIOR_BASE}" \
        WW_BASE="${WW_BASE}" bash "${WW_BASE}/bin/ww" issues uda
    assert_success
    assert_output --partial "No UDAs defined"
}
