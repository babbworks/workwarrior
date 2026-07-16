# Unit Registry — v1

**Contract for:** `config/units.yaml`
**Status:** normative, v1.
**Owning module:** `lib/unit-registry.sh` — the **single** reader. No other code path may
parse this file.
**Reasoning:** `dev/logs/decisions.md`, 2026-07-13. This document is the *what*; that entry
is the *why*.

---

## 1. What a unit is

**A unit is the system's shared vocabulary of quantity.** A unit declared here means the same
thing to the ledger, to `stream`, to `viz` and to tasks. If it did not, the two could never be
reconciled.

The thesis (`dev/docs/ledger-systems-accounting.md`): **double-entry is a conservation law, and
money is merely the first commodity it was applied to.** So the *unit* — not the dollar — is the
system's most fundamental noun: hours, kilowatt-hours, kilograms, machine-cycles, API dollars,
defects.

### Why `unit` and not `commodity`

`commodity` is **hledger's** word. It carries financial baggage into a system whose entire point
is that units are **general**. Naming the general case after the special case would quietly
re-import the assumption we exist to remove.

> **`unit` is what the thing IS. `symbol` is what hledger calls it AT THE BOUNDARY.**

The mapping `unit → hledger commodity` lives in the `symbol` field, never in the name.

---

## 2. The shape

```yaml
schema: v1

units:
  kWh:
    display: Kilowatt-hour
    dimension: energy
    symbol: kWh
    precision: 3
    base: true
    equivalences:
      - { to: Wh, factor: 1000 }

  Wh:
    display: Watt-hour
    dimension: energy
    symbol: Wh
    precision: 0
```

| Field | Type | Required | Meaning |
|---|---|---|---|
| *(key)* | unit id | yes | Stable. Referenced by events and postings. |
| `dimension` | string | **yes** | What kind of quantity: `time`, `energy`, `mass`, `count`, `money`, `score`. |
| `display` | string | no | Human-readable name. Defaults to the id. |
| `symbol` | string | no | **The hledger commodity string.** Defaults to the id. This is the boundary. |
| `precision` | int | no | Decimal places. Default 2. |
| `base` | bool | no | If `true`, this unit is the **base** (anchor) for its dimension. Exactly one unit per dimension must be `base: true`. The base is the normalisation target — all other units in the dimension must have a conversion path to it. |
| `equivalences` | list | no | `{to, factor}` — see §3. |

---

## 3. Equivalences are SAME-DIMENSION. This is enforced.

**An equivalence is a CONVERSION.** `1 kWh = 1000 Wh`. Always true, everywhere, for everyone.

**A cross-dimension relation is a PRICE.** *"An hour is worth 50 USD."* *"A machine-hour is
worth 3 attention."* Contingent, contextual, different per person and per time.

> **The registry says what a unit IS. A mode says what it is WORTH.**

`lib/unit-registry.sh` **REJECTS** a cross-dimension equivalence, so the boundary cannot be
crossed by accident. This is not pedantry: the moment a price lands in the registry, the
verified result that *"personal and production are one engine with two price tables"* is lost —
because the valuation would have been baked into the vocabulary.

hledger agrees, independently: converting a multi-unit balance with `-X Wh` leaves `kg` and `h`
**untouched**, because no price path exists between dimensions.

### Equivalences generate hledger price directives

```
ww unit prices 2026-01-01
  P 2026-01-01 h   60   min
  P 2026-01-01 kWh 1000 Wh
  P 2026-01-01 kg  1000 g
```

**VERIFIED** (`dev/reports/ledger-hledger/`, Test 2): `P DATE kWh 1000 Wh` plus `-X Wh` converts
`3 kWh` → `3000 Wh`. **hledger's price engine IS a unit-conversion algebra** — which is exactly
why ledger-cli's `C` directive, and ledger-cli itself, are not needed.

Validation rules: the target must exist, must share the unit's `dimension`, must not be the unit
itself, and `factor` must be a number > 0.

---

## 3a. Base unit per dimension

Exactly one unit per dimension must declare `base: true`. The base is the **normalisation
anchor** — the unit everything else in that dimension can be expressed in terms of. Without it,
"normalise everything in this dimension" has no target.

**Enforced by `unit_reg_validate`**: zero bases in a dimension is an error; more than one is an
error.

---

## 3b. Connectivity — no islands

Every non-base unit in a dimension **must have a conversion path to the base**. A unit with no
equivalences and no incoming equivalences from a connected peer is an **island**: it sits in the
dimension but cannot be compared to anything. Two energy quantities that should be addable would
quietly fail to combine in a report — the same class of "not an error, just a wrong answer" bug
that the registry exists to prevent.

**Implementation**: BFS from the base unit along the undirected equivalence graph. Any unit not
reached is reported as an island error.

**Exception**: a dimension with only one unit (which must be the base) trivially satisfies
connectivity.

---

## 4. Authoritative, with a loud unknown

**Decided 2026-07-13.** If `stream` emits a unit the registry has never seen:

- **The event is still RECORDED.** The log is truth; the registry is a lookup table. (The same
  rule as [`actors-v1.md`](./actors-v1.md) §7 for an unresolvable actor ID.)
- **The unit is REPORTED as `unregistered`** and surfaces in a report.
- **Never silently coerce. Never silently drop.**

An unknown unit is a **registry** problem, not a **data** problem. An append-only record that
quietly rewrites what it was given, to make itself look tidy, is not worth keeping.

```
ww unit check parsec
  ⚠ 'parsec' is UNREGISTERED.
    The value is still recorded — the log is truth; the registry is a lookup table.
```

**A malformed registry is FATAL** (exit 2), never a silent default. Guessing what a quantity
means is how you end up adding kilograms to hours.

---

## 5. What does NOT live here

**Coefficients.** A weight — *how much this matters* — is per-profile and per-mode
(`profiles/<name>/actors.yaml`; `ledger-systems-accounting.md` §6.5, *"a mode is a price
table"*). The registry describes units; it does not value them.

`att` (attention) is registered as a unit with `dimension: score` because the attention queue
values everything **into** it (`hledger balance -X att -S`). But it has **no equivalences and
must have none** — converting a real quantity into `att` is a *price*, not a conversion.

---

## 6. The module contract

Single owner: `lib/unit-registry.sh`, python/`yaml.safe_load`-backed (consistent with
`lib/ledger-config.sh`, `lib/deps-manifest.sh`). Sourced-lib rules: no `set -euo pipefail`,
return codes only, no `exit`.

**Reads:** `unit_reg_list` · `unit_reg_exists` · `unit_reg_display` · `unit_reg_dimension` ·
`unit_reg_symbol` · `unit_reg_precision` · `unit_reg_equivalences` · `unit_reg_by_symbol` ·
`unit_reg_dimension_base`
**Unknowns:** `unit_reg_symbol_known` · `unit_reg_unregistered`
**Integrity:** `unit_reg_validate` (same-dimension, base-per-dimension, connectivity)
**Write:** `unit_reg_add` (validates before commit; reverts on failure)
**Ledger boundary:** `unit_reg_price_directives [date]`

CLI: `ww unit list|show <id>|check <symbol>|prices [date]|validate|add [id]`

---

## 7. Changelog

**v1.1 — 2026-07-15** — round 2 (R1–R4). Added `base` field (exactly one per dimension,
enforced). Added connectivity validation (BFS from base; islands are rejected). Added
`unit_reg_dimension_base(dim)`. Added `unit_reg_add` write path (validates before commit,
reverts on failure). Chained conversion verified with hledger 1.52.1.

**v1 — 2026-07-13** — initial contract. `unit` chosen over `commodity`; same-dimension
equivalences enforced; authoritative with a loud unknown; equivalences generate hledger `P`
directives.
