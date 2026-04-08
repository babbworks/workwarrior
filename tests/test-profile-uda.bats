#!/usr/bin/env bats
# Tests for ww profile uda surface — TASK-UDA-001
# Covers: list, add, remove, group, perm (lib/sync-permissions.sh)

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export TEST_MODE=1
    export WW_BASE="${BATS_TEST_DIRNAME}/.."
    export WORKWARRIOR_BASE
    WORKWARRIOR_BASE="$(mktemp -d)"
    export WARRIOR_PROFILE="testprofile"

    # Minimal .taskrc
    TASKRC_FILE="${WORKWARRIOR_BASE}/.taskrc"
    cat > "${TASKRC_FILE}" << 'EOF'
# Workwarrior test profile
data.location=.task
EOF

    export UDA_SCRIPT="${WW_BASE}/services/profile/subservices/profile-uda.sh"
}

teardown() {
    rm -rf "${WORKWARRIOR_BASE}"
}

# ── lib/sync-permissions.sh unit tests ────────────────────────────────────────

@test "sp_set_permissions: creates sync-permissions file" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "goals" "nosync,noai"
    [ -f "${WORKWARRIOR_BASE}/.config/sync-permissions" ]
}

@test "sp_get_permissions: returns tokens for a UDA" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "goals" "nosync,noai"
    run sp_get_permissions "${WORKWARRIOR_BASE}" "goals"
    assert_output --partial "nosync"
    assert_output --partial "noai"
}

@test "sp_has_permission: true when token present" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "phase" "readonly"
    run sp_has_permission "${WORKWARRIOR_BASE}" "phase" "readonly"
    assert_success
}

@test "sp_has_permission: false when token absent" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "phase" "readonly"
    run sp_has_permission "${WORKWARRIOR_BASE}" "phase" "nosync"
    assert_failure
}

@test "sp_add_permission: appends to existing permissions" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "goals" "nosync"
    sp_add_permission "${WORKWARRIOR_BASE}" "goals" "noai"
    run sp_get_permissions "${WORKWARRIOR_BASE}" "goals"
    assert_output --partial "nosync"
    assert_output --partial "noai"
}

@test "sp_add_permission: does not duplicate existing token" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "goals" "nosync"
    sp_add_permission "${WORKWARRIOR_BASE}" "goals" "nosync"
    count=$(sp_get_permissions "${WORKWARRIOR_BASE}" "goals" | grep -c "^nosync$")
    [ "${count}" -eq 1 ]
}

@test "sp_remove_permission: removes specific token" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "goals" "nosync,noai"
    sp_remove_permission "${WORKWARRIOR_BASE}" "goals" "nosync"
    run sp_get_permissions "${WORKWARRIOR_BASE}" "goals"
    refute_output --partial "nosync"
    assert_output --partial "noai"
}

@test "sp_set_permissions: empty permissions clears entry" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "goals" "nosync"
    sp_set_permissions "${WORKWARRIOR_BASE}" "goals" ""
    run sp_get_permissions "${WORKWARRIOR_BASE}" "goals"
    assert_output ""
}

@test "sp_list_all: returns all UDAs with permissions" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "goals" "nosync"
    sp_set_permissions "${WORKWARRIOR_BASE}" "phase" "readonly"
    run sp_list_all "${WORKWARRIOR_BASE}"
    assert_output --partial "goals"
    assert_output --partial "phase"
}

@test "sp_get_permissions: returns empty when no file exists" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    run sp_get_permissions "${WORKWARRIOR_BASE}" "nonexistent"
    assert_output ""
    assert_success
}

@test "sp_set_permissions: multiple UDAs coexist in file" {
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "alpha" "nosync"
    sp_set_permissions "${WORKWARRIOR_BASE}" "beta" "private"
    run sp_get_permissions "${WORKWARRIOR_BASE}" "alpha"
    assert_output --partial "nosync"
    run sp_get_permissions "${WORKWARRIOR_BASE}" "beta"
    assert_output --partial "private"
}

# ── profile-uda.sh help ────────────────────────────────────────────────────────

@test "profile-uda help: exits 0" {
    run bash "${UDA_SCRIPT}" help
    assert_success
}

@test "profile-uda help: shows usage" {
    run bash "${UDA_SCRIPT}" help
    assert_output --partial "Usage: ww profile uda"
}

@test "profile-uda help: shows all subcommands" {
    run bash "${UDA_SCRIPT}" help
    assert_output --partial "list"
    assert_output --partial "add"
    assert_output --partial "remove"
    assert_output --partial "group"
    assert_output --partial "perm"
}

@test "profile-uda help: documents perm tokens" {
    run bash "${UDA_SCRIPT}" help
    assert_output --partial "nosync"
    assert_output --partial "noai"
}

# ── profile-uda list ───────────────────────────────────────────────────────────

@test "profile-uda list: fails without active profile" {
    unset WORKWARRIOR_BASE
    run bash "${UDA_SCRIPT}" list
    assert_failure
}

@test "profile-uda list: shows empty message when no UDAs defined" {
    run bash "${UDA_SCRIPT}" list
    assert_success
    assert_output --partial "No UDAs defined"
}

@test "profile-uda list: shows user UDA after task rc.confirmation=no config write" {
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.goals.type string 2>/dev/null || true
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.goals.label "Goals" 2>/dev/null || true
    run bash "${UDA_SCRIPT}" list
    assert_success
    assert_output --partial "goals"
}

@test "profile-uda list: separates service UDAs into their own section" {
    # Simulate bugwarrior UDA
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.github_number.type numeric 2>/dev/null || true
    run bash "${UDA_SCRIPT}" list
    assert_success
    assert_output --partial "Service-managed"
    assert_output --partial "github_number"
}

@test "profile-uda list: uncategorized UDAs hidden without --all" {
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.hidden_uda.type string 2>/dev/null || true
    # Mark it uncategorized in .taskrc
    echo "# uda:hidden_uda uncategorized" >> "${WORKWARRIOR_BASE}/.taskrc"
    run bash "${UDA_SCRIPT}" list
    assert_success
    refute_output --partial "hidden_uda"
    assert_output --partial "uncategorized"
}

@test "profile-uda list --all: shows uncategorized UDAs" {
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.hidden_uda.type string 2>/dev/null || true
    echo "# uda:hidden_uda uncategorized" >> "${WORKWARRIOR_BASE}/.taskrc"
    run bash "${UDA_SCRIPT}" list --all
    assert_success
    assert_output --partial "hidden_uda"
}

@test "profile-uda list: shows nosync badge for permission-restricted UDA" {
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.goals.type string 2>/dev/null || true
    source "${WW_BASE}/lib/sync-permissions.sh"
    sp_set_permissions "${WORKWARRIOR_BASE}" "goals" "nosync"
    run bash "${UDA_SCRIPT}" list
    assert_success
    assert_output --partial "nosync"
}

# ── profile-uda remove ─────────────────────────────────────────────────────────

@test "profile-uda remove: fails for service-managed UDA" {
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.github_number.type numeric 2>/dev/null || true
    run bash "${UDA_SCRIPT}" remove github_number
    assert_failure
    assert_output --partial "service-managed"
}

@test "profile-uda remove: fails when UDA not found" {
    run bash "${UDA_SCRIPT}" remove nonexistent_uda
    assert_failure
    assert_output --partial "not found"
}

@test "profile-uda remove: requires name argument" {
    run bash "${UDA_SCRIPT}" remove
    assert_failure
    assert_output --partial "Usage"
}

# ── profile-uda perm ───────────────────────────────────────────────────────────

@test "profile-uda perm: shows 'no permissions' message when none set" {
    run bash "${UDA_SCRIPT}" perm someuda
    assert_success
    assert_output --partial "no sync permissions"
}

@test "profile-uda perm: sets permissions and confirms" {
    run bash "${UDA_SCRIPT}" perm myuda nosync noai
    assert_success
    assert_output --partial "nosync"
    assert_output --partial "noai"
}

@test "profile-uda perm: persists permissions to file" {
    bash "${UDA_SCRIPT}" perm myuda nosync
    source "${WW_BASE}/lib/sync-permissions.sh"
    run sp_has_permission "${WORKWARRIOR_BASE}" "myuda" "nosync"
    assert_success
}

@test "profile-uda perm: shows error without uda name" {
    run bash "${UDA_SCRIPT}" perm
    assert_failure
    assert_output --partial "Usage"
}

# ── profile-uda group ──────────────────────────────────────────────────────────

@test "profile-uda group: requires uda name argument" {
    run bash "${UDA_SCRIPT}" group
    assert_failure
    assert_output --partial "Usage"
}

@test "profile-uda group: fails when UDA not found" {
    run bash "${UDA_SCRIPT}" group nonexistent_uda mygroup
    assert_failure
    assert_output --partial "not found"
}

@test "profile-uda group: writes group to .taskrc comment block" {
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.goals.type string 2>/dev/null || true
    run bash "${UDA_SCRIPT}" group goals work
    assert_success
    assert_output --partial "work"
    grep -q "WW UDA GROUPS" "${WORKWARRIOR_BASE}/.taskrc"
}

@test "profile-uda group: appends uda to existing group" {
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.goals.type string 2>/dev/null || true
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.phase.type string 2>/dev/null || true
    bash "${UDA_SCRIPT}" group goals work
    bash "${UDA_SCRIPT}" group phase work
    grep -q "goals" "${WORKWARRIOR_BASE}/.taskrc"
    grep -q "phase" "${WORKWARRIOR_BASE}/.taskrc"
}

# ── profile-uda add (interactive wizard) ──────────────────────────────────────
# Input order matches read prompts in order:
#   name (if not pre-supplied), type, label, values, group

@test "profile-uda add wizard: minimal path (name arg, string, no values, no group)" {
    # args: name=goals; prompts: type=string, label=Goals, values=(skip), group=(skip)
    run bash -c "printf 'string\nGoals\n\n\n' | bash '${UDA_SCRIPT}' add goals"
    assert_success
    assert_output --partial "UDA 'goals' added"
    type=$(grep -E '^uda\.goals\.type=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${type}" = "string" ]
}

@test "profile-uda add wizard: label auto-generated from name" {
    run bash -c "printf 'string\n\n\n\n' | bash '${UDA_SCRIPT}' add my_goal"
    assert_success
    label=$(grep -E '^uda\.my_goal\.label=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${label}" = "My Goal" ]
}

@test "profile-uda add wizard: custom label accepted" {
    run bash -c "printf 'string\nCustom Label\n\n\n' | bash '${UDA_SCRIPT}' add phase"
    assert_success
    label=$(grep -E '^uda\.phase\.label=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${label}" = "Custom Label" ]
}

@test "profile-uda add wizard: values written to .taskrc" {
    # type=string, label=Phase, values=todo,doing,done, order=confirm(Enter), default=none, group=skip
    run bash -c "printf 'string\nPhase\ntodo,doing,done\n\n\n\n' | bash '${UDA_SCRIPT}' add phase"
    assert_success
    values=$(grep -E '^uda\.phase\.values=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${values}" = "todo,doing,done" ]
}

@test "profile-uda add wizard: trailing comma preserved in values" {
    # trailing comma = unset allowed
    run bash -c "printf 'string\nPhase\nlow,medium,high,\n\n\n\n' | bash '${UDA_SCRIPT}' add phase"
    assert_success
    values=$(grep -E '^uda\.phase\.values=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [[ "${values}" == *"," ]]
}

@test "profile-uda add wizard: reorder confirmation changes value order" {
    # values=a,b,c then reorder: 3 1 2 → c,a,b; default=none; group=skip
    run bash -c "printf 'string\nRank\na,b,c\n3 1 2\n\n\n' | bash '${UDA_SCRIPT}' add rank"
    assert_success
    values=$(grep -E '^uda\.rank\.values=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${values}" = "c,a,b" ]
}

@test "profile-uda add wizard: numeric type accepted" {
    run bash -c "printf 'numeric\nScore\n\n' | bash '${UDA_SCRIPT}' add score"
    assert_success
    type=$(grep -E '^uda\.score\.type=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${type}" = "numeric" ]
}

@test "profile-uda add wizard: date type accepted" {
    run bash -c "printf 'date\nDeadline\n\n' | bash '${UDA_SCRIPT}' add deadline"
    assert_success
    type=$(grep -E '^uda\.deadline\.type=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${type}" = "date" ]
}

@test "profile-uda add wizard: invalid type exits non-zero" {
    run bash -c "printf 'badtype\n' | bash '${UDA_SCRIPT}' add myuda"
    assert_failure
    assert_output --partial "Invalid type"
}

@test "profile-uda add wizard: group assignment writes to .taskrc group block" {
    # prompts in order: type, label, values(skip=Enter), group name
    # no existing groups → single "Group name:" prompt
    run bash -c "printf 'string\nGoals\n\nwork\n' | bash '${UDA_SCRIPT}' add goals"
    assert_success
    grep -q "WW UDA GROUPS" "${WORKWARRIOR_BASE}/.taskrc"
    grep -q "group:work" "${WORKWARRIOR_BASE}/.taskrc"
}

@test "profile-uda add wizard: duplicate name rejected" {
    # Add goals first
    bash -c "printf 'string\nGoals\n\n\n' | bash '${UDA_SCRIPT}' add goals" >/dev/null
    # Try to add again
    run bash -c "printf 'string\nGoals\n\n\n' | bash '${UDA_SCRIPT}' add goals"
    assert_failure
    assert_output --partial "already exists"
}

@test "profile-uda add wizard: service-reserved name rejected" {
    run bash -c "printf 'string\nLabel\n\n\n' | bash '${UDA_SCRIPT}' add github_anything"
    assert_failure
    assert_output --partial "reserved"
}

@test "profile-uda add wizard: interactive name prompt (no name arg)" {
    # No name arg — wizard prompts for it first
    run bash -c "printf 'myfield\nstring\nMy Field\n\n\n' | bash '${UDA_SCRIPT}' add"
    assert_success
    type=$(grep -E '^uda\.myfield\.type=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${type}" = "string" ]
}

# ── UDA-002: indicator assignment ─────────────────────────────────────────────

@test "indicator: assigned when uda added with group" {
    run bash -c "printf 'string\nGoals\n\nplanning\n' | bash '${UDA_SCRIPT}' add goals"
    assert_success
    indicator=$(grep -E '^uda\.goals\.indicator=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ -n "${indicator}" ]
}

@test "indicator: planning group gets ⊞ character" {
    run bash -c "printf 'string\nGoals\n\nplanning\n' | bash '${UDA_SCRIPT}' add goals"
    assert_success
    indicator=$(grep -E '^uda\.goals\.indicator=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${indicator}" = "⊞" ]
}

@test "indicator: work group gets ⊡ character" {
    run bash -c "printf 'string\nPhase\n\nwork\n' | bash '${UDA_SCRIPT}' add phase"
    assert_success
    indicator=$(grep -E '^uda\.phase\.indicator=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${indicator}" = "⊡" ]
}

@test "indicator: unrecognized group falls back to ◆" {
    run bash -c "printf 'string\nFoo\n\nmygroup\n' | bash '${UDA_SCRIPT}' add foo"
    assert_success
    indicator=$(grep -E '^uda\.foo\.indicator=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${indicator}" = "◆" ]
}

@test "indicator: not written when no group assigned" {
    run bash -c "printf 'string\nGoals\n\n\n' | bash '${UDA_SCRIPT}' add goals"
    assert_success
    indicator=$(grep -E '^uda\.goals\.indicator=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ -z "${indicator}" ]
}

@test "indicator: shown in list output" {
    bash -c "printf 'string\nGoals\n\nplanning\n' | bash '${UDA_SCRIPT}' add goals" >/dev/null
    run bash "${UDA_SCRIPT}" list
    assert_success
    assert_output --partial "⊞"
}

# ── UDA-003: color rules ───────────────────────────────────────────────────────

@test "color: rule written to .taskrc when group assigned" {
    run bash -c "printf 'string\nGoals\n\nplanning\n' | bash '${UDA_SCRIPT}' add goals"
    assert_success
    color=$(grep -E '^color\.uda\.goals=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ -n "${color}" ]
}

@test "color: planning group writes green (no uda_override for this name)" {
    # 'mytask' has no uda_override entry so falls through to group color
    run bash -c "printf 'string\nMyTask\n\nplanning\n' | bash '${UDA_SCRIPT}' add mytask"
    assert_success
    color=$(grep -E '^color\.uda\.mytask=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${color}" = "green" ]
}

@test "color: content group writes rgb:255/165/0 (orange)" {
    run bash -c "printf 'string\nNotes\n\ncontent\n' | bash '${UDA_SCRIPT}' add notes"
    assert_success
    color=$(grep -E '^color\.uda\.notes=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${color}" = "rgb:255/165/0" ]
}

@test "color: uda_override takes precedence over group (goals = orange not planning green)" {
    run bash -c "printf 'string\nGoals\n\nplanning\n' | bash '${UDA_SCRIPT}' add goals"
    assert_success
    color=$(grep -E '^color\.uda\.goals=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${color}" = "rgb:255/165/0" ]
}

@test "color: WW COLOR RULES block created in .taskrc" {
    run bash -c "printf 'string\nGoals\n\nplanning\n' | bash '${UDA_SCRIPT}' add goals"
    assert_success
    grep -q "WW COLOR RULES" "${WORKWARRIOR_BASE}/.taskrc"
}

@test "color: not written when no group assigned" {
    run bash -c "printf 'string\nGoals\n\n\n' | bash '${UDA_SCRIPT}' add goals"
    assert_success
    color=$(grep -E '^color\.uda\.goals=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ -z "${color}" ]
}

@test "color subcommand: shows current color for a UDA" {
    bash -c "printf 'string\nGoals\n\nplanning\n' | bash '${UDA_SCRIPT}' add goals" >/dev/null
    run bash "${UDA_SCRIPT}" color goals
    assert_success
    assert_output --partial "color.uda.goals="
}

@test "color subcommand: sets color and confirms" {
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.goals.type string 2>/dev/null || true
    run bash "${UDA_SCRIPT}" color goals "bold blue"
    assert_success
    assert_output --partial "color.uda.goals=bold blue"
    color=$(grep -E '^color\.uda\.goals=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${color}" = "bold blue" ]
}

@test "color subcommand: updates existing rule" {
    bash -c "printf 'string\nGoals\n\nplanning\n' | bash '${UDA_SCRIPT}' add goals" >/dev/null
    bash "${UDA_SCRIPT}" color goals "bold red" >/dev/null
    color=$(grep -E '^color\.uda\.goals=' "${WORKWARRIOR_BASE}/.taskrc" | cut -d= -f2 | head -1 || true)
    [ "${color}" = "bold red" ]
    # Should only have one color rule for goals
    count=$(grep -c "^color\.uda\.goals=" "${WORKWARRIOR_BASE}/.taskrc" || true)
    [ "${count}" -eq 1 ]
}

@test "color subcommand: shows 'no color rule' message when none set" {
    TASKRC="${WORKWARRIOR_BASE}/.taskrc" task rc.confirmation=no config uda.goals.type string 2>/dev/null || true
    run bash "${UDA_SCRIPT}" color goals
    assert_success
    assert_output --partial "no color rule"
}

@test "color subcommand: requires uda name" {
    run bash "${UDA_SCRIPT}" color
    assert_failure
    assert_output --partial "Usage"
}

# ── unknown subcommand ─────────────────────────────────────────────────────────

@test "profile-uda unknown subcommand: exits non-zero" {
    run bash "${UDA_SCRIPT}" boguscommand
    assert_failure
}
