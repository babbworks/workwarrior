#!/usr/bin/env bash
# lib/unit-registry.sh — the SINGLE owner of config/units.yaml.
#
# No other code path may parse that file. This is the rule the ledgers.yaml audit produced
# (decisions.md 2026-07-11): five independent parsers for one file gave us a schema forked
# three ways. Do not repeat it.
#
# Contract: dev/schemas/units-v1.md
#
# TWO INVARIANTS THIS MODULE ENFORCES, AND WHY THEY MATTER:
#
#   1. AN EQUIVALENCE IS SAME-DIMENSION. `1 kWh = 1000 Wh` is a CONVERSION: always true,
#      everywhere, for everyone. "An hour is worth 50 USD" is a PRICE: contingent,
#      contextual, different per person and per time. The registry says what a unit IS;
#      a MODE says what it is WORTH. A cross-dimension equivalence is REJECTED, so the
#      boundary cannot be crossed by accident — which is what would collapse the verified
#      "personal and production are one engine with two price tables" result.
#
#   2. AUTHORITATIVE, WITH A LOUD UNKNOWN (decisions.md 2026-07-13). An unregistered unit
#      is REPORTED, never silently coerced and never silently dropped. The log is truth;
#      the registry is a lookup table. An unknown unit is a REGISTRY problem, not a data
#      problem.
#
# SOURCED library: no `set -euo pipefail`, no `exit`, return codes only.

if [[ -n "${_WW_UNIT_REGISTRY_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_WW_UNIT_REGISTRY_LOADED=1

unit_reg_path() {
  local base="${WW_BASE:-${WORKWARRIOR_BASE:-}}"
  local candidates=(
    "${WW_UNITS_FILE:-}"
    "${base}/config/units.yaml"
    "$(dirname "${BASH_SOURCE[0]}")/../config/units.yaml"
  )
  local c
  for c in "${candidates[@]}"; do
    [[ -n "$c" && -f "$c" ]] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

# A malformed registry is FATAL, never a silent default. Guessing what a quantity means is
# how you end up adding kilograms to hours.
_unit_query() {
  local expr="$1" path
  path="$(unit_reg_path)" || {
    echo "units: config/units.yaml not found" >&2
    return 2
  }
  python3 -c "
import sys, yaml
try:
    with open('$path') as f:
        m = yaml.safe_load(f) or {}
except Exception as e:
    sys.stderr.write('units: malformed registry: %s\n' % e)
    sys.exit(2)
u = m.get('units')
if not isinstance(u, dict):
    sys.stderr.write('units: registry has no units: map\n')
    sys.exit(2)
try:
    v = $expr
except Exception:
    sys.exit(1)
if v is None:
    sys.exit(1)
print(v)
" 2>&1
}

# ── reads ────────────────────────────────────────────────────────────────────

unit_reg_list()      { _unit_query "'\n'.join(u.keys())"; }
unit_reg_exists()    { _unit_query "'${1}' if '${1}' in u else None" >/dev/null 2>&1; }
unit_reg_display()   { _unit_query "u['${1}'].get('display','${1}')"; }
unit_reg_dimension() { _unit_query "u['${1}']['dimension']"; }
unit_reg_precision() { _unit_query "u['${1}'].get('precision',2)"; }

# The hledger commodity string. THIS is the boundary: `unit` is what the thing is,
# `symbol` is what hledger calls it. Everything downstream of the ledger uses the symbol.
unit_reg_symbol()    { _unit_query "u['${1}'].get('symbol','${1}')"; }

# Resolve a hledger symbol back to a unit id. Empty (rc 1) if unregistered.
unit_reg_by_symbol() {
  _unit_query "next((k for k, v in u.items() if v.get('symbol', k) == '${1}'), None)"
}

# "<to> <factor>" per line.
unit_reg_equivalences() {
  _unit_query "'\n'.join('%s %s' % (e['to'], e['factor']) for e in (u['${1}'].get('equivalences') or []))"
}

# Return the base unit id for a dimension. Exactly one unit per dimension must have base: true.
unit_reg_dimension_base() {
  local dim="${1:-}"
  [[ -n "$dim" ]] || return 1
  _unit_query "next((k for k, v in u.items() if v.get('dimension') == '${dim}' and v.get('base') is True), None)"
}

# ── the loud unknown (invariant 2) ───────────────────────────────────────────
#
# Is this hledger symbol something we know about? Callers MUST NOT coerce or drop on a
# `no` — they must record the value and report the symbol.
unit_reg_symbol_known() {
  local sym="${1:-}"
  [[ -n "$sym" ]] || return 1
  unit_reg_by_symbol "$sym" >/dev/null 2>&1
}

# Given symbols on stdin (one per line), print the ones the registry has never seen.
# This is the report — not a filter. Nothing is dropped.
unit_reg_unregistered() {
  local sym
  while IFS= read -r sym; do
    [[ -n "$sym" ]] || continue
    unit_reg_symbol_known "$sym" || printf '%s\n' "$sym"
  done
}

# ── validation (invariant 1) ─────────────────────────────────────────────────
#
# Returns 0 if the registry is coherent; prints every problem and returns 1 if not.
unit_reg_validate() {
  local path
  path="$(unit_reg_path)" || { echo "units: config/units.yaml not found" >&2; return 2; }
  python3 -c "
import sys, yaml
from collections import defaultdict, deque
try:
    with open('$path') as f:
        m = yaml.safe_load(f) or {}
except Exception as e:
    print('units: malformed registry: %s' % e); sys.exit(2)

u = m.get('units')
if not isinstance(u, dict):
    print('units: registry has no units: map'); sys.exit(2)

problems = []

# ── per-unit checks ──────────────────────────────────────────────────────────
for uid, spec in u.items():
    if not isinstance(spec, dict):
        problems.append('%s: not a map' % uid); continue
    if 'dimension' not in spec:
        problems.append('%s: missing required field: dimension' % uid)
    dim = spec.get('dimension')

    for e in (spec.get('equivalences') or []):
        to, factor = e.get('to'), e.get('factor')
        if to is None or factor is None:
            problems.append('%s: equivalence needs both to: and factor:' % uid); continue
        if to == uid:
            problems.append('%s: equivalence to itself' % uid); continue
        if to not in u:
            problems.append('%s: equivalence targets unknown unit %r' % (uid, to)); continue
        # THE INVARIANT. An equivalence is a CONVERSION (same dimension, always true).
        # A cross-dimension relation is a PRICE (what a thing is WORTH) and belongs to a
        # mode, not here. Rejecting it is what keeps the registry from becoming a
        # valuation table.
        tdim = u[to].get('dimension')
        if dim != tdim:
            problems.append(
                '%s (%s) -> %s (%s): CROSS-DIMENSION equivalence. An equivalence is a '
                'CONVERSION, always true. A cross-dimension relation is a PRICE — what a '
                'thing is WORTH — and belongs to a mode, not the unit registry.'
                % (uid, dim, to, tdim))
        try:
            if float(factor) <= 0:
                problems.append('%s: equivalence factor must be > 0' % uid)
        except (TypeError, ValueError):
            problems.append('%s: equivalence factor is not a number: %r' % (uid, factor))

# ── R1: exactly one base per dimension ───────────────────────────────────────
dims = defaultdict(list)
for uid, spec in u.items():
    if not isinstance(spec, dict):
        continue
    dim = spec.get('dimension')
    if dim:
        dims[dim].append(uid)

bases = defaultdict(list)
for uid, spec in u.items():
    if not isinstance(spec, dict):
        continue
    if spec.get('base') is True:
        dim = spec.get('dimension')
        if dim:
            bases[dim].append(uid)

for dim, units in dims.items():
    base_list = bases.get(dim, [])
    if len(base_list) == 0:
        problems.append('dimension %r: no base unit declared (exactly one unit needs base: true)' % dim)
    elif len(base_list) > 1:
        problems.append('dimension %r: multiple base units: %s (exactly one allowed)' % (dim, ', '.join(base_list)))

# ── R3: connectivity — every unit must be reachable from the base ────────────
# Build undirected adjacency from equivalences (a conversion is bidirectional).
for dim, units in dims.items():
    base_list = bases.get(dim, [])
    if len(base_list) != 1:
        continue  # can't check connectivity without exactly one base
    base_id = base_list[0]
    dim_units = [uid for uid in u if isinstance(u[uid], dict) and u[uid].get('dimension') == dim]
    if len(dim_units) <= 1:
        continue  # singleton dimension — nothing to connect

    # Build adjacency graph (undirected: if A->B exists, B can reach A and vice versa)
    adj = defaultdict(set)
    for uid in dim_units:
        spec = u[uid]
        for e in (spec.get('equivalences') or []):
            to = e.get('to')
            if to and to in u and isinstance(u[to], dict) and u[to].get('dimension') == dim:
                adj[uid].add(to)
                adj[to].add(uid)

    # BFS from base
    visited = set()
    queue = deque([base_id])
    visited.add(base_id)
    while queue:
        node = queue.popleft()
        for neighbor in adj.get(node, []):
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)

    # Any unit not reached is an island
    for uid in dim_units:
        if uid not in visited:
            problems.append(
                '%s: ISLAND in dimension %r — no conversion path to base unit %r. '
                'Every unit must be reachable from the dimension base, or quantities cannot be compared.'
                % (uid, dim, base_id))

for p in problems:
    print('  %s' % p)
sys.exit(1 if problems else 0)
"
}

# ── hledger price directives (criterion 4) ───────────────────────────────────
#
# VERIFIED MECHANISM (dev/reports/ledger-hledger/, Test 2): `P DATE kWh 1000 Wh` plus
# `-X Wh` converts 3 kWh -> 3000 Wh. hledger's price engine IS a unit-conversion algebra —
# which is precisely why ledger-cli's `C` directive is not needed and ledger-cli is not
# needed at all.
#
#   unit_reg_price_directives [date]   ->   P <date> <symbol> <factor> <to-symbol>
unit_reg_price_directives() {
  local date="${1:-$(date +%Y-%m-%d)}" path
  path="$(unit_reg_path)" || return 2
  python3 -c "
import sys, yaml
with open('$path') as f:
    m = yaml.safe_load(f) or {}
u = m.get('units') or {}
for uid, spec in u.items():
    sym = spec.get('symbol', uid)
    for e in (spec.get('equivalences') or []):
        to = e['to']
        tsym = u.get(to, {}).get('symbol', to)
        print('P $date %s %s %s' % (sym, e['factor'], tsym))
" 2>/dev/null
}

# ── write path (R4) ─────────────────────────────────────────────────────────
#
# unit_reg_add <id> <display> <dimension> <symbol> <precision> [equivalences]
#   equivalences: comma-separated "to:factor" pairs, e.g. "Wh:1000,MWh:0.001"
#   Returns 0 on success, 1 on validation failure (reverted), 2 on I/O error.
unit_reg_add() {
  local id="${1:-}" display="${2:-}" dimension="${3:-}" symbol="${4:-}" precision="${5:-2}" equivalences="${6:-}"
  [[ -n "$id" ]] || { echo "unit_reg_add: id required" >&2; return 1; }
  [[ -n "$display" ]] || { echo "unit_reg_add: display required" >&2; return 1; }
  [[ -n "$dimension" ]] || { echo "unit_reg_add: dimension required" >&2; return 1; }
  [[ -n "$symbol" ]] || symbol="$id"

  local path
  path="$(unit_reg_path)" || { echo "unit_reg_add: config/units.yaml not found" >&2; return 2; }

  # Check if unit already exists
  if unit_reg_exists "$id"; then
    echo "unit_reg_add: unit '$id' already exists" >&2
    return 1
  fi

  # Back up the file for revert on validation failure
  local backup="${path}.bak.$$"
  cp "$path" "$backup" || { echo "unit_reg_add: failed to create backup" >&2; return 2; }

  # Write the new unit using python to preserve YAML structure
  python3 -c "
import sys, yaml

path = '$path'
uid = '$id'
display = '$display'
dimension = '$dimension'
symbol = '$symbol'
precision = int('$precision')
equiv_str = '$equivalences'

with open(path) as f:
    content = f.read()

# Build equivalences list
equivs = []
if equiv_str:
    for pair in equiv_str.split(','):
        pair = pair.strip()
        if ':' in pair:
            to, factor = pair.split(':', 1)
            equivs.append({'to': to.strip(), 'factor': float(factor.strip())})

# Build the YAML block to append
lines = []
lines.append('')
lines.append('  %s:' % uid)
lines.append('    display: %s' % display)
lines.append('    dimension: %s' % dimension)
lines.append('    symbol: %s' % symbol)
lines.append('    precision: %s' % precision)
if equivs:
    lines.append('    equivalences:')
    for e in equivs:
        # Use int if factor is whole number
        f = int(e['factor']) if e['factor'] == int(e['factor']) else e['factor']
        lines.append('      - { to: %s, factor: %s }' % (e['to'], f))

# Find the right insertion point: before the trailing comments (after the last unit)
# We insert right before the '# ── EQUIVALENCES' comment block at the end
import re
# Find the last non-comment, non-blank content line position
content_lines = content.split('\n')
insert_idx = len(content_lines)
# Look for the trailing comment block about equivalences
for i, line in enumerate(content_lines):
    if line.startswith('# ── EQUIVALENCES ARE SAME-DIMENSION'):
        insert_idx = i
        break

# Insert the new unit block
new_content = '\n'.join(content_lines[:insert_idx]) + '\n'.join(lines) + '\n\n' + '\n'.join(content_lines[insert_idx:])
with open(path, 'w') as f:
    f.write(new_content)
" 2>&1

  local write_rc=$?
  if [[ $write_rc -ne 0 ]]; then
    cp "$backup" "$path"
    rm -f "$backup"
    echo "unit_reg_add: failed to write unit" >&2
    return 2
  fi

  # Clear the module cache so validate re-reads the file
  _WW_UNIT_REGISTRY_LOADED=""
  source "${BASH_SOURCE[0]}"

  # Validate the new state
  local val_output
  val_output="$(unit_reg_validate 2>&1)"
  local val_rc=$?

  if [[ $val_rc -ne 0 ]]; then
    # REVERT: validation failed
    cp "$backup" "$path"
    rm -f "$backup"
    echo "unit_reg_add: validation failed, reverted. Problems:" >&2
    echo "$val_output" >&2
    return 1
  fi

  rm -f "$backup"
  return 0
}
