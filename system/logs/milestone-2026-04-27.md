# Workwarrior Milestone Assessment — 2026-04-27

**Trigger:** Orchestrator-requested full scan of ww-development Taskwarrior profile, service state, extensions, tests, and documentation. 8 new task cards created. 1 TW task closed (subjournals fix confirmed).

---

## Tool State Summary

### What's Actually Built (Production Quality)

**Browser (crown jewel)**
`server.py` is ~5,200 lines. `app.js` is ~7,700 lines. This is a fully realized SPA. Shipping features:
- 25+ sections: Tasks, Times, Journal, Ledger, Lists, Communities, Warlock, Projects, Tags, Sync, Models, Questions, Ctrl, CMD, Export, Groups, Warrior, Next, Schedule, Sword, Gun, Profile, Bookbuilder, Network
- SSE live refresh, 30s polling fallback
- Profile-scoped named resources: sub-journals, sub-ledgers, sub-tasklists, sub-timew (dropdown selector, `+` create, working after today's `[\w-]+` regex fix)
- Task CRUD + inline detail + dependencies + bulk ops + urgency + UDA inputs
- Journal: markdown rendering toggle, filter chips (annotated/rejournaled/all-comments), pagination, metadata markers, archive/delete, cross-journal entry (link bug → TASK-SITE-040)
- Ledger: transaction entry, hledger balance/register, account tab-complete, currency units, archived view (archive missing browse → TASK-SITE-041)
- Communities: full CRUD, unified/journal/tasks/comments views, copy-back workflow, project/tag badges, SSE-driven
- Weapons: Gun (task series generator), Sword (task splitter)
- CMD: 627-rule heuristic engine + AI fallback + log (log UX → TASK-SITE-042)
- Warlock: task-warlock Next.js UI adopted as sibling
- Markdown rendering across journal, communities, ledger notes

**CLI Services (solid)**
| Service | Lines | Status |
|---|---|---|
| `custom/` (github-sync, issues, sync-*) | 814 / 6 files | Production |
| `community/` | 542 | Production |
| `browser/` | 392 | Production |
| `ctrl/` | 361 | Production |
| `profile/` | 406 / 4 files | Production |
| `warlock/` | 669 | Production |
| `x-delete/` | 602 | Production |
| `export/` | 506 | Production |
| `models/` | 448 | Production |
| `groups/` | 329 | Production |
| `remove/` | 368 | Production |

**Library Layer (lib/)**
24 files. GitHub sync engine (8 files) is architecturally complete with lock-based concurrency. `community-db.sh` and `journal-scanner.sh` added recently. `journal_scanner.py` (Python companion) in lib/.

**Extensions**
- `services/extensions/` — TaskWarrior extensions registry via GitHub API (287-line Python scraper). `ww extensions taskwarrior list/search/info/refresh` functional.
- TimeWarrior: `ww timew extensions help` surfaces `timew-billable` (trev-dev). BATS test suite exists (46 lines, 2 tests — thin).
- Warlock (task-warlock Next.js): installed, wired, has its own BATS suite (366 lines).

**Tests**
41 BATS files, ~12,000 lines total. Coverage is broad but CI is disabled. Key gaps:
- `test-browser.bats` (267 lines) — port-coupling issues, not CI-safe
- `test-browser-warlock.bats` (366 lines) — new, not validated in CI
- `test-timew-extensions.bats` (46 lines, 2 tests) — thin
- GitHub sync tests exist but require live credentials (correctly excluded from CI)

---

## Stub Services (Design-Only, No Implementation)

These 12 services exist as `README.md` or `service-overview.md` only. No executable script:

| Service | Notes |
|---|---|
| `base/` | Internal scaffolding stub |
| `cmd/` | Has `cmd.log` artifact — no shell script |
| `diagnostic/` | Service overview only |
| `help/` | Service overview only |
| `kompare/` | Service overview only |
| `network/` | Service overview only |
| `open/` | Service overview only |
| `projects/` | README only — browser panel exists but no CLI |
| `saves/` | Service overview only |
| `servers/` | README only |
| `unique/` | Service overview only |
| `verify/` | Service overview only |
| `warrior/` | Service overview only (browser panel exists) |
| `you/` | Service overview only |
| `z-default/` | README only — fallback handler |

`bookbuilder/` is a full Python application (ingest/fetch/analyze/cluster/build/agents pipeline) but has no ww CLI integration — it's a standalone tool living in services/.

---

## Documentation State

**Outdated / Misleading**
- `docs/IMPLEMENTATION-COMPLETE.md` and `docs/RELEASE-CHECKLIST.md` describe a much earlier state of the tool. The browser has grown by ~5,000 lines since any doc checkpoint.
- `docs/site/` guides describe Wave 1-3 browser features. Wave 4-5 additions (communities, dependencies, tags section, resource selectors, markdown rendering, weapons) are undocumented.
- `docs/overviews/` and `docs/search-guides/` describe the CLI as if services like warrior, projects, network, you are implemented — they're stubs.

**Adequate**
- GitHub sync docs (`docs/github-sync-*.md`, `GITHUB-SYNC-README.md`) are detailed and reasonably current.
- `system/ONBOARDING.md`, `system/CLAUDE.md`, `system/TASKS.md` are well-maintained.
- `lib/CLAUDE.md` is accurate and enforced.

**Gap: ww-agent-guidance**
Lives only in `.claude/ww/` — not installable, not derivable from system state. TASK-AGENT-001 addresses this.

---

## Prioritization Breakdown (Synthesized)

### Tier 1 — Fix Active Bugs (do next)

| Card | Why Now |
|---|---|
| TASK-SITE-040 | Journal cross-journal add is broken — users see a useless link. Regression in core workflow. |
| TASK-SITE-041 | Archive actions exist in server + UI but there's no way to VIEW or restore archived items. Feature is half-built. |

### Tier 2 — Browser Polish (high leverage, visible)

| Card | Why |
|---|---|
| TASK-COMM-008 | Task annotation copy-back UI modal is the last missing piece of the community flow. Server side done. |
| TASK-SITE-042 | CMD log grows unboundedly — functional but annoying on long sessions. |
| TASK-LED-001 | Ledger row redesign — current flat row is information-poor. |
| TASK-SITE-039 | Markdown rendering toggle (in progress — already coded, needs verification/cleanup) |

### Tier 3 — Infrastructure / Quality (unblocking CI and future work)

| Card | Why |
|---|---|
| TASK-TEST-003 | Unlocks CI. Browser test suites are the highest-value tests and they can't run in CI today. |
| TASK-RES-001 | Cross-profile ledger accounts → better browser tab-complete + onboarding |
| TASK-RES-002 | Cross-profile UDA inventory → CMD AI context, new profile wizard |
| TASK-AGENT-001 | Installable agent guidance → faster cold-start in new sessions |
| TASK-CI-001 | Depends on TEST-003. Green CI is a milestone gate for any public release claim. |

### Tier 4 — Stub Service Promotion (medium-term)

| Service | Effort | Value |
|---|---|---|
| `warrior/` | Low-medium — browser panel exists, need CLI to match | High — closes docs gap |
| `projects/` | Low — browser panel exists, need `ww project` CLI | High |
| `you/` | Unknown scope | Medium |
| `network/` | Unknown scope | Low (niche) |
| Others | All design-only | Defer |

### Parked / Deferred (correct as-is)

- TASK-EXT-GUN-001-EXPLORE — Gun works; audit is nice-to-have
- TASK-EXT-CAL-001 — Calendar integration scope unclear; platform differences large
- TASK-TC-001 — TaskChampion sync is a significant undertaking; not blocking anything
- TASK-ISSUES-002 — Single-profile bugwarrior is fine for now
- TASK-COMM-010 — Blocked on warrior service stub promotion

---

## Release Readiness Signal

| Dimension | Status |
|---|---|
| Browser UI | ~85% — feature-rich, a few bugs and missing archive view |
| CLI Core (profile, journal, ledger, time) | ~90% — solid |
| CLI Stubs | ~40% — 12+ services are design-only |
| GitHub Sync | ~80% — functional, CI-untested |
| Tests / CI | ~50% — suites exist, CI disabled |
| Documentation | ~35% — user docs behind by 3 major browser waves |
| Extensions | ~60% — TW registry functional, timew thin, warlock integrated |

**Honest assessment:** The tool is production-quality for personal use and for users who activate it from the repo. It is not yet releasable in a public sense because CI is disabled, ~12 services are stubs, and user docs are significantly behind. The browser in particular is the most impressive and most advanced part — it would benefit from a dedicated documentation wave before any public announcement.
