#!/usr/bin/env bats
# test-deps-fleet.bats — TASK-DEPS-001
#
# Tests for `ww deps check --all`: the fleet view.
# Verifies:
#   - Iterates registered instances
#   - Reads each instance's .state/deps.json
#   - Reports unknown when no stamp
#   - Reports stale when manifest fingerprint changed
#   - Reports below_floor correctly
#   - Exit 1 when any hard-floor violation exists
#   - --format json produces valid JSON
#   - Read-only: never modifies instance state

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export WW_BASE="${BATS_TEST_TMPDIR}/ww-instance"
  export WW_CONFIG_HOME="${BATS_TEST_TMPDIR}/config-home"
  export WW_REGISTRY_DIR="${WW_CONFIG_HOME}/registry"

  mkdir -p "$WW_BASE/lib"
  mkdir -p "$WW_BASE/config"
  mkdir -p "$WW_REGISTRY_DIR"

  local repo_root="${BATS_TEST_DIRNAME}/../.."

  # Copy required libs
  cp "${repo_root}/lib/deps-state.sh" "$WW_BASE/lib/"
  cp "${repo_root}/lib/deps-manifest.sh" "$WW_BASE/lib/"
  cp "${repo_root}/lib/instance-registry.sh" "$WW_BASE/lib/"

  # Create a minimal dependencies.yaml for fingerprint calculation
  cat > "$WW_BASE/config/dependencies.yaml" <<'EOF'
tools:
  hledger:
    min_version: "1.52"
    enforcement: hard
    strategy: static
    display: hledger
  task:
    min_version: "2.6.0"
    enforcement: advisory
    strategy: package
    display: TaskWarrior
  timew:
    min_version: "1.4.0"
    enforcement: advisory
    strategy: package
    display: TimeWarrior
EOF

  # Compute the manifest fingerprint
  MANIFEST_FP="$(sha256sum "$WW_BASE/config/dependencies.yaml" | cut -d' ' -f1)"

  # --- Instance A: all ok ---
  local inst_a="${BATS_TEST_TMPDIR}/instances/factory-a"
  mkdir -p "$inst_a/.state"
  cat > "$inst_a/.state/deps.json" <<EOF
{
  "schema": "v1",
  "checked_at": 1783980000,
  "manifest": "${MANIFEST_FP}",
  "tools": {
    "hledger": {"version": "1.52.1", "min": "1.52", "status": "ok", "path": "/usr/local/bin/hledger"},
    "task": {"version": "2.6.2", "min": "2.6.0", "status": "ok", "path": "/usr/bin/task"},
    "timew": {"version": "1.4.3", "min": "1.4.0", "status": "ok", "path": "/usr/bin/timew"}
  }
}
EOF
  # Register instance A
  cat > "$WW_REGISTRY_DIR/factory-a.json" <<EOF
{
  "id": "factory-a",
  "alias": "factory-a",
  "version": "1.0.0",
  "visibility": "visible",
  "install_path": "$inst_a",
  "status": "active"
}
EOF

  # --- Instance B: hledger below floor ---
  local inst_b="${BATS_TEST_TMPDIR}/instances/home"
  mkdir -p "$inst_b/.state"
  cat > "$inst_b/.state/deps.json" <<EOF
{
  "schema": "v1",
  "checked_at": 1783970000,
  "manifest": "${MANIFEST_FP}",
  "tools": {
    "hledger": {"version": "1.25", "min": "1.52", "status": "below_floor", "path": "/usr/bin/hledger"},
    "task": {"version": "2.6.2", "min": "2.6.0", "status": "ok", "path": "/usr/bin/task"},
    "timew": {"version": "1.4.3", "min": "1.4.0", "status": "ok", "path": "/usr/bin/timew"}
  }
}
EOF
  cat > "$WW_REGISTRY_DIR/home.json" <<EOF
{
  "id": "home",
  "alias": "home",
  "version": "1.0.0",
  "visibility": "visible",
  "install_path": "$inst_b",
  "status": "active"
}
EOF

  # --- Instance C: no stamp (unknown) ---
  local inst_c="${BATS_TEST_TMPDIR}/instances/fresh-install"
  mkdir -p "$inst_c"
  cat > "$WW_REGISTRY_DIR/fresh-install.json" <<EOF
{
  "id": "fresh-install",
  "alias": "fresh",
  "version": "1.0.0",
  "visibility": "visible",
  "install_path": "$inst_c",
  "status": "active"
}
EOF

  # --- Instance D: stale stamp (old manifest fingerprint) ---
  local inst_d="${BATS_TEST_TMPDIR}/instances/stale-one"
  mkdir -p "$inst_d/.state"
  cat > "$inst_d/.state/deps.json" <<EOF
{
  "schema": "v1",
  "checked_at": 1783950000,
  "manifest": "old_fingerprint_that_does_not_match",
  "tools": {
    "hledger": {"version": "1.52.1", "min": "1.52", "status": "ok", "path": "/usr/local/bin/hledger"},
    "task": {"version": "2.6.2", "min": "2.6.0", "status": "ok", "path": "/usr/bin/task"}
  }
}
EOF
  cat > "$WW_REGISTRY_DIR/stale-one.json" <<EOF
{
  "id": "stale-one",
  "alias": "stale-one",
  "version": "1.0.0",
  "visibility": "visible",
  "install_path": "$inst_d",
  "status": "active"
}
EOF
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR"
}

# Helper: source the libs and run the fleet check function
run_fleet_check() {
  (
    source "$WW_BASE/lib/instance-registry.sh"
    source "$WW_BASE/lib/deps-manifest.sh"
    source "$WW_BASE/lib/deps-state.sh"

    # Stub log functions
    log_error() { echo "ERROR: $*" >&2; }
    log_success() { echo "OK: $*" >&2; }
    log_warning() { echo "WARN: $*" >&2; }

    # Extract the fleet functions from bin/ww using Python (more robust than sed)
    local repo_root="${BATS_TEST_DIRNAME}/../.."
    eval "$(python3 -c "
import re, sys
with open('${repo_root}/bin/ww') as f:
    content = f.read()

# Extract named functions
funcs = ['cmd_deps_check_all', '_deps_fleet_add_unknown', '_deps_fleet_json', '_deps_fleet_has_violations']
for fname in funcs:
    # Match function_name() { ... } with brace counting
    pattern = r'^(' + re.escape(fname) + r'\(\) \{)'
    match = re.search(pattern, content, re.MULTILINE)
    if not match:
        continue
    start = match.start()
    # Count braces to find the end
    depth = 0
    i = match.start(1) + len(match.group(1)) - 1  # position of opening {
    for j in range(i, len(content)):
        if content[j] == '{':
            depth += 1
        elif content[j] == '}':
            depth -= 1
            if depth == 0:
                print(content[start:j+1])
                print()
                break
")"

    cmd_deps_check_all "$@"
  )
}


# ── Basic functionality ─────────────────────────────────────────────────────

@test "fleet check runs without error when instances exist" {
  # It will exit 1 because instance B is below floor — that's correct
  run run_fleet_check "text"
  # Should produce output (not crash)
  [[ -n "$output" ]]
}

@test "fleet check reports registered instances" {
  run run_fleet_check "text"
  assert_output --partial "factory-a"
  assert_output --partial "home"
}


# ── Criterion 1: Fleet table format ────────────────────────────────────────

@test "fleet table shows tool versions" {
  run run_fleet_check "text"
  assert_output --partial "1.52.1"
  assert_output --partial "1.25"
}

@test "fleet table shows floor for below-floor tools" {
  run run_fleet_check "text"
  assert_output --partial "BELOW FLOOR"
}


# ── Criterion 2: No stamp = unknown ────────────────────────────────────────

@test "instance with no stamp reports NO STAMP" {
  run run_fleet_check "text"
  assert_output --partial "fresh"
  assert_output --partial "NO STAMP"
}


# ── Criterion 3: Stale stamp detection ─────────────────────────────────────

@test "stale stamp (old manifest fingerprint) reports STALE" {
  run run_fleet_check "text"
  assert_output --partial "stale-one"
  assert_output --partial "STALE"
}


# ── Criterion 4: JSON format ───────────────────────────────────────────────

@test "--format json produces valid JSON" {
  run run_fleet_check "json"
  # Strip any stderr lines and validate JSON
  echo "$output" | python3 -c "import json, sys; json.load(sys.stdin)"
}

@test "JSON output contains fleet array" {
  run run_fleet_check "json"
  local has_fleet
  has_fleet=$(echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('yes' if 'fleet' in data and isinstance(data['fleet'], list) else 'no')
")
  [ "$has_fleet" = "yes" ]
}

@test "JSON output contains has_violations flag" {
  run run_fleet_check "json"
  local has_viol
  has_viol=$(echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('has_violations', 'missing'))
")
  [ "$has_viol" = "True" ]
}

@test "JSON output shows instance with below_floor status" {
  run run_fleet_check "json"
  local below
  below=$(echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for inst in data['fleet']:
    if inst['id'] == 'home':
        for tname, tinfo in inst['tools'].items():
            if tinfo['status'] == 'below_floor':
                print(tname)
                break
")
  [ "$below" = "hledger" ]
}

@test "JSON output shows stale stamp status" {
  run run_fleet_check "json"
  local stale_status
  stale_status=$(echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for inst in data['fleet']:
    if inst['id'] == 'stale-one':
        print(inst['stamp_status'])
        break
")
  [ "$stale_status" = "stale" ]
}

@test "JSON output shows absent stamp status for no-stamp instance" {
  run run_fleet_check "json"
  local absent_status
  absent_status=$(echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for inst in data['fleet']:
    if inst['id'] == 'fresh-install':
        print(inst['stamp_status'])
        break
")
  [ "$absent_status" = "absent" ]
}


# ── Criterion 5: Exit 1 on below-floor violation ───────────────────────────

@test "exit 1 when any instance is below a hard floor" {
  run run_fleet_check "text"
  [ "$status" -eq 1 ]
}

@test "exit 0 when all instances are within floor" {
  # Remove the below-floor instance
  rm "$WW_REGISTRY_DIR/home.json"
  run run_fleet_check "text"
  [ "$status" -eq 0 ]
}

@test "JSON mode exit 1 on violations" {
  run run_fleet_check "json"
  [ "$status" -eq 1 ]
}


# ── Criterion 6: Read-only ─────────────────────────────────────────────────

@test "fleet check does not modify any instance's deps.json" {
  local inst_a="${BATS_TEST_TMPDIR}/instances/factory-a"
  local before_hash
  before_hash="$(md5sum "$inst_a/.state/deps.json" | cut -d' ' -f1)"

  run run_fleet_check "text"

  local after_hash
  after_hash="$(md5sum "$inst_a/.state/deps.json" | cut -d' ' -f1)"
  [ "$before_hash" = "$after_hash" ]
}

@test "fleet check does not create files in instances" {
  local inst_c="${BATS_TEST_TMPDIR}/instances/fresh-install"
  run run_fleet_check "text"
  # fresh-install should still have no .state directory
  [ ! -d "$inst_c/.state" ]
}
