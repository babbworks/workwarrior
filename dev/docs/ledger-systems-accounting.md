# The Ledger as a General Systems-Accounting Engine

**Status:** living synthesis — analysis, not a plan. No task cards derive from this
document until its claims are triaged into a spec.
**Date:** 2026-07-12
**Supersedes nothing.** Extends [`ledger-account-hierarchy.md`](./ledger-account-hierarchy.md)
and [`modular-journals.md`](./modular-journals.md), which it now reads as early,
partial statements of the thesis below.

---

## 0. The thesis

Double-entry accounting is not a financial technique that happens to use arithmetic.
It is a **conservation law with a mature toolchain** — the assertion that in a closed
system, signed flows sum to zero, plus 500 years of tooling for recording,
constraining, and interrogating that assertion.

Money is merely the commodity it was first applied to.

If that is true, then a ledger engine is not a finance feature bolted onto
workwarrior. It is the **substrate for accounting for anything that flows**: hours,
attention, kilowatt-hours, kilograms, machine-cycles, API dollars, scrap, throughput,
defects. A factory floor and a personal work-week are the same algebra over different
quantities.

That is the ambition, stated plainly: **workwarrior's ledger is the accounting kernel
for physical and cognitive work, at any scale, in any unit.** The personal
productivity system and the industrial telemetry system are not two products. They
are one engine with two price tables.

This document is the standing synthesis of everything we know about whether that is
achievable, what it would take, and where it breaks.

---

## 1. Evidence tiers

This document mixes hard verification with speculation. Every claim below is tagged.
**Do not let a `[SPEC]` claim into a task card without demoting it to `[VERIFIED]` first.**

| Tag | Meaning |
|---|---|
| `[VERIFIED]` | Executed locally against hledger 1.52.1 and observed. See §3. |
| `[DOCUMENTED]` | Asserted by upstream docs or already written into this repo; not independently run. |
| `[SPEC]` | Speculative. A hypothesis we find compelling. Unproven. |

---

## 2. State of play

### What exists

| Artifact | Location | Status |
|---|---|---|
| Ledger transport/config shell | `services/custom/configure-ledgers.sh`, `services/questions/handlers/ledger_handler.sh` | Shipped |
| Command model — schema owner + dispatcher | `lib/ledger-config.sh`, `lib/ledger-dispatch.sh` | Built on `agent/builder/ledger-schema` (TASK-LED-004→011). **Stranded on the pre-`struct-1b` `system/` layout; needs rebase onto `dev/` to land.** |
| Non-money account hierarchy | `dev/docs/ledger-account-hierarchy.md` | **Declared, never built.** Asserts commodities are time (h), sessions (sess), cost ($) and defines the `time:`/`sessions:`/`costs:`/`output:`/`backlog:` tree. |
| Profile-level journal composition | `dev/docs/modular-journals.md` | Documented (`include` directives, sub-ledger provisioning) |
| Capability study + 16-test verification | `dev/reports/ledger-hledger/` on `agent/research/ledger-hledger-study` | **UNTRACKED — at risk. Commit before touching that worktree.** |

### The two facts that most shape what follows

**The non-money ledger was already declared and never built.** `ledger-account-hierarchy.md`
opens by stating the primary commodities are time, sessions and cost — "not money" —
and lays out the full account tree. The research effort rediscovered that same thesis
from the opposite direction, via Bitpads. Two independent derivations landing on the
same claim is the strongest signal we have that it's right. **The gap is not insight.
It is that nothing behind the doc runs.**

**Two tools in the stack speak the same language and have no wire between them.**
hledger natively parses `timeclock` and `timedot` formats `[VERIFIED, Test 16]`.
TimeWarrior is installed and integrated across a dozen files. `grep -r 'timeclock\|timedot'`
across the entire repository returns **zero hits**. The account-hierarchy doc claims
time is a ledger commodity; nothing makes it one.

### The current computational surface: unexploited

The ledger service today is a **transport and config shell over hledger**. It manages
named ledgers, appends transactions, and passes through `check`/`register`/`balance`.
No valuation. No periodic or auto postings. No commodity beyond `$`. No assertions
beyond the implicit balancing rule. No machine-output contract. **None of hledger's
computational surface is in use.** That gap is the entire opportunity.

Compounding it: **the host runs hledger 1.25 — 27 releases behind 1.52.1.** Much of
what is `[VERIFIED]` below is weak or absent there. Upgrading the bundled hledger is
the single highest-leverage, lowest-risk move available and is a hard prerequisite for
most of this document.

---

## 3. Verified ground

Sixteen advanced capabilities were tested by direct local execution against hledger
1.52.1 rather than read from a changelog. Full detail:
`dev/reports/ledger-hledger/hledger-1.52-verification.md`. The load-bearing results:

| Capability | Result |
|---|---|
| Arbitrary units native — `kg` and `Wh` side by side, no money involved | Works |
| **Unit equivalence** via `P DATE kWh 1000 Wh` + `-X` | Works |
| Time-aware valuation `--value=then\|DATE\|now` | Works |
| Computed postings — `--auto` rule with multiplier (`*0.1` on `100 kg` → `10 kg`) | Works (opt-in) |
| Periodic `~` + `--forecast` — projects flows past the last real transaction | Works |
| Conservation: `==` sole-commodity assertion passes when correct | Enforced |
| Conservation: wrong asserted balance **fails with a precise diff** | Enforced |
| Conservation: unbalanced transaction (Σ ≠ 0) rejected | Enforced |
| Machine output on `print`: `txt csv tsv json sql fods` | Works |
| `roi` (IRR / TWR) | Works |
| `timedot` — `....` parses as `1.00`, `..` as `0.50` | Works |

Three of these changed the strategic picture:

1. **Unit equivalence is already in hledger.** ledger-cli's headline
   `C 1.00 kWh = 1000 Wh` directive — which hledger silently ignores — is fully
   reproduced by a market-price directive plus `-X`. **The price engine *is* a
   unit-conversion algebra.** This removes the single most-cited reason to adopt
   ledger-cli at all.
2. **Conservation is enforced, not merely represented.** Σ=0 balancing plus `==`
   assertions give exactly the conservation invariant, and violations fail with a
   machine-parseable diff. That diff is the raw material for an attention signal.
3. **Time is a first-class axis.** A quantity can be re-valued at any point in time
   without editing the journal.

### The ledger-cli question: settled

**Keep hledger as the sole system-of-record.** ledger-cli is not installed on this
host, and hledger alone covers units, proportional derivation, unit equivalence,
valuation, forecasting, assertions and JSON.

The two engines' advanced syntaxes are mutually invisible — you cannot author one
journal both fully honour — which rules out co-mounting ledger as a second reader.
The only genuinely ledger-only capabilities left are **in-posting value expressions**
(arithmetic and functions beyond a single multiplier) and the **Python bindings**.

If a real need for those emerges, the pattern is a **pre-processor**, not a second
engine: `ledger -f rules.ldg print > expanded.journal && hledger -f expanded.journal …`.
ledger becomes a stateless expander whose output is a plain journal. Everything
downstream still consumes hledger. This is a contingency, not a plan.

---

## 4. The Bitpads bridge

Bitpads' universal-domain model states the thesis independently: *"Financial accounting
and physical conservation are the same algebra applied to different quantities."*
hledger is that algebra, already implemented and hardened.

| Bitpads universal-domain concept | hledger primitive | Tier |
|---|---|---|
| Quantity Type Code (mass=g, energy=Wh, data=KB…) | commodity (`50 kWh`, `1.8 kg`) | `[VERIFIED]` |
| Decode `Real Q = (N × SF)/10^D` | JSON `decimalMantissa` + `decimalPlaces` | `[VERIFIED]` |
| Unit scaling between QTCs | `P DATE kWh 1000 Wh` + `-X` | `[VERIFIED]` |
| Conservation invariant Σ(signed flows) = 0 | transaction must balance | `[VERIFIED]` |
| Checkpoint / settled balance | `==` sole-commodity assertion | `[VERIFIED]` |
| Transformation (billet → part + scrap) | `--auto` computed posting | `[VERIFIED]` |
| Generation / Consumption / Depletion | income/expense/asset-style postings | `[VERIFIED]` |
| Time-indexed valuation of a flow | `--value=then\|DATE\|now` | `[VERIFIED]` |
| Efficiency of a flow over time | `roi` (IRR/TWR) | `[VERIFIED]` |

**Every row is verified.** A ledger service that adopts commodities, `P` equivalences
and `==` assertions is not doing finance. It is doing general systems accounting, and
a Bitpads record is a journal transaction.

This is the reindustrialization claim, and it is not rhetorical: the thing a factory
needs — conservation of material, energy and time, enforced, auditable, queryable,
re-valuable after the fact — is a solved problem in a domain nobody thought to point
at factories.

---

## 5. The concept map

Nine axes, grouped by the kind of move each represents.

### Adopt a concept from hledger into workwarrior proper

**A — The commodity as workwarrior's universal quantity type.** `[SPEC]`
Promote "commodity" out of the ledger and into a repo-wide registry
(`config/commodities.yaml`) that the ledger, `stream`, `viz` and tasks all read.
This decides whether units are a ledger-local detail or the **system's shared
vocabulary**. Bitpads QTC ↔ hledger commodity ↔ ww registry, one definition.

*The extension point already exists:* `config/` holds `service-uda-registry.yaml`,
`uda-color-map.yaml`, `body-uda-map.yaml` — workwarrior already has the pattern of a
central registry many services read. A commodity registry is that same shape.

**A is the keystone.** Almost everything else in this document is downstream of the
answer.

**F — `-O json` as a universal service output contract.** `[SPEC]`
hledger emits `json`/`csv`/`sql`/`tsv`/`fods` on most commands `[VERIFIED]`.
workwarrior's self-discovering services have **no declared output contract at all**.
Adopt hledger's machine-output discipline repo-wide so `stream`, `viz` and the Warrior
app consume one shape rather than each parsing text.

**H — Declarative import rules as the general intake layer.** `[DOCUMENTED]`
hledger ships a mature declarative source→posting mapper (CSV rules). `stream` needs
precisely this and does not have it. Adopt the pattern — or literally the engine — for
telemetry ingestion. Bitpads → journal is an import rule.

### Extend a concept workwarrior already has

**C — The TimeWarrior ↔ hledger overlap.** `[VERIFIED capability, unbuilt]`
The missing wire from §2. Does `timew export` → `timeclock` → hledger make the journal
the single analytical surface over time? Or does that duplicate the store and create
two disagreeing truths? *"Four tools, one voice"* is the title of one of this repo's
own story docs. **This is the claim's first real test**, and it is small enough to
settle empirically.

**E — Valuation and urgency are the same primitive.** `[SPEC]` — see §6.

**D — Assertions as an invariant engine.** `[VERIFIED capability]`
workwarrior already runs Orchestrator→Builder→Verifier gates for *process*. hledger's
`==` assertions and `check` suite are the exact analogue for *data*, with
machine-parseable failures. Unify them into one invariant concept, and the output feeds
the attention queue. Note §6: **D turns out to be a special case of E.**

### Structural

**B — Is double-entry actually the right shape for recording work?** `[SPEC]`
`ledger-account-hierarchy.md` asserts it and never justifies it. When you log an hour,
**what is the second posting?** "Conservation of attention" is a real, falsifiable
claim: it holds only if attention is genuinely conserved. It is currently unexamined,
and everything ambitious here rests on it. See §8 for the escape hatch if it fails.

**G — The add-on isomorphism.** `[DOCUMENTED]`
`hledger-foo` on `PATH` becomes `hledger foo` — **the same self-discovering-executable
pattern as `services/<category>/`.** The two architectures already rhyme. ww ledger
sub-services could register as hledger add-ons, and vice versa, for free. Elegant;
possibly a gimmick. Low cost to find out.

**I — Periodic/auto postings + `--forecast` as the loop-agent's projection substrate.**
`[VERIFIED capability]` The agent must reason about future flows. hledger already
computes them.

---

## 6. Valuation and urgency are the same primitive

**`[VERIFIED 2026-07-12]` — this claim was speculative in the first draft. It has since
been demonstrated end-to-end against hledger 1.52.1. See §6.5 for the mechanism and
the reproduction.** It reorganises the rest of the document.

**TaskWarrior's urgency** is a weighted sum of coefficients times factors (due-date
proximity, priority, age, tags, blocking, active), collapsed to one float. Crucially,
**urgency is never stored.** It is not a field on the task; it is recomputed on every
read, because one of its inputs is *now*. The record is immutable fact; urgency is a
projection of that fact through a formula, evaluated at read time.

**hledger's valuation** is structurally identical. A posting stores a raw quantity —
`100 kWh`. What it is *worth* depends on a price table and a point in time, and you
choose the point when you ask: `--value=then`, `--value=now`, `--value=DATE`. The
journal is never rewritten. The number you act on is a function of the stored quantity
and time, computed at report time. `[VERIFIED, Test 4]`

Two tools, built by different people for different purposes, independently arrived at
the same discipline: **separate the record from its valuation.** Three consequences
follow.

### 6.1 hledger's valuation is auditable; TaskWarrior's is not

In hledger the price table is *data in a file*. Ask "why is this worth 150?" and you
trace it to a `P` directive on a date. TaskWarrior hands you a bare float with no
provenance — urgency is notoriously the thing users cannot reason about. Adopting
hledger's stance means treating attention as something with a **declared, inspectable
price that varies by time and context**, rather than a magic number falling out of a
config file.

### 6.2 Run it backwards: the attention queue *is* a valuation report

hledger's price is one scalar per commodity per date. Urgency is a *weighted sum of
many factors*. Now value ledger accounts under an urgency-style formula: value every
account in a synthetic commodity called **attention**, sort descending.

A machine's balance in `machine-hours-since-service`, weighted by criticality; plus
days-since-inspection, weighted by another coefficient — out falls a ranked list.

**This is exactly the floor-manager problem.** "Which 3 of my 50 machines need
attention now" and "which task should I do next" collapse into **the same operation**:
a valuation report over a synthetic commodity.

The consequences are large:
- The attention queue is not a feature to build. It is a *report to run*.
- **D is a special case of E.** The invariant engine's failures are just accounts with
  a very high attention-value.
- Personal mode and production mode differ only in their **price table**. Same engine,
  same records, different coefficients. This is what makes one product serve both.

### 6.3 Counterfactual valuation — which TaskWarrior structurally cannot do

Because `--value=then` and `--value=now` range over the same immutable record, you can
ask: *what did this look like at the moment the decision was made, versus in hindsight?*

Applied to work: "was that task genuinely urgent when I skipped it, or does it only
look urgent now?"

This is load-bearing for the **loop-agent**. An agent acting autonomously while the
user is away needs its decisions **replayable at the valuation that was true at
decision time**, not re-litigated against today's numbers. Double-entry provides this
for free. Nothing else in the stack does.

### 6.4 Where the analogy strains

Urgency is unitless and **unconserved**. You cannot post it double-entry unless
attention is a conserved quantity. But that is precisely the claim of **B** — attention
*is* conserved; there are finite hours. **E does not merely sit beside B; it
pressure-tests it.** If B is false, §6.2 degrades from double-entry to a mere weighted
query, and much of the elegance is lost (though not the utility).

### 6.5 The mechanism, verified `[VERIFIED 2026-07-12, hledger 1.52.1]`

The open question was whether hledger's price mechanism — one scalar per commodity per
date — could express a **multi-factor weighted sum**, or whether that forced us to
ledger-cli. It can, natively. **It is not an hledger limitation, and ledger-cli is not
required for it.**

**The mechanism: each factor is a commodity, and the price table is the coefficient
vector.**

```hledger
; ── the weights ──
P 2026-01-01 Mh    0.5 att    ; machine-hours since service
P 2026-01-01 Di    2.0 att    ; days since inspection
P 2026-01-01 crit 10.0 att    ; criticality

; ── the raw observed record ──
2026-07-12 press-04 state
    factors:press-04   40 Mh
    factors:press-04   21 Di
    factors:press-04    3 crit
    equity:observed
```

`hledger balance factors -X att -S` converts every factor by its coefficient, sums
them, and sorts descending:

```
 92.0 att  factors:press-04     (40×0.5 + 21×2.0 + 3×10)
 76.0 att  factors:lathe-01
 17.0 att  factors:mill-02
```

Values match hand-calculation exactly. **The ranked attention queue is one command.**
"Which machines need attention now" and "which task next" are the same query.

Three consequences, each tested:

1. **Modes are price tables.** The same immutable records, read against a different
   weight file, yield different attention values — `-f records.journal -f
   weights-safety.journal`. *Caveat, honestly reported:* in the trial dataset the
   safety weights **rescaled** values (press 92→322, mill 17→59) but did **not**
   reorder the ranking. Mode-switching changes magnitudes and gaps; whether it
   reorders depends on the data. Do not oversell this.

2. **Time-varying coefficients do reorder — this is the strong result.** With `P`
   directives on different dates (`Di` rising from 1.0 to 5.0 at audit season),
   `--value=2026-03-01,att` ranks `lathe-01` (73) above `press-04` (71), while
   `--value=now,att` ranks `press-04` (155) above `lathe-01` (85). **The same records
   produce a different priority order depending on the date you value them at.** This
   is §6.3 — counterfactual valuation — demonstrated. "Was that genuinely the top
   priority when we decided, or does it only look that way now?" is a runnable query,
   and it is the audit primitive the loop-agent needs.

3. **The coefficients are data, not code.** The weights live in a plain-text price
   file, dated, diffable, per-profile. This is §6.1: attention has a declared,
   inspectable price. Unlike TaskWarrior's urgency float, you can trace *why*.

**The residual limit.** A price is piecewise-constant between dated `P` directives. It
cannot express a *continuous nonlinear function of now* — TaskWarrior's due-date
proximity curve, for instance. Options: emit dated `P` directives on a schedule to
approximate the curve, or compute genuinely nonlinear factors in a layer above hledger
and post the result as a factor commodity. **This is the one place where a computation
layer above the journal is unavoidable — and it is a small one.**

Reproduction: `dev/reports/ledger-hledger/` (harness to be extended with these cases).

---

## 7. Spin-offs

Consequences that fall out of the above and were on no earlier list.

### J — The journal as the loop-agent's audit log and budget governor `[SPEC]`

**The strongest of these.** The loop-agent work identified hard requirements: cap
iterations, detect no-progress, enforce a **dollar budget ceiling**, and establish a
trust model for an agent writing to real data unattended.

Double-entry is the most battle-tested append-only audit format ever built, **with
integrity checks included**. Every agent action becomes a transaction. Its cost posts
to `costs:api:anthropic` — **an account that already exists in
`ledger-account-hierarchy.md`.** The budget ceiling becomes a **balance assertion**
that fails loudly with a machine-parseable diff `[VERIFIED]`.

We would not be inventing an agent-governance layer. We would be **pointing an existing
one at the problem** — one whose account tree already anticipated it.

Combined with §6.3, this yields something rare: an autonomous agent whose every action
is conserved, budgeted, auditable, and **replayable at the valuation under which it
decided.**

### O — `include` as multi-instance composition `[SPEC]`

`modular-journals.md` already documents `include` at the **profile** level. Extend the
same primitive **upward**: the "Warrior" meta-identity is defined as a view across
profiles *and instances*, backed by the registry at `~/.config/ww/registry/`. A
warrior-level journal that `include`s each instance's journal produces the aggregate
view with **zero new machinery** — and because it is the same file format at every
level, the top-level view is queryable by exactly the same commands.

One format, three scopes: sub-ledger → profile → warrior.

### N — Virtual postings as the escape hatch `[VERIFIED capability]`

The obvious objection to B — *must everything balance?* — has a built-in answer.
Virtual postings `()` and `[]` record quantities that do not participate in the
conservation check. Raw telemetry observations can land in the journal without
inventing a fake counterparty. **Keep the discipline where it is meaningful; relax it
where it is not.** This is what makes B survivable even if attention turns out not to
be strictly conserved.

### L — `timedot` as the low-friction capture format `[VERIFIED]`

`....` parses as `1.00`, `..` as `0.50`. A human-writable, glanceable effort format
with none of TimeWarrior's start/stop ceremony — which is precisely what **retroactive
logging** and the **Warrior mobile app's** quick-entry surface need.

### M — `roi` over effort rather than money `[VERIFIED capability]`

Hours invested → `output:features`. Which projects actually returned? Strange,
possibly profound, and nearly free: the command already exists.

### P — hledger-web's JSON API as the Warrior app's ledger backend `[DOCUMENTED]`

Official `hledger-web` exposes a JSON API. This collapses a chunk of the planned
`server.py` extension work for the mobile app.

### Q — **Mode** as the bundling concept `[SPEC]`

A concept that surfaced from the ledger work but is **larger than the ledger**, and may
be the right home for several loose ends.

§6.5 verified that **a mode is, in part, a price table** — the same records valued
under different coefficients. But the idea generalises: a *mode* bundles

- a **coefficient/price table** (what matters here — `[VERIFIED]` as a mechanism),
- an **account/commodity template** (which units and accounts this domain uses),
- a set of **active services**,
- and — the new part — a set of **optional dependencies and capabilities**.

That last item resolves the ledger-cli question cleanly. ledger-cli is not required for
the weighted sum (§6.5), so it is no longer needed for the core. If some future mode
*does* need in-posting value expressions, **ledger-cli becomes an optional install
attached to that mode**, rather than a system-wide dependency everyone pays for.
Installing a mode installs what the mode needs.

This reframes "personal vs production" from two products, or even two configs, into
**one engine and a mode manifest**. It likely deserves its own design document; it is
recorded here because the ledger is where it became visible.

---

## 8. How it composes

The pieces are not a menu of features. They stack:

```
  Bitpads records / telemetry / timew intervals / agent actions
                          │
                     [H] import rules ──────────► declarative intake
                          │
                          ▼
              ═══════ THE JOURNAL ═══════          ← immutable record
              commodities [A] · conservation [B]      one format,
              assertions [D] · virtual postings [N]   three scopes [O]
                          │
                     [F] -O json                   ← one machine contract
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
   [E] valuation     [I] forecast      [M] roi
   at time T         periodic/auto     efficiency
        │                 │
        ▼                 ▼
   THE ATTENTION QUEUE            [J] agent budget +
   personal: "do this next"           audit + replay
   production: "3 machines need
   attention now"
        │
        ▼
   viz · stream · Warrior app [P] · loop-agent
```

The whole system has one shape: **record conserved flows in declared units; value them
at a time under a price table; act on what the valuation surfaces.**

Personal and industrial are the same engine with different coefficients. That is the
claim in one line.

---

## 9. Questions — resolved and open

Reviewed 2026-07-12. Four of the six original questions are now settled.

### Resolved

**Q1 — What is the second posting when you log an hour? → RESOLVED `[VERIFIED]`**
**An hour logged to a project accrues a liability against that project.** Logging 8h to
`time:project:ww` under an auto rule at a 15% coefficient derives `1.2 h` into
`backlog:tech-debt` automatically. Work does not merely consume time; it *creates
obligation*. That is the second posting, and it balances.

This also names what the ledger adds over TaskWarrior: **the ledger explodes a task
into the granularity the task only implies.** A task is one row. The hour spent on it
has structure — it consumed a session, produced output, and accrued debt — and the
journal can hold all of it.

**Q4 — Can hledger express a multi-factor weighted sum? → RESOLVED `[VERIFIED]`. YES,
natively.** Each factor is a commodity; the price table is the coefficient vector;
`balance -X att -S` is the ranked attention queue. **Not an hledger limitation.
ledger-cli is not required.** Full mechanism, reproduction and residual limits in §6.5.
The one thing a price table cannot do is a continuous nonlinear function of *now* —
that (and only that) needs a thin computation layer above the journal.

**Q5 — The hledger version floor. → RESOLVED (decision), pending implementation.**
Upgrade, pin, and **document a minimum required version**, then test for it at runtime.
The host's 1.25 is 27 releases stale and cannot support most of this document. Open
sub-question: bundled static binary vs. dependency-installer bump — a mechanism choice,
not a strategic one.

**Q6 — Does the computational surface break "direct file truth"? → RESOLVED
`[VERIFIED]`, with a hazard.**

The divergence is real and it is large. A journal whose literal text declares **two**
accounts reports **six** under `--auto --forecast`, including a `backlog:tech-debt`
never written and three future transactions that exist nowhere in the file.

But the divergence is **fully materialisable**: `hledger print --auto --forecast`
renders the computed truth back into plain journal text, which is itself a valid
journal. That is the reconciliation path, and it preserves the bar: *the file is truth;
computed views are projections; every projection can be rendered back to file-truth text
for audit.*

**The hazard `[VERIFIED]`: materialisation is NOT idempotent.** Write `print --auto`
output back into a journal that still contains the rule, and the rule fires again on the
posting it just created — `1.2 h` becomes `2.4 h`. **Policy: `print --auto` is a view
and an export, never a write-back.** Any ww verb that materialises must emit to a new
artifact, never into the source journal. This is a hard rule and it must be enforced in
`lib/ledger-dispatch.sh`.

### Open

**Q2 — The TimeWarrior ↔ ledger relationship. STILL OPEN — now the top question.**
Position taken: **some redundancy between the two stores is unavoidable and acceptable.**
TimeWarrior logs time against tasks and running intervals; the ledger captures the
exploded, structured consequences of that time (Q1). They are not competing stores of
the same fact; they are different resolutions of it.

What must still be nailed down: which is the **capture** surface and which the
**analytical** surface, in which direction data flows, what happens when they disagree,
and whether `timeclock`/`timedot` `[VERIFIED]` is the wire between them. Until this is
settled, nothing downstream should assume where time lives.

**Q3 — The registry: authoritative or advisory? And is it "commodity" or "unit"?**
A registry is agreed to be **needed**. Naming is unsettled — "commodity" is hledger's
word and carries financial baggage; **"unit registry"** may be the better name for a
system whose whole thesis is that units are general. (`config/units.yaml`.) The
authority question stands: if `stream` declares a unit the ledger has never seen, who
wins?

**Q7 (new) — Mode as a bundling concept.** Raised during review; see §7-Q. Likely needs
its own design document.

---

## 10. Sequencing candidates

Not a plan. Ordered by leverage-over-risk.

0. ~~Commit the untracked research report.~~ **Done** — now in `dev/reports/ledger-hledger/`.
1. ~~Settle Q4 (can a price carry a weighted sum?)~~ **Done — yes.** §6.5.
2. **Land `ledger-schema`** — rebase TASK-LED-004→011 onto the `dev/` layout. Nothing
   else can build on a stranded branch.
3. **Upgrade hledger, pin a minimum version, and test for it.** Hard prerequisite for
   almost everything above; the host's 1.25 supports none of §6.5.
4. **Settle Q2 — the TimeWarrior ↔ ledger relationship.** Now the top open question, and
   the gate on the first real domain. Nothing that touches time should be built until
   this is decided.
5. **Prove the spine on that domain**: unit registry (A) → time as a unit → the Q1
   liability accrual → an attention valuation over it (E/§6.5).
6. Then F (json contract) → J (agent audit + budget) → the rest.

**Enforcement rule to carry into implementation:** `print --auto` never writes back into
a source journal (Q6 hazard, double-counting). Encode in `lib/ledger-dispatch.sh`.

---

## Sources

**Internal:** `dev/docs/ledger-account-hierarchy.md` · `dev/docs/modular-journals.md` ·
`dev/reports/ledger-hledger/` (branch `agent/research/ledger-hledger-study`) ·
`system/logs/decisions.md` on `agent/builder/ledger-schema` (ledgers.yaml schema decision).

**External:** [hledger manual](https://hledger.org/hledger.html) ·
[hledger scripts & add-ons](https://hledger.org/scripts.html) ·
[hledger 1.52.1](https://github.com/simonmichael/hledger/releases/tag/1.52.1) ·
[ledger manual](https://ledger-cli.org/doc/ledger3.html) ·
[Bitpads universal-domain](https://bitpads.org/universal-domain.html).
