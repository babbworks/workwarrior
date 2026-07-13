#!/usr/bin/env bash
# lib/ledger-config.sh — single owner of the ledgers.yaml contract.
#
# Schema: jrnl-style hybrid (see logs/decisions.md 2026-07-11).
#   ledgers:
#     default: /abs/path/to.journal        # string form
#     business:                            # map form (only when metadata present)
#       journal: /abs/path/to.journal
#       commodity: USD
#       hidden: false
#
# Entry value is EITHER a string (absolute path) OR a map with the path under
# `journal:`. `default` is a reserved key resolved by name, never by position.
# The legacy nested `path:` key is READ (with a deprecation warning) but NEVER
# written. YAML parsing is delegated to Python/yaml.safe_load — line-oriented
# shell parsers cannot survive the string-or-map ambiguity.
#
# SOURCED library: no `set -euo pipefail`, no `exit`, return codes only.
# Blessed map fields (v1): journal (required in map form), commodity, hidden.
# Reserved-but-inert: role (standalone|include), description.

# --------------------------------------------------------------------------
# Internal: python dispatcher. argv = <cfg_path> <op> [args...].
# Exit codes: 0 ok, 1 user/validation error, 2 not found, 3 system error.
# --------------------------------------------------------------------------
_ledger_cfg_py() {
  python3 - "$@" <<'PYEOF'
import sys, os, re

try:
    import yaml
except Exception:
    sys.stderr.write("ledger-config: PyYAML not available\n")
    sys.exit(3)

NAME_RE = re.compile(r'^[a-zA-Z0-9_-]+$')
BLESSED = ('journal', 'commodity', 'hidden', 'role', 'description')

def die(msg, code):
    sys.stderr.write("ledger-config: %s\n" % msg)
    sys.exit(code)

def load(path):
    try:
        with open(path) as f:
            doc = yaml.safe_load(f)
    except FileNotFoundError:
        die("ledgers.yaml not found: %s" % path, 2)
    except Exception as e:
        die("parse error: %s" % e, 3)
    if not isinstance(doc, dict):
        doc = {}
    led = doc.get('ledgers')
    if not isinstance(led, dict):
        doc['ledgers'] = {}
    return doc

def dump(path, doc):
    tmp = path + '.tmp'
    with open(tmp, 'w') as f:
        yaml.safe_dump(doc, f, default_flow_style=False, sort_keys=False)
    os.replace(tmp, path)

def entry_path(entry, warn_name=None):
    if isinstance(entry, str):
        return entry
    if isinstance(entry, dict):
        if 'journal' in entry:
            return entry['journal']
        if 'path' in entry:
            if warn_name is not None:
                sys.stderr.write(
                    "ledger-config: ledger '%s' uses legacy 'path:' key; "
                    "'journal:' is canonical (deprecated)\n" % warn_name)
            return entry['path']
    return None

def to_bool(v):
    s = str(v).strip().lower()
    if s in ('true', '1', 'yes'):
        return True
    if s in ('false', '0', 'no'):
        return False
    return None

def convert_field(field, value):
    if field == 'hidden':
        b = to_bool(value)
        if b is None:
            die("field 'hidden' must be boolean (true/false)", 1)
        return b
    if field == 'role' and value not in ('standalone', 'include'):
        die("field 'role' must be one of: standalone, include", 1)
    return value

path = sys.argv[1]
op = sys.argv[2]
args = sys.argv[3:]

if op == 'names':
    inc = bool(args) and args[0] == '1'
    for name, entry in load(path)['ledgers'].items():
        if name == 'default':
            continue
        hidden = isinstance(entry, dict) and bool(entry.get('hidden', False))
        if hidden and not inc:
            continue
        print(name)
    sys.exit(0)

if op == 'resolve':
    name = args[0]
    led = load(path)['ledgers']
    if name not in led:
        sys.exit(2)
    p = entry_path(led[name], warn_name=name)
    if not p:
        die("ledger '%s' has no path" % name, 2)
    print(p)
    sys.exit(0)

if op == 'get_field':
    name, field = args[0], args[1]
    entry = load(path)['ledgers'].get(name)
    if isinstance(entry, dict) and field in entry:
        v = entry[field]
        if v is True:
            print('true')
        elif v is False:
            print('false')
        elif v is not None:
            print(v)
    sys.exit(0)

if op == 'exists':
    sys.exit(0 if args[0] in load(path)['ledgers'] else 1)

if op == 'add':
    name, ppath = args[0], args[1]
    if name == 'default' or not NAME_RE.match(name):
        die("invalid ledger name: '%s'" % name, 1)
    doc = load(path)
    led = doc['ledgers']
    if name in led:
        die("ledger '%s' already exists" % name, 1)
    meta = {}
    for kv in args[2:]:
        k, _, v = kv.partition('=')
        if k not in BLESSED or k == 'journal':
            die("unknown metadata field: '%s'" % k, 1)
        meta[k] = convert_field(k, v)
    led[name] = {'journal': ppath, **meta} if meta else ppath
    dump(path, doc)
    sys.exit(0)

if op == 'remove':
    name = args[0]
    if name == 'default':
        die("cannot remove reserved ledger key 'default'", 1)
    doc = load(path)
    led = doc['ledgers']
    if name not in led:
        sys.exit(2)
    if 'default' in led and entry_path(led[name]) == entry_path(led['default']):
        die("cannot remove the current default ledger", 1)
    del led[name]
    dump(path, doc)
    sys.exit(0)

if op == 'rename':
    old, new = args[0], args[1]
    if old == 'default' or new == 'default':
        die("cannot rename to or from reserved key 'default'", 1)
    if not NAME_RE.match(new):
        die("invalid ledger name: '%s'" % new, 1)
    doc = load(path)
    led = doc['ledgers']
    if old not in led:
        sys.exit(2)
    if new in led:
        die("ledger '%s' already exists" % new, 1)
    # Rebuild preserving order; default (a stored path) is unaffected by a key rename.
    doc['ledgers'] = {(new if k == old else k): v for k, v in led.items()}
    dump(path, doc)
    sys.exit(0)

if op == 'set_default':
    name = args[0]
    doc = load(path)
    led = doc['ledgers']
    if name not in led:
        sys.exit(2)
    p = entry_path(led[name], warn_name=name)
    if not p:
        die("ledger '%s' has no path" % name, 2)
    led['default'] = p
    dump(path, doc)
    sys.exit(0)

if op == 'set_field':
    name, field, value = args[0], args[1], args[2]
    if field not in BLESSED:
        die("unknown metadata field: '%s'" % field, 1)
    doc = load(path)
    led = doc['ledgers']
    if name not in led:
        sys.exit(2)
    entry = led[name]
    if isinstance(entry, str):
        entry = {'journal': entry}      # upgrade string -> map
    elif isinstance(entry, dict) and 'journal' not in entry and 'path' in entry:
        entry = {'journal': entry.pop('path'), **entry}  # migrate legacy on write
    entry[field] = convert_field(field, value)
    led[name] = entry
    dump(path, doc)
    sys.exit(0)

die("unknown operation: '%s'" % op, 3)
PYEOF
}

# PyYAML availability is enforced inside _ledger_cfg_py itself (it exits 3 with a
# clear message on ImportError). Keeping this a cheap no-op means each public call
# fires a single python3, not two — the named-ledger resolve is one round-trip.
_ledger_cfg_guard() { return 0; }

# --------------------------------------------------------------------------
# Public readers
# --------------------------------------------------------------------------
ledger_cfg_path() {
  printf '%s\n' "${WORKWARRIOR_BASE:-}/ledgers.yaml"
}

ledger_cfg_names() {
  _ledger_cfg_guard || return 2
  local inc=0
  [[ "${1:-}" == "--include-hidden" ]] && inc=1
  _ledger_cfg_py "$(ledger_cfg_path)" names "$inc"
}

ledger_cfg_resolve() {
  _ledger_cfg_guard || return 2
  _ledger_cfg_py "$(ledger_cfg_path)" resolve "${1:-}"
}

ledger_cfg_default_path() {
  ledger_cfg_resolve default
}

ledger_cfg_get_field() {
  _ledger_cfg_guard || return 2
  _ledger_cfg_py "$(ledger_cfg_path)" get_field "${1:-}" "${2:-}"
}

ledger_cfg_exists() {
  _ledger_cfg_guard || return 2
  _ledger_cfg_py "$(ledger_cfg_path)" exists "${1:-}"
}

# --------------------------------------------------------------------------
# Public writers (atomic tmp+mv via the python dispatcher)
# --------------------------------------------------------------------------
ledger_cfg_add() {
  _ledger_cfg_guard || return 2
  local name="${1:-}" path="${2:-}"
  shift 2 2>/dev/null || true
  local meta=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --commodity) meta+=("commodity=${2:-}"); shift 2 ;;
      --hidden)    meta+=("hidden=true");      shift ;;
      --role)      meta+=("role=${2:-}");      shift 2 ;;
      --desc)      meta+=("description=${2:-}"); shift 2 ;;
      *) shift ;;
    esac
  done
  _ledger_cfg_py "$(ledger_cfg_path)" add "$name" "$path" "${meta[@]}"
}

ledger_cfg_remove() {
  _ledger_cfg_guard || return 2
  _ledger_cfg_py "$(ledger_cfg_path)" remove "${1:-}"
}

ledger_cfg_rename() {
  _ledger_cfg_guard || return 2
  _ledger_cfg_py "$(ledger_cfg_path)" rename "${1:-}" "${2:-}"
}

ledger_cfg_set_default() {
  _ledger_cfg_guard || return 2
  _ledger_cfg_py "$(ledger_cfg_path)" set_default "${1:-}"
}

ledger_cfg_set_field() {
  _ledger_cfg_guard || return 2
  _ledger_cfg_py "$(ledger_cfg_path)" set_field "${1:-}" "${2:-}" "${3:-}"
}
