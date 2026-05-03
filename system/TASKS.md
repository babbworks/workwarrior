# TASKS.md — Workwarrior Canonical Task Board

**Summary index only. Each task's source of truth is its card in `tasks/cards/TASK-XXX.md`.**
**Orchestrator is the only agent that updates status fields.**
`pending/` is archive-only. Nothing new is written there.

Last updated: 2026-05-02 (TASK-INSTALL-003 complete — installer v0.2: 6-preset taxonomy, @instance dispatch, companion functions, multi-anchor registry, pin/unpin, default profile rename; production migrated ~/ww → ~/wwv02)
Current phase: Phase 2 active — browser UI polish, resource management, test hardening, stub service promotion

---

## Active Tasks

| ID | Status | Goal |
|---|---|---|
| _(none)_ | — | Awaiting next dispatch |

---

## Dispatch Queue (Priority Order)

| Priority | ID | Goal |
|---|---|---|
| HIGH | [TASK-SITE-040](tasks/cards/TASK-SITE-040.md) | Journal cross-journal entry link — fix non-functional UI response |
| HIGH | [TASK-SITE-041](tasks/cards/TASK-SITE-041.md) | Archive view button — browse/restore archived entries across services |
| MEDIUM | [TASK-COMM-008](tasks/cards/TASK-COMM-008.md) | Task annotation copy-back — approve/deny modal (server done; UI modal missing) |
| MEDIUM | [TASK-SITE-042](tasks/cards/TASK-SITE-042.md) | CMD log UI — collapse/clear/dismiss past command entries |
| MEDIUM | [TASK-RES-001](tasks/cards/TASK-RES-001.md) | Ledger account/commodity inventory — aggregate from all profiles |
| MEDIUM | [TASK-RES-002](tasks/cards/TASK-RES-002.md) | UDA inventory — aggregate from all profile .taskrc files |
| MEDIUM | [TASK-TEST-003](tasks/cards/TASK-TEST-003.md) | Harden test-browser.bats + test-browser-warlock.bats for CI |
| MEDIUM | [TASK-AGENT-001](tasks/cards/TASK-AGENT-001.md) | Canonical ww-agent-guidance in resources/agent-templates/ |
| MEDIUM | [TASK-EXT-SWORD-001](tasks/cards/TASK-EXT-SWORD-001.md) | Sword weapon — browser UI |
| LOW | [TASK-LED-001](tasks/cards/TASK-LED-001.md) | Ledger transaction row redesign — 3-line item UI |
| LOW | [TASK-CI-001](tasks/cards/TASK-CI-001.md) | Re-enable GitHub Actions CI (depends on TASK-TEST-003) |
| PARKED | [TASK-EXT-GUN-001-EXPLORE](tasks/cards/TASK-EXT-GUN-001-EXPLORE.md) | Read-only audit of taskgun source (defer until after browser polish) |

---

## Community Service — Phase 3 Planning

Spec status: architecture settled 2026-04-20. Cards pending Gate A (acceptance criteria to be filled before dispatch).

| Priority | ID | Goal | Depends On |
|---|---|---|---|
| H | [TASK-COMM-001](tasks/cards/TASK-COMM-001.md) | Community storage layer — `community.db` schema + migrations | — |
| H | [TASK-COMM-002](tasks/cards/TASK-COMM-002.md) | Community bash CLI — `services/community/` | COMM-001 |
| H | [TASK-COMM-009](tasks/cards/TASK-COMM-009.md) | Warrior service — promote from stub, community mgmt, cross-profile read | COMM-001 |
| H | [TASK-COMM-004](tasks/cards/TASK-COMM-004.md) | Browser `/data/community/*` server endpoints | COMM-001 |
| H | [TASK-COMM-003](tasks/cards/TASK-COMM-003.md) | Browser community section — 4 views (Unified/Journal/Tasks/Comments) | COMM-004 |
| M | [TASK-COMM-005](tasks/cards/TASK-COMM-005.md) | Journal annotation append — timestamped separator format | — |
| M | [TASK-COMM-006](tasks/cards/TASK-COMM-006.md) | Journal metadata markers — `@tags`/`@project`/`@priority` at creation | — |
| M | [TASK-COMM-007](tasks/cards/TASK-COMM-007.md) | Journal filter buttons — Annotated / Rejournaled / All Comments | COMM-005, COMM-006 |
| M | [TASK-COMM-008](tasks/cards/TASK-COMM-008.md) | Task annotation copy-back — approve/deny + community prefix control | COMM-002 |
| L | [TASK-COMM-010](tasks/cards/TASK-COMM-010.md) | Warrior cross-profile annotation write — phase 2, blocked on COMM-009 | COMM-009 |

---

## Queued Backlog (Phase 2+)

| ID | Status | Goal |
|---|---|---|
| [TASK-SYS-001](tasks/cards/TASK-SYS-001.md) | complete | Fully activate `/system` as control plane |
| [TASK-SYS-002](tasks/cards/TASK-SYS-002.md) | complete | Pass Phase-1 checks except expected rollout gates |
| [TASK-SYS-003](tasks/cards/TASK-SYS-003.md) | complete | Create command syntax source of truth |
| [TASK-CLI-001](tasks/cards/TASK-CLI-001.md) | complete | Define top-level CLI taxonomy |
| [TASK-CLI-002](tasks/cards/TASK-CLI-002.md) | complete | Standardize global flag model |
| [TASK-CLI-003](tasks/cards/TASK-CLI-003.md) | complete | Standardize help output contract |
| [TASK-CLI-004](tasks/cards/TASK-CLI-004.md) | complete | Add deprecation/compatibility command layer |
| [TASK-SVC-001](tasks/cards/TASK-SVC-001.md) | complete | Implement journal command lifecycle |
| [TASK-SVC-002](tasks/cards/TASK-SVC-002.md) | complete | Implement ledger command lifecycle |
| [TASK-SVC-003](tasks/cards/TASK-SVC-003.md) | complete | Add service discovery/info/help commands |
| [TASK-SVC-004](tasks/cards/TASK-SVC-004.md) | complete | Add profile import/restore workflow |
| [TASK-SVC-005](tasks/cards/TASK-SVC-005.md) | complete | Harden questions service CLI UX |
| [TASK-SVC-006](tasks/cards/TASK-SVC-006.md) | complete | Normalize issues service command contract |
| [TASK-TEST-001](tasks/cards/TASK-TEST-001.md) | complete | Enforce test baseline by change type |
| [TASK-SHELL-001](tasks/cards/TASK-SHELL-001.md) | complete | Add set -euo pipefail to all lib/ and services/ scripts |
| [TASK-SYNC-001](tasks/cards/TASK-SYNC-001.md) | complete | Add test coverage for GitHub sync engine |
| [TASK-SYNC-002](tasks/cards/TASK-SYNC-002.md) | complete | Fix critical state integrity bugs in sync engine |
| [TASK-SYNC-003](tasks/cards/TASK-SYNC-003.md) | complete | Harden sync pre-flight validation and error surfacing |
| [TASK-SYNC-004](tasks/cards/TASK-SYNC-004.md) | complete | Resolve tag sync TODO in sync-pull.sh (Gate E) |
| [TASK-SYNC-005](tasks/cards/TASK-SYNC-005.md) | complete | Implement GitHub label → TaskWarrior tag sync |
| [TASK-TEST-002](tasks/cards/TASK-TEST-002.md) | complete | Add CI gate for BATS + integration tests |
| [TASK-QUAL-001](tasks/cards/TASK-QUAL-001.md) | complete | Enforce artifact hygiene across repo |
| [TASK-QUAL-004](tasks/cards/TASK-QUAL-004.md) | complete | Fix filter_system_tags() jq iterator bug in field-mapper.sh |
| [TASK-SYNC-006](tasks/cards/TASK-SYNC-006.md) | complete | Extended label encoding for categorical UDA ↔ GitHub label sync |
| [TASK-SYNC-007](tasks/cards/TASK-SYNC-007.md) | complete | Issue body YAML block for rich UDA ↔ GitHub sync |
| [TASK-QUAL-002](tasks/cards/TASK-QUAL-002.md) | complete | Automate docs/help parity checks (`system/scripts/check-parity.sh`) |
| [TASK-ISSUES-001](tasks/cards/TASK-ISSUES-001.md) | complete | Improve `ww issues uda` CLI and uda-manager service |
| [TASK-ISSUES-002](tasks/cards/TASK-ISSUES-002.md) | deferred | Configure bugwarrior for additional profiles |
| [TASK-QUAL-003](tasks/cards/TASK-QUAL-003.md) | complete | Audit and clean functions/ directory dead code |
| TASK-INSTALL-001 | complete | Per-tool interactive installer (no separate card file — see Completed Tasks) |
| [TASK-INSTALL-002](tasks/cards/TASK-INSTALL-002.md) | complete | Fix journals() function — grep matches all YAML keys, not just journal names under journals: section |
| [TASK-INSTALL-003](tasks/cards/TASK-INSTALL-003.md) | complete | Installer v0.2 — 6-preset taxonomy, @instance dispatch, multi-anchor registry, companion functions, pin/unpin, default profile |
| [TASK-SHELL-UX-001](tasks/cards/TASK-SHELL-UX-001.md) | complete | Shell integration overhaul — re-source safety, dual-rc writes, bare commands, profile creation output cleanup |
| [TASK-TIMEW-001](tasks/cards/TASK-TIMEW-001.md) | complete | Per-profile TimeWarrior extensions (`ww timew extensions`, timew-billable preset) |
| [TASK-DESIGN-001](tasks/cards/TASK-DESIGN-001.md) | complete | `service-overview.md` for 12 undeveloped service categories (+ `saves/`) |
| [TASK-UX-001](tasks/cards/TASK-UX-001.md) | complete | Standardize human/compact/json output behavior |
| [TASK-UX-002](tasks/cards/TASK-UX-002.md) | complete | Build command examples library per service |
| [TASK-REL-001](tasks/cards/TASK-REL-001.md) | complete | Operationalize release checklist gate |
| [TASK-REL-002](tasks/cards/TASK-REL-002.md) | complete | Define production-ready CLI milestone criteria |
| [TASK-UDA-001](tasks/cards/TASK-UDA-001.md) | complete | Build ww profile uda surface — list/add/remove/group/manage/perm |
| [TASK-UDA-002](tasks/cards/TASK-UDA-002.md) | complete | Unicode indicator system for UDA groups |
| [TASK-UDA-003](tasks/cards/TASK-UDA-003.md) | complete | UDA color schema — systematic color rules for TW reports |
| [TASK-URG-001](tasks/cards/TASK-URG-001.md) | complete | Interactive urgency coefficient tuning |
| [TASK-TC-001](tasks/cards/TASK-TC-001.md) | parked | TaskChampion multi-device profile sync — ww integration layer |
| [TASK-SITE-001](tasks/cards/TASK-SITE-001.md) | pending | Parent epic: `ww browser` design (waves tracked in SITE-002..006) |
| [TASK-SITE-002](tasks/cards/TASK-SITE-002.md) | complete | Wave 1: server scaffolding — Python3 HTTP + SSE + /cmd + /profile endpoints |
| [TASK-SITE-003](tasks/cards/TASK-SITE-003.md) | complete | Wave 2: UI shell — dark terminal aesthetic, sidebar, terminal line, SSE wiring |
| [TASK-SITE-004](tasks/cards/TASK-SITE-004.md) | complete | Wave 3: Live data sections — all 4 tools, /data/* endpoints, /action mutations |
| [TASK-SITE-005](tasks/cards/TASK-SITE-005.md) | complete | Wave 4: Time, Journal, Ledger polish |
| [TASK-SITE-006](tasks/cards/TASK-SITE-006.md) | complete | Wave 5: export, terminal context, inline forms, density, transaction search |
| [TASK-SITE-006](tasks/cards/TASK-SITE-006.md) | pending | Wave 5: export/publish, full typeahead, keyboard shortcuts, polish |
| [TASK-EXT-SWORD-001](tasks/cards/TASK-EXT-SWORD-001.md) | pending | Design and implement Sword weapon service for browser UI |
| [TASK-SITE-008](tasks/cards/TASK-SITE-008.md) | complete | Fix task start/stop/done buttons in browser |
| [TASK-SITE-009](tasks/cards/TASK-SITE-009.md) | complete | Fix Times click-to-start on interval rows |
| [TASK-SITE-010](tasks/cards/TASK-SITE-010.md) | complete | Enable UDA editing from task inline detail |
| TASK-SITE-036 | complete | Tags screen — function-group nav item, tag cards with count/date, status/priority/UDA chip filters, exclude toggle, sort |
| TASK-SITE-037 | complete | Task dependency display — ⊸N/→N row badges, dep section in inline detail, dep_add/dep_remove server actions |
| TASK-SITE-038 | complete | Header restructure — unified resource slot adjacent to title, green active-task bar removed, stat-context-bar removed, section-resource-bars removed |

---

## Dispatch Queue (Phase 2 — active)

| Priority | ID | Goal | Depends On |
|---|---|---|---|
| 1 | [TASK-COMM-008](tasks/cards/TASK-COMM-008.md) | Task annotation copy-back modal | server ✓; UI modal pending |
| 2 | [TASK-EXT-SWORD-001](tasks/cards/TASK-EXT-SWORD-001.md) | Sword weapon browser UI | — |
| 3 | [TASK-LED-001](tasks/cards/TASK-LED-001.md) | Ledger row redesign | — |
| 4 | [TASK-SITE-039](tasks/cards/TASK-SITE-039.md) | Journal markdown rendering with toggle | — |
| — | [TASK-ISSUES-002](tasks/cards/TASK-ISSUES-002.md) | Configure bugwarrior for additional profiles (deferred) | — |

---

## Dependency Waves (Phase 2)

| Wave | Tasks | Depends On |
|---|---|---|
| A (safety floor) | ~~`TASK-SHELL-001`~~ ~~`TASK-SHELL-UX-001`~~ ~~`TASK-INSTALL-002`~~ ~~`TASK-SYNC-002`~~ ~~`TASK-SYNC-004`~~ (all done) | — |
| B (test coverage) | ~~`TASK-SYNC-001`~~ ~~`TASK-TEST-002`~~ (done) | Wave A ✓ |
| C (sync hardening) | ~~`TASK-SYNC-003`~~ (done) | Waves A + B |
| D (quality/CI) | ~~`TASK-QUAL-001`~~ ~~`TASK-QUAL-003`~~ ~~`TASK-QUAL-004`~~ ~~`TASK-QUAL-002`~~ ~~`TASK-UX-001`~~ | Wave A |
| E (release) | ~~`TASK-REL-001`~~ ~~`TASK-REL-002`~~ ~~`TASK-UX-002`~~ (done) | Waves A-D |

---

## Completed Tasks

| ID | Goal |
|---|---|
| TASK-SYS-001..003 | Control plane, phase-1 checks, CSSOT |
| TASK-CLI-001..004 | Full CLI taxonomy, flags, help, deprecation layer |
| TASK-SVC-001..006 | All service command lifecycles |
| TASK-TEST-001 | Test baseline by change type (select-tests.sh) |
| TASK-1.3a | Explorer A — docs/status drift audit |
| TASK-1.3b | Explorer B — code/test reality audit |
| TASK-1.5 | Artifact cleanup (.gitignore + untrack 24 files) |
| TASK-SHELL-001 | set -euo pipefail sweep (sourced libs use defensive guards; flags in executed scripts only) |
| TASK-INSTALL-001 | Per-tool interactive installer with version cards, platform detection, conflict neutralisation, uninstall |
| TASK-INSTALL-002 | Fix journals() YAML grep bug — awk section-scoped reader |
| TASK-INSTALL-003 | Installer v0.2: 6-preset taxonomy (basic/direct/multi/hidden/isolated/hardened); `@instance [profile] [cmd]` dispatch + companion activation functions; multi-anchor registry isolation (`~/.config/<cmd>/`); `ww pin`/`ww unpin`; `instances()` bare function; default profile renamed `main`→`default`; 3 runtime bug fixes; prompt silent when no profile active; production migrated `~/ww` → `~/wwv02` |
| TASK-SHELL-UX-001 | Shell integration overhaul: re-source safety, dual-rc writes, bare commands, profile creation output cleanup |
| TASK-SYNC-001 | Add BATS test coverage for GitHub sync engine (42 tests: state, detection, API) |
| TASK-SYNC-002 | Fix 3 critical data-integrity bugs: mv error checks in state, JSON input validation in detector, two-phase commit in profile restore |
| TASK-SYNC-004 | Gate E: remove TODO from sync-pull.sh, create TASK-SYNC-005 for deferred tag sync |
| TASK-REL-001..002 | Release checklist gate (Gate D) + production-readiness rubric |
| TASK-SITE-005 | Wave 4: Time / Journal / Ledger polish + top bar + typeahead + terminal position |
| TASK-SITE-007 | Browser UI overhaul meta-card closed; residual scope migrated to TASK-SITE-006 |
| TASK-TIMEW-001 | `ww timew extensions` + timew-billable integration doc + CSSOT `timew` domain |
| TASK-DESIGN-001 | Twelve `services/*/service-overview.md` design stubs (+ `services/saves/`) |
| TASK-UX-001 | Standardized compact-default output policy + `--json`/`--verbose` behavior for read/list flows |
| TASK-UX-002 | Approved command examples library per major command family + verifier checklist integration |
| TASK-EXT-CRON-001 | `ww routines` recurring-task microservice (profile-scoped `.config/routines`) |
| TASK-EXT-WARLOCK-001 | `ww browser warlock` — task-warlock Next.js UI adopted as sibling (port 5001); `ww web` synonym; browser sidebar panel; 25 bats tests |
| TASK-QUAL-002 | Gate C: `system/scripts/check-parity.sh` + Verifier workflow hook |
| TASK-ISSUES-001 | ww-native `issues uda` + idempotent install + canonical github group |
| TASK-QUAL-003 | Dead code audit: removed 8 unreferenced scripts from functions/ |
| TASK-ISSUES-† | Session 4: bugwarrior installed (pipx + setuptools); profile configured; GitHub UDAs added to .taskrc; configure-issues.sh GitHub wizard overhauled (gh auth token, login/org split, project_template, UDA auto-generate); dependency-installer.sh + bin/ww install hints corrected; uda-manager.sh service-source display; test-shell-functions Property 12 assertion fixed |

---

## Phase 1 Resolution Notes

**TASK-1.1** (Deploy root CLAUDE.md): Closed as design correction.
  `system/CLAUDE.md` is authoritative and already loaded by agent sessions.
  Deploying a copy to the project root would create a maintenance split in a user-data directory.

**TASK-1.2** (Deploy services/CLAUDE.md): Same resolution as TASK-1.1.
  `system/services-CLAUDE.md` is authoritative.

**TASK-1.4** (TASKS.md at project root): Closed as design correction.
  `system/TASKS.md` is authoritative. Project root is user data space.

---

## Fragility Register (interim)

Full policy: `fragility-register.md`

| File(s) | Classification |
|---|---|
| `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh` | HIGH FRAGILITY |
| `bin/ww`, `lib/shell-integration.sh` | SERIALIZED |

---

## Phase Boundary Rules

**Phase 1:** Closed. Explorer A + B complete, artifact cleanup done, CSSOT corrected.

**Phase 2 prerequisites before any lib/ Builder task:**
- `lib/CLAUDE.md` must exist
- `tests/CLAUDE.md` must exist
- TASK-SHELL-001 strongly recommended before touching HIGH FRAGILITY files
