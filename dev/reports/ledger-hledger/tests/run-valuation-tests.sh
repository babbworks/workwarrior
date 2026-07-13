#!/usr/bin/env bash
# run-valuation-tests.sh — evidence for §6.5, Q1 and Q6 of
# dev/docs/ledger-systems-accounting.md
#
# Answers three questions that were speculative in the first draft:
#   V1. Can hledger express a MULTI-FACTOR WEIGHTED SUM?      -> YES, natively.
#   V2. Do coefficients vary over time, and does that reorder? -> YES.
#   V3. Does --auto/--forecast break "direct file truth"?      -> Diverges, but
#       materialises back to text. NOT idempotent: double-counts on write-back.
#
# Requires hledger >= 1.52 (the host's 1.25 will not do).
#   HLEDGER=/path/to/hledger-1.52.1 bash run-valuation-tests.sh
set -euo pipefail

HL="${HLEDGER:-hledger}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

pass=0; fail=0
check() { # check <label> <expected-substring> <actual>
  if grep -qF "$2" <<<"$3"; then
    printf '  PASS  %s\n' "$1"; pass=$((pass + 1))
  else
    printf '  FAIL  %s (expected to find: %s)\n' "$1" "$2"
    printf '%s\n' "$3" | sed 's/^/        /'
    fail=$((fail + 1))
  fi
}

printf '\n=== V1. Multi-factor weighted sum: the price table IS the coefficient vector ===\n'

cat > weights-production.journal <<'EOF'
P 2026-01-01 Mh    0.5 att
P 2026-01-01 Di    2.0 att
P 2026-01-01 crit 10.0 att
EOF

cat > records.journal <<'EOF'
2026-07-12 lathe-01 state
    factors:lathe-01     120 Mh
    factors:lathe-01       3 Di
    factors:lathe-01       1 crit
    equity:observed
2026-07-12 press-04 state
    factors:press-04      40 Mh
    factors:press-04      21 Di
    factors:press-04       3 crit
    equity:observed
2026-07-12 mill-02 state
    factors:mill-02       10 Mh
    factors:mill-02        1 Di
    factors:mill-02        1 crit
    equity:observed
EOF

# press-04 = 40*0.5 + 21*2.0 + 3*10 = 92 ; lathe-01 = 76 ; mill-02 = 17
out="$($HL -f records.journal -f weights-production.journal balance factors -X att -S --no-total)"
printf '%s\n' "$out"
check "press-04 weighted sum = 92"      "92.0 att" "$out"
check "lathe-01 weighted sum = 76"      "76.0 att" "$out"
check "mill-02 weighted sum = 17"       "17.0 att" "$out"
check "ranked queue: press-04 is first" "$(printf '%s\n' "$out" | head -1)" "$out"

printf '\n=== V2. Time-varying coefficients reorder the queue ===\n'

cat > weights-time.journal <<'EOF'
P 2026-01-01 Di   1.0 att     ; inspections cheap early in the year
P 2026-06-01 Di   5.0 att     ; audit season: inspection lapse gets expensive
P 2026-01-01 Mh   0.5 att
P 2026-01-01 crit 10.0 att
EOF

early="$($HL -f records.journal -f weights-time.journal balance factors --value=2026-03-01,att -S --no-total)"
now="$($HL   -f records.journal -f weights-time.journal balance factors --value=now,att        -S --no-total)"
printf -- '--- valued 2026-03-01 ---\n%s\n--- valued now ---\n%s\n' "$early" "$now"
# The SAME records rank differently depending on the date they are valued at.
check "pre-audit: lathe-01 outranks press-04" "lathe-01" "$(printf '%s\n' "$early" | head -1)"
check "audit season: press-04 outranks lathe-01" "press-04" "$(printf '%s\n' "$now" | head -1)"

printf '\n=== V3. File truth vs computed view (Q1 accrual + Q6 divergence) ===\n'

cat > truth.journal <<'EOF'
; Q1: an hour logged to a project ACCRUES A LIABILITY against that project.
= time:project
    backlog:tech-debt          *0.15
    time:accrued-review       *-0.15

~ weekly from 2026-07-13
    time:admin                 1.0 h
    sessions:manual

2026-07-10 build the thing
    time:project:ww          8.0 h
    sessions:agent:claude
EOF

literal="$($HL -f truth.journal balance --no-total)"
computed="$($HL -f truth.journal balance --auto --forecast --no-total -e 2026-08-01)"
printf -- '--- what the file literally says ---\n%s\n--- what hledger reports ---\n%s\n' "$literal" "$computed"
if grep -q 'tech-debt' <<<"$literal"; then
  printf '  FAIL  literal file must NOT report a tech-debt account\n'; fail=$((fail + 1))
else
  printf '  PASS  literal file has NO tech-debt account (divergence is real)\n'; pass=$((pass + 1))
fi
check "Q1: 8h logged accrues 1.2h liability"  "1.2 h  backlog:tech-debt" "$computed"
check "forecast injects unwritten time:admin" "3.0 h  time:admin"        "$computed"

# The reconciliation path: computed truth renders back to plain journal text.
materialised="$($HL -f truth.journal print --auto --forecast -e 2026-08-01)"
check "print materialises the derived posting" "backlog:tech-debt" "$materialised"

printf '\n=== V3b. HAZARD: materialisation is NOT idempotent ===\n'
{ printf '= time:project\n    backlog:tech-debt          *0.15\n    time:accrued-review       *-0.15\n\n'
  $HL -f truth.journal print --auto -e 2026-08-01
} > baked.journal

plain="$($HL -f baked.journal balance backlog --no-total)"
reapplied="$($HL -f baked.journal balance backlog --auto --no-total)"
printf -- '--- baked, read plain ---\n%s\n--- baked, read with --auto AGAIN ---\n%s\n' "$plain" "$reapplied"
check "baked posting is literal (1.2 h)"                 "1.2 h" "$plain"
check "re-applying the rule DOUBLE-COUNTS it (2.4 h)"    "2.4 h" "$reapplied"
printf '  NOTE  Policy: `print --auto` is a view/export, NEVER a write-back.\n'

printf '\n=== %d passed / %d failed ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
