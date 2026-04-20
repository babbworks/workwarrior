#!/usr/bin/env bats
# ww routines — profile-scoped recurring task command surface
#
# Run: bats tests/test-routines.bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export REPO_ROOT="${BATS_TEST_DIRNAME}/.."
  export TEST_WW_BASE
  TEST_WW_BASE="$(mktemp -d)"
  cp -a "${REPO_ROOT}/lib" "${TEST_WW_BASE}/lib"
  mkdir -p "${TEST_WW_BASE}/profiles/rtest/.task"
  mkdir -p "${TEST_WW_BASE}/profiles/rtest/.timewarrior"
  echo 'data.location=.task' > "${TEST_WW_BASE}/profiles/rtest/.taskrc"
}

teardown() {
  rm -rf "${TEST_WW_BASE}"
}

@test "routines: list returns empty for new profile" {
  run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
    WW_BASE="${TEST_WW_BASE}" bash "${REPO_ROOT}/bin/ww" --profile rtest --verbose routines list
  assert_success
  assert_output --partial "(none)"
}

@test "routines: new creates template file" {
  run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
    WW_BASE="${TEST_WW_BASE}" WW_ROUTINES_NO_EDIT=1 EDITOR=true \
    bash "${REPO_ROOT}/bin/ww" --profile rtest routines new clean_room
  assert_success
  [ -f "${TEST_WW_BASE}/profiles/rtest/.config/routines/clean_room.py" ]
}

@test "routines: add shortcut creates routine from description" {
  run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
    WW_BASE="${TEST_WW_BASE}" WW_ROUTINES_NO_EDIT=1 EDITOR=true \
    bash "${REPO_ROOT}/bin/ww" --profile rtest routines add "Clean room" --frequency weekly
  assert_success
  [ -f "${TEST_WW_BASE}/profiles/rtest/.config/routines/clean_room.py" ]
  run bash -c "grep -E 'class CleanRoom\\(Weekly\\)|task = T\\(\"Clean room\"\\)' \"${TEST_WW_BASE}/profiles/rtest/.config/routines/clean_room.py\""
  assert_success
}

@test "routines: run executes routine script and writes state metadata" {
  mkdir -p "${TEST_WW_BASE}/profiles/rtest/.config/routines"
  cat > "${TEST_WW_BASE}/profiles/rtest/.config/routines/smoke.py" << 'PY'
#!/usr/bin/env python3
import os
base = os.environ.get("WORKWARRIOR_BASE", "")
with open(os.path.join(base, ".config", "routines", "ran.txt"), "w", encoding="utf-8") as f:
    f.write("ok")
PY
  chmod +x "${TEST_WW_BASE}/profiles/rtest/.config/routines/smoke.py"

  run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
    WW_BASE="${TEST_WW_BASE}" bash "${REPO_ROOT}/bin/ww" --profile rtest routines run smoke
  assert_success
  [ -f "${TEST_WW_BASE}/profiles/rtest/.config/routines/ran.txt" ]
  [ -f "${TEST_WW_BASE}/profiles/rtest/.config/routines/.ww-routines-state.json" ]
}

@test "routines: status --json returns object" {
  run env -u WARRIOR_PROFILE -u WORKWARRIOR_BASE \
    WW_BASE="${TEST_WW_BASE}" bash "${REPO_ROOT}/bin/ww" --profile rtest --json routines status
  assert_success
  assert_output --partial "\"profile\": \"rtest\""
  assert_output --partial "\"runtime_installed\""
}
