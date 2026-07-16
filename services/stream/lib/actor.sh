#!/usr/bin/env bash
# services/stream/lib/actor.sh — the SINGLE owner of actor identity resolution.
#
# Contract: dev/schemas/stream-event-v1.md §4
# Design:   dev/specs/2026-07-12-stream-actor-axis-design.md
#
# WHY THIS EXISTS. v0 of the stream event had no ACTOR. The `object` field records what was
# acted UPON; nothing recorded WHO acted. So the log could not answer "what did operator 3 do
# today" or "which agent is running right now", and identity had to be smuggled into object
# names by convention — conflating the actor with the thing they acted on.
#
# v1 adds `ctx.actor`. Identity and object become a PAIR: operator 3 ON lathe-01; agent
# claude-07 ON the ledger refactor.
#
# THE FALLBACK IS REQUIRED, NOT OPTIONAL. v0 events have no actor key and MUST NOT be
# rewritten — the log is append-only. Every consumer that reads an actor resolves it through
# actor_resolve(), which attributes a historical event to the profile that recorded it. That is
# the honest answer: we know the context, not the individual. A consumer that skips this and
# reads ctx.actor directly will silently drop attribution for all of history.
#
# SOURCED library: no `set -euo pipefail`, no `exit`, return codes only.

if [[ -n "${_WW_STREAM_ACTOR_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_WW_STREAM_ACTOR_LOADED=1

# The kinds. Actors PUNCH; objects get punched ONTO. A machine an operator works is an OBJECT;
# a machine running unattended is an ACTOR. Both are legitimate, in different events.
ACTOR_KINDS="human agent machine"

# actor_resolve <ctx_json> -> actor id
#
# Applies the REQUIRED v0 fallback. Never returns empty for well-formed ctx.
#   {"actor":"human:op-03",...}  -> human:op-03
#   {"prof":"work",...}          -> profile:work      (v0 event — attributed to its context)
#   {}                           -> profile:default
#   (malformed json)             -> profile:default   (never fatal: a lens must not die on one bad line)
actor_resolve() {
  local ctx="${1:-}"
  [[ -n "$ctx" ]] || { printf 'profile:default\n'; return 0; }
  printf '%s' "$ctx" | python3 -c "
import sys, json
try:
    c = json.loads(sys.stdin.read() or '{}')
    if not isinstance(c, dict):
        c = {}
except Exception:
    c = {}
a = c.get('actor')
if a:
    print(a)
else:
    print('profile:' + (c.get('prof') or 'default'))
" 2>/dev/null || printf 'profile:default\n'
}

# actor_validate <id> -> 0 valid, 1 invalid
#
# <kind>:<local-id>, kind in human|agent|machine, local-id [a-z0-9][a-z0-9_-]*
# NOTE the `profile:` prefix produced by the v0 fallback is deliberately NOT valid here: it is
# a resolved ATTRIBUTION, not a registered actor. Anything that writes an actor must write a
# real one.
actor_validate() {
  local id="${1:-}"
  [[ "$id" =~ ^(human|agent|machine):[a-z0-9][a-z0-9_.-]*$ ]]
}

# actor_kind <id> -> human|agent|machine   (or `profile` for a v0 fallback attribution)
actor_kind() {
  local id="${1:-}"
  [[ -n "$id" && "$id" == *:* ]] || return 1
  printf '%s\n' "${id%%:*}"
}

# actor_local <id> -> the part after the kind
actor_local() {
  local id="${1:-}"
  [[ -n "$id" && "$id" == *:* ]] || return 1
  printf '%s\n' "${id#*:}"
}

# Is this a v0 fallback attribution rather than a real registered actor?
actor_is_fallback() {
  [[ "${1:-}" == profile:* ]]
}
