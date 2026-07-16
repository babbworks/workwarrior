## TASK-LED-017: The attention queue — value every account in a synthetic commodity

Goal:                 The payoff. "Which 3 machines need attention now" and "which task next" are
                      THE SAME QUERY: a valuation report over a synthetic commodity.

                      VERIFIED (dev/reports/ledger-hledger/tests/run-valuation-tests.sh, V1/V2):
                      each factor is a commodity; the PRICE TABLE IS THE COEFFICIENT VECTOR;
                      `hledger balance factors -X att -S` converts every factor by its weight,
                      sums them, and returns a ranked list. Values match hand-calculation exactly.
                      **This is not an hledger limitation and ledger-cli is NOT required.**

Depends on:           TASK-LED-015 (postings exist)
                      TASK-LED-013 (hledger >= 1.52 — 1.25 cannot do this)
                      TASK-STRM-002 (actor `weight` lives in profiles/<n>/actors.yaml)

Design:               dev/docs/ledger-systems-accounting.md §6.5 (mechanism + reproduction)

Acceptance criteria:  1. `ww ledger attention [--profile P] [--top N] [--at <date>]` emits a
                         ranked list, highest attention-value first.
                      2. The coefficient table is GENERATED from the profile's actor weights
                         (profiles/<n>/actors.yaml, schema actors-v1 §6) into `P` price directives
                         in a weights journal. Coefficients are DATA, not code — dated, diffable,
                         inspectable. A user must be able to ask WHY something ranks high and get
                         a traceable answer (unlike TaskWarrior's opaque urgency float).
                      3. `--at <date>` performs COUNTERFACTUAL valuation via `--value=<date>,att`.
                         VERIFIED that this REORDERS the ranking: the same immutable records
                         produce a different priority order depending on the date valued at.
                         "Was that genuinely the top priority when we decided, or only in
                         hindsight?" must be answerable. This is the loop-agent's audit primitive.
                      4. `--format json` — the contract the browser panel and Warrior app consume.
                      5. Switching profiles switches the coefficient table (a MODE IS A PRICE
                         TABLE). Same records, different weights, different ranking. Prove with a
                         two-profile fixture.
                      6. KNOWN LIMIT, documented not worked around: a price is piecewise-constant
                         between dated `P` directives. It CANNOT express a continuous nonlinear
                         function of `now` (e.g. TaskWarrior's due-date proximity curve). If such
                         a factor is needed, compute it ABOVE hledger and post it as a factor
                         commodity. This is the ONLY place a computation layer above the journal
                         is unavoidable — do not build one until a real factor demands it.

Write scope:          services/  or bin/ww                    (attention verb)
                      lib/ledger-dispatch.sh                  (verb registration)
                      lib/actor-registry.sh                   (weights -> P directives)
                      dev/tests/test-ledger-attention.bats    (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-ledger-attention.bats
                      bats dev/tests/            (full suite)
                      Manual: reproduce V1 (weighted sum matches hand-calc) and V2 (time-varying
                              coefficients reorder the queue) through the ww verb, not raw hledger.

Rollback:             git revert. Read-only reporting verb; nothing written.

Fragility:            LOW (read-only) but the MOST VISIBLE feature in the program. A wrong ranking
                      is worse than no ranking — it directs a human's attention incorrectly.
                      Criterion 2 (traceability) is what makes a wrong answer debuggable.

Risk notes:           (Orchestrator) This card is mostly plumbing — the MECHANISM IS ALREADY
                      VERIFIED. Do not re-derive it. What must be got right is that coefficients
                      stay DATA (criterion 2) and that the counterfactual axis is exposed
                      (criterion 3), because that is what the agent-supervision story needs.
                      This unifies the "invariant engine" idea into valuation: a failed assertion
                      is just an account with a very high attention-value.

Status:               complete
Taskwarrior:          (assign live TW id on dispatch)
