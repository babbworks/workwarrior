## TASK-LED-016: The accrual rule — work creates obligation (opt-in)

Goal:                 The second half of the conservation chain. LED-014 posts CAPACITY -> WORK.
                      This card posts WORK -> DEBT: an hour spent on a project accrues a liability
                      against that project.

                      VERIFIED (dev/reports/ledger-hledger/tests/run-valuation-tests.sh, V3):
                        = time:project
                            backlog:tech-debt          *0.15
                            time:accrued-review       *-0.15
                      8.0 h logged to time:project:ww derives 1.2 h into backlog:tech-debt.
                      It balances. This is the answer to "what is the second posting" at the
                      PROJECT level, and it was the user's own proposal.

Depends on:           TASK-LED-015 (postings must exist before rules can fire on them)
                      TASK-LED-013 (hledger >= 1.52)

Acceptance criteria:  1. An auto-rule file (`rules.journal`, included by the profile journal)
                         carrying the accrual rule, with the coefficient PER PROFILE (it is a
                         mode coefficient — see ledger-systems-accounting.md §6.5).
                      2. OPT-IN ONLY. hledger's `--auto` is a flag; reports are literal by
                         default. `ww ledger` verbs pass it through DELIBERATELY and never
                         implicitly. A user who does not ask for derived postings must never see
                         them.
                      3. `ww ledger report --auto` / `--forecast` expose the computed view.
                      4. **THE HAZARD, ENFORCED:** materialisation is NOT idempotent — feeding
                         `print --auto` output back into a journal that still holds the rule
                         fires it AGAIN (verified: 1.2h -> 2.4h). Therefore:
                         `print --auto` is a VIEW and an EXPORT, NEVER a write-back.
                         lib/ledger-dispatch.sh MUST refuse to write `--auto` output into any
                         file inside the profile's ledger tree. Assert with a test that ATTEMPTS
                         the write-back and expects refusal.
                      5. A `ww ledger explain` verb showing the materialised text
                         (`print --auto --forecast`) so a human can audit the divergence between
                         file truth and computed truth. Read-only, prints to stdout.
                      6. The accrual coefficient is documented, and set to 0 (inert) by default —
                         it must be a deliberate choice, not a surprise.

Write scope:          resources/                          (rules.journal template)
                      lib/ledger-dispatch.sh              (--auto passthrough + write-back refusal)
                      services/  or bin/ww                (ledger explain verb)
                      dev/tests/test-ledger-auto-rules.bats   (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-ledger-auto-rules.bats
                      bats dev/tests/            (full suite)
                      Manual: 8h posted -> `report --auto` shows 1.2h backlog:tech-debt;
                              `report` (no flag) does NOT.
                      Manual: attempt write-back of `print --auto` -> REFUSED (criterion 4).

Rollback:             git revert + set the coefficient to 0. Derived postings vanish from reports
                      instantly — they were never in the file.

Fragility:            MEDIUM-HIGH. Criterion 4 protects against a verified data-corruption bug.
                      Get it wrong and users silently double-count their own history.

Risk notes:           (Orchestrator) The write-back refusal is NOT optional and NOT advisory. We
                      reproduced the double-count locally: 1.2h became 2.4h. Any code path that
                      can pipe `print --auto` into a journal file in the ledger tree is a Gate B
                      failure.
                      (Builder) Opt-in means opt-in. Do not "helpfully" default --auto on.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
