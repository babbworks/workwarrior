## TASK-STRUCT-2: Consolidate the four overlapping entry docs

Goal:                 Give a newcomer (human or agent) one obvious "read this first" per
                      audience by reducing four overlapping orientation docs to a clear
                      canonical set with distinct jobs.

Depends on:           TASK-STRUCT-1B (dev/ must exist as the pointer target)

Acceptance criteria:  1. root `readme.md` renamed to `README.md` (git mv, convention-cased);
                         it is the public front door.
                      2. root `CLAUDE.md` remains a thin agent pointer and points at
                         `dev/ONBOARDING.md` (not dev/).
                      3. dev/README.md and dev/CLAUDE.md remain the canonical dev docs; no
                         content duplicated from the public README.
                      4. `git grep -n 'dev/context'` returns nothing (drift already fixed;
                         confirm still clean).
                      5. No dangling doc references introduced (grep the four docs for paths
                         that don't resolve).

Write scope:          README.md            (git mv from readme.md)
                      CLAUDE.md

Tests required:       Manual: verify each of README.md, CLAUDE.md, dev/README.md,
                        dev/CLAUDE.md opens and every relative path it names resolves
                      grep: `git grep -n 'dev/context'` -> empty

Rollback:             git mv README.md readme.md && git checkout CLAUDE.md

Fragility:            None. Low risk, docs-only.

Risk notes:           (Orchestrator) GitBook config fix (.gitbook.yaml points at root
                      whyworkwarrior.md/SUMMARY.md which live in docs/site/) is DEFERRED to
                      Part 4 — do not touch it here. Some tools/CI may reference readme.md
                      lowercase; grep before renaming.

Status:               complete
Taskwarrior:          (assign live TW id on dispatch) status:pending
