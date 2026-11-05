# Lens mathematics and qualification

5 November 2026 · TASK-OPS-001 / NA-367 · scoped operations implementation only.

The inventor names preserve the project's lineage. The method identifier is the executable mathematical definition. Names do not establish fidelity to an inventor's historical apparatus or validate a model of human work. This document separates computational correctness, distinct information content and external meaning. Tests qualify the first within their stated scope; no claim of formal verification or empirical construct validation is made.

## Common input contract

Let E be the currently recorded, issuer-scoped event set. Each event has a unique identity, sequence, organization/instance/profile, occurred time, recorded time, category, producer, actor, object and typed data. Duplicate event identities and mixed scopes are refused. All instants are normalized to UTC at microsecond precision. Ordering is by occurred time, then native sequence for ties; it is not lexical ordering of timezone strings.

The selection W is [start,end), optionally intersected with occurred_at <= as_of, actor and object filters. `as_of` is an event-time cutoff using current knowledge, not a historical recorded-knowledge cutoff. Late arrivals can therefore change an old period's result. Input hash/cursor and method identify that change. A future bitemporal replay needs a separate recorded-time cutoff.

Eligible activity A is the observation-category subset of W. Administrative and derived events remain inspectable but do not feed count/rate/signal calculations. This prevents measurement outputs from generating their own apparent input activity. Eligibility still depends on correct source classification; the system cannot prove a source supplied truthful labels or complete events.

Interval reconstruction first consumes complete eligible native history up to as_of, then applies overlap clipping and subject filters. It does not discard starts preceding the requested window. Foreign producer payloads cannot imitate native start/finish semantics. Baldwin and Frick object filters target changed snapshot identities, including assignment changes emitted by an attempt event. Interval subject filters accept attempt or assignment identity. Other object filters match the event object. Native assignments validate their own transitions; a lens does not confer authority.

## Distinction and definitions

| Lens / method | Exact quantity or transformation | Units / preservation | Important limits and tests |
| --- | --- | --- | --- |
| Burroughs `scoped-events/v1` | Ordered selected events, including all categories | Original event identity/data retained | Inspection, not a scalar metric. Count is conserved; no truncation in provider result. |
| Baldwin `object-field-deltas/v2` | Recursive object-field comparison of native before/after snapshots. Arrays are atomic. JSON pointer escaping; add/remove/replace distinguish missing, null and typed values. | Structural changes, not physical units | Tests distinguish absent/null and true/1. A structural delta does not establish semantic consequence or undo an external effect. |
| Frick `native-state-transitions/v2` | Changed native assignment/attempt state pairs (before state, after state), including creation from absent state; unchanged heartbeats excluded | Categorical transition history | A projection of transitions, not a second state-machine validator. It overlaps Burroughs but focuses on transition semantics. |
| Bundy `attempt-actor-wall-unions/v2` | For each attempt i, L_i = [max(start_i,start), min(end_i or as_of,end)). Discard empty intersections. T_attempt = sum length(L_i). T_actor = sum over actors length(union L_i for actor). T_wall = length(union all L_i). Peak is maximum overlapping attempt count, with adjacent endpoints treated half-open. | Exact integer microseconds internally; seconds for display. T_wall <= T_actor <= T_attempt. | Tests compare 100 seeded interval populations against an independent discrete-time oracle, verify microsecond partition additivity and shared-actor overlap. Time measures participation, not useful effort. Cancellation requests do not close intervals. |
| Board `open-attempts/v2` | Starts without finish at as_of; elapsed = as_of - start, heartbeat age = as_of - last recorded heartbeat | Seconds, separate per attempt | Snapshot at as_of. Optional window filters open interval overlap. Age is not proof of process liveness, health or productive work. |
| Felt `eligible-hour-count/v1` | n_b = number of A in epoch-aligned UTC hour b | Events per explicit hourly bin; empty bins omitted | Conserves eligible event count. Raw count is not a continuous density estimate. Partial selected hours retain their counts without inventing exposure completeness. |
| Felt `hourly-count-first-difference/v1` | Delta n_b = n_b - n_(b-1) | Events per bucket-step; step 3600 s | Requires explicit full UTC-hour bounds, maximum 10000 bins; absent logged events yield count zero, with source completeness unknown. First output is null, not an invented initial difference. |
| Grant `operational-counts/v1` | Counts by event type, started/finished attempts, and succeeded finish events in A | Event counts | Aggregates overlap Felt. Finished/started within a window is not a cohort completion probability. A successful execution is not an accepted finding or publication. |
| Grant `hourly-count-second-difference/v1` | Delta² n_b = n_b - 2n_(b-1) + n_(b-2) | Events per bucket-step squared | Same bounded grid as Felt difference. First two values null. Counts [1,4,9,16] give [null,null,2,2]. This is not automatically physical acceleration of an arrival rate or business outcome. |
| Dey `rate-type-entropy-features/v2` | In each nonempty UTC 300 s bin: n; rate n/300; richness k; p_j = n_j/n; H = -sum p_j log2 p_j; evenness H/log2(k), with evenness 0 for k=1. | Events/s, type count, bits, dimensionless evenness | 0 <= H <= log2(k). Count in a partly selected bin still divides by fixed 300 s, explicitly a coarse-bin rate. Sparse omitted bins do not imply downtime. No arbitrary cognitive stability/fragmentation coefficients. Experimental descriptive features, not a validated model of work. |
| Cooper `utc-rate-polar/v2` | Uses the identical Dey samples. theta = 2pi * UTC seconds-of-day / 86400; r = Dey events/s; x=r cos(theta), y=r sin(theta). | Radians; radius and x/y in events/s. No result-dependent normalization. Full dates retained. | Tests verify norm(x,y)=r, identical daily angles with distinct dates, and absolute 2:1 rate preservation. A rendering, not independent corroboration or the proposed composite geometric field. |
| Hollerith `all-event-ids-per-cell/v1` | Partition W by UTC hour and native object; retain every cell event reference | Categorical matrix, all selected event identities | Conservation test: sum cell cardinalities equals selected events. It indexes Burroughs's input rather than independently measuring it. |
| Pacioli `event-count-not-signed-balance/v1` | Per-object prefix sum of 1 over W in event-time order | Events; prefix starts at zero at selected window | Counts [1,2,...] over selected history. Not signed arithmetic, lifetime opening balance, currency accounting or double-entry. Actual resource ledger remains separate. |

The alternative Felt/Grant methods retain the recovered difference-engine design beside the installed count interpretation. Choosing one requires its explicit method identifier; the meanings are not quietly interchanged. Historical synthesis material is design evidence, not proof that the original implementations used these formulas correctly.

## What is and is not independent

Burroughs, Frick and Hollerith are complementary inspections/indexes over related records. Baldwin adds version comparison. Board and Bundy reconstruct state and intervals. Felt and Grant aggregate; Pacioli accumulates. Dey transforms observed distributions into declared features; Cooper renders those features. A pipeline can compose these views, but their agreement is not independent confirmation when they share inputs.

No requirement says all names must be independent scalar measurements. Their distinct roles should determine composition. We specifically do not force invented mathematics onto an inspection lens to make it appear more sophisticated.

## Remaining qualification work

- Source coverage manifests, clock accuracy/skew, dropped-input accounting, clock corrections and data-retention gaps. Deterministic arithmetic over incomplete logs can still mislead.
- Recorded-time cutoffs for strict historical-knowledge replay; correction/retraction events with declared semantics rather than destructive edits.
- Empirical calibration and baselines for any claim about workload, concentration, fatigue, value or anomaly. No such inference drives automatic actions here.
- Outcome/cohort metrics bound to actual MAKE digest/Join decisions and costs with verified denominators, units and measured/reported/estimated basis.
- Resource-ledger accounting validation; Barrels/composition lineage; longitudinal Regeneration definitions and testing. They are not hidden inside Dey or Pacioli.
- Independent technical review, formal proof where worthwhile, and production comparison against real known examples. These local tests are not that sign-off.

## Anchors and reproducible checks

The uncertainty discipline follows the distinction between a defined measurand, measurement model and uncertainty, described by [NIST](https://www.nist.gov/itl/sed/topic-areas/measurement-uncertainty). The entropy formula is the discrete empirical-distribution use of [Shannon's original paper](https://www.nokia.com/bell-labs/publications-and-media/publications/a-mathematical-theory-of-communication/); it does not license psychological interpretation of event-type entropy. Neither source validates our organization's features or instrument coverage.

The alternate difference definitions are documented in the project's [Babbage–Lovelace framework](https://github.com/babbworks/ww-standard/blob/96cb9f84e70ef9d98a86bad6f2d57d95892dc253/times-research/babbage-lovelace-framework.md). Its broader approximation/automation claims are not adopted as mathematical guarantees.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s dev/tests -p test_lens_mathematics.py -v
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s dev/tests -p test_operations.py -v
```

Tests use synthetic isolated inputs only. No benchmark here evaluates quality of WNY research or completeness of real company operations.
