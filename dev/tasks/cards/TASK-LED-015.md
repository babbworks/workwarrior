## TASK-LED-015: ww ledger sync-stream — the derived journal (regenerate, never append)

Goal:                 Project stream.log into hledger. `derived/stream.journal` is a PURE
                      FUNCTION of stream.log: regenerate it wholesale, never append to it.
                      The manual journal (money, materials — things that do not punch in) stays
                      hand-written and separate. hledger `include`s both. Divergence becomes
                      impossible because the two files never hold the same fact.

Depends on:           TASK-LED-014 (the posting shape must be normative first)
                      TASK-LED-013 (hledger >= 1.52)

Design:               decisions.md 2026-07-13 (capture -> record -> interpret)
Contract:             dev/schemas/punch-posting-v1.md (LED-014)

Layout:               profile.journal
                          include manual.journal            ; human-written. NEVER generated.
                          include derived/stream.journal    ; GENERATED. NEVER hand-edited.

Acceptance criteria:  1. `ww ledger sync-stream` reads stream.log and REGENERATES
                         `<profile>/ledgers/derived/stream.journal` in full.
                      2. IDEMPOTENT: running it twice produces a byte-identical file. Running it
                         ten times produces the same balances. **Assert this in a test.**
                         (This is the structural answer to the Q6 double-count hazard — the 1.2h
                         -> 2.4h bug happened because derived postings were APPENDED into a file
                         that still carried the rule. Regeneration cannot double-count.)
                      3. The generated file carries a DO-NOT-EDIT header naming the generator
                         and the source log.
                      4. It NEVER writes to manual.journal, and never to the profile's main
                         journal beyond ensuring the two `include` lines exist.
                      5. Open punches (no `B stop`) are EXCLUDED — an unfinished interval has no
                         duration and cannot be posted. They live on the board (STRM-004), not in
                         the journal.
                      6. Reconciled punches are posted WITH their reconciliation tag (LED-014 §4).
                      7. `hledger -f profile.journal check` passes on the combined result.
                      8. Round-trip: N punches in stream.log -> N transactions -> total hours in
                         `balance` equals the sum of interval durations. Assert numerically.
                      9. `--dry-run` prints the journal to stdout without writing.

Write scope:          services/custom/ or bin/ww          (the sync-stream verb)
                      lib/ledger-dispatch.sh              (verb registration)
                      dev/tests/test-ledger-sync-stream.bats  (new)

Tests required:       bats dev/tests/test-smoke.bats
                      bats dev/tests/test-ledger-sync-stream.bats
                      bats dev/tests/            (full suite)
                      Manual: sync twice -> byte-identical (criterion 2).
                      Manual: 40-concurrent-actor fixture -> hours reconcile (criterion 8).

Rollback:             git revert + rm derived/stream.journal. The derived file is disposable BY
                      DESIGN — that is the entire point. Nothing is lost; stream.log is the truth.

Fragility:            MEDIUM. Writes into profile ledger directories. It must NEVER touch
                      manual.journal — a generator that clobbers hand-written financial records
                      would be the single worst bug this system could have. Guard it explicitly.

Risk notes:           (Orchestrator) THE RULE: derived artifacts are REGENERATED, never appended
                      to. This is the generalisation of the verified Q6 hazard, and it is what
                      makes the redundancy safe — the derived journal is a cache of stream.log,
                      not a second truth.
                      (Builder) Criterion 4 is a hard boundary. Write ONLY to derived/. Assert it
                      in the test by making manual.journal read-only in a fixture and confirming
                      sync still succeeds.

Status:               pending
Taskwarrior:          (assign live TW id on dispatch)
