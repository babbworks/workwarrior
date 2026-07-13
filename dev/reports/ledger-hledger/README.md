# Ledger & hledger — capability study for the workwarrior ledger service

**Branch:** `agent/research/ledger-hledger-study` (isolated worktree, based on the
`dev/`-layout restructure so it lands in the intended tree).
**Status:** research / analysis only — no runtime code changed.
**Scope:** study the two tools (built-in features + extension ecosystems) and
determine what deeper functionality workwarrior could enfold, in light of (a)
using ledgers for **arbitrary units**, not just money, and (b) Babb's **Bitpads**
universal-domain model of input/output accounting.

Companion files:
- [`hledger-1.52-verification.md`](./hledger-1.52-verification.md) — 16 advanced
  features confirmed by local execution against the latest release.
- [`tests/run-advanced-tests.sh`](./tests/run-advanced-tests.sh) — reproducible harness.
- [`tests/results-hledger-1.52.1.txt`](./tests/results-hledger-1.52.1.txt) — raw output.

---

## 0. Baseline — what the service is today

The current workwarrior ledger service is a **transport + config shell over
hledger**: `services/custom/configure-ledgers.sh` and
`services/questions/handlers/ledger_handler.sh` manage named ledgers in
`ledgers.yaml`, append transactions, and pass through `check` / `register` /
`balance`. The parallel `ledger-schema` branch is building the **command model**
(`lib/ledger-config.sh`, `lib/ledger-dispatch.sh` — reserved words + hledger
passthrough). **None of hledger's computational surface is exploited yet** — no
valuation, no periodic/auto postings, no non-`$` commodities, no assertions beyond
the balancing rule, no machine-output contract. That gap is the opportunity space.

---

## 1. The two tools, two buckets each

### 1a. Built-in — the deep/niche layer

Both tools share a journal syntax and most primitives (commodities, `@`/`@@` cost,
`P` prices, periodic `~`, auto `=`, virtual `()`/`[]`, balance assertions,
`--budget`, `--forecast`, a query language, multi-period reports). They diverge at
the edges:

**hledger differentiators** — stronger valuation (`--value=then|end|now|DATE`, `-X`,
`--valuechange`, `--gain`); first-class machine output (`json`, `sql`, `csv`, `tsv`,
`fods`) on many commands; native `timedot`/`timeclock` time formats; the `roi`
command; a pluggable `check` suite; the `hledger-*`-on-PATH add-on model; a strong
CSV import-rules engine. **All of the above verified working on 1.52.1 — see the
verification doc.**

**ledger-cli differentiators** — a full **value-expression language usable inside
postings** (`(amount * 0.15)`, functions `market`/`quantity`/`total`, the `%`
percentage commodity); the **`C` commodity-equivalence directive**
(`C 1.00 Kb = 1024 b`); **Python bindings** (`import ledger`, live
`Transaction`/`Posting`/`AutomatedTransaction` objects). Its power is *in-language*,
not in add-ons.

> **Empirical correction (important).** Two features I initially catalogued as
> "ledger-only" are already reachable in hledger:
> - proportional/computed postings → hledger `--auto` rule with a `*multiplier`
>   (verification Test 5);
> - unit equivalence (`C 1.00 kWh = 1000 Wh`) → hledger `P DATE kWh 1000 Wh` +
>   `-X`/`--value` (verification Test 2).
>
> So the genuinely ledger-only reasons to add it shrink to: rich in-posting value
> **expressions** (functions, arithmetic beyond a single multiplier) and the
> **Python library** embedding.

### 1b. Extensions — where added value lives (hledger ecosystem)

Grouped by relevance to workwarrior (from hledger.org/scripts.html):

- **Validation / invariants (highest value):** `hledger-check-fancyassertions`
  (balances over time, thresholds/ratios), plus built-in `check` subcommands. This
  is the engine behind a production "these N need attention now" queue.
- **Single-number / machine output:** `hledger-simplebal`, `sortandmergepostings`.
- **Visualization (feeds the `viz` service):** `hledger-plot` (matplotlib),
  `hledger-bar`, `hledger-sankeymatic` (flow diagrams — literally the source→sink
  picture).
- **Live monitoring (feeds `stream`):** `watchaccounts` (re-renders on file change);
  official `hledger-web` with a **JSON API**.
- **Ingestion:** `getprices`/`pricehist`, `simplefin*`, `paypal*`, and hledger's
  declarative **CSV rules** engine.
- **Math / transformation:** `ledgereval` (evaluate *Ledger* value expressions from
  hledger — the cross-tool math bridge), `hledger-smooth` (amortize/split),
  `hledger-interest`, `hledger-lots` (FIFO), `hledger-move`.
- **Haskell library scripts (the "special mathematical capacity"):**
  `hledger-register-max`, `hledger-combine-balances`, `hledger-balance-as-budget`,
  `hledger-txnsbycat.hs` — stack scripts over `hledger-lib` that parse the journal
  into typed, total values and compute arbitrary functions, optionally compiled.

> Note the structural echo: hledger's add-on model (`hledger-foo` on PATH becomes
> `hledger foo`) is **the same self-discovering-executable pattern** as
> workwarrior's `services/<category>/` services. A workwarrior ledger sub-service
> could register as an hledger add-on, or vice-versa, for free.

---

## 2. How is ledger practically incorporated when the basis is hledger?

Short answer: **it isn't today, and it mostly shouldn't be.** `ledger` is not even
installed on the host; the service is 100% hledger. Given §1's empirical
correction, hledger alone already covers units, proportional derivation, unit
equivalence, valuation, forecasting, assertions, and JSON.

If a concrete need for ledger's *value-expression language* or *Python embedding*
arises, the binding constraint is proven by the `C`-directive probe: **ledger's
advanced syntax is invisible/erroneous to hledger and vice-versa, so you cannot
author one journal both engines fully honor.** That rules out co-mounting ledger as
a second reader of the live journal, and leaves three real patterns:

- **A — expansion / pre-processor (cleanest).** `ledger` reads a rules file with its
  advanced syntax; `ledger print` materializes the computed postings into a plain
  journal; hledger consumes *that*.
  `ledger -f rules.ldg print > expanded.journal && hledger -f expanded.journal …`
- **B — pure expression evaluator (`ledgereval`).** Shell out for one value, capture
  stdout, feed back. ledger = stateless `expr → value`.
- **C — Python library.** Build ledger `--python`, `import ledger` inside a
  workwarrior Python service, emit JSON shaped like `hledger -O json`.

**Code touch-points:** (1) `lib/dependency-installer.sh` — add `ledger` as an
*optional* guarded dependency; (2) `lib/ledger-dispatch.sh` — add an engine selector
(default `hledger`; a verb like `ww ledger expand`/`eval` routes to `ledger`);
(3) a normalization boundary so everything downstream still consumes hledger JSON.

**Recommendation:** keep hledger as the single system-of-record; treat ledger as an
optional Pattern-A co-processor invoked only for value-expression math, and only
when a real use-case demands it. **Upgrading the bundled hledger (1.25 → 1.52+) is a
higher-leverage first move than adding ledger.**

---

## 3. The Bitpads bridge (why this matters beyond money)

Bitpads' universal-domain page states the thesis outright: *"Financial accounting
and physical conservation are the same algebra applied to different quantities"* and
*"Double-entry accounting is … a conservation law."* hledger **is** that algebra with
a mature toolchain. The mapping (each row verified against hledger where marked):

| Bitpads universal-domain | hledger primitive | Verified |
|---|---|---|
| Quantity Type Code (mass=g, energy=Wh, data=KB…) | commodity (`50 kWh`, `1.8 kg`) | Test 1 |
| Decode `Real Q = (N × SF)/10^D` | JSON `decimalMantissa` + `decimalPlaces` | Test 14 (json) |
| Unit scaling between QTCs | `P DATE kWh 1000 Wh` + `-X` | Test 2 |
| Conservation invariant Σ(signed flows) = 0 | transaction must balance | Test 9 |
| Checkpoint / settled balance | `==` sole-commodity assertion | Tests 7–8 |
| Transformation (billet → part + scrap) | `--auto` computed posting | Test 5 |
| Generation / Consumption / Depletion | income-/expense-/asset-style postings + `--valuechange` | Test 11 |
| Time-indexed valuation of a flow | `--value=then|DATE|now` | Test 4 |
| Efficiency of a flow over time | `roi` (IRR/TWR) | Test 15 |

So a ledger service that adopts commodities + `P` equivalences + `==` assertions is
not doing finance — it is doing **general systems accounting**, and Bitpads records
become journal transactions.

---

## 4. Prioritized enfold candidates (menu, not a plan)

1. **Upgrade the bundled hledger to 1.52+** — unlocks valuation, `roi`, `fods`/`tsv`,
   and richer `check` on the host. Highest leverage, lowest risk.
2. **Adopt `-O json` as the internal data contract** — feeds `viz`, the Warrior app,
   and `stream` lenses. Home: the `ledger-schema` dispatch layer.
3. **Unit-domain ledger pattern** — `commodity` + `P` equivalence + `==` assertions,
   with per-QTC templates. The Bitpads bridge; turns the service from money-only into
   systems accounting.
4. **Invariant/attention engine** — wrap `check` + `fancyassertions` into a verb that
   emits the "N things need attention" list (production-mode compression).
5. **Computed/auto postings + forecast** — for transformation accounting and the
   loop-agent's projections (remember: opt-in flags).
6. **Ingestion adapters** — CSV rules + `pricehist`, including Bitpads → journal.
7. **Live heartbeat** — `watchaccounts` / `hledger-web` JSON into `stream`.
8. **(Optional) one `hledger-lib` stack script** — proof-of-concept conservation
   checker, registered via the `hledger-*` add-on convention that mirrors
   workwarrior's own service model.
9. **(Only if needed) ledger as Pattern-A co-processor** for value-expression math.

---

## Sources

Ledger: [manual](https://ledger-cli.org/doc/ledger3.html) ·
[ledger3.texi](https://github.com/ledger/ledger/blob/master/doc/ledger3.texi) ·
[Python bindings](https://groups.google.com/g/ledger-cli/c/mV-RQLLV9o4).
hledger: [manual](https://hledger.org/hledger.html) ·
[scripting](https://hledger.org/scripting.html) ·
[scripts & add-ons](https://hledger.org/scripts.html) ·
[1.52.1 release](https://github.com/simonmichael/hledger/releases/tag/1.52.1).
Bitpads: [universal-domain](https://bitpads.org/universal-domain.html).
