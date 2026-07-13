# hledger 1.52.1 — advanced capability verification

**Purpose.** Confirm, by direct local execution rather than by reading the changelog,
which deeper/niche hledger features are actually available for using ledgers as
**general systems-accounting instruments** (arbitrary units, time-aware valuation,
conservation/assertions, computed postings). Feeds the ledger-service study in
[`README.md`](./README.md).

**Binary under test.** `hledger 1.52.1, linux-x86_64` (statically linked), the
current latest release, downloaded from
`https://github.com/simonmichael/hledger/releases/download/1.52.1/hledger-linux-x64.tar.gz`.
Contrast: the system copy on this host is **1.25** (27 releases behind).

**Reproduce.** `HLEDGER=/path/to/hledger-1.52.1 bash tests/run-advanced-tests.sh`.
Full captured output: [`tests/results-hledger-1.52.1.txt`](./tests/results-hledger-1.52.1.txt).
The binary is intentionally **not committed** (47 MB) — download to reproduce.

## Results

| # | Capability | Verdict | Evidence |
|---|---|---|---|
| 1 | Arbitrary units native (kg + Wh side by side) | ✅ works | `balance` lists `48.2 kg` and `1200 Wh` with no money involved |
| 2 | **Unit equivalence via `P` price directive** (hledger's answer to ledger's `C`) | ✅ works | `P 2026-01-01 kWh 1000 Wh` + `-X Wh` converts `3 kWh` → `3000 Wh` |
| 3 | Cost notation `@` + report at cost `-B` | ✅ works | `100 kWh @ 0.30 USD` reports as `30.00 USD` under `-B` |
| 4 | **Time-aware valuation** `--value=then\|DATE\|now` | ✅ works | same 100 WGT valued `100 / 150 / 150 USD` at three time points |
| 5 | Computed postings: auto-rule `--auto` + dimensionless multiplier | ✅ works (opt-in) | `*0.1` on `100 kg` derives `10 kg`; fires only with `--auto` |
| 6 | Periodic transactions `~` + `--forecast` | ✅ works | monthly rule projects Aug/Sep flows past the last real txn |
| 7 | Conservation guard: `==` sole-commodity assertion (pass) | ✅ caught | `50 L − 20 L`, asserted `== 30 L`, `check` exits 0 |
| 8 | Conservation guard: wrong asserted balance (fail) | ✅ caught | asserted `== 999 L`, `check` exits 1 with a precise diff (`969 L`) |
| 9 | Unbalanced transaction (Σ ≠ 0) rejected | ✅ caught | `48 kg` out vs `−50 kg` in → rejected |
| 10 | `check` suite (accounts/commodities/ordereddates/assertions) | ✅ works | strict mode flags undeclared `Equity:Open` |
| 11 | Multi-period report `-M -T -A` (totals + averages) | ✅ works | monthly columns with Total & Average |
| 12 | Budget report `--budget` (rule vs actual) | ✅ works | `[100% of 5 unit]` performance cells |
| 13 | Query language `amt:>N`, `tag:k=v` | ✅ works | `amt:>100` keeps the 1500 Wh posting; `tag:unit=lathe` filters |
| 14 | Machine-output formats on `print` | ✅ mostly | `txt csv tsv json sql fods` supported; `beancount` supported but **enforces** Assets/Liabilities/… top-level names |
| 15 | `roi` command (IRR / TWR) | ✅ works | reports `IRR 10.00%`, `TWR 10.00%` over a 1-year flow |
| 16 | `timedot` format (effort/time as a quantity) | ✅ works | `....` (4 dots) parsed as `1.00`, `..` as `0.50` |

**Automated assertions in the harness: 3 passed / 0 failed** (tests 7–9, the
conservation invariants — the ones that must hold or must be rejected).

## The three findings that change the ledger-vs-hledger decision

1. **Unit equivalence is already in hledger (Test 2).** Ledger-cli's headline
   `C 1.00 kWh = 1000 Wh` directive — which hledger *silently ignores* — is
   reproduced by a market-price directive `P DATE kWh 1000 Wh` plus `-X`/`--value`.
   The price engine *is* a unit-conversion algebra. This removes the single most
   commonly cited reason to reach for ledger.

2. **Conservation is enforced, not merely represented (Tests 7–9).** The
   transaction-balancing rule (Σ = 0) plus `==` sole-commodity assertions give
   exactly the Bitpads "conservation invariant." Violations fail with a precise,
   machine-parseable diff — the raw material for a production "needs attention"
   signal.

3. **Time is a first-class axis (Test 4).** `--value=then|DATE|now` means a
   quantity can be re-valued at any point in time — e.g. energy priced at the
   tariff *then* vs *now* — without editing the journal. Ledger's valuation story
   is weaker here.

## Caveats

- `beancount` export (Test 14) requires accounts to map to the fixed
  Assets/Liabilities/Equity/Income/Expenses roots — a constraint to remember if
  workwarrior ever exports non-financial unit-domains to Beancount tooling.
- Auto-postings (`--auto`) and forecasting (`--forecast`) are **opt-in flags**;
  reports are literal by default. The workwarrior dispatch layer must pass these
  through deliberately.
- Version gap matters: several of the above (richer valuation, `fods`/`tsv`
  output, `roi` refinements) are weaker or absent on the host's 1.25. **Upgrading
  the bundled hledger is the highest-leverage single change.**
