# Journal / JRNL Service — Excellence Audit

**Date:** 2026-07-13 · **Branch:** `agent/builder/struct-1b` (uncommitted) · **Production code changed:** none
**Full report:** `dev/reports/journal-jrnl/audit-2026-07-13.md`

---

## What I was asked to do

Audit the journal/notes service (jrnl) the way the ledger service is being audited — understand how
the tool ties into the CLI and browser, find where the good and bad code is, and assess our testing
and work processes for improvement.

## What I found in the code

**A live code-injection hole.** `ww journal write --journal <name>` interpolates the user's value
straight into Python source via an unquoted heredoc (`bin/ww:3586`, repeated at `:3672`). Nothing
validates it between the CLI flag and the interpreter. Reproduced: arbitrary Python executes as the
user. The same pattern needs sweeping across all 71 `python3` call sites in `bin/ww`.

**Two silent failures that corrupt the record without saying so.**
- `bin/ww:3603` — any exception during journal resolution silently redirects the entry to
  `default.txt`. You ask for `--journal work`, get no warning, and your entry is in the wrong file.
- `server.py:2003` — `except Exception: pass` falls through to a lossier parser that drops every
  annotation while still answering `200 {"ok": true}`. The browser renders a journal that looks
  complete and has quietly lost data. That endpoint is *currently failing* in the suite.

**No contract, no service directory.** Journal is the only capability without `services/journal/` —
it lives inside a 6,472-line `bin/ww`. The jrnl entry grammar is re-implemented in four files with
no normative schema. Ledger has `ledgers-yaml-v1.md`; there is no `journals-yaml-v1`. Until there
is, "improve the syntax" has nothing to be correct against. Also: `create-new-template-jrnl.sh`
exists at three byte-identical paths — nobody knows which one is live.

## What I found about our testing

**The real baseline is 665 tests / 601 pass / 64 fail.** The docs claim `~19`, `~29`, and `60/605` —
in three places, naming three *different* sets of failing files. A Verifier following
`dev/tests/CLAUDE.md` today would clear a genuine regression as "baseline."

**The test index is a hand-maintained table and it has drifted in every dimension.** It claims
"~450 tests across 26 files"; there are 665 across 42. Thirteen files — 187 tests, 28% of the
suite — do not appear in it at all, including two of the five journal suites.

**The sharpest finding:** the 5 dedicated journal suites are **88/88 green** while the service has a
code-injection hole. Eighty-eight passing tests protect the paths nobody was worried about. Green
told us nothing, because nothing told us what the tests *cover*.

`dev/CLAUDE.md` already diagnosed this class of bug in its own words — *"Never hand-maintain a
mirror of a fact that lives in 145 other files. It will drift."* That was written about task cards,
and the cure was `wwctl index`, which **generates** the index. Nobody applied the same cure to tests.

## The plan (7 cards, proposed — not started)

| # | Card | Goal |
|---|---|---|
| 1 | `TASK-JRN-001` | Kill the injection — quoted heredocs, values via `argv`; sweep all 71 sites |
| 2 | `TASK-TEST-002` | One measured baseline + `wwctl baseline --check`; delete the three stale figures |
| 3 | `TASK-TEST-001` | `@covers:`/`@purpose:` tags in each `.bats`; generated `dev/tests/INDEX.md`; `select-tests.sh` becomes a query over tags, not a hardcoded matrix |
| 4 | `TASK-JRN-002` | `journals-yaml-v1` + `journal-entry-v1` — the contract |
| 5 | `TASK-JRN-003` | Replace silent fallbacks with typed errors (exit 1 user / exit 2 system) |
| 6 | `TASK-JRN-004` | De-duplicate templates, fix 4× `#!/bin/bash`, route 120 raw `echo` through the logging lib |
| 7 | `TASK-JRN-005` | Extract journal from `bin/ww` into `services/journal/` — last, once it is safe |

Full-suite-before-merge stays untouched. The tag work only speeds the inner loop (88 tests instead
of 665) and — more importantly — makes *"what has no test coverage at all?"* a question with an
answer.

## Open decisions (Orchestrator only — I will not self-approve these)

1. **Branch** — this work is uncommitted on `agent/builder/struct-1b`, another agent's stream.
   Move to `agent/research/journal-jrnl-audit`?
2. **Ownership** — the `TASK-TEST-*` cards touch `dev/`, which another session owns. Write them, or
   hand the findings over?
3. **Priority** — does `JRN-001` jump Phase 0? A proven injection hole on a shipped CLI arguably
   outranks LED-012/013/SHIP-001.
