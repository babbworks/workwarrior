#!/usr/bin/env bats
# Tests for ww profile urgency surface — TASK-URG-001
# Covers: show, set, reset, explain, help; coefficient read/write helpers

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export WW_BASE="${BATS_TEST_DIRNAME}/.."
    export WORKWARRIOR_BASE
    WORKWARRIOR_BASE="$(mktemp -d)"
    export WARRIOR_PROFILE="urgtest"
    export URG_SCRIPT="${WW_BASE}/services/profile/urgency.sh"

    cat > "${WORKWARRIOR_BASE}/.taskrc" << 'EOF'
data.location=.task
EOF
    mkdir -p "${WORKWARRIOR_BASE}/.task"
}

teardown() {
    rm -rf "${WORKWARRIOR_BASE}"
}

# ── help ───────────────────────────────────────────────────────────────────────

@test "urgency help: exits 0" {
    run bash "${URG_SCRIPT}" help
    assert_success
}

@test "urgency help: shows all subcommands" {
    run bash "${URG_SCRIPT}" help
    assert_output --partial "show"
    assert_output --partial "set"
    assert_output --partial "tune"
    assert_output --partial "reset"
    assert_output --partial "explain"
}

@test "urgency help: documents coefficient syntax" {
    run bash "${URG_SCRIPT}" help
    assert_output --partial "urgency.uda."
    assert_output --partial "coefficient"
}

# ── requires active profile ───────────────────────────────────────────────────

@test "urgency show: fails without active profile" {
    run env -u WORKWARRIOR_BASE bash "${URG_SCRIPT}" show
    assert_failure
}

@test "urgency set: fails without active profile" {
    run env -u WORKWARRIOR_BASE bash "${URG_SCRIPT}" set due 10.0
    assert_failure
}

# ── show ──────────────────────────────────────────────────────────────────────

@test "urgency show: exits 0 with active profile" {
    run bash "${URG_SCRIPT}" show
    assert_success
}

@test "urgency show: displays built-in factors section" {
    run bash "${URG_SCRIPT}" show
    assert_output --partial "Built-in factors"
    assert_output --partial "due"
    assert_output --partial "blocking"
}

@test "urgency show: shows TW default for due (12.0)" {
    run bash "${URG_SCRIPT}" show
    assert_output --partial "12.0"
}

@test "urgency show: shows taskrc source when coefficient set" {
    echo "urgency.due.coefficient=9.5" >> "${WORKWARRIOR_BASE}/.taskrc"
    run bash "${URG_SCRIPT}" show
    assert_output --partial "9.5"
    assert_output --partial "taskrc"
}

@test "urgency show: shows UDA section when UDAs defined" {
    echo "uda.goals.type=string" >> "${WORKWARRIOR_BASE}/.taskrc"
    run bash "${URG_SCRIPT}" show
    assert_output --partial "UDA presence"
    assert_output --partial "uda.goals"
}

@test "urgency show: shows UDA value coefficient section when set" {
    echo "urgency.uda.phase.review.coefficient=5.0" >> "${WORKWARRIOR_BASE}/.taskrc"
    run bash "${URG_SCRIPT}" show
    assert_output --partial "UDA value"
    assert_output --partial "5.0"
}

# ── set ───────────────────────────────────────────────────────────────────────

@test "urgency set: writes coefficient to .taskrc" {
    run bash "${URG_SCRIPT}" set due 10.0
    assert_success
    grep -q "urgency.due.coefficient=10.0" "${WORKWARRIOR_BASE}/.taskrc"
}

@test "urgency set: creates WW URGENCY block" {
    bash "${URG_SCRIPT}" set due 10.0
    grep -q "WW URGENCY" "${WORKWARRIOR_BASE}/.taskrc"
}

@test "urgency set: writes UDA presence coefficient" {
    run bash "${URG_SCRIPT}" set uda.goals 2.0
    assert_success
    grep -q "urgency.uda.goals.coefficient=2.0" "${WORKWARRIOR_BASE}/.taskrc"
}

@test "urgency set: writes UDA value coefficient" {
    run bash "${URG_SCRIPT}" set uda.phase.review 5.0
    assert_success
    grep -q "urgency.uda.phase.review.coefficient=5.0" "${WORKWARRIOR_BASE}/.taskrc"
}

@test "urgency set: confirms with key=value output" {
    run bash "${URG_SCRIPT}" set due 9.0
    assert_success
    assert_output --partial "urgency.due.coefficient=9.0"
}

@test "urgency set: rejects non-numeric value" {
    run bash "${URG_SCRIPT}" set due notanumber
    assert_failure
    assert_output --partial "numeric"
}

@test "urgency set: rejects missing factor arg" {
    run bash "${URG_SCRIPT}" set
    assert_failure
    assert_output --partial "Usage"
}

@test "urgency set: rejects missing value arg" {
    run bash "${URG_SCRIPT}" set due
    assert_failure
    assert_output --partial "Usage"
}

@test "urgency set: updates existing coefficient in-place (no duplicate)" {
    bash "${URG_SCRIPT}" set due 10.0
    bash "${URG_SCRIPT}" set due 8.0
    count=$(grep -c "^urgency.due.coefficient=" "${WORKWARRIOR_BASE}/.taskrc" || true)
    [ "${count}" -eq 1 ]
    grep -q "urgency.due.coefficient=8.0" "${WORKWARRIOR_BASE}/.taskrc"
}

@test "urgency set: negative value accepted (e.g. waiting=-3.0)" {
    run bash "${URG_SCRIPT}" set waiting -3.0
    assert_success
    grep -q "urgency.waiting.coefficient=-3.0" "${WORKWARRIOR_BASE}/.taskrc"
}

# ── reset ─────────────────────────────────────────────────────────────────────

@test "urgency reset: removes WW URGENCY block" {
    bash "${URG_SCRIPT}" set due 10.0
    printf 'y\n' | bash "${URG_SCRIPT}" reset
    run grep "WW URGENCY" "${WORKWARRIOR_BASE}/.taskrc"
    assert_failure
}

@test "urgency reset: removes coefficient lines" {
    bash "${URG_SCRIPT}" set due 10.0
    bash "${URG_SCRIPT}" set uda.goals 2.0
    printf 'y\n' | bash "${URG_SCRIPT}" reset
    run grep "^urgency\." "${WORKWARRIOR_BASE}/.taskrc"
    assert_failure
}

@test "urgency reset: aborts on N confirmation" {
    bash "${URG_SCRIPT}" set due 10.0
    printf 'n\n' | bash "${URG_SCRIPT}" reset
    grep -q "urgency.due.coefficient=10.0" "${WORKWARRIOR_BASE}/.taskrc"
}

@test "urgency reset: no-op message when nothing set" {
    run bash "${URG_SCRIPT}" reset
    assert_success
    assert_output --partial "No urgency coefficients"
}

# ── explain ───────────────────────────────────────────────────────────────────

@test "urgency explain: requires task-id argument" {
    run bash "${URG_SCRIPT}" explain
    assert_failure
    assert_output --partial "Usage"
}

@test "urgency explain: fails gracefully for non-existent task" {
    run bash "${URG_SCRIPT}" explain 9999
    assert_failure
    assert_output --partial "not found"
}

# ── unknown subcommand ─────────────────────────────────────────────────────────

@test "urgency unknown subcommand: exits non-zero" {
    run bash "${URG_SCRIPT}" bogus
    assert_failure
}

# ── bin/ww routing ────────────────────────────────────────────────────────────

@test "bin/ww profile urgency help: routes correctly" {
    run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE WW_BASE="${WW_BASE}" \
        bash "${WW_BASE}/bin/ww" profile urgency help
    assert_success
    assert_output --partial "Urgency"
}

@test "bin/ww profile help: includes urgency section" {
    run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE WW_BASE="${WW_BASE}" \
        bash "${WW_BASE}/bin/ww" profile help
    assert_success
    assert_output --partial "urgency"
}
