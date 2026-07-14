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
try:
    with open('$path') as f:
        m = yaml.safe_load(f) or {}
except Exception as e:
    print('units: malformed registry: %s' % e); sys.exit(2)

u = m.get('units')
if not isinstance(u, dict):
    print('units: registry has no units: map'); sys.exit(2)

problems = []
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
