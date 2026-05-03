#!/usr/bin/env bats
# Tests for ww issues uda surface — TASK-ISSUES-001

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export REPO_ROOT="${BATS_TEST_DIRNAME}/.."
    export TEST_WW_BASE
    TEST_WW_BASE="$(mktemp -d)"

    mkdir -p "${TEST_WW_BASE}/bin" "${TEST_WW_BASE}/profiles/issueprof/.config/bugwarrior"
    cp "${REPO_ROOT}/bin/ww" "${TEST_WW_BASE}/bin/ww"
    chmod +x "${TEST_WW_BASE}/bin/ww"
    cp -a "${REPO_ROOT}/lib" "${TEST_WW_BASE}/lib"

    # Minimal profile state expected by resolve_scope_context / issues helpers.
    cat > "${TEST_WW_BASE}/profiles/issueprof/.taskrc" << 'EOF'
data.location=.task
EOF
    mkdir -p "${TEST_WW_BASE}/profiles/issueprof/.task"
    cat > "${TEST_WW_BASE}/profiles/issueprof/.config/bugwarrior/bugwarriorrc" << 'EOF'
[general]
targets = taskwarrior
EOF

    # Fake bugwarrior binary for deterministic tests.
    export FAKE_BIN="${TEST_WW_BASE}/fake-bin"
    mkdir -p "${FAKE_BIN}"
    cat > "${FAKE_BIN}/bugwarrior" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "uda" ]]; then
  cat <<'LINES'
uda.github_number.type=numeric
uda.github_number.label=GitHub Issue #
uda.github_repo.type=string
uda.github_repo.label=GitHub Repo
uda.github_url.type=string
uda.github_url.label=GitHub URL
LINES
  exit 0
fi
echo "unsupported fake bugwarrior subcommand: ${1:-}" >&2
exit 1
EOF
    chmod +x "${FAKE_BIN}/bugwarrior"
}

teardown() {
    rm -rf "${TEST_WW_BASE}"
}

@test "issues uda install: idempotent when run repeatedly" {
    run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
        PATH="${FAKE_BIN}:${PATH}" \
        WW_BASE="${TEST_WW_BASE}" \
        bash "${TEST_WW_BASE}/bin/ww" --profile issueprof issues uda install
    assert_success
    assert_output --partial "added"

    run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
        PATH="${FAKE_BIN}:${PATH}" \
        WW_BASE="${TEST_WW_BASE}" \
        bash "${TEST_WW_BASE}/bin/ww" --profile issueprof issues uda install
    assert_success
    assert_output --partial "0 added"

    run bash -c "grep -c '^uda\\.github_number\\.type=' '${TEST_WW_BASE}/profiles/issueprof/.taskrc'"
    assert_success
    assert_output "1"
}

@test "issues uda group github: writes canonical 15-field group to .uda-groups" {
    run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
        WW_BASE="${TEST_WW_BASE}" \
        bash "${TEST_WW_BASE}/bin/ww" --profile issueprof issues uda group github
    assert_success
    assert_output --partial "Group 'github' written"

    run bash -c "grep '^github:' '${TEST_WW_BASE}/profiles/issueprof/.uda-groups'"
    assert_success
    assert_output --partial "github_number"
    assert_output --partial "github_body"

    run bash -c "line=\$(grep '^github:' '${TEST_WW_BASE}/profiles/issueprof/.uda-groups'); list=\${line#github: }; echo \"\$list\" | tr ',' '\n' | wc -l | tr -d ' '"
    assert_success
    assert_output "15"

    # Redundant portability write in .taskrc metadata block.
    run bash -c "grep '^# group:github ' '${TEST_WW_BASE}/profiles/issueprof/.taskrc'"
    assert_success
    assert_output --partial "github_number"
    assert_output --partial "github_body"
}

@test "issues uda taskrc authority: install heals stale .uda-groups from taskrc metadata" {
    cat >> "${TEST_WW_BASE}/profiles/issueprof/.taskrc" << 'EOF'
# === WW UDA GROUPS ===
# group:github udas:github_number,github_repo
# === END WW UDA GROUPS ===
EOF
    echo "github: stale_old_value" > "${TEST_WW_BASE}/profiles/issueprof/.uda-groups"

    run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
        PATH="${FAKE_BIN}:${PATH}" \
        WW_BASE="${TEST_WW_BASE}" \
        bash "${TEST_WW_BASE}/bin/ww" --profile issueprof issues uda install
    assert_success

    run bash -c "grep '^github:' '${TEST_WW_BASE}/profiles/issueprof/.uda-groups'"
    assert_success
    assert_output "github: github_number,github_repo"
}
