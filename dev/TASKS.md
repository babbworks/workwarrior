# TASKS.md — Workwarrior Canonical Task Board

**This board is the curated PLAN: priority, sequence, and why. It is not the status ledger.**
**The status ledger is each card's `Status:` field in `tasks/cards/`. That is the only source of truth.**
**`tasks/INDEX.md` is GENERATED from those cards (`wwctl index`) — never hand-edit it.**
**Orchestrator is the only agent that updates status fields.**

Last updated: 2026-07-15 (THE PROGRAM complete: Phases 0–4 all landed. LED-017 attention queue shipped with 27 BATS tests.)
Current phase: **Program complete.** All four phases of the capture→record→interpret pipeline landed.

> **On the word "phase".** It used to mean three different things in this file. It now means
> exactly one: a stage of THE PROGRAM below (Phase 0 → Phase 4). The old project phases
> ("Phase 1 = Explorer audits, Phase 2 = implementation") are historical and closed — they are
> preserved under "Historical phases (closed)" at the bottom and are **not** a live queue.

---

## Active Tasks

| ID | Status | Goal |
|---|---|---|
| _(none)_ | — | Phase 4 complete. Reviewing DEPS-001 and remaining backlog |

---

## THE PROGRAM: capture → record → interpret

One engine that records conserved flows in declared units, values them at a time under a coefficient table, and acts on what the valuation surfaces. **Personal productivity and industrial operations are the same system with different coefficients** — verified, not aspirational (`docs/ledger-systems-accounting.md` §6.5).

```
CAPTURE                  RECORD                      INTERPRET
timew (a card)  ──┐
agents          ──┼──►  STREAM (the clock)  ──►  HLEDGER (the journal)
machines        ──┤     append-only, all actors    conservation · valuation
manual punches  ──┘     B start / B stop           attention ranking
```

One direction, never backwards. **Every redundant store is a pure function of the append-only log** — timew is a cache of Stream, `derived/stream.journal` is a cache of Stream. Redundancy without forks.

**Phase 0 ✅ → Phase 1 ✅ → Phase 2 ✅ → Phase 3 ✅ (foundation) → Phase 4 ✅.**

---

## Phase 0 — clear the decks ✅ COMPLETE

All computational prerequisites landed 2026-07-14.

| ID | Status | Goal | Depends On | Notes |
|---|---|---|---|---|
| [TASK-LED-012](tasks/cards/TASK-LED-012.md) | **complete** | Land `ledger-schema` — rebase TASK-LED-004..011 onto `dev/` layout | STRUCT-1B | Landed. Ledger suites running on the dev/ layout |
| [TASK-LED-013](tasks/cards/TASK-LED-013.md) | **complete** | hledger version floor — upgrade, pin ≥1.52, guard at runtime | — | Floor enforced. Host at 1.52.1. All valuation tests passing |
| [TASK-SHIP-001](tasks/cards/TASK-SHIP-001.md) | pending | Ship `dev/` with workwarrior | STRUCT-1B | Independent. Still needs merge of STRUCT-1B |

---

## Phase 1 — identity: the actor axis ✅ COMPLETE

Spec: `specs/2026-07-12-stream-actor-axis-design.md`. Contracts: `schemas/stream-event-v1.md`, `schemas/actors-v1.md`.
All five cards landed 2026-07-15 in a single streak. Full BATS coverage at `dev/tests/test-stream-*.bats`.

| Order | ID | Status | Goal | Notes |
|---|---|---|---|---|
| 1 | [TASK-STRM-001](tasks/cards/TASK-STRM-001.md) | **complete** | Schema v1 marker + actor.sh resolution lib | test-stream-schema.bats, test-stream-actor.bats |
| 2 | [TASK-STRM-002](tasks/cards/TASK-STRM-002.md) | **complete** | Actor registry `config/actors.yaml` + owning module | lib/actor-registry.sh, test-actor-registry.bats |
| 3 | [TASK-STRM-003](tasks/cards/TASK-STRM-003.md) | **complete** | Emit the actor axis: punch verbs + adapter enrichment | test-stream-punch.bats, test-stream-ingest-dedup.bats |
| 4 | [TASK-STRM-004](tasks/cards/TASK-STRM-004.md) | **complete** | The board — who/what is currently IN | test-stream-board.bats |
| 5 | [TASK-STRM-005](tasks/cards/TASK-STRM-005.md) | **complete** | Reconciliation — close missed punch-outs | test-stream-reconcile.bats |

---

## Phase 2 — the bridge: capture → record ✅ COMPLETE

Decision: `logs/decisions.md` 2026-07-13. Landed 2026-07-15.

| ID | Status | Goal | Notes |
|---|---|---|---|
| [TASK-STRM-006](tasks/cards/TASK-STRM-006.md) | **complete** | `timew` on-modify hook — live card reader, not a store | test-stream-timew-hook.bats. Hook/adapter tuple parity verified (criterion 5) |

---

## Phase 3 — the journal: record → interpret ✅ COMPLETE

Keystone (UNIT-001) landed 2026-07-15. LED-014/015/016 all landed same day.

| ID | Status | Goal | Depends On | Notes |
|---|---|---|---|---|
| [TASK-UNIT-001](tasks/cards/TASK-UNIT-001.md) | **complete** | The unit registry — the system's shared vocabulary of quantity | — | config/units.yaml + lib/unit-registry.sh + test-unit-registry.bats |


| ID | Status | Goal | Depends On | Notes |
|---|---|---|---|---|
| [TASK-LED-014](tasks/cards/TASK-LED-014.md) | **complete** | Actor accounts + the punch posting shape | STRM-003, LED-012 | dev/schemas/punch-posting-v1.md normative |
| [TASK-LED-015](tasks/cards/TASK-LED-015.md) | **complete** | `ww ledger sync-stream` — the derived journal | LED-014, LED-013 | 21 BATS tests passing. Idempotent, conservation-law verified |
| [TASK-LED-016](tasks/cards/TASK-LED-016.md) | **complete** | The accrual rule — work creates obligation (opt-in) | LED-015 ✅ | 15 BATS tests. Write-back refusal enforced. Double-count hazard proven + guarded |

---

## Phase 4 — the payoff ✅ COMPLETE

| ID | Status | Goal | Depends On | Notes |
|---|---|---|---|---|
| [TASK-LED-017](tasks/cards/TASK-LED-017.md) | **complete** | The attention queue — `balance -X att -S` | LED-015 ✅, LED-013 ✅, STRM-002 ✅ | 27 BATS tests. V1 weighted sum verified. V2 two-profile reorder proven. --at counterfactual, --format json |

**Falls out for free, built for nothing extra:** the floor-manager view · the hung-agent detector (a stale punch *is* a non-terminating loop) · counterfactual audit (`--value=then` vs `now`, verified to reorder) · the agent budget governor (`costs:api:anthropic` already exists in the account tree).

---

## Restructure: product-vs-meta (design 2026-07-09)

Spec: `specs/2026-07-09-product-meta-restructure-design.md`. Parts 1–3 (docs/ dedup = Part 4, separate spec). Execute in dependency order; 1B runs SOLO.

| Order | ID | Status | Goal | Depends On | Notes |
|---|---|---|---|---|---|
| 1 | [TASK-STRUCT-1A](tasks/cards/TASK-STRUCT-1A.md) | verified* | Decouple 5 runtime YAMLs system/config → config/ | — | ⚠️ HIGH FRAG; done+verified on agent/builder/struct-1a (9154879). *Pre-merge: N1 integration-in-install, N2 docs (Part 4) |
| 2 | [TASK-STRUCT-1B](tasks/cards/TASK-STRUCT-1B.md) | verified* | Rename system/ → dev/, tests/ → dev/tests/, stop shipping dev/ | 1A | Done+verified on agent/builder/struct-1b (160e725); 285 renames, suite identical to master. *Pre-merge: N1 integration-in-install, N2 docs (Part 4) |
| 3 | [TASK-STRUCT-2](tasks/cards/TASK-STRUCT-2.md) | pending | Consolidate 4 entry docs → canonical set | 1B | Low risk; GitBook fix deferred to Part 4 |
| 4 | [TASK-STRUCT-3](tasks/cards/TASK-STRUCT-3.md) | pending | Relocate 9 empty service stubs → dev/specs/service-designs/ | 1B | scripts/ + cmd/ held out. Confirmed empty 2026-07-13: base, cmd, diagnostic, help, kompare, open, unique, verify, you, z-default |

---

## Outside the program — residual queue

Everything not in THE PROGRAM or the Restructure. This replaces the five overlapping queue
tables that used to live here (see Reconciliation below). Small, and deliberately so.

**Recently completed (outside the phases):**
- **TASK-DEPS-001** — Fleet view (`ww deps check --all`). 17 BATS tests.

| Priority | ID | Status | Goal | Notes |
|---|---|---|---|---|
| LOW | [TASK-LED-018](tasks/cards/TASK-LED-018.md) | pending | Counterfactual valuation — dated weight history + `--value=DATE,att` | Not urgent until the loop-agent is live |

| Priority | ID | Status | Goal | Notes |
|---|---|---|---|---|
| HIGH | [TASK-TEST-003](tasks/cards/TASK-TEST-003.md) | pending | Harden `test-browser.bats` + `test-browser-warlock.bats` for CI isolation | Unblocks CI-001. ~29 known baseline failures live here |
| MEDIUM | [TASK-SITE-040](tasks/cards/TASK-SITE-040.md) | pending | Journal cross-journal entry link — fix non-functional link | Confirmed still broken 2026-07-13 (no cross-link handler in app.js) |
| MEDIUM | [TASK-SVC-008](tasks/cards/TASK-SVC-008.md) | pending | Rename bookbuilder → saves everywhere; add `ww saves` CLI | The ONLY real card of the old SVC-008..011 set. `ww saves` currently errors "not installed (peers8862-bookbuilder)"; `bookbuilder` still in 5 files |
| MEDIUM | [TASK-COMM-008](tasks/cards/TASK-COMM-008.md) | pending | Task annotation copy-back — approve/deny modal | Server side done; UI modal missing |
| LOW | [TASK-COMM-009](tasks/cards/TASK-COMM-009.md) | pending | **RESCOPED** — add `--format html\|json` to `ww warrior community export` | Was "promote Warrior from stub". Service already exists (215 lines); 5 of 6 criteria verified DONE 2026-07-13. Only the export flag remains |
| LOW | [TASK-COMM-010](tasks/cards/TASK-COMM-010.md) | pending | Warrior cross-profile annotation write | ⚠️ Listed COMM-009 as blocker. No longer blocked on the service existing — re-evaluate the dependency at dispatch |
| LOW | [TASK-AGENT-001](tasks/cards/TASK-AGENT-001.md) | pending | Canonical agent-templates in `resources/` | **Now unblocked** — its deps RES-001/RES-002 closed 2026-07-13 |
| LOW | [TASK-CI-001](tasks/cards/TASK-CI-001.md) | pending | Re-enable GitHub Actions CI | Depends on TEST-003. Wire `wwctl index --check` in as a gate here |

---

## Parked / Deferred

| ID | Status | Goal | Why |
|---|---|---|---|
| [TASK-EXT-CAL-001](tasks/cards/TASK-EXT-CAL-001.md) | parked | Calendar / reminders integration | Requires operator design decision |
| [TASK-TC-001](tasks/cards/TASK-TC-001.md) | parked | TaskChampion multi-device sync | Requires design review |
| [TASK-ISSUES-002](tasks/cards/TASK-ISSUES-002.md) | deferred | bugwarrior for additional profiles | Only `acme` configured |

---

## Reconciliation 2026-07-13

A full audit of all 145 cards against the running system. The board had drifted badly from the
cards; the cards are authoritative and won every disagreement.

**Root cause — the tooling could not see a sixth of the backlog.** `wwctl task-status` parsed
`grep "^Status:" | awk '{print $2}'`. Twelve cards used YAML frontmatter (`status: pending`,
lowercase, inside `---`) and three used bold markdown (`**Status:** complete`). All fifteen were
**silently skipped** — and those are exactly the fifteen that had gone missing from `INDEX.md`.
Worse, four of them carried *two contradictory status fields*: `status: pending` in frontmatter
and a `## Status` section in the body reading `complete — 2026-04-27`.

**Fixes applied:**
- All 145 cards normalised to the canonical `templates/task-card.md` format. One `Status:` per card.
- `dev/scripts/gen-index.sh` + `wwctl index` — `INDEX.md` is now GENERATED from card Status fields.
  **An unparseable card is a fatal error, never a silent omission.** `wwctl index --check` exits 1
  if the index is stale (wire into CI-001).
- Five legacy queue tables retired ("Dispatch Queue (Priority Order)", "Community Service — Phase 3
  Planning", "Queued Backlog (Phase 2+)", "Dispatch Queue (Phase 2 — active)", "Dependency Waves
  (Phase 2)"). They overlapped, contradicted each other, and were mostly completed work. Card status
  now lives in the generated INDEX; this board carries plan and priority only.
- The word "phase" disambiguated (it meant three different things).

**Twelve cards closed against verified evidence — zero engineering required:**

| Card | Was | Evidence |
|---|---|---|
| TASK-SITE-001 | pending | Parent epic; waves SITE-002..006 all complete. Browser serves **29 sections**. Superseded |
| TASK-WEB-001 | parked | Same delivery. Superseded. (A divergent copy also sits in `cards/removed/` — live card is authoritative) |
| TASK-SVC-009 | pending | `ww network status\|check\|help` — all pass, exit codes correct |
| TASK-SVC-010 | pending | `ww projects list\|show\|describe\|help` — all pass |
| TASK-SVC-011 | pending | `ww warrior summary\|hooks\|report\|help` — all pass (215-line service) |
| TASK-RES-001 | pending | Body said complete; `scripts/build-ledger-inventory.sh` exists |
| TASK-RES-002 | pending | Body said complete; `scripts/build-uda-inventory.sh` + `ww profile uda inventory` exist |
| TASK-SITE-041 | pending | Body said complete; `journal_restore` in `server.py` |
| TASK-SITE-042 | pending | Body said complete; `_dismissedCmdLog` in `app.js` |
| TASK-LED-002 | open | Subsumed by LED-014 (board already said so; card status lagged) |
| TASK-LED-003 | open | Subsumed by LED-015; `docs/modular-journals.md` exists |
| TASK-EXT-GUN-001-EXPLORE | pending | Moot — a *pre-implementation* audit for TASK-EXT-GUN-001, which shipped in 27d019d |

**Also stale on the old board, already complete on their cards:** SITE-006 (listed *twice*, once
`complete` and once `pending`, in the same table), SITE-035, SITE-039, EXT-SWORD-001, LED-001,
COMM-001..007 (the "pending Gate A" community table — 7 of its 10 rows had shipped),
EXT-CRON-001 (listed as both complete *and* parked).

**Follow-up for the operator (live TaskWarrior data — deliberately NOT auto-mutated):** the closed
cards' `Taskwarrior:` rows were updated in the card text, but the `wwdev` task DB was not touched
(hard rule 1: never write profile data). Run `wwdev task <id> done` for the twelve closed cards.

---

## Historical phases (closed — not a live queue)

**Old project Phase 1:** Closed. Explorer A + B complete, artifact cleanup done, CSSOT corrected.
**Old project Phase 2:** Implementation era (CLI taxonomy, services, sync, browser UI, installer).
Effectively closed — its residuals are the eight cards in "Outside the program" above.
These numbers are historical only. The live numbering is THE PROGRAM's Phase 0–4.

**TASK-1.1 / TASK-1.2 / TASK-1.4** — closed as design corrections: `dev/CLAUDE.md`,
`dev/services-CLAUDE.md`, and `dev/TASKS.md` are authoritative; deploying copies to the project
root would create a maintenance split in a user-data directory.

Prerequisites that still bind any `lib/` Builder task:
- `lib/CLAUDE.md` must exist
- `dev/tests/CLAUDE.md` must exist

---

## Completed Tasks

**117 cards complete.** The full, always-current list is generated into
[`tasks/INDEX.md`](tasks/INDEX.md) — run `wwctl index` to refresh. It is no longer duplicated here;
the hand-maintained copy was one of the mirrors that drifted.

---

## Fragility Register (interim)

Full policy: `fragility-register.md`

| File(s) | Classification |
|---|---|
| `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh` | HIGH FRAGILITY |
| `bin/ww`, `lib/shell-integration.sh` | SERIALIZED |
