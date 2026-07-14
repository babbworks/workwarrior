#!/usr/bin/env bats
# test-unit-registry.bats — TASK-UNIT-001
#
# The unit registry is the KEYSTONE: LED-014/015/017 all assume a shared vocabulary of
# quantity exists. These tests protect the two invariants that make it worth having.
#
#   1. AN EQUIVALENCE IS SAME-DIMENSION. `1 kWh = 1000 Wh` is a CONVERSION (always true).
#      "An hour is worth 50 USD" is a PRICE (contingent). The registry says what a unit IS;
#      a mode says what it is WORTH. If a price can be smuggled in as an equivalence, the
#      valuation gets baked into the vocabulary and the verified "personal and production are
#      one engine with two price tables" result is lost.
#
#   2. AUTHORITATIVE, WITH A LOUD UNKNOWN. An unregistered unit is REPORTED — never silently
#      coerced, never silently dropped. The log is truth; the registry is a lookup table.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export WW_BASE="$REPO_ROOT"
  export WW_UNITS_FILE="${REPO_ROOT}/config/units.yaml"
  BIN_WW="${REPO_ROOT}/bin/ww"
  source "${REPO_ROOT}/lib/unit-registry.sh"
}

# ── the registry parses and is coherent ──────────────────────────────────────

@test "the shipped registry is coherent" {
  run unit_reg_validate
  [ "$status" -eq 0 ]
}

@test "registry declares units across multiple dimensions (money is A unit, not THE unit)" {
  run unit_reg_list
  [ "$status" -eq 0 ]
  [[ "$output" == *"h"* ]]
  [[ "$output" == *"kWh"* ]]
  [[ "$output" == *"kg"* ]]
  [[ "$output" == *"USD"* ]]
  # The demotion of money to one unit among many IS the thesis.
  [ "$(unit_reg_dimension USD)" = "money" ]
  [ "$(unit_reg_dimension kWh)" = "energy" ]
}

@test "symbol is the hledger boundary — 'unit' is the name, 'symbol' is what hledger calls it" {
  [ "$(unit_reg_symbol kWh)" = "kWh" ]
  run unit_reg_by_symbol Wh
  [ "$output" = "Wh" ]
}

@test "a malformed registry is FATAL, never a silent default" {
  # Guessing what a quantity means is how you end up adding kilograms to hours.
  printf 'this: [is: not\n' > "${BATS_TEST_TMPDIR}/bad.yaml"
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/bad.yaml" run unit_reg_dimension kg
  [ "$status" -ne 0 ]
}

@test "a registry with no units: map is FATAL" {
  printf 'schema: v1\n' > "${BATS_TEST_TMPDIR}/empty.yaml"
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/empty.yaml" run unit_reg_list
  [ "$status" -ne 0 ]
}

# ── INVARIANT 1: an equivalence is a conversion, not a price ─────────────────

@test "INVARIANT: a CROSS-DIMENSION equivalence is REJECTED (a price is not a conversion)" {
  cat > "${BATS_TEST_TMPDIR}/price.yaml" <<'EOF'
schema: v1
units:
  h:
    dimension: time
    symbol: h
    equivalences:
      - { to: USD, factor: 50 }
  USD:
    dimension: money
    symbol: USD
EOF
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/price.yaml" run unit_reg_validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"CROSS-DIMENSION"* ]]
  [[ "$output" == *"PRICE"* ]]
}

@test "INVARIANT: 'att' has NO equivalences — valuing INTO attention is a price" {
  # att is a score. Nothing is ever recorded in att; things are VALUED into it.
  run unit_reg_equivalences att
  [ -z "$output" ]
}

@test "an equivalence to a nonexistent unit is rejected" {
  printf 'schema: v1\nunits:\n  h: {dimension: time, symbol: h, equivalences: [{to: parsec, factor: 3}]}\n' \
    > "${BATS_TEST_TMPDIR}/ghost.yaml"
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/ghost.yaml" run unit_reg_validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown unit"* ]]
}

@test "a self-referential equivalence is rejected" {
  printf 'schema: v1\nunits:\n  h: {dimension: time, symbol: h, equivalences: [{to: h, factor: 1}]}\n' \
    > "${BATS_TEST_TMPDIR}/self.yaml"
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/self.yaml" run unit_reg_validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"itself"* ]]
}

@test "a non-numeric or non-positive factor is rejected" {
  printf 'schema: v1\nunits:\n  kWh: {dimension: energy, symbol: kWh, equivalences: [{to: Wh, factor: lots}]}\n  Wh: {dimension: energy, symbol: Wh}\n' \
    > "${BATS_TEST_TMPDIR}/nan.yaml"
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/nan.yaml" run unit_reg_validate
  [ "$status" -eq 1 ]
}

# ── INVARIANT 2: authoritative, with a LOUD unknown ─────────────────────────

@test "INVARIANT: a registered symbol is known" {
  run unit_reg_symbol_known Wh
  [ "$status" -eq 0 ]
}

@test "INVARIANT: an unregistered symbol is REPORTED, not swallowed" {
  run unit_reg_symbol_known parsec
  [ "$status" -ne 0 ]

  run "$BIN_WW" unit check parsec
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNREGISTERED"* ]]
  # The crucial half: the data is NOT rejected. The log is truth.
  [[ "$output" == *"still recorded"* ]]
}

@test "INVARIANT: unregistered symbols are listed, and known ones are not" {
  run bash -c "printf 'Wh\nparsec\nkg\nfurlong\n' | { source '${REPO_ROOT}/lib/unit-registry.sh'; unit_reg_unregistered; }"
  [[ "$output" == *"parsec"* ]]
  [[ "$output" == *"furlong"* ]]
  [[ "$output" != *"Wh"* ]]
  [[ "$output" != *"kg"* ]]
}

# ── the hledger boundary: equivalences BECOME price directives ───────────────

@test "equivalences generate hledger P directives" {
  run unit_reg_price_directives 2026-01-01
  [ "$status" -eq 0 ]
  [[ "$output" == *"P 2026-01-01 kWh 1000 Wh"* ]]
  [[ "$output" == *"P 2026-01-01 h 60 min"* ]]
}

@test "END TO END: the registry's price table actually drives hledger's conversion" {
  # This is the whole claim. hledger's price engine IS a unit-conversion algebra — which is
  # why ledger-cli's C directive, and ledger-cli itself, are not needed.
  command -v hledger >/dev/null 2>&1 || skip "hledger not installed"

  unit_reg_price_directives 2026-01-01 > "${BATS_TEST_TMPDIR}/units.prices"
  cat > "${BATS_TEST_TMPDIR}/j.journal" <<'EOF'
2026-07-13 intake
    assets:store   3 kWh
    assets:store   2 h
    equity:opening
EOF
  run hledger -f "${BATS_TEST_TMPDIR}/j.journal" -f "${BATS_TEST_TMPDIR}/units.prices" \
      balance assets -X Wh --no-total
  [ "$status" -eq 0 ]
  [[ "$output" == *"3000 Wh"* ]]     # 3 kWh converted by the registry's own factor
  [[ "$output" == *"2 h"* ]]         # ...and time is left ALONE: no cross-dimension path
}

# ── the CLI is read-only ─────────────────────────────────────────────────────

@test "ww unit list works and shows the equivalences" {
  run "$BIN_WW" unit list
  [ "$status" -eq 0 ]
  [[ "$output" == *"kWh"* ]]
  [[ "$output" == *"Wh 1000"* ]]
}

@test "ww unit show gives full detail" {
  run "$BIN_WW" unit show kWh
  [ "$status" -eq 0 ]
  [[ "$output" == *"energy"* ]]
  [[ "$output" == *"1 kWh = 1000 Wh"* ]]
}

@test "ww unit show on an unknown unit fails with a usable message" {
  run "$BIN_WW" unit show parsec
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown unit"* ]]
}

@test "ww unit NEVER writes — no write path exists in the verb" {
  # Read-only is a contract, not an intention. Assert it structurally.
  # Only mutation verbs count. (An earlier version of this test matched the '>' inside
  # "Usage: ww unit show <id>" — a reminder that a grep gate must be narrow to be true.)
  run bash -c "sed -n '/^cmd_unit()/,/^}/p' '$BIN_WW' \
    | grep -cE 'sed -i|tee |[[:space:]]mv |[[:space:]]rm |install -m|unit_reg_(add|set|write|remove)' || true"
  [ "$output" -eq 0 ]
}

@test "ww unit validate passes on the shipped registry" {
  run "$BIN_WW" unit validate
  [ "$status" -eq 0 ]
}

# ── the single-owner rule ────────────────────────────────────────────────────

@test "only lib/unit-registry.sh PARSES config/units.yaml (the ledgers.yaml lesson)" {
  # ledgers.yaml had FIVE independent parsers and a schema forked three ways. Never again.
  # Mentioning the filename (help text, comments) is fine; PARSING it elsewhere is not.
  run bash -c "grep -rnE 'units\.yaml' '${REPO_ROOT}/lib' '${REPO_ROOT}/bin' '${REPO_ROOT}/services' 2>/dev/null \
    | grep -v 'unit-registry.sh' \
    | grep -E 'safe_load|yaml\.load|open\(|awk|sed |grep -|yq' || true"
  [ -z "$output" ]
}
