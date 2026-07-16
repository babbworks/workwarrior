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

# ── R1: base unit per dimension ──────────────────────────────────────────────

@test "R1: every dimension has exactly one base unit" {
  # The shipped registry must declare a base for each dimension.
  for dim in time energy mass count money score; do
    run unit_reg_dimension_base "$dim"
    [ "$status" -eq 0 ]
    [[ -n "$output" ]]
  done
}

@test "R1: unit_reg_dimension_base returns the correct base" {
  [ "$(unit_reg_dimension_base time)" = "h" ]
  [ "$(unit_reg_dimension_base energy)" = "kWh" ]
  [ "$(unit_reg_dimension_base mass)" = "kg" ]
  [ "$(unit_reg_dimension_base count)" = "sess" ]
  [ "$(unit_reg_dimension_base money)" = "USD" ]
  [ "$(unit_reg_dimension_base score)" = "att" ]
}

@test "R1: validation rejects a dimension with NO base" {
  cat > "${BATS_TEST_TMPDIR}/nobase.yaml" <<'EOF'
schema: v1
units:
  kWh:
    dimension: energy
    symbol: kWh
    equivalences:
      - { to: Wh, factor: 1000 }
  Wh:
    dimension: energy
    symbol: Wh
EOF
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/nobase.yaml" run unit_reg_validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"no base unit"* ]]
}

@test "R1: validation rejects a dimension with MULTIPLE bases" {
  cat > "${BATS_TEST_TMPDIR}/twobases.yaml" <<'EOF'
schema: v1
units:
  kWh:
    dimension: energy
    symbol: kWh
    base: true
    equivalences:
      - { to: Wh, factor: 1000 }
  Wh:
    dimension: energy
    symbol: Wh
    base: true
EOF
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/twobases.yaml" run unit_reg_validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"multiple base"* ]]
}

# ── R2: chained conversion verification ─────────────────────────────────────

@test "R2: CHAINED CONVERSION — hledger resolves h->s via h->min->s (two hops)" {
  # VERIFICATION TEST: prove hledger can chain P directives for multi-hop conversion.
  # If h->min (x60) and we add min->s (x60), can hledger convert h directly to s?
  command -v hledger >/dev/null 2>&1 || skip "hledger not installed"

  # Create price directives for a chain: h -> min -> s
  cat > "${BATS_TEST_TMPDIR}/chain.prices" <<'EOF'
P 2026-01-01 h 60 min
P 2026-01-01 min 60 s
EOF

  # Journal: post in h, try to query in s
  cat > "${BATS_TEST_TMPDIR}/chain.journal" <<'EOF'
2026-07-13 chain test
    assets:time   1 h
    equity:opening
EOF

  # Try to convert 1 h -> s (expecting 3600 s if chaining works)
  run hledger -f "${BATS_TEST_TMPDIR}/chain.journal" -f "${BATS_TEST_TMPDIR}/chain.prices" \
      balance assets -X s --no-total
  [ "$status" -eq 0 ]

  # hledger 1.52.1: check if chaining worked (3600 s) or if it shows 1 h (no chaining)
  if [[ "$output" == *"3600 s"* ]]; then
    # Chaining WORKS — hledger resolved h -> min -> s transitively.
    true
  elif [[ "$output" == *"1 h"* ]]; then
    # Chaining DOES NOT WORK — document the limitation.
    # This means multi-hop conversion requires explicit P directives for every pair.
    skip "hledger $(hledger --version | head -1) does NOT chain P directives transitively. Direct P required for every conversion pair."
  else
    # Unexpected output — fail to surface it
    echo "Unexpected output: $output" >&2
    false
  fi
}

# ── R3: connectivity validation (no islands) ────────────────────────────────

@test "R3: an ISLAND unit (no conversion path to base) is rejected" {
  cat > "${BATS_TEST_TMPDIR}/island.yaml" <<'EOF'
schema: v1
units:
  kWh:
    dimension: energy
    symbol: kWh
    base: true
    equivalences:
      - { to: Wh, factor: 1000 }
  Wh:
    dimension: energy
    symbol: Wh
  MWh:
    dimension: energy
    symbol: MWh
EOF
  # MWh has no equivalence to anything — it's an island.
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/island.yaml" run unit_reg_validate
  [ "$status" -eq 1 ]
  [[ "$output" == *"ISLAND"* ]]
  [[ "$output" == *"MWh"* ]]
}

@test "R3: a connected unit (reachable from base via peer) passes" {
  # Wh is reachable from kWh (base) via kWh->Wh equivalence.
  cat > "${BATS_TEST_TMPDIR}/connected.yaml" <<'EOF'
schema: v1
units:
  kWh:
    dimension: energy
    symbol: kWh
    base: true
    equivalences:
      - { to: Wh, factor: 1000 }
  Wh:
    dimension: energy
    symbol: Wh
    equivalences:
      - { to: mWh, factor: 1000 }
  mWh:
    dimension: energy
    symbol: mWh
EOF
  # mWh is reachable: kWh -> Wh -> mWh (undirected graph)
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/connected.yaml" run unit_reg_validate
  [ "$status" -eq 0 ]
}

@test "R3: singleton dimension trivially satisfies connectivity" {
  cat > "${BATS_TEST_TMPDIR}/singleton.yaml" <<'EOF'
schema: v1
units:
  USD:
    dimension: money
    symbol: USD
    base: true
EOF
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/singleton.yaml" run unit_reg_validate
  [ "$status" -eq 0 ]
}

@test "R3: the shipped registry passes connectivity check" {
  run unit_reg_validate
  [ "$status" -eq 0 ]
}

# ── R4: unit_reg_add ─────────────────────────────────────────────────────────

@test "R4: unit_reg_add creates a new unit and validates" {
  # Work on a copy of the registry
  cp "${WW_UNITS_FILE}" "${BATS_TEST_TMPDIR}/add.yaml"
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/add.yaml" run unit_reg_add "MWh" "Megawatt-hour" "energy" "MWh" "3" "kWh:1000"
  [ "$status" -eq 0 ]
  # Verify it's now in the file
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/add.yaml" run unit_reg_exists MWh
  [ "$status" -eq 0 ]
}

@test "R4: unit_reg_add rejects duplicate id" {
  cp "${WW_UNITS_FILE}" "${BATS_TEST_TMPDIR}/dup.yaml"
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/dup.yaml" run unit_reg_add "kWh" "Kilowatt-hour" "energy" "kWh" "3" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "R4: unit_reg_add reverts on validation failure (cross-dimension)" {
  cp "${WW_UNITS_FILE}" "${BATS_TEST_TMPDIR}/revert.yaml"
  # Try to add a unit with cross-dimension equivalence — should be reverted
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/revert.yaml" run unit_reg_add "bad" "Bad Unit" "time" "bad" "2" "USD:50"
  [ "$status" -eq 1 ]
  [[ "$output" == *"validation failed"* ]] || [[ "$output" == *"CROSS-DIMENSION"* ]]
  # The unit should NOT exist after revert
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/revert.yaml" run unit_reg_exists bad
  [ "$status" -ne 0 ]
}

@test "R4: unit_reg_add reverts on island (no path to base)" {
  cp "${WW_UNITS_FILE}" "${BATS_TEST_TMPDIR}/island_add.yaml"
  # Add a unit with no equivalence in a multi-unit dimension — creates an island
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/island_add.yaml" run unit_reg_add "MWh" "Megawatt-hour" "energy" "MWh" "3" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"ISLAND"* ]] || [[ "$output" == *"validation failed"* ]]
  # Must be reverted
  WW_UNITS_FILE="${BATS_TEST_TMPDIR}/island_add.yaml" run unit_reg_exists MWh
  [ "$status" -ne 0 ]
}