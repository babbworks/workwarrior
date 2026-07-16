## TASK-LED-018: Counterfactual valuation — dated weight history + --value=DATE,att

Goal:                 Complete criterion 3 of LED-017. Today actor weights are a single static
                      value in profiles/<name>/actors.yaml. For `--at DATE` to actually REORDER
                      the attention queue, weights must have a dated history — the same records
                      valued under last month's coefficients vs today's coefficients must
                      produce different rankings.

                      The mechanism is already verified (dev/docs/ledger-systems-accounting.md
                      §6.5 V2): hledger's `P` directives are piecewise-constant between dates.
                      `--value=2026-03-01,att` picks the price active on that date.

                      What's missing: a persistent weights.journal that accumulates dated P
                      directives every time a weight changes, and wiring `--value=DATE,att`
                      through hledger in the attention verb.

Depends on:           TASK-LED-017 (the attention queue must exist — complete)

Design:               dev/docs/ledger-systems-accounting.md §6.5 (V2 — time-varying reorder)

Acceptance criteria:  1. A `weights.journal` file per profile accumulating dated P directives.
                         Format: `P YYYY-MM-DD <actor_factor_commodity> <weight> att`
                         One line per weight change, never rewritten — append-only history.
                      2. `ww ledger attention --at DATE` passes `--value=DATE,att` to hledger
                         (or equivalent), causing hledger to use the coefficient active on that
                         date rather than the current one.
                      3. REORDER TEST: change a weight on a known date, then prove that
                         `--at <before>` and `--at <after>` produce different top-1 rankings
                         from the same immutable records. This is the V2 result from §6.5.
                      4. `ww stream actor set-weight <id> <new-weight>` (or similar) appends
                         the dated P directive AND updates the static actors.yaml. The two
                         must not drift — the static value is "current weight" and the journal
                         is "weight history".
                      5. `--at` without a weights.journal gracefully falls back to current
                         static weights (backward-compatible with LED-017 as shipped).
                      6. KNOWN LIMIT, documented: a P directive is piecewise-constant. It
                         cannot express a continuous nonlinear function of `now` (e.g.
                         TaskWarrior's due-date proximity curve). If such a factor is needed,
                         compute it above hledger and post it as a factor commodity. This is
                         the ONLY place a computation layer above the journal is unavoidable.

Write scope:          services/stream/attention.py          (--at -> --value=DATE,att passthrough)
                      lib/actor-registry.sh                 (set-weight appends P directive)
                      profiles/<name>/ledgers/weights.journal (new — append-only)
                      dev/tests/test-ledger-attention-counterfactual.bats (new)

Tests required:       bats dev/tests/test-ledger-attention-counterfactual.bats
                      bats dev/tests/test-ledger-attention.bats (no regressions)
                      Manual: change weight, --at before vs --at after -> different top-1

Rollback:             git revert. Attention queue still works with static weights.
                      weights.journal is disposable — regenerable from actors.yaml git history.

Fragility:            LOW. Read-only reporting; no production data modified.

Risk notes:           (Orchestrator) This is the audit primitive the loop-agent needs. An agent
                      acting autonomously while the user is away needs its decisions REPLAYABLE
                      at the valuation that was true at decision time, not re-litigated against
                      today's numbers. Not urgent until the agent is live.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
