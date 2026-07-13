#!/usr/bin/env bash
# Advanced hledger capability probe for the workwarrior ledger-service study.
#
# Confirms — by execution, not by changelog — the deeper/niche features that
# matter for using ledgers as GENERAL systems-accounting instruments (arbitrary
# units, time-aware valuation, conservation/assertions, computed postings).
#
# Reproducible: point $HLEDGER at any hledger binary to compare versions, e.g.
#   HLEDGER=/path/to/hledger-1.52.1  bash run-advanced-tests.sh
#   HLEDGER=hledger                  bash run-advanced-tests.sh   # system copy
#
# The 1.52.1 static linux binary used for the committed results came from:
#   https://github.com/simonmichael/hledger/releases/download/1.52.1/hledger-linux-x64.tar.gz
# (Binary itself is intentionally NOT committed — download to reproduce.)

set -u
HLEDGER="${HLEDGER:-hledger}"
WD="$(mktemp -d)"
trap 'rm -rf "$WD"' EXIT
pass=0; fail=0

hr()   { printf '\n============================================================\n'; }
title(){ hr; printf 'TEST %-3s %s\n' "$1" "$2"; hr; }
run()  { printf '$ %s\n\n' "$*"; "$@" 2>&1; printf '\n[exit %s]\n' "$?"; }
# expect: run cmd, assert it SUCCEEDS (exit 0) -> conservation "should hold"
expect_ok()  { if "$@" >/dev/null 2>&1; then echo "  => OK (exit 0, as expected)"; pass=$((pass+1)); else echo "  => UNEXPECTED FAIL"; fail=$((fail+1)); fi; }
# expect_fail: assert it FAILS (nonzero) -> a violated invariant that hledger must catch
expect_fail(){ if "$@" >/dev/null 2>&1; then echo "  => UNEXPECTED PASS (invariant NOT caught!)"; fail=$((fail+1)); else echo "  => OK (correctly rejected, nonzero exit)"; pass=$((pass+1)); fi; }

echo "hledger under test: $($HLEDGER --version)"

# ---------------------------------------------------------------------------
title 1 "Arbitrary units are native (kg + Wh tracked side by side)"
cat > "$WD/units.journal" <<'EOF'
2026-07-01 * Steel stamping run
    Process:Stamped                 48.2 kg
    Process:Scrap                    1.8 kg
    Inventory:SteelBillet          -50.0 kg
2026-07-02 * Grid draw
    Machine:PressA                 1200 Wh
    Utility:Grid                  -1200 Wh
EOF
run "$HLEDGER" -f "$WD/units.journal" balance --no-total

# ---------------------------------------------------------------------------
title 2 "Unit EQUIVALENCE via P price directive (hledger's answer to ledger's 'C')"
cat > "$WD/equiv.journal" <<'EOF'
P 2026-01-01 kWh  1000 Wh
2026-07-02 * meter reading
    Machine:PressA     3 kWh
    Utility:Grid      -3 kWh
EOF
echo "-- raw (kWh) --";       run "$HLEDGER" -f "$WD/equiv.journal" balance Machine --no-total
echo "-- converted -X Wh --"; run "$HLEDGER" -f "$WD/equiv.journal" balance Machine -X Wh --no-total

# ---------------------------------------------------------------------------
title 3 "Cost notation @ + report at cost (-B) and infer prices"
cat > "$WD/cost.journal" <<'EOF'
2026-07-01 * buy energy forward
    Assets:EnergyStore     100 kWh @ 0.30 USD
    Assets:Cash
EOF
echo "-- default --"; run "$HLEDGER" -f "$WD/cost.journal" balance Assets --no-total
echo "-- at cost -B --"; run "$HLEDGER" -f "$WD/cost.journal" balance Assets -B --no-total

# ---------------------------------------------------------------------------
title 4 "Time-aware valuation: --value=then vs end vs a specific date"
cat > "$WD/val.journal" <<'EOF'
P 2026-01-01 WGT  1.00 USD
P 2026-06-01 WGT  1.50 USD
P 2026-12-01 WGT  2.00 USD
2026-03-01 * acquire widgets
    Assets:Widgets   100 WGT
    Equity:Opening
EOF
echo "-- -X USD --value=then --"; run "$HLEDGER" -f "$WD/val.journal" -X USD --value=then balance Assets:Widgets --no-total
echo "-- -X USD --value=2026-06-15 --"; run "$HLEDGER" -f "$WD/val.journal" -X USD --value=2026-06-15 balance Assets:Widgets --no-total
echo "-- -X USD --value=now --"; run "$HLEDGER" -f "$WD/val.journal" -X USD --value=now balance Assets:Widgets --no-total

# ---------------------------------------------------------------------------
title 5 "Computed postings: auto-rule (--auto) with a dimensionless multiplier"
cat > "$WD/auto.journal" <<'EOF'
= expenses:materials
    (overhead:handling)    *0.1
2026-07-01 * buy steel
    expenses:materials    100 kg
    assets:inventory
EOF
echo "-- without --auto (literal) --"; run "$HLEDGER" -f "$WD/auto.journal" print
echo "-- with --auto (10 kg derived) --"; run "$HLEDGER" -f "$WD/auto.journal" print --auto

# ---------------------------------------------------------------------------
title 6 "Periodic transactions + --forecast (projecting future flows)"
cat > "$WD/fc.journal" <<'EOF'
~ monthly  planned maintenance draw
    Maintenance:Parts     5 unit
    Inventory:Parts

2026-07-15 * actual
    Maintenance:Parts     5 unit
    Inventory:Parts
EOF
run "$HLEDGER" -f "$WD/fc.journal" register --forecast=2026-07-01..2026-10-01

# ---------------------------------------------------------------------------
title 7 "Conservation guard: balance assertion == (sole-commodity), PASS case"
cat > "$WD/assert_ok.journal" <<'EOF'
2026-07-01 * in
    Tank:Water    50 L
    Source:Main
2026-07-02 * out
    Tank:Water   -20 L
    Sink:Drain
2026-07-02 * checkpoint
    Tank:Water     0 L == 30 L
    Sink:Drain
EOF
run "$HLEDGER" -f "$WD/assert_ok.journal" balance Tank --no-total
echo "assertion should HOLD:"; expect_ok "$HLEDGER" -f "$WD/assert_ok.journal" check

# ---------------------------------------------------------------------------
title 8 "Conservation guard: same file but WRONG asserted balance -> must be caught"
cat > "$WD/assert_bad.journal" <<'EOF'
2026-07-01 * in
    Tank:Water    50 L
    Source:Main
2026-07-02 * out
    Tank:Water   -20 L
    Sink:Drain
2026-07-02 * checkpoint
    Tank:Water     0 L == 999 L
    Sink:Drain
EOF
echo "assertion should FAIL (30 L != 999 L):"; expect_fail "$HLEDGER" -f "$WD/assert_bad.journal" check
echo "-- the error hledger emits --"; run "$HLEDGER" -f "$WD/assert_bad.journal" check

# ---------------------------------------------------------------------------
title 9 "Transaction that does NOT balance (Sigma != 0) -> rejected"
cat > "$WD/unbalanced.journal" <<'EOF'
2026-07-01 * lossy transform (mass not conserved)
    Process:Out    48 kg
    Process:In    -50 kg
EOF
echo "unbalanced 48 vs 50 kg should FAIL:"; expect_fail "$HLEDGER" -f "$WD/unbalanced.journal" balance

# ---------------------------------------------------------------------------
title 10 "hledger check suite (accounts, commodities, ordereddates, assertions)"
cat > "$WD/strict.journal" <<'EOF'
account Assets:Cash
commodity 1.00 USD
2026-07-01 * ok
    Assets:Cash   10.00 USD
    Equity:Open
EOF
run "$HLEDGER" -f "$WD/strict.journal" check accounts commodities ordereddates assertions

# ---------------------------------------------------------------------------
title 11 "Multi-period report with totals (-T) and averages (-A)"
run "$HLEDGER" -f "$WD/val.journal" balance -M -T -A --no-total

# ---------------------------------------------------------------------------
title 12 "Budget report (--budget) from periodic rule vs actuals"
run "$HLEDGER" -f "$WD/fc.journal" balance --budget -M

# ---------------------------------------------------------------------------
title 13 "Query language: amt: numeric, cur:, tag: filters"
cat > "$WD/query.journal" <<'EOF'
2026-07-01 * big  ; unit: press
    Machine:PressA   1500 Wh
    Utility:Grid
2026-07-02 * small ; unit: lathe
    Machine:LatheB     40 Wh
    Utility:Grid
EOF
echo "-- amt:>100 --"; run "$HLEDGER" -f "$WD/query.journal" register "amt:>100"
echo "-- tag:unit=lathe --"; run "$HLEDGER" -f "$WD/query.journal" register tag:unit=lathe

# ---------------------------------------------------------------------------
title 14 "Machine-output contract: which formats does 'print' now support?"
for fmt in txt csv tsv json sql beancount fods; do
  printf '  %-9s : ' "$fmt"
  if "$HLEDGER" -f "$WD/units.journal" print -O "$fmt" >/dev/null 2>&1; then echo "supported"; else echo "NOT supported"; fi
done
echo "-- sample beancount output --"; run "$HLEDGER" -f "$WD/units.journal" print -O beancount

# ---------------------------------------------------------------------------
title 15 "roi command (rate of return over a flow) — generic efficiency metric"
cat > "$WD/roi.journal" <<'EOF'
2026-01-01 * invest
    Assets:Fund     1000 USD
    Assets:Cash
2026-12-31 * value
    Assets:Fund      100 USD = 1100 USD
    Equity:Unrealized
EOF
run "$HLEDGER" -f "$WD/roi.journal" roi --investment Assets:Fund --profit-loss Equity:Unrealized -Y 2>&1 | head -25

# ---------------------------------------------------------------------------
title 16 "timedot format: effort/time logged as a quantity, read as a journal"
cat > "$WD/effort.timedot" <<'EOF'
2026-07-01
maint.pressA   ....    ; 4 dots = 1.0h
maint.latheB   ..      ; 2 dots = 0.5h
EOF
run "$HLEDGER" -f "timedot:$WD/effort.timedot" balance --no-total

hr
printf 'SUMMARY: %s assertions passed, %s failed\n' "$pass" "$fail"
hr
