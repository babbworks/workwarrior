# lib/actor-registry.sh — single owner of the actors.yaml contract.
#
# Schema:  dev/schemas/actors-v1.md
# Design:  dev/specs/2026-07-12-stream-actor-axis-design.md §3.2
# Task:    TASK-STRM-002
#
# ONE owner — no other code may read or write actors.yaml directly.
# All YAML parsing via python3/yaml.safe_load (consistent with lib/ledger-config.sh,
# lib/instance-registry.sh). Unknown fields PRESERVED on rewrite.
#
# Resolution: profile -> instance for participation fields (role, weight).
# IDENTITY resolves at instance tier only — a profile MUST NOT define an actor
# the instance does not know.
#
# SOURCED library: no `set -euo pipefail`, no `exit`, return codes only.

if [[ -n "${_WW_ACTOR_REGISTRY_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_WW_ACTOR_REGISTRY_LOADED=1

# Source actor.sh for validation
if [[ -z "${_WW_STREAM_ACTOR_LOADED:-}" ]]; then
  source "${WW_BASE:-}/services/stream/lib/actor.sh"
fi

# --------------------------------------------------------------------------
# Internal: config paths
# --------------------------------------------------------------------------
_actor_reg_instance_path() {
  printf '%s\n' "${WW_BASE:-}/config/actors.yaml"
}

_actor_reg_profile_path() {
  printf '%s\n' "${WORKWARRIOR_BASE:-}/actors.yaml"
}

# --------------------------------------------------------------------------
# Internal: python dispatcher
# Exit codes: 0 ok, 1 user/validation error, 2 not found, 3 system error
# --------------------------------------------------------------------------
_actor_reg_py() {
  python3 - "$@" <<'PYEOF'
import sys, os, re

try:
    import yaml
except Exception:
    sys.stderr.write("actor-registry: PyYAML not available\n")
    sys.exit(3)

def die(msg, code=1):
    sys.stderr.write("actor-registry: %s\n" % msg)
    sys.exit(code)

def load_yaml(path):
    try:
        with open(path) as f:
            doc = yaml.safe_load(f)
    except FileNotFoundError:
        return None
    except Exception as e:
        die("parse error: %s" % e, 3)
    if not isinstance(doc, dict):
        doc = {}
    return doc

def load_instance(path):
    doc = load_yaml(path)
    if doc is None:
        die("actors.yaml not found: %s" % path, 2)
    if 'actors' not in doc or not isinstance(doc.get('actors'), dict):
        doc['actors'] = {}
    return doc

def dump_instance(path, doc):
    tmp = path + '.tmp'
    with open(tmp, 'w') as f:
        yaml.safe_dump(doc, f, default_flow_style=False, sort_keys=False)
    os.replace(tmp, path)

def load_profile(path):
    """Load profile overlay; returns None if absent."""
    doc = load_yaml(path)
    if doc is None:
        return None
    if 'members' not in doc or not isinstance(doc.get('members'), dict):
        doc['members'] = {}
    return doc

# --- Commands ---

def cmd_list(ipath):
    doc = load_instance(ipath)
    for aid in doc['actors']:
        print(aid)

def cmd_get(ipath, actor_id):
    doc = load_instance(ipath)
    actor = doc['actors'].get(actor_id)
    if actor is None:
        die("actor not found: %s" % actor_id, 2)
    if isinstance(actor, dict):
        for k, v in actor.items():
            print("%s=%s" % (k, v))

def cmd_exists(ipath, actor_id):
    doc = load_instance(ipath)
    if actor_id in doc['actors']:
        sys.exit(0)
    else:
        sys.exit(1)

def cmd_kind(ipath, actor_id):
    doc = load_instance(ipath)
    actor = doc['actors'].get(actor_id)
    if actor is None:
        die("actor not found: %s" % actor_id, 2)
    print(actor.get('kind', ''))

def cmd_display(ipath, actor_id):
    doc = load_instance(ipath)
    actor = doc['actors'].get(actor_id)
    if actor is None:
        die("actor not found: %s" % actor_id, 2)
    print(actor.get('display', ''))

def cmd_members(ipath, ppath):
    """List actors that participate in a profile.
    If profile overlay exists, return its members (validated against instance).
    Otherwise return all active actors from instance."""
    doc = load_instance(ipath)
    prof = load_profile(ppath)

    if prof is not None:
        # Profile overlay present — validate and list its members
        for mid in prof['members']:
            if mid not in doc['actors']:
                die("profile references unknown actor: %s" % mid, 1)
            print(mid)
    else:
        # No profile overlay — all active instance actors
        for aid, rec in doc['actors'].items():
            if isinstance(rec, dict) and rec.get('status') == 'active':
                print(aid)

def cmd_weight(ipath, ppath, actor_id):
    """Print weight for actor in profile (default 1.0)."""
    doc = load_instance(ipath)
    if actor_id not in doc['actors']:
        die("actor not found: %s" % actor_id, 2)
    prof = load_profile(ppath)
    if prof is not None:
        member = prof['members'].get(actor_id)
        if isinstance(member, dict) and 'weight' in member:
            print(member['weight'])
            return
    print("1.0")

def cmd_add(ipath, actor_id, display, source):
    if source != 'local':
        die("refuses to add actor with source '%s' (only 'local' allowed)" % source, 1)
    doc = load_instance(ipath)
    if actor_id in doc['actors']:
        die("actor already exists: %s" % actor_id, 1)
    # Extract kind from id
    kind = actor_id.split(':')[0]
    doc['actors'][actor_id] = {
        'kind': kind,
        'display': display,
        'status': 'active',
        'source': source,
    }
    dump_instance(ipath, doc)

def cmd_set_status(ipath, actor_id, status):
    if status not in ('active', 'inactive'):
        die("invalid status '%s' (must be active or inactive)" % status, 1)
    doc = load_instance(ipath)
    if actor_id not in doc['actors']:
        die("actor not found: %s" % actor_id, 2)
    doc['actors'][actor_id]['status'] = status
    dump_instance(ipath, doc)

def cmd_set_field(ipath, actor_id, field, value):
    if field == 'kind':
        die("kind is immutable (encoded in actor ID)", 1)
    doc = load_instance(ipath)
    if actor_id not in doc['actors']:
        die("actor not found: %s" % actor_id, 2)
    doc['actors'][actor_id][field] = value
    dump_instance(ipath, doc)

# --- Dispatch ---

def main():
    args = sys.argv[1:]
    if len(args) < 2:
        die("usage: _actor_reg_py <instance_path> <command> [args...]", 1)
    ipath = args[0]
    cmd = args[1]
    rest = args[2:]

    if cmd == 'list':
        cmd_list(ipath)
    elif cmd == 'get':
        if not rest:
            die("get requires actor_id", 1)
        cmd_get(ipath, rest[0])
    elif cmd == 'exists':
        if not rest:
            die("exists requires actor_id", 1)
        cmd_exists(ipath, rest[0])
    elif cmd == 'kind':
        if not rest:
            die("kind requires actor_id", 1)
        cmd_kind(ipath, rest[0])
    elif cmd == 'display':
        if not rest:
            die("display requires actor_id", 1)
        cmd_display(ipath, rest[0])
    elif cmd == 'members':
        ppath = rest[0] if rest else ''
        cmd_members(ipath, ppath)
    elif cmd == 'weight':
        if not rest:
            die("weight requires actor_id", 1)
        ppath = rest[1] if len(rest) > 1 else ''
        cmd_weight(ipath, ppath, rest[0])
    elif cmd == 'add':
        if len(rest) < 2:
            die("add requires actor_id and display", 1)
        source = rest[2] if len(rest) > 2 else 'local'
        cmd_add(ipath, rest[0], rest[1], source)
    elif cmd == 'set_status':
        if len(rest) < 2:
            die("set_status requires actor_id and status", 1)
        cmd_set_status(ipath, rest[0], rest[1])
    elif cmd == 'set_field':
        if len(rest) < 3:
            die("set_field requires actor_id, field, and value", 1)
        cmd_set_field(ipath, rest[0], rest[1], rest[2])
    else:
        die("unknown command: %s" % cmd, 1)

main()
PYEOF
}

# --------------------------------------------------------------------------
# Public API — Readers
# --------------------------------------------------------------------------

# actor_reg_list — list all actor IDs (one per line)
actor_reg_list() {
  _actor_reg_py "$(_actor_reg_instance_path)" list
}

# actor_reg_get <id> — print all fields as key=value lines
actor_reg_get() {
  local id="${1:-}"
  [[ -n "$id" ]] || { echo "actor_reg_get: id required" >&2; return 1; }
  _actor_reg_py "$(_actor_reg_instance_path)" get "$id"
}

# actor_reg_exists <id> — return 0 if exists, 1 if not
actor_reg_exists() {
  local id="${1:-}"
  [[ -n "$id" ]] || return 1
  _actor_reg_py "$(_actor_reg_instance_path)" exists "$id"
}

# actor_reg_kind <id> — print the kind field
actor_reg_kind() {
  local id="${1:-}"
  [[ -n "$id" ]] || { echo "actor_reg_kind: id required" >&2; return 1; }
  _actor_reg_py "$(_actor_reg_instance_path)" kind "$id"
}

# actor_reg_display <id> — print the display name
actor_reg_display() {
  local id="${1:-}"
  [[ -n "$id" ]] || { echo "actor_reg_display: id required" >&2; return 1; }
  _actor_reg_py "$(_actor_reg_instance_path)" display "$id"
}

# actor_reg_members [profile] — list actors that participate in a profile
# With no args: uses WORKWARRIOR_BASE profile overlay
actor_reg_members() {
  local ppath
  ppath="$(_actor_reg_profile_path)"
  _actor_reg_py "$(_actor_reg_instance_path)" members "$ppath"
}

# actor_reg_weight <id> [profile] — print weight for actor in profile (default 1.0)
actor_reg_weight() {
  local id="${1:-}"
  local ppath
  [[ -n "$id" ]] || { echo "actor_reg_weight: id required" >&2; return 1; }
  ppath="$(_actor_reg_profile_path)"
  _actor_reg_py "$(_actor_reg_instance_path)" weight "$id" "$ppath"
}

# --------------------------------------------------------------------------
# Public API — Writers
# --------------------------------------------------------------------------

# _actor_reg_id_scheme — read id_scheme from config/actors.yaml (solo|team|enterprise)
# Returns "solo" if null/missing (default for uninitialized instances).
_actor_reg_id_scheme() {
  local cfg
  cfg="$(_actor_reg_instance_path)"
  python3 -c "
import yaml, sys
try:
    with open('$cfg') as f:
        doc = yaml.safe_load(f) or {}
except Exception:
    doc = {}
scheme = doc.get('id_scheme')
if scheme in ('solo', 'team', 'enterprise'):
    print(scheme)
else:
    print('solo')
"
}

# _actor_reg_gen_nano <length> — generate a base36 nano suffix (a-z0-9)
_actor_reg_gen_nano() {
  local len="${1:-4}"
  python3 -c "
import random, string
print(''.join(random.choices(string.ascii_lowercase + string.digits, k=$len)))
"
}

# actor_reg_add <id> <display> [source] — add new actor
# Validates ID via actor_validate. REFUSES if source != 'local'.
# If id_scheme is team or enterprise, appends a nano suffix to the slug portion.
# The <id> argument is the BASE id (kind:slug) — suffix is auto-appended.
actor_reg_add() {
  local id="${1:-}"
  local display="${2:-}"
  local source="${3:-local}"

  [[ -n "$id" ]] || { echo "actor_reg_add: id required" >&2; return 1; }
  [[ -n "$display" ]] || { echo "actor_reg_add: display required" >&2; return 1; }

  # Source must be local
  if [[ "$source" != "local" ]]; then
    echo "actor_reg_add: refuses source '$source' (only 'local' allowed)" >&2
    return 1
  fi

  # Determine id_scheme and append nano suffix if needed
  local scheme
  scheme="$(_actor_reg_id_scheme)"

  local final_id="$id"
  case "$scheme" in
    team)
      local nano attempts=0
      while true; do
        nano="$(_actor_reg_gen_nano 4)"
        final_id="${id}.${nano}"
        # Validate before collision check
        if ! actor_validate "$final_id"; then
          echo "actor_reg_add: invalid actor id '$final_id'" >&2
          return 1
        fi
        # Collision check
        if ! actor_reg_exists "$final_id" 2>/dev/null; then
          break
        fi
        attempts=$((attempts + 1))
        if [[ $attempts -ge 100 ]]; then
          echo "actor_reg_add: failed to generate unique nano after 100 attempts" >&2
          return 1
        fi
      done
      ;;
    enterprise)
      local nano attempts=0
      while true; do
        nano="$(_actor_reg_gen_nano 6)"
        final_id="${id}.${nano}"
        # Validate before collision check
        if ! actor_validate "$final_id"; then
          echo "actor_reg_add: invalid actor id '$final_id'" >&2
          return 1
        fi
        # Collision check
        if ! actor_reg_exists "$final_id" 2>/dev/null; then
          break
        fi
        attempts=$((attempts + 1))
        if [[ $attempts -ge 100 ]]; then
          echo "actor_reg_add: failed to generate unique nano after 100 attempts" >&2
          return 1
        fi
      done
      ;;
    *)
      # solo: no suffix
      if ! actor_validate "$final_id"; then
        echo "actor_reg_add: invalid actor id '$final_id'" >&2
        return 1
      fi
      ;;
  esac

  _actor_reg_py "$(_actor_reg_instance_path)" add "$final_id" "$display" "$source" || return $?
  # Print the final ID so caller knows what was assigned
  printf '%s\n' "$final_id"
}

# actor_reg_set_status <id> <active|inactive> — change status. NO DELETE.
actor_reg_set_status() {
  local id="${1:-}"
  local status="${2:-}"

  [[ -n "$id" ]] || { echo "actor_reg_set_status: id required" >&2; return 1; }
  [[ -n "$status" ]] || { echo "actor_reg_set_status: status required" >&2; return 1; }

  if [[ "$status" != "active" && "$status" != "inactive" ]]; then
    echo "actor_reg_set_status: invalid status '$status' (must be active or inactive)" >&2
    return 1
  fi

  _actor_reg_py "$(_actor_reg_instance_path)" set_status "$id" "$status"
}

# actor_reg_set_field <id> <field> <value> — set arbitrary field. Refuses 'kind' (immutable).
actor_reg_set_field() {
  local id="${1:-}"
  local field="${2:-}"
  local value="${3:-}"

  [[ -n "$id" ]] || { echo "actor_reg_set_field: id required" >&2; return 1; }
  [[ -n "$field" ]] || { echo "actor_reg_set_field: field required" >&2; return 1; }

  if [[ "$field" == "kind" ]]; then
    echo "actor_reg_set_field: kind is immutable (encoded in actor ID)" >&2
    return 1
  fi

  _actor_reg_py "$(_actor_reg_instance_path)" set_field "$id" "$field" "$value"
}
