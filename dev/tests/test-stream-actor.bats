#!/usr/bin/env bats
# test-stream-actor.bats — TASK-STRM-001
#
# v0 of the stream event had NO ACTOR. `object` records what was acted UPON; nothing recorded
# WHO acted. v1 adds `ctx.actor`, so identity and object become a PAIR: operator 3 ON lathe-01.
#
# THE v0 FALLBACK IS REQUIRED, NOT OPTIONAL. Historical events have no actor key and MUST NOT be
# rewritten — the log is append-only. A consumer that reads ctx.actor directly, instead of going
# through actor_resolve(), silently drops attribution for ALL of history.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  source "${REPO_ROOT}/services/stream/lib/actor.sh"
}

# ── resolution, and the required fallback ────────────────────────────────────

@test "a v1 event resolves to its declared actor" {
  run actor_resolve '{"actor":"human:op-03","proj":"line-a"}'
  [ "$output" = "human:op-03" ]
}

@test "FALLBACK: a v0 event (no actor key) attributes to its PROFILE" {
  # The honest answer: we know the context, not the individual.
  run actor_resolve '{"prof":"work","proj":"line-a"}'
  [ "$output" = "profile:work" ]
}

@test "FALLBACK: a v0 event with no profile either still resolves — never empty" {
  run actor_resolve '{}'
  [ "$output" = "profile:default" ]
}

@test "FALLBACK: malformed ctx does not kill the caller (a lens must not die on one bad line)" {
  run actor_resolve 'not json at all'
  [ "$status" -eq 0 ]
  [ "$output" = "profile:default" ]
}

@test "FALLBACK: empty ctx resolves" {
  run actor_resolve ''
  [ "$output" = "profile:default" ]
}

@test "actor_resolve NEVER returns empty" {
  local ctx
  for ctx in '{"actor":"agent:c-1"}' '{"prof":"x"}' '{}' 'garbage' ''; do
    run actor_resolve "$ctx"
    [ -n "$output" ]
  done
}

# ── validation: <kind>:<local-id> ────────────────────────────────────────────

@test "valid actor ids are accepted" {
  local id
  for id in human:op-03 agent:claude-07 machine:lathe-01 human:a agent:x_1; do
    run actor_validate "$id"
    [ "$status" -eq 0 ]
  done
}

@test "an unknown kind is rejected (actors punch; objects get punched onto)" {
  run actor_validate "robot:r2"
  [ "$status" -ne 0 ]
}

@test "a bare id with no kind is rejected" {
  run actor_validate "op-03"
  [ "$status" -ne 0 ]
}

@test "uppercase and spaces are rejected" {
  run actor_validate "human:Op 03"
  [ "$status" -ne 0 ]
  run actor_validate "human:OP03"
  [ "$status" -ne 0 ]
}

@test "an empty id is rejected" {
  run actor_validate ""
  [ "$status" -ne 0 ]
}

@test "the v0 fallback attribution is NOT a valid actor id" {
  # `profile:work` is a resolved ATTRIBUTION, not a registered actor. Anything that WRITES an
  # actor must write a real one — otherwise the fallback would quietly become a legitimate
  # identity and history would be indistinguishable from the present.
  run actor_validate "profile:work"
  [ "$status" -ne 0 ]
  run actor_is_fallback "profile:work"
  [ "$status" -eq 0 ]
  run actor_is_fallback "human:op-03"
  [ "$status" -ne 0 ]
}

# ── decomposition ────────────────────────────────────────────────────────────

@test "actor_kind and actor_local split the id" {
  run actor_kind "machine:lathe-01"
  [ "$output" = "machine" ]
  run actor_local "machine:lathe-01"
  [ "$output" = "lathe-01" ]
}

@test "actor_kind fails on a malformed id rather than guessing" {
  run actor_kind "nonsense"
  [ "$status" -ne 0 ]
}
