#!/usr/bin/env bats
# Tests for multi-list management (TASK-LIST-001)
# Feature: list new, list which, list switch, lists picker, orientation header
#
# Run:  bats dev/tests/test-list-service.bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    export WW_BASE="${BATS_TEST_DIRNAME}/../.."
    export TEST_PROFILE_BASE
    TEST_PROFILE_BASE="$(mktemp -d)"
    export WORKWARRIOR_BASE="$TEST_PROFILE_BASE"
    export WARRIOR_PROFILE="testprof"

    # Create profile structure
    mkdir -p "$TEST_PROFILE_BASE/list"
    touch "$TEST_PROFILE_BASE/list/tasks"

    # Create lists.yaml
    cat > "$TEST_PROFILE_BASE/lists.yaml" << 'EOF'
lists:
  default: tasks
EOF

    export LIST_PY="$WW_BASE/tools/list/list.py"
    export LIST_DIR="$TEST_PROFILE_BASE/list"
    export LISTS_YAML="$TEST_PROFILE_BASE/lists.yaml"
}

teardown() {
    if [[ -d "$TEST_PROFILE_BASE" ]]; then
        rm -rf "$TEST_PROFILE_BASE"
    fi
}

# ============================================================================
# list new
# ============================================================================

@test "list new: creates a new list file and exits 0" {
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof new ideas
    assert_success
    assert_output --partial "Created list: ideas"
    [ -f "$LIST_DIR/ideas" ]
}

@test "list new: rejects duplicate name with exit 1" {
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof new tasks
    assert_failure
    assert_output --partial "already exists"
}

@test "list new: rejects empty name" {
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof new
    assert_failure
    assert_output --partial "requires a name"
}

@test "list new: rejects invalid characters in name" {
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof new "bad name"
    assert_failure
    assert_output --partial "alphanumeric"
}

# ============================================================================
# list which
# ============================================================================

@test "list which: prints profile / list" {
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof which
    assert_success
    assert_output "testprof / tasks"
}

@test "list which: reflects current default list" {
    # Switch to a different list first
    touch "$LIST_DIR/ideas"
    python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof switch ideas
    # Now check which
    run python3 "$LIST_PY" -t "$LIST_DIR" -l ideas --profile-name testprof which
    assert_success
    assert_output "testprof / ideas"
}

# ============================================================================
# list switch
# ============================================================================

@test "list switch <name>: updates default in lists.yaml" {
    touch "$LIST_DIR/projects"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof switch projects
    assert_success
    assert_output --partial "Switched to list: projects"
    run grep "default: projects" "$LISTS_YAML"
    assert_success
}

@test "list switch: errors if list does not exist" {
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof switch nonexistent
    assert_failure
    assert_output --partial "does not exist"
}

@test "list switch (bare, non-TTY): prints lists and exits 0 without blocking" {
    touch "$LIST_DIR/ideas"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof switch
    assert_success
    # Should show the picker output (numbered list)
    assert_output --partial "1."
    assert_output --partial "tasks"
}

# ============================================================================
# lists (--show-lists)
# ============================================================================

@test "lists: shows numbered lists with default marked (non-TTY exits 0)" {
    touch "$LIST_DIR/ideas"
    touch "$LIST_DIR/projects"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof --show-lists
    assert_success
    assert_output --partial "ideas"
    assert_output --partial "projects"
    assert_output --partial "tasks"
    assert_output --partial "*"
}

@test "lists: marks current default with asterisk" {
    touch "$LIST_DIR/ideas"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof --show-lists
    assert_success
    # tasks is default, should have asterisk
    assert_output --partial "tasks *"
}

@test "lists: no lists shows message" {
    rm -f "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof --show-lists
    assert_success
    assert_output --partial "No lists found"
}

# ============================================================================
# Orientation header
# ============================================================================

@test "list (bare): prints orientation header before items" {
    echo "buy milk | id:abc123" > "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof
    assert_success
    # First line should be the header
    local first_line
    first_line="$(echo "$output" | head -1)"
    [ "$first_line" = "testprof / tasks" ]
}

@test "list (bare, --quiet): suppresses orientation header" {
    echo "buy milk | id:abc123" > "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof -q
    assert_success
    refute_output --partial "testprof / tasks"
    assert_output --partial "buy milk"
}

@test "list (bare, no profile name): no header printed" {
    echo "buy milk | id:abc123" > "$LIST_DIR/tasks"
    unset WARRIOR_PROFILE
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks
    assert_success
    # Without profile name, no header
    refute_output --partial " / tasks"
    assert_output --partial "buy milk"
}

# ============================================================================
# Existing behavior unchanged
# ============================================================================

@test "list add: adding a task still works" {
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof "hello world"
    assert_success
    # Should print the prefix/id
    [ -n "$output" ]
    # Task should be in the file
    run grep "hello world" "$LIST_DIR/tasks"
    assert_success
}

@test "list finish: finishing a task still works" {
    echo "buy milk | id:abc123def456789012345678901234567890" > "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof -f abc
    assert_success
    # Task should be gone from tasks file
    run grep "buy milk" "$LIST_DIR/tasks"
    assert_failure
}

@test "list remove: removing a task still works" {
    echo "buy milk | id:abc123def456789012345678901234567890" > "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof -r abc
    assert_success
    run grep "buy milk" "$LIST_DIR/tasks"
    assert_failure
}

# ============================================================================
# Routing via bin/ww
# ============================================================================

@test "ww list which: routes correctly" {
    run bash -c "
        export WW_BASE='${WW_BASE}'
        export WORKWARRIOR_BASE='${TEST_PROFILE_BASE}'
        export WARRIOR_PROFILE='testprof'
        '${WW_BASE}/bin/ww' list which
    "
    assert_success
    assert_output "testprof / tasks"
}

@test "ww lists: routes to show-lists (non-TTY)" {
    run bash -c "
        export WW_BASE='${WW_BASE}'
        export WORKWARRIOR_BASE='${TEST_PROFILE_BASE}'
        export WARRIOR_PROFILE='testprof'
        '${WW_BASE}/bin/ww' lists
    "
    assert_success
    assert_output --partial "tasks"
}

@test "ww list new: creates list via passthrough" {
    run bash -c "
        export WW_BASE='${WW_BASE}'
        export WORKWARRIOR_BASE='${TEST_PROFILE_BASE}'
        export WARRIOR_PROFILE='testprof'
        '${WW_BASE}/bin/ww' list new mylist
    "
    assert_success
    assert_output --partial "Created list: mylist"
    [ -f "$LIST_DIR/mylist" ]
}

@test "ww list switch: switches via passthrough" {
    touch "$LIST_DIR/other"
    run bash -c "
        export WW_BASE='${WW_BASE}'
        export WORKWARRIOR_BASE='${TEST_PROFILE_BASE}'
        export WARRIOR_PROFILE='testprof'
        '${WW_BASE}/bin/ww' list switch other
    "
    assert_success
    assert_output --partial "Switched to list: other"
    run grep "default: other" "$LISTS_YAML"
    assert_success
}

# ============================================================================
# Shell function routing (list/lists via shell-integration.sh)
# ============================================================================

@test "shell: list function passes subcommands" {
    run bash -c "
        export WW_BASE='${WW_BASE}'
        export WORKWARRIOR_BASE='${TEST_PROFILE_BASE}'
        export WARRIOR_PROFILE='testprof'
        export WW_GLOBAL_BASE='${TEST_PROFILE_BASE}'
        source '${WW_BASE}/lib/core-utils.sh'
        source '${WW_BASE}/lib/shell-integration.sh'
        list which
    "
    assert_success
    assert_output "testprof / tasks"
}

@test "shell: lists function shows picker (non-TTY)" {
    touch "$LIST_DIR/ideas"
    run bash -c "
        export WW_BASE='${WW_BASE}'
        export WORKWARRIOR_BASE='${TEST_PROFILE_BASE}'
        export WARRIOR_PROFILE='testprof'
        export WW_GLOBAL_BASE='${TEST_PROFILE_BASE}'
        source '${WW_BASE}/lib/core-utils.sh'
        source '${WW_BASE}/lib/shell-integration.sh'
        lists
    "
    assert_success
    assert_output --partial "ideas"
    assert_output --partial "tasks"
}

# ============================================================================
# TASK-LIST-002: Tags, Notes, Export
# ============================================================================

@test "tag filter: list #tag filters items containing that tag" {
    echo "buy milk #errands | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    echo "read book #reading | id:bbb222ccc333ddd444eee555fff666aaa111bbb2" >> "$LIST_DIR/tasks"
    echo "clean house #errands | id:ccc333ddd444eee555fff666aaa111bbb222ccc3" >> "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof '#errands'
    assert_success
    assert_output --partial "buy milk #errands"
    assert_output --partial "clean house #errands"
    refute_output --partial "read book"
}

@test "tag filter: cross-list #tag search via --show-lists" {
    echo "buy milk #errands | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    echo "fix bug #work | id:bbb222ccc333ddd444eee555fff666aaa111bbb2" >> "$LIST_DIR/tasks"
    touch "$LIST_DIR/shopping"
    echo "get bread #errands | id:ddd444eee555fff666aaa111bbb222ccc333ddd4" > "$LIST_DIR/shopping"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof --show-lists '#errands'
    assert_success
    assert_output --partial "shopping:"
    assert_output --partial "get bread #errands"
    assert_output --partial "tasks:"
    assert_output --partial "buy milk #errands"
    refute_output --partial "fix bug"
}

@test "notes: -n shows note on second line with arrow" {
    echo "buy milk #errands // check oat milk sale | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof -n
    assert_success
    assert_output --partial "buy milk #errands // check oat milk sale"
    assert_output --partial "↳ check oat milk sale"
}

@test "notes: cross-list --show-lists -n shows annotated items grouped" {
    echo "buy milk // oat preferred | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    echo "no note item | id:bbb222ccc333ddd444eee555fff666aaa111bbb2" >> "$LIST_DIR/tasks"
    touch "$LIST_DIR/projects"
    echo "deploy app // friday deadline | id:ccc333ddd444eee555fff666aaa111bbb222ccc3" > "$LIST_DIR/projects"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof --show-lists -n
    assert_success
    assert_output --partial "projects:"
    assert_output --partial "deploy app"
    assert_output --partial "↳ friday deadline"
    assert_output --partial "tasks:"
    assert_output --partial "buy milk"
    assert_output --partial "↳ oat preferred"
    refute_output --partial "no note item"
}

@test "json: --json outputs valid JSON with correct fields" {
    echo "buy milk #errands // check sale | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof --json
    assert_success
    # Validate it's JSON with expected fields
    echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, list), 'Expected list'
item = data[0]
assert 'id' in item
assert 'prefix' in item
assert 'text' in item
assert 'body' in item
assert 'tags' in item
assert 'note' in item
assert 'done' in item
assert item['body'] == 'buy milk #errands'
assert item['tags'] == ['errands']
assert item['note'] == 'check sale'
assert item['done'] == False
"
}

@test "json: timestamp parsed into added field" {
    echo "[2026-07-14 08:00] read chapter 5 #reading | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof --json
    assert_success
    echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
item = data[0]
assert 'added' in item, 'Expected added field'
assert item['added'] == '2026-07-14 08:00'
assert item['body'] == 'read chapter 5 #reading'
"
}

@test "print: --print outputs clean text, no IDs" {
    echo "buy milk #errands | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    echo "read book | id:bbb222ccc333ddd444eee555fff666aaa111bbb2" >> "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof --print
    assert_success
    # Should not have orientation header
    refute_output --partial "testprof / tasks"
    # Should not have ID prefixes (no ' - ' prefix pattern)
    refute_output --regexp '^[a-f0-9]+ - '
    assert_output --partial "buy milk #errands"
    assert_output --partial "read book"
}

@test "export: --show-lists --export json dumps all lists as JSON object" {
    echo "buy milk | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    touch "$LIST_DIR/ideas"
    echo "learn rust | id:bbb222ccc333ddd444eee555fff666aaa111bbb2" > "$LIST_DIR/ideas"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof --show-lists --export json
    assert_success
    echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
assert isinstance(data, dict), 'Expected dict'
assert 'tasks' in data
assert 'ideas' in data
assert len(data['tasks']) == 1
assert len(data['ideas']) == 1
assert data['tasks'][0]['text'] == 'buy milk'
assert data['ideas'][0]['text'] == 'learn rust'
"
}

@test "tag filter: case-insensitive matching" {
    echo "buy milk #Errands | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof '#errands'
    assert_success
    assert_output --partial "buy milk #Errands"
}

@test "existing behavior: adding a task with # still works (non-tag position)" {
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof "learn C# programming"
    assert_success
    run grep "learn C# programming" "$LIST_DIR/tasks"
    assert_success
}

@test "json: --json suppresses orientation header" {
    echo "item one | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof --json
    assert_success
    # First char should be '[' (JSON array start)
    local first_char
    first_char="$(echo "$output" | head -c 1)"
    [ "$first_char" = "[" ]
}

@test "notes: items without notes don't show arrow line" {
    echo "simple item | id:aaa111bbb222ccc333ddd444eee555fff666aaa1" > "$LIST_DIR/tasks"
    run python3 "$LIST_PY" -t "$LIST_DIR" -l tasks --profile-name testprof -n
    assert_success
    assert_output --partial "simple item"
    refute_output --partial "↳"
}
