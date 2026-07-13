## TASK-LED-014: Actor accounts + the punch posting shape

Goal:                 Define how a punch becomes a journal transaction. This is the card that
                      answers "what is conserved" — and the answer is: AN ACTOR'S HOURS.

                      dev/docs/ledger-account-hierarchy.md predates the actor axis and has no
                      `actors:` tree. It declares commodities (h, sess, $) and a time:/sessions:/
                      costs:/output:/backlog: hierarchy, but nothing that can act. Fix that.

Depends on:           TASK-STRM-003 (events carry ctx.actor)
                      TASK-LED-012  (ledger module landed)

Design:               dev/docs/ledger-systems-accounting.md §6 (valuation), Q1 (the liability)
                      decisions.md 2026-07-13 (capture -> record -> interpret)

The posting shape:    2026-07-12 punch  human:op-03 -> lathe-01
                          time:project:line-a         2.25 h
                          actors:human:op-03         -2.25 h

                      THE ACTOR IS THE SOURCE ACCOUNT. Time flows FROM an actor's capacity INTO
                      the work. Actor accounts run NEGATIVE — structurally like income accounts
                      in finance. Sigma = 0. There are finite hours in a person, a shift, an
                      agent's budget: that is the conservation law, and it is real.

Acceptance criteria:  1. dev/docs/ledger-account-hierarchy.md gains an `actors:` tree:
                         actors:human:<id> · actors:agent:<id> · actors:machine:<id>
                         with the source-account semantics stated explicitly (they run negative,
                         and WHY).
                      2. The punch -> transaction mapping is specified normatively: which stream
                         fields map to which posting, how object maps to the target account, how
                         ctx.proj participates.
                      3. Commodity for punch time is `h`, consistent with the existing hierarchy.
                      4. Reconciled punches (ctx.reconciled, schema §5) are marked in the
                         journal — a reconciled interval MUST be distinguishable from a real one
                         forever. Use a tag (`; reconciled:by=...`) — NOT a different account.
                      5. Account-name derivation is DETERMINISTIC and documented: the same stream
                         event always yields the same account names. (TASK-LED-015 depends on
                         this being a pure function.)
                      6. A worked example journal committed under dev/reports/ or as a fixture,
                         and it must `hledger check` clean.
                      7. NO CODE. This card is spec + doc only. LED-015 implements it.

Write scope:          dev/docs/ledger-account-hierarchy.md
                      dev/schemas/punch-posting-v1.md     (new — the normative mapping)

Tests required:       Manual: the worked-example journal passes `hledger check` and `hledger
                      balance` shows actors negative, time:project positive, total zero.

Rollback:             git revert. Docs only.

Fragility:            LOW (no code) but HIGH LEVERAGE — LED-015/016 both build on this mapping,
                      and getting the conservation direction wrong (actor positive instead of
                      negative) inverts every downstream report.

Risk notes:           (Orchestrator) This resolves open question B of ledger-systems-accounting.md
                      ("what is the second posting?") at the ACTOR level. We could only reach this
                      answer because the actor axis exists — the stream and ledger threads
                      genuinely needed each other. Update §9 of that doc when this lands.
                      (Builder) Do not conflate this with the ACCRUAL rule (LED-016). Capacity ->
                      work is this card. Work -> debt is that one. Two separate postings, two
                      separate cards.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
