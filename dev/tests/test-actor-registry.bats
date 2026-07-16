#!/usr/bin/env bats
# test-actor-registry.bats — TASK-STRM-002
#
# Tests for lib/actor-registry.sh: the SINGLE owner of the actors.yaml contract.
# Verifies readers, writers, profile overlay resolution, and the one-owner rule invariants.

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  export WW_BASE="${BATS_TEST_DIRNAME}/../.."
  export WORKWARRIOR_BASE
  WORKWARRIOR_BASE="$(mktemp -d)"

  # Create a test actors.yaml (isolated from the real one)
  export TEST_ACTORS_DIR
  TEST_ACTORS_DIR="$(mktemp -d)"
  mkdir -p "${TEST_ACTORS_DIR}/config"

  cat > "${TEST_ACTORS_DIR}/config/actors.yaml" << 'EOF'
schema: v1

actors:
  human:test-user:
    kind: human
    display: "Test User"
    status: active
    source: local
  agent:claude-07:
    kind: agent
    display: "Claude — ledger builder"
    status: active
    source: local
  machine:lathe-01:
    kind: machine
    display: "Haas ST-20"
    status: inactive
    source: local
    installed: 2021-03-14
EOF

  # Override WW_BASE to point to isolated test config
  export WW_BASE="${TEST_ACTORS_DIR}"

  # Source the library (which sources actor.sh from real WW_BASE)
  local real_base="${BATS_TEST_DIRNAME}/../.."
  source "${real_base}/services/stream/lib/actor.sh"
  source "${real_base}/lib/actor-registry.sh"
}

teardown() {
  rm -rf "${WORKWARRIOR_BASE}"
  rm -rf "${TEST_ACTORS_DIR}"
}

# ── Reader: actor_reg_list ────────────────────────────────────────────────────

@test "actor_reg_list returns all actor IDs" {
  run actor_reg_list
  assert_success
  assert_output --partial "human:test-user"
  assert_output --partial "agent:claude-07"
  assert_output --partial "machine:lathe-01"
}

@test "actor_reg_list returns seeded actor from real config" {
  local real_base="${BATS_TEST_DIRNAME}/../.."
  # Skip if real config has no actors seeded yet
  local real_cfg="${real_base}/config/actors.yaml"
  if ! grep -q 'human:morgen' "$real_cfg" 2>/dev/null; then
    skip "real config not seeded with human:morgen yet"
  fi
  WW_BASE="${real_base}" run actor_reg_list
  assert_success
  assert_output --partial "human:morgen"
}

# ── Reader: actor_reg_get ─────────────────────────────────────────────────────

@test "actor_reg_get returns fields as key=value" {
  run actor_reg_get "human:test-user"
  assert_success
  assert_output --partial "kind=human"
  assert_output --partial "display=Test User"
  assert_output --partial "status=active"
  assert_output --partial "source=local"
}

@test "actor_reg_get returns extra fields (unknown fields preserved)" {
  run actor_reg_get "machine:lathe-01"
  assert_success
  assert_output --partial "installed=2021-03-14"
}

@test "actor_reg_get fails for nonexistent actor" {
  run actor_reg_get "human:nobody"
  assert_failure
}

# ── Reader: actor_reg_exists ──────────────────────────────────────────────────

@test "actor_reg_exists returns 0 for existing actor" {
  run actor_reg_exists "human:test-user"
  assert_success
}

@test "actor_reg_exists returns 1 for nonexistent actor" {
  run actor_reg_exists "human:nobody"
  assert_failure
}

# ── Reader: actor_reg_kind / actor_reg_display ────────────────────────────────

@test "actor_reg_kind returns the kind field" {
  run actor_reg_kind "agent:claude-07"
  assert_success
  assert_output "agent"
}

@test "actor_reg_display returns the display name" {
  run actor_reg_display "agent:claude-07"
  assert_success
  assert_output "Claude — ledger builder"
}

# ── Writer: actor_reg_add ─────────────────────────────────────────────────────

@test "actor_reg_add creates a new actor" {
  run actor_reg_add "human:new-op" "New Operator"
  assert_success

  # Verify it exists
  run actor_reg_exists "human:new-op"
  assert_success

  # Verify fields
  run actor_reg_get "human:new-op"
  assert_success
  assert_output --partial "kind=human"
  assert_output --partial "display=New Operator"
  assert_output --partial "status=active"
  assert_output --partial "source=local"
}

@test "actor_reg_add refuses non-local source" {
  run actor_reg_add "human:ext-op" "External Op" "cmms"
  assert_failure
  assert_output --partial "local"
}

@test "actor_reg_add refuses invalid ID" {
  run actor_reg_add "robot:r2" "R2D2"
  assert_failure
  assert_output --partial "invalid"
}

@test "actor_reg_add refuses duplicate actor" {
  run actor_reg_add "human:test-user" "Duplicate"
  assert_failure
  assert_output --partial "already exists"
}

# ── Writer: actor_reg_set_status ──────────────────────────────────────────────

@test "actor_reg_set_status changes status" {
  run actor_reg_set_status "human:test-user" "inactive"
  assert_success

  run actor_reg_get "human:test-user"
  assert_output --partial "status=inactive"
}

@test "actor_reg_set_status refuses invalid status (no delete)" {
  run actor_reg_set_status "human:test-user" "deleted"
  assert_failure
}

# ── Writer: actor_reg_set_field ───────────────────────────────────────────────

@test "actor_reg_set_field sets arbitrary field" {
  run actor_reg_set_field "human:test-user" "belongs_to" "site-a/line-1"
  assert_success

  run actor_reg_get "human:test-user"
  assert_output --partial "belongs_to=site-a/line-1"
}

@test "actor_reg_set_field refuses kind change (immutable)" {
  run actor_reg_set_field "human:test-user" "kind" "agent"
  assert_failure
  assert_output --partial "immutable"
}

# ── Unknown fields preserved on rewrite ───────────────────────────────────────

@test "unknown fields preserved on rewrite" {
  # machine:lathe-01 has 'installed' — set a new field and verify installed survives
  run actor_reg_set_field "machine:lathe-01" "custom_tag" "shop-floor"
  assert_success

  run actor_reg_get "machine:lathe-01"
  assert_success
  assert_output --partial "installed=2021-03-14"
  assert_output --partial "custom_tag=shop-floor"
}

# ── Profile overlay resolution ────────────────────────────────────────────────

@test "actor_reg_members lists active actors when no profile overlay" {
  # No profile overlay exists
  run actor_reg_members
  assert_success
  assert_output --partial "human:test-user"
  assert_output --partial "agent:claude-07"
  # machine:lathe-01 is inactive — should NOT appear
  refute_output --partial "machine:lathe-01"
}

@test "profile overlay: actor_reg_weight returns weight from profile" {
  cat > "${WORKWARRIOR_BASE}/actors.yaml" << 'EOF'
schema: v1

members:
  human:test-user:
    role: operator
    weight: 2.5
  agent:claude-07:
    role: builder
    weight: 0.5
EOF

  run actor_reg_weight "human:test-user"
  assert_success
  assert_output "2.5"

  run actor_reg_weight "agent:claude-07"
  assert_success
  assert_output "0.5"
}

@test "actor_reg_weight defaults to 1.0 without profile overlay" {
  run actor_reg_weight "human:test-user"
  assert_success
  assert_output "1.0"
}

@test "profile overlay: actor_reg_members lists profile members" {
  cat > "${WORKWARRIOR_BASE}/actors.yaml" << 'EOF'
schema: v1

members:
  human:test-user:
    role: operator
    weight: 1.0
EOF

  run actor_reg_members
  assert_success
  assert_output --partial "human:test-user"
  refute_output --partial "agent:claude-07"
}

@test "profile overlay referencing unknown actor returns error" {
  cat > "${WORKWARRIOR_BASE}/actors.yaml" << 'EOF'
schema: v1

members:
  human:unknown-person:
    role: operator
    weight: 1.0
EOF

  run actor_reg_members
  assert_failure
  assert_output --partial "unknown actor"
}

# ── Nano ID generation (id_scheme) ────────────────────────────────────────────

@test "solo mode: actor_reg_add does not append suffix" {
  # Default config has id_scheme: null which defaults to solo
  run actor_reg_add "human:solo-user" "Solo User"
  assert_success
  assert_output "human:solo-user"

  run actor_reg_exists "human:solo-user"
  assert_success
}

@test "team mode: actor_reg_add appends .xxxx suffix" {
  # Set id_scheme to team
  python3 -c "
import yaml
path = '${TEST_ACTORS_DIR}/config/actors.yaml'
with open(path) as f:
    doc = yaml.safe_load(f)
doc['id_scheme'] = 'team'
with open(path, 'w') as f:
    yaml.safe_dump(doc, f, default_flow_style=False, sort_keys=False)
"

  run actor_reg_add "human:marta" "Marta"
  assert_success
  # Output should match human:marta.XXXX (4 base36 chars)
  [[ "$output" =~ ^human:marta\.[a-z0-9]{4}$ ]]
}

@test "enterprise mode: actor_reg_add appends .xxxxxx suffix" {
  # Set id_scheme to enterprise
  python3 -c "
import yaml
path = '${TEST_ACTORS_DIR}/config/actors.yaml'
with open(path) as f:
    doc = yaml.safe_load(f)
doc['id_scheme'] = 'enterprise'
with open(path, 'w') as f:
    yaml.safe_dump(doc, f, default_flow_style=False, sort_keys=False)
"

  run actor_reg_add "agent:planner" "Planner Agent"
  assert_success
  # Output should match agent:planner.XXXXXX (6 base36 chars)
  [[ "$output" =~ ^agent:planner\.[a-z0-9]{6}$ ]]
}

@test "team mode: collision avoidance produces different ID" {
  # Set id_scheme to team
  python3 -c "
import yaml
path = '${TEST_ACTORS_DIR}/config/actors.yaml'
with open(path) as f:
    doc = yaml.safe_load(f)
doc['id_scheme'] = 'team'
with open(path, 'w') as f:
    yaml.safe_dump(doc, f, default_flow_style=False, sort_keys=False)
"

  # Add first actor
  run actor_reg_add "human:collider" "Collider 1"
  assert_success
  local first_id="$output"

  # Add second actor with same slug — must get different nano
  run actor_reg_add "human:collider" "Collider 2"
  assert_success
  local second_id="$output"

  # Both should be valid and different
  [[ "$first_id" =~ ^human:collider\.[a-z0-9]{4}$ ]]
  [[ "$second_id" =~ ^human:collider\.[a-z0-9]{4}$ ]]
  [[ "$first_id" != "$second_id" ]]
}
