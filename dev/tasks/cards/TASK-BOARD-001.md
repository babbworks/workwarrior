## TASK-BOARD-001: Reconcile the backlog and make tasks/INDEX.md a generated artifact

Goal:                 The board had drifted from the cards. Restore the cards as the single
                      source of truth for task status, close everything already shipped, and
                      remove the mechanism that let the drift happen — by generating
                      tasks/INDEX.md instead of maintaining it by hand, and by making an
                      unparseable card a hard error rather than a silent omission.

Background:           Audit of all 145 cards against the running system (2026-07-13).
                      Root cause: `wwctl task-status` parsed `grep "^Status:" | awk '{print $2}'`.
                      Three card formats existed — 130 canonical, 12 YAML frontmatter
                      (`status: pending`), 3 bold markdown (`**Status:** complete`). The 15
                      non-canonical cards were SILENTLY SKIPPED, and those are exactly the 15
                      that had gone missing from INDEX.md. Four of them carried two
                      contradictory status fields at once (frontmatter `pending` + body
                      `## Status: complete — 2026-04-27`).
                      Full write-up: logs/decisions.md 2026-07-13.

Acceptance criteria:  1. All 145 cards carry exactly one canonical `^Status:` line.
                         VERIFIED: `wwctl index` parses 145/145, zero unparseable.
                      2. tasks/INDEX.md is generated, not hand-written, and carries a
                         DO-NOT-EDIT header. VERIFIED.
                      3. `wwctl index --check` exits 1 when a card Status changes without
                         regeneration. VERIFIED both directions (flipped SITE-040 -> FAIL;
                         restored -> PASS).
                      4. gen-index.sh REFUSES to write a partial index if any card is
                         unparseable, and names the offenders. VERIFIED — caught the 3
                         bold-markdown cards on first run.
                      5. Every card closed by this task is closed against evidence recorded
                         in its own Closure note. VERIFIED — 12 cards.
                      6. The word "phase" has exactly one meaning across TASKS.md and
                         ONBOARDING.md. VERIFIED.
                      7. No prose lost in card normalisation. VERIFIED — word-level diff of
                         all 12 rewritten cards; only structural tokens (---, frontmatter
                         keys, section headings) removed.

Write scope:          dev/scripts/gen-index.sh                (new)
                      dev/bin/wwctl                           (add `index` subcommand + usage)
                      dev/tasks/INDEX.md                      (now generated)
                      dev/TASKS.md                            (retire 5 legacy queues; plan only)
                      dev/ONBOARDING.md                       (phase + source-of-truth section)
                      dev/CLAUDE.md                           (canonical task source section)
                      dev/logs/decisions.md                   (decision entry)
                      dev/tasks/cards/*.md                    (15 normalised; 12 closed; 1 rescoped)

Tests required:       bash dev/bin/wwctl index --check        (must PASS)
                      bats dev/tests/test-smoke.bats          (must be at baseline)
                      bats dev/tests/                         (full suite — at/above baseline)
                      Manual: ww warrior summary | ww projects | ww network  (the 3 SVC closes)

Rollback:             git checkout dev/  — every change is in dev/ (the control plane).
                      NOTHING under bin/, lib/, services/, or profiles/ was touched, so no
                      product behaviour can regress. The 12 closed cards are text-only.

Fragility:            None. Zero production code touched — dev/ control plane only.
                      NOT SERIALIZED (bin/ww untouched), NOT HIGH FRAGILITY (no lib/, no sync).

Risk notes:           (Orchestrator) The real risk was silently losing prose while rewriting 12
                      rich markdown cards into the canonical column format. Mitigated by a
                      word-level set-difference check of every card before/after; the only
                      tokens dropped were structural (frontmatter delimiters, keys, and the
                      heading words that BECAME field labels). Backups in scratchpad.
                      Second risk: closing a card that is not actually done. Mitigated by
                      refusing to close on the card's own say-so — every close is backed by
                      executing the command or grepping for the named artifact. SITE-040 was
                      checked the same way and left OPEN because it genuinely is.
                      Live TaskWarrior data deliberately NOT mutated (hard rule 1). The
                      `wwdev task <id> done` calls for the 12 closed cards are listed in
                      TASKS.md as an operator follow-up.

Status:               complete — 2026-07-13

Completion note:      145 cards audited. 12 closed against verified evidence (SITE-001, WEB-001,
                      SVC-009, SVC-010, SVC-011, RES-001, RES-002, SITE-041, SITE-042, LED-002,
                      LED-003, EXT-GUN-001-EXPLORE). 1 rescoped (COMM-009 — 5 of 6 criteria were
                      already live; only `community export --format html|json` remains).
                      Backlog: ~40 nominally-open -> 23 pending + 2 verified. 117 complete.
                      Five overlapping queue tables retired. INDEX.md now generated.

Taskwarrior:          wwdev task (unassigned) status:completed
